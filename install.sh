#!/usr/bin/env zsh

# Do not use set -e; individual failures must not abort the full run

DRY_RUN=false
VERBOSE=false
CLEANUP=false
OS_TYPE=""

LOG_FILE="install.log"
ERROR_LOG_FILE="error.log"

typeset -a SELECTED_TOOLS=()

typeset -g APT_UPDATED=false
typeset -g BREW_READY=unknown
typeset -g BREW_UPDATED=false
typeset -g FLATPAK_READY=false
typeset -g PACMAN_READY=unknown
typeset -g PACMAN_SYNCED=false

show_help() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
    --dry-run           Show what would be installed without making changes
    --verbose           Show detailed output during installation
    --cleanup           Clean up caches after installation
    --select TOOL       Install only specific tools (can be used multiple times)
    --debug             Enable debug mode (shows all commands)
    --os OS             Force OS: macos, linux, bazzite, or archlike
    --help              Show this help message

Bazzite experimental selectors:
    --select kwin-mcp-experimental   Install kwin-mcp via uv (NOT default; may be unstable)

Example:
    ./install.sh --dry-run
    ./install.sh --select warp --select slack
    ./install.sh --select kwin-mcp-experimental --os bazzite
    ./install.sh --verbose --cleanup
    ./install.sh --os archlike
EOF
}

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "$timestamp - $1"
    echo "$timestamp - $1" >> "$LOG_FILE"
    if [[ "$VERBOSE" == "true" && -n "$2" ]]; then
        echo "Details: $2"
        echo "Details: $2" >> "$LOG_FILE"
    fi
}

log_error() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "$timestamp - ERROR: $1" | tee -a "$ERROR_LOG_FILE"
}

init_logs() {
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$ERROR_LOG_FILE")"
    : > "$LOG_FILE"
    : > "$ERROR_LOG_FILE"
    echo "Log files initialized"
}

is_supported_os() {
    case "$1" in
        archlike|bazzite|linux|macos)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

