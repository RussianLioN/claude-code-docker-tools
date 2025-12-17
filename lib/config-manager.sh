#!/bin/bash
# Configuration Manager Library
# Manages AI Assistant configurations with templates and project-specific settings

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Global variables
CONFIG_DIR="$(pwd)/config"
TEMPLATES_DIR="${CONFIG_DIR}/templates"
ACTIVE_DIR="${CONFIG_DIR}/active"
WORKSPACE_DIR="$(pwd)/workspace"
BACKUPS_DIR="$(pwd)/backups"

# Logging functions
log_config() {
    echo -e "${GREEN}[CONFIG]${NC} $1"
}

log_config_error() {
    echo -e "${RED}[CONFIG-ERROR]${NC} $1" >&2
}

log_config_warn() {
    echo -e "${YELLOW}[CONFIG-WARN]${NC} $1" >&2
}

# Initialize configuration directories
init_config_dirs() {
    log_config "Initializing configuration directories..."
    
    local dirs=("$TEMPLATES_DIR" "$ACTIVE_DIR" "$WORKSPACE_DIR" "$BACKUPS_DIR")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_config "Created directory: $dir"
        fi
    done
    
    # Create mode-specific directories
    for mode in claude gemini glm; do
        mkdir -p "${ACTIVE_DIR}/${mode}"
        mkdir -p "${WORKSPACE_DIR}/${mode}"
        mkdir -p "${BACKUPS_DIR}/${mode}"
    done
}

# Copy template configuration to active
copy_template_config() {
    local mode="$1"
    local template_file="${TEMPLATES_DIR}/${mode}-development.yml"
    local active_file="${ACTIVE_DIR}/${mode}.yml"
    
    if [[ ! -f "$template_file" ]]; then
        log_config_error "Template not found: $template_file"
        return 1
    fi
    
    if [[ -f "$active_file" ]]; then
        log_config_warn "Active configuration already exists: $active_file"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_config "Keeping existing configuration"
            return 0
        fi
    fi
    
    log_config "Copying template for ${mode}..."
    cp "$template_file" "$active_file"
    
    # Customize with project-specific values
    customize_config "$mode" "$active_file"
    
    log_config "Configuration ready: $active_file"
}

# Customize configuration with project-specific values
customize_config() {
    local mode="$1"
    local config_file="$2"
    
    log_config "Customizing ${mode} configuration..."
    
    # Add project-specific metadata
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname)
    local user=$(whoami)
    
    # Create backup of original
    cp "$config_file" "${config_file}.backup"
    
    # Add project metadata (basic YAML manipulation)
    {
        echo ""
        echo "# Project-specific metadata"
        echo "project:"
        echo "  name: \"$(basename "$(pwd)")\""
        echo "  created_at: \"${timestamp}\""
        echo "  hostname: \"${hostname}\""
        echo "  user: \"${user}\""
        echo "  workspace_dir: \"${WORKSPACE_DIR}/${mode}\""
    } >> "$config_file"
}

# Load configuration
load_config() {
    local mode="$1"
    local config_file="${ACTIVE_DIR}/${mode}.yml"
    
    if [[ ! -f "$config_file" ]]; then
        log_config_warn "Configuration not found: $config_file"
        log_config "Creating from template..."
        copy_template_config "$mode"
    fi
    
    # Source configuration (basic implementation)
    if [[ -f "$config_file" ]]; then
        log_config "Loading configuration: $config_file"
        
        # Parse YAML and export as environment variables (basic)
        export AI_MODE="$mode"
        export AI_CONFIG_FILE="$config_file"
        
        # Extract resource limits
        local memory_limit=$(grep -A1 "memory_limit:" "$config_file" | tail -1 | sed 's/.*: *//' | tr -d '"')
        local cpu_limit=$(grep -A1 "cpu_limit:" "$config_file" | tail -1 | sed 's/.*: *//' | tr -d '"')
        local pids_limit=$(grep -A1 "pids_limit:" "$config_file" | tail -1 | sed 's/.*: *//' | tr -d '"')
        
        export AI_MEMORY_LIMIT="${memory_limit:-512m}"
        export AI_CPU_LIMIT="${cpu_limit:-0.5}"
        export AI_PIDS_LIMIT="${pids_limit:-100}"
        
        # Extract model information
        local model=$(grep "model:" "$config_file" | head -1 | sed 's/.*: *//' | tr -d '"')
        export AI_MODEL="${model:-${mode}-latest}"
        
        log_config "Configuration loaded successfully"
        return 0
    else
        log_config_error "Failed to load configuration for ${mode}"
        return 1
    fi
}

