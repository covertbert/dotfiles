# 🏠 dotfiles

My personal macOS dotfiles. One command to go from a blank Mac to a fully configured dev machine. Everything tracked, versioned, and sync-able.

> ⚠️ **Warning:** `bootstrap.sh` and `dotfiles sync --to system` will **overwrite** managed config files in your home directory without prompting. Back up anything you want to keep before running.

---

## 🗺️ What's managed

| Area                  | What it covers                                                                                           |
| --------------------- | -------------------------------------------------------------------------------------------------------- |
| 🐚 **ZSH**            | `.zshrc`, aliases, functions, plugins, prompt, fnm, plus private `.zshrc.local` backup through 1Password |
| 🧬 **Git**            | `.gitconfig` with delta diffs, GPG signing, branch/push defaults, includes                               |
| 🍎 **macOS defaults** | Keyboard, Finder, Dock, screenshots, Trash, software updates, Chrome, Transmission                       |
| 🍺 **Homebrew**       | CLI tools (`Brewfile`) and GUI apps/fonts (`Caskfile`)                                                   |
| 🖥️ **Terminal**       | Hyper config, Ghostty config, Starship theme                                                             |
| 🤖 **Pi agent**       | Settings, models, AGENTS.md, skills, prompts, extensions                                                 |
| 🔀 **Pi + Meridian**  | Rewrite proxy, launchd service, lifecycle commands, and managed dependencies                             |
| 🔌 **MCP**            | Shared MCP server config (Chrome DevTools, GitLab, Notion, LinearB)                                      |

---

## 🚀 Quick start

```sh
git clone https://github.com/covertbert/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

Bootstrap runs in this order:

1. `dotfiles install` — creates `~/.local/bin/dotfiles` symlink
2. Homebrew setup — installs Homebrew if missing and loads its environment
3. `dotfiles installers` — installs zgen if missing
4. `dotfiles brew` — installs Homebrew packages, including fnm, and casks
5. `dotfiles npm` — installs managed npm global packages
6. `dotfiles sync --to system` — deploys all managed config files
7. `dotfiles defaults` — applies macOS system defaults (requires `sudo`)
8. `dotfiles pi-meridian setup` — deploys and starts the local Pi → Meridian stack

```
Bootstrap complete. Run 'dotfiles status' to verify.
```

Claude authentication remains manual on a new machine:

```sh
claude login
dotfiles pi-meridian restart
dotfiles pi-meridian status
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
dotfiles zsh-local <action>  Back up and restore ~/.zshrc.local with 1Password
dotfiles pi-meridian <action> Set up and manage the Pi → Meridian service
dotfiles defaults            Preview and apply macOS system defaults
dotfiles check               Validate shell, proxy, tests, and launchd plist
dotfiles install             (Re)create ~/.local/bin/dotfiles symlink
dotfiles installers          Install zgen if missing
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

**Edit private ZSH config and back it up:**

```sh
dotfiles zsh-local edit
```

**Full re-bootstrap after pulling updates:**

```sh
git pull && ./bootstrap.sh
```

---

## 📦 Managed files

Defined in `lib/manifest.sh`. Everything in this table is tracked by `dotfiles sync`.

| Group   | Repo path                                                 | System path                                                          |
| ------- | --------------------------------------------------------- | -------------------------------------------------------------------- |
| config  | `config/git/.gitconfig`                                   | `~/.gitconfig`                                                       |
| config  | `config/git/themes.gitconfig`                             | `~/themes.gitconfig`                                                 |
| config  | `config/terminal/starship.toml`                           | `~/.config/starship.toml`                                            |
| config  | `config/terminal/.hyper.js`                               | `~/.hyper.js`                                                        |
| config  | `config/terminal/config.ghostty`                          | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |
| config  | `config/zsh/.zshrc`                                       | `~/.zshrc`                                                           |
| config  | `config/zsh/` (dir)                                       | `~/.config/zsh/`                                                     |
| pi      | `config/pi/AGENTS.md`                                     | `~/.pi/agent/AGENTS.md`                                              |
| pi      | `config/pi/settings.json`                                 | `~/.pi/agent/settings.json`                                          |
| pi      | `config/pi/models.json`                                   | `~/.pi/agent/models.json`                                            |
| pi      | `config/pi/zsh-shell`                                     | `~/.pi/agent/zsh-shell`                                              |
| pi      | `config/pi/agents/` (dir)                                 | `~/.pi/agent/agents/`                                                |
| pi      | `config/pi/skills/` (dir)                                 | `~/.pi/agent/skills/`                                                |
| pi      | `config/pi/extensions/` (dir)                             | `~/.pi/agent/extensions/`                                            |
| pi      | `config/pi/themes/` (dir)                                 | `~/.pi/agent/themes/`                                                |
| pi      | `config/pi/prompts/` (dir)                                | `~/.pi/agent/prompts/`                                               |
| service | `services/pi-meridian/pi-meridian-proxy.mjs`              | `~/.local/bin/pi-meridian-proxy.mjs`                                 |
| service | `services/pi-meridian/pi-meridian-stack.sh`               | `~/.local/bin/pi-meridian-stack.sh`                                  |
| service | `services/pi-meridian/com.bertie.pi-meridian-stack.plist` | `~/Library/LaunchAgents/com.bertie.pi-meridian-stack.plist`          |
| mcp     | `config/mcp/mcp.json`                                     | `~/.config/mcp/mcp.json`                                             |

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
- `@rynfar/meridian`
- `corepack`
- `openclaw`