parse_args() {
    echo "Parsing arguments..."
    while [[ $# -gt 0 ]]; do
        case "$1" in
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
            --os)
                if [[ -z "$2" ]]; then
                    echo "Error: --os requires an argument (macos, linux, bazzite, or archlike)"
                    exit 1
                fi
                if ! is_supported_os "$2"; then
                    echo "Error: unsupported OS '$2'"
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

os_release_field() {
    local key="$1"
    local value=""

    if [[ -r /etc/os-release ]]; then
        value="$(awk -F= -v key="$key" '$1 == key { print $2; exit }' /etc/os-release 2>/dev/null)"
        value="${value#\"}"
        value="${value%\"}"
    fi

    print -r -- "$value"
}

detect_os() {
    if [[ -n "$OS_TYPE" ]]; then
        return 0
    fi

    case "$(uname -s)" in
        Darwin)
            OS_TYPE="macos"
            ;;
        Linux)
            if command -v rpm-ostree >/dev/null 2>&1; then
                OS_TYPE="bazzite"
            else
                local distro_id
                local distro_like
                local distro_tags

                distro_id="$(os_release_field ID)"
                distro_like="$(os_release_field ID_LIKE)"
                distro_tags="${distro_id:l} ${distro_like:l}"

                if [[ "$distro_tags" == *arch* ]] || [[ "$distro_tags" == *cachyos* ]]; then
                    OS_TYPE="archlike"
                else
                    OS_TYPE="linux"
                fi
            fi
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

typeset -A macos_cask_tools=(
    [1password]="1password"
    [discord]="discord"
    [docker]="docker"
    [ghostty]="ghostty"
    [gitkraken]="gitkraken"
    [karabiner]="karabiner-elements"
    [keyboardcleantool]="keyboardcleantool"
    [notion]="notion"
    [orbstack]="orbstack"
    [raycast]="raycast"
    [slack]="slack"
    [vscode]="visual-studio-code"
    [warp]="warp"
)

typeset -A macos_brew_tools=(
    [gh]="gh"
    [git]="git"
    [miniconda]="miniconda"
    [node]="node"
    [opencode]="opencode"
    [python]="python@3.13"
)

typeset -A linux_apt_tools=(
    [docker]="docker.io"
    [gh]="gh"
    [git]="git"
    [node]="nodejs"
    [python]="python3"
)

typeset -A linux_brew_tools=(
    [fnm]="fnm"
    [ghostty]="ghostty"
    [miniconda]="miniconda"
    [opencode]="opencode"
)

typeset -A linux_flatpak_tools=(
    [1password]="com.onepassword.OnePassword"
    [discord]="com.discordapp.Discord"
    [gitkraken]="com.axosoft.GitKraken"
    [slack]="com.slack.Slack"
    [vscode]="com.visualstudio.code"
    [warp]="dev.warp.Warp"
)

typeset -A bazzite_brew_tools=(
    [fnm]="fnm"
    [gh]="gh"
    [ghostty]="ghostty"
    [git]="git"
    [miniconda]="miniconda"
    [node]="node"
    [opencode]="opencode"
    [python]="python@3.13"
)

typeset -A bazzite_experimental_tools=(
    [kwin-mcp-experimental]="kwin-mcp"
)

typeset -A bazzite_flatpak_tools=(
    [1password]="com.onepassword.OnePassword"
    [discord]="com.discordapp.Discord"
    [gitkraken]="com.axosoft.GitKraken"
    [slack]="com.slack.Slack"
    [vscode]="com.visualstudio.code"
    [warp]="dev.warp.Warp"
)

typeset -A archlike_aur_tools=(
    [fnm]="fnm"
    [miniconda]="miniconda3"
)

typeset -A archlike_brew_tools=(
    [opencode]="opencode"
)

typeset -A archlike_flatpak_tools=(
    [1password]="com.onepassword.OnePassword"
    [gitkraken]="com.axosoft.GitKraken"
    [slack]="com.slack.Slack"
    [warp]="dev.warp.Warp"
)

typeset -A archlike_pacman_tools=(
    [discord]="discord"
    [docker]="docker"
    [gh]="github-cli"
    [git]="git"
    [ghostty]="ghostty"
    [node]="nodejs"
    [python]="python"
    [vscode]="code"
)

should_install_tool() {
    local requested="$1"
    local selected

    if (( ${#SELECTED_TOOLS[@]} == 0 )); then
        return 0
    fi

    for selected in "${SELECTED_TOOLS[@]}"; do
        if [[ "$selected" == "$requested" ]]; then
            return 0
        fi
    done

    return 1
}

contains_value() {
    local needle="$1"
    shift

    local value
    for value in "$@"; do
        if [[ "$value" == "$needle" ]]; then
            return 0
        fi
    done

    return 1
}

report_unavailable_selected_tools() {
    local mode="$1"
    shift

    if (( ${#SELECTED_TOOLS[@]} == 0 )); then
        return 0
    fi

    local selected
    for selected in "${SELECTED_TOOLS[@]}"; do
        if ! contains_value "$selected" "$@"; then
            log_error "Tool '$selected' is not available in $mode mode."
        fi
    done
}

announce_selection() {
    if (( ${#SELECTED_TOOLS[@]} > 0 )); then
        echo "Selected tools: ${SELECTED_TOOLS[*]}"
    else
        echo "Installing all available tools"
    fi
}

ensure_homebrew_ready() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    if [[ "$BREW_READY" == "false" ]]; then
        return 1
    fi

    if [[ "$BREW_READY" == "unknown" ]]; then
        if ! command -v brew >/dev/null 2>&1; then
            log_error "Homebrew is not installed. Skipping brew-managed tools."
            BREW_READY=false
            return 1
        fi
        BREW_READY=true
    fi

    if [[ "$BREW_UPDATED" == "false" ]]; then
        brew update || log_error "Failed to update Homebrew"
        brew upgrade || log_error "Failed to upgrade Homebrew packages"
        BREW_UPDATED=true
    fi

    return 0
}

install_brew_tool() {
    local tool="$1"
    local is_cask="${2:-false}"
    local label="brew"

    if [[ "$is_cask" == "true" ]]; then
        label="brew cask"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would install $label: $tool"
        return 0
    fi

    ensure_homebrew_ready || return 1

    echo "Verifying $tool..."
    if [[ "$is_cask" == "true" ]]; then
        brew info --cask "$tool" >/dev/null 2>&1 || {
            log_error "Package $tool not found in Homebrew Cask. Skipping."
            return 1
        }
    else
        brew info "$tool" >/dev/null 2>&1 || {
            log_error "Package $tool not found in Homebrew. Skipping."
            return 1
        }
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

ensure_apt_ready() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "apt-get is not available. Skipping apt-managed tools."
        return 1
    fi

    if [[ "$APT_UPDATED" == "false" ]]; then
        sudo apt-get update || {
            log_error "Failed to update apt"
            return 1
        }
        APT_UPDATED=true
    fi

    return 0
}

install_apt_tool() {
    local tool="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would install apt: $tool"
        return 0
    fi

    ensure_apt_ready || return 1

    echo "Verifying $tool..."
    apt-cache show "$tool" >/dev/null 2>&1 || {
        log_error "Package $tool not found in apt. Skipping."
        return 1
    }

    echo "Installing $tool..."
    sudo apt-get install -y "$tool" || {
        log_error "$tool installation failed"
        return 1
    }

    echo "$tool installed successfully"
}

ensure_pacman_ready() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    if [[ "$PACMAN_READY" == "false" ]]; then
        return 1
    fi

    if [[ "$PACMAN_READY" == "unknown" ]]; then
        if ! command -v pacman >/dev/null 2>&1; then
            log_error "pacman is not available. Skipping pacman-managed tools."
            PACMAN_READY=false
            return 1
        fi
        PACMAN_READY=true
    fi

    if [[ "$PACMAN_SYNCED" == "false" ]]; then
        sudo pacman -Syu --noconfirm || {
            log_error "Failed to synchronize pacman packages"
            return 1
        }
        PACMAN_SYNCED=true
    fi

    return 0
}

install_pacman_tool() {
    local tool="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would install pacman: $tool"
        return 0
    fi

    ensure_pacman_ready || return 1

    echo "Verifying $tool..."
    pacman -Si "$tool" >/dev/null 2>&1 || {
        log_error "Package $tool not found in pacman. Skipping."
        return 1
    }

    echo "Installing $tool..."
    sudo pacman -S --needed --noconfirm "$tool" || {
        log_error "$tool installation failed"
        return 1
    }

    echo "$tool installed successfully"
}

detect_aur_helper() {
    if command -v paru >/dev/null 2>&1; then
        print -r -- "paru"
        return 0
    fi

    if command -v yay >/dev/null 2>&1; then
        print -r -- "yay"
        return 0
    fi

    return 1
}

install_aur_tool() {
    local tool="$1"
    local helper=""

    if helper="$(detect_aur_helper)"; then
        :
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ -n "$helper" ]]; then
            echo "[DRY RUN] Would install AUR via $helper: $tool"
        else
            echo "[DRY RUN] Would install AUR: $tool (requires paru or yay)"
        fi
        return 0
    fi

    if [[ -z "$helper" ]]; then
        log_error "No AUR helper (paru or yay) found. Skipping $tool."
        return 1
    fi

    echo "Verifying $tool..."
    "$helper" -Si "$tool" >/dev/null 2>&1 || {
        log_error "Package $tool not found in AUR. Skipping."
        return 1
    }

    echo "Installing $tool via $helper..."
    "$helper" -S --needed --noconfirm "$tool" || {
        log_error "$tool installation failed"
        return 1
    }

    echo "$tool installed successfully"
}

ensure_flatpak_ready() {
    local bootstrapper="${1:-none}"

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    if [[ "$FLATPAK_READY" == "true" ]]; then
        return 0
    fi

    if ! command -v flatpak >/dev/null 2>&1; then
        case "$bootstrapper" in
            apt)
                ensure_apt_ready || return 1
                echo "Installing flatpak..."
                sudo apt-get install -y flatpak || {
                    log_error "Failed to install flatpak"
                    return 1
                }
                ;;
            pacman)
                ensure_pacman_ready || return 1
                echo "Installing flatpak..."
                sudo pacman -S --needed --noconfirm flatpak || {
                    log_error "Failed to install flatpak"
                    return 1
                }
                ;;
            none)
                log_error "Flatpak is not installed. Skipping flatpak-managed tools."
                return 1
                ;;
            *)
                log_error "Unknown flatpak bootstrapper '$bootstrapper'"
                return 1
                ;;
        esac
    fi

    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || {
        log_error "Failed to configure the flathub remote"
        return 1
    }

    FLATPAK_READY=true
    return 0
}

install_flatpak_tool() {
    local tool="$1"
    local bootstrapper="${2:-none}"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would install flatpak: $tool"
        return 0
    fi

    ensure_flatpak_ready "$bootstrapper" || return 1

    echo "Verifying $tool..."
    flatpak remote-info flathub "$tool" >/dev/null 2>&1 || {
        log_error "Package $tool not found in flathub. Skipping."
        return 1
    }

    echo "Installing $tool..."
    flatpak install -y flathub "$tool" || {
        log_error "$tool flatpak installation failed"
        return 1
    }

    echo "$tool installed successfully"
}

install_bazzite_kwin_mcp_experimental() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would install kwin-mcp via uv tool"
        echo "[DRY RUN] Would run: uv tool install kwin-mcp --python /usr/bin/python3"
        return 0
    fi

    echo "Installing kwin-mcp experimental setup..."

    if ! command -v uv >/dev/null 2>&1; then
        echo "uv not found. Installing via Homebrew..."
        install_brew_tool "uv" false || {
            log_error "Unable to install uv; skipping kwin-mcp"
            return 1
        }
    fi

    uv tool install kwin-mcp --python /usr/bin/python3 || {
        echo "kwin-mcp already installed or install failed; trying upgrade..."
        uv tool upgrade kwin-mcp || {
            log_error "kwin-mcp install/upgrade failed"
            return 1
        }
    }

    cat <<'NOTE'
kwin-mcp installed (experimental).
Important on Bazzite/KDE:
  - If you hit session_start segfaults, install/update system deps via rpm-ostree and reboot.
  - Keep wrapper scripts (kwin-mcp-run / kwin-mcp-cleanup) from dotfiles in ~/.local/bin.
NOTE 
} 
 
install_islands_dark_theme() { 
    local ext_dir 
    case "$OS_TYPE" in 
        macos|linux|bazzite|archlike) 
            ext_dir="$HOME/.vscode/extensions/bwya77.islands-dark-0.0.2" 
            ;; 
        *) 
            log_error "Unsupported OS for Islands Dark theme manual install" 
            return 1 
            ;; 
    esac 
 
    if [[ "$DRY_RUN" == "true" ]]; then 
        echo "[DRY RUN] Would install Islands Dark theme to $ext_dir" 
        echo "[DRY RUN] Would run: git clone https://github.com/bwya77/vscode-dark-islands $ext_dir" 
        return 0 
    fi 
 
    if [[ -d "$ext_dir" ]]; then 
        echo "Islands Dark theme already installed at $ext_dir. Updating..." 
        git -C "$ext_dir" pull || log_error "Failed to update Islands Dark theme" 
    else 
        echo "Installing Islands Dark theme..." 
        mkdir -p "$(dirname "$ext_dir")" 
        git clone https://github.com/bwya77/vscode-dark-islands "$ext_dir" || { 
            log_error "Failed to clone Islands Dark theme" 
            return 1 
        } 
    fi 
 
    echo "Islands Dark theme installed successfully" 
}
NOTE
}

