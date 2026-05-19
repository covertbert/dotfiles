# .files

This is my dotfile configuration. It includes ZSH config, Brew/Cask scripts and MacOS system defaults.

> Shell configs aligned  
> Home directory at peace  
> One script rules them all

To install all config:

`./bootstrap.sh`

To install individual configs:

- MacOS defaults: `defaults.sh`
- Dotfile config: `config.sh`
- Homebrew & packages: `brew.sh`

To backfill current Pi config into this repo:

- Pi config: `pi-backfill.sh`

## contributing

Git hooks via [Lefthook](https://github.com/evilmartians/lefthook).

- `brew install lefthook` - For the binary
- `lefthook install` - To install the hook scripts

Validate shell changes without running the full bootstrap:

```sh
find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck && find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shfmt -d && find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -I {} bash -n {}
```
