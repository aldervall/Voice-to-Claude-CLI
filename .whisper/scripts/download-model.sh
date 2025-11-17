#!/usr/bin/env bash
# Download whisper model to .whisper/models/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="$SCRIPT_DIR/../models"
mkdir -p "$MODELS_DIR"

# Default to base.en if no argument provided
MODEL="${1:-base.en}"

echo "Downloading whisper model: $MODEL"
echo "Target directory: $MODELS_DIR"

# Download using whisper.cpp's download script
cd "$MODELS_DIR"

# Download the model with progress bar
echo "ℹ Downloading whisper model (~142 MB)"
echo "ℹ This may take 30-60 seconds depending on your connection..."
echo ""
curl --progress-bar -L -o "ggml-${MODEL}.bin" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${MODEL}.bin"
echo ""
echo "✓ Model downloaded: ggml-${MODEL}.bin"
ls -lh "$MODELS_DIR/ggml-${MODEL}.bin"
