# External PSU monitor stub. Extend monitor.py for your I2C/serial hardware.
ARG L4T_TAG=r36.4.0
FROM dustynv/l4t-base:${L4T_TAG}

WORKDIR /app

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY src/ ./src/

ENV POLL_INTERVAL_SEC=5

CMD ["python3", "-m", "src.main"]
