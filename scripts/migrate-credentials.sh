#!/bin/bash

# migrate-credentials.sh - Migration utility for multi-AI credentials
# Transfers credentials from legacy gemini setup to new unified AI system

set -euo pipefail

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Paths
readonly LEGACY_CONFIG="${HOME}/.docker-gemini-config"
readonly NEW_CONFIG="${HOME}/.docker-ai-config"
readonly MIGRATION_LOG="${NEW_CONFIG}/migration.log"

# Files to migrate
readonly CREDENTIAL_FILES=(
    "google_accounts.json"
    "settings.json"
    "oauth_creds.json"
    "installation_id"
    "state.json"
)

# Directories to migrate
readonly CREDENTIAL_DIRS=(
    "gh_config"
    "global_state"
    "tmp"
    "tmp_exec"
)

# Initialize log
init_log() {
    mkdir -p "$(dirname "$MIGRATION_LOG")"
    echo "=== Credentials Migration Log ===" > "$MIGRATION_LOG"
    echo "Started at: $(date)" >> "$MIGRATION_LOG"
    echo "" >> "$MIGRATION_LOG"
}

# Log message
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$MIGRATION_LOG"

    case "$level" in
        "INFO")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️ $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "DEBUG")
            echo -e "${BLUE}🔍 $message${NC}"
            ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Проверка prerequisites..."

    # Check if legacy config exists
    if [[ ! -d "$LEGACY_CONFIG" ]]; then
        log "ERROR" "Legacy config не найден: $LEGACY_CONFIG"
        return 1
    fi

    # Check if there's anything to migrate
    local has_files=false
    for file in "${CREDENTIAL_FILES[@]}"; do
        if [[ -f "$LEGACY_CONFIG/$file" ]]; then
            has_files=true
            break
        fi
    done

    if [[ "$has_files" == "false" ]]; then
        log "WARN" "Не найдено файлов для миграции в $LEGACY_CONFIG"
        return 1
    fi

    log "INFO" "Prerequisites проверены успешно"
    return 0
}

