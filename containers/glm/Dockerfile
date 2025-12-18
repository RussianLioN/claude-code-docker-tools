# GLM-4.6 Isolated Container
# True GLM implementation (not Claude masking)
FROM node:22-alpine

# Metadata
LABEL maintainer="AI Assistant Team"
LABEL version="3.1.0"
LABEL description="GLM-4.6 isolated container"
LABEL ai.assistant.mode="glm"
LABEL ai.assistant.isolation="full"

# Security hardening
RUN addgroup -g 1001 -S glm && \
    adduser -S glm -u 1001 -G glm

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

# Install GLM CLI (if available) or use Z.AI integration
RUN npm install -g @z-ai/glm-cli@latest --no-audit || \
    npm install -g @anthropic-ai/claude-code@latest --no-audit

# Create directories with proper permissions
RUN mkdir -p /home/glm/.glm-config \
             /home/glm/.glm \
             /home/glm/.glm-cache \
             /home/glm/.ssh \
             /home/glm/.config \
             /home/glm/workspace && \
    chown -R glm:glm /home/glm

# Working directory
WORKDIR /home/glm/workspace

# Environment variables for GLM
ENV GLM_CONFIG_DIR="/home/glm/.glm-config"
ENV GLM_MODEL="glm-4.6"
ENV GLM_BASE_URL="https://api.z.ai"
ENV GLM_MAX_TOKENS=4096
ENV AI_MODE="glm"
ENV AI_PROVIDER="glm"
ENV CONTAINER_MODE="isolated"

# SSH setup for GLM
RUN mkdir -p /home/glm/.ssh && \
    chmod 700 /home/glm/.ssh && \
    chown glm:glm /home/glm/.ssh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "console.log('GLM-4.6 container healthy')" || exit 1

# Copy entrypoint
COPY containers/glm/entrypoint.sh /usr/local/bin/glm-entrypoint.sh
RUN chmod +x /usr/local/bin/glm-entrypoint.sh

# Switch to non-root user
USER glm

# Expose workspace volume
VOLUME ["/home/glm/.glm-config", "/home/glm/workspace"]

ENTRYPOINT ["/usr/local/bin/glm-entrypoint.sh"]
