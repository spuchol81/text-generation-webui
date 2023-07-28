FROM nvidia/cuda:11.8.0-devel-ubuntu22.04 as builder

RUN apt-get update && \
    apt-get install --no-install-recommends -y git vim build-essential python3-dev python3-venv && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/oobabooga/GPTQ-for-LLaMa /build

WORKDIR /build

RUN python3 -m venv /build/venv
RUN . /build/venv/bin/activate && \
    pip3 install --upgrade pip setuptools wheel && \
    pip3 install torch torchvision torchaudio && \
    pip3 install -r requirements.txt


FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="Docker image for GPTQ-for-LLaMa and Text Generation WebUI"

RUN apt-get update && \
    apt-get install --no-install-recommends -y python3-dev libportaudio2 libasound-dev git python3 python3-pip make g++ && \
    rm -rf /var/lib/apt/lists/*

RUN --mount=type=cache,target=/root/.cache/pip pip3 install virtualenv
RUN mkdir /app

WORKDIR /app
ARG WEBUI_VERSION
RUN test -n "${WEBUI_VERSION}" && git reset --hard ${WEBUI_VERSION} || echo "Using provided webui source"

RUN virtualenv /app/venv
RUN . /app/venv/bin/activate && \
    pip3 install --upgrade pip setuptools wheel && \
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

COPY extensions/api/requirements.txt /app/extensions/api/requirements.txt
COPY extensions/elevenlabs_tts/requirements.txt /app/extensions/elevenlabs_tts/requirements.txt
COPY extensions/google_translate/requirements.txt /app/extensions/google_translate/requirements.txt
COPY extensions/silero_tts/requirements.txt /app/extensions/silero_tts/requirements.txt
COPY extensions/whisper_stt/requirements.txt /app/extensions/whisper_stt/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip . /app/venv/bin/activate && cd extensions/api && pip3 install -r requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip . /app/venv/bin/activate && cd extensions/elevenlabs_tts && pip3 install -r requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip . /app/venv/bin/activate && cd extensions/google_translate && pip3 install -r requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip . /app/venv/bin/activate && cd extensions/silero_tts && pip3 install -r requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip . /app/venv/bin/activate && cd extensions/whisper_stt && pip3 install -r requirements.txt

COPY requirements.txt /app/requirements.txt
RUN . /app/venv/bin/activate && \
    pip3 install -r requirements.txt

RUN ls -al
RUN python download-model.py ozcur/alpaca-native-4bit 
COPY . /app/
ENV CLI_ARGS="--model alpaca-native-4bit --wbits 4 --groupsize 128"
CMD . /app/venv/bin/activate && python3 server.py ${CLI_ARGS}
