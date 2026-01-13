#!/bin/bash

# Resize all AFL logos to 512x512 canvas with transparent background
# Requires ImageMagick:
#   macOS (Homebrew):   brew install imagemagick
#   Ubuntu/Debian:      sudo apt-get install imagemagick

INPUT_DIR="assets/logos"
OUTPUT_DIR="assets/logos_resized"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Loop over all PNG files (case-insensitive by converting via shell)
for file in "$INPUT_DIR"/*.[Pp][Nn][Gg]; do
  filename=$(basename "$file")
  echo "Processing $filename..."

  convert "$file" -resize 512x512 \
    -gravity center \
    -background none \
    -extent 512x512 \
    "$OUTPUT_DIR/$filename"
done

echo "Done! Resized logos saved to $OUTPUT_DIR"