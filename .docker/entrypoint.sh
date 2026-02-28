#!/bin/sh -l

CONFIG_PATH=$3
LUACHECK_ARGS="--default-config $CONFIG_PATH $1"
LUACHECK_PATH="$2"
LUACHECK_CAPTURE_OUTFILE="$GITHUB_WORKSPACE/$4"
LUACHECK_EXIT_ON_WARN="$5"

# extra luacheck definitions
if [ ! -z "$6" ]; then
  OLD_DIR=$(pwd)
  cd /luacheck-fivem/
  yarn build "$6"
  cd $OLD_DIR
fi

EXIT_CODE=0

echo "Args => 1: $1, 2: $2, 3: $3, 4: $4, 5: $5, 6: $6, 7: $7"

cd $GITHUB_WORKSPACE

echo "outfile => $LUACHECK_CAPTURE_OUTFILE"

# ----------------------------------------
# FXAP encrypted file filter
# ----------------------------------------
if [ "$LUACHECK_PATH" = "." ]; then
  echo "Filtering FXAP encrypted files..."

  FILES=$(find . -name "*.lua" -type f)
  VALID_FILES=""

  for file in $FILES; do
    if ! head -c 4 "$file" | grep -q "FXAP"; then
      VALID_FILES="$VALID_FILES $file"
    else
      echo "Skipping encrypted file: $file"
    fi
  done

  LUACHECK_PATH="$VALID_FILES"
fi
# ----------------------------------------

if [ ! -z "$LUACHECK_CAPTURE_OUTFILE" ]; then
  echo "exec => luacheck $LUACHECK_ARGS $LUACHECK_PATH 2>>$LUACHECK_CAPTURE_OUTFILE"
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
  ERROR_BLOCKS=$(awk '
  /^Checking .* [0-9]+ error$/ {
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
  ' "$LUACHECK_CAPTURE_OUTFILE")

  if [ ! -z "$ERROR_BLOCKS" ]; then
      echo ""
      echo "----------------------------------------"
      echo "$ERROR_BLOCKS"
      echo "----------------------------------------"
  fi
fi

# ----------------------------------------
# Exit handling (origineel)
# ----------------------------------------

if [ "$LUACHECK_EXIT_ON_WARN" = true ]; then
  exit $EXIT_CODE
elif [ $EXIT_CODE -ge 2 ]; then
  exit $EXIT_CODE
fi
