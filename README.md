# Setup Tools

`setup-tools` bootstraps a workstation in `zsh` across four modes:

- `macos`
- `linux` for apt-based distros
- `bazzite` for Fedora Atomic/Bazzite-style systems
- `archlike` for Arch-based distros such as CachyOS

## Features

- Auto-detects the current mode, with `--os` available to override it
- Supports `--dry-run`, repeated `--select`, `--cleanup`, and `--debug`
- Uses the best available source for each mode:
  - `macos`: Homebrew formulae and casks
  - `linux`: `apt`, Flatpak, and Homebrew
  - `bazzite`: Flatpak and Homebrew
  - `archlike`: `pacman`, AUR (`paru` or `yay`), Flatpak, and Homebrew
- Continues after individual install failures and records them in `error.log`

## Core tool keys

- Desktop apps: `1password`, `discord`, `docker`, `gitkraken`, `ghostty`, `notion`, `raycast`, `slack`, `vscode`, `warp`
- CLI tools: `fnm`, `gh`, `git`, `miniconda`, `node`, `opencode`, `python`
- macOS-only extras: `karabiner`, `keyboardcleantool`, `orbstack`
- Bazzite experimental: `kwin-mcp-experimental`

## Mode notes

- `docker` on `bazzite` resolves to the preinstalled Podman stack instead of installing Docker.
- `notion` is only mapped on `macos`. The Linux-like modes currently skip it instead of relying on a weak package source.
- `archlike` uses AUR for `fnm` and `miniconda`, so `paru` or `yay` must already be installed.
- Any brew-managed tool is skipped if `brew` is not already available on that machine.

## Usage

```zsh
# Auto-detect the current mode
./install.sh

# Preview changes only
./install.sh --dry-run

# Install a subset of tools
./install.sh --select warp --select docker

# Force Arch-like mode
./install.sh --os archlike

# Opt into the Bazzite experimental installer
./install.sh --os bazzite --select kwin-mcp-experimental

# Verbose install with cleanup
./install.sh --verbose --cleanup
```

## Options

| Option | Description |
| --- | --- |
| `--dry-run` | Show what would be installed without changing the machine |
| `--verbose` | Include extra log detail while running |
| `--cleanup` | Clean package-manager caches after installation |
| `--select TOOL` | Install only the named tool key; repeat as needed |
| `--debug` | Enable shell tracing |
| `--os OS` | Force `macos`, `linux`, `bazzite`, or `archlike` |
| `--help` | Show usage information |

## Requirements

- `zsh`
- sudo access for system package managers where applicable
- internet access
- Homebrew installed already if you want brew-managed tools on Linux-like systems

## Validation

`validate.sh` auto-detects the same mode matrix and checks the expected packages for that platform:

```zsh
./validate.sh
```

It exits with code `1` if any expected tool is missing.

## Logs

- `install.log`: progress and verbose details
- `error.log`: installation failures and unsupported selections
