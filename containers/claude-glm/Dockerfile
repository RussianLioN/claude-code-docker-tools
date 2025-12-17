FROM mcr.microsoft.com/devcontainers/javascript-node:20

# Установка Claude Code
RUN npm install -g @anthropic-ai/claude-3-dev

# Установка Python для GLM
RUN apt-get update && apt-get install -y python3 python3-pip && rm -rf /var/lib/apt/lists/*

# Установка GLM библиотеки
RUN pip3 install --no-cache-dir zhipuai

# Создание пользователя
RUN useradd -m -s /bin/bash aiuser && \
    mkdir -p /home/aiuser/.config && \
    chown -R aiuser:aiuser /home/aiuser

USER aiuser
WORKDIR /home/aiuser

# Настройка окружения
ENV PATH="/home/aiuser/.local/bin:$PATH"
ENV HOME="/home/aiuser"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "console.log('Claude GLM container healthy')" || exit 1

# Копирование конфигурации GLM (будет смонтирована)
# COPY --chown=aiuser:aiuser config/glm_config.json /home/aiuser/.config/glm.json

# Скрипт для запуска GLM в Claude (будет смонтирован)
# COPY --chown=aiuser:aiuser scripts/claude-glm-wrapper.sh /home/aiuser/claude-glm.sh

CMD ["/bin/bash"]