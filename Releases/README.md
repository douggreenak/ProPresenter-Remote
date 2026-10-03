# Pro Remote for Mac - ready-to-run app

`Pro-Remote-macOS.zip` is a built copy of the Mac app. You don't need Xcode to use it.

[`BUILD-INFO.txt`](BUILD-INFO.txt) records exactly what the zip was built from (commit, date, architectures, signing).

## Install

1. Download **`Pro-Remote-macOS.zip`** (on GitHub, open the file and click the download button).
2. Double-click the zip. It unpacks to **Pro Remote.app**.
3. Drag **Pro Remote.app** into your **Applications** folder (or anywhere you like - Downloads works too).
4. Open it. The first time, macOS will probably refuse - see the next section.

**Requires** macOS 26.4 or later. It runs on both Apple Silicon and Intel Macs.

## First launch: "Pro Remote can't be opened"

This build is signed with Bethel Church's Apple Developer certificate but is **not notarized** (notarization needs a
separate "Developer ID" certificate). macOS therefore blocks an app that came from a browser download until you approve
it once. Pick whichever is easier:

**Option A - Privacy & Security (no Terminal)**
1. Try to open Pro Remote once, then dismiss the warning.
2. Open **System Settings > Privacy & Security**.
3. Scroll down to the message about "Pro Remote" and click **Open Anyway**, then confirm.

**Option B - Terminal (one line)**

```
xattr -dr com.apple.quarantine "/Applications/Pro Remote.app"
```

(Change the path if you put the app somewhere else.) After either option the app opens normally from then on.

If you cloned this repository with `git` instead of downloading the zip in a browser, macOS never marks the app as
downloaded, so this step usually isn't needed.

## First connection

1. When asked to allow **local network access**, click **Allow** - Pro Remote cannot find ProPresenter without it.
2. Open **Settings** (the gear in the toolbar). ProPresenter appears under **Discovered on Network** - click it.
   Otherwise type its IP address and API port by hand.
3. Optional: in the **Bitfocus Companion** section, enter Companion's address to use the virtual Stream Deck.

See the [main README](../README.md) for everything else.

## Rebuilding

From the repository root:

```
Scripts/build-mac-app.sh
```

This archives a Release build, signs it with the Bethel Church team's development certificate, and rewrites
`Pro-Remote-macOS.zip` and `BUILD-INFO.txt` here. It does not change anything on the Apple Developer account.
Requires Xcode 26.4+ and the team's certificate in your keychain.

### Making it open without any warning

That needs notarization: a **Developer ID Application** certificate, then `notarytool` with an Apple ID app-specific
password. Neither exists on the build machine today, so builds are not notarized.
