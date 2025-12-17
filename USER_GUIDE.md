# 🚀 **ИНСТРУКЦИЯ ПОЛЬЗОВАТЕЛЯ AI ASSISTANT ISOLATED V3.1**

## 📋 **ОБЩИЙ ОБЗОР**

AI Assistant Isolated v3.1 предоставляет полностью изолированные контейнеры для работы с различными AI моделями:
- **Claude Code** (Sonnet 4.5) - для продвинутой разработки
- **GLM-4.6** - для работы с китайской AI моделью  
- **Gemini CLI** (2.5-Pro) - для Google AI

---

## 🎯 **БЫСТРЫЙ СТАРТ**

### **1. Развертывание контейнеров**
```bash
# Интерактивное развертывание (рекомендуется)
./deploy-isolated.sh interactive

# Автоматическое развертывание всех контейнеров
./deploy-isolated.sh automated

# Проверка статуса
./deploy-isolated.sh status
```

### **2. Работа с контейнерами**
```bash
# Claude Code (основной режим)
docker run --rm -it \
  -v "$(pwd)/workspace/claude:/workspace/claude" \
  -v "$(pwd)/config/active/claude:/home/claude/.config" \
  -e CLAUDE_API_KEY="$ANTHROPIC_API_KEY" \
  ai-assistant-claude:3.1.0

# GLM-4.6 (настоящий GLM)
docker run --rm -it \
  -v "$(pwd)/workspace/glm:/workspace/glm" \
  -v "$(pwd)/config/active/glm:/home/glm/.config" \
  -e ZAI_API_KEY="$ZAI_API_KEY" \
  ai-assistant-glm:3.1.0

# Gemini CLI (Google AI)
docker run --rm -it \
  -v "$(pwd)/workspace/gemini:/workspace/gemini" \
  -v "$(pwd)/config/active/gemini:/home/gemini/.config" \
  -e GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/config/active/gemini/credentials.json" \
  ai-assistant-gemini:3.1.0
```

---

## 🤖 **ПОДРОБНАЯ ИНСТРУКЦИЯ ДЛЯ КАЖДОГО КОНТЕЙНЕРА**

### **1. Claude Code (Sonnet 4.5)**

#### **Развертывание**
```bash
# Построить контейнер
docker build -t ai-assistant-claude:3.1.0 containers/claude/

# Создать рабочую директорию
mkdir -p workspace/claude
cd workspace/claude

# Запустить Claude Code
docker run --rm -it \
  --name "claude-session-$(date +%s)" \
  -v "$(pwd)/workspace/claude:/workspace/claude" \
  -v "$(pwd)/config/active/claude:/home/claude/.config" \
  -e CLAUDE_API_KEY="$ANTHROPIC_API_KEY" \
  -e CLAUDE_MODEL="claude-3-5-sonnet-20241022" \
  ai-assistant-claude:3.1.0
```

#### **Работа в Claude Code**
```bash
# Внутри контейнера доступны команды:
claude --help                    # Показать справку
claude --version                 # Версия Claude
claude "Напиши Hello World"     # Простой запрос
claude --file main.py "Оптимизируй код"  # Работа с файлами
claude --interactive             # Интерактивный режим
```

#### **Тестовые запросы для Claude**
```bash
# 1. Базовый тест
claude "Привет! Как тебя зовут и что ты умеешь?"

# 2. Тест с кодом
echo 'def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)' > test.py

claude --file test.py "Оптимизируй этот код и объясни изменения"

# 3. Тест с проектом
mkdir -p my-project/src
echo 'console.log("Hello World");' > my-project/src/index.js
cd my-project
claude "Создай package.json для этого проекта и добавь скрипты сборки"

# 4. Интерактивный режим
claude --interactive
# В интерактивном режиме:
# > Создай REST API на Node.js
# > Добавь аутентификацию JWT
# > Напиши тесты
```

---

### **2. GLM-4.6 (Настоящий GLM)**

#### **Развертывание**
```bash
# Построить контейнер
docker build -t ai-assistant-glm:3.1.0 containers/glm/

# Создать рабочую директорию
mkdir -p workspace/glm
cd workspace/glm

# Запустить GLM-4.6
docker run --rm -it \
  --name "glm-session-$(date +%s)" \
  -v "$(pwd)/workspace/glm:/workspace/glm" \
  -v "$(pwd)/config/active/glm:/home/glm/.config" \
  -e ZAI_API_KEY="$ZAI_API_KEY" \
  -e GLM_MODEL="glm-4.6" \
  ai-assistant-glm:3.1.0
```

