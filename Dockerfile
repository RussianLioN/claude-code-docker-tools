FROM node:22-alpine

# Аргумент для управления версией при сборке
ARG GEMINI_VERSION=latest
ARG CLAUDE_VERSION=latest

# 1. Системные пакеты
RUN apk add --no-cache bash coreutils ncurses git python3 make g++ openssh-client github-cli curl wget

# 2. Фикс локали
ENV LANG=C.UTF-8
RUN echo "#!/bin/sh" > /usr/bin/locale && \
    echo "echo C.UTF-8" >> /usr/bin/locale && \
    chmod +x /usr/bin/locale

# 3. Создание удобных команд 'll', 'l'
RUN echo '#!/bin/bash' > /usr/local/bin/ll && \
    echo 'ls -lh --color=auto "$@"' >> /usr/local/bin/ll && \
    chmod +x /usr/local/bin/ll

RUN echo '#!/bin/bash' > /usr/local/bin/l && \
    echo 'ls -F --color=auto "$@"' >> /usr/local/bin/l && \
    chmod +x /usr/local/bin/l

# 4. Установка Gemini CLI
RUN npm install -g @google/gemini-cli@${GEMINI_VERSION} --no-audit

# 5. Установка Claude Code CLI tools
RUN npm install -g @anthropic-ai/claude-code@latest --no-audit

# 6. Создание директорий для Claude Code
RUN mkdir -p /root/.claude /root/.claude-config

# 7. Настройка SSH для Claude Code
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# 8. Claude Code environment variables
ENV CLAUDE_CONFIG_DIR="/root/.claude-config"
ENV CLAUDE_API_KEY=""
ENV CLAUDE_MODEL="claude-3-5-sonnet-20241022"
ENV CLAUDE_MAX_TOKENS=4096
ENV GEMINI_MODEL="gemini-2.5-pro"

WORKDIR /app

# 9. Entrypoint для двойного режима (Gemini + Claude)
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
