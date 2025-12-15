# Руководство по миграции Credentials в Multi-AI среду

## Обзор

Это руководство описывает процесс миграции credentials из старого проекта `gemini-docker-setup` в новую унифицированную среду `claude-code-docker-tools`, поддерживающую multiple AI ассистентов.

## Проблема

- **Старый проект**: Использует `~/.docker-gemini-config/` для хранения credentials
- **Новый проект**: Настроен на `~/.docker-ai-config/`
- **Результат**: Новый проект не может найти существующие credentials

## Решение: Универсальная система с Fallback Logic

Мы реализовали систему, которая:

1. **Автоматически находит** credentials в нескольких locations
2. **Мигрирует** старые credentials в новую директорию
3. **Поддерживает backward compatibility** с существующими проектами

## Структура директорий

```
~/
├── .docker-ai-config/          # Новая унифицированная конфигурация
│   ├── google_accounts.json    # Gemini credentials
│   ├── settings.json           # AI настройки
│   ├── claude_config.json      # Claude конфигурация
│   └── gh_config/              # GitHub CLI конфигурация
│
├── .docker-gemini-config/      # Legacy конфигурация (будет удалена)
│   └── ...                     # Старые credentials
│
└── .project-ai-config/         # Project-specific credentials (опционально)
    └── ...                     # Перезаписывает глобальные настройки
```

## Инструменты управления

### 1. Credential Manager

Универсальная утилита для управления credentials:

```bash
# Показать статус всех credentials
./scripts/credential-manager.sh status

# Автоматическая миграция из legacy в новую конфигурацию
./scripts/credential-manager.sh migrate

# Синхронизировать credentials в runtime
./scripts/credential-manager.sh sync /tmp/ai-state

# Создать backup
./scripts/credential-manager.sh backup

# Восстановить из backup
./scripts/credential-manager.sh restore /path/to/backup
```

### 2. Migration Script

Специализированный скрипт для одной миграции:

```bash
# Показать что будет мигрировано (без выполнения)
./scripts/migrate-credentials.sh --dry-run

# Выполнить миграцию
./scripts/migrate-credentials.sh
```

## Пошаговая миграция

### Шаг 1: Автоматическая миграция (рекомендуется)

Новый проект автоматически обнаружит legacy credentials и предложит миграцию:

```bash
# Первый запуск - автоматическая проверка
source ai-assistant.zsh
gemini    # или claude
# Система обнаружит legacy credentials и выполнит миграцию
```

### Шаг 2: Ручная миграция (если автоматическая не сработала)

```bash
# Запустить миграцию вручную
./scripts/migrate-credentials.sh

# Или использовать credential manager
./scripts/credential-manager.sh migrate
```

### Шаг 3: Проверка результата

```bash
# Проверить статус
./scripts/credential-manager.sh status

# Протестировать работу
source ai-assistant.zsh
gemini --version
claude --version
```

### Шаг 4: Очистка (опционально)

После успешной миграции и проверки:

```bash
# Удалить legacy конфигурацию
./scripts/credential-manager.sh cleanup

# Или вручную
rm -rf ~/.docker-gemini-config
```

## Best Practices

### 1. Naming Conventions

Для multi-AI среды используйте generic naming:

- ✅ `~/.docker-ai-config/` - универсально для всех AI
- ❌ `~/.docker-gemini-config/` - специфично для Gemini
- ❌ `~/.docker-claude-config/` - специфично для Claude

### 2. Future-proofing

Система спроектирована для поддержки дополнительных AI:

```bash
# Структура для новых AI
~/.docker-ai-config/
├── openai_config.json      # Для ChatGPT
├── anthropic_config.json   # Для Claude
├── gemini_config.json      # Для Gemini
└── settings.json           # Общие настройки
```

### 3. Security Considerations

- **Права доступа**: Credentials файлы имеют права `600`
- **Backup**: Автоматически создается backup перед миграцией
- **Encryption**: Для production среды используйте GPG encryption

```bash
# Шифрование sensitive файлов
gpg --symmetric --cipher-algo AES256 ~/.docker-ai-config/google_accounts.json

# Расшифровка при необходимости
gpg --decrypt ~/.docker-ai-config/google_accounts.json.gpg > ~/.docker-ai-config/google_accounts.json
```

### 4. CI/CD Integration

Для CI/CD pipeline:

```yaml
# GitHub Actions example
- name: Setup AI Credentials
  run: |
    mkdir -p ~/.docker-ai-config
    echo "${{ secrets.GOOGLE_ACCOUNTS_JSON }}" > ~/.docker-ai-config/google_accounts.json
    echo "${{ secrets.AI_SETTINGS_JSON }}" > ~/.docker-ai-config/settings.json
    chmod 600 ~/.docker-ai-config/*
```

## Troubleshooting

### Проблема: Credentials не найдены

```bash
# Проверить все возможные location
find ~ -name "google_accounts.json" -type f 2>/dev/null

# Показать детальный статус
./scripts/credential-manager.sh status
```

### Проблема: Ошибка миграции

```bash
# Проверить лог миграции
cat ~/.docker-ai-config/migration.log

# Создать backup и retry
./scripts/credential-manager.sh backup
./scripts/migrate-credentials.sh
```

### Проблема: Права доступа

```bash
# Исправить права доступа
chmod 600 ~/.docker-ai-config/*.json
chmod 700 ~/.docker-ai-config
```

## Industry Standards

### Production Patterns

1. **Vault Integration**: Для production используйте HashiCorp Vault
2. **Kubernetes Secrets**: В K8s环境中 используйте secrets
3. **AWS Parameter Store**: Для AWS deployed приложений

### Enterprise Considerations

1. **Audit Trail**: Логируйте все операции с credentials
2. **Rotation**: Регулярная ротация credentials
3. **Multi-tenancy**: Изоляция credentials per tenant

```bash
# Enterprise структура
~/.docker-ai-config/
├── tenants/
│   ├── dev-team/
│   ├── prod-team/
│   └── shared/
└── audit/
    └── access.log
```

## Заключение

Новая система управления credentials обеспечивает:

- ✅ **Seamless migration** из старой системы
- ✅ **Backward compatibility** с существующими проектами
- ✅ **Future-proof** архитектуру для новых AI
- ✅ **Security best practices** для production
- ✅ **Centralized management** через credential manager

Для получения дополнительной помощи:

```bash
# Показать справку
./scripts/credential-manager.sh help

# Поддержка
echo "Проблема: [описание]" | tee -a ~/.docker-ai-config/support.log
```