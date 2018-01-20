#!/bin/sh

# Clean up build directory
rm -rf ~/.build
mkdir ~/.build

# Build with Xcode
xcodebuild -workspace MediaSorter.xcworkspace -scheme "MediaSorter" -derivedDataPath ~/.build -configuration Release

# Copy app to current directory
ditto ~/.build/Build/Products/Release/MediaSorter.app ./MediaSorter.app

# Create Zip
zip --symlinks -r "MediaSorter$1.zip" "MediaSorter.app/"

# Copy to releases directory
ditto MediaSorter$1.zip ./Releases/

# Clean up
rm MediaSorter$1.zip
rm -rf MediaSorter.app