install_selected_macos_tools() {
    local -a supported=(${(ok)macos_cask_tools} ${(ok)macos_brew_tools})
    local key

    echo "Starting installation of tools on macOS..."
    announce_selection
    report_unavailable_selected_tools "macOS" "${supported[@]}"

    echo "Installing Homebrew casks..."
    for key in ${(ok)macos_cask_tools}; do
        should_install_tool "$key" || continue
        echo "Processing cask: $key..."
        install_brew_tool "${macos_cask_tools[$key]}" true
        if [[ "$key" == "vscode" ]]; then 
            install_islands_dark_theme 
        fi
    done

    echo "Installing Homebrew formulae..."
    for key in ${(ok)macos_brew_tools}; do
        should_install_tool "$key" || continue
        echo "Processing brew: $key..."
        install_brew_tool "${macos_brew_tools[$key]}" false
    done

    echo "Completed installation of macOS tools"
}

install_selected_linux_tools() {
    local -a supported=(${(ok)linux_apt_tools} ${(ok)linux_brew_tools} ${(ok)linux_flatpak_tools})
    local key

    echo "Starting installation of tools on Linux..."
    announce_selection
    report_unavailable_selected_tools "linux" "${supported[@]}"

    echo "Installing apt packages..."
    for key in ${(ok)linux_apt_tools}; do
        should_install_tool "$key" || continue
        echo "Processing apt: $key..."
        install_apt_tool "${linux_apt_tools[$key]}"
    done

    echo "Installing Flatpak applications..."
    for key in ${(ok)linux_flatpak_tools}; do
        should_install_tool "$key" || continue
        echo "Processing flatpak: $key..."
        install_flatpak_tool "${linux_flatpak_tools[$key]}" "apt"
        if [[ "$key" == "vscode" ]]; then 
            install_islands_dark_theme 
        fi
    done

    echo "Installing Homebrew packages..."
    for key in ${(ok)linux_brew_tools}; do
        should_install_tool "$key" || continue
        echo "Processing brew: $key..."
        install_brew_tool "${linux_brew_tools[$key]}" false
    done

    echo "Completed installation of Linux tools"
}

