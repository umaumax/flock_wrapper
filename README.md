# flock_wrapper

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
* flockの終了コードを予め開いていたパイプからファイルへ出力する
* ファイルの中身から、コマンドの終了コードを確認する

## terminal A-2
``` bash
FLOCK_EXIT_CODE_PIPE_PATH=flock_result_pipe_A APP_CONTROL_BASE_DIR=base ./flock_wrapper.sh run label bash -c 'for ((i = 1; i <= 30; i++)); do echo "$i:A"; sleep 1; done'
```

* 指定したコマンドを実行し、terminal A-1で結果を待ち受ける

## terminal B-1
``` bash
cat flock_result_pipe_B | tee flock_result_B; if [[ "$(cat flock_result_B)" == 0 ]]; then tail -f base/label/latest/output; else echo '❌'; fi
```

* terminal A-1と原理的には同じである

## terminal B-2
``` bash
FLOCK_EXIT_CODE_PIPE_PATH=flock_result_pipe_B APP_CONTROL_BASE_DIR=base ./flock_wrapper.sh run label bash -c 'for ((i = 1; i <= 30; i++)); do echo "$i:B"; sleep 1; done'
```

* terminal A-2と原理的には同じである

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
* 3. (run check or stop)

## how to use
* The environment variable `SCREEN_CMD=screen` is used to run a command in the background.
  * If `SCREEN_CMD=` is set, a command runs in the foreground.

# TODOs
* [ ] 図で挙動を整理する

# NOTE: `tail -f`として、そのファイルへの書き込みが終了しても閉じられないのは仕様である
[linux - How do I stop tail command in script - Stack Overflow]( https://stackoverflow.com/questions/28600353/how-do-i-stop-tail-command-in-script )
