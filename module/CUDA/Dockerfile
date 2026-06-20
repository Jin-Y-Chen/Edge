# CUDA / GPU workload. Health check by default; set RUN_LLM=1 for llama-server.
ARG L4T_TAG=r36.4.0
FROM dustynv/l4t-pytorch:${L4T_TAG}

WORKDIR /app

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY src/ ./src/

ENV CUDA_PORT=8080
ENV RUN_LLM=0

CMD ["python3", "-m", "src.main"]