install_selected_bazzite_tools() {
    local -a supported=(${(ok)bazzite_brew_tools} ${(ok)bazzite_experimental_tools} ${(ok)bazzite_flatpak_tools} docker)
    local key

    echo "Starting installation of tools on Bazzite..."
    announce_selection
    report_unavailable_selected_tools "bazzite" "${supported[@]}"

    echo "Installing Flatpak applications..."
    for key in ${(ok)bazzite_flatpak_tools}; do
        should_install_tool "$key" || continue
        echo "Processing flatpak: $key..."
        install_flatpak_tool "${bazzite_flatpak_tools[$key]}" "none"
        if [[ "$key" == "vscode" ]]; then 
            install_islands_dark_theme 
        fi
    done

    echo "Installing Homebrew packages..."
    for key in ${(ok)bazzite_brew_tools}; do
        should_install_tool "$key" || continue
        echo "Processing brew: $key..."
        install_brew_tool "${bazzite_brew_tools[$key]}" false
    done

    echo "Installing Bazzite experimental tools (opt-in only)..."
    for key in ${(ok)bazzite_experimental_tools}; do
        should_install_tool "$key" || continue
        echo "Processing experimental: $key..."
        case "$key" in
            kwin-mcp-experimental)
                install_bazzite_kwin_mcp_experimental
                ;;
        esac
    done

    if should_install_tool "docker"; then
        echo "Docker equivalent on Bazzite: using the preinstalled Podman stack."
    fi

    echo "Completed installation of Bazzite tools"
}

