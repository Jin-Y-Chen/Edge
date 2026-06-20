"""Serial gimbal control stub for C-20T class mounts.

Replace command bytes with your gimbal protocol (SIYI, Gremsy, etc.).
"""

import os
import time
from dataclasses import dataclass

import serial


@dataclass
class GimbalConfig:
    port: str
    baud: int = 115200
    timeout: float = 1.0


class C20TGimbal:
    def __init__(self, config: GimbalConfig) -> None:
        self._ser = serial.Serial(
            config.port,
            baudrate=config.baud,
            timeout=config.timeout,
        )

    def close(self) -> None:
        self._ser.close()

    def _send(self, payload: bytes) -> None:
        self._ser.write(payload)
        self._ser.flush()

    def center(self) -> None:
        # Placeholder: replace with real C-20T center command
        self._send(b"\x55\xaa\x01\x00\x00\x00\x00\x00")

    def set_angles(self, yaw_deg: float, pitch_deg: float) -> None:
        # Placeholder: encode yaw/pitch per your protocol
        yaw = int(yaw_deg * 10) & 0xFFFF
        pitch = int(pitch_deg * 10) & 0xFFFF
        cmd = bytes([0x55, 0xAA, 0x02, yaw & 0xFF, (yaw >> 8) & 0xFF, pitch & 0xFF, (pitch >> 8) & 0xFF])
        self._send(cmd)
        time.sleep(0.05)


def from_env() -> C20TGimbal:
    return C20TGimbal(
        GimbalConfig(
            port=os.environ.get("GIMBAL_PORT", "/dev/ttyUSB0"),
            baud=int(os.environ.get("GIMBAL_BAUD", "115200")),
        )
    )
