# AGENTS.md

macOS dev environment bootstrapper using Homebrew.

## Mandatory rules
- Shell: **Zsh** only. No bash shebangs.
- All tool installs go through **Homebrew** (brew or cask). No manual curl installs.
- Keep tool arrays (`cask_tools`, `brew_tools`) alphabetically sorted.
- Error resilience: never use `set -e`. Individual failures must not abort the full run.
- Support `--dry-run` and `--select` flags for all operations.

## Commands
- Full install: `./install.sh`
- Dry run: `./install.sh --dry-run`
- Selective: `./install.sh --select`
