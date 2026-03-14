#!/usr/bin/env python3
"""
Train Console Controller — RPi4 + PS2 Joystick + MCP3008 ADC

Reads PS2 joystick via MCP3008 over SPI, sends TrainCommand packets
to ESP32-CAM via WebSocket, and displays MJPEG camera feed on the
7" touch screen using pygame.

Protocol: TrainCommand binary packet
  [0xAA] [type] [speed_hi] [speed_lo] [horn] [lights] [checksum]
  - header:   0xAA
  - type:     0x01 = speed, 0x02 = horn, 0x03 = lights
  - speed:    int16 signed (-100 to +100)
  - horn:     0x00 or 0x01
  - lights:   0x00 or 0x01
  - checksum: XOR of bytes 0..5
"""

import io
import os
import sys
import time
import struct
import signal
import logging
import threading
from typing import Optional
from urllib.request import urlopen
from urllib.error import URLError

import pygame

# Conditional imports for RPi hardware
try:
    import spidev
    HAS_SPI = True
except ImportError:
    HAS_SPI = False

try:
    import RPi.GPIO as GPIO
    HAS_GPIO = True
except ImportError:
    HAS_GPIO = False

try:
    import websocket
    HAS_WS = True
except ImportError:
    HAS_WS = False

# ==============================================================================
# Configuration
# ==============================================================================

ESP32_WS_URL = os.environ.get("ESP32_WS_URL", "ws://192.168.4.1:80/ws")
ESP32_STREAM_URL = os.environ.get("ESP32_STREAM_URL", "http://192.168.4.1:81/stream")

# MCP3008 SPI config
SPI_BUS = 0
SPI_DEVICE = 0
SPI_SPEED = 1000000  # 1 MHz

# Joystick ADC channels
JOY_X_CH = 0   # X axis
JOY_Y_CH = 1   # Y axis
JOY_BTN_CH = 2 # Button (analog threshold)

# Joystick calibration
JOY_CENTER = 512       # ADC midpoint
JOY_DEADZONE = 50      # Dead zone radius around center
JOY_MAX_SPEED = 100    # Max speed value

# Display
SCREEN_W = 800
SCREEN_H = 480
FPS = 30
BG_COLOR = (20, 20, 30)
STATUS_BAR_H = 40

# TrainCommand protocol
CMD_HEADER = 0xAA
CMD_TYPE_SPEED = 0x01
CMD_TYPE_HORN = 0x02
CMD_TYPE_LIGHTS = 0x03

# Reconnect
RECONNECT_DELAY = 3.0  # seconds
COMMAND_INTERVAL = 0.05  # 50ms between commands (20 Hz)

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("train_ctrl")


# ==============================================================================
# TrainCommand Packet Builder
# ==============================================================================

def build_command(cmd_type: int, speed: int = 0, horn: int = 0, lights: int = 0) -> bytes:
    """Build a TrainCommand binary packet with XOR checksum."""
    speed_clamped = max(-100, min(100, speed))
    speed_bytes = struct.pack(">h", speed_clamped)  # big-endian int16
    packet = bytes([
        CMD_HEADER,
        cmd_type,
        speed_bytes[0],
        speed_bytes[1],
        horn & 0x01,
        lights & 0x01,
    ])
    checksum = 0
    for b in packet:
        checksum ^= b
    return packet + bytes([checksum])


# ==============================================================================
# MCP3008 ADC Reader (SPI)
# ==============================================================================

class JoystickReader:
    """Reads PS2 joystick analog values via MCP3008 ADC over SPI."""

    def __init__(self):
        self.spi: Optional[spidev.SpiDev] = None
        self._init_spi()

    def _init_spi(self):
        if not HAS_SPI:
            log.warning("spidev not available — joystick will use keyboard fallback")
            return
        try:
            self.spi = spidev.SpiDev()
            self.spi.open(SPI_BUS, SPI_DEVICE)
            self.spi.max_speed_hz = SPI_SPEED
            self.spi.mode = 0
            log.info("SPI initialized (bus=%d, device=%d)", SPI_BUS, SPI_DEVICE)
        except Exception as e:
            log.warning("SPI init failed: %s — using keyboard fallback", e)
            self.spi = None

    def read_channel(self, channel: int) -> int:
        """Read a single MCP3008 channel (0-7). Returns 0-1023."""
        if self.spi is None:
            return JOY_CENTER  # Return center if no SPI
        cmd = [1, (8 + channel) << 4, 0]
        result = self.spi.xfer2(cmd)
        value = ((result[1] & 0x03) << 8) | result[2]
        return value

    def read_joystick(self) -> tuple[int, int, bool]:
        """Read X, Y axes and button. Returns (x, y, pressed)."""
        x = self.read_channel(JOY_X_CH)
        y = self.read_channel(JOY_Y_CH)
        btn_val = self.read_channel(JOY_BTN_CH)
        pressed = btn_val < 100  # Button pulls low when pressed
        return x, y, pressed

    def close(self):
        if self.spi:
            self.spi.close()
            self.spi = None


