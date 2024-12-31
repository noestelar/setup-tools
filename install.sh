#!/usr/bin/env zsh

# Enable proper error handling
set -e

# Only enable debug mode if requested
[[ "$DEBUG" == "true" ]] && set -x

# Default modes
DRY_RUN=false
VERBOSE=false
CLEANUP=false
typeset -a SELECTED_TOOLS

# Log files
LOG_FILE="install.log"
ERROR_LOG_FILE="error.log"

# Initialize log files
init_logs() {
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$ERROR_LOG_FILE")"
    : > "$LOG_FILE"
    : > "$ERROR_LOG_FILE"
}

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

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    [[ "$VERBOSE" == "true" ]] && echo "Details: $2" | tee -a "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" | tee -a "$ERROR_LOG_FILE"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        key="$1"
        case "$key" in
            --dry-run)
                DRY_RUN=true
                ;;
            --verbose)
                VERBOSE=true
                ;;
            --cleanup)
                CLEANUP=true
                ;;
            --debug)
                set -x
                ;;
            --select)
                if [[ -z "$2" ]]; then
                    echo "Error: --select requires a tool name"
                    exit 1
                fi
                SELECTED_TOOLS+=("$2")
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown parameter: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# System check
check_system() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only. Exiting."
        exit 1
    fi
}

# Homebrew setup
setup_homebrew() {
    if ! command -v brew &>/dev/null; then
        log "Homebrew not found. Would install Homebrew..."
        if [[ "$DRY_RUN" == "false" ]]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
                log_error "Failed to install Homebrew. Exiting."
                exit 1
            }
            
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

# Tool definitions
typeset -A cask_tools=(
    [warp]="warp"
    [raycast]="raycast"
    [notion]="notion"
    [cursor]="cursor"
    [chatgpt]="chatgpt"
    [slack]="slack"
    [discord]="discord"
    [1password]="1password"
    [karabiner]="karabiner-elements"
    [keyboardcleantool]="keyboardcleantool"
    [gitkraken]="gitkraken"
    [paw]="paw"
    [vscode]="visual-studio-code"
    [docker]="docker"
)

typeset -A brew_tools=(
    [miniconda]="miniconda"
    [git]="git"
    [node]="node"
    [python]="python@3.11"
    [gh]="gh"
)

# Tool verification and installation
verify_tool() {
    local tool="$1"
    local is_cask="$2"
    
    if [[ "$is_cask" == "true" ]]; then
        brew info --cask "$tool" &>/dev/null
    else
        brew info "$tool" &>/dev/null
    fi
}

install_tool() {
    local tool="$1"
    local is_cask="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ "$is_cask" == "true" ]]; then
            log "[DRY RUN] Would install cask: $tool"
        else
            log "[DRY RUN] Would install formula: $tool"
        fi
        return 0
    fi
    
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
    local tool_type="$3"
    log "Installing $tool_type..."
    
    local -n tools="$1"
    local is_cask="$2"
    
    for key in "${(@k)tools}"; do
        if [[ ${#SELECTED_TOOLS[@]} -eq 0 ]] || [[ " ${SELECTED_TOOLS[*]} " == *" $key "* ]]; then
            install_tool "${tools[$key]}" "$is_cask"
        fi
    done
}

# Conda setup
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

# Cleanup
cleanup() {
    if [[ "$CLEANUP" == "true" ]] && [[ "$DRY_RUN" == "false" ]]; then
        log "Cleaning up..."
        brew cleanup || log_error "Failed to clean up Homebrew cache"
    fi
}

# Completion message
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
    
    install_selected_tools cask_tools true "cask applications"
    install_selected_tools brew_tools false "brew formulae"
    
    setup_conda
    cleanup
    
    log "Installation process completed."
    echo "Check $ERROR_LOG_FILE for errors, if any."
    show_completion_message
}

main "$@"