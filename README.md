# .files

My personal macOS dotfiles. Covers ZSH config, Git config, macOS system defaults, Homebrew packages, and Pi coding agent config.

## What these dotfiles manage

- **ZSH** — shell config, aliases, functions, plugins (via zgen), Starship prompt, fzf, lazy NVM, 1Password completions
- **Git** — `.gitconfig` with delta diffs, GPG signing, and theme config
- **macOS defaults** — keyboard, Finder, Dock, screenshots, and low-risk UI defaults; plus app-specific defaults for Chrome and Transmission
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

> **Warning:** `bootstrap.sh` will overwrite most managed config files in your home directory without prompting. Back up any custom config before running.

`bootstrap.sh` runs in order:

1. `dotfiles install` — creates `~/.local/bin/dotfiles` symlink
2. `dotfiles installers` — installs NVM and zgen if missing
3. `dotfiles sync --to system` — deploys all managed config files
4. `dotfiles defaults` — applies macOS system defaults
5. `dotfiles brew` — installs Homebrew and runs bundle

## The `dotfiles` command

After bootstrap, `dotfiles` is available from any directory via `~/.local/bin/dotfiles`.

```
dotfiles status              Show which managed files differ between repo and system
dotfiles diff                Detailed diff for every changed file
dotfiles sync                Interactive: prompt per changed item for direction
dotfiles sync --to system    Deploy all from repo to system
dotfiles sync --to repo      Backfill all from system to repo
dotfiles brew                Preview and run Homebrew bundle
dotfiles defaults            Preview and apply macOS system defaults
dotfiles check               Run shellcheck/shfmt/bash -n on all shell files
dotfiles install             (Re)create ~/.local/bin/dotfiles symlink
dotfiles installers          Install NVM and zgen if missing
```

Aliases: `deploy` = `sync --to system`, `backfill` = `sync --to repo`.

Add `--yes` to skip confirmation prompts on `sync --to`, `brew`, and `defaults`.

### Typical workflows

**See what's out of sync:**

```sh
dotfiles status
dotfiles diff
```

**Deploy repo changes to machine:**

```sh
dotfiles deploy
# or interactively, choosing direction per file:
dotfiles sync
```

**Copy machine changes back to repo:**

```sh
dotfiles backfill
```

**After editing Pi agent config in the app:**

```sh
dotfiles sync --to repo   # backfill only
# or interactively:
dotfiles sync
```

**Full re-bootstrap after pulling updates:**

```sh
git pull && ./bootstrap.sh
```

## Repository layout

```
.
├── bin/
│   └── dotfiles              # Primary CLI (all sync/diff/deploy commands)
├── lib/
│   └── manifest.sh           # Manifest of managed paths (repo ↔ system)
├── bootstrap.sh              # Full install: install → installers → sync → defaults → brew
├── config.sh                 # Deprecated: use 'dotfiles deploy'
├── mcp.sh                    # Deprecated: use 'dotfiles deploy'
├── brew.sh                   # Deprecated: use 'dotfiles brew'
├── defaults.sh               # Deprecated: use 'dotfiles defaults'
├── pi-backfill.sh            # Deprecated: use 'dotfiles backfill'
├── brew/
│   ├── Brewfile              # CLI packages
│   └── Caskfile              # GUI apps and fonts
├── config/
│   ├── git/                  # .gitconfig, themes.gitconfig, user.gitconfig template
│   ├── mcp/                  # Shared MCP config
│   ├── terminal/             # starship.toml, .hyper.js
│   ├── zsh/                  # .zshrc, aliases.zsh, functions.zsh
│   └── pi/                   # Pi agent settings, models, AGENTS.md, prompts, etc.
└── defaults/
    ├── system.sh             # Conservative macOS defaults: keyboard, Finder, Dock, screenshots
    ├── chrome.sh             # Chrome-specific defaults
    └── transmission.sh       # Transmission-specific defaults
```

## Shell config

ZSH config is split across:

- `config/zsh/.zshrc` — main shell config: completion, history, PATH, plugins, Starship init, fzf, 1Password, NVM bootstrap
- `config/zsh/aliases.zsh` — aliases (including git shortcuts, `vim` → `nvim`, `cat` → `bat`)
- `config/zsh/functions.zsh` — shell functions and lazy NVM loading with Node 24 as default

`dotfiles sync --to system` copies `config/zsh/` to `~/.config/zsh/` and `config/zsh/.zshrc` to `~/.zshrc`.

## Git config

`config/git/.gitconfig` includes:

- `git-delta` for diffs with the `calochortus-lyallii` theme
- GPG commit and tag signing
- `push.autoSetupRemote = true` for branch tracking
- Includes `~/user.gitconfig` (personal name/email) and `~/themes.gitconfig`

`~/user.gitconfig` is only created if it does not already exist — edit it to set your name and email after first install.

## macOS defaults

> **Warning:** `dotfiles defaults` requests `sudo` and restarts Dock, Finder, and SystemUIServer. Review `defaults/system.sh` before running on a machine where you want to keep existing preferences.

Changes applied by `defaults/system.sh`:

- **Keyboard:** fast repeat rate, no smart quotes/dashes/autocorrect, full keyboard access
- **Finder:** show hidden files, show extensions, path bar, list view, home as default window
- **Dock:** auto-hide, translucent hidden apps, no bounce, no recent apps
- **Screenshots:** PNG, no shadow, saved to Desktop
- **Software updates:** automatic check and background download enabled
- **General:** no iCloud default save, no crash reporter dialog, no LSQuarantine dialog

`defaults/chrome.sh` disables swipe navigation in Chrome. `defaults/transmission.sh` sets sensible Transmission download defaults.

## Homebrew

**Formulae** (`brew/Brewfile`): `gh`, `git-delta`, `starship`, `wget`, `fzf`, `shellcheck`, `shfmt`, `bat`, `coreutils`.

**Casks** (`brew/Caskfile`): `appcleaner`, `font-jetbrains-mono-nerd-font`.

`dotfiles brew` checks what's missing, shows a preview, runs `brew bundle` for both files in sequence (exits clearly on first failure), and installs fzf shell integration.

## Pi agent config

`config/pi/` holds portable Pi coding agent config:

- `settings.json`, `keybindings.json`, `models.json` — agent and UI settings
- `AGENTS.md` — global agent instructions (caveman mode, commit rules, etc.)
- `plannotator.json` — Plannotator extension config
- `prompts/`, `skills/`, `extensions/`, `themes/` — customisations

`dotfiles sync` copies these into `~/.pi/agent/`. Private/local state (`auth.json`, `sessions/`, `npm/`, `git/`) is excluded and ignored by `.gitignore`.

## MCP config

`config/mcp/mcp.json` is source of truth for shared MCP servers and is synced to `~/.config/mcp/mcp.json`.

Current servers:

- `chrome-devtools` via `npx -y chrome-devtools-mcp@latest`
- `notion` via `npx -y @notionhq/notion-mcp-server`

Notion auth uses `NOTION_TOKEN` from environment. Use a Notion internal integration secret (PAT-style token) and grant the integration access to the pages/databases it should see.

## Contributing and validation

Git hooks are managed via [Lefthook](https://github.com/evilmartians/lefthook).

```sh
brew install lefthook
lefthook install
```

Hooks run on commit and push: Prettier formatting, shfmt formatting, shellcheck linting, and bash syntax checks for shell files.

To validate shell changes manually:

```sh
dotfiles check
```

Or directly:

```sh
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck && \
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shfmt -d && \
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -I {} bash -n {}
```
