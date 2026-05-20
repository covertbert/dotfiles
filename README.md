# .files

My personal macOS dotfiles. Covers ZSH config, Git config, macOS system defaults, Homebrew packages, and Pi coding agent config.

## What these dotfiles manage

- **ZSH** — shell config, aliases, functions, plugins (via zgen), Starship prompt, fzf, lazy NVM, 1Password completions
- **Git** — `.gitconfig` with delta diffs, GPG signing, and theme config
- **macOS defaults** — UI/UX, keyboard, Finder, Dock, Spotlight, screen, and app-specific defaults (Chrome, Transmission)
- **Homebrew** — CLI tools and casks via `brew/Brewfile` and `brew/Caskfile`
- **Terminal** — Hyper config and Starship theme
- **Pi agent** — coding agent settings, keybindings, models, prompts, and AGENTS instructions
- **MCP** — shared MCP server config, currently Chrome DevTools

## Prerequisites

- macOS
- Git (comes with Xcode Command Line Tools: `xcode-select --install`)
- Internet access (Homebrew and NVM will be installed automatically if missing)

## Quick start

Clone the repo and run the full bootstrap:

```sh
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

> **Warning:** `bootstrap.sh` will overwrite most managed config files in your home directory without prompting. The only exception is `~/user.gitconfig`, which is created only if it does not already exist. Back up any custom config before running.

`bootstrap.sh` runs these scripts in order:

1. `defaults.sh` — applies macOS system defaults
2. `config.sh` — copies dotfiles, Pi config, MCP config, and installs NVM + zgen if missing
3. `brew.sh` — installs Homebrew if missing, then runs `brew bundle`

## Individual scripts

Run any script independently:

```sh
./defaults.sh   # macOS system defaults only
./config.sh     # Copy dotfiles, Pi config, MCP config, and install ZSH/NVM dependencies only
./mcp.sh        # Copy shared MCP config only
./brew.sh       # Homebrew install and bundle only
```

## Update workflow

Pull the latest changes and re-run bootstrap:

```sh
git pull && ./bootstrap.sh
```

## Repository layout

```
.
├── bootstrap.sh          # Full install: runs defaults → config → brew
├── config.sh             # Copies config files, installs NVM + zgen
├── mcp.sh                # Copies shared MCP config
├── brew.sh               # Installs Homebrew and runs bundle
├── defaults.sh           # Applies macOS defaults (delegates to defaults/)
├── pi-backfill.sh        # Copies Pi agent config back into this repo
├── brew/
│   ├── Brewfile          # CLI packages
│   └── Caskfile          # GUI apps and fonts
├── config/
│   ├── git/              # .gitconfig, themes.gitconfig, user.gitconfig template
│   ├── mcp/              # Shared MCP config
│   ├── terminal/         # starship.toml, .hyper.js
│   ├── zsh/              # .zshrc, aliases.zsh, functions.zsh
│   └── pi/               # Pi agent settings, models, AGENTS.md, prompts, etc.
└── defaults/
    ├── system.sh         # Broad macOS UI, keyboard, Finder, Dock, Spotlight defaults
    ├── chrome.sh         # Chrome-specific defaults
    └── transmission.sh   # Transmission-specific defaults
```

## Shell config

ZSH config is split across:

- `config/zsh/.zshrc` — main shell config: completion, history, PATH, plugins, Starship init, fzf, 1Password, NVM bootstrap
- `config/zsh/aliases.zsh` — aliases (including git shortcuts, `vim` → `nvim`, `cat` → `bat`)
- `config/zsh/functions.zsh` — shell functions and lazy NVM loading with Node 24 as default

`config.sh` copies `config/zsh/` to `~/.config/zsh/` and `config/zsh/.zshrc` to `~/.zshrc`.

## Git config

`config/git/.gitconfig` includes:

- `git-delta` for diffs with the `calochortus-lyallii` theme
- GPG commit and tag signing
- `push.autoSetupRemote = true` for branch tracking
- Includes `~/user.gitconfig` (personal name/email) and `~/themes.gitconfig`

`~/user.gitconfig` is only created if it does not already exist — edit it to set your name and email after first install.

## macOS defaults

> **Warning:** `defaults.sh` (and `defaults/system.sh`) requests `sudo` and applies broad system-level changes including killing Dock, Finder, and other affected apps. Review `defaults/system.sh` before running on a machine where you want to keep existing preferences.

Notable changes applied by `defaults/system.sh`:

- Dock: auto-hide, no bouncing icons, no recent apps, hidden-app icons translucent
- Finder: show hidden files, show extensions, path bar, list view by default
- Keyboard: fast repeat rate, disable smart quotes/dashes/autocorrect
- Screenshots: PNG format, no shadow, saved to Desktop
- Software updates: automatic checks and background downloads enabled

## Homebrew

See `brew/Brewfile` for CLI tools and `brew/Caskfile` for GUI apps and fonts.

`brew.sh` installs Homebrew if not present, runs both bundle files, and installs fzf shell integration.

## Pi agent config

`config/pi/` holds portable Pi coding agent config:

- `settings.json`, `keybindings.json`, `models.json` — agent and UI settings
- `AGENTS.md` — global agent instructions (caveman mode, commit rules, etc.)
- `plannotator.json` — Plannotator extension config
- `prompts/`, `skills/`, `extensions/`, `themes/` — customisations

`config.sh` copies these into `~/.pi/agent/`. Private/local state (`auth.json`, `sessions/`, `npm/`, `git/`) is excluded and ignored by `.gitignore`.

## MCP config

`config/mcp/mcp.json` is source of truth for shared MCP servers and is copied to `~/.config/mcp/mcp.json` by `mcp.sh` or `config.sh`.

Current servers:

- `chrome-devtools` via `npx -y chrome-devtools-mcp@latest`

### Backfill Pi config into this repo

After changing Pi config in the agent, run:

```sh
./pi-backfill.sh
```

This copies the safe portable files back from `~/.pi/agent/` into `config/pi/`. Auth and session state are intentionally not copied.

## Contributing and validation

Git hooks are managed via [Lefthook](https://github.com/evilmartians/lefthook).

```sh
brew install lefthook
lefthook install
```

Hooks run on commit and push: Prettier formatting, shfmt formatting, shellcheck linting, and bash syntax checks for shell files. Note that `.prettierignore` excludes shell/config files from Prettier — shell checks are handled by shfmt and shellcheck via Lefthook instead.

To validate shell changes manually without running bootstrap:

```sh
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck && \
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shfmt -d && \
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -I {} bash -n {}
```
