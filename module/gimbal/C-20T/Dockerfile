# C-20T gimbal over serial. Pass --device /dev/ttyUSB0 (or your port).
ARG L4T_TAG=r36.4.0
FROM dustynv/l4t-base:${L4T_TAG}

WORKDIR /app

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY src/ ./src/

ENV GIMBAL_PORT=/dev/ttyUSB0
ENV GIMBAL_BAUD=115200

CMD ["python3", "-m", "src.main"]
