#!/usr/bin/env bash

redact() {
  [[ ! $1 || ! $2 ]] && help redact
  local castle=$1
  local filename=$(readlink -f $2 2> /dev/null || realpath $2)
  local redacted="$filename.redacted"
  if [[ $filename != $HOME/* ]]; then
    err $EX_ERR "The file $filename must be in your home directory."
  fi
  if [[ $redacted == $repos/* ]]; then
    err $EX_ERR "The file $redacted is already being tracked."
  fi

  local repo="$repos/$castle"
  local newfile="$repo/home/${redacted#$HOME/}"

  pending "redacting" "$filename to $newfile"
  home_exists 'redact' $castle
  if [[ ! -e $filename ]]; then
    err $EX_ERR "The file $filename does not exist."
  fi
  if [[ -e $newfile && $FORCE = false ]]; then
    err $EX_ERR "The file $filename already exists in the castle $castle."
  fi
  if [[ ! -f $filename ]]; then
    err $EX_ERR "The file $filename must be a regular file."
  fi

  mkdir -p $(dirname $newfile)

  echo '!! Edit the file below, replacing any sensitive information to turn this:
!!
!!   password: superSecretPassword
!!
!! Into:
!!
!!   password: # briefcase(password)
!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' >> $newfile
  cat $filename >> $newfile
  "${EDITOR:-vim}" $newfile
  sed -i -e '/^!!.*$/d' $newfile

  parse_secrets $filename $newfile

  (cd $repo; git add "$newfile")
  success
}