def adc_to_speed(value: int) -> int:
    """Map ADC value (0-1023) to speed (-100 to +100) with dead zone."""
    offset = value - JOY_CENTER
    if abs(offset) < JOY_DEADZONE:
        return 0
    # Map remaining range to -100..+100
    if offset > 0:
        max_range = 1023 - JOY_CENTER - JOY_DEADZONE
        normalized = (offset - JOY_DEADZONE) / max(max_range, 1)
    else:
        max_range = JOY_CENTER - JOY_DEADZONE
        normalized = (offset + JOY_DEADZONE) / max(max_range, 1)
    return int(max(-JOY_MAX_SPEED, min(JOY_MAX_SPEED, normalized * JOY_MAX_SPEED)))


# ==============================================================================
# WebSocket Connection Manager
# ==============================================================================

class WSConnection:
    """Manages WebSocket connection to ESP32 with auto-reconnect."""

    def __init__(self, url: str):
        self.url = url
        self.ws: Optional[websocket.WebSocket] = None
        self.connected = False
        self._lock = threading.Lock()

    def connect(self) -> bool:
        """Attempt WebSocket connection. Returns True on success."""
        if not HAS_WS:
            log.warning("websocket-client not available")
            return False
        with self._lock:
            try:
                self.ws = websocket.WebSocket()
                self.ws.settimeout(5)
                self.ws.connect(self.url)
                self.connected = True
                log.info("WebSocket connected: %s", self.url)
                return True
            except Exception as e:
                log.warning("WebSocket connect failed: %s", e)
                self.connected = False
                return False

    def send(self, data: bytes) -> bool:
        """Send binary data. Returns True on success."""
        with self._lock:
            if not self.connected or not self.ws:
                return False
            try:
                self.ws.send_binary(data)
                return True
            except Exception:
                self.connected = False
                return False

    def close(self):
        with self._lock:
            if self.ws:
                try:
                    self.ws.close()
                except Exception:
                    pass
            self.ws = None
            self.connected = False


# ==============================================================================
# MJPEG Stream Reader
# ==============================================================================

