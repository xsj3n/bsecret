if [[ "push" != "$1" ]] ; then
  git "$@"
  exit "$?"
fi

# TODO: check this logic once further progressed 
check_for_gpg() {
  if [[ ${1: -3} == "gpg" ]]; then
    return 0
  else
    return 1
  fi
}

# encrpts everything in the calling directory that matches the pattern passed to it in $1
directory_encrypt_pattern() {
  for file in "$(pwd)"$1; do
    check_for_gpg "$file" && continue
    gpg --encrypt --recipient xsj3n@tutanota.com --yes --trust-model always --output "$file.gpg" "$file"
    rm "$file"
  done

}

directory_decrypt() {
  for file in *.gpg; do
    gpg --decrypt "$file" > "${file:0:-4}"
    rm "$file"
  done
}

# encrypt every file matching the pattern, skipping those that end w/ .gpg
# $1 = pattern | $2+ = staged_files 
encrypt_pattern() {
  [[ -z "$staged_files" ]] && return 1
  local -n staged_files_ref="$staged_files"
  mapfile -t repo_files < <(find . -type f -name "$1" | xargs -n1 basename 2>/dev/null)
  for file in "${repo_files[@]}"; do
    [[ "${staged_files_ref[*]}" == "$file.gpg" ]] && continue 
 
    gpg --encrypt --recipient xsj3n@tutanota.com --yes --trust-model always --output "$file.gpg" "$file"
    rm "$file"

    git reset HEAD "$file" &>/dev/null
    git add "$file.gpg"
  done
}



repo_root="$(git rev-parse --show-toplevel)"
# make sure glob expands to null w/o match
shopt -s nullglob

# may need to check if files are staged already but thats an issue for later 
mapfile -t staged_files < <(git diff --name-only --cached | xargs -n1 basename)
mapfile -t secret_file_patterns < "$repo_root/.gitsecret"


for pattern in "${secret_file_patterns[@]}"; do
  encrypt_pattern "$pattern" staged_files
done


git commit --amend --no-edit
git push "${@:2}"


# check for .gpg files, if for some reason, the files were not encrypted, 
gpg_files=(*.gpg)
if [[ ${#gpg_files[@]} -eq 0  ]]; then
  exit
fi

directory_decrypt
