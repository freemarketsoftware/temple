#!/bin/bash
# Send a string as QEMU sendkey commands
# Usage: ./sendtext.sh "text to type"

SOCK="/tmp/qmon.sock"
DELAY=0.05

send_key() {
  echo "sendkey $1" | sudo nc -N -U "$SOCK" > /dev/null 2>&1
  sleep "$DELAY"
}

type_string() {
  local text="$1"
  local len=${#text}
  for (( i=0; i<len; i++ )); do
    local ch="${text:$i:1}"
    case "$ch" in
      a) send_key "a" ;;
      b) send_key "b" ;;
      c) send_key "c" ;;
      d) send_key "d" ;;
      e) send_key "e" ;;
      f) send_key "f" ;;
      g) send_key "g" ;;
      h) send_key "h" ;;
      i) send_key "i" ;;
      j) send_key "j" ;;
      k) send_key "k" ;;
      l) send_key "l" ;;
      m) send_key "m" ;;
      n) send_key "n" ;;
      o) send_key "o" ;;
      p) send_key "p" ;;
      q) send_key "q" ;;
      r) send_key "r" ;;
      s) send_key "s" ;;
      t) send_key "t" ;;
      u) send_key "u" ;;
      v) send_key "v" ;;
      w) send_key "w" ;;
      x) send_key "x" ;;
      y) send_key "y" ;;
      z) send_key "z" ;;
      A) send_key "shift-a" ;;
      B) send_key "shift-b" ;;
      C) send_key "shift-c" ;;
      D) send_key "shift-d" ;;
      E) send_key "shift-e" ;;
      F) send_key "shift-f" ;;
      G) send_key "shift-g" ;;
      H) send_key "shift-h" ;;
      I) send_key "shift-i" ;;
      J) send_key "shift-j" ;;
      K) send_key "shift-k" ;;
      L) send_key "shift-l" ;;
      M) send_key "shift-m" ;;
      N) send_key "shift-n" ;;
      O) send_key "shift-o" ;;
      P) send_key "shift-p" ;;
      Q) send_key "shift-q" ;;
      R) send_key "shift-r" ;;
      S) send_key "shift-s" ;;
      T) send_key "shift-t" ;;
      U) send_key "shift-u" ;;
      V) send_key "shift-v" ;;
      W) send_key "shift-w" ;;
      X) send_key "shift-x" ;;
      Y) send_key "shift-y" ;;
      Z) send_key "shift-z" ;;
      0) send_key "0" ;;
      1) send_key "1" ;;
      2) send_key "2" ;;
      3) send_key "3" ;;
      4) send_key "4" ;;
      5) send_key "5" ;;
      6) send_key "6" ;;
      7) send_key "7" ;;
      8) send_key "8" ;;
      9) send_key "9" ;;
      ' ') send_key "spc" ;;
      '.') send_key "dot" ;;
      ',') send_key "comma" ;;
      '/') send_key "slash" ;;
      ';') send_key "semicolon" ;;
      ':') send_key "shift-semicolon" ;;
      "'") send_key "apostrophe" ;;
      '"') send_key "shift-apostrophe" ;;
      '!') send_key "shift-1" ;;
      '@') send_key "shift-2" ;;
      '#') send_key "shift-3" ;;
      '$') send_key "shift-4" ;;
      '%') send_key "shift-5" ;;
      '^') send_key "shift-6" ;;
      '&') send_key "shift-7" ;;
      '*') send_key "shift-8" ;;
      '(') send_key "shift-9" ;;
      ')') send_key "shift-0" ;;
      '-') send_key "minus" ;;
      '_') send_key "shift-minus" ;;
      '=') send_key "equal" ;;
      '+') send_key "shift-equal" ;;
      '[') send_key "bracket_left" ;;
      ']') send_key "bracket_right" ;;
      '{') send_key "shift-bracket_left" ;;
      '}') send_key "shift-bracket_right" ;;
      '|') send_key "shift-backslash" ;;
      \\) send_key "backslash" ;;
      '`') send_key "grave_accent" ;;
      '~') send_key "shift-grave_accent" ;;
      '<') send_key "shift-comma" ;;
      '>') send_key "shift-dot" ;;
      '?') send_key "shift-slash" ;;
      *) echo "Unknown char: $ch" ;;
    esac
  done
}

# Type each argument, pressing Enter after each
for line in "$@"; do
  type_string "$line"
  send_key "ret"
done
