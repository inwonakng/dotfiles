#!/bin/bash
# Custom image viewer for Midnight Commander with HEIC support
# Usage: image-viewer.sh <image-file>

IMAGE_FILE="$1"

# Max dimension for preview (only downsamples if larger, never upsamples)
# The '>' in geometry means: only shrink larger images, preserve aspect ratio
MAX_DIMENSION="1280x1280>"

if [ -z "$IMAGE_FILE" ]; then
    echo "Error: No image file specified"
    exit 1
fi

# Function to display image with kitty
display_image() {
    local file="$1"
    kitty +kitten icat --align left "$file"
    echo ""
    echo "Press ENTER to continue..."
    read dummy
}

# Check if file is HEIC/HEIF format
if [[ "$IMAGE_FILE" =~ \.(heic|heif|HEIC|HEIF)$ ]]; then
    echo "Converting HEIC image..."

    # Create temporary file
    TEMP_FILE="/tmp/mc_image_$$.png"

    # Convert with downsampling for faster preview
    # The -resize with '>' only shrinks images larger than MAX_DIMENSION
    if command -v magick >/dev/null 2>&1; then
        magick "$IMAGE_FILE" -resize "$MAX_DIMENSION" "$TEMP_FILE" 2>/dev/null
    elif command -v convert >/dev/null 2>&1; then
        convert "$IMAGE_FILE" -resize "$MAX_DIMENSION" "$TEMP_FILE" 2>/dev/null
    elif command -v sips >/dev/null 2>&1; then
        # sips doesn't support the '>' notation, so we do it manually
        # First convert, then check if we need to resize
        sips -s format png "$IMAGE_FILE" --out "$TEMP_FILE" >/dev/null 2>&1
        if [ -f "$TEMP_FILE" ]; then
            # Get dimensions and resize only if larger than max
            WIDTH=$(sips -g pixelWidth "$TEMP_FILE" 2>/dev/null | tail -1 | awk '{print $2}')
            HEIGHT=$(sips -g pixelHeight "$TEMP_FILE" 2>/dev/null | tail -1 | awk '{print $2}')
            MAX_DIM=1280
            if [ "$WIDTH" -gt "$MAX_DIM" ] || [ "$HEIGHT" -gt "$MAX_DIM" ]; then
                sips -Z "$MAX_DIM" "$TEMP_FILE" >/dev/null 2>&1
            fi
        fi
    else
        echo "Error: No image conversion tool found (tried magick, convert, sips)"
        exit 1
    fi

    if [ -f "$TEMP_FILE" ]; then
        display_image "$TEMP_FILE"
        rm -f "$TEMP_FILE"
    else
        echo "Error: Failed to convert HEIC image"
        exit 1
    fi
else
    # Display regular image formats directly
    display_image "$IMAGE_FILE"
fi
