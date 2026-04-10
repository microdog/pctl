# Codebase Map

## Overview

`pctl` is a small Zsh plugin that toggles proxy-related environment variables in the current shell session.

## Files

- `init.zsh`
  Loads the plugin autoload directory, autoloads `pctl`, and registers completion when `compinit` is already active.
- `autoload/pctl`
  Main command implementation for `--set`, `--unset`, `--status`, `--help`, and `--version`.
  Manages lowercase and uppercase proxy variables plus optional `no_proxy` state.
- `autoload/_pctl`
  Zsh completion definition for the `pctl` command.
- `tests/smoke.zsh`
  Black-box smoke tests that run the plugin in clean `zsh` processes and verify runtime behavior.
- `README.md`
  User-facing installation, configuration, and usage notes.
