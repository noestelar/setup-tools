#!/usr/bin/env bash

set -e

DRY_RUN=false
VERBOSE=false
CLEANOSE=false
typeset -a SELECTED_TOOLS
OS_TYPE=""

LOG_FILE="install.log"
ERROR_LOG_FILE="error.log"

init_logs() {
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$ERROR_LOG_FILE")"
    : > "$LOG_FILE"
    : > "$ERROR_LOG_FILE"
    echo "Log files initialized"
}

show_help() {
    cat << EOF
Usage: ./install.sh [options]

Options:
    --dry-run           Show what would be installed without making changes
    --verbose           Show detailed output during installation
    --cleanup           Clean up caches after installation
    --select TOOL       Install only specific tools (can be used multiple times)
    --debug            Enable debug mode (shows all commands)
    --os OS            Force OS: macos or linux (auto-detected by default)
    --help             Show this help message

Example:
    ./install.sh --dry-run
    ./install.sh --select chrome --select slack
    ./install.sh --verbose --cleanup
    ./install.sh --os linux
EOF
}

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
                CLEANOSE=true
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
            --os)
                if [[ -z "$2" ]]; then
                    echo "Error: --os requires an argument (macos or linux)"
                    exit 1
                fi
                OS_TYPE="$2"
                echo "OS forced to: $OS_TYPE"
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

detect_os() {
    if [[ -n "$OS_TYPE" ]]; then
        return 0
    fi
    
    case "$(uname)" in
        Darwin)
            OS_TYPE="macos"
            ;;
        Linux)
            OS_TYPE="linux"
            ;;
        *)
            log_error "Unsupported operating system"
            exit 1
            ;;
    esac
    echo "Detected OS: $OS_TYPE"
}

check_system() {
    echo "Checking system..."
    detect_os
    echo "System check passed for $OS_TYPE"
}

declare -A macos_cask_tools=(
    [warp]="warp"
    [raycast]="raycast"
    [notion]="notion"
    [ghostty]="ghostty"
    [slack]="slack"
    [discord]="discord"
    [1password]="1password"
    [karabiner]="karabiner-elements"
    [keyboardcleantool]="keyboardcleantool"
    [gitkraken]="gitkraken"
    [vscode]="visual-studio-code"
    [docker]="docker"
    [orbstack]="orbstack"
)

declare -A macos_brew_tools=(
    [miniconda]="miniconda"
    [git]="git"
    [node]="node"
    [python]="python@3.13"
    [gh]="gh"
    [opencode]="opencode"
)

declare -A linux_apt_tools=(
    [warp]="warp"
    [ghostty]="ghostty"
    [notion]="notion"
    [slack]="slack"
    [discord]="discord"
    [1password]="1password"
    [gitkraken]="gitkraken"
    [vscode]="code"
    [docker]="docker.io"
    [git]="git"
    [gh]="gh"
    [opencode]="opencode"
)

declare -A linux_brew_tools=(
    [fnm]="fnm"
    [node]="nodejs"
)

install_tool_macos() {
    local tool="$1"
    local is_cask="$2"
    
    if [[ "$is_cask" == "true" ]]; then
        brew info --cask "$tool" &>/dev/null
    else
        brew info "$tool" &>/dev/null
    fi
}

install_tool_linux_apt() {
    local tool="$1"
    apt-cache show "$tool" &>/dev/null
}

install_tool_linux_brew() {
    local tool="$1"
    brew info "$tool" &>/dev/null
}

install_macos_tool() {
    local tool="$1"
    local is_cask="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would install ${is_cask:+cask: }$tool"
        return 0
    fi
    
    echo "Verifying $tool..."
    if ! install_tool_macos "$tool" "$is_cask"; then
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

install_linux_apt_tool() {
    local tool="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would install apt: $tool"
        return 0
    fi
    
    echo "Verifying $tool..."
    if ! install_tool_linux_apt "$tool"; then
        log_error "Package $tool not found in apt. Skipping."
        return 1
    fi
    
    echo "Installing $tool..."
    sudo apt-get update || {
        log_error "Failed to update apt"
        return 1
    }
    sudo apt-get install -y "$tool" || {
        log_error "$tool installation failed"
        return 1
    }
    echo "$tool installed successfully"
}

install_linux_brew_tool() {
    local tool="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would install brew: $tool"
        return 0
    fi
    
    if ! command -v brew &>/dev/null; then
        echo "Installing Homebrew on Linux..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
            log_error "Failed to install Homebrew"
            return 1
        }
        (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> ~/.bashrc
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    
    echo "Verifying $tool..."
    if ! install_tool_linux_brew "$tool"; then
        log_error "Package $tool not found in Homebrew. Skipping."
        return 1
    fi
    
    echo "Installing $tool..."
    brew install "$tool" || {
        log_error "$tool installation failed"
        return 1
    }
    echo "$tool installed successfully"
}

install_fnm_linux() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would install fnm"
        return 0
    fi
    
    if command -v fnm &>/dev/null; then
        echo "fnm already installed"
        return 0
    fi
    
    echo "Installing fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash
    
    if [[ -s "$HOME/.bashrc" ]]; then
        echo 'export PATH="$HOME/.local/share/fnm:$PATH"' >> ~/.bashrc
        echo 'eval "$(fnm env)"' >> ~/.bashrc
    fi
    
    fnm install --lts
    fnm default lts-latest
    
    echo "fnm installed successfully"
}

