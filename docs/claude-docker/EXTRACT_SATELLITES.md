# 🔧 Инструкция: Извлечение Satellite Файлов из Backup

**Статус**: КРИТИЧНО - Выполнить в следующей сессии ДО начала реализации

---

## 📋 Проблема

Hub + Satellites архитектура создана, но **не все satellite файлы извлечены** из backup.

**Что есть**:
- ✅ Hub: `CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md` (263 lines)
- ✅ Phase 1: `docs/claude-docker/phases/PHASE1_FOUNDATION.md` (595 lines)
- ✅ Backup: `CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3_FULL.md.backup` (2200 lines)

**Что нужно создать**:
- ⏳ Phase 2: `docs/claude-docker/phases/PHASE2_CORE.md`
- ⏳ Phase 3: `docs/claude-docker/phases/PHASE3_HARDENING.md`
- ⏳ Phase 4: `docs/claude-docker/phases/PHASE4_TESTING.md`
- ⏳ Architecture: `docs/claude-docker/ARCHITECTURE.md`
- ⏳ Modules: `docs/claude-docker/MODULES_REFERENCE.md`
- ⏳ Troubleshooting: `docs/claude-docker/TROUBLESHOOTING.md`
- ⏳ SLO: `docs/claude-docker/SLO_SLA_METRICS.md`
- ⏳ GitOps: `docs/claude-docker/GITOPS_WORKFLOW.md`
- ⏳ Rollback: `docs/claude-docker/ROLLBACK_DR.md`

---

## 🚀 Автоматическое Извлечение

### Метод 1: Использовать AI ассистента

**Prompt для следующей сессии**:

```
Извлеки оставшиеся satellite файлы из backup:

1. Прочитай CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3_FULL.md.backup
2. Извлеки секции Phase 2-4 и темы
3. Создай satellite файлы:
   - docs/claude-docker/phases/PHASE2_CORE.md (строки ~700-1200 из backup)
   - docs/claude-docker/phases/PHASE3_HARDENING.md (строки ~1200-1650)
   - docs/claude-docker/phases/PHASE4_TESTING.md (строки ~1650-1850)
   - docs/claude-docker/ARCHITECTURE.md (извлечь Architecture секцию)
   - docs/claude-docker/TROUBLESHOOTING.md (извлечь Troubleshooting секцию)

Формат satellite файлов:
- Навигация вверху: [← Back to Plan v3.0](../../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
- Содержимое секции
- Навигация внизу + ссылка на следующую фазу
```

### Метод 2: Ручное Извлечение (Fallback)

**Используй text editor с поиском по строкам**:

1. Открой `CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3_FULL.md.backup`
2. Найди секцию "## PHASE 2: CORE IMPLEMENTATION"
3. Скопируй до "## PHASE 3:"
4. Создай файл `docs/claude-docker/phases/PHASE2_CORE.md`
5. Добавь навигацию (см. шаблон ниже)
6. Повтори для остальных секций

---

## 📄 Шаблон Satellite Файла

```markdown
# [Title of Section]

**📍 Navigation**: [← Back to Plan v3.0](../../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)

---

[СОДЕРЖИМОЕ ИЗ BACKUP]

---

**🔗 Next**: [Next Phase/Topic](./NEXT_FILE.md)

**📍 Navigation**: [← Back to Plan v3.0](../../../CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md)
```

---

## 📊 Mapping: Backup → Satellites

### Phase Satellites

| Satellite File | Backup Section | Approximate Lines |
|----------------|----------------|-------------------|
| PHASE2_CORE.md | "## PHASE 2: CORE IMPLEMENTATION" | 700-1200 |
| PHASE3_HARDENING.md | "## PHASE 3: PRODUCTION HARDENING" | 1200-1650 |
| PHASE4_TESTING.md | "## PHASE 4: TESTING & VALIDATION" | 1650-1850 |

### Theme Satellites

| Satellite File | Backup Section | Extract From |
|----------------|----------------|--------------|
| ARCHITECTURE.md | "## PRODUCTION ARCHITECTURE" + diagrams | Lines ~230-270 |
| MODULES_REFERENCE.md | "## CRITICAL COMPONENTS" | Lines ~1600-1650 |
| TROUBLESHOOTING.md | "## TROUBLESHOOTING GUIDE" | Lines ~1875-1960 |
| SLO_SLA_METRICS.md | "## SLO/SLA DEFINITIONS" | Lines ~1825-1875 |
| GITOPS_WORKFLOW.md | "## GITOPS INTEGRATION" | Lines ~1750-1825 |
| ROLLBACK_DR.md | "## ROLLBACK & RECOVERY" | Lines ~1645-1695 |

---

## ✅ Проверка После Извлечения

После создания всех satellites:

```bash
# 1. Проверить что все файлы созданы
ls -lh docs/claude-docker/phases/
ls -lh docs/claude-docker/

# 2. Проверить размеры (должны быть разумными)
wc -l docs/claude-docker/phases/*.md
wc -l docs/claude-docker/*.md

# 3. Проверить кросс-ссылки
grep -r "CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3.md" docs/claude-docker/

# 4. Удалить backup (после проверки)
# rm CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3_FULL.md.backup
```

---

## 🎯 Приоритет Извлечения

**Если ограничены во времени, создать в этом порядке**:

1. **PHASE2_CORE.md** (CRITICAL) - нужно для продолжения реализации
2. **TROUBLESHOOTING.md** (HIGH) - для debugging
3. **PHASE3_HARDENING.md** (MEDIUM) - для production
4. **ARCHITECTURE.md** (MEDIUM) - для понимания
5. Остальные (LOW) - можно создать позже

---

## 🚨 ВАЖНО

**НЕ УДАЛЯЙ backup файл** до тех пор, пока:
- ✅ Все satellite файлы созданы
- ✅ Кросс-ссылки проверены
- ✅ Размеры файлов корректны
- ✅ Контент проверен

**Backup - это единственная полная копия контента Plan v3.0!**

---

**Статус**: Готово к извлечению в следующей сессии
**Backup Location**: `CLAUDE_CODE_DOCKER_IMPLEMENTATION_PLAN_V3_FULL.md.backup`
**Priority**: CRITICAL
