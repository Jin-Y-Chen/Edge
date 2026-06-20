"""Power supply telemetry stub.

Board power mode (nvpmodel, jetson_clocks) stays on host: ~/Edge/max_power.
This module is for external PSU monitoring — wire read_metrics() to your hardware.
"""

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass
class PowerMetrics:
    voltage_v: float | None
    current_a: float | None
    source: str


def _read_sysfs_float(path: str, scale: float = 1.0) -> float | None:
    p = Path(path)
    if not p.is_file():
        return None
    try:
        return float(p.read_text().strip()) * scale
    except (OSError, ValueError):
        return None


def _read_i2c_stub(bus_path: str, address: int) -> PowerMetrics:
    try:
        from smbus2 import SMBus  # noqa: PLC0415
    except ImportError:
        return PowerMetrics(None, None, f"i2c:{bus_path} (smbus2 missing)")

    bus_num = int(bus_path.rsplit("-", 1)[-1])
    try:
        with SMBus(bus_num) as bus:
            # Placeholder registers — replace with your INA219 / fuel-gauge map
            raw_v = bus.read_word_data(address, 0x02)
            raw_i = bus.read_word_data(address, 0x03)
        return PowerMetrics(raw_v / 1000.0, raw_i / 1000.0, f"i2c:{bus_path}@{address:#x}")
    except OSError as exc:
        return PowerMetrics(None, None, f"i2c error: {exc}")


def read_metrics() -> PowerMetrics:
    i2c_bus = os.environ.get("I2C_BUS", "")
    i2c_addr = int(os.environ.get("I2C_ADDRESS", "0x40"), 0)

    if i2c_bus and Path(i2c_bus).exists():
        return _read_i2c_stub(i2c_bus, i2c_addr)

    # Fallback: Jetson hwmon input voltage if exposed (varies by carrier)
    voltage = _read_sysfs_float(
        os.environ.get("VOLTAGE_SYSFS", "/sys/class/hwmon/hwmon0/in1_input"),
        scale=0.001,
    )
    return PowerMetrics(voltage, None, "sysfs")
