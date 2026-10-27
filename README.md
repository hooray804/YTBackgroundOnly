# YTBackgroundOnly

A lightweight iOS tweak for YouTube that enables continuous background playback and bypasses the annoying "Video paused. Continue watching?" / "Are you there?" interruption dialogs.

[![Build Tweak](https://github.com/hooray804/YTBackgroundOnly/actions/workflows/build.yml/badge.svg)](https://github.com/hooray804/YTBackgroundOnly/actions/workflows/build.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/Platform-iOS-lightgrey.svg)

---

## Features

- **Background Audio Playback:** Listen to your favorite videos and music while using other apps or with your device locked.
- **Bypass "Video paused. Continue watching?" Prompts:** Prevents YouTube from pausing long playback sessions and asking if you are still watching.
- **Ultra Lightweight:** Pure Objective-C / Logos runtime hooks without complex UI overhead or unnecessary modifications.
- **Multiple Injection Support:** Compatible with Rootless Jailbreak, TrollStore, LiveContainer, SideStore, and Feather.

---

## Configuration & Settings

YTBackgroundOnly includes a native toggle directly inside YouTube's settings menu, allowing you to turn the tweak on or off at any time without needing third-party helper tweaks.

- **Location:** Open YouTube > Settings > **Tweaks** > **YTBackgroundOnly**
- **Master Toggle:** Enabling the switch activates background playback and disables interruption prompts. Disabling it instantly restores pure stock YouTube behavior without restarting the app.
- **Auto Localization:** The settings UI automatically adapts to your system language (supports both Korean and English).

---

## Installation

Due to GitHub upload policies, release binaries are packaged as individual `.zip` archives.  
Download the appropriate archive from [Releases](https://github.com/hooray804/YTBackgroundOnly/releases) and unzip it in the iOS Files app to extract the file.

| Archive | Contained File | Recommended For |
| :--- | :--- | :--- |
| **`YTBackgroundOnly.deb.zip`** | `.deb` | Rootless Jailbreak (Sileo/Zebra), Feather, TrollStore(via TrollFools) |
| **`YTBackgroundOnly.dylib.zip`** | `.dylib` | LiveContainer, IPA Dylib Injection (SideStore/Azule) |

### 1. Sideloading (Feather / Sideloadly)
1. Download and extract **`YTBackgroundOnly.deb.zip` (recommended)** or `YTBackgroundOnly.dylib.zip`.
2. Inject the extracted file into your decrypted YouTube `.ipa`.
3. Sign and install the patched IPA.

### 2. LiveContainer
1. Download and extract **`YTBackgroundOnly.dylib.zip`**.
2. Open LiveContainer, go to YouTube's settings, and add `YTBackgroundOnly.dylib` under Tweaks / Dynamic Libraries.

### 3. SideStore
1. Inject the extracted file using tools like Feather, Sideloadly, or Azule, then install with SideStore/Sideloadly.⁠

### 4. Rootless Jailbreak
1. Download and extract **`YTBackgroundOnly.deb.zip`**.
2. Share the extracted `.deb` to your package manager (Sileo, Zebra) and install.
3. Restart YouTube.

---

## Building from Source

### Prerequisites
- macOS or Linux with [Theos](https://theos.dev/) installed.
- iOS SDK (iOS 14.0 or higher recommended).

### Local Build

```bash
# Clone the repository
git clone https://github.com/hooray804/YTBackgroundOnly.git
cd YTBackgroundOnly

# Build Rootless .deb package
make clean package THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1

# Build standalone .dylib for sideloading
make clean && make FINALPACKAGE=1

```

The compiled binary will be located in `.theos/obj/` or `packages/`.

---

## Credits & Acknowledgments

* [YouMod](https://github.com/Tonwalter888/YouMod) for inspiration and reference.
* [Theos](https://theos.dev/) development team.

---

## License

This project uses GPLv3 license. See [LICENSE](LICENSE) for more details.
