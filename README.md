# .files

This is my dotfile configuration. It includes ZSH config, Brew/Cask scripts and MacOS system defaults.

To install all config:

`./bootstrap.sh`

To install individual configs:

- MacOS defaults: `defaults.sh`
- Dotfile config: `config.sh`
- Homebrew & packages: `brew.sh`

## contributing

Git hooks via [Lefthook](https://github.com/evilmartians/lefthook).

- `brew install lefthook` - For the binary
- `lefthook install` - To install the hook scripts
