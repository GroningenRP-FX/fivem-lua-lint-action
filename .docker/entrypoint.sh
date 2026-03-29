#!/bin/sh -l
set -e
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
# FXAP encrypted file filter
# ----------------------------------------
echo "Filtering FXAP encrypted files..."

if [ "$LUACHECK_PATH" = "." ]; then
  FILES=$(find . -name "*.lua" -type f)
else
  FILES=$(echo "$LUACHECK_PATH" | tr ' ' '\n')
fi

VALID_FILES=""
for file in $FILES; do
  if [ ! -f "$file" ]; then
    continue
  fi
  if ! head -c 4 "$file" 2>/dev/null | grep -q "FXAP"; then
    VALID_FILES="$VALID_FILES $file"
  else
    echo "Skipping encrypted file: $file"
  fi
done

LUACHECK_PATH="$VALID_FILES"
# ----------------------------------------
echo "Running luacheck..."
luacheck --operators "+=" $LUACHECK_ARGS --formatter default $LUACHECK_PATH \
  > "$LUACHECK_CAPTURE_OUTFILE" 2>&1
EXIT_CODE=$?
cat "$LUACHECK_CAPTURE_OUTFILE"
echo "exit => $EXIT_CODE"
# ----------------------------------------
# Exit handling
# ----------------------------------------
if [ "$LUACHECK_EXIT_ON_WARN" = true ]; then
  exit $EXIT_CODE
elif [ "$EXIT_CODE" -ge 2 ]; then
  exit $EXIT_CODE
fi
exit 0
