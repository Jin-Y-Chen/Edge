"""V4L2 / OpenCV capture for IMX and compatible Jetson cameras."""

import os
import subprocess
from pathlib import Path

import cv2
import numpy as np


def device_ready(device: str) -> bool:
    return Path(device).exists()


def capture_opencv(device: str, width: int = 0, height: int = 0) -> np.ndarray:
    """Standard V4L2 capture via OpenCV (GMSL / USB / many IMX pipelines)."""
    cap = cv2.VideoCapture(device, cv2.CAP_V4L2)
    if not cap.isOpened():
        raise RuntimeError(f"cannot open {device}")

    if width:
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
    if height:
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)

    ok, frame = cap.read()
    cap.release()
    if not ok or frame is None:
        raise RuntimeError(f"read failed on {device}")
    return frame


def capture_bayer_raw(
    device: str,
    raw_path: str,
    height: int,
    width: int,
    black: int = 1729,
    white: int = 4740,
) -> np.ndarray:
    """10-bit Bayer via v4l2-ctl (ArduCAM / raw sensor path from jetson-config notes)."""
    subprocess.run(
        [
            "v4l2-ctl",
            "-d",
            device,
            "--stream-mmap",
            "--stream-count=1",
            f"--stream-to={raw_path}",
        ],
        check=True,
        capture_output=True,
    )
    raw = np.fromfile(raw_path, dtype=np.uint16).reshape(height, width)
    scaled = (
        np.clip(raw.astype("int32") - black, 0, white - black) * 255 // (white - black)
    ).astype("uint8")
    return cv2.cvtColor(scaled, cv2.COLOR_BayerGR2BGR)


def capture_frame(device: str | None = None) -> np.ndarray:
    device = device or os.environ.get("CAMERA_DEVICE", "/dev/video0")
    mode = os.environ.get("CAPTURE_MODE", "opencv").lower()

    if not device_ready(device):
        raise FileNotFoundError(f"{device} not found — install driver on host first")

    if mode == "bayer":
        return capture_bayer_raw(
            device,
            os.environ.get("RAW_PATH", "/tmp/frame.raw"),
            int(os.environ.get("FRAME_HEIGHT", "1200")),
            int(os.environ.get("FRAME_WIDTH", "1920")),
        )
    return capture_opencv(
        device,
        int(os.environ.get("FRAME_WIDTH", "0") or 0),
        int(os.environ.get("FRAME_HEIGHT", "0") or 0),
    )
