# 🏠 dotfiles

My personal macOS dotfiles. One command to go from a blank Mac to a fully configured dev machine. Everything tracked, versioned, and sync-able.

> ⚠️ **Warning:** `bootstrap.sh` and `dotfiles sync --to system` will **overwrite** managed config files in your home directory without prompting. Back up anything you want to keep before running.

---

## 🗺️ What's managed

| Area                  | What it covers                                                                                                      |
| --------------------- | ------------------------------------------------------------------------------------------------------------------- |
| 🐚 **ZSH**            | `.zshrc`, aliases, functions, plugins (zgen), Starship prompt, fzf, history, NVM, 1Password completions, Pi wrapper |
| 🧬 **Git**            | `.gitconfig` with delta diffs, GPG signing, branch/push defaults, includes                                          |
| 🍎 **macOS defaults** | Keyboard, Finder, Dock, screenshots, Trash, software updates, Chrome, Transmission                                  |
| 🍺 **Homebrew**       | CLI tools (`Brewfile`) and GUI apps/fonts (`Caskfile`)                                                              |
| 🖥️ **Terminal**       | Hyper config, Ghostty config, Starship theme                                                                        |
| 🤖 **Pi agent**       | Settings, models, AGENTS.md, skills, prompts, extensions                                                            |
| 🔌 **MCP**            | Shared MCP server config (`chrome-devtools`)                                                                        |

---

## 🚀 Quick start