`dotfiles brew` checks what’s missing and runs `brew bundle` for both brew files.

`dotfiles brew-cleanup` previews and removes Homebrew formulae/casks not listed in `brew/Brewfile` or `brew/Caskfile`.

`dotfiles npm` treats `npm/globals.txt` as source of truth for fnm's resolved default Node. npm globals are isolated per Node installation, so a new Node patch starts with an empty global prefix. The command reports packages found under older fnm versions, checks both package metadata and expected global binaries, repairs missing or broken installs under the current default and never removes old runtimes.

After verifying no project needs an old runtime, clean it up explicitly:

```sh
fnm list
fnm uninstall <version>
```

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
- fnm default runtime with recursive `.nvmrc` switching on shell startup and `cd`
- chruby

**`aliases.zsh`** — highlights:

- `vim` → `nvim`, `cat` → `bat`, `top` → `btm`
- `g`, `ga`, `gaa`, `gb`, `gcl`, `gcmsg`, `gd`, `gp`, `gl`, `gss`, `gsv`, `gco`, `glog`, `gloga`, `gpristine`
- `z` — reload ZSH config
- `fd` → `find`, `t` → `tail -f`, `sgrep` — recursive grep with context

**`functions.zsh`** — highlights:

- `rimraf` — nuke all `node_modules` dirs recursively
- `setSecret` — pull a 1Password secret into env
- `_fnm_auto_use` — auto-install and switch Node from the nearest `.nvmrc`
- `pi()` — runs Pi through fnm's exact default Node and auto-updates Pi plus unpinned packages at most once per day before interactive runs

### Private `.zshrc.local` backup

`~/.zshrc.local` remains outside Git and is sourced by the managed `.zshrc`. The `zsh-local` command stores an encrypted backup as a 1Password Document. Local content is the normal source of truth; restore is always explicit.

First-time setup uses the `Private` vault and document title `dotfiles: .zshrc.local` by default:

```sh
dotfiles zsh-local setup
```

Use another vault or title when needed:

```sh
dotfiles zsh-local setup --vault "Dotfiles" --document "shell: .zshrc.local"
```

Normal change flow:

```sh
dotfiles zsh-local edit    # check remote, open $EDITOR, validate, upload
dotfiles zsh-local status  # compare copies without showing contents
dotfiles zsh-local push    # upload changes made outside the edit command
```

Restore on a new machine by running `dotfiles zsh-local setup`; when the local file is missing and the Document exists, setup restores it automatically. Later restores are explicit:

```sh
dotfiles zsh-local pull
```

Push refuses when the 1Password copy changed since the last successful sync. Pull refuses when local content has unsynced changes. Inspect the Document in 1Password, then resolve deliberately:

```sh
dotfiles zsh-local push --force  # local wins
dotfiles zsh-local pull --force  # 1Password wins
```

Enable **Settings → Developer → Integrate with 1Password CLI** in the 1Password desktop app. Commands may request Touch ID or device authentication. No service account, background process, or permanent token is used.

Sync state contains only item/vault identifiers and a content hash under `~/.local/state/dotfiles/zsh-local/`. Pulled files use mode `0600`. File contents are never printed by these commands.

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
| `models.json`   | Provider config: Anthropic (via proxy), OpenRouter (DeepSeek V4 Pro)                            |
| `AGENTS.md`     | Global agent instructions: caveman mode, commit rules, context protection                       |
| `agents/`       | Reserved local agent directory                                                                  |
| `skills/`       | Skill definitions: `considered-writing`, `git-workflow`, `node-npm`, `php-symfony`, `shadcn-ui` |
| `prompts/`      | Custom prompt templates, including `/ui-rebuild`                                                |
| `extensions/`   | Local Pi extensions                                                                             |
| `themes/`       | UI themes                                                                                       |
| `zsh-shell`     | Shell config for Pi's embedded shell                                                            |

**Installed packages** (from `settings.json`):

- `pi-caveman` — caveman mode responses
- `pi-mcp-adapter` — MCP server integration
- `@feniix/pi-notion` — Notion integration
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

