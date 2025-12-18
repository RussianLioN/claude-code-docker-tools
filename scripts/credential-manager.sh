#!/bin/bash

# credential-manager.sh - Универсальная система управления credentials для multi-AI среды
# Поддерживает fallback logic и автоматическую миграцию

set -euo pipefail

# Version
readonly CREDENTIAL_MANAGER_VERSION="1.0.0"

# Пути для поиска credentials (в порядке приоритета)
readonly NEW_CONFIG_HOME="${HOME}/.docker-ai-config"
readonly LEGACY_CONFIG_HOME="${HOME}/.docker-gemini-config"
readonly PROJECT_CONFIG_NAME=".project-ai-config"

# Цвета для вывода
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Ищет credentials в указанных директориях
find_credentials() {
    local credential_file="$1"
    local search_paths=(
        "${NEW_CONFIG_HOME}/${credential_file}"
        "${LEGACY_CONFIG_HOME}/${credential_file}"
        "$(pwd)/${PROJECT_CONFIG_NAME}/${credential_file}"
    )

    for path in "${search_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# Создает symlink для backward compatibility
create_symlink() {
    local source="$1"
    local target="$2"

    if [[ ! -L "$target" && ! -f "$target" ]]; then
        echo -e "${BLUE}🔗 Создаю symlink: ${target} -> ${source}${NC}"
        ln -s "$source" "$target"
    fi
}

# Копирует credentials с сохранением прав доступа
copy_credentials() {
    local source="$1"
    local target="$2"

    # Создаем директорию если необходимо
    mkdir -p "$(dirname "$target")"

    # Копируем с сохранением прав
    cp -p "$source" "$target"
    echo -e "${GREEN}✅ Скопирован: $(basename "$source")${NC}"
}

# Мигрирует credentials из старой директории в новую
migrate_credentials() {
    local credential_types=(
        "google_accounts.json"
        "settings.json"
        "oauth_creds.json"
        "claude_config.json"
    )

    echo -e "${YELLOW}🔄 Проверка необходимости миграции...${NC}"

    local needs_migration=false

    # Проверяем, есть ли credentials в legacy директории
    for cred in "${credential_types[@]}"; do
        if [[ -f "${LEGACY_CONFIG_HOME}/${cred}" && ! -f "${NEW_CONFIG_HOME}/${cred}" ]]; then
            needs_migration=true
            break
        fi
    done

    if [[ "$needs_migration" == "true" ]]; then
        echo -e "${BLUE}📦 Обнаружены credentials в legacy директории${NC}"
        echo -e "${BLUE}   Выполняю миграцию в ${NEW_CONFIG_HOME}${NC}"

        # Создаем директорию если необходимо
        mkdir -p "$NEW_CONFIG_HOME"

        # Копируем credentials
        for cred in "${credential_types[@]}"; do
            local legacy_path="${LEGACY_CONFIG_HOME}/${cred}"
            local new_path="${NEW_CONFIG_HOME}/${cred}"

            if [[ -f "$legacy_path" ]]; then
                copy_credentials "$legacy_path" "$new_path"
            fi
        done

        # Копируем дополнительные директории
        if [[ -d "${LEGACY_CONFIG_HOME}/gh_config" && ! -d "${NEW_CONFIG_HOME}/gh_config" ]]; then
            cp -r "${LEGACY_CONFIG_HOME}/gh_config" "${NEW_CONFIG_HOME}/"
            echo -e "${GREEN}✅ Скопирована директория: gh_config${NC}"
        fi

        echo -e "${GREEN}✅ Миграция завершена${NC}"
    else
        echo -e "${GREEN}✅ Миграция не требуется${NC}"
    fi
}

# Инициализирует credentials для проекта
init_project_credentials() {
    local project_dir="${1:-$(pwd)}"
    local project_config_dir="${project_dir}/${PROJECT_CONFIG_NAME}"

    if [[ -d "$project_config_dir" ]]; then
        echo -e "${BLUE}📁 Обнаружены project-specific credentials${NC}"
        return 0
    fi

    return 1
}

# Синхронизирует credentials в runtime
sync_credentials() {
    local state_dir="$1"

    # Ищем необходимые credentials
    local credential_files=(
        "google_accounts.json"
        "settings.json"
        "claude_config.json"
    )

    for cred_file in "${credential_files[@]}"; do
        local source_path
        if source_path=$(find_credentials "$cred_file"); then
            # Копируем в state_dir для контейнера
            cp -p "$source_path" "${state_dir}/${cred_file}"
            echo -e "${GREEN}✅ Синхронизирован: ${cred_file}${NC}"
        else
            echo -e "${YELLOW}⚠️ Пропущен: ${cred_file} (не найден)${NC}"
        fi
    done
}

# Показывает статус credentials
show_status() {
    echo -e "${BLUE}📊 Статус Credentials:${NC}"
    echo "=================================="

    # Проверяем новую конфигурацию
    if [[ -d "$NEW_CONFIG_HOME" ]]; then
        echo -e "${GREEN}✅ Новая конфигурация:${NC} $NEW_CONFIG_HOME"
        ls -la "$NEW_CONFIG_HOME" | grep -E "\.(json|yml)$" || echo "  (нет JSON/YAML файлов)"
    else
        echo -e "${RED}❌ Новая конфигурация не найдена:${NC} $NEW_CONFIG_HOME"
    fi

    echo ""

    # Проверяем legacy конфигурацию
    if [[ -d "$LEGACY_CONFIG_HOME" ]]; then
        echo -e "${YELLOW}⚠️ Legacy конфигурация:${NC} $LEGACY_CONFIG_HOME"
        ls -la "$LEGACY_CONFIG_HOME" | grep -E "\.(json|yml)$" || echo "  (нет JSON/YAML файлов)"
    else
        echo -e "${GREEN}✅ Legacy конфигурация отсутствует${NC}"
    fi

    echo ""

    # Проверяем project-specific конфигурацию
    if [[ -d "$(pwd)/${PROJECT_CONFIG_NAME}" ]]; then
        echo -e "${BLUE}📁 Project-specific конфигурация:${NC} $(pwd)/${PROJECT_CONFIG_NAME}"
        ls -la "$(pwd)/${PROJECT_CONFIG_NAME}" | grep -E "\.(json|yml)$" || echo "  (нет JSON/YAML файлов)"
    fi
}

# Создает backup credentials
backup_credentials() {
    local backup_dir="${1:-${NEW_CONFIG_HOME}/backups/$(date +%Y%m%d_%H%M%S)}"

    echo -e "${BLUE}💾 Создаю backup в: ${backup_dir}${NC}"

    mkdir -p "$backup_dir"

    # Backup новой конфигурации
    if [[ -d "$NEW_CONFIG_HOME" ]]; then
        cp -r "$NEW_CONFIG_HOME"/* "$backup_dir/" 2>/dev/null || true
    fi

    echo -e "${GREEN}✅ Backup создан${NC}"
}

# Восстанавливает из backup
restore_credentials() {
    local backup_dir="$1"

    if [[ ! -d "$backup_dir" ]]; then
        echo -e "${RED}❌ Backup директория не найдена: ${backup_dir}${NC}"
        return 1
    fi

    echo -e "${YELLOW}🔄 Восстановление из backup: ${backup_dir}${NC}"

    # Создаем backup текущих настроек
    backup_credentials

    # Восстанавливаем файлы
    cp -r "$backup_dir"/* "$NEW_CONFIG_HOME/"

    echo -e "${GREEN}✅ Восстановление завершено${NC}"
}

# Очищует старые credentials (опасно!)
cleanup_legacy() {
    echo -e "${RED}⚠️ ВНИМАНИЕ: Это удалит legacy credentials!${NC}"
    echo -e "${RED}   Убедитесь, что миграция выполнена успешно.${NC}"
    echo ""

    read -p "Продолжить? (yes/no): " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        echo "Отменено"
        return 1
    fi

    echo -e "${YELLOW}🧹 Очистка legacy credentials...${NC}"

    # Удаляем legacy директорию
    if [[ -d "$LEGACY_CONFIG_HOME" ]]; then
        rm -rf "$LEGACY_CONFIG_HOME"
        echo -e "${GREEN}✅ Удалена legacy директория${NC}"
    fi

    echo -e "${GREEN}✅ Очистка завершена${NC}"
}

# Показывает справку
show_help() {
    cat << EOF
Credential Manager v${CREDENTIAL_MANAGER_VERSION}

Универсальная система управления credentials для multi-AI среды.

USAGE:
    credential-manager <command> [arguments]

COMMANDS:
    status                      Показать статус credentials
    migrate                     Мигрировать из legacy в новую конфигурацию
    sync <state_dir>            Синхронизировать credentials в state_dir
    init                        Инициализировать credentials для проекта
    backup [dir]                Создать backup
    restore <dir>               Восстановить из backup
    cleanup                     Очистить legacy credentials
    help                        Показать эту справку

EXAMPLES:
    credential-manager status                    # Показать статус
    credential-manager migrate                   # Мигрировать credentials
    credential-manager sync /tmp/ai-state        # Синхронизировать
    credential-manager backup                    # Создать backup
    credential-manager restore /path/to/backup   # Восстановить

CONFIGURATION PATHS:
    New Config:      ${NEW_CONFIG_HOME}
    Legacy Config:   ${LEGACY_CONFIG_HOME}
    Project Config:  ./${PROJECT_CONFIG_NAME}

EOF
}

# Main execution
main() {
    local command="${1:-"help"}"

    case "$command" in
        "status")
            show_status
            ;;
        "migrate")
            migrate_credentials
            ;;
        "sync")
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} Требуется указать state_dir"
                echo "Usage: credential-manager sync <state_dir>"
                exit 1
            fi
            sync_credentials "$2"
            ;;
        "init")
            init_project_credentials
            ;;
        "backup")
            backup_credentials "${2:-}"
            ;;
        "restore")
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error:${NC} Требуется указать backup директорию"
                echo "Usage: credential-manager restore <backup_dir>"
                exit 1
            fi
            restore_credentials "$2"
            ;;
        "cleanup")
            cleanup_legacy
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}Error:${NC} Неизвестная команда '$command'"
            show_help
            exit 1
            ;;
    esac
}

# Execute if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
