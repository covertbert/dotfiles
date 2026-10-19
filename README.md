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
| 🤖 **Pi agent**       | Settings, models, AGENTS.md, skills, prompts, extensions; Anthropic API key from private `.zshrc.local`  |
| 🔌 **MCP**            | Shared MCP server config (Chrome DevTools, GitLab, Notion, LinearB, Datadog, Spacelift)                  |

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
4. `dotfiles brew` — installs Homebrew packages, including fnm and Herdr, and casks
5. `dotfiles npm` — installs managed npm global packages
6. `dotfiles sync --to system` — deploys all managed config files, including Pi's Herdr extension
7. `dotfiles defaults` — applies macOS system defaults (requires `sudo`)

```
Bootstrap complete. Run 'dotfiles status' to verify.
```

Anthropic access on a new machine is manual: store the API key in private `~/.zshrc.local` (see [Anthropic API access](#-anthropic-api-access)), then run `dotfiles zsh-local setup` to restore it from 1Password.

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
dotfiles defaults            Preview and apply macOS system defaults
dotfiles check               Validate shell config and tests
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

| Group  | Repo path                        | System path                                                          |
| ------ | -------------------------------- | -------------------------------------------------------------------- |
| config | `config/git/.gitconfig`          | `~/.gitconfig`                                                       |
| config | `config/git/themes.gitconfig`    | `~/themes.gitconfig`                                                 |
| config | `config/terminal/starship.toml`  | `~/.config/starship.toml`                                            |
| config | `config/terminal/.hyper.js`      | `~/.hyper.js`                                                        |
| config | `config/terminal/config.ghostty` | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |
| config | `config/ponytail/config.json`    | `~/.config/ponytail/config.json`                                     |
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

Examples: `gh`, `git-delta`, `glab`, `fd`, `fzf`, `herdr`, `neovim`, `mysql-client`, `bottom`, `htop`, `yarn`, `opentofu`, `tflint`.

**`brew/Caskfile`** — Homebrew casks (GUI apps, CLI-distributed casks, fonts, runtimes)

Examples: `ghostty`, `docker-desktop`, `1password-cli`, `claude-code`, `codex`, `font-jetbrains-mono-nerd-font`, `temurin@11`.

**`npm/globals.txt`** — managed npm global packages

- `@earendil-works/pi-coding-agent`
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
- `gitlab-main-push` — add or remove your account from the explicit push allowlist on `main` for the current repository (`gitlab-main-push status` reports membership without changing anything)
- `pi()` — runs Pi through fnm's exact default Node and auto-updates Pi plus unpinned packages at most once per day before interactive runs

### `gitlab-main-push`

Adds or removes the authenticated `glab` account in the current repository's GitLab protected-branch rule for `main`. It only touches your own explicit `user_id` push access entry; role, group, deploy-key, merge, unprotect, and force-push settings are left alone.

```sh
gitlab-main-push           # toggle your explicit entry
gitlab-main-push status    # report membership, no writes
```

Requires `glab` authenticated against the repository's GitLab host, `jq`, and an account allowed to edit the protection rule. Individual allowlist entries need GitLab Premium or Ultimate.

Limits: it reports allowlist membership, not effective permission — removing the entry does not block pushes when a matching role, group, or other rule still grants access. Only the exact `main` rule is edited; wildcard and inherited protection is refused. A failed PATCH can leave the outcome uncertain, so check `status` before retrying.

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

| File/Dir        | Purpose                                                                                        |
| --------------- | ---------------------------------------------------------------------------------------------- |
| `settings.json` | Agent settings: default model (`gpt-5.5`), enabled models, packages, UI options                |
| `models.json`   | Custom provider config: RunAI, OpenRouter, OpenCode Zen. Anthropic uses Pi's built-in provider |
| `AGENTS.md`     | Global agent instructions: caveman mode, commit rules, context protection                      |
| `agents/`       | Reserved local agent directory                                                                 |
| `skills/`       | Skill definitions, including `coderabbit-review`, `git-workflow` and repository toolchains     |
| `prompts/`      | Custom prompt templates, including `/coderabbit` and `/ui-rebuild`                             |
| `extensions/`   | Local Pi extensions, including Herdr lifecycle and session reporting                           |
| `themes/`       | UI themes                                                                                      |
| `zsh-shell`     | Shell config for Pi's embedded shell                                                           |

**Installed packages** (from `settings.json`):

- `pi-caveman` — caveman mode responses
- `pi-mcp-adapter` — MCP server integration
- `@feniix/pi-notion` — Notion integration
- `pi-powerline-footer` — powerline status bar
- `@dietrichgebert/ponytail@4.8.4` — minimal-code rules, commands and status indicator
- `@mcuste/pi-diagram@0.6.2` — D2-backed diagrams in Pi

### Ponytail

Ponytail runs alongside Caveman: Caveman keeps responses terse while Ponytail prefers smallest safe code change. Package source is pinned in `config/pi/settings.json`; Pi installs it under `~/.pi/agent/npm/`, which remains local and is not synced. `config/ponytail/config.json` sets synced default mode.

```sh
/ponytail status
/ponytail lite|full|ultra
/ponytail-review
```

Update deliberately: change package version in `config/pi/settings.json`, deploy, then run `pi update --extensions`. `normal mode` disables Ponytail for current session.

**Private/local state** (not committed, excluded by `.gitignore`):

```
config/pi/sessions/
config/pi/auth/
config/pi/git/
config/pi/npm/
config/pi/**/*.local.json
config/pi/**/.env
```

## 🐑 Herdr + Pi

Herdr is terminal-native persistent workspace for coding agents. Homebrew installs `herdr`; managed Pi extension reports lifecycle state and session identity when Pi runs inside Herdr.

```sh
cd ~/Projects/project
herdr
# Start `pi` in a Herdr pane.
```

Verify integration after deployment:

```sh
herdr integration status
```

Update flow: when Herdr reports Pi integration outdated, run `herdr integration install pi`, copy generated `~/.pi/agent/extensions/herdr-agent-state.ts` into `config/pi/extensions/`, review and commit it, then deploy. Do not edit generated extension directly.

For remote host, bootstrap this dotfiles repo on host before attaching:

```sh
ssh workbox
cd ~/dotfiles && ./bootstrap.sh
cd ~/Projects/project && herdr
```

Then attach from another machine with `herdr --remote workbox`.

## 🔌 MCP config

`config/mcp/mcp.json` and `config/mcp/dbhub.toml` are source of truth for shared MCP servers, synced to `~/.config/mcp/`.

**Current servers:**

| Server            | How it runs/auths                                                                       |
| ----------------- | --------------------------------------------------------------------------------------- |
| `chrome-devtools` | `npx -y chrome-devtools-mcp@latest`                                                     |
| `gitlab`          | `npx -y @zereight/mcp-gitlab`, reads `GITLAB_PERSONAL_ACCESS_TOKEN`                     |
| `notion`          | Remote MCP at `https://mcp.notion.com/mcp`, OAuth                                       |
| `linearb`         | Remote MCP at `https://mcp.linearb.io/mcp`, reads `LINEARB_API_KEY`                     |
| `datadog`         | Remote EU MCP at `https://mcp.datadoghq.eu/v1/mcp`, reads `DD_API_KEY` and `DD_APP_KEY` |
| `spacelift`       | Remote MCP at `https://airtimerewards.app.spacelift.io/mcp`, OAuth                      |
| `dbhub`           | Local `npx @bytebase/dbhub`, reads Zsh environment secrets                              |

**LinearB setup:**

1. In LinearB, go to **Settings → API Tokens** and generate an admin API key.
2. Export it before launching Pi so Pi inherits it: `export LINEARB_API_KEY="..."`.
   - Prefer 1Password: `setSecret LINEARB_API_KEY` if item/field matches.
   - Or store local-only export in `~/.zshrc.local` if plaintext local secret is acceptable.
3. Run `dotfiles deploy` to sync `config/mcp/mcp.json` to `~/.config/mcp/mcp.json`.
4. Restart Pi from that shell, then verify MCP server `linearb` connects.

**Spacelift setup:**

1. On first connection, authenticate in browser and choose `mcp:read` or `mcp:write`.
2. Run `dotfiles deploy`, then restart Pi or run `/reload`.
3. Verify with `mcp({ connect: "spacelift" })` and a harmless read-only query.

Write tools `mutate` and `intent` require explicit approval in Pi.

**Datadog EU setup:**

1. Store `DD_API_KEY` and `DD_APP_KEY` in private `~/.zshrc.local`; restore this file with `dotfiles zsh-local setup` on a new machine.
2. Start Pi from a fresh Zsh session so it inherits both variables. Datadog server maps `DD_APP_KEY` to its required `DD_APPLICATION_KEY` request header.
3. Run `dotfiles deploy`, then restart Pi or run `/reload`.
4. Verify with `mcp({ connect: "datadog" })`, then search and call a harmless read-only tool.

Datadog starts with default `core` toolset. Add named toolsets only when needed; avoid `toolsets=all` unless broad tool discovery is required.

**Zorro production database setup:**

1. Add secrets to private `~/.zshrc.local`:

   ```sh
   export ZORRO_PRODUCTION_USER="zorro"
   export ZORRO_PRODUCTION_PASSWORD="..."
   ```

2. Run `dotfiles deploy`, then start Pi from fresh Zsh shell.
3. Ask Pi `show databases on zorro-production`, then ask it to inspect table `production` in correct database.

Do not commit API keys or database passwords. Repo stores only environment variable references.

---

## 🔑 Anthropic API access

Pi's built-in `anthropic` provider talks directly to `https://api.anthropic.com` using an API key from the environment. No local proxy, rewrite service, or Claude Code dependency is involved.

```text
Pi → api.anthropic.com
```

The key lives in private `~/.zshrc.local`, which the managed `.zshrc` sources and `dotfiles zsh-local` backs up to 1Password. The repo never stores it.

```sh
dotfiles zsh-local edit   # add: export ANTHROPIC_API_KEY="..."
# open a fresh shell so Pi inherits it
```

Pi credential precedence is runtime `--api-key`, stored `auth.json`, `models.json`, then the provider environment variable. `config/pi/models.json` no longer overrides the `anthropic` provider, so the environment key is used unless a stored credential exists. Remove a stale credential with `/logout anthropic` if Anthropic appears in `/login`.

---

## 🧪 Validation

Git hooks managed via [Lefthook](https://github.com/evilmartians/lefthook).

```sh
brew install lefthook
lefthook install
```

**Pre-commit** (parallel): Prettier and shfmt formatting, shellcheck, bash syntax, Zsh-local tests.

**Pre-push** (parallel): Prettier and shfmt checks, shellcheck, bash syntax, Zsh-local tests.

Validate repo files manually:

```sh
dotfiles check
```

Or directly:

```sh
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shfmt -d
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -I {} bash -n {}
bash tests/zsh-local-sync.test.sh
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
├── bootstrap.sh              # Full install through macOS defaults application
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
├── .nvmrc                    # Node runtime used by repo tooling
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
