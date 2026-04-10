#!/bin/zsh

fpath=($fpath $0:a:h/autoload(N-/)) || return 1
autoload -Uz pctl

if (( $+functions[compdef] )); then
  autoload -Uz _pctl
  compdef _pctl pctl
fi
