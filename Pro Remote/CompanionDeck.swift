import Foundation
import Network
import ImageIO
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

/// A virtual Stream Deck backed by Bitfocus Companion's Satellite API.
///
/// Companion treats this app like a hardware surface: it pushes every key's image (and text and
/// colour) whenever it changes, and the app reports presses back. That is the same channel a
/// physical Stream Deck uses, so buttons, feedback and page changes behave exactly as they do on
/// the real thing — nothing is polled or scraped.
///
/// Protocol: a line-based TCP text protocol (default port 16622); see Companion's
/// "Satellite API" documentation. Messages are `COMMAND KEY=value KEY="quoted value" ...`.
@Observable
@MainActor
final class CompanionDeck {
    enum State: Equatable {
        case idle
        case connecting
        case connected
        case failed(String)
    }

    static let columns = 8
    static let rows = 4
    static var keyCount: Int { columns * rows }

    private(set) var state: State = .idle
    /// The current picture for each key, by key index (row-major, `columns` per row).
    private(set) var images: [Int: CGImage] = [:]
    /// The colour along the top and bottom edge of each key's picture (below the location strip).
    /// The strip is cropped off by default, and these fill the space that leaves, so the key stays
    /// square without a visible seam.
    private(set) var edges: [Int: EdgeColors] = [:]
    /// Button text, used only to label keys for VoiceOver.
    private(set) var labels: [Int: String] = [:]
    /// The Companion page this surface is currently showing, once known.
    private(set) var page: Int?

    // MARK: - Connection bookkeeping

    private var host = ""
    private var port = 16622
    private var bitmapSize = 256
    private var running = false
    private var connection: NWConnection?
    private var buffer = Data()
    private var keepAlive: Task<Void, Never>?
    private var reconnect: Task<Void, Never>?
    private var attempt = 0
    private var lastReceived = ContinuousClock.now
    private var imageSequence: [Int: Int] = [:]
    private var heldKeys: Set<Int> = []

