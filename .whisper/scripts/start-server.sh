#!/usr/bin/env bash
# Start whisper-server from .whisper/bin/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"
MODELS_DIR="$SCRIPT_DIR/../models"

# Detect architecture and find binary
ARCH=$(uname -m)
BINARY=""

# Check for architecture-specific binary first, then generic name (AUR package)
case "$ARCH" in
    x86_64)
        if [ -f "$BIN_DIR/whisper-server-linux-x64" ]; then
            BINARY="$BIN_DIR/whisper-server-linux-x64"
        elif [ -f "$BIN_DIR/whisper-server" ]; then
            BINARY="$BIN_DIR/whisper-server"
        fi
        ;;
    aarch64|arm64)
        if [ -f "$BIN_DIR/whisper-server-linux-arm64" ]; then
            BINARY="$BIN_DIR/whisper-server-linux-arm64"
        elif [ -f "$BIN_DIR/whisper-server" ]; then
            BINARY="$BIN_DIR/whisper-server"
        fi
        ;;
    *)
        echo "Error: Unsupported architecture: $ARCH"
        echo "Supported: x86_64, aarch64/arm64"
        exit 1
        ;;
esac

# Check if binary was found
if [ -z "$BINARY" ] || [ ! -f "$BINARY" ]; then
    echo "Error: whisper-server binary not found in: $BIN_DIR"
    echo "Run: bash .whisper/scripts/install-binary.sh to build from source"
    exit 1
fi

# Check if model exists
MODEL_FILE="$MODELS_DIR/ggml-base.en.bin"
if [ ! -f "$MODEL_FILE" ]; then
    echo "Model not found. Downloading base.en model..."
    bash "$SCRIPT_DIR/download-model.sh" base.en
fi

# Check if server is already running
if curl -s http://127.0.0.1:2022/health >/dev/null 2>&1; then
    echo "✓ whisper-server is already running"
    exit 0
fi

echo "Starting whisper-server..."
echo "Binary: $BINARY"
echo "Model: $MODEL_FILE"
echo "Endpoint: http://127.0.0.1:2022/v1/audio/transcriptions"

# Start server in background
"$BINARY" \
    --model "$MODEL_FILE" \
    --host 127.0.0.1 \
    --port 2022 \
    --inference-path "/v1/audio/transcriptions" \
    --threads 4 \
    --processors 1 \
    --convert \
    --print-progress &

# Wait for server to start
for i in {1..10}; do
    if curl -s http://127.0.0.1:2022/health >/dev/null 2>&1; then
        echo "✓ whisper-server started successfully"
        exit 0
    fi
    sleep 0.5
done

echo "Warning: Server may not have started. Check with: curl http://127.0.0.1:2022/health"
exit 1
