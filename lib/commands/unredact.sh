#!/usr/bin/env bash

function unredact {
  [[ ! $1 ]] && help unredact
  local castle=$1
  castle_exists $castle
  local repo="$repos/$castle"
  if [[ ! -d $repo/home ]]; then
    ignore 'ignored' "$castle"
    return $EX_SUCCESS
  fi

  load_secrets

  for filepath in $(find $repo/home -mindepth 1 -type f -iname "*.redacted"); do
    file=${filepath#$repo/home/}
    unredacted=${file%.redacted}

    if [[ -e $HOME/$unredacted ]]; then
      if $SKIP; then
        ignore 'exists' $file
        continue
      fi
      if ! $FORCE; then
        prompt_no 'conflict' "$unredacted exists" "overwrite?"
        if [[ $? != 0 ]]; then
          continue
        fi
      fi
      rm -rf "$HOME/$unredacted"
    fi

    populate_placeholders "$repo/home/$file" "$HOME/$unredacted"

    success
  done
  return $EX_SUCCESS
}
