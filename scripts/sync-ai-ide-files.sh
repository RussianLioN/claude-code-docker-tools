#!/bin/bash
# ================================================================
# INTELLIGENT AI IDE FILES SYNCHRONIZATION SCRIPT
# ================================================================
# Purpose: Automatically detect the most recent AI IDE file and synchronize all others to it
# Files: CLAUDE.md, QWEN.md, .qoder/rules/QODER.md, .clinerules, .cursorrules, docs/system-instructions.md
# Special: QODER.md preserves YAML frontmatter (lines 1-4)
# Usage: ./scripts/sync-ai-ide-files.sh
# ================================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "================================================================"
echo "🧠 INTELLIGENT AI IDE FILES SYNCHRONIZATION"
echo "================================================================"
echo ""

# Define all AI IDE instruction files to monitor
ALL_AI_IDE_FILES=(
    "CLAUDE.md"
    "QWEN.md"
    ".qoder/rules/QODER.md"
    ".clinerules"
    ".cursorrules"
    ".trae/rules/00-system-manifest.md"
    "docs/system-instructions.md"
)

# YAML frontmatter for QODER.md (lines 1-4)
QODER_YAML_HEADER="---
trigger: always_on
alwaysApply: true
---     "

# YAML frontmatter for Trae (lines 1-5)
TRAE_YAML_HEADER="---
mode: system
applies_to: [\"*\"]
alwaysApply: true
---"

# Check which files exist and get their modification times
EXISTING_FILES=()
echo "🔍 Checking for AI IDE files..."
for file in "${ALL_AI_IDE_FILES[@]}"; do
    if [ -f "$file" ]; then
        # Use stat to get modification time in a way that works on both GNU (Linux) and BSD (macOS)
        MOD_TIME=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
        EXISTING_FILES+=("$file:$MOD_TIME")
        # Format timestamp to human-readable date - compatible with both Linux and macOS
        FORMATTED_DATE=$(date -r "$MOD_TIME" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d@"$MOD_TIME" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
        echo "   ✅ Found: $file ($FORMATTED_DATE)"
    else
        echo "   ❌ Missing: $file"
    fi
done

echo ""

if [ ${#EXISTING_FILES[@]} -eq 0 ]; then
    echo -e "${RED}❌ ERROR: No AI IDE files found!${NC}"
    exit 1
fi

# Find the most recently modified file
MOST_RECENT_FILE=""
MOST_RECENT_TIME=0

for entry in "${EXISTING_FILES[@]}"; do
    FILE_NAME="${entry%%:*}"
    FILE_TIME="${entry#*:}"

    if [ "$FILE_TIME" -gt "$MOST_RECENT_TIME" ]; then
        MOST_RECENT_TIME="$FILE_TIME"
        MOST_RECENT_FILE="$FILE_NAME"
    fi
done

FORMATTED_MOST_RECENT_DATE=$(date -r "$MOST_RECENT_TIME" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d@"$MOST_RECENT_TIME" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
echo -e "${BLUE}🎯 Most recent file detected:${NC} $MOST_RECENT_FILE (modified: $FORMATTED_MOST_RECENT_DATE)"
echo ""

# Get source file info
SOURCE_FILE="$MOST_RECENT_FILE"
SOURCE_SIZE=$(wc -c < "$SOURCE_FILE")
SOURCE_LINES=$(wc -l < "$SOURCE_FILE")
SOURCE_MD5=$(md5 -q "$SOURCE_FILE" 2>/dev/null || md5sum "$SOURCE_FILE" | cut -d' ' -f1)

echo -e "${YELLOW}📄 Source File: $SOURCE_FILE${NC}"
echo "   Size: $SOURCE_SIZE bytes"
echo "   Lines: $SOURCE_LINES"
echo "   MD5: $SOURCE_MD5"
echo ""

# Identify target files (all existing files except the source)
TARGET_FILES=()
for entry in "${EXISTING_FILES[@]}"; do
    FILE_NAME="${entry%%:*}"
    if [ "$FILE_NAME" != "$SOURCE_FILE" ]; then
        TARGET_FILES+=("$FILE_NAME")
    fi
done

if [ ${#TARGET_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}ℹ️  All files are already up to date (only one file exists)${NC}"
    echo ""
    echo "================================================================"
    echo "✅ No synchronization needed"
    echo "================================================================"
    exit 0
fi

# Compare source with targets and show differences
echo "🔍 Comparing source with target files..."
DIFFERING_FILES=()

for target in "${TARGET_FILES[@]}"; do
    TARGET_MD5=$(md5 -q "$target" 2>/dev/null || md5sum "$target" | cut -d' ' -f1)
    if [ "$SOURCE_MD5" != "$TARGET_MD5" ]; then
        DIFFERING_FILES+=("$target")
        TARGET_SIZE=$(wc -c < "$target")
        echo -e "   📄 $target differs: $TARGET_SIZE bytes vs $SOURCE_SIZE bytes (MD5: $TARGET_MD5)"
    else
        echo -e "   ✅ $target is already in sync"
    fi
done

echo ""

if [ ${#DIFFERING_FILES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All files are already synchronized${NC}"
    echo ""
    echo "================================================================"
    echo "✅ Synchronization complete"
    echo "================================================================"
    exit 0
fi

echo "📋 Files to synchronize: ${DIFFERING_FILES[@]}"
echo ""

# Backup differing files before synchronization
echo "📦 Creating backups..."
BACKUP_DIR=".backup_ai_ide_files_$(date -u +"%Y%m%d_%H%M%S")"
mkdir -p "$BACKUP_DIR"

for target in "${DIFFERING_FILES[@]}"; do
    cp "$target" "$BACKUP_DIR/"
    echo "   ✅ Backed up: $target → $BACKUP_DIR/"
done

echo "   📁 Backups saved to: $BACKUP_DIR/"
echo ""

# Synchronize files
echo "🔄 Synchronizing files..."
SYNC_COUNT=0
ERROR_COUNT=0

for target in "${DIFFERING_FILES[@]}"; do
    echo -n "   Syncing $target... "

    # Special handling for QODER.md
    if [ "$target" == ".qoder/rules/QODER.md" ]; then
        # Extract content without YAML header from source
        if [ "$SOURCE_FILE" == ".qoder/rules/QODER.md" ]; then
            # Source is QODER.md - skip YAML header (first 4 lines)
            CONTENT=$(tail -n +5 "$SOURCE_FILE")
        elif [ "$SOURCE_FILE" == ".trae/rules/00-system-manifest.md" ]; then
            # Source is Trae - skip YAML header (first 6 lines)
            CONTENT=$(tail -n +7 "$SOURCE_FILE")
        else
            # Source is standard - use full content
            CONTENT=$(cat "$SOURCE_FILE")
        fi

        # Create QODER.md with YAML header + content
        {
            echo "$QODER_YAML_HEADER"
            echo "$CONTENT"
        } > "$target"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ OK (with Qoder YAML frontmatter)${NC}"
            ((SYNC_COUNT++))
        else
            echo -e "${RED}❌ FAILED${NC}"
            ((ERROR_COUNT++))
        fi

    # Special handling for Trae
    elif [ "$target" == ".trae/rules/00-system-manifest.md" ]; then
        # Ensure directory exists
        mkdir -p "$(dirname "$target")"

        # Extract content without YAML header from source
        if [ "$SOURCE_FILE" == ".qoder/rules/QODER.md" ]; then
            # Source is QODER.md - skip YAML header (first 4 lines)
            CONTENT=$(tail -n +5 "$SOURCE_FILE")
        elif [ "$SOURCE_FILE" == ".trae/rules/00-system-manifest.md" ]; then
            # Source is Trae - skip YAML header (first 6 lines)
            CONTENT=$(tail -n +7 "$SOURCE_FILE")
        else
            # Source is standard - use full content
            CONTENT=$(cat "$SOURCE_FILE")
        fi

        # Create Trae file with YAML header + content
        {
            echo "$TRAE_YAML_HEADER"
            echo "$CONTENT"
        } > "$target"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ OK (with Trae YAML frontmatter)${NC}"
            ((SYNC_COUNT++))
        else
            echo -e "${RED}❌ FAILED${NC}"
            ((ERROR_COUNT++))
        fi

    else
        # Standard file - direct copy (but strip YAML if source is QODER or Trae)
        if [ "$SOURCE_FILE" == ".qoder/rules/QODER.md" ]; then
            # Source is QODER.md - strip YAML header (skip first 4 lines)
            tail -n +5 "$SOURCE_FILE" > "$target"
        elif [ "$SOURCE_FILE" == ".trae/rules/00-system-manifest.md" ]; then
            # Source is Trae - strip YAML header (skip first 6 lines)
            tail -n +7 "$SOURCE_FILE" > "$target"
        else
            # Normal copy
            cp "$SOURCE_FILE" "$target"
        fi

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ OK${NC}"
            ((SYNC_COUNT++))
        else
            echo -e "${RED}❌ FAILED${NC}"
            ((ERROR_COUNT++))
        fi
    fi
done

echo ""
echo "================================================================"

if [ $ERROR_COUNT -eq 0 ]; then
    echo -e "${GREEN}✅ SYNCHRONIZATION SUCCESSFUL${NC}"
    echo "   Files synchronized: $SYNC_COUNT/${#DIFFERING_FILES[@]}"
    echo "   All files now identical to $SOURCE_FILE (most recently updated)"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Verify changes in synchronized files"
    echo "   2. Commit changes to git if needed"
    echo "   3. Continue work in any AI IDE environment"
else
    echo -e "${RED}❌ SYNCHRONIZATION COMPLETED WITH ERRORS${NC}"
    echo "   Successful: $SYNC_COUNT"
    echo "   Failed: $ERROR_COUNT"
    echo ""
    echo "⚠️  Please check error messages above and retry"
    exit 1
fi

echo "================================================================"
echo ""

# Show final status
echo "📊 Final Status:"
echo ""
printf "%-30s %-10s %-35s\n" "File" "Size" "MD5"
echo "--------------------------------------------------------------------------------"
printf "%-30s %-10s %-35s\n" "$SOURCE_FILE" "$SOURCE_SIZE" "$SOURCE_MD5"

for target in "${ALL_AI_IDE_FILES[@]}"; do
    if [ -f "$target" ]; then
        TARGET_SIZE=$(wc -c < "$target")
        TARGET_MD5=$(md5 -q "$target" 2>/dev/null || md5sum "$target" | cut -d' ' -f1)

        if [ "$SOURCE_MD5" == "$TARGET_MD5" ]; then
            if [[ " ${DIFFERING_FILES[@]} " =~ " $target " ]]; then
                printf "%-30s %-10s %-35s 🔄\n" "$target" "$TARGET_SIZE" "$TARGET_MD5"
            else
                printf "%-30s %-10s %-35s ✅\n" "$target" "$TARGET_SIZE" "$TARGET_MD5"
            fi
        else
            printf "%-30s %-10s %-35s ❌\n" "$target" "$TARGET_SIZE" "$TARGET_MD5"
        fi
    else
        printf "%-30s %-10s %-35s ❌ MISSING\n" "$target" "N/A" "N/A"
    fi
done

echo ""
echo "================================================================"
echo "✅ Intelligent synchronization complete!"
echo "================================================================"
