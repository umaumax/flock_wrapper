#!/usr/bin/env bash

set -eu

if [[ $# -lt 2 ]]; then
  echo "$(basename "$0") label commands..." 1>&2
  exit 1
fi

app_control_label=$1
shift

export APP_CONTROL_BASE_DIR=${APP_CONTROL_BASE_DIR-.}
app_control_target_dir="$APP_CONTROL_BASE_DIR/$app_control_label"
export FLOCK_EXIT_CODE_PIPE_PATH=${FLOCK_EXIT_CODE_PIPE_PATH-""}

function main() {
  local PID=$$
  local record_dir_name="$(date +"%Y%m%d-%H%M%S")_$PID"
  mkdir -p "$app_control_target_dir/$record_dir_name"
  ln -sfn "$record_dir_name" "$app_control_target_dir/latest"

  echo "$*" >"$app_control_target_dir/latest/command"
  local exit_code=0
  if [[ -n "$FLOCK_EXIT_CODE_PIPE_PATH" ]]; then
    echo "$exit_code" >"$FLOCK_EXIT_CODE_PIPE_PATH"
  fi

  (
    {
      "$@"
    } |& tee "$app_control_target_dir/latest/output"
  ) &
  CMD_PID=$!
  echo "$CMD_PID" >"$app_control_target_dir/latest/pid"
  if wait "$CMD_PID"; then
    :
  else
    CMD_EXIT_CODE=$?
  fi
  echo "$CMD_EXIT_CODE" >"$app_control_target_dir/latest/exit_code"
}

main "$@"
