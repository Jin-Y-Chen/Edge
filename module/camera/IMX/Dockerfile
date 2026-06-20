# IMX / V4L2 camera capture. Host must expose /dev/video* (driver + jetson-io on L4T).
ARG L4T_TAG=r36.4.0
FROM dustynv/l4t-ml:${L4T_TAG}

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends v4l-utils \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY src/ ./src/

ENV CAMERA_DEVICE=/dev/video0
ENV FRAME_OUTPUT=/tmp/edge_frame.png

CMD ["python3", "-m", "src.main"]
