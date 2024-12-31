#!/usr/bin/env zsh

# Script to install tools and languages using Homebrew
# Handles failures gracefully and logs errors.

# Only enable debug mode if requested
if [[ "$DEBUG" == "true" ]]; then
    set -x
fi

# Default modes
DRY_RUN=false
VERBOSE=false
CLEANUP=false
SELECTED_TOOLS=()

# Log files
LOG_FILE="install.log"
ERROR_LOG_FILE="error.log"

# Help message
show_help() {
    cat << EOF
Usage: ./install.sh [options]

Options:
    --dry-run           Show what would be installed without making changes
    --verbose           Show detailed output during installation
    --cleanup           Clean up caches after installation
    --select TOOL       Install only specific tools (can be used multiple times)
    --debug            Enable debug mode (shows all commands)
    --help             Show this help message

Example:
    ./install.sh --dry-run
    ./install.sh --select chrome --select slack
    ./install.sh --verbose --cleanup
EOF
}

# Functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    if [[ "$VERBOSE" == "true" ]]; then
        echo "Details: $2" | tee -a "$LOG_FILE"
    fi
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" | tee -a "$ERROR_LOG_FILE"
}

# Initialize log files
init_logs() {
    # Create logs directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$ERROR_LOG_FILE")"
    > "$LOG_FILE"
    > "$ERROR_LOG_FILE"
}

# Parse command line arguments
parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --dry-run) DRY_RUN=true ;;
            --verbose) VERBOSE=true ;;
            --cleanup) CLEANUP=true ;;
            --debug) DEBUG=true; set -x ;;
            --select) 
                if [[ -z "$2" ]]; then
                    echo "Error: --select requires a tool name"
                    exit 1
                fi
                SELECTED_TOOLS+=("$2")
                shift 
                ;;
            --help) show_help; exit 0 ;;
            *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
        esac
        shift
    done
}

# Check system requirements
check_system() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only. Exiting."
        exit 1
    fi
}

# Install or update Homebrew
setup_homebrew() {
    if ! command -v brew &>/dev/null; then
        log "Homebrew not found. Would install Homebrew..."
        if [[ "$DRY_RUN" == "false" ]]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
                log_error "Failed to install Homebrew. Exiting."
                exit 1
            }
            
            # Add Homebrew to PATH for Apple Silicon Macs
            if [[ "$(uname -m)" == "arm64" ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
            
            log "Homebrew installed successfully."
        fi
    else
        log "Homebrew already installed. Would update..."
        if [[ "$DRY_RUN" == "false" ]]; then
            brew update || log_error "Failed to update Homebrew."
            brew upgrade || log_error "Failed to upgrade Homebrew packages."
            log "Homebrew is up to date."
        fi
    fi
}

# Tools to install (separated by installation method)
declare -A cask_tools=(
    ["warp"]="warp"
    ["raycast"]="raycast"
    ["notion"]="notion"
    ["cursor"]="cursor"
    ["chatgpt"]="chatgpt"
    ["slack"]="slack"
    ["discord"]="discord"
    ["1password"]="1password"
    ["karabiner"]="karabiner-elements"
    ["keyboardcleantool"]="keyboardcleantool"
    ["gitkraken"]="gitkraken"
    ["paw"]="paw"
    ["vscode"]="visual-studio-code"
    ["docker"]="docker"
)

declare -A brew_tools=(
    ["miniconda"]="miniconda"
    ["git"]="git"
    ["node"]="node"
    ["python"]="python@3.11"
    ["gh"]="gh"
)

verify_tool() {
    local tool=$1
    local is_cask=$2
    
    if [[ "$is_cask" == "true" ]]; then
        brew info --cask "$tool" &>/dev/null
    else
        brew info "$tool" &>/dev/null
    fi
    return $?
}

install_tool() {
    local tool=$1
    local is_cask=$2
    
    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ "$is_cask" == "true" ]]; then
            log "[DRY RUN] Would install cask: $tool"
        else
            log "[DRY RUN] Would install formula: $tool"
        fi
        return 0
    fi
    
    # Verify package exists
    if ! verify_tool "$tool" "$is_cask"; then
        log_error "Package $tool not found in Homebrew. Skipping."
        return 1
    fi
    
    log "Installing $tool..."
    local output
    if [[ "$is_cask" == "true" ]]; then
        if output=$(brew install --cask "$tool" 2>&1); then
            log "$tool installed successfully." "$output"
        else
            log_error "$tool installation failed. Skipping to next item."
            [[ "$VERBOSE" == "true" ]] && echo "$output" >> "$ERROR_LOG_FILE"
        fi
    else
        if output=$(brew install "$tool" 2>&1); then
            log "$tool installed successfully." "$output"
        else
            log_error "$tool installation failed. Skipping to next item."
            [[ "$VERBOSE" == "true" ]] && echo "$output" >> "$ERROR_LOG_FILE"
        fi
    fi
}

install_selected_tools() {
    local -n tools=$1
    local is_cask=$2
    local type=$3
    
    log "Installing $type..."
    for key in "${(@k)tools}"; do
        if [[ ${#SELECTED_TOOLS[@]} -eq 0 ]] || [[ " ${SELECTED_TOOLS[@]} " =~ " ${key} " ]]; then
            install_tool "${tools[$key]}" "$is_cask"
        fi
    done
}

setup_conda() {
    if command -v conda &>/dev/null; then
        log "Initializing conda..."
        if [[ "$DRY_RUN" == "false" ]]; then
            conda init "$(basename "$SHELL")" || log_error "Failed to initialize conda"
        else
            log "[DRY RUN] Would initialize conda"
        fi
    fi
}

cleanup() {
    if [[ "$CLEANUP" == "true" ]] && [[ "$DRY_RUN" == "false" ]]; then
        log "Cleaning up..."
        brew cleanup || log_error "Failed to clean up Homebrew cache"
    fi
}

show_completion_message() {
    cat << EOF

🎉 Installation completed! Here are some additional steps you might want to take:

1. Set up SSH keys for GitHub:
   ssh-keygen -t ed25519 -C "your_email@example.com"

2. Configure Git:
   git config --global user.name "Your Name"
   git config --global user.email "your_email@example.com"

3. Install Oh My Zsh (if you want):
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

4. Configure your terminal preferences in iTerm2/Warp

5. Set up Rectangle window management preferences

For more details, check the documentation of each tool installed.
EOF
}

# Main execution
main() {
    parse_args "$@"
    init_logs
    check_system
    setup_homebrew
    
    # Install tools
    install_selected_tools cask_tools true "cask applications"
    install_selected_tools brew_tools false "brew formulae"
    
    setup_conda
    cleanup
    
    log "Installation process completed."
    echo "Check $ERROR_LOG_FILE for errors, if any."
    show_completion_message
}

# Execute main function with all arguments
main "$@"