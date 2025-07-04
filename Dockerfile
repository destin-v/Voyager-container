#===================================================
# Docker for MineCraft Voyager.
# 
# Build:
# >>> podman build --format docker -t voyager .
#
# Run:
# ============
# Host:
# >>> podman run -it --rm --device nvidia.com/gpu=all --net=host --env="DISPLAY" --volume="$HOME/.Xauthority:/root/.Xauthority:rw" voyager bash
# 
# Inside container:
# >>> minecraft-launcher
#
# Description:
# ============
# [x] Add miniconda package manager
# [x] Add pipx package manager
# [x] Add vim awesome
# [x] Add nodeJS manager
# 
# References:
# ===========
# * https://ubuntu.com/tutorials/install-jre#2-installing-openjdk-jre
# * https://dzone.com/articles/docker-x11-client-via-ssh
# * https://datawookie.dev/blog/2023/12/minecraft-client-on-ubuntu/
#====================================================

FROM ubuntu:22.04

# Disable interaction
# Set ARG as this is only available during build
ARG DEBIAN_FRONTEND=noninteractive

# Common packages
RUN apt -y update &&\ 
    apt -y upgrade &&\
    apt -y install \
    build-essential \
    curl \
    default-jre \
    git \
    htop \
    libopengl0 \
    nodejs \
    pipx \
    unzip \
    wget \
    vim \
    x11-apps &&\
    apt -y clean

# Install pipx
RUN pipx ensurepath
RUN pipx install nvitop

WORKDIR /root

# replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# nvm environment variables
ENV NVM_DIR /root/.nvm
ENV NODE_VERSION 16.13.0

# install nvm
RUN mkdir -p /root/.nvm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# install node and npm
RUN source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# add node and npm to path so the commands are available
ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# confirm installation
RUN node -v
RUN npm -v

# Install Miniconda on x86 or ARM platforms
ENV PATH="/root/miniconda3/bin:${PATH}"
ARG PATH="/root/miniconda3/bin:${PATH}"
RUN arch=$(uname -m) && \
    if [ "$arch" = "x86_64" ]; then \
    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"; \
    elif [ "$arch" = "aarch64" ]; then \
    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"; \
    else \
    echo "Unsupported architecture: $arch"; \
    exit 1; \
    fi && \
    wget $MINICONDA_URL -O miniconda.sh && \
    mkdir -p /root/.conda && \
    bash miniconda.sh -b -p /root/miniconda3 && \
    rm -f miniconda.sh
RUN conda init
RUN conda --version

# To create a Conda environment.  Need --format docker in build.
RUN conda create -n myenv python=3.10
SHELL ["conda", "run", "-n", "myenv", "/bin/bash", "-c"]

# Copy Git repo
COPY ./ /root/Voyager/
WORKDIR /root/Voyager
RUN pip install -e .

WORKDIR /root/Voyager/voyager/env/mineflayer
RUN npm install --no-audit

# Install Typescript
WORKDIR /root/Voyager/voyager/env/mineflayer/mineflayer-collectblock
RUN npm install typescript --no-audit
RUN npx tsc

# Install Mineflayer
WORKDIR /root/Voyager/voyager/env/mineflayer
RUN npm install --no-audit

# Setup MineCraft client
WORKDIR /root/
RUN wget https://launcher.mojang.com/download/Minecraft.deb
RUN dpkg -i Minecraft.deb; exit 0
RUN apt --fix-broken install -y
RUN ls -alh
RUN dpkg -i Minecraft.deb

# Install Fabric
RUN curl -O https://maven.fabricmc.net/net/fabricmc/fabric-installer/0.11.2/fabric-installer-0.11.2.jar
RUN java -jar fabric-installer-0.11.2.jar