install_selected_archlike_tools() {
    local -a supported=(${(ok)archlike_aur_tools} ${(ok)archlike_brew_tools} ${(ok)archlike_flatpak_tools} ${(ok)archlike_pacman_tools})
    local key

    echo "Starting installation of tools on Arch-like Linux..."
    announce_selection
    report_unavailable_selected_tools "archlike" "${supported[@]}"

    echo "Installing pacman packages..."
    for key in ${(ok)archlike_pacman_tools}; do
        should_install_tool "$key" || continue
        echo "Processing pacman: $key..."
        install_pacman_tool "${archlike_pacman_tools[$key]}"
        if [[ "$key" == "vscode" ]]; then 
            install_islands_dark_theme 
        fi
    done

    echo "Installing Flatpak applications..."
    for key in ${(ok)archlike_flatpak_tools}; do
        should_install_tool "$key" || continue
        echo "Processing flatpak: $key..."
        install_flatpak_tool "${archlike_flatpak_tools[$key]}" "pacman"
    done

    echo "Installing AUR packages..."
    for key in ${(ok)archlike_aur_tools}; do
        should_install_tool "$key" || continue
        echo "Processing AUR: $key..."
        install_aur_tool "${archlike_aur_tools[$key]}"
    done

    echo "Installing Homebrew packages..."
    for key in ${(ok)archlike_brew_tools}; do
        should_install_tool "$key" || continue
        echo "Processing brew: $key..."
        install_brew_tool "${archlike_brew_tools[$key]}" false
    done

    echo "Completed installation of Arch-like tools"
}

