# BrowserPicker 🚀

BrowserPicker is a lightweight, native macOS application that intercepts clicked web links and allows you to choose which browser to open them in by simply typing a number key.

![BrowserPicker Screenshot](assets/screenshot.png)
![BrowserPicker Screenshot](assets/screenshotSettings.png)


## Features

- **Fast & Lightweight**: Built with Swift and SwiftUI.
- **Keyboard Centric**: Select your browser instantly using number keys (1, 2, 3, etc.).
- **Auto-Detection**: Automatically finds installed browsers like Safari, Chrome, Firefox, Brave, Arc, Edge, and more.
- **Works everywhere**: Works in any app that opens links.
- **Multiple Profiles for the same browser**: For example you can have multiple Chrome/Brave profiles and choose between them.
- **Privacy Focused**: No tracking, no data collection. Just a simple routing tool.

## Installation

### Prerequisites

- macOS 11.0 or later.
- Swift installed (default on macOS).

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/BrowserPicker.git
   cd BrowserPicker
   ```
2. Create the application bundle:
   ```bash
   mkdir -p BrowserPicker.app/Contents/MacOS
   mkdir -p BrowserPicker.app/Contents/Resources
   ```
3. Prepare the `Info.plist`:
   Use the `Info.plist.example` provided and rename it to `Info.plist` inside `BrowserPicker.app/Contents/`.
4. Compile the code:
   ```bash
   swiftc main.swift -o BrowserPicker.app/Contents/MacOS/BrowserPicker
   ```
5. Move to Applications:
   ```bash
   mv BrowserPicker.app /Applications/
   ```

## Setup

1. **Open the App**: Double-click `BrowserPicker.app` in your `/Applications` folder once to register it with macOS.
2. **Set as Default Browser**:
   - Go to **System Settings** > **Desktop & Dock**.
   - Find **Default web browser** and select **BrowserPicker**.

## Usage

Whenever you click a link in any app (Mail, Slack, Messages, etc.), BrowserPicker will pop up. Press the number corresponding to your desired browser, and the link will open immediately!

## License

MIT
