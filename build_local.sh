#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🔨 Building BrowserPicker..."

# Create necessary directories
mkdir -p BrowserPicker.app/Contents/MacOS
mkdir -p BrowserPicker.app/Contents/Resources

# Compile Swift code
echo "📝 Compiling Swift code..."
swiftc main.swift -o BrowserPicker.app/Contents/MacOS/BrowserPicker

# Create PkgInfo
echo -n "APPL????" > BrowserPicker.app/Contents/PkgInfo

# Copy Info.plist
cp Info.plist.example BrowserPicker.app/Contents/Info.plist

# Sign the app with an ad-hoc local signature
echo "🔐 Signing application..."
codesign --force --deep --sign - BrowserPicker.app

# Move to Applications
echo "📦 Installing to /Applications..."
rm -rf /Applications/BrowserPicker.app
cp -R BrowserPicker.app /Applications/

# Force macOS LaunchServices to recognize the new app
echo "🔄 Refreshing LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f /Applications/BrowserPicker.app

echo "✅ Done! BrowserPicker has been built and installed to your Applications folder."
