#!/bin/sh -l

set -o pipefail

CONFIG_PATH=$3
LUACHECK_ARGS="--default-config $CONFIG_PATH $1"
LUACHECK_PATH="$2"
LUACHECK_CAPTURE_OUTFILE="$GITHUB_WORKSPACE/$4"
LUACHECK_EXIT_ON_WARN="$5"

EXIT_CODE=0

echo "Args => 1: $1, 2: $2, 3: $3, 4: $4, 5: $5, 6: $6, 7: $7"

cd "$GITHUB_WORKSPACE"

echo "outfile => $LUACHECK_CAPTURE_OUTFILE"

# ----------------------------------------
# Extra luacheck definitions (optional)
# ----------------------------------------
if [ ! -z "$6" ]; then
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
# Run luacheck
# ----------------------------------------

if [ ! -z "$LUACHECK_CAPTURE_OUTFILE" ]; then
  echo "exec => luacheck $LUACHECK_ARGS $LUACHECK_PATH"

  luacheck --operators "+=" $LUACHECK_ARGS $LUACHECK_PATH >"$LUACHECK_CAPTURE_OUTFILE" 2>&1 || true

  echo "exec => luacheck $LUACHECK_ARGS --formatter default $LUACHECK_PATH"

  luacheck --operators "+=" $LUACHECK_ARGS --formatter default $LUACHECK_PATH || EXIT_CODE=$?
else
  echo "exec => luacheck $LUACHECK_ARGS $LUACHECK_PATH"

  luacheck --operators "+=" $LUACHECK_ARGS $LUACHECK_PATH || EXIT_CODE=$?
fi

echo "exit => $EXIT_CODE"

# ----------------------------------------
# Repeat error blocks from captured output
# ----------------------------------------

if [ -f "$LUACHECK_CAPTURE_OUTFILE" ]; then

  CLEAN_FILE="$RUNNER_TEMP/luacheck_clean.txt"

  # Strip ANSI color codes safely
  sed -r "s/\x1B\[[0-9;]*[mK]//g" "$LUACHECK_CAPTURE_OUTFILE" > "$CLEAN_FILE"

  ERROR_BLOCKS=$(awk '
  /^Checking .* [0-9]+ error(s)?$/ {
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

  if [ ! -z "$ERROR_BLOCKS" ]; then
      echo ""
      echo "----------------------------------------"
      echo "$ERROR_BLOCKS"
      echo "----------------------------------------"
  fi
fi

# ----------------------------------------
# Exit handling (origineel gedrag behouden)
# ----------------------------------------

if [ "$LUACHECK_EXIT_ON_WARN" = true ]; then
  exit $EXIT_CODE
elif [ "$EXIT_CODE" -ge 2 ]; then
  exit $EXIT_CODE
fi

exit 0
