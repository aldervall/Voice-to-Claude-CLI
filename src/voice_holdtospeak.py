#!/usr/bin/env python3
"""
Hold-to-Speak Voice Input Daemon
Monitors F12 key - hold to record, release to transcribe and type
Cross-platform support for Wayland and X11, multiple desktop environments
"""
import sys
import os
import subprocess
import threading
import queue
import time
import numpy as np
import sounddevice as sd
import scipy.io.wavfile as wav
import tempfile
import requests
from .voice_type import VoiceTranscriber, SAMPLE_RATE, WHISPER_URL
from .platform_detect import get_platform_info
from .config import load_config, get_trigger_key_code, get_trigger_key_name, get_config_path
import evdev
from evdev import ecodes

# Load configuration from ~/.config/voicetype/config.toml
_config = load_config()

# Configuration - loaded from config file with fallback defaults
TRIGGER_KEY = get_trigger_key_code(_config)
TRIGGER_KEY_NAME = get_trigger_key_name(_config)
MIN_RECORDING_DURATION = _config["daemon"]["min_duration"]
BEEP_ENABLED = _config["audio"]["beep_enabled"]

# Audio feedback options - choose one:
# Option 1: Use WAV files (set BEEP_USE_WAV_FILES = True)
BEEP_USE_WAV_FILES = _config["audio"]["beep_use_wav_files"]

def _find_sound_file(filename):
    """Find sound file in multiple possible locations (dev and AUR package)"""
    candidates = [
        os.path.join(os.path.dirname(__file__), '..', 'sounds', filename),  # Dev: src/../sounds/
        os.path.join(os.path.dirname(__file__), 'sounds', filename),        # AUR: /usr/lib/voicetype/sounds/
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return candidates[0]  # Fallback to first path

BEEP_START_SOUND = _find_sound_file('start.wav')
BEEP_STOP_SOUND = None  # None = use frequency tone for stop beep

# Option 2: Use frequency tones (set BEEP_USE_WAV_FILES = False)
BEEP_START_FREQUENCY = _config["audio"]["start_frequency"]
BEEP_STOP_FREQUENCY = _config["audio"]["stop_frequency"]
BEEP_DURATION = _config["audio"]["beep_duration"]

CLIPBOARD_PASTE_DELAY = _config["output"]["clipboard_paste_delay"]
NOTIFICATION_PREVIEW_LENGTH = _config["output"]["notification_preview_length"]
NOTIFICATION_TIMEOUT = _config["output"]["notification_timeout"]

# Audio level meter configuration
SHOW_AUDIO_METER = _config["ui"]["show_audio_meter"]
METER_WIDTH = _config["ui"]["meter_width"]
METER_UPDATE_RATE = _config["ui"]["meter_update_rate"]


class StreamingRecorder:
    """Records audio with dynamic start/stop capability"""

    def __init__(self):
        self.audio_queue = queue.Queue()
        self.stream = None
        self.is_recording = False
        self.start_time = None
        self.current_level = 0.0  # Current audio level (0-1)

    def start(self):
        """Start recording audio"""
        if self.is_recording:
            return

        # Clear any old data
        while not self.audio_queue.empty():
            self.audio_queue.get()

        self.is_recording = True
        self.start_time = time.time()

        # Start audio input stream
        self.stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype='int16',
            callback=self._audio_callback
        )
        self.stream.start()

    def stop(self):
        """Stop recording and return audio data"""
        if not self.is_recording:
            return None

        self.is_recording = False

        # Stop stream
        if self.stream:
            self.stream.stop()
            self.stream.close()
            self.stream = None

        # Calculate duration
        duration = time.time() - self.start_time if self.start_time else 0

        # Check minimum duration
        if duration < MIN_RECORDING_DURATION:
            print(f"Recording too short ({duration:.2f}s), ignoring...")
            return None

        # Collect all audio chunks
        audio_chunks = []
        while not self.audio_queue.empty():
            audio_chunks.append(self.audio_queue.get())

        if not audio_chunks:
            return None

        # Concatenate all chunks
        audio_data = np.concatenate(audio_chunks, axis=0)
        return audio_data

    def _audio_callback(self, indata, frames, time_info, status):
        """Callback function for audio stream"""
        if status:
            print(f"Audio status: {status}", file=sys.stderr)
        if self.is_recording:
            self.audio_queue.put(indata.copy())
            # Calculate RMS level for audio meter
            rms = np.sqrt(np.mean(indata.astype(np.float32) ** 2))
            # Normalize to 0-1 range (int16 max is 32767)
            self.current_level = min(1.0, rms / 8000)  # Adjusted for typical speech levels

    def get_elapsed_time(self):
        """Get elapsed recording time in seconds"""
        if self.start_time:
            return time.time() - self.start_time
        return 0.0