#### **Работа в GLM-4.6**
```bash
# GLM использует тот же интерфейс, но с Z.AI API
glm --help                     # Показать справку
glm --version                  # Версия GLM
glm "你好！请介绍一下你自己"      # Запрос на китайском
glm --file code.py "分析这段代码"  # Анализ кода
```

#### **Тестовые запросы для GLM**
```bash
# 1. Базовый тест на китайском
glm "你好！请介绍一下GLM-4.6模型的特点"

# 2. Тест с кодом
echo 'def quick_sort(arr):
    if len(arr) <= 1:
        return arr
    pivot = arr[len(arr) // 2]
    left = [x for x in arr if x < pivot]
    middle = [x for x in arr if x == pivot]
    right = [x for x in arr if x > pivot]
    return quick_sort(left) + middle + quick_sort(right)' > sort.py

glm --file sort.py "请分析这个快速排序算法的时间复杂度"

# 3. Тест с проектом
mkdir -p glm-project
echo 'print("你好，世界！")' > glm-project/hello.py
cd glm-project
glm "请为这个Python项目创建requirements.txt和README文件"

# 4. Многоязычный тест
glm "Translate this to English: 人工智能正在改变世界"
```

---

### **3. Gemini CLI (2.5-Pro)**

#### **Развертывание**
```bash
# Построить контейнер
docker build -t ai-assistant-gemini:3.1.0 containers/gemini/

# Создать рабочую директорию
mkdir -p workspace/gemini
cd workspace/gemini

# Настроить Google Cloud credentials
echo "$GOOGLE_APPLICATION_CREDENTIALS_JSON" > config/active/gemini/credentials.json

# Запустить Gemini CLI
docker run --rm -it \
  --name "gemini-session-$(date +%s)" \
  -v "$(pwd)/workspace/gemini:/workspace/gemini" \
  -v "$(pwd)/config/active/gemini:/home/gemini/.config" \
  -e GOOGLE_APPLICATION_CREDENTIALS="/home/gemini/.config/credentials.json" \
  -e GOOGLE_CLOUD_PROJECT="claude-code-docker-tools" \
  ai-assistant-gemini:3.1.0
```

#### **Работа в Gemini CLI**
```bash
# Gemini CLI команды
gemini --help                    # Показать справку
gemini --version                 # Версия Gemini
gemini "Hello! What can you do?" # Простой запрос
gemini --file main.go "Review this Go code"  # Работа с файлами
```

#### **Тестовые запросы для Gemini**
```bash
# 1. Базовый тест
gemini "Hello! I'm using Gemini CLI in Docker. How are you?"

# 2. Тест с кодом
echo 'package main

import "fmt"

func main() {
    fmt.Println("Hello from Gemini!")
}' > main.go

gemini --file main.go "Please review this Go code and suggest improvements"

# 3. Тест с проектом
mkdir -p gemini-project
echo '# Gemini Project
This is a test project for Gemini CLI.' > gemini-project/README.md
cd gemini-project
gemini "Create a comprehensive documentation structure for this project"

# 4. Тест с анализом
echo 'The quick brown fox jumps over the lazy dog.' > text.txt
gemini --file text.txt "Analyze this text for linguistic patterns"
```

---

## 🔧 **ПРОДВИНУТЫЕ ОПЕРАЦИИ**

### **Работа с файлами и проектами**
```bash
# Монтирование текущей директории
docker run --rm -it \
  -v "$(pwd):/workspace" \
  -v "$(pwd)/config/active/claude:/home/claude/.config" \
  -e CLAUDE_API_KEY="$ANTHROPIC_API_KEY" \
  ai-assistant-claude:3.1.0

# Работа с Git репозиторием
docker run --rm -it \
  -v "$(pwd):/workspace" \
  -v "$SSH_AUTH_SOCK:/ssh-agent" \
  -e SSH_AUTH_SOCK="/ssh-agent" \
  -v "$(pwd)/config/active/claude:/home/claude/.config" \
  -e CLAUDE_API_KEY="$ANTHROPIC_API_KEY" \
  ai-assistant-claude:3.1.0
```

