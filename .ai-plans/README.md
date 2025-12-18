# AI Plans Repository

> 📋 Централизованное хранилище планов реализации AI-систем
> *Кросс-устройственная синхронизация через Git*

**📍 Navigation**: [← Back to CLAUDE.md](../CLAUDE.md)

---

## 🎯 Активные планы

### 📊 [Session Manager v1.0 Implementation](./session-manager-implementation.md)

**Статус**: В разработке | **Приоритет**: HIGH | **Срок**: Q1 2026

- Multi-instance AI управление
- Real container integration
- Project context persistence
- Production monitoring

### 📋 [Backlog Tasks](./backlog.md)

**Статус**: Накопление | **Приоритет**: MEDIUM

Накопительные задачи и будущие эпики

---

## 📚 Архив планов

### ✅ [Q1 2026 Initial Architecture](./archive/2025-12-initial-analysis.md)

**Дата**: 2025-12-11 | **Статус**: Завершен

Первоначальный анализ архитектуры и планирование

---

## 🔄 Workflow управления планами

### Создание нового плана

```bash
# 1. Создать файл плана
touch .ai-plans/new-plan.md

# 2. Добавить в индекс
echo "- [new-plan.md](./new-plan.md) - Description" >> .ai-plans/README.md

# 3. Commit и push
git add .ai-plans/
git commit -m "plan: add new plan - description"
git push origin main
```

### Обновление существующего плана

```bash
# 1. Редактировать план
vim .ai-plans/existing-plan.md

# 2. Commit изменения
git add .ai-plans/existing-plan.md
git commit -m "plan: update existing-plan - progress update"
git push origin main
```

### Архивация завершенного плана

```bash
# 1. Переместить в архив с датой
mv .ai-plans/completed-plan.md .ai-plans/archive/2025-12-completed-plan.md

# 2. Обновить README
# (переместить ссылку в секцию архива)

# 3. Commit архивацию
git add .ai-plans/
git commit -m "plan: archive completed-plan - finished implementation"
git push origin main
```

---

## 🏷️ Стандарты планирования

### Формат плана

```markdown
# Plan Title

**Статус**: [In Progress/Planning/Completed] | **Приоритет**: [HIGH/MEDIUM/LOW] | **Версия**: vX.Y

## 📋 Sections
- **🎯 Objectives** - Цели и критерии успеха
- **🔧 Implementation** - Пошаговый план реализации
- **📊 Metrics** - Измеримые метрики прогресса
- **🚀 Timeline** - Сроки и milestone'и
- **🔗 Dependencies** - Зависимости от других компонентов
```

### Naming convention

- `feature-name.md` - активные планы
- `YYYY-MM-feature-name.md` - архивированные планы
- `backlog.md` - накопительные задачи

---

## 📱 Кросс-устройственная работа

### На компьютере A

```bash
git pull origin main          # Получить последние изменения
# Редактировать план...
git add .ai-plans/plan.md
git commit -m "plan: update progress"
git push origin main          # Синхронизировать с другими устройствами
```

### На компьютере B

```bash
git pull origin main          # Автоматически получить обновления
# Продолжить работу с последней версией плана
```

---

## 🏷️ Метаданные

```
Type: PLAN_REPOSITORY
Scope: CROSS_DEVICE_SYNC
Version: 1.0
Last_Updated: 2025-12-11
Sync_Method: GIT_BASED
Navigation: 2-clicks-max
```
