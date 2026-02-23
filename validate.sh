#!/usr/bin/env zsh

# Validation script for setup-tools
# Checks whether each tool was successfully installed

PASS=0
FAIL=0
TOTAL=0

check() {
    local name="$1"
    local cmd="$2"
    TOTAL=$((TOTAL + 1))
    if eval "$cmd" &>/dev/null; then
        echo "  ✅ $name"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $name"
        FAIL=$((FAIL + 1))
    fi
}

echo "🔍 Validating setup-tools installation..."
echo ""

echo "── Homebrew ──"
check "Homebrew" "command -v brew"
echo ""

echo "── GUI Applications (Casks) ──"
check "Warp"               "brew list --cask warp"
check "Raycast"            "brew list --cask raycast"
check "Notion"             "brew list --cask notion"
check "Ghostty"            "brew list --cask ghostty"
check "Slack"              "brew list --cask slack"
check "Discord"            "brew list --cask discord"
check "1Password"          "brew list --cask 1password"
check "Karabiner Elements" "brew list --cask karabiner-elements"
check "KeyboardCleanTool"  "brew list --cask keyboardcleantool"
check "GitKraken"          "brew list --cask gitkraken"
check "VS Code"            "brew list --cask visual-studio-code"
check "Docker"             "brew list --cask docker"
check "OrbStack"           "brew list --cask orbstack"
echo ""

echo "── CLI Tools ──"
check "Miniconda"  "brew list miniconda"
check "Git"        "command -v git"
check "Node.js"    "command -v node"
check "Python 3.13" "brew list python@3.13"
check "GitHub CLI" "command -v gh"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total: $TOTAL | ✅ Passed: $PASS | ❌ Failed: $FAIL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAIL -gt 0 ]]; then
    exit 1
else
    echo "  🎉 All tools installed successfully!"
    exit 0
fi