install_docker_linux() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would install Docker Engine"
        return 0
    fi
    
    if command -v docker &>/dev/null; then
        echo "Docker already installed"
        return 0
    fi
    
    echo "Installing Docker Engine..."
    
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    sudo usermod -aG docker "$USER"
    
    echo "Docker Engine installed successfully"
}

install_selected_macos_tools() {
    local tool_type="$3"
    echo "Starting installation of $tool_type on macOS..."
    
    local array_name="$1"
    local is_cask="$2"
    
    if (( ${#SELECTED_TOOLS[@]} > 0 )); then
        echo "Selected tools: ${SELECTED_TOOLS[*]}"
    else
        echo "Installing all available tools"
    fi
    
    case "$array_name" in
        "cask_tools")
            for key in "${!macos_cask_tools[@]}"; do
                if (( ${#SELECTED_TOOLS[@]} == 0 )) || [[ " ${SELECTED_TOOLS[*]} " == *" $key "* ]]; then
                    echo "Processing $key..."
                    install_macos_tool "${macos_cask_tools[$key]}" "$is_cask"
                fi
            done
            ;;
        "brew_tools")
            for key in "${!macos_brew_tools[@]}"; do
                if (( ${#SELECTED_TOOLS[@]} == 0 )) || [[ " ${SELECTED_TOOLS[*]} " == *" $key "* ]]; then
                    echo "Processing $key..."
                    install_macos_tool "${macos_brew_tools[$key]}" "$is_cask"
                fi
            done
            ;;
    esac
    
    echo "Completed installation of $tool_type"
}

install_selected_linux_tools() {
    echo "Starting installation of tools on Linux..."
    
    if (( ${#SELECTED_TOOLS[@]} > 0 )); then
        echo "Selected tools: ${SELECTED_TOOLS[*]}"
    else
        echo "Installing all available tools"
    fi
    
    for key in "${!linux_apt_tools[@]}"; do
        if (( ${#SELECTED_TOOLS[@]} == 0 )) || [[ " ${SELECTED_TOOLS[*]} " == *" $key "* ]]; then
            echo "Processing apt: $key..."
            install_linux_apt_tool "${linux_apt_tools[$key]}"
        fi
    done
    
    for key in "${!linux_brew_tools[@]}"; do
        if (( ${#SELECTED_TOOLS[@]} == 0 )) || [[ " ${SELECTED_TOOLS[*]} " == *" $key "* ]]; then
            echo "Processing brew: $key..."
            install_linux_brew_tool "${linux_brew_tools[$key]}"
        fi
    done
    
    if (( ${#SELECTED_TOOLS[@]} == 0 )) || [[ " ${SELECTED_TOOLS[*]} " == *" fnm "* ]]; then
        echo "Processing: fnm..."
        install_fnm_linux
    fi
    
    if (( ${#SELECTED_TOOLS[@]} == 0 )) || [[ " ${SELECTED_TOOLS[*]} " == *" docker "* ]]; then
        echo "Processing: docker..."
        install_docker_linux
    fi
    
    echo "Completed installation of Linux tools"
}

setup_homebrew_macos() {
    echo "Setting up Homebrew on macOS..."
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

setup_conda_macos() {
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

cleanup_macos() {
    if [[ "$CLEANOSE" == "true" ]]; then
        echo "Running cleanup..."
        if [[ "$DRY_RUN" == "false" ]]; then
            brew cleanup || log_error "Failed to clean up Homebrew cache"
        else
            echo "[DRY RUN] Would clean up Homebrew cache"
        fi
    fi
}

cleanup_linux() {
    if [[ "$CLEANOSE" == "true" ]]; then
        echo "Running cleanup..."
        if [[ "$DRY_RUN" == "false" ]]; then
            sudo apt-get autoremove -y || log_error "Failed to clean up apt cache"
            sudo apt-get autoclean -y || log_error "Failed to clean up apt cache"
        else
            echo "[DRY RUN] Would clean up apt cache"
        fi
    fi
}

main() {
    echo "Starting installation process..."
    
    parse_args "$@"
    init_logs
    check_system
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        setup_homebrew_macos
        echo "Installing tools..."
        install_selected_macos_tools cask_tools true "cask applications"
        install_selected_macos_tools brew_tools false "brew formulae"
        setup_conda_macos
        cleanup_macos
    elif [[ "$OS_TYPE" == "linux" ]]; then
        echo "Installing tools..."
        install_selected_linux_tools
        cleanup_linux
    fi
    
    echo "Installation process completed"
    echo "Check $ERROR_LOG_FILE for any errors"
}

main "$@"
