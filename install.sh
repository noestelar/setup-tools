#!/usr/bin/env zsh
set -x  # ← Uncomment this line if you want to see each command as it runs (debug mode).

###############################################################################
# Script to install tools and languages using Homebrew (Zsh version).
# Handles failures gracefully and logs errors.
###############################################################################

# Default modes
typeset DRY_RUN=false
typeset VERBOSE=false
typeset CLEANUP=false
typeset -a SELECTED_TOOLS=()

# Help message
function show_help() {
  cat << EOF
Usage: ./install.sh [options]

Options:
  --dry-run           Show what would be installed without making changes
  --verbose           Show detailed output during installation
  --cleanup           Clean up caches after installation
  --select TOOL       Install only specific tools (can be used multiple times)
  --help              Show this help message

Example:
  ./install.sh --dry-run
  ./install.sh --select chrome --select slack
  ./install.sh --verbose --cleanup
EOF
}

###############################################################################
# Parse command line arguments
###############################################################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --verbose)
      VERBOSE=true
      ;;
    --cleanup)
      CLEANUP=true
      ;;
    --select)
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

###############################################################################
# Log files
###############################################################################
typeset LOG_FILE="install.log"
typeset ERROR_LOG_FILE="error.log"

# Initialize log files
> "$LOG_FILE"
> "$ERROR_LOG_FILE"

# Logging functions
function log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
  if [[ "$VERBOSE" == true ]]; then
    echo "Details: $2" | tee -a "$LOG_FILE"
  fi
}

function log_error() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" | tee -a "$ERROR_LOG_FILE"
}

###############################################################################
# Check if running on macOS
###############################################################################
if [[ "$(uname)" != "Darwin" ]]; then
  log_error "This script is designed for macOS only. Exiting."
  exit 1
fi

###############################################################################
# Check for Homebrew, install if not found
###############################################################################
if ! command -v brew &>/dev/null; then
  log "Homebrew not found. Would install Homebrew..."
  if [[ "$DRY_RUN" == false ]]; then
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
  log "Homebrew already installed."
  # The following lines often cause freezing if there's a license or network issue.
  # Uncomment them if you want the script to update/upgrade Homebrew automatically:
  #
  # if [[ "$DRY_RUN" == false ]]; then
  #   brew update || log_error "Failed to update Homebrew."
  #   brew upgrade || log_error "Failed to upgrade Homebrew packages."
  #   log "Homebrew is up to date."
  # fi
fi

###############################################################################
# Define the tools to install (with chatgpt and cursor included)
###############################################################################
typeset -A cask_tools=(
  ["chrome"]="google-chrome"
  ["warp"]="warp"
  ["raycast"]="raycast"
  ["notion"]="notion"
  ["cursor"]="cursor"           # ← included
  ["chatgpt"]="chatgpt"         # ← included
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

typeset -A brew_tools=(
  ["miniconda"]="miniconda"
  ["git"]="git"
  ["node"]="node"
  ["python"]="python@3.11"
  ["gh"]="gh"
)

###############################################################################
# Installation Functions
###############################################################################
function install_tool() {
  local tool="$1"
  local is_cask="$2"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ "$is_cask" == true ]]; then
      log "[DRY RUN] Would install cask: $tool"
    else
      log "[DRY RUN] Would install formula: $tool"
    fi
    return
  fi

  log "Installing $tool..."
  local output
  if [[ "$is_cask" == true ]]; then
    if output=$(brew install --cask "$tool" 2>&1); then
      log "$tool installed successfully." "$output"
    else
      log_error "$tool installation failed. Skipping to next item."
      [[ "$VERBOSE" == true ]] && echo "$output" >> "$ERROR_LOG_FILE"
    fi
  else
    if output=$(brew install "$tool" 2>&1); then
      log "$tool installed successfully." "$output"
    else
      log_error "$tool installation failed. Skipping to next item."
      [[ "$VERBOSE" == true ]] && echo "$output" >> "$ERROR_LOG_FILE"
    fi
  fi
}

function install_cask_tools() {
  log "Installing cask applications..."
  for key in ${(k)cask_tools}; do
    if [[ ${#SELECTED_TOOLS[@]} -eq 0 || " ${SELECTED_TOOLS[*]} " == *" $key "* ]]; then
      install_tool "${cask_tools[$key]}" true
    fi
  done
}

function install_brew_tools() {
  log "Installing brew formulae..."
  for key in ${(k)brew_tools}; do
    if [[ ${#SELECTED_TOOLS[@]} -eq 0 || " ${SELECTED_TOOLS[*]} " == *" $key "* ]]; then
      install_tool "${brew_tools[$key]}" false
    fi
  done
}

###############################################################################
# Main Script
###############################################################################
log "Starting installation process..."

install_cask_tools
install_brew_tools

# Initialize conda if installed
if command -v conda &>/dev/null; then
  log "Initializing conda..."
  if [[ "$DRY_RUN" == false ]]; then
    conda init "$(basename "$SHELL")" || log_error "Failed to initialize conda"
  else
    log "[DRY RUN] Would initialize conda"
  fi
fi

# Cleanup if requested
if [[ "$CLEANUP" == true && "$DRY_RUN" == false ]]; then
  log "Cleaning up..."
  brew cleanup || log_error "Failed to clean up Homebrew cache"
fi

log "Installation process completed."
echo "Check $ERROR_LOG_FILE for errors, if any."

###############################################################################
# Additional setup suggestions
###############################################################################
cat << EOF

🎉 Installation completed! Here are some additional steps you might want to take:

1. Set up SSH keys for GitHub:
   ssh-keygen -t ed25519 -C "your_email@example.com"

2. Configure Git:
   git config --global user.name "Your Name"
   git config --global user.email "your_email@example.com"

3. Install Oh My Zsh (if you want):
   sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

4. Configure your terminal preferences in iTerm2/Warp

5. Set up Rectangle window management preferences

For more details, check the documentation of each tool installed.
EOF