class HoldToSpeakDaemon:
    """Main daemon class for hold-to-speak functionality"""

    def __init__(self):
        # Don't initialize transcriber yet - will do it after ensuring server is running
        self.transcriber = None
        self.recorder = StreamingRecorder()
        self.keyboard_devices = []
        self.notification_id = None  # Track notification for in-place updates
        self.platform = get_platform_info()  # Detect platform and available tools
        self._meter_thread = None  # Audio meter display thread
        self._stop_meter = False  # Flag to stop meter thread

    def _display_audio_meter(self):
        """Display real-time audio level meter in terminal"""
        while not self._stop_meter and self.recorder.is_recording:
            level = self.recorder.current_level
            elapsed = self.recorder.get_elapsed_time()

            # Build the meter bar
            filled = int(level * METER_WIDTH)
            empty = METER_WIDTH - filled
            bar = '█' * filled + '░' * empty

            # Format elapsed time
            time_str = f"{elapsed:.1f}s"

            # Print meter with carriage return (overwrite line)
            sys.stdout.write(f"\r🎤 Recording... {bar} [{time_str}]  ")
            sys.stdout.flush()

            time.sleep(1.0 / METER_UPDATE_RATE)

        # Clear the meter line when done
        sys.stdout.write("\r" + " " * 60 + "\r")
        sys.stdout.flush()

    def _start_audio_meter(self):
        """Start the audio meter display thread"""
        if not SHOW_AUDIO_METER:
            return
        self._stop_meter = False
        self._meter_thread = threading.Thread(target=self._display_audio_meter, daemon=True)
        self._meter_thread.start()

    def _stop_audio_meter(self):
        """Stop the audio meter display thread"""
        self._stop_meter = True
        if self._meter_thread:
            self._meter_thread.join(timeout=0.5)
            self._meter_thread = None

    def ensure_whisper_server(self):
        """
        Ensure whisper.cpp server is running.
        If not, try to start it using local binary.
        Returns True if server is available, False otherwise.
        """
        # Check if server is already running
        try:
            response = requests.get(WHISPER_URL.replace('/v1/audio/transcriptions', '/health'), timeout=2)
            if response.status_code == 200:
                return True
        except (requests.ConnectionError, requests.Timeout):
            pass

        # Server not running, try to start it
        print("⚠ whisper server not running. Attempting to start local server...")

        # Try to use the start-server.sh script
        # Check multiple possible locations (dev and AUR package)
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.abspath(os.path.join(script_dir, '..'))

        start_script_candidates = [
            os.path.join(project_root, '.whisper/scripts/start-server.sh'),  # Dev
            os.path.join(script_dir, 'whisper/scripts/start-server.sh'),     # AUR: /usr/lib/voicetype/whisper/
        ]

        start_script = None
        for candidate in start_script_candidates:
            if os.path.exists(candidate):
                start_script = candidate
                break

        if start_script:
            try:
                # Run start script in background
                subprocess.Popen(['bash', start_script],
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE)

                # Wait for server to become available (up to 20 seconds)
                print("⏳ Waiting for whisper server to start...")
                for i in range(40):  # 40 attempts * 0.5s = 20 seconds max
                    try:
                        response = requests.get(WHISPER_URL.replace('/v1/audio/transcriptions', '/health'), timeout=1)
                        if response.status_code == 200:
                            print("✓ whisper server started successfully!")
                            return True
                    except (requests.ConnectionError, requests.Timeout):
                        time.sleep(0.5)

                print("✗ Server not responding after 20 seconds")
                return False

            except Exception as e:
                print(f"✗ Failed to start server: {e}")
                return False
        else:
            print(f"✗ Start script not found in any of these locations:")
            for candidate in start_script_candidates:
                print(f"   - {candidate}")
            return False

    def find_keyboard_devices(self):
        """Find all keyboard input devices with F12 key"""
        devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
        keyboard_devices = []

        # Look for keyboard devices
        for device in devices:
            capabilities = device.capabilities(verbose=False)
            # Check if device has keyboard keys (EV_KEY events)
            if ecodes.EV_KEY in capabilities:
                keys = capabilities[ecodes.EV_KEY]
                # Check if it has F12 key
                if TRIGGER_KEY in keys:
                    print(f"Found keyboard device: {device.name} ({device.path})")
                    keyboard_devices.append(device)

        return keyboard_devices

    def play_beep(self, sound_file: str = None, frequency: int = BEEP_START_FREQUENCY, duration: float = BEEP_DURATION):
        """Play a beep sound for feedback - either WAV file or frequency tone"""
        if not BEEP_ENABLED:
            return

        try:
            # Option 1: Play WAV file if using WAV files and file exists
            if BEEP_USE_WAV_FILES and sound_file and os.path.exists(sound_file):
                subprocess.run(['paplay', sound_file],
                              timeout=1,
                              check=False,
                              stderr=subprocess.DEVNULL)
            # Option 2: Generate frequency tone (fallback or when WAV files disabled)
            else:
                subprocess.run([
                    'paplay',
                    '--raw',
                    '--format=s16le',
                    '--rate=16000',
                    '--channels=1',
                    '/dev/stdin'
                ], input=self._generate_tone(frequency, duration, SAMPLE_RATE),
                   timeout=1,
                   check=False,
                   stderr=subprocess.DEVNULL)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            # Silently fail if paplay not available or file missing
            pass

    def _generate_tone(self, frequency, duration, sample_rate):
        """Generate a simple sine wave tone (fallback for when WAV files not used)"""
        samples = int(sample_rate * duration)
        t = np.linspace(0, duration, samples, False)
        tone = np.sin(2 * np.pi * frequency * t)
        # Convert to 16-bit PCM
        tone = (tone * 32767).astype(np.int16)
        return tone.tobytes()

    def show_notification(self, title: str, message: str, icon: str = 'dialog-information', timeout: int = NOTIFICATION_TIMEOUT):
        """Show or update desktop notification"""
        try:
            cmd = ['notify-send', '-i', icon, '-t', str(timeout), title, message]

            if self.notification_id:
                # Replace existing notification
                cmd.insert(1, '--replace-id')
                cmd.insert(2, self.notification_id)
            else:
                # Get notification ID for future updates
                cmd.insert(1, '--print-id')

            result = subprocess.run(cmd, capture_output=True, text=True,
                                   timeout=2, check=False)

            # Store notification ID if this is the first notification
            if not self.notification_id and result.stdout:
                self.notification_id = result.stdout.strip()

        except Exception:
            # Silently fail - notifications are nice-to-have
            pass

    def type_text_via_clipboard(self, text):
        """Copy text to clipboard and automatically paste with keyboard shortcut"""
        if not text:
            return False

        # Copy to clipboard using platform-appropriate tool
        if not self.platform.copy_to_clipboard(text):
            print("✗ Error: No clipboard tool available")
            print("\nPlease install required tools:")
            print(self.platform.get_install_instructions())
            return False

        # Increased delay to ensure clipboard is ready
        time.sleep(CLIPBOARD_PASTE_DELAY)

        print(f"✓ Copied {len(text)} characters to clipboard")

        # Automatically paste using keyboard shortcut (Shift+Ctrl+V for terminals)
        if self.platform.simulate_paste_shortcut(use_shift=True):
            print("✓ Auto-pasted into active window")
            return True
        else:
            # Fallback: clipboard only (manual paste required)
            print("⚠ Auto-paste not available")
            print("📋 Text is in clipboard - paste manually with Shift+Ctrl+V (terminals) or Ctrl+V (GUI)")
            return True  # Still successful - text is in clipboard

    def handle_key_event(self, event):
        """Handle keyboard events (press/release)"""
        if event.code != TRIGGER_KEY:
            return

        if event.value == 1:  # Key pressed
            if not SHOW_AUDIO_METER:
                print(f"\n🎤 Recording... (hold {TRIGGER_KEY_NAME})")
            self.play_beep(sound_file=BEEP_START_SOUND, frequency=BEEP_START_FREQUENCY, duration=BEEP_DURATION)
            self.recorder.start()
            self._start_audio_meter()  # Start the visual meter
            # Show notification with long timeout (will be replaced when done)
            self.show_notification('Voice Input', 'Recording...',
                                 icon='audio-input-microphone', timeout=60000)

        elif event.value == 0:  # Key released
            self._stop_audio_meter()  # Stop the visual meter
            print("⏹️  Recording stopped")
            self.play_beep(sound_file=BEEP_STOP_SOUND, frequency=BEEP_STOP_FREQUENCY, duration=BEEP_DURATION)

            # Stop recording and get audio data
            audio_data = self.recorder.stop()

            if audio_data is not None:
                # Update notification to show transcribing status
                self.show_notification('Voice Input', 'Transcribing...',
                                     icon='view-refresh', timeout=30000)
                # Transcribe in background to avoid blocking key monitoring
                threading.Thread(
                    target=self._transcribe_and_type,
                    args=(audio_data,),
                    daemon=True
                ).start()
            else:
                print("No audio data recorded")
                self.show_notification('Voice Input', 'Recording too short',
                                     icon='dialog-warning', timeout=3000)

    def _transcribe_and_type(self, audio_data):
        """Transcribe audio and type the result"""
        try:
            print("🔄 Transcribing...")
            transcribed_text = self.transcriber.transcribe_audio(audio_data)

            if transcribed_text:
                print(f"📝 Transcription: {transcribed_text}")

                # Show preview in notification
                preview = transcribed_text[:NOTIFICATION_PREVIEW_LENGTH] + \
                         ('...' if len(transcribed_text) > NOTIFICATION_PREVIEW_LENGTH else '')
                self.show_notification('Voice Input', f'Ready: {preview}',
                                     icon='dialog-ok-apply', timeout=3000)

                self.type_text_via_clipboard(transcribed_text)
            else:
                print("✗ No speech detected")
                self.show_notification('Voice Input', 'No speech detected',
                                     icon='dialog-warning', timeout=3000)

        except Exception as e:
            print(f"✗ Error during transcription: {e}")
            self.show_notification('Voice Input', f'Error: {str(e)[:40]}',
                                 icon='dialog-error', timeout=NOTIFICATION_TIMEOUT)

    def run(self):
        """Main daemon loop"""
        print("="*60)
        print("Hold-to-Speak Voice Input Daemon")
        print("="*60)
        print(f"Platform: {self.platform.display_server.upper()}/{self.platform.desktop_env}")
        print(f"Clipboard: {self.platform.get_clipboard_tool() or 'None'}")
        print(f"Keyboard: {self.platform.get_keyboard_tool() or 'None'}")
        print(f"Trigger key: {TRIGGER_KEY_NAME}")
        print(f"Whisper server: {WHISPER_URL}")
        print(f"Minimum recording: {MIN_RECORDING_DURATION}s")
        print("="*60)

        # Ensure whisper server is running before starting daemon
        print("\nChecking whisper.cpp server...")
        if not self.ensure_whisper_server():
            print("\n✗ Error: whisper.cpp server is not available")
            print("\nPlease start the server manually:")
            print("  systemctl --user start whisper-server")
            print("  OR: bash .whisper/scripts/start-server.sh")
            print("  OR: bash install-whisper.sh")
            sys.exit(1)

        # Initialize transcriber now that server is running
        try:
            self.transcriber = VoiceTranscriber()
            print("✓ Connected to whisper.cpp server")
        except Exception as e:
            print(f"\n✗ Error connecting to whisper server: {e}")
            sys.exit(1)

        # Find keyboard devices
        print("\nSearching for keyboard devices...")
        self.keyboard_devices = self.find_keyboard_devices()

        if not self.keyboard_devices:
            print(f"✗ Error: Could not find any keyboard device with {TRIGGER_KEY_NAME} key")
            print("\nTroubleshooting:")
            print("1. Make sure you're in the 'input' group:")
            print("   sudo usermod -a -G input $USER")
            print("2. Log out and log back in for group changes to take effect")
            print("3. Check available devices:")
            print("   python3 -c 'import evdev; print([d for d in evdev.list_devices()])'")
            sys.exit(1)

        print(f"✓ Monitoring {len(self.keyboard_devices)} keyboard(s)")
        print(f"\n🎯 Ready! Hold {TRIGGER_KEY_NAME} to record, release to transcribe and type.")
        print(f"   Config: {get_config_path()}")
        print("Press Ctrl+C to stop daemon.\n")

        try:
            # Create a device map for select
            import select
            devices_map = {dev.fd: dev for dev in self.keyboard_devices}

            # Monitor keyboard events from all devices
            while True:
                r, w, x = select.select(devices_map, [], [])
                for fd in r:
                    device = devices_map[fd]
                    for event in device.read():
                        if event.type == ecodes.EV_KEY:
                            self.handle_key_event(event)

        except KeyboardInterrupt:
            print("\n\n✓ Daemon stopped")
            sys.exit(0)
        except Exception as e:
            print(f"\n✗ Error: {e}")
            sys.exit(1)


def main():
    """Entry point"""
    try:
        daemon = HoldToSpeakDaemon()
        daemon.run()
    except Exception as e:
        print(f"✗ Fatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
