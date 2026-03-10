#!/usr/bin/env zsh

PASS=0
FAIL=0
TOTAL=0
OS_TYPE=""

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
            echo "Unsupported operating system"
            exit 1
            ;;
    esac
}

section() {
    echo ""
    echo "== $1 =="
}

check() {
    local name="$1"
    local cmd="$2"

    TOTAL=$((TOTAL + 1))
    if eval "$cmd" >/dev/null 2>&1; then
        echo "  [OK]   $name"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $name"
        FAIL=$((FAIL + 1))
    fi
}

check_command() {
    check "$1" "command -v $2"
}

check_brew_formula() {
    if command -v brew >/dev/null 2>&1; then
        check "$1" "brew list $2"
    else
        check "$1" "false"
    fi
}

check_brew_cask() {
    if command -v brew >/dev/null 2>&1; then
        check "$1" "brew list --cask $2"
    else
        check "$1" "false"
    fi
}

check_flatpak_app() {
    if command -v flatpak >/dev/null 2>&1; then
        check "$1" "flatpak info $2"
    else
        check "$1" "false"
    fi
}

check_apt_package() {
    if command -v dpkg >/dev/null 2>&1; then
        check "$1" "dpkg -s $2"
    else
        check "$1" "false"
    fi
}

check_pacman_package() {
    if command -v pacman >/dev/null 2>&1; then
        check "$1" "pacman -Q $2"
    else
        check "$1" "false"
    fi
}

validate_macos() {
    section "Homebrew Casks"
    check_brew_cask "1Password" "1password"
    check_brew_cask "Discord" "discord"
    check_brew_cask "Docker" "docker"
    check_brew_cask "Ghostty" "ghostty"
    check_brew_cask "GitKraken" "gitkraken"
    check_brew_cask "Karabiner Elements" "karabiner-elements"
    check_brew_cask "KeyboardCleanTool" "keyboardcleantool"
    check_brew_cask "Notion" "notion"
    check_brew_cask "OrbStack" "orbstack"
    check_brew_cask "Raycast" "raycast"
    check_brew_cask "Slack" "slack"
    check_brew_cask "Visual Studio Code" "visual-studio-code"
    check_brew_cask "Warp" "warp"

    section "Homebrew Formulae"
    check_brew_formula "GitHub CLI" "gh"
    check_brew_formula "Git" "git"
    check_brew_formula "Miniconda" "miniconda"
    check_brew_formula "Node.js" "node"
    check_brew_formula "OpenCode" "opencode"
    check_brew_formula "Python 3.13" "python@3.13"
}

validate_linux() {
    section "APT Packages"
    check_apt_package "Docker" "docker.io"
    check_apt_package "GitHub CLI" "gh"
    check_apt_package "Git" "git"
    check_apt_package "Node.js" "nodejs"
    check_apt_package "Python" "python3"

    section "Flatpak Apps"
    check_flatpak_app "1Password" "com.onepassword.OnePassword"
    check_flatpak_app "Discord" "com.discordapp.Discord"
    check_flatpak_app "GitKraken" "com.axosoft.GitKraken"
    check_flatpak_app "Slack" "com.slack.Slack"
    check_flatpak_app "Visual Studio Code" "com.visualstudio.code"
    check_flatpak_app "Warp" "dev.warp.Warp"

    section "Homebrew Formulae"
    check_brew_formula "fnm" "fnm"
    check_brew_formula "Ghostty" "ghostty"
    check_brew_formula "Miniconda" "miniconda"
    check_brew_formula "OpenCode" "opencode"
}

validate_bazzite() {
    section "Flatpak Apps"
    check_flatpak_app "1Password" "com.onepassword.OnePassword"
    check_flatpak_app "Discord" "com.discordapp.Discord"
    check_flatpak_app "GitKraken" "com.axosoft.GitKraken"
    check_flatpak_app "Slack" "com.slack.Slack"
    check_flatpak_app "Visual Studio Code" "com.visualstudio.code"
    check_flatpak_app "Warp" "dev.warp.Warp"

    section "Homebrew Formulae"
    check_brew_formula "fnm" "fnm"
    check_brew_formula "GitHub CLI" "gh"
    check_brew_formula "Ghostty" "ghostty"
    check_brew_formula "Git" "git"
    check_brew_formula "Miniconda" "miniconda"
    check_brew_formula "Node.js" "node"
    check_brew_formula "OpenCode" "opencode"
    check_brew_formula "Python 3.13" "python@3.13"

    section "Built-in Equivalent"
    check_command "Podman (Docker equivalent)" "podman"
}

validate_archlike() {
    section "pacman Packages"
    check_pacman_package "Discord" "discord"
    check_pacman_package "Docker" "docker"
    check_pacman_package "GitHub CLI" "github-cli"
    check_pacman_package "Git" "git"
    check_pacman_package "Ghostty" "ghostty"
    check_pacman_package "Node.js" "nodejs"
    check_pacman_package "Python" "python"
    check_pacman_package "Visual Studio Code" "code"

    section "Flatpak Apps"
    check_flatpak_app "1Password" "com.onepassword.OnePassword"
    check_flatpak_app "GitKraken" "com.axosoft.GitKraken"
    check_flatpak_app "Slack" "com.slack.Slack"
    check_flatpak_app "Warp" "dev.warp.Warp"

    section "AUR Packages"
    check_pacman_package "fnm" "fnm"
    check_pacman_package "Miniconda" "miniconda3"

    section "Homebrew Formulae"
    check_brew_formula "OpenCode" "opencode"
}

detect_os

echo "Validating setup-tools installation for $OS_TYPE..."

case "$OS_TYPE" in
    macos)
        validate_macos
        ;;
    linux)
        validate_linux
        ;;
    bazzite)
        validate_bazzite
        ;;
    archlike)
        validate_archlike
        ;;
esac

echo ""
echo "=============================="
echo "Total: $TOTAL | Passed: $PASS | Failed: $FAIL"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi

echo "All expected tools are present."
exit 0
