#!/usr/bin/env bash

homeshick=${HOMESHICK_DIR:-$HOME/.homesick/repos/homeshick}
# shellcheck source=../lib/fs.sh
source "$homeshick/lib/fs.sh"

unredact() {
  [[ ! $1 ]] && help unredact
  local castle=$1
  castle_exists "$castle"
  local repo="$repos/$castle"
  if [[ ! -d $repo/home ]]; then
    if $VERBOSE; then
      ignore 'ignored' "$castle"
    fi
    return "$EX_SUCCESS"
  fi

  load_secrets

  # Loop through files in the repository using get_repo_files
  while IFS= read -d $'\0' -r relpath <&3; do
    local repopath="$repo/home/$relpath"
    local unredacted=${relpath%.redacted}
    local homepath="$HOME/$unredacted"

    # Only proceed if it's a redacted file
    if [[ $relpath == *.redacted ]]; then
      if [[ -e $homepath ]]; then
        if $SKIP; then
          ignore 'exists' "$unredacted"
          continue
        fi
        if ! $FORCE; then
          prompt_no 'conflict' "$unredacted exists" "overwrite?" || continue
        fi
        rm -rf "$homepath"
      fi

      # Perform placeholder substitution
      pending 'unredacting' "$relpath"
      populate_placeholders "$repopath" "$homepath"

      success
    fi
  done 3< <(get_repo_files "$repo")
  return "$EX_SUCCESS"
}
