# Claude Code Isolated Container
# Optimized for Claude Sonnet 4.5 with full isolation
FROM node:22-alpine

# Metadata
LABEL maintainer="AI Assistant Team"
LABEL version="3.1.0"
LABEL description="Claude Code isolated container"
LABEL ai.assistant.mode="claude"
LABEL ai.assistant.isolation="full"

# Security hardening
RUN addgroup -g 1001 -S claude && \
    adduser -S claude -u 1001 -G claude

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

# Claude Code CLI installation
RUN npm install -g @anthropic-ai/claude-code@latest --no-audit

# Create directories with proper permissions
RUN mkdir -p /home/claude/.claude-config \
             /home/claude/.claude \
             /home/claude/.ssh \
             /home/claude/.config \
             /home/claude/workspace && \
    chown -R claude:claude /home/claude

# Working directory
WORKDIR /home/claude/workspace

# Environment variables for Claude
ENV CLAUDE_CONFIG_DIR="/home/claude/.claude-config"
ENV CLAUDE_MODEL="claude-3-5-sonnet-20241022"
ENV CLAUDE_MAX_TOKENS=4096
ENV AI_MODE="claude"
ENV AI_PROVIDER="claude"
ENV CONTAINER_MODE="isolated"

# SSH setup for Claude
RUN mkdir -p /home/claude/.ssh && \
    chmod 700 /home/claude/.ssh && \
    chown claude:claude /home/claude/.ssh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "console.log('Claude Code container healthy')" || exit 1

# Copy entrypoint
COPY containers/claude/entrypoint.sh /usr/local/bin/claude-entrypoint.sh
RUN chmod +x /usr/local/bin/claude-entrypoint.sh

# Switch to non-root user
USER claude

# Expose workspace volume
VOLUME ["/home/claude/.claude-config", "/home/claude/workspace"]

ENTRYPOINT ["/usr/local/bin/claude-entrypoint.sh"]