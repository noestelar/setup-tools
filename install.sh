#!/usr/bin/env zsh

# Enable proper error handling
set -e

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
    echo "Log files initialized"
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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    if [[ "$VERBOSE" == "true" && -n "$2" ]]; then
        echo "Details: $2"
        echo "Details: $2" >> "$LOG_FILE"
    fi
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" | tee -a "$ERROR_LOG_FILE"
}

# Parse command line arguments
parse_args() {
    echo "Parsing arguments..."
    while [[ $# -gt 0 ]]; do
        key="$1"
        case "$key" in
            --dry-run)
                DRY_RUN=true
                echo "Dry run mode enabled"
                ;;
            --verbose)
                VERBOSE=true
                echo "Verbose mode enabled"
                ;;
            --cleanup)
                CLEANUP=true
                echo "Cleanup mode enabled"
                ;;
            --debug)
                set -x
                echo "Debug mode enabled"
                ;;
            --select)
                if [[ -z "$2" ]]; then
                    echo "Error: --select requires a tool name"
                    exit 1
                fi
                SELECTED_TOOLS+=("$2")
                echo "Added $2 to selected tools"
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
    echo "Checking system..."
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only. Exiting."
        exit 1
    fi
    echo "System check passed"
}

# Tool definitions
declare -A cask_tools=(
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
    [orbstack]="orbstack"
)

declare -A brew_tools=(
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
        echo "[DRY RUN] Would install ${is_cask:+cask: }$tool"
        return 0
    fi
    
    echo "Verifying $tool..."
    if ! verify_tool "$tool" "$is_cask"; then
        log_error "Package $tool not found in Homebrew. Skipping."
        return 1
    fi
    
    echo "Installing $tool..."
    if [[ "$is_cask" == "true" ]]; then
        brew install --cask "$tool" || {
            log_error "$tool installation failed"
            return 1
        }
    else
        brew install "$tool" || {
            log_error "$tool installation failed"
            return 1
        }
    fi
    echo "$tool installed successfully"
}

install_selected_tools() {
    local tool_type="$3"
    echo "Starting installation of $tool_type..."
    
    # Get the array name without -n reference
    local array_name="$1"
    local is_cask="$2"
    
    # Print selected tools if any
    if (( ${#SELECTED_TOOLS[@]} > 0 )); then
        echo "Selected tools: ${SELECTED_TOOLS[*]}"
    else
        echo "Installing all available tools"
    fi
    
    # Access the array using the name
    case "$array_name" in
        "cask_tools")
            for key in "${(@k)cask_tools}"; do
                if (( ${#SELECTED_TOOLS[@]} == 0 )) || [[ " ${SELECTED_TOOLS[*]} " == *" $key "* ]]; then
                    echo "Processing $key..."
                    install_tool "${cask_tools[$key]}" "$is_cask"
                fi
            done
            ;;
        "brew_tools")
            for key in "${(@k)brew_tools}"; do
                if (( ${#SELECTED_TOOLS[@]} == 0 )) || [[ " ${SELECTED_TOOLS[*]} " == *" $key "* ]]; then
                    echo "Processing $key..."
                    install_tool "${brew_tools[$key]}" "$is_cask"
                fi
            done
            ;;
    esac
    
    echo "Completed installation of $tool_type"
}

# Homebrew setup
setup_homebrew() {
    echo "Setting up Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found. Installing..."
        if [[ "$DRY_RUN" == "false" ]]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
                log_error "Failed to install Homebrew"
                exit 1
            }
            
            if [[ "$(uname -m)" == "arm64" ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
        fi
        echo "Homebrew installation completed"
    else
        echo "Homebrew found. Updating..."
        if [[ "$DRY_RUN" == "false" ]]; then
            brew update || log_error "Failed to update Homebrew"
            brew upgrade || log_error "Failed to upgrade Homebrew packages"
        fi
        echo "Homebrew update completed"
    fi
}

# Conda setup
setup_conda() {
    echo "Checking conda..."
    if command -v conda &>/dev/null; then
        echo "Initializing conda..."
        if [[ "$DRY_RUN" == "false" ]]; then
            conda init "$(basename "$SHELL")" || log_error "Failed to initialize conda"
        else
            echo "[DRY RUN] Would initialize conda"
        fi
    fi
}

# Cleanup
cleanup() {
    if [[ "$CLEANUP" == "true" ]]; then
        echo "Running cleanup..."
        if [[ "$DRY_RUN" == "false" ]]; then
            brew cleanup || log_error "Failed to clean up Homebrew cache"
        else
            echo "[DRY RUN] Would clean up Homebrew cache"
        fi
    fi
}

# Main execution
main() {
    echo "Starting installation process..."
    
    parse_args "$@"
    init_logs
    check_system
    setup_homebrew
    
    echo "Installing tools..."
    install_selected_tools cask_tools true "cask applications"
    install_selected_tools brew_tools false "brew formulae"
    
    setup_conda
    cleanup
    
    echo "Installation process completed"
    echo "Check $ERROR_LOG_FILE for any errors"
}

# Execute main
main "$@"