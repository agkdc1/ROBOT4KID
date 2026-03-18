# Project Cradle — Universal Command Console

A modular, 3D-printable command console for controlling any ROBOT4KID robot via a standardized abstract protocol.

## Architecture

```
┌─────────────────────────────────────────────┐
│           7" DSI Touch Display              │
│           (Freenove, 800x480)               │
├────────┬──────────────┬─────────────────────┤
│ [LEFT] │   [BUTTONS]  │      [RIGHT]        │
│ Arcade │   2x2 diag   │   Flight Stick      │
│ 8-way  │   30mm each  │   + Trigger         │
│ Ball   │              │                     │
├────────┴──────────────┴─────────────────────┤
│  RPi4 + Heatsink │ Encoder │ Anker 10000    │
│  (DSI ribbon)    │ (USB)   │ (USB-C charge) │
└──────────────────┴─────────┴────────────────┘
```

## External Interfaces (ONLY these exposed)
1. iUniker power switch toggle
2. Anker USB-C charging port
3. RJ45 Ethernet (panel-mount extension)

## Hardware BOM
| Component | Product | Dimensions |
|-----------|---------|------------|
| RPi 4B + heatsink | - | 85x56x50mm (with 30mm heatsink) |
| 7" DSI Display | Freenove B0BPP6MFFJ | ~194x110x20mm + legs |
| Power Bank | Anker Slim 10000 B081YPQPXH | 149x68x14mm |
| Power Switch | iUniker USB-C | inline cable |
| Arcade Joystick | Hilitand Kit B07XM5C4PD | ~95mm mounting plate |
| Flight Stick | Totority B0CVNN9Y6N | microswitch base |
| Buttons | 4x 30mm from kit | 30mm snap-in |
| USB Encoder | Zero Delay (from kit) | ~95x35x10mm |

## Print Pieces (4-6 for Bambu A1 Mini 180x180x180mm)
1. Base Plate — power bank + RPi mount + encoder bay
2. Control Deck Left — arcade joystick mount
3. Control Deck Right — flight stick mount + buttons
4. Screen Bezel — display frame (uses display's own legs)
5. Rear Cover — ethernet panel mount + power switch slot
6. (Optional) Wire cover plate

## Software
- Flutter Linux app via GCS OTA
- RPi SoftAP for ESP32 connection
- Abstract JSON protocol (WebSocket + MJPEG)