    /// Stable per install, so Companion can remember how this surface was set up.
    private let deviceID: String = {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: "co_device_id") { return existing }
        let created = "ProRemote-" + UUID().uuidString.prefix(8)
        defaults.set(created, forKey: "co_device_id")
        return created
    }()

    private var productName: String {
        #if os(iOS)
        "Pro Remote (\(UIDevice.current.model))"
        #else
        "Pro Remote (Mac)"
        #endif
    }

    // MARK: - Lifecycle

    func start(host: String, port: Int, bitmapSize: Int) {
        self.host = host
        self.port = port
        self.bitmapSize = bitmapSize
        guard !running else { return }
        running = true
        attempt = 0
        open()
    }

    /// Releases anything still held and tells Companion this surface is gone.
    func stop() {
        running = false
        reconnect?.cancel()
        keepAlive?.cancel()
        guard let connection else { state = .idle; return }
        for key in heldKeys { send("KEY-PRESS DEVICEID=\"\(deviceID)\" KEY=\(key) PRESSED=0", on: connection) }
        heldKeys.removeAll()
        let finish = Data("REMOVE-DEVICE DEVICEID=\"\(deviceID)\"\n".utf8)
        connection.send(content: finish, completion: .contentProcessed { _ in connection.cancel() })
        self.connection = nil
        state = .idle
    }

    /// Drops the current connection and tries again straight away.
    func retryNow() {
        guard running else { return }
        reconnect?.cancel()
        attempt = 0
        tearDownConnection()
        open()
    }

    func setKey(_ key: Int, pressed: Bool) {
        guard let connection, state == .connected else { return }
        if pressed { heldKeys.insert(key) } else { heldKeys.remove(key) }
        send("KEY-PRESS DEVICEID=\"\(deviceID)\" KEY=\(key) PRESSED=\(pressed ? 1 : 0)", on: connection)
    }

    // MARK: - Connecting

    private func open() {
        guard running, let portValue = NWEndpoint.Port(rawValue: UInt16(clamping: port)), !host.isEmpty else {
            state = .failed("Enter Companion's address in Settings.")
            return
        }
        state = .connecting
        buffer.removeAll(keepingCapacity: true)

        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.connectionTimeout = 5
        let connection = NWConnection(host: NWEndpoint.Host(host), port: portValue, using: NWParameters(tls: nil, tcp: tcp))
        self.connection = connection

        connection.stateUpdateHandler = { [weak self, weak connection] newState in
            Task { @MainActor [weak self] in
                guard let self, let connection, self.connection === connection else { return }
                switch newState {
                case .ready:
                    self.lastReceived = .now
                    self.register(on: connection)
                    self.receive(on: connection)
                    self.startKeepAlive()
                case .failed(let error):
                    self.connectionLost(error.localizedDescription)
                case .waiting(let error):
                    // Unreachable host, refused port, local-network permission not granted yet.
                    self.connectionLost(error.localizedDescription)
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
    }

    private func register(on connection: NWConnection) {
        // Raw RGB would be megabytes per refresh; PNG keeps a whole page well under half a
        // megabyte. COLORS/TEXT are requested too so VoiceOver can read each key.
        let add = "ADD-DEVICE DEVICEID=\"\(deviceID)\" PRODUCT_NAME=\"\(productName)\" "
            + "KEYS_TOTAL=\(Self.keyCount) KEYS_PER_ROW=\(Self.columns) "
            + "BITMAPS=\(bitmapSize) BITMAP_FORMAT=png COLORS=hex TEXT=true"
        send(add, on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self, weak connection] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self, let connection, self.connection === connection else { return }
                if let data, !data.isEmpty {
                    self.lastReceived = .now
                    self.buffer.append(data)
                    self.drainLines()
                }
                if let error {
                    self.connectionLost(error.localizedDescription)
                } else if isComplete {
                    self.connectionLost("Companion closed the connection.")
                } else {
                    self.receive(on: connection)
                }
            }
        }
    }

    private func drainLines() {
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if !line.isEmpty { handle(Array(line)) }
        }
    }

    // MARK: - Messages

    private func handle(_ line: [UInt8]) {
        let (command, params) = Self.parse(line)
        switch command {
        case "ADD-DEVICE":
            if params["ERROR"] != nil {
                connectionLost(params["MESSAGE"] ?? "Companion rejected this surface.")
            } else {
                state = .connected
                attempt = 0
            }
        case "KEY-STATE":
            applyKeyState(params)
        case "KEYS-CLEAR":
            images.removeAll()
            labels.removeAll()
            edges.removeAll()
        default:
            break // BEGIN, CAPS, BRIGHTNESS, PONG, KEY-PRESS acknowledgements: nothing to show.
        }
    }

    private func applyKeyState(_ params: [String: String]) {
        guard params["DEVICEID"] == deviceID,
              (params["TYPE"] ?? "BUTTON") == "BUTTON",
              let key = Int(params["KEY"] ?? ""), (0..<Self.keyCount).contains(key) else { return }

        if let location = params["LOCATION"], let first = location.split(separator: "/").first, let value = Int(first) {
            page = value
        }
        if let encoded = params["TEXT"], let data = Data(base64Encoded: encoded), let text = String(data: data, encoding: .utf8) {
            labels[key] = text.replacingOccurrences(of: "\\n", with: " ").replacingOccurrences(of: "\n", with: " ")
        }
        guard let bitmap = params["BITMAP"], !bitmap.isEmpty else { return }

        // Decoding a few hundred KB of PNG per key is cheap, but not on the main thread.
        let sequence = (imageSequence[key] ?? 0) + 1
        imageSequence[key] = sequence
        Task.detached(priority: .userInitiated) { [weak self] in
            let decoded = Self.decodeImage(bitmap)
            await self?.finishImage(decoded, key: key, sequence: sequence)
        }
    }

    private func finishImage(_ box: ImageBox, key: Int, sequence: Int) {
        // A newer state for this key may have been requested while this one was decoding.
        guard imageSequence[key] == sequence, let image = box.image else { return }
        images[key] = image
        edges[key] = box.edges
    }

    // MARK: - Keep-alive and recovery

    private func startKeepAlive() {
        keepAlive?.cancel()
        keepAlive = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled, let connection = self.connection else { return }
                self.send("PING", on: connection)
                if ContinuousClock.now - self.lastReceived > .seconds(8) {
                    self.connectionLost("Lost contact with Companion.")
                    return
                }
            }
        }
    }

    private func connectionLost(_ message: String) {
        tearDownConnection()
        guard running else { return }
        state = .failed(message)
        attempt += 1
        let delay = min(Double(attempt), 5)
        reconnect?.cancel()
        reconnect = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, self.running else { return }
            self.open()
        }
    }

    private func tearDownConnection() {
        keepAlive?.cancel()
        let old = connection
        connection = nil
        heldKeys.removeAll()
        old?.stateUpdateHandler = nil
        old?.cancel()
    }

    private func send(_ line: String, on connection: NWConnection) {
        connection.send(content: Data((line + "\n").utf8), completion: .contentProcessed { _ in })
    }

    // MARK: - Reachability check (Settings)

    /// True when something answers like Companion's Satellite API on this address.
    nonisolated static func probe(host: String, port: Int) async -> Bool {
        guard !host.isEmpty, let portValue = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else { return false }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: portValue, using: .tcp)
        let gate = ResumeOnce()
        return await withCheckedContinuation { continuation in
            @Sendable func finish(_ result: Bool) {
                guard gate.claim() else { return }
                connection.cancel()
                continuation.resume(returning: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // Companion greets every client with a BEGIN line.
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                        let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                        finish(text.hasPrefix("BEGIN"))
                    }
                case .failed, .waiting:
                    finish(false)
                default:
                    break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 4) { finish(false) }
        }
    }

    // MARK: - Parsing and decoding

    private final class ResumeOnce: @unchecked Sendable {
        private let lock = NSLock()
        private var claimed = false
        func claim() -> Bool {
            lock.lock(); defer { lock.unlock() }
            if claimed { return false }
            claimed = true
            return true
        }
    }

    struct EdgeColors: @unchecked Sendable {
        let top: CGColor
        let bottom: CGColor
    }

    struct ImageBox: @unchecked Sendable {
        let image: CGImage?
        var edges: EdgeColors? = nil
    }

    /// Fraction of a key picture taken up by Companion's location strip.
    nonisolated static let locationStripFraction = 0.2

    /// Average colour of the picture's first row below the strip and of its last row.
    nonisolated static func edgeColors(of image: CGImage) -> EdgeColors? {
        let cut = Int((Double(image.height) * locationStripFraction).rounded(.up))
        guard cut < image.height - 1, let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        func average(row: Int) -> CGColor? {
            guard let strip = image.cropping(to: CGRect(x: 0, y: row, width: image.width, height: 1)) else { return nil }
            var pixel = [UInt8](repeating: 0, count: 4)
            let drawn: Bool = pixel.withUnsafeMutableBytes { buffer in
                guard let context = CGContext(
                    data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                    space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return false }
                context.interpolationQuality = .medium
                context.draw(strip, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                return true
            }
            guard drawn else { return nil }
            return CGColor(colorSpace: srgb, components: [CGFloat(pixel[0]) / 255, CGFloat(pixel[1]) / 255, CGFloat(pixel[2]) / 255, 1])
        }
        guard let top = average(row: cut), let bottom = average(row: image.height - 1) else { return nil }
        return EdgeColors(top: top, bottom: bottom)
    }

    /// `COMMAND KEY=value KEY="quoted value"` → (command, parameters). Written by hand rather than
    /// with a regular expression because key images arrive as one multi-hundred-KB value.
    nonisolated static func parse(_ bytes: [UInt8]) -> (String, [String: String]) {
        let count = bytes.count
        var index = 0
        while index < count, bytes[index] != 0x20 { index += 1 }
        let command = String(decoding: bytes[0..<index], as: UTF8.self)
        var params: [String: String] = [:]

        while index < count {
            while index < count, bytes[index] == 0x20 { index += 1 }
            let keyStart = index
            while index < count, bytes[index] != 0x3D, bytes[index] != 0x20 { index += 1 }
            let key = String(decoding: bytes[keyStart..<index], as: UTF8.self)
            guard index < count, bytes[index] == 0x3D else {
                if !key.isEmpty { params[key] = "" }
                continue
            }
            index += 1 // '='
            if index < count, bytes[index] == 0x22 {
                index += 1
                var value: [UInt8] = []
                while index < count {
                    let byte = bytes[index]
                    if byte == 0x5C, index + 1 < count { value.append(bytes[index + 1]); index += 2; continue }
                    if byte == 0x22 { index += 1; break }
                    value.append(byte)
                    index += 1
                }
                params[key] = String(decoding: value, as: UTF8.self)
            } else {
                let valueStart = index
                while index < count, bytes[index] != 0x20 { index += 1 }
                params[key] = String(decoding: bytes[valueStart..<index], as: UTF8.self)
            }
        }
        return (command, params)
    }

    /// Accepts a `data:image/...;base64,` URI (what `BITMAP_FORMAT=png` produces) or, for older
    /// Companion versions that ignore that option, plain base64 raw RGB.
    nonisolated static func decodeImage(_ value: String) -> ImageBox {
        if value.hasPrefix("data:"), let comma = value.firstIndex(of: ",") {
            let payload = value[value.index(after: comma)...]
            guard let data = Data(base64Encoded: String(payload)),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return ImageBox(image: nil) }
            return ImageBox(image: image, edges: edgeColors(of: image))
        }
        guard let data = Data(base64Encoded: value), data.count >= 3 else { return ImageBox(image: nil) }
        let side = Int((Double(data.count) / 3).squareRoot())
        guard side > 0, side * side * 3 == data.count, let provider = CGDataProvider(data: data as CFData) else { return ImageBox(image: nil) }
        let image = CGImage(
            width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: side * 3,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
        return ImageBox(image: image, edges: image.flatMap(edgeColors(of:)))
    }
}
