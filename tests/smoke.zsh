#!/bin/zsh

set -euo pipefail

typeset -gr TEST_ROOT=${0:A:h:h}
typeset -gr TEST_INIT_PATH=${TEST_ROOT}/init.zsh

typeset -g TEST_OUTPUT=''
typeset -gi TEST_RC=0

fail() {
  print -u2 -- "FAIL: $1"
  exit 1
}

assert_contains() {
  local haystack=$1
  local needle=$2

  [[ $haystack == *"$needle"* ]] || fail "expected output to contain: $needle"$'\n'"$haystack"
}

run_shell() {
  local expected_rc=$1
  local command=$2
  local init_path=${(q)TEST_INIT_PATH}

  set +e
  TEST_OUTPUT=$(
    env -i HOME="$HOME" PATH="$PATH" zsh -lc "$command" 2>&1
  )
  TEST_RC=$?
  set -e

  [[ $TEST_RC -eq $expected_rc ]] || fail "expected exit code $expected_rc, got $TEST_RC"$'\n'"$TEST_OUTPUT"
}

run_with_plugin() {
  local expected_rc=$1
  local command=$2
  local init_path=${(q)TEST_INIT_PATH}

  run_shell "$expected_rc" "source $init_path; $command"
}

test_no_argument_shows_help() {
  run_with_plugin 0 'pctl'
  assert_contains "$TEST_OUTPUT" 'Usage: pctl [OPTIONS]'
}

test_set_writes_lowercase_uppercase_and_no_proxy() {
  run_with_plugin 0 'PCTL_PROXY_ADDRESS=proxy.example.com PCTL_PROXY_PORT=8080 PCTL_NO_PROXY=localhost,127.0.0.1 pctl --set; print -r -- "http_proxy=$http_proxy"; print -r -- "HTTP_PROXY=$HTTP_PROXY"; print -r -- "https_proxy=$https_proxy"; print -r -- "HTTPS_PROXY=$HTTPS_PROXY"; print -r -- "no_proxy=$no_proxy"; print -r -- "NO_PROXY=$NO_PROXY"'
  assert_contains "$TEST_OUTPUT" 'http_proxy=http://proxy.example.com:8080'
  assert_contains "$TEST_OUTPUT" 'HTTP_PROXY=http://proxy.example.com:8080'
  assert_contains "$TEST_OUTPUT" 'https_proxy=http://proxy.example.com:8080'
  assert_contains "$TEST_OUTPUT" 'HTTPS_PROXY=http://proxy.example.com:8080'
  assert_contains "$TEST_OUTPUT" 'no_proxy=localhost,127.0.0.1'
  assert_contains "$TEST_OUTPUT" 'NO_PROXY=localhost,127.0.0.1'
}

test_set_refuses_existing_uppercase_proxy_state() {
  run_shell 1 'HTTP_PROXY=http://proxy.example.com:8080; HTTPS_PROXY=http://proxy.example.com:8080; source '"${(q)TEST_INIT_PATH}"'; PCTL_PROXY_ADDRESS=new.example.com PCTL_PROXY_PORT=9090 pctl --set'
  assert_contains "$TEST_OUTPUT" 'Environment variable has already set.'
}

test_set_clears_stale_no_proxy_when_not_configured() {
  run_shell 0 'no_proxy=localhost; NO_PROXY=internal.example.com; source '"${(q)TEST_INIT_PATH}"'; PCTL_PROXY_ADDRESS=proxy.example.com PCTL_PROXY_PORT=8080 pctl --set; print -r -- "no_proxy_set=${+no_proxy}"; print -r -- "NO_PROXY_set=${+NO_PROXY}"'
  assert_contains "$TEST_OUTPUT" 'no_proxy_set=0'
  assert_contains "$TEST_OUTPUT" 'NO_PROXY_set=0'
}

test_unset_clears_uppercase_only_state() {
  run_shell 0 'HTTP_PROXY=http://proxy.example.com:8080; HTTPS_PROXY=http://proxy.example.com:8080; NO_PROXY=localhost; source '"${(q)TEST_INIT_PATH}"'; pctl --unset; print -r -- "HTTP_PROXY_set=${+HTTP_PROXY}"; print -r -- "HTTPS_PROXY_set=${+HTTPS_PROXY}"; print -r -- "NO_PROXY_set=${+NO_PROXY}"'
  assert_contains "$TEST_OUTPUT" 'HTTP_PROXY_set=0'
  assert_contains "$TEST_OUTPUT" 'HTTPS_PROXY_set=0'
  assert_contains "$TEST_OUTPUT" 'NO_PROXY_set=0'
}

test_status_reports_all_managed_variables() {
  run_shell 0 'http_proxy=http://lower.example.com:8080; HTTP_PROXY=http://upper.example.com:8080; https_proxy=http://lower-secure.example.com:8080; HTTPS_PROXY=http://upper-secure.example.com:8080; no_proxy=localhost; NO_PROXY=internal.example.com; source '"${(q)TEST_INIT_PATH}"'; pctl --status'
  assert_contains "$TEST_OUTPUT" 'http_proxy: http://lower.example.com:8080'
  assert_contains "$TEST_OUTPUT" 'HTTP_PROXY: http://upper.example.com:8080'
  assert_contains "$TEST_OUTPUT" 'https_proxy: http://lower-secure.example.com:8080'
  assert_contains "$TEST_OUTPUT" 'HTTPS_PROXY: http://upper-secure.example.com:8080'
  assert_contains "$TEST_OUTPUT" 'no_proxy: localhost'
  assert_contains "$TEST_OUTPUT" 'NO_PROXY: internal.example.com'
}

test_completion_registers_after_compinit() {
  run_shell 0 'autoload -Uz compinit; compinit; source '"${(q)TEST_INIT_PATH}"'; print -r -- "_comps[pctl]=${_comps[pctl]-missing}"; whence -w _pctl'
  assert_contains "$TEST_OUTPUT" '_comps[pctl]=_pctl'
  assert_contains "$TEST_OUTPUT" '_pctl: function'
}

test_illegal_option_message_strips_leading_dashes() {
  run_with_plugin 1 'pctl --wat'
  assert_contains "$TEST_OUTPUT" "illegal option -- 'wat'"
}

test_no_argument_shows_help
test_set_writes_lowercase_uppercase_and_no_proxy
test_set_refuses_existing_uppercase_proxy_state
test_set_clears_stale_no_proxy_when_not_configured
test_unset_clears_uppercase_only_state
test_status_reports_all_managed_variables
test_completion_registers_after_compinit
test_illegal_option_message_strips_leading_dashes

print -- 'All smoke tests passed.'
