#!/usr/bin/env bash

homeshick=${HOMESHICK_DIR:-$HOME/.homesick/repos/homeshick}
# shellcheck source=../lib/fs.sh
source "$homeshick/lib/fs.sh"

symlink() {
  [[ ! $1 ]] && help symlink
  local castle=$1
  castle_exists 'link' "$castle"
  # repos is a global variable
  # shellcheck disable=SC2154
  local repo="$repos/$castle"
  if [[ ! -d $repo/home ]]; then
    if $VERBOSE; then
      ignore 'ignored' "$castle"
    fi
    return "$EX_SUCCESS"
  fi
  # Run through the repo files using process substitution.
  # The get_repo_files call is at the bottom of this loop.
  # We set the IFS to nothing and the separator for `read' to NUL so that we
  # don't separate files with newlines in their name into two iterations.
  # `read's stdin comes from a third unused file descriptor because we are
  # using the real stdin for prompting whether the user wants to
  # overwrite or skip on conflicts.
  while IFS= read -d $'\0' -r relpath <&3 ; do
    local repopath="$repo/home/$relpath"
    local homepath="$HOME/$relpath"
    local rel_repopath
    rel_repopath=$(create_rel_path "$(dirname "$homepath")/" "$repopath") || return $?

    if [[ -e $homepath || -L $homepath ]]; then
      # $homepath exists (but may be a dead symlink)
      if [[ -L $homepath && $(readlink "$homepath") == "$rel_repopath" ]]; then
        # $homepath symlinks to $repopath.
        if $VERBOSE; then
          ignore 'identical' "$relpath"
        fi
        continue
      elif [[ $(readlink "$homepath") == "$repopath" ]]; then
        # $homepath is an absolute symlink to $repopath
        if [[ -d $repopath && ! -L $repopath ]]; then
          # $repopath is a directory, but $homepath is a symlink -> legacy handling.
          rm "$homepath"
        else
          # replace it with a relative symlink
          rm "$homepath"
        fi
      else
        # $homepath does not symlink to $repopath
        # check if we should delete $homepath
        if [[ -d $homepath && -d $repopath && ! -L $repopath ]]; then
          # $repopath is a real directory while
          # $homepath is a directory or a symlinked directory
          # we do not take any action regardless of which it is.
          if $VERBOSE; then
            ignore 'identical' "$relpath"
          fi
          continue
        elif $SKIP; then
          ignore 'exists' "$relpath"
          continue
        elif ! $FORCE; then
          prompt_no 'conflict' "$relpath exists" "overwrite?" || continue
        fi
        # Delete $homepath.
        rm -rf "$homepath"
      fi
    fi

    if [[ ! -d $repopath || -L $repopath ]]; then
      # $repopath is not a real directory so we create a symlink to it
      pending 'symlink' "$relpath"
      ln -s "$rel_repopath" "$homepath"
    else
      pending 'directory' "$relpath"
      mkdir "$homepath"
    fi

    success
  # Fetch the repo files and redirect the output into file descriptor 3
  done 3< <(get_repo_files "$repo" "\.redacted$")
  return "$EX_SUCCESS"
}
