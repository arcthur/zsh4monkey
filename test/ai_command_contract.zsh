#!/usr/bin/env zsh

emulate -L zsh -o err_return -o no_unset -o pipe_fail

local repository=${0:A:h:h}

function -z4m-autosuggest-core() {
  function -z4m-autosuggest-core-load-ai() {
    return 0
  }

  function -z4m-autosuggest-ai-read-config() {
    return 0
  }

  function -z4m-autosuggest-ai-intent-command() {
    REPLY=${Z4M_TEST_AI_COMMAND_RESULT:-'printf "%s\n" "hello world"'}
    return 0
  }
}

local output
output=$(source "$repository/fn/-z4m-cmd-ai" --print 'say hello')
[[ $output == 'printf "%s\n" "hello world"' ]]

output=$(source "$repository/fn/-z4m-cmd-ai" --json 'say hello')
[[ $output == '{"command":"printf \"%s\\n\" \"hello world\"","executed":false}' ]]

typeset -g Z4M_TEST_AI_COMMAND_RESULT=$'printf "tab:\tbackspace:\bformfeed:\f"\a'
output=$(source "$repository/fn/-z4m-cmd-ai" --json 'escape controls')
[[ $output == '{"command":"printf \"tab:\tbackspace:\bformfeed:\f\"","executed":false}' ]]

output=$(source "$repository/fn/-z4m-cmd-ai" 'say hello')
[[ $output == $'printf "tab:\tbackspace:\bformfeed:\f"\a' ]]

if source "$repository/fn/-z4m-cmd-ai" --queue 'say hello' >/dev/null 2>&1; then
  print -ru2 -- 'non-interactive AI command unexpectedly queued output'
  exit 1
fi
