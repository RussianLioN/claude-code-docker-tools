# Gemini CLI Isolated Container
# Optimized for Gemini 2.5-Pro with full isolation
FROM node:22-alpine

# Metadata
LABEL maintainer="AI Assistant Team"
LABEL version="3.1.0"
LABEL description="Gemini CLI isolated container"
LABEL ai.assistant.mode="gemini"
LABEL ai.assistant.isolation="full"

# Security hardening
RUN addgroup -g 1001 -S gemini && \
    adduser -S gemini -u 1001 -G gemini

# System packages
RUN apk add --no-cache \
    bash \
    coreutils \
    ncurses \
    git \
    python3 \
    make \
    g++ \
    openssh-client \
    github-cli \
    curl \
    wget \
    procps \
    htop

# Locale setup
ENV LANG=C.UTF-8
RUN echo "#!/bin/sh" > /usr/bin/locale && \
    echo "echo C.UTF-8" >> /usr/bin/locale && \
    chmod +x /usr/bin/locale

# Install Gemini CLI
RUN npm install -g @google/gemini-cli@latest --no-audit

# Create directories with proper permissions
RUN mkdir -p /home/gemini/.gemini \
             /home/gemini/.gemini-config \
             /home/gemini/.ssh \
             /home/gemini/.config \
             /home/gemini/workspace && \
    chown -R gemini:gemini /home/gemini

# Working directory
WORKDIR /home/gemini/workspace

# Environment variables for Gemini
ENV GEMINI_CONFIG_DIR="/home/gemini/.gemini-config"
ENV GEMINI_MODEL="gemini-2.5-pro"
ENV GEMINI_MAX_TOKENS=4096
ENV AI_MODE="gemini"
ENV AI_PROVIDER="gemini"
ENV CONTAINER_MODE="isolated"

# SSH setup for Gemini
RUN mkdir -p /home/gemini/.ssh && \
    chmod 700 /home/gemini/.ssh && \
    chown gemini:gemini /home/gemini/.ssh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "console.log('Gemini CLI container healthy')" || exit 1

# Copy entrypoint
COPY containers/gemini/entrypoint.sh /usr/local/bin/gemini-entrypoint.sh
RUN chmod +x /usr/local/bin/gemini-entrypoint.sh

# Switch to non-root user
USER gemini

# Expose workspace volume
VOLUME ["/home/gemini/.gemini-config", "/home/gemini/workspace"]

ENTRYPOINT ["/usr/local/bin/gemini-entrypoint.sh"]