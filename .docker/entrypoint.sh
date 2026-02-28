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

# ----------------------------------------
# Run luacheck and capture output
# ----------------------------------------

TMP_OUTPUT="$GITHUB_WORKSPACE/luacheck_output.txt"

luacheck --operators "+=" $LUACHECK_ARGS --formatter plain --codes $LUACHECK_PATH >"$TMP_OUTPUT" 2>&1 || EXIT_CODE=$?

# Print full luacheck output
cat "$TMP_OUTPUT"

echo ""
echo "exit => $EXIT_CODE"

# ----------------------------------------
# Extra error block under summary
# ----------------------------------------

ERROR_LINES=$(grep -E ":[0-9]+:[0-9]+:" "$TMP_OUTPUT")

if [ ! -z "$ERROR_LINES" ]; then
  echo ""
  echo "----------------------------------------"
  echo "Errors:"
  echo "$ERROR_LINES"
  echo "----------------------------------------"
fi

# ----------------------------------------
# Exit handling
# ----------------------------------------

if [ "$LUACHECK_EXIT_ON_WARN" = true ]; then
  exit $EXIT_CODE
elif [ $EXIT_CODE -ge 2 ]; then
  exit $EXIT_CODE
fi