setup_conda_macos() {
    echo "Checking conda..."
    if command -v conda >/dev/null 2>&1; then
        echo "Initializing conda..."
        if [[ "$DRY_RUN" == "false" ]]; then
            conda init zsh || log_error "Failed to initialize conda"
        else
            echo "[DRY RUN] Would initialize conda"
        fi
    fi
}

cleanup_macos() {
    if [[ "$CLEANUP" != "true" ]]; then
        return 0
    fi

    echo "Running cleanup..."
    if [[ "$DRY_RUN" == "false" ]]; then
        if command -v brew >/dev/null 2>&1; then
            brew cleanup || log_error "Failed to clean up Homebrew cache"
        fi
    else
        echo "[DRY RUN] Would clean up Homebrew cache"
    fi
}

cleanup_linux() {
    if [[ "$CLEANUP" != "true" ]]; then
        return 0
    fi

    echo "Running cleanup..."
    if [[ "$DRY_RUN" == "false" ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get autoremove -y || log_error "Failed to run apt autoremove"
            sudo apt-get autoclean -y || log_error "Failed to run apt autoclean"
        fi
        if command -v flatpak >/dev/null 2>&1; then
            flatpak uninstall --unused -y || log_error "Failed to clean up unused Flatpak runtimes"
        fi
        if command -v brew >/dev/null 2>&1; then
            brew cleanup || log_error "Failed to clean up Homebrew cache"
        fi
    else
        echo "[DRY RUN] Would clean up apt, Flatpak, and Homebrew caches"
    fi
}

cleanup_bazzite() {
    if [[ "$CLEANUP" != "true" ]]; then
        return 0
    fi

    echo "Running cleanup..."
    if [[ "$DRY_RUN" == "false" ]]; then
        if command -v flatpak >/dev/null 2>&1; then
            flatpak uninstall --unused -y || log_error "Failed to clean up unused Flatpak runtimes"
        fi
        if command -v brew >/dev/null 2>&1; then
            brew cleanup || log_error "Failed to clean up Homebrew cache"
        fi
    else
        echo "[DRY RUN] Would clean up Flatpak and Homebrew caches"
    fi
}

cleanup_archlike() {
    if [[ "$CLEANUP" != "true" ]]; then
        return 0
    fi

    echo "Running cleanup..."
    if [[ "$DRY_RUN" == "false" ]]; then
        if command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sc --noconfirm || log_error "Failed to clean up pacman cache"
        fi
        if command -v flatpak >/dev/null 2>&1; then
            flatpak uninstall --unused -y || log_error "Failed to clean up unused Flatpak runtimes"
        fi
        if command -v brew >/dev/null 2>&1; then
            brew cleanup || log_error "Failed to clean up Homebrew cache"
        fi
    else
        echo "[DRY RUN] Would clean up pacman, Flatpak, and Homebrew caches"
    fi
}

main() {
    echo "Starting installation process..."

    parse_args "$@"
    init_logs
    check_system

    echo "Installing tools..."
    case "$OS_TYPE" in
        macos)
            install_selected_macos_tools
            setup_conda_macos
            cleanup_macos
            ;;
        linux)
            install_selected_linux_tools
            cleanup_linux
            ;;
        bazzite)
            install_selected_bazzite_tools
            cleanup_bazzite
            ;;
        archlike)
            install_selected_archlike_tools
            cleanup_archlike
            ;;
    esac

    echo "Installation process completed"
    echo "Check $ERROR_LOG_FILE for any errors"
}

main "$@"
