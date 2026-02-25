# Setup Tools

A robust script for automatically setting up a new development environment. This script supports both macOS and Linux, using Homebrew (macOS) or apt/dnf (Linux) to install and manage various development tools, applications, and utilities.

## Features

- 🚀 One-command setup for new machines
- 🔍 Dry run mode to preview installations
- 📦 Selective tool installation
- 📝 Detailed logging and error tracking
- 🧹 Optional cleanup functionality
- 🔄 Automatic package manager installation and updates
- 💻 Support for macOS (Intel and Apple Silicon) and Linux

## Available Tools

### GUI Applications (Casks)

**macOS only:**
- Raycast (`raycast`)
- Karabiner Elements (`karabiner`)
- OrbStack (`orbstack`)
- KeyboardCleanTool (`keyboardcleantool`)

**Linux & macOS:**
- Warp Terminal (`warp`)
- Ghostty Terminal (`ghostty`)
- Notion (`notion`)
- Slack (`slack`)
- Discord (`discord`)
- 1Password (`1password`)
- GitKraken (`gitkraken`)
- Visual Studio Code (`vscode`)
- Docker (`docker`) - OrbStack on macOS, Docker Engine on Linux

### Command Line Tools

**macOS only:**
- Miniconda (`miniconda`)
- Python 3.13 (`python`)

**Linux & macOS:**
- Git (`git`)
- Node.js (`node`) - via Homebrew (macOS) or fnm (Linux)
- GitHub CLI (`gh`)
- OpenCode CLI (`opencode`)
- fnm (`fnm`) - Linux only (Node version manager)

## Usage

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/setup-tools.git
   cd setup-tools
   ```

2. Make the script executable:
   ```bash
   chmod +x install.sh
   ```

3. Run the script with desired options:
    ```bash
    # Full installation (auto-detects OS)
    ./install.sh

    # Show help
    ./install.sh --help

    # Dry run to preview changes
    ./install.sh --dry-run

    # Install specific tools
    ./install.sh --select warp --select docker

    # Force Linux installation on WSL/cross-compile
    ./install.sh --os linux

    # Verbose output with cleanup
    ./install.sh --verbose --cleanup
    ```

## Command Line Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be installed without making changes |
| `--verbose` | Show detailed output during installation |
| `--cleanup` | Clean up caches after installation |
| `--select TOOL` | Install only specific tools (can be used multiple times) |
| `--os OS` | Force OS: macos or linux (auto-detected by default) |
| `--help` | Show help message |

## Logging

The script maintains two log files:
- `install.log`: Records successful installations and general progress
- `error.log`: Records any errors or failed installations

## Post-Installation Steps

After running the script, you might want to:

1. Set up SSH keys for GitHub:
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. Configure Git:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your_email@example.com"
   ```

3. Install Oh My Zsh:
   ```bash
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
   ```

4. Configure your terminal preferences in iTerm2/Warp
5. Set up Rectangle window management preferences

## Requirements

- macOS (Apple Silicon or Intel) OR Linux (Ubuntu/Debian/Arch)
- Internet connection
- Administrator/sudo privileges (for installation)

## Error Handling

The script includes robust error handling:
- Verifies OS compatibility (macOS or Linux)
- Checks for successful package manager installation
- Validates package availability before installation
- Logs all errors for troubleshooting
- Continues installation even if individual tools fail

## Validation

After installation, run the validation script to check which tools were installed successfully:

```bash
chmod +x validate.sh
./validate.sh
```

The script outputs a pass/fail status for each tool and exits with code 1 if any tool is missing.

## Contributing

Feel free to fork this repository and submit pull requests to add more tools or improve the script.

## License

This project is open source and available under the MIT License.
