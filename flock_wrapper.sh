#!/usr/bin/env bash

set -eu

function help() {
  echo "$(basename "$0") action(run,check,stop) label commands..." 1>&2
}

if [[ $# -lt 2 ]]; then
  help
  exit 255
fi

action=$1
shift

app_control_label=$1
shift

export APP_CONTROL_BASE_DIR=${APP_CONTROL_BASE_DIR-.}
app_control_target_dir="$APP_CONTROL_BASE_DIR/$app_control_label"
export FLOCK_EXIT_CODE_PIPE_PATH=${FLOCK_EXIT_CODE_PIPE_PATH-""}
SCREEN_CMD=${SCREEN_CMD-screen}

if [[ -z "$SCREEN_CMD" ]]; then
  function flock_wrapper() {
    "$@"
  }
else
  function flock_wrapper() {
    screen -dmS "flock_wrapper" "$@"
  }
fi

function main-run() {
  local current_abs_directory_path=$(cd $(dirname $0) && pwd)

  mkdir -p "$app_control_target_dir"
  if [[ -n "$FLOCK_EXIT_CODE_PIPE_PATH" ]] && [[ ! -e "$FLOCK_EXIT_CODE_PIPE_PATH" ]]; then
    mkfifo "$FLOCK_EXIT_CODE_PIPE_PATH"
  fi

  flock_wrapper bash -c '
  if flock -n "$@"; then
      :
    else
      exit_code=$?
      if [[ -n "$FLOCK_EXIT_CODE_PIPE_PATH" ]]; then
        echo "$exit_code" >"$FLOCK_EXIT_CODE_PIPE_PATH"
      fi
    fi
  ' bash "$app_control_target_dir/lockfile" bash "$current_abs_directory_path/launch.sh" "$app_control_label" "$@"
}

function main-check() {
  mkdir -p "$app_control_target_dir"

  local pid_file_path="$app_control_target_dir/latest/pid"
  local cmd_pid="$(cat "$pid_file_path")"
  local output_file_path="$app_control_target_dir/latest/output"
  local status
  if flock -n "$app_control_target_dir/lockfile" true; then
    if [[ ! -e "$output_file_path" ]]; then
      echo '{"status":"none","pid":null,"output":null}'
      return
    fi
    status="completed"
  else
    status="running"
  fi
  echo '{"status":"'"$status"'","pid":"'"$cmd_pid"'","output":"'"$output_file_path"'"}'
}

function main-stop() {
  mkdir -p "$app_control_target_dir"

  local pid_file_path="$app_control_target_dir/latest/pid"
  if [[ ! -e "$pid_file_path" ]]; then
    echo "No target PID at $pid_file_path" 1>&2
    return 1
  fi
  local cmd_pid="$(cat "$pid_file_path")"
  if [[ ! "$cmd_pid" =~ ^[0-9]+$ ]]; then
    echo "Invalid PID: '$cmd_pid'" 1>&2
    return 2
  fi

  if flock -n "$app_control_target_dir/lockfile" true; then
    echo "Already stopped PID: $cmd_pid" 1>&2
    return 3
  fi

  kill -KILL "$cmd_pid"
}

if [[ "$action" =~ ^(check|run|stop)$ ]]; then
  "main-$action" "$@"
  exit $?
else
  echo "Invalid action '$action'" 1>&2
  help
  exit 255
fi
