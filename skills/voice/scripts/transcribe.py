#!/usr/bin/env python3
"""
Voice Transcription Script for Claude Code Skill
Uses existing VoiceTranscriber class to record and transcribe audio
"""
import sys
import os
import json
import argparse

# Add project root to path to import voice_to_claude
# Script location: skills/voice/scripts/transcribe.py
# Project root: ../../.. from script location
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, '../../..'))
sys.path.insert(0, project_root)

try:
    from src.voice_to_claude import VoiceTranscriber
    import requests
    import subprocess
    import time
except ImportError as e:
    print(json.dumps({
        "error": f"Failed to import required modules: {e}",
        "help": "Make sure you're in the voice-to-claude-cli directory and venv is activated"
    }))
    sys.exit(1)


def check_installation():
    """
    Check if Voice-to-Claude-CLI is properly installed.
    Returns (is_installed, missing_components)
    """
    missing = []

    # Check for venv
    venv_path = os.path.join(project_root, 'venv')
    if not os.path.exists(venv_path):
        missing.append("Python venv")

    # Check for whisper binary
    whisper_bin = os.path.join(project_root, '.whisper/bin')
    if not os.path.exists(whisper_bin) or not os.listdir(whisper_bin):
        missing.append("whisper.cpp binary")

    # Check for whisper scripts
    start_script = os.path.join(project_root, '.whisper/scripts/start-server.sh')
    if not os.path.exists(start_script):
        missing.append("whisper helper scripts")

    return (len(missing) == 0, missing)


def ensure_whisper_server():
    """
    Ensure whisper.cpp server is running.
    If not, try to start it using local binary.
    Returns True if server is available, False otherwise.
    """
    # Check if server is already running
    try:
        response = requests.get("http://127.0.0.1:2022/health", timeout=2)
        if response.status_code == 200:
            return True
    except (requests.ConnectionError, requests.Timeout):
        pass

    # Server not running, try to start it
    print("whisper server not running. Attempting to start local server...", file=sys.stderr)

    # Try to use the start-server.sh script
    start_script = os.path.join(project_root, '.whisper/scripts/start-server.sh')

    if os.path.exists(start_script):
        try:
            # Run start script in background (don't wait for it to complete)
            # The script starts whisper-server as a background process
            subprocess.Popen(['bash', start_script],
                           stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)

            # Wait for server to become available (up to 15 seconds)
            print("Waiting for server to start...", file=sys.stderr)
            for i in range(30):  # 30 attempts * 0.5s = 15 seconds max
                try:
                    response = requests.get("http://127.0.0.1:2022/health", timeout=1)
                    if response.status_code == 200:
                        print("✓ whisper server started successfully!", file=sys.stderr)
                        return True
                except (requests.ConnectionError, requests.Timeout):
                    time.sleep(0.5)

            print("Warning: Server not responding after 15 seconds", file=sys.stderr)
            return False

        except Exception as e:
            print(f"Failed to start server: {str(e)}", file=sys.stderr)
            return False
    else:
        # No start script, provide instructions
        print(f"Start script not found: {start_script}", file=sys.stderr)
        return False


def main():
    """Record audio and transcribe using whisper.cpp"""
    parser = argparse.ArgumentParser(description='Record and transcribe voice input')
    parser.add_argument(
        '--duration',
        type=int,
        default=5,
        help='Recording duration in seconds (1-30, default: 5)'
    )
    args = parser.parse_args()

    # Validate duration
    if args.duration < 1 or args.duration > 30:
        print(json.dumps({
            "error": "Duration must be between 1 and 30 seconds"
        }))
        sys.exit(1)

    # Check if installation is complete
    is_installed, missing = check_installation()
    if not is_installed:
        print(json.dumps({
            "error": "Voice-to-Claude-CLI is not fully installed",
            "missing_components": missing,
            "installation_needed": True,
            "help": [
                "Run installation: bash install.sh",
                "Or use Claude command: /voice-install",
                f"Missing: {', '.join(missing)}"
            ]
        }))
        sys.exit(1)

    # Ensure whisper server is running
    if not ensure_whisper_server():
        print(json.dumps({
            "error": "whisper.cpp server is not available",
            "help": [
                "Start manually: systemctl --user start whisper-server",
                "Or use: bash .whisper/scripts/start-server.sh",
                "Or reinstall: bash install.sh"
            ]
        }))
        sys.exit(1)

    try:
        # Initialize transcriber (checks whisper.cpp server connection)
        transcriber = VoiceTranscriber()

        # Record audio
        print(f"Recording for {args.duration} seconds... Speak now!", file=sys.stderr)
        audio_data = transcriber.record_audio(duration=args.duration)
        print("Recording finished!", file=sys.stderr)

        # Transcribe audio (makes HTTP POST to whisper.cpp)
        print("Transcribing...", file=sys.stderr)
        transcribed_text = transcriber.transcribe_audio(audio_data)

        if not transcribed_text:
            print(json.dumps({
                "error": "No speech detected or transcription failed",
                "text": ""
            }))
            sys.exit(1)

        # Output JSON result
        print(json.dumps({
            "text": transcribed_text,
            "duration": args.duration
        }))

    except ConnectionError as e:
        print(json.dumps({
            "error": "whisper.cpp server is not running",
            "help": "Start server with: systemctl --user start whisper-server"
        }))
        sys.exit(1)
    except KeyboardInterrupt:
        print(json.dumps({
            "error": "Recording cancelled by user"
        }))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({
            "error": f"Transcription failed: {str(e)}"
        }))
        sys.exit(1)


if __name__ == "__main__":
    main()
