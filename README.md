# BrowserPicker 🚀

BrowserPicker is a lightweight, native macOS application that intercepts clicked web links and allows you to choose which browser to open them in by simply typing a number key.

![BrowserPicker Screenshot](assets/screenshot.png)
![BrowserPicker Screenshot](assets/screenshotSettings.png)


## Features

- **Fast & Lightweight**: Built with Swift and SwiftUI.
- **Keyboard Centric**: Select your browser instantly using number keys (1, 2, 3, etc.).
- **Auto-Detection**: Automatically finds installed browsers like Safari, Chrome, Firefox, Brave, Arc, Edge, and more.
- **Browser Profiles**: Native support for Chromium browser profiles (Brave, Chrome, Edge, Vivaldi), allowing you to route links to specific profiles.
- **URL Rules & Auto-Routing**: Define rules to automatically open specific domains in a designated browser — no picker needed.
- **Remember Choice**: Hold Shift when selecting a browser to remember that choice for the current domain. Future links to that domain open automatically.
- **Default Browser Toggle**: Easily set BrowserPicker as your system default browser directly from the settings.
- **Customizable List**: Hide browsers you don't use and reorder them to match your preference.
- **Appearance Customization**: Choose between System, Light, or Dark theme. Pick from 6 accent colors. Save your preferred window position.
- **Privacy Focused**: No tracking, no data collection. Just a simple routing tool.

## Installation

### Prerequisites

- macOS 11.0 or later.
- Swift installed (default on macOS).

### Build & Install

The easiest way to build and install is to use the provided script:

```bash
./build_local.sh
```

This will compile the app, sign it locally, and move it to your `/Applications` folder.

## Setup

1. **Open the App**: Once installed, open BrowserPicker from your Applications folder.
2. **Set as Default Browser**:
   - Open BrowserPicker.
   - Click the gear icon or press **Cmd+,** to open **Settings**.
   - Click **"Set as Default"**. macOS will prompt you to confirm BrowserPicker as your default browser.

## Usage

Whenever you click a link in any app (Mail, Slack, Messages, etc.), BrowserPicker will pop up. Press the number corresponding to your desired browser, and the link will open immediately!

- **Number Keys (1-9)**: Quick-launch a browser.
- **Shift + Number / Shift + Click**: Pick a browser and remember that choice for the current domain.
- **Cmd+,**: Open settings.
- **Esc**: Close the picker without opening a link.
- **Drag & Drop**: In settings, reorder browsers to change their numeric shortcuts.

### URL Rules

Set up rules so links to specific domains skip the picker entirely:

1. Open Settings (gear icon or Cmd+,) and go to the **Rules** tab.
2. Enter a domain (e.g. `github.com`) and choose a browser.
3. Click **Add**. All future links to that domain (and its subdomains) will open in that browser automatically.

Rules can also be created on the fly by holding **Shift** when picking a browser — this saves a rule for the current link's domain.

### Appearance

Customize the look in the **Appearance** tab:

- **Theme**: System (follows macOS), Light, or Dark.
- **Accent Color**: Blue, Purple, Green, Orange, Red, or Pink — applied to number badges, buttons, and toggles.
- **Window Position**: Save the current position so the picker always appears where you want it.

## License

MIT
