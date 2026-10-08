# SuperMuseum Deck Launcher

A small installer that adds [Super Museum](https://supermuseum.netlify.app/) to your Steam Deck library as a non-Steam game, so you can launch it from Game Mode like any other title.

> **Disclaimer:** This project is not affiliated with, endorsed by, or connected to Super Museum. The game and website at [supermuseum.netlify.app](https://supermuseum.netlify.app/) belong to their creator, **livercake**. This repository only contains a launcher script that opens the public website in a browser window; it does not include, copy, or modify any of the game's content.

## Install

**[Download the installer (latest release)](https://github.com/segovia-no/SuperMuseum-Deck-Launcher/releases/latest/download/SuperMuseum-Installer.desktop)**

1. Switch to **Desktop Mode** (Steam button > Power > Switch to Desktop). Keep Steam running in the background.
2. Open the download link above in the Deck's browser. `SuperMuseum-Installer.desktop` is saved to your **Downloads** folder.
3. Open **Downloads** in Dolphin (the file manager) and double-click `SuperMuseum-Installer.desktop`.
   - If you are asked whether to trust or run the file, choose **Continue** / **Execute**.
   - If it opens in a text editor instead, right-click it > Properties > Permissions > tick **Is executable**, then double-click again.
4. Wait for the progress window to finish. Installing Chrome the first time can take a few minutes.
5. Confirm the "Add to Steam" prompt if Steam shows one.
6. Return to Game Mode. **Super Museum** is in your library under the **Non-Steam** tab.

All versions are listed on the [Releases page](https://github.com/segovia-no/SuperMuseum-Deck-Launcher/releases).

## What it does

1. Checks whether Google Chrome (Flatpak) is installed, and installs it from Flathub if not. Chrome is required because the site does not work in Firefox.
2. Creates a dedicated Chrome profile for the game, so its saves, cache and settings stay separate from your normal browsing.
3. Creates a launcher that opens the site in Chrome kiosk mode (fullscreen, no address bar or tabs).
4. Adds that launcher to Steam as **Super Museum**, so Steam shows "Super Museum" as the game you are playing instead of "Google Chrome".

A small progress window shows each step, followed by a success or error message. A log is written to `/tmp/supermuseum-deck-launcher.log`.

## Alternative: install from the terminal

If you prefer not to download the installer file, open **Konsole** in Desktop Mode and run:

```bash
curl -fsSL https://raw.githubusercontent.com/segovia-no/SuperMuseum-Deck-Launcher/main/install.sh | bash
```

## Recommended settings in Game Mode

- **Controls:** Super Museum is played with the Deck's built-in gamepad. No mouse or keyboard setup is needed. If the buttons do not respond, open the game's controller settings and select the **Gamepad** template.
- **Quitting:** kiosk mode has no close button. Press the **Steam** button and choose **Exit Game**.
- **Artwork:** Steam shows a generic image by default. Use the [SteamGridDB Decky plugin](https://github.com/SteamGridDB/decky-steamgriddb) or, in Desktop Mode, right-click the entry > Manage > Set custom artwork.

## Uninstall

Remove the launcher files and the game's Chrome profile (this also deletes any progress stored in that profile):

```bash
curl -fsSL https://raw.githubusercontent.com/segovia-no/SuperMuseum-Deck-Launcher/main/install.sh | bash -s -- --uninstall
```

Then remove the entry from Steam: select Super Museum in your library > Manage > Remove non-Steam game from your library. Chrome itself is left installed.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Game does not appear in Steam | Restart Steam, or add `~/.local/share/applications/SuperMuseum.desktop` manually via Games > Add a Non-Steam Game to My Library. |
| Double-clicking the installer opens a text editor | Right-click the file > Properties > Permissions > tick "Is executable", then double-click again. Or use the terminal alternative. |
| Page looks too small or too large | Edit `~/.local/share/applications/SuperMuseum.desktop` and add `--force-device-scale-factor=1.25` (or another value) to the `Exec=` line. |
| Something failed during install | Check `/tmp/supermuseum-deck-launcher.log`. |

## What gets installed where

| Item | Location |
| --- | --- |
| Google Chrome | Flatpak `com.google.Chrome` (user install) |
| Launcher | `~/.local/share/applications/SuperMuseum.desktop` |
| Chrome profile for the game | `~/.var/app/com.google.Chrome/config/webapps/SuperMuseum` |

## License

The launcher script is released under the [MIT License](LICENSE). This license covers only the files in this repository, not Super Museum itself.
