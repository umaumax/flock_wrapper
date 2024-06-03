# flock_wrwrapperer

# how to run
## preparation
``` bash
mkfifo flock_result_pipe_A
mkfifo flock_result_pipe_B
```

## terminal A-1
``` bash
cat flock_result_pipe_A | tee flock_result_A; if [[ "$(cat flock_result_A)" == 0 ]]; then tail -f base/label/latest/output; else echo '❌'; fi
```

## terminal A-2
``` bash
FLOCK_EXIT_CODE_PIPE_PATH=flock_result_pipe_A APP_CONTROL_BASE_DIR=base ./flock_wrapper.sh run label bash -c 'for ((i = 1; i <= 30; i++)); do echo "$i:A"; sleep 1; done'
```

## terminalB-1
``` bash
cat flock_result_pipe_B | tee flock_result_B; if [[ "$(cat flock_result_B)" == 0 ]]; then tail -f base/label/latest/output; else echo '❌'; fi
```

## terminalB-2
``` bash
FLOCK_EXIT_CODE_PIPE_PATH=flock_result_pipe_B APP_CONTROL_BASE_DIR=base ./flock_wrapper.sh run label bash -c 'for ((i = 1; i <= 30; i++)); do echo "$i:B"; sleep 1; done'
```

## check
``` bash
APP_CONTROL_BASE_DIR=base ./flock_wrapper.sh check label
```

## stop
``` bash
APP_CONTROL_BASE_DIR=base ./flock_wrapper.sh stop label
```

steps
* 1. run A-1, B-1
* 2. run A-2, B-2