### **Интерактивные сессии**
```bash
# Запуск в интерактивном режиме
docker run --rm -it \
  --entrypoint /bin/bash \
  -v "$(pwd)/workspace/claude:/workspace/claude" \
  ai-assistant-claude:3.1.0

# Внутри контейнера:
cd /workspace/claude
claude --interactive
```

### **Мониторинг и логи**
```bash
# Показать логи контейнера
docker logs claude-session-1234567890

# Мониторинг в реальном времени
docker logs -f claude-session-1234567890

# Проверить статус контейнера
docker ps | grep claude
```

---

## 🛠️ **УПРАВЛЕНИЕ КОНТЕЙНЕРАМИ**

### **Очистка и обслуживание**
```bash
# Остановить все AI контейнеры
docker stop $(docker ps -q --filter "name=ai-assistant")

# Удалить все AI контейнеры
docker rm $(docker ps -aq --filter "name=ai-assistant")

# Очистить образы
docker rmi ai-assistant-claude:3.1.0 ai-assistant-glm:3.1.0 ai-assistant-gemini:3.1.0

# Полная очистка
./deploy-isolated.sh cleanup
```

### **Резервное копирование**
```bash
# Сохранить конфигурации
tar -czf ai-configs-backup-$(date +%Y%m%d).tar.gz config/active/

# Сохранить workspace
tar -czf ai-workspace-backup-$(date +%Y%m%d).tar.gz workspace/
```

---

## 🚨 **ТРУБЛЕШУТИНГ**

### **Частые проблемы**

#### **1. Проблема: Контейнер не запускается**
```bash
# Решение: Проверить образ
docker images | grep ai-assistant

# Решение: Проверить логи
docker logs claude-session-1234567890

# Решение: Пересобрать контейнер
docker build -t ai-assistant-claude:3.1.0 containers/claude/
```

#### **2. Проблема: API ключ не работает**
```bash
# Решение: Проверить переменные окружения
docker run --rm -it \
  -e CLAUDE_API_KEY="$ANTHROPIC_API_KEY" \
  ai-assistant-claude:3.1.0 env | grep CLAUDE

# Решение: Проверить файл конфигурации
cat config/active/claude.yml
```

#### **3. Проблема: Файлы не видны в контейнере**
```bash
# Решение: Проверить права доступа
ls -la workspace/claude
chmod -R 755 workspace/claude

# Решение: Проверить монтирование
docker run --rm -it \
  -v "$(pwd)/workspace/claude:/workspace/claude" \
  --entrypoint /bin/bash \
  ai-assistant-claude:3.1.0
# Внутри: ls -la /workspace/claude
```

---

## 📋 **ЧЕК-ЛИСТ ДЛЯ ТЕСТИРОВАНИЯ**

### **✅ Перед началом работы**
- [ ] Docker установлен и запущен
- [ ] API ключи настроены (CLAUDE_API_KEY, ZAI_API_KEY, GOOGLE_APPLICATION_CREDENTIALS)
- [ ] Конфигурации скопированы из шаблонов
- [ ] Рабочие директории созданы

### **✅ Тестирование каждого контейнера**
- [ ] Claude контейнер запускается
- [ ] Claude отвечает на базовые запросы
- [ ] Claude работает с файлами
- [ ] GLM контейнер запускается
- [ ] GLM отвечает на китайские запросы
- [ ] GLM работает с кодом
- [ ] Gemini контейнер запускается
- [ ] Gemini отвечает на запросы
- [ ] Gemini работает с проектами

### **✅ Тестирование изоляции**
- [ ] Конфигурации не перемешиваются
- [ ] Рабочие директории изолированы
- [ ] API ключи не конфликтуют
- [ ] Контейнеры работают одновременно

---

## 🎯 **СЛЕДУЮЩИЕ ШАГИ**

После освоения базовых операций:
1. **MCP сервера** - расширенные возможности
2. **Плагины** - дополнительная функциональность  
3. **CI/CD** - автоматизация развертывания
4. **Мониторинг** - наблюдение за состоянием

---

*Документация обновлена: 2025-12-17*  
*Версия: 3.1.0*