# Validate configuration
validate_config() {
    local mode="$1"
    local config_file="${ACTIVE_DIR}/${mode}.yml"
    
    log_config "Validating ${mode} configuration..."
    
    if [[ ! -f "$config_file" ]]; then
        log_config_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Basic YAML validation
    if ! grep -q "ai_mode:" "$config_file"; then
        log_config_error "Missing ai_mode in configuration"
        return 1
    fi
    
    if ! grep -q "resources:" "$config_file"; then
        log_config_error "Missing resources section in configuration"
        return 1
    fi
    
    if ! grep -q "workspace:" "$config_file"; then
        log_config_error "Missing workspace section in configuration"
        return 1
    fi
    
    log_config "Configuration validation passed"
    return 0
}

# Show configuration
show_config() {
    local mode="${1:-all}"
    
    if [[ "$mode" == "all" ]]; then
        log_config "All configurations:"
        for config_file in "${ACTIVE_DIR}"/*.yml; do
            if [[ -f "$config_file" ]]; then
                local mode_name=$(basename "$config_file" .yml)
                echo ""
                echo "=== ${mode_name^} Configuration ==="
                cat "$config_file"
            fi
        done
    else
        local config_file="${ACTIVE_DIR}/${mode}.yml"
        if [[ -f "$config_file" ]]; then
            log_config "Showing ${mode} configuration:"
            cat "$config_file"
        else
            log_config_error "Configuration not found: $config_file"
            return 1
        fi
    fi
}

# Reset configuration to template
reset_config() {
    local mode="$1"
    local active_file="${ACTIVE_DIR}/${mode}.yml"
    local backup_file="${active_file}.backup"
    
    log_config "Resetting ${mode} configuration..."
    
    # Create backup if exists
    if [[ -f "$active_file" ]]; then
        mv "$active_file" "$backup_file"
        log_config "Backup created: $backup_file"
    fi
    
    # Copy fresh template
    copy_template_config "$mode"
    log_config "Configuration reset completed"
}

# Backup configurations
backup_configs() {
    local backup_dir="${BACKUPS_DIR}/configurations/$(date +%Y%m%d_%H%M%S)"
    
    log_config "Creating configuration backup..."
    mkdir -p "$backup_dir"
    
    # Backup all active configurations
    for config_file in "${ACTIVE_DIR}"/*.yml; do
        if [[ -f "$config_file" ]]; then
            cp "$config_file" "$backup_dir/"
            log_config "Backed up: $(basename "$config_file")"
        fi
    done
    
    # Create archive
    local archive_file="${BACKUPS_DIR}/configurations/config-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$archive_file" -C "$backup_dir" .
    
    log_config "Configuration backup created: $archive_file"
}

# Restore configurations
restore_configs() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        log_config_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_config "Restoring configurations from: $backup_file"
    
    # Extract to temporary directory
    local temp_dir="/tmp/ai-config-restore-$(date +%s)"
    mkdir -p "$temp_dir"
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Restore configurations
    for config_file in "$temp_dir"/*.yml; do
        if [[ -f "$config_file" ]]; then
            local mode_name=$(basename "$config_file" .yml)
            local target_file="${ACTIVE_DIR}/${mode_name}.yml"
            
            # Backup existing
            if [[ -f "$target_file" ]]; then
                mv "$target_file" "${target_file}.backup.$(date +%s)"
            fi
            
            # Restore
            mv "$config_file" "$target_file"
            log_config "Restored: ${mode_name}.yml"
        fi
    done
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_config "Configuration restore completed"
}

# List available templates
list_templates() {
    log_config "Available configuration templates:"
    
    for template_file in "${TEMPLATES_DIR}"/*.yml; do
        if [[ -f "$template_file" ]]; then
            local template_name=$(basename "$template_file" .yml)
            local mode_name=${template_name%-development}
            local status="available"
            
            if [[ -f "${ACTIVE_DIR}/${mode_name}.yml" ]]; then
                status="active"
            fi
            
            echo "  ${template_name}: ${status}"
        fi
    done
}

# Export functions
export -f init_config_dirs
export -f copy_template_config
export -f customize_config
export -f load_config
export -f validate_config
export -f show_config
export -f reset_config
export -f backup_configs
export -f restore_configs
export -f list_templates