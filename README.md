# Setup Tools

A robust script for automatically setting up a new macOS development environment. This script uses Homebrew to install and manage various development tools, applications, and utilities.

## Features

- 🚀 One-command setup for new macOS machines
- 🔍 Dry run mode to preview installations
- 📦 Selective tool installation
- 📝 Detailed logging and error tracking
- 🧹 Optional cleanup functionality
- 🔄 Automatic Homebrew installation and updates
- 💻 Support for both Intel and Apple Silicon Macs

## Available Tools

### GUI Applications (Casks)
- Google Chrome (`chrome`)
- Warp Terminal (`warp`)
- Raycast (`raycast`)
- Notion (`notion`)
- Cursor IDE (`cursor`)
- ChatGPT (`chatgpt`)
- Slack (`slack`)
- Discord (`discord`)
- 1Password (`1password`)
- Karabiner Elements (`karabiner`)
- KeyboardCleanTool (`keyboardcleantool`)
- GitKraken (`gitkraken`)
- Paw/RapidAPI (`paw`)
- Visual Studio Code (`vscode`)
- Docker (`docker`)

### Command Line Tools
- Miniconda (`miniconda`)
- Git (`git`)
- Node.js (`node`)
- Python 3.11 (`python`)
- GitHub CLI (`gh`)

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
   # Full installation
   ./install.sh

   # Show help
   ./install.sh --help

   # Dry run to preview changes
   ./install.sh --dry-run

   # Install specific tools
   ./install.sh --select chrome --select slack

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

- macOS (Apple Silicon or Intel)
- Internet connection
- Administrator privileges (for installation)

## Error Handling

The script includes robust error handling:
- Verifies macOS compatibility
- Checks for successful Homebrew installation
- Validates package availability before installation
- Logs all errors for troubleshooting
- Continues installation even if individual tools fail

## Contributing

Feel free to fork this repository and submit pull requests to add more tools or improve the script.

## License

This project is open source and available under the MIT License.
