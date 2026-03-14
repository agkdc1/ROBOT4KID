"""Extended part specification enums and helpers."""

from enum import Enum


class PartCategory(str, Enum):
    CHASSIS = "chassis"
    TURRET = "turret"
    CONSOLE = "console"
    SLIP_RING = "slip_ring"
    TRACK = "track"


class FastenerType(str, Enum):
    M4_SCREW = "m4_screw"
    SNAP_FIT = "snap_fit"
    PRESS_FIT = "press_fit"
    BAYONET = "bayonet"
    ALIGNMENT_PIN = "alignment_pin"
