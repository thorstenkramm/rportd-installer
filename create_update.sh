#!/usr/bin/env bash
set -e
OUT="./rportd-update.sh"
test -e $OUT && rm -f $OUT
{
  echo "#!/usr/bin/env bash"
  echo "set -e"
} >>$OUT
while read -r FILE; do
  {
    printf "## %s -----------|\n" "$FILE"
    cat "$FILE"
    printf "\n## END of %s -----------|\n" "$FILE"
  } >>$OUT
done < <(
  find snippets/shared -type f -name '*.sh' | sort
  find snippets/update -type f -name '*.sh' | sort
)
echo "Script $OUT created."
command -v shellcheck >/dev/null && shellcheck -S info $OUT