class MJPEGReader:
    """Reads MJPEG stream from ESP32-CAM and provides pygame surfaces."""

    def __init__(self, url: str):
        self.url = url
        self.frame: Optional[pygame.Surface] = None
        self._lock = threading.Lock()
        self._running = False
        self._thread: Optional[threading.Thread] = None

    def start(self):
        """Start background MJPEG reader thread."""
        self._running = True
        self._thread = threading.Thread(target=self._read_loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._running = False
        if self._thread:
            self._thread.join(timeout=3)

    def get_frame(self) -> Optional[pygame.Surface]:
        with self._lock:
            return self.frame

    def _read_loop(self):
        """Continuously read MJPEG frames from HTTP stream."""
        while self._running:
            try:
                stream = urlopen(self.url, timeout=5)
                buf = b""
                while self._running:
                    chunk = stream.read(4096)
                    if not chunk:
                        break
                    buf += chunk

                    # Find JPEG start/end markers
                    start = buf.find(b"\xff\xd8")
                    end = buf.find(b"\xff\xd9")
                    if start != -1 and end != -1 and end > start:
                        jpg_data = buf[start:end + 2]
                        buf = buf[end + 2:]

                        try:
                            img = pygame.image.load(io.BytesIO(jpg_data))
                            with self._lock:
                                self.frame = img
                        except Exception:
                            pass  # Skip corrupt frames

            except (URLError, OSError) as e:
                log.warning("MJPEG stream error: %s — retrying in %.1fs", e, RECONNECT_DELAY)
                time.sleep(RECONNECT_DELAY)
            except Exception as e:
                log.error("MJPEG unexpected error: %s", e)
                time.sleep(RECONNECT_DELAY)


# ==============================================================================
# Status Bar Renderer
# ==============================================================================

def draw_status_bar(screen: pygame.Surface, font: pygame.font.Font,
                    connected: bool, speed: int, horn: bool, lights: bool):
    """Draw status bar at bottom of screen."""
    bar_rect = pygame.Rect(0, SCREEN_H - STATUS_BAR_H, SCREEN_W, STATUS_BAR_H)
    pygame.draw.rect(screen, (30, 30, 40), bar_rect)
    pygame.draw.line(screen, (80, 80, 100), (0, SCREEN_H - STATUS_BAR_H),
                     (SCREEN_W, SCREEN_H - STATUS_BAR_H), 1)

    # Connection indicator
    dot_color = (0, 200, 0) if connected else (200, 0, 0)
    dot_label = "CONNECTED" if connected else "DISCONNECTED"
    pygame.draw.circle(screen, dot_color, (20, SCREEN_H - STATUS_BAR_H // 2), 6)
    txt = font.render(dot_label, True, dot_color)
    screen.blit(txt, (32, SCREEN_H - STATUS_BAR_H + 10))

    # Speed gauge
    speed_label = f"SPD: {speed:+4d}"
    speed_color = (200, 200, 200) if speed == 0 else (100, 255, 100) if speed > 0 else (255, 100, 100)
    txt = font.render(speed_label, True, speed_color)
    screen.blit(txt, (220, SCREEN_H - STATUS_BAR_H + 10))

    # Speed bar
    bar_x, bar_y = 340, SCREEN_H - STATUS_BAR_H + 8
    bar_w, bar_h = 200, 24
    pygame.draw.rect(screen, (60, 60, 60), (bar_x, bar_y, bar_w, bar_h))
    center_x = bar_x + bar_w // 2
    fill_w = int((abs(speed) / 100) * (bar_w // 2))
    if speed > 0:
        pygame.draw.rect(screen, (0, 180, 0), (center_x, bar_y + 2, fill_w, bar_h - 4))
    elif speed < 0:
        pygame.draw.rect(screen, (180, 0, 0), (center_x - fill_w, bar_y + 2, fill_w, bar_h - 4))
    pygame.draw.line(screen, (200, 200, 200), (center_x, bar_y), (center_x, bar_y + bar_h), 1)

    # Horn / Lights indicators
    horn_txt = font.render("HORN", True, (255, 255, 0) if horn else (80, 80, 80))
    screen.blit(horn_txt, (580, SCREEN_H - STATUS_BAR_H + 10))

    lights_txt = font.render("LIGHTS", True, (0, 200, 255) if lights else (80, 80, 80))
    screen.blit(lights_txt, (660, SCREEN_H - STATUS_BAR_H + 10))


# ==============================================================================
# Touch Controls
# ==============================================================================

class TouchController:
    """Fallback touch controls: tap top half = horn, swipe vertical = speed."""

    def __init__(self):
        self.speed = 0
        self.horn = False
        self._touch_start_y: Optional[int] = None

    def handle_event(self, event: pygame.event.Event) -> tuple[int, bool]:
        """Process touch/mouse events. Returns (speed_delta, horn_trigger)."""
        horn_trigger = False

        if event.type == pygame.MOUSEBUTTONDOWN:
            x, y = event.pos
            self._touch_start_y = y
            # Tap top half = horn
            if y < (SCREEN_H - STATUS_BAR_H) // 2:
                horn_trigger = True

        elif event.type == pygame.MOUSEMOTION and self._touch_start_y is not None:
            _, y = event.pos
            delta = self._touch_start_y - y  # Swipe up = positive
            self.speed = max(-100, min(100, int(delta * 0.5)))

        elif event.type == pygame.MOUSEBUTTONUP:
            self._touch_start_y = None
            self.speed = 0  # Release = stop

        return self.speed, horn_trigger


# ==============================================================================
# Main Controller
# ==============================================================================

class TrainController:
    """Main controller: ties together joystick, WebSocket, and display."""

    def __init__(self):
        self.running = True
        self.speed = 0
        self.horn = False
        self.lights = False

        self.joystick = JoystickReader()
        self.ws = WSConnection(ESP32_WS_URL)
        self.mjpeg = MJPEGReader(ESP32_STREAM_URL)
        self.touch = TouchController()

        self._last_cmd_time = 0.0

    def shutdown(self, *_):
        """Graceful shutdown handler."""
        log.info("Shutting down...")
        self.running = False

    def run(self):
        """Main loop."""
        signal.signal(signal.SIGINT, self.shutdown)
        signal.signal(signal.SIGTERM, self.shutdown)

        # Initialize pygame
        pygame.init()
        try:
            screen = pygame.display.set_mode((SCREEN_W, SCREEN_H),
                                             pygame.FULLSCREEN | pygame.HWSURFACE)
        except Exception:
            log.warning("Fullscreen failed, using windowed mode")
            screen = pygame.display.set_mode((SCREEN_W, SCREEN_H))
        pygame.display.set_caption("Train Console")
        pygame.mouse.set_visible(False)
        clock = pygame.time.Clock()
        font = pygame.font.SysFont("monospace", 16, bold=True)
        big_font = pygame.font.SysFont("monospace", 32, bold=True)

        # Start MJPEG reader
        self.mjpeg.start()

        # WebSocket connect (background retry)
        ws_thread = threading.Thread(target=self._ws_connect_loop, daemon=True)
        ws_thread.start()

        log.info("Train Controller started — press Q or ESC to quit")

        try:
            while self.running:
                # --- Event handling ---
                for event in pygame.event.get():
                    if event.type == pygame.QUIT:
                        self.running = False

                    elif event.type == pygame.KEYDOWN:
                        if event.key in (pygame.K_q, pygame.K_ESCAPE):
                            self.running = False
                        elif event.key == pygame.K_h:
                            self.horn = True
                        elif event.key == pygame.K_l:
                            self.lights = not self.lights

                    elif event.type == pygame.KEYUP:
                        if event.key == pygame.K_h:
                            self.horn = False

                    # Touch fallback
                    elif event.type in (pygame.MOUSEBUTTONDOWN, pygame.MOUSEMOTION,
                                        pygame.MOUSEBUTTONUP):
                        touch_speed, horn_trigger = self.touch.handle_event(event)
                        if self.joystick.spi is None:
                            self.speed = touch_speed
                        if horn_trigger:
                            self.horn = True

                # --- Keyboard speed control ---
                keys = pygame.key.get_pressed()
                if self.joystick.spi is None:
                    # Keyboard fallback only when no SPI joystick
                    if keys[pygame.K_UP]:
                        self.speed = min(self.speed + 5, JOY_MAX_SPEED)
                    elif keys[pygame.K_DOWN]:
                        self.speed = max(self.speed - 5, -JOY_MAX_SPEED)
                    else:
                        # Gradual deceleration when no key pressed (and no touch)
                        if self.touch._touch_start_y is None:
                            if self.speed > 0:
                                self.speed = max(0, self.speed - 3)
                            elif self.speed < 0:
                                self.speed = min(0, self.speed + 3)

                # --- Joystick reading (SPI) ---
                if self.joystick.spi is not None:
                    _, y_raw, btn_pressed = self.joystick.read_joystick()
                    self.speed = adc_to_speed(y_raw)
                    if btn_pressed:
                        self.horn = True

                # --- Send command at fixed rate ---
                now = time.monotonic()
                if now - self._last_cmd_time >= COMMAND_INTERVAL:
                    self._last_cmd_time = now
                    cmd = build_command(CMD_TYPE_SPEED, self.speed,
                                        int(self.horn), int(self.lights))
                    self.ws.send(cmd)

                # --- Render ---
                screen.fill(BG_COLOR)

                # Camera feed
                frame = self.mjpeg.get_frame()
                if frame is not None:
                    # Scale to fill screen (minus status bar)
                    view_h = SCREEN_H - STATUS_BAR_H
                    scaled = pygame.transform.scale(frame, (SCREEN_W, view_h))
                    screen.blit(scaled, (0, 0))
                else:
                    # No feed placeholder
                    txt = big_font.render("NO CAMERA FEED", True, (100, 100, 100))
                    rect = txt.get_rect(center=(SCREEN_W // 2,
                                                (SCREEN_H - STATUS_BAR_H) // 2))
                    screen.blit(txt, rect)

                    sub_txt = font.render(f"Connecting to {ESP32_STREAM_URL}...",
                                          True, (80, 80, 80))
                    sub_rect = sub_txt.get_rect(center=(SCREEN_W // 2,
                                                        (SCREEN_H - STATUS_BAR_H) // 2 + 40))
                    screen.blit(sub_txt, sub_rect)

                # Status bar
                draw_status_bar(screen, font, self.ws.connected,
                                self.speed, self.horn, self.lights)

                pygame.display.flip()
                clock.tick(FPS)

        finally:
            self._cleanup()

    def _ws_connect_loop(self):
        """Background thread: maintain WebSocket connection."""
        while self.running:
            if not self.ws.connected:
                self.ws.connect()
            time.sleep(RECONNECT_DELAY)

    def _cleanup(self):
        """Clean up resources."""
        log.info("Cleaning up...")
        self.mjpeg.stop()
        self.ws.close()
        self.joystick.close()
        if HAS_GPIO:
            GPIO.cleanup()
        pygame.quit()
        log.info("Shutdown complete.")


# ==============================================================================
# Entry point
# ==============================================================================

if __name__ == "__main__":
    controller = TrainController()
    controller.run()