# Create backup before migration
create_backup() {
    local backup_dir="${NEW_CONFIG}/backups/pre-migration-$(date +%Y%m%d_%H%M%S)"

    log "INFO" "Создаю backup: $backup_dir"
    mkdir -p "$backup_dir"

    # Backup new config if it exists
    if [[ -d "$NEW_CONFIG" && "$NEW_CONFIG" != "$backup_dir" ]]; then
        cp -r "$NEW_CONFIG"/* "$backup_dir/" 2>/dev/null || true
    fi

    log "INFO" "Backup создан успешно"
}

# Migrate files
migrate_files() {
    log "INFO" "Начинаю миграцию файлов..."

    local migrated_count=0

    for file in "${CREDENTIAL_FILES[@]}"; do
        local src="$LEGACY_CONFIG/$file"
        local dst="$NEW_CONFIG/$file"

        if [[ -f "$src" ]]; then
            if [[ -f "$dst" ]]; then
                log "WARN" "Файл уже существует: $file (пропускаю)"
                log "DEBUG" "Сравниваю файлы:"
                if diff "$src" "$dst" > /dev/null; then
                    log "DEBUG" "Файлы идентичны"
                else
                    log "DEBUG" "Файлы различаются!"
                    log "DEBUG" "Legacy:"
                    cat "$src" | sed 's/^/  /' >> "$MIGRATION_LOG"
                    log "DEBUG" "New:"
                    cat "$dst" | sed 's/^/  /' >> "$MIGRATION_LOG"
                fi
            else
                log "INFO" "Мигрирую файл: $file"
                cp -p "$src" "$dst"
                ((migrated_count++))
                log "DEBUG" "Скопирован: $src -> $dst"
            fi
        fi
    done

    log "INFO" "Миграция файлов завершена. Перенесено: $migrated_count"
}

# Migrate directories
migrate_directories() {
    log "INFO" "Начинаю миграцию директорий..."

    for dir in "${CREDENTIAL_DIRS[@]}"; do
        local src="$LEGACY_CONFIG/$dir"
        local dst="$NEW_CONFIG/$dir"

        if [[ -d "$src" ]]; then
            if [[ -d "$dst" ]]; then
                log "WARN" "Директория уже существует: $dir (сливаю содержимое)"

                # Merge directories
                find "$src" -maxdepth 1 -mindepth 1 -exec bash -c '
                    src="$1"
                    dst="$2"
                    filename=$(basename "$src")
                    dst_path="$dst/$filename"

                    if [[ -e "$dst_path" ]]; then
                        echo "Файл существует: $filename (пропускаю)"
                    else
                        cp -r "$src" "$dst"
                    fi
                ' _ {} "$dst" \;
            else
                log "INFO" "Мигрирую директорию: $dir"
                cp -r "$src" "$dst"
            fi
        fi
    done

    log "INFO" "Миграция директорий завершена"
}

# Verify migration
verify_migration() {
    log "INFO" "Проверка миграции..."

    local errors=0

    for file in "${CREDENTIAL_FILES[@]}"; do
        if [[ -f "$LEGACY_CONFIG/$file" ]]; then
            if [[ -f "$NEW_CONFIG/$file" ]]; then
                log "DEBUG" "✓ Файл мигрирован: $file"
            else
                log "ERROR" "✗ Файл не мигрирован: $file"
                ((errors++))
            fi
        fi
    done

    if [[ $errors -gt 0 ]]; then
        log "ERROR" "Миграция завершилась с ошибками: $errors"
        return 1
    fi

    log "INFO" "Верификация успешна"
    return 0
}

# Create symlink for backward compatibility
create_symlinks() {
    log "INFO" "Создаю symlinks для backward compatibility..."

    # Create project-level symlinks if needed
    local project_links=(
        ".gemini-config:.docker-ai-config"
        ".docker-gemini-config:.docker-ai-config"
    )

    for link in "${project_links[@]}"; do
        local src="${link%%:*}"
        local dst="${link##*:}"

        if [[ -L "$src" ]]; then
            log "DEBUG" "Symlink уже существует: $src"
            continue
        fi

        # Only create in current directory if it's a git repo
        if git rev-parse --show-toplevel > /dev/null 2>&1; then
            ln -sf "$dst" "$src" 2>/dev/null || true
        fi
    done
}

# Show post-migration summary
show_summary() {
    echo ""
    echo -e "${BLUE}📊 Сводка миграции:${NC}"
    echo "=================================="
    echo -e "Legacy:  ${YELLOW}$LEGACY_CONFIG${NC}"
    echo -e "New:     ${GREEN}$NEW_CONFIG${NC}"
    echo -e "Log:     ${BLUE}$MIGRATION_LOG${NC}"
    echo ""

    echo -e "${GREEN}✅ Миграция завершена успешно!${NC}"
    echo ""
    echo "Следующие шаги:"
    echo "1. Проверьте, что все работает корректно"
    echo "2. При необходимости удалите legacy директорию:"
    echo "   ${YELLOW}rm -rf $LEGACY_CONFIG${NC}"
    echo "3. Используйте новую команду для управления credentials:"
    echo "   ${BLUE}credential-manager status${NC}"
    echo ""
}

# Cleanup after successful migration
cleanup() {
    read -p "Удалить legacy директорию после успешной миграции? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Удаляю legacy директорию..."
        rm -rf "$LEGACY_CONFIG"
        log "INFO" "Legacy директория удалена"
    fi
}

# Main migration flow
main() {
    echo -e "${BLUE}🚀 Миграция Credentials: Gemini -> Unified AI${NC}"
    echo "======================================"
    echo ""

    # Initialize
    init_log

    # Check if we need to migrate
    if ! check_prerequisites; then
        echo -e "${YELLOW}⚠️ Миграция не требуется или невозможна${NC}"
        echo "Проверьте лог: $MIGRATION_LOG"
        exit 0
    fi

    # Create backup
    create_backup

    # Create target directory
    mkdir -p "$NEW_CONFIG"

    # Perform migration
    migrate_files
    migrate_directories

    # Verify
    if verify_migration; then
        create_symlinks
        show_summary

        # Ask about cleanup
        echo -n "Хотите удалить legacy директорию? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            cleanup
        fi
    else
        log "ERROR" "Миграция завершилась с ошибками"
        echo "Проверьте лог: $MIGRATION_LOG"
        exit 1
    fi
}

# Show help
show_help() {
    cat << EOF
Migration Utility for AI Credentials

USAGE:
    migrate-credentials.sh [options]

OPTIONS:
    --dry-run     Показать что будет мигрировано без выполнения
    --help        Показать эту справку

DESCRIPTION:
    Переносит credentials из ~/.docker-gemini-config в ~/.docker-ai-config
    для использования в unified multi-AI среде.

FILES TO MIGRATE:
    - google_accounts.json
    - settings.json
    - oauth_creds.json
    - installation_id
    - state.json
    - gh_config/
    - global_state/
    - tmp/
    - tmp_exec/

EOF
}

# Parse arguments
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Неизвестный аргумент: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${BLUE}🔍 DRY RUN MODE${NC}"
    echo "Файлы для миграции:"
    for file in "${CREDENTIAL_FILES[@]}"; do
        if [[ -f "$LEGACY_CONFIG/$file" ]]; then
            echo "  ✓ $file"
        else
            echo "  ✗ $file (не найден)"
        fi
    done
    echo ""
    echo "Директории для миграции:"
    for dir in "${CREDENTIAL_DIRS[@]}"; do
        if [[ -d "$LEGACY_CONFIG/$dir" ]]; then
            echo "  ✓ $dir/"
        else
            echo "  ✗ $dir/ (не найдена)"
        fi
    done
else
    main
fi
