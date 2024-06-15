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

  (
    local pid_file_path="$app_control_target_dir/latest/pid"
    export pid
    if [[ -e "$pid_file_path" ]]; then
      pid="$(cat "$pid_file_path")"
    fi
    export output_file_path="$app_control_target_dir/latest/output"
    export status
    export exit_code
    local exit_code_file_path="$app_control_target_dir/latest/exit_code"
    if [[ ! -e "$exit_code_file_path" ]]; then
      unset exit_code
    fi
    if flock -n "$app_control_target_dir/lockfile" true; then
      if [[ ! -e "$output_file_path" ]]; then
        status="none"
      else
        status="completed"
      fi
    else
      status="running"
    fi
    if [[ ! -e "$output_file_path" ]]; then
      unset output_file_path
    else
      output_file_path="$(realpath $output_file_path)"
    fi

    local screen_socket_name_file_path="$app_control_target_dir/latest/screen_socket_name"
    if [[ -e "$screen_socket_name_file_path" ]]; then
      export screen_socket_name="$(cat "$screen_socket_name_file_path")"
    fi
    python3 - <<EOF
import os;
import json;
print(json.dumps({
    "status": os.environ["status"],
    "pid": int(os.getenv("pid")) if os.getenv("pid") else None,
    "output_file_path": os.getenv("output_file_path"),
    "exit_code": int(os.getenv("exit_code")) if os.getenv("exit_code") else None,
    "screen_socket_name": os.getenv("screen_socket_name"),
}, ensure_ascii=False,indent=True))
EOF
  )
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
