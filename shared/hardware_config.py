"""Hardware configuration loader — single source of truth from hardware_specs.yaml.

Usage:
    from shared.hardware_config import hw
    print(hw["tank"]["chassis"]["length_mm"])  # 300
    print(hw.get_component("esp32_cam"))       # {"dimensions_mm": [40,27,12], ...}
"""

from pathlib import Path
from functools import lru_cache

import yaml


_CONFIG_PATH = Path(__file__).resolve().parent.parent / "config" / "hardware_specs.yaml"


class HardwareConfig(dict):
    """Dict subclass with attribute access and component lookup."""

    def __init__(self, data: dict):
        super().__init__(data)
        for key, value in data.items():
            if isinstance(value, dict):
                self[key] = HardwareConfig(value)

    def __getattr__(self, name):
        try:
            return self[name]
        except KeyError:
            raise AttributeError(f"No config key: {name}")

    def get_component(self, name: str) -> dict:
        """Lookup a component by name from the components section."""
        return self.get("components", {}).get(name, {})


@lru_cache(maxsize=1)
def load_hardware_config(path: str | Path | None = None) -> HardwareConfig:
    """Load and cache hardware_specs.yaml."""
    config_path = Path(path) if path else _CONFIG_PATH
    with open(config_path, "r", encoding="utf-8") as f:
        return HardwareConfig(yaml.safe_load(f))


# Convenience alias
hw = load_hardware_config()
