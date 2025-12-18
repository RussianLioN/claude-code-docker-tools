#!/bin/bash
# Скрипт для управления версиями и релизами

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Получение текущей версии
get_current_version() {
    if [ -f "package.json" ]; then
        node -p "require('./package.json').version"
    else
        echo "0.0.0"
    fi
}

# Проверка чистоты рабочего дерева
check_git_status() {
    if [ -n "$(git status --porcelain)" ]; then
        print_error "Рабочее дерево не чисто. Сначала закоммитьте изменения."
        git status --short
        exit 1
    fi
}

# Обновление CHANGELOG
update_changelog() {
    local version=$1
    local release_date=$(date +%Y-%m-%d)

    print_info "Обновление CHANGELOG.md для версии $version..."

    # Создаем временную секцию для новой версии
    local temp_changelog="## [$version] - $release_date

### Добавлено
-

### Изменено
-

### Исправлено
-

"

    # Вставляем новую версию после [Unreleased] секции
    if [ -f "CHANGELOG.md" ]; then
        awk -v version_section="$temp_changelog" '
        /^## \[Unreleased\]/ {
            print
            print ""
            print version_section
            next
        }
        { print }
        ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
    else
        echo "# CHANGELOG\n\n$version_section" > CHANGELOG.md
    fi

    print_success "CHANGELOG.md обновлен"
}

# Создание Git tag
create_tag() {
    local version=$1
    local message="Release version $version"

    print_info "Создание Git tag v$version..."
    git tag -a "v$version" -m "$message"
    print_success "Tag v$version создан"
}

# Публикация релиза
publish_release() {
    local version=$1

    print_info "Публикация релиза v$version..."

    # Push изменений и tag
    git push origin main
    git push origin "v$version"

    print_success "Релиз v$version опубликован"
}

# Основная функция
main() {
    local action=${1:-"help"}
    local version_type=${2:-"patch"}

    case $action in
        "patch"|"minor"|"major")
            print_info "Подготовка к $version_type релизу..."

            # Проверка состояния
            check_git_status

            # Получение текущей версии
            local current_version=$(get_current_version)
            print_info "Текущая версия: $current_version"

            # Обновление версии в package.json
            if command -v npm &> /dev/null && [ -f "package.json" ]; then
                npm version "$version_type" --no-git-tag-version
                local new_version=$(get_current_version)
                print_success "Версия обновлена до $new_version"

                # Обновление CHANGELOG
                update_changelog "$new_version"

                # Коммит изменений
                git add package.json CHANGELOG.md
                git commit -m "chore: release version $new_version"

                # Создание tag
                create_tag "$new_version"

                # Публикация
                if [ "${3:-}" != "--no-publish" ]; then
                    publish_release "$new_version"
                fi
            else
                print_error "npm не найден или отсутствует package.json"
                exit 1
            fi
            ;;

        "current")
            get_current_version
            ;;

        "changelog")
            local version=${2:-$(get_current_version)}
            update_changelog "$version"
            ;;

        "tag")
            local version=${2:-$(get_current_version)}
            create_tag "$version"
            ;;

        "help"|*)
            echo "Скрипт управления версиями и релизами"
            echo ""
            echo "Использование:"
            echo "  $0 [COMMAND] [OPTIONS]"
            echo ""
            echo "Команды:"
            echo "  patch [--no-publish]    Создать patch версию (x.x.X)"
            echo "  minor [--no-publish]    Создать minor версию (x.X.x)"
            echo "  major [--no-publish]    Создать major версию (X.x.x)"
            echo "  current                Показать текущую версию"
            echo "  changelog [version]    Обновить CHANGELOG для версии"
            echo "  tag [version]          Создать Git tag"
            echo "  help                   Показать эту справку"
            echo ""
            echo "Примеры:"
            echo "  $0 patch               # Создать patch версию и опубликовать"
            echo "  $0 minor --no-publish  # Создать minor версию без публикации"
            echo "  $0 current             # Показать текущую версию"
            ;;
    esac
}

# Запуск
main "$@"
