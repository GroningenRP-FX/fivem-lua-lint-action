#!/bin/sh -l

CONFIG_PATH=$3
LUACHECK_ARGS="--default-config $CONFIG_PATH $1"
LUACHECK_PATH="$2"
LUACHECK_EXIT_ON_WARN="$5"

# extra luacheck definitions
if [ ! -z "$6" ]; then
  OLD_DIR=$(pwd)
  cd /luacheck-fivem/
  yarn build "$6" >/dev/null 2>&1
  cd $OLD_DIR
fi

EXIT_CODE=0

cd $GITHUB_WORKSPACE

# ----------------------------------------
# FXAP encrypted file filter (silent)
# ----------------------------------------
if [ "$LUACHECK_PATH" = "." ]; then
  FILES=$(find . -name "*.lua" -type f)
  VALID_FILES=""

  for file in $FILES; do
    if ! head -c 4 "$file" | grep -q "FXAP"; then
      VALID_FILES="$VALID_FILES $file"
    fi
  done

  LUACHECK_PATH="$VALID_FILES"
fi
# ----------------------------------------

TMP_OUTPUT="$GITHUB_WORKSPACE/luacheck_output.txt"

luacheck --operators "+=" $LUACHECK_ARGS --formatter plain --codes $LUACHECK_PATH >"$TMP_OUTPUT" 2>&1 || EXIT_CODE=$?

# Print normale output
cat "$TMP_OUTPUT"

echo ""
echo "exit => $EXIT_CODE"

# ----------------------------------------
# Extract echte error blocks
# ----------------------------------------

ERROR_BLOCKS=$(awk '
/^Checking .* [0-9]+ error/ {
    capture=1
    print
    next
}
/^Checking/ {
    capture=0
}
capture {
    # sluit warningregels uit
    if ($0 !~ /\(W[0-9]+\)/)
        print
}
' "$TMP_OUTPUT")

if [ ! -z "$ERROR_BLOCKS" ]; then
  echo ""
  echo "----------------------------------------"
  echo "Errors detected:"
  echo ""
  echo "$ERROR_BLOCKS"
  echo "----------------------------------------"
fi

# ----------------------------------------
# Exit handling
# ----------------------------------------

if [ "$LUACHECK_EXIT_ON_WARN" = true ]; then
  exit $EXIT_CODE
elif [ $EXIT_CODE -eq 2 ] || [ $EXIT_CODE -eq 3 ]; then
  exit $EXIT_CODE
fi
