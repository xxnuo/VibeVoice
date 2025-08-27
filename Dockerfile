# FROM registry.lazycat.cloud/x/xtts:r36.3.0
FROM registry.lazycat.cloud/x/vllm:r36.4-cu128-24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV OMP_NUM_THREADS=12
ENV OMP_WAIT_POLICY=ACTIVE
ENV CUDA_VISIBLE_DEVICES=0

RUN apt-key adv --fetch-keys https://repo.download.nvidia.com/jetson/jetson-ota-public.asc
RUN echo "deb https://repo.download.nvidia.com/jetson/common r36.4 main" | tee -a /etc/apt/sources.list && \
    echo "deb https://repo.download.nvidia.com/jetson/t234 r36.4 main" | tee -a /etc/apt/sources.list && \
    echo "deb https://repo.download.nvidia.com/jetson/ffmpeg r36.4 main" | tee -a /etc/apt/sources.list

# Ubuntu 22.04 源
# RUN sed -i 's/ports.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list

# Ubuntu 24.04 源
RUN sed -i 's/ports.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/ubuntu.sources

# RUN apt-get update && apt-get install -y \
#     python3-libnvinfer-dev

# COPY models models
# ENV MODELSCOPE_CACHE=/app/

WORKDIR /app

COPY models /app/models

ENV HF_ENDPOINT=https://hf-mirror.com
ENV HF_HUB_OFFLINE=1

COPY vibevoice /app/vibevoice
COPY pyproject.toml /app/pyproject.toml

RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install -e .

COPY demo /app/demo

# 复制模型文件夹
# RUN mkdir -p /data/models/huggingface
# 特别坑，注意容器内设置了 TRANSFORMERS_CACHE 和 HF_HOME 都为 /data/models/huggingface
# 只会使用 TRANSFORMERS_CACHE
# 所以这里需要复制 hub 目录到 /data/models/huggingface 才行
# COPY models/hub/* /data/models/huggingface/

EXPOSE 7860

CMD ["python3", "demo/gradio_demo.py", "--model_path", "/app/models/WestZhang/VibeVoice-Large-pt", "--share"]