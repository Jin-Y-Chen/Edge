"""Capture loop: write frames to FRAME_OUTPUT (default /tmp/edge_frame.png)."""

import os
import time

import cv2

from .capture import capture_frame, device_ready


def main() -> None:
    device = os.environ.get("CAMERA_DEVICE", "/dev/video0")
    output = os.environ.get("FRAME_OUTPUT", "/tmp/edge_frame.png")
    interval = float(os.environ.get("CAPTURE_INTERVAL_SEC", "0"))

    if not device_ready(device):
        raise SystemExit(f"camera device missing: {device}")

    print(f"camera ready: {device} -> {output}")
    while True:
        frame = capture_frame(device)
        cv2.imwrite(output, frame)
        print(f"saved {output} ({frame.shape[1]}x{frame.shape[0]})")
        if interval <= 0:
            break
        time.sleep(interval)


if __name__ == "__main__":
    main()