```sh
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

Bootstrap runs in this order:

1. `dotfiles install` — creates `~/.local/bin/dotfiles` symlink
2. `dotfiles installers` — installs NVM and zgen if missing
3. `dotfiles sync --to system` — deploys all managed config files
4. `dotfiles defaults` — applies macOS system defaults (requires `sudo`)
5. `dotfiles brew` — installs Homebrew packages and casks
6. `dotfiles npm` — installs managed npm global packages

```
Bootstrap complete. Run 'dotfiles status' to verify.
```

---

## 🎬 Screenshots

> 📸 _Screenshots and GIFs coming soon — no image assets in repo yet._
>
> **TODO:** Add terminal recordings for:
>
> - `dotfiles status` output
> - `dotfiles sync` interactive flow
> - Starship prompt in action
> - `dotfiles diff` with delta colours

---

## 🔁 Core mental model

Every managed config lives in two places: **repo** and **system**. The `dotfiles` CLI is the bridge.

```
repo (~/dotfiles/)  ←→  system (~/, ~/.config/, ~/.pi/agent/)
```

- **Deploy** (`repo → system`): push changes from repo to the live machine
- **Backfill** (`system → repo`): pull changes from the machine back into the repo
- **Status/diff**: see what's out of sync without touching anything

---

## 🧰 The `dotfiles` command

After bootstrap, `dotfiles` is available anywhere via `~/.local/bin/dotfiles`.

```
dotfiles status              Show which managed files differ
dotfiles diff                Detailed diff for every changed file
dotfiles sync                Interactive: choose direction per changed item
dotfiles sync --to system    Deploy all from repo → system
dotfiles sync --to repo      Backfill all from system → repo
dotfiles brew                Preview and run Homebrew bundle
dotfiles brew-cleanup        Uninstall Homebrew packages not listed in brew files
dotfiles npm                 Check and install managed npm globals
dotfiles defaults            Preview and apply macOS system defaults
dotfiles check               Run shellcheck/shfmt/bash -n on all shell files
dotfiles install             (Re)create ~/.local/bin/dotfiles symlink
dotfiles installers          Install NVM and zgen if missing
```

Aliases: `deploy` = `sync --to system`, `backfill` = `sync --to repo`.

Add `--yes` to skip confirmation prompts on `sync --to`, `brew`, `brew-cleanup`, `npm`, and `defaults`.

### 📋 Typical workflows

**Check what's out of sync:**

```sh
dotfiles status
dotfiles diff
```

**Deploy repo changes to the machine:**

```sh
dotfiles deploy
# or choose per-file interactively:
dotfiles sync
```

**Pull machine changes back to repo:**

```sh
dotfiles backfill
```

**After editing Pi agent config in the app:**

```sh
dotfiles backfill
```

**Full re-bootstrap after pulling updates:**

```sh
git pull && ./bootstrap.sh
```

---

## 📦 Managed files

Defined in `lib/manifest.sh`. Everything in this table is tracked by `dotfiles sync`.

| Group  | Repo path                        | System path                                                          |
| ------ | -------------------------------- | -------------------------------------------------------------------- |
| config | `config/git/.gitconfig`          | `~/.gitconfig`                                                       |
| config | `config/git/themes.gitconfig`    | `~/themes.gitconfig`                                                 |
| config | `config/terminal/starship.toml`  | `~/.config/starship.toml`                                            |
| config | `config/terminal/.hyper.js`      | `~/.hyper.js`                                                        |
| config | `config/terminal/config.ghostty` | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |
| config | `config/zsh/.zshrc`              | `~/.zshrc`                                                           |
| config | `config/zsh/` (dir)              | `~/.config/zsh/`                                                     |
| pi     | `config/pi/AGENTS.md`            | `~/.pi/agent/AGENTS.md`                                              |
| pi     | `config/pi/settings.json`        | `~/.pi/agent/settings.json`                                          |
| pi     | `config/pi/models.json`          | `~/.pi/agent/models.json`                                            |
| pi     | `config/pi/zsh-shell`            | `~/.pi/agent/zsh-shell`                                              |
| pi     | `config/pi/agents/` (dir)        | `~/.pi/agent/agents/`                                                |
| pi     | `config/pi/skills/` (dir)        | `~/.pi/agent/skills/`                                                |
| pi     | `config/pi/extensions/` (dir)    | `~/.pi/agent/extensions/`                                            |
| pi     | `config/pi/themes/` (dir)        | `~/.pi/agent/themes/`                                                |
| pi     | `config/pi/prompts/` (dir)       | `~/.pi/agent/prompts/`                                               |
| mcp    | `config/mcp/mcp.json`            | `~/.config/mcp/mcp.json`                                             |

**Optional** (synced only if present):

| Repo path                    | System path                    |
| ---------------------------- | ------------------------------ |
| `config/pi/SYSTEM.md`        | `~/.pi/agent/SYSTEM.md`        |
| `config/pi/APPEND_SYSTEM.md` | `~/.pi/agent/APPEND_SYSTEM.md` |
| `config/pi/keybindings.json` | `~/.pi/agent/keybindings.json` |

---

## 🍺 Homebrew + npm globals

Packages are split across three files:

**`brew/Brewfile`** — Homebrew formulae (CLI and dev tooling)

Examples: `gh`, `git-delta`, `glab`, `fd`, `fzf`, `neovim`, `mysql-client`, `bottom`, `htop`, `yarn`, `opentofu`, `tflint`.

**`brew/Caskfile`** — Homebrew casks (GUI apps, CLI-distributed casks, fonts, runtimes)

Examples: `ghostty`, `docker-desktop`, `1password-cli`, `claude-code`, `codex`, `font-jetbrains-mono-nerd-font`, `temurin@11`.

**`npm/globals.txt`** — managed npm global packages

- `@earendil-works/pi-coding-agent`
- `corepack`
- `openclaw`

`dotfiles brew` checks what’s missing and runs `brew bundle` for both brew files.

`dotfiles brew-cleanup` previews and removes Homebrew formulae/casks not listed in `brew/Brewfile` or `brew/Caskfile`.

`dotfiles npm` ensures the default NVM Node version exists, then installs globals from `npm/globals.txt`.

---

## 🍎 macOS defaults

> ⚠️ **`dotfiles defaults` requests `sudo` and restarts Dock, Finder, and SystemUIServer.** Review `defaults/system.sh` before running if you want to keep existing preferences.

**`defaults/system.sh`** applies:

| Category         | What changes                                                                               |
| ---------------- | ------------------------------------------------------------------------------------------ |
| Keyboard         | Fast repeat rate, no smart quotes/dashes/autocorrect, full keyboard access (Tab in modals) |
| Finder           | Show hidden files, show extensions, path bar, list view, home dir as default window        |
| Dock             | Auto-hide, translucent hidden apps, no bounce, no recent apps, indicator lights            |
| Screenshots      | PNG format, no shadow, saves to Desktop                                                    |
| Software updates | Auto check + background download enabled                                                   |
| General          | iCloud doesn't own new documents, no crash reporter dialog, no LSQuarantine dialog         |

**`defaults/chrome.sh`** — disables swipe navigation in Chrome.

**`defaults/transmission.sh`** — sets sensible Transmission download defaults (incomplete folder, auto-delete torrents).

---

## 🐚 ZSH setup

Config split across three files in `config/zsh/`:

**`.zshrc`** — main shell init:

- Tab completion with menu select
- History: 50k size, dedup, `EXTENDED_HISTORY`, incremental append
- `AUTO_CD`, `CHASE_LINKS`
- PATH: `~/.local/bin`, `/usr/local/sbin`, Homebrew MySQL client
- `$EDITOR` / `$VISUAL` → `nvim`
- fzf key bindings and fuzzy file search
- Sources `aliases.zsh` and `functions.zsh`
- zgen plugins: `zsh-syntax-highlighting`, `zsh-history-substring-search`, `zsh-autosuggestions`
- Starship prompt init
- 1Password completions
- NVM bootstrap (lazy-loaded with auto-switch on `.nvmrc`)
- chruby

**`aliases.zsh`** — highlights:

- `vim` → `nvim`, `cat` → `bat`, `top` → `btm`
- `g`, `ga`, `gaa`, `gb`, `gcl`, `gcmsg`, `gd`, `gp`, `gl`, `gss`, `gsv`, `gco`, `glog`, `gloga`, `gpristine`
- `z` — reload ZSH config
- `fd` → `find`, `t` → `tail -f`, `sgrep` — recursive grep with context

**`functions.zsh`** — highlights:

- `rimraf` — nuke all `node_modules` dirs recursively
- `setSecret` — pull a 1Password secret into env
- `loadNvmrc` — auto-switch Node version on `cd` when `.nvmrc` found
- `pi()` — wrapper that runs Pi using its pinned Node version, unaffected by `.nvmrc` overrides

---

## 🧬 Git config

`config/git/.gitconfig`:

- **Pager**: `git-delta` with `calochortus-lyallii` theme
- **Interactive**: delta for `add -p`
- **Merge**: `diff3` conflict style
- **GPG**: commit and tag signing enabled
- **Push**: `autoSetupRemote = true`, `default = current`
- **Includes**: `~/user.gitconfig` (personal name/email) and `~/themes.gitconfig`

`~/user.gitconfig` is created on first install **only if it doesn't exist** — edit it to set your name and email.

---

## 🤖 Pi agent config

`config/pi/` holds portable Pi coding agent config:

| File/Dir        | Purpose                                                                                         |
| --------------- | ----------------------------------------------------------------------------------------------- |
| `settings.json` | Agent settings: default model (`gpt-5.5`), enabled models, packages, UI options                 |
| `models.json`   | Provider config: Anthropic (via proxy), OpenRouter (Auto, Qwen, DeepSeek)                       |
| `AGENTS.md`     | Global agent instructions: caveman mode, commit rules, context protection                       |
| `agents/`       | Custom subagents: `git-workflow`, `frontend-ui-builder`                                         |
| `skills/`       | Skill definitions: `git-workflow`, `node-npm`, `notion-doc-writing`, `php-symfony`, `shadcn-ui` |
| `prompts/`      | Custom prompt templates, including `/ui-rebuild`                                                |
| `extensions/`   | Local Pi extensions                                                                             |
| `themes/`       | UI themes                                                                                       |
| `zsh-shell`     | Shell config for Pi's embedded shell                                                            |

**Installed packages** (from `settings.json`):

- `pi-caveman` — caveman mode responses
- `pi-mcp-adapter` — MCP server integration
- `@feniix/pi-notion` — Notion integration
- `pi-subagents` — subagent support
- `pi-powerline-footer` — powerline status bar

**Private/local state** (not committed, excluded by `.gitignore`):

```
config/pi/sessions/
config/pi/auth/
config/pi/git/
config/pi/npm/
config/pi/**/*.local.json
config/pi/**/.env
```

## 🔌 MCP config

`config/mcp/mcp.json` is source of truth for shared MCP servers, synced to `~/.config/mcp/mcp.json`.

**Current servers:**

| Server            | How it runs                         |
| ----------------- | ----------------------------------- |
| `chrome-devtools` | `npx -y chrome-devtools-mcp@latest` |

---

## 🧪 Validation

Git hooks managed via [Lefthook](https://github.com/evilmartians/lefthook).

```sh
brew install lefthook
lefthook install
```

**Pre-commit** (parallel): Prettier formatting, shfmt formatting, shellcheck linting, bash syntax check.

**Pre-push** (parallel): Prettier check, shfmt lint, shellcheck, bash syntax check.

Validate shell files manually:

```sh
dotfiles check
```

Or directly:

```sh
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shfmt -d
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -I {} bash -n {}
```

---

## 🗂️ Repository layout

```
.
├── bin/
│   └── dotfiles              # Primary CLI (all sync/diff/deploy commands)
├── lib/
│   └── manifest.sh           # Managed paths (repo ↔ system mapping)
├── bootstrap.sh              # Full install: install → installers → sync → defaults → brew → npm
├── brew/
│   ├── Brewfile              # Homebrew formulae
│   └── Caskfile              # Homebrew casks
├── npm/
│   └── globals.txt           # Managed npm global packages
├── config/
│   ├── git/                  # .gitconfig, themes.gitconfig, user.gitconfig template
│   ├── mcp/                  # Shared MCP server config
│   ├── terminal/             # starship.toml, .hyper.js, config.ghostty
│   ├── zsh/                  # .zshrc, aliases.zsh, functions.zsh
│   └── pi/                   # Pi agent: settings, models, AGENTS.md, skills, prompts…
└── defaults/
    ├── system.sh             # macOS defaults: keyboard, Finder, Dock, screenshots
    ├── chrome.sh             # Chrome-specific defaults
    └── transmission.sh       # Transmission download defaults
```

---

## ⚙️ Prerequisites

- macOS
- Git (via Xcode CLT: `xcode-select --install`)
- Internet access (Homebrew and NVM installed automatically if missing)
