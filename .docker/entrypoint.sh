#!/usr/bin/env bash

set -o pipefail

CONFIG_PATH=$3
LUACHECK_ARGS="--default-config $CONFIG_PATH $1"
LUACHECK_PATH="$2"
LUACHECK_CAPTURE_OUTFILE="$GITHUB_WORKSPACE/$4"
LUACHECK_EXIT_ON_WARN="$5"

EXIT_CODE=0

echo "Args => 1: $1, 2: $2, 3: $3, 4: $4, 5: $5, 6: $6"

cd "$GITHUB_WORKSPACE" || exit 1

echo "outfile => $LUACHECK_CAPTURE_OUTFILE"

# ----------------------------------------
# Extra luacheck definitions (optional)
# ----------------------------------------
if [ -n "$6" ]; then
  OLD_DIR=$(pwd)
  cd /luacheck-fivem/ || exit 1
  yarn build "$6"
  cd "$OLD_DIR" || exit 1
fi

# ----------------------------------------
# FXAP encrypted file filter
# ----------------------------------------
if [ "$LUACHECK_PATH" = "." ]; then
  echo "Filtering FXAP encrypted files..."

  FILES=$(find . -name "*.lua" -type f)
  VALID_FILES=""

  for file in $FILES; do
    if ! head -c 4 "$file" 2>/dev/null | grep -q "FXAP"; then
      VALID_FILES="$VALID_FILES $file"
    else
      echo "Skipping encrypted file: $file"
    fi
  done

  LUACHECK_PATH="$VALID_FILES"
fi
# ----------------------------------------

# ----------------------------------------
# Run luacheck ONCE (console + file identical)
# ----------------------------------------

echo "Running luacheck..."

luacheck --operators "+=" $LUACHECK_ARGS --formatter default $LUACHECK_PATH \
  2>&1 | tee "$LUACHECK_CAPTURE_OUTFILE"

EXIT_CODE=${PIPESTATUS[0]}

echo "exit => $EXIT_CODE"

# ----------------------------------------
# Process captured output
# ----------------------------------------

if [ -f "$LUACHECK_CAPTURE_OUTFILE" ]; then

  CLEAN_FILE="$RUNNER_TEMP/luacheck_clean.txt"

  # Strip ANSI color codes
  sed -r "s/\x1B\[[0-9;]*[mK]//g" "$LUACHECK_CAPTURE_OUTFILE" > "$CLEAN_FILE"

  # Extract summary safely
  SUMMARY=$(grep "Total:" "$CLEAN_FILE" | tail -n 1 || true)

  echo "Raw summary => $SUMMARY"

  if [ -n "$SUMMARY" ]; then
    WARNINGS=$(echo "$SUMMARY" | sed -E 's/.*Total: ([0-9]+) warnings.*/\1/')
    ERRORS=$(echo "$SUMMARY" | sed -E 's/.*\/ ([0-9]+) error.*/\1/')
  else
    WARNINGS=0
    ERRORS=0
  fi

  WARNINGS=${WARNINGS:-0}
  ERRORS=${ERRORS:-0}

  echo "Detected warnings => $WARNINGS"
  echo "Detected errors   => $ERRORS"

  # ----------------------------------------
  # Repeat error blocks (max 20 lines per file)
  # ----------------------------------------
  ERROR_BLOCKS=$(awk '
  /^Checking .* [0-9]+ error/ {
      if (capture) print ""
      capture=1
      lines=0
      print
      next
  }

  /^Checking/ {
      capture=0
  }

  capture {
      if (lines < 20) {
          print
          lines++
      }
  }
  ' "$CLEAN_FILE")

  if [ -n "$ERROR_BLOCKS" ]; then
      echo ""
      echo "----------------------------------------"
      echo "$ERROR_BLOCKS"
      echo "----------------------------------------"
  fi
fi

# ----------------------------------------
# Exit handling
# ----------------------------------------

if [ "$LUACHECK_EXIT_ON_WARN" = true ]; then
  exit $EXIT_CODE
elif [ "$EXIT_CODE" -ge 2 ]; then
  exit $EXIT_CODE
fi

exit 0
