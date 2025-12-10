#!/bin/bash
# Custom PDF viewer for Midnight Commander
# Converts PDF pages to images and displays them in kitty
# Usage: pdf-viewer.sh <pdf-file>

PDF_FILE="$1"

# How many pages to show (adjust as needed)
MAX_PAGES=5

# Resolution for conversion (lower = faster, higher = clearer)
# 150 is good for previews, 300 for better quality
DPI=150

if [ -z "$PDF_FILE" ]; then
    echo "Error: No PDF file specified"
    exit 1
fi

if [ ! -f "$PDF_FILE" ]; then
    echo "Error: File not found: $PDF_FILE"
    exit 1
fi

# Get total page count
if command -v pdfinfo >/dev/null 2>&1; then
    TOTAL_PAGES=$(pdfinfo "$PDF_FILE" 2>/dev/null | grep "Pages:" | awk '{print $2}')
else
    TOTAL_PAGES="unknown"
fi

echo "PDF: $(basename "$PDF_FILE")"
echo "Total pages: $TOTAL_PAGES"
echo "Showing first $MAX_PAGES pages at ${DPI} DPI"
echo ""

# Create temporary directory for PDF pages
TEMP_DIR="/tmp/mc_pdf_$$"
mkdir -p "$TEMP_DIR"

# Convert PDF pages to PNG
# pdftoppm -png -f <first_page> -l <last_page> -r <dpi> input.pdf output_prefix
if command -v pdftoppm >/dev/null 2>&1; then
    echo "Converting PDF pages..."
    pdftoppm -png -f 1 -l "$MAX_PAGES" -r "$DPI" "$PDF_FILE" "$TEMP_DIR/page" 2>/dev/null
elif command -v magick >/dev/null 2>&1; then
    echo "Converting PDF pages (using ImageMagick)..."
    # ImageMagick: convert first N pages
    magick -density "$DPI" "$PDF_FILE[0-$((MAX_PAGES-1))]" "$TEMP_DIR/page-%03d.png" 2>/dev/null
elif command -v convert >/dev/null 2>&1; then
    echo "Converting PDF pages (using convert)..."
    convert -density "$DPI" "$PDF_FILE[0-$((MAX_PAGES-1))]" "$TEMP_DIR/page-%03d.png" 2>/dev/null
else
    echo "Error: No PDF conversion tool found (tried pdftoppm, magick, convert)"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Display each page
PAGE_NUM=1
for img in "$TEMP_DIR"/*.png; do
    if [ -f "$img" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Page $PAGE_NUM"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        kitty +kitten icat --align left "$img"
        echo ""
        PAGE_NUM=$((PAGE_NUM + 1))
    fi
done

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
if [ "$TOTAL_PAGES" != "unknown" ] && [ "$TOTAL_PAGES" -gt "$MAX_PAGES" ]; then
    echo "Showing first $MAX_PAGES of $TOTAL_PAGES pages"
fi
echo "Press ENTER to continue..."
read dummy