| Server            | How it runs/auths                                                   |
| ----------------- | ------------------------------------------------------------------- |
| `chrome-devtools` | `npx -y chrome-devtools-mcp@latest`                                 |
| `gitlab`          | `npx -y @zereight/mcp-gitlab`, reads `GITLAB_PERSONAL_ACCESS_TOKEN` |
| `notion`          | Remote MCP at `https://mcp.notion.com/mcp`, OAuth                   |
| `linearb`         | Remote MCP at `https://mcp.linearb.io/mcp`, reads `LINEARB_API_KEY` |

**LinearB setup:**

1. In LinearB, go to **Settings → API Tokens** and generate an admin API key.
2. Export it before launching Pi so Pi inherits it: `export LINEARB_API_KEY="..."`.
   - Prefer 1Password: `setSecret LINEARB_API_KEY` if item/field matches.
   - Or store local-only export in `~/.zshrc.local` if plaintext local secret is acceptable.
3. Run `dotfiles deploy` to sync `config/mcp/mcp.json` to `~/.config/mcp/mcp.json`.
4. Restart Pi from that shell, then verify MCP server `linearb` connects.

Do not commit API keys. Repo stores only env var reference.

---

## 🔀 Pi + Meridian service

Pi sends Anthropic requests through a local prompt-rewrite proxy before Meridian forwards them through Claude Code:

```text
Pi → rewrite proxy :3457 → Meridian :3456 → Claude Code → Claude subscription
```

Dependencies are managed by existing installers:

- Node 24 through fnm (`.nvmrc` records the repo runtime)
- Claude Code through `brew/Caskfile`
- Pi and Meridian through `npm/globals.txt`
- `curl`, `launchctl`, and `plutil` from macOS

The rewrite proxy uses only Node built-ins. No local `node_modules` or API key is required.

### Lifecycle

```sh
dotfiles pi-meridian setup    # deploy files, reload launchd, check health/auth
dotfiles pi-meridian status   # show service, endpoint, CLI, and auth status
dotfiles pi-meridian restart  # restart or reload the launch agent
dotfiles pi-meridian stop     # disable and unload the launch agent
dotfiles pi-meridian logs     # show the last 100 lines from each service log
```

Logs live under `~/Library/Logs/pi-meridian/`:

- `stack.log`
- `meridian.log`
- `proxy.log`

Both services bind only to `127.0.0.1`. Do not expose ports `3456` or `3457` externally. Claude credentials remain local and are never synced by this repo.

The proxy warns in `proxy.log` if a Pi update changes the two exact system-prompt sections it expects to rewrite. Update the rewrite strings and tests together when that happens.

---

## 🧪 Validation

Git hooks managed via [Lefthook](https://github.com/evilmartians/lefthook).

```sh
brew install lefthook
lefthook install
```

**Pre-commit** (parallel): Prettier and shfmt formatting, shellcheck, bash/Node syntax, proxy tests, plist lint.

**Pre-push** (parallel): Prettier and shfmt checks, shellcheck, bash/Node syntax, proxy tests, plist lint.

Validate repo files manually:

```sh
dotfiles check
```

Or directly:

```sh
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shfmt -d
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -I {} bash -n {}
node --check services/pi-meridian/pi-meridian-proxy.mjs
node --test services/pi-meridian/pi-meridian-proxy.test.mjs
bash tests/zsh-local-sync.test.sh
plutil -lint services/pi-meridian/com.bertie.pi-meridian-stack.plist
```

---

## 🗂️ Repository layout

```
.
├── bin/
│   └── dotfiles              # Primary CLI (all sync/diff/deploy commands)
├── lib/
│   ├── manifest.sh           # Managed paths (repo ↔ system mapping)
│   └── zsh-local-sync.sh     # Interactive 1Password backup/restore engine
├── tests/
│   └── zsh-local-sync.test.sh # Mocked secret-sync safety tests
├── bootstrap.sh              # Full install through Pi → Meridian service setup
├── brew/
│   ├── Brewfile              # Homebrew formulae
│   └── Caskfile              # Homebrew casks
├── npm/
│   └── globals.txt           # Managed npm global packages
├── services/
│   └── pi-meridian/          # Rewrite proxy, tests, stack wrapper, launch agent
├── config/
│   ├── git/                  # .gitconfig, themes.gitconfig, user.gitconfig template
│   ├── mcp/                  # Shared MCP server config
│   ├── terminal/             # starship.toml, .hyper.js, config.ghostty
│   ├── zsh/                  # .zshrc, aliases.zsh, functions.zsh
│   └── pi/                   # Pi agent: settings, models, AGENTS.md, skills, prompts…
├── .nvmrc                    # Node runtime used by repo tooling and proxy tests
└── defaults/
    ├── system.sh             # macOS defaults: keyboard, Finder, Dock, screenshots
    ├── chrome.sh             # Chrome-specific defaults
    └── transmission.sh       # Transmission download defaults
```

---

## ⚙️ Prerequisites

- macOS
- Git (via Xcode CLT: `xcode-select --install`)
- Internet access (Homebrew and fnm installed automatically if missing)
