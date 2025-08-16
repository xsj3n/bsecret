if [[ "-is-bsecret" == "$1" ]]; then
  echo "<> <> git-bsecret is active <> <>"
  exit 0 
fi

git_path="$(which git)"
if [[ "push" != "$1" ]] ; then
  "$git_path" "$@"
  exit "$?"
fi

split_on_period() {
  while IFS= read -r line; do
    IFS='.' read -ra split_array <<< "$line"
    echo "${split_array[${#split_array[@]} - 2]}"
  done
}




type=""
encrypt() {
  if [[ "$type" == "gpg" ]]; then
    gpg --encrypt --recipient "$2" --yes --trust-model always --output "$1.gpg" "$1"
  else
    sops --encrypt "$1" > "$1.gpg"   
  fi
}

decrypt() {
  if [[ "$type" == "gpg" ]]; then
    gpg --decrypt "$1" > "${1:0:-4}"
  else
    local output_type
    output_type=$(basename "$1" | split_on_period)
    sops --output-type "$output_type" --decrypt "$1" > "${1:0:-4}"   
  fi
}


directory_decrypt() {
  mapfile -t gpg_files < <(find . -type f -name "*.gpg")
  for file in "${gpg_files[@]}"; do
    decrypt "$file"
    touch -r "$file" "${file:0:-4}"
    rm "$file"
  done
}

recipient="$(gpg --list-key | grep -Eo '[^ ]+@[^ ]+' | cut -c2- | rev | cut -c2- | rev)"
encrypt_pattern() {
  local pattern="${1//\\\\/\\}"
  mapfile -t repo_files < <(find . -type f -regex "$pattern")
  for file in "${repo_files[@]}"; do
    [[ "${file:0:-4}" == ".gpg" ]] && continue 
    encrypt "$file" "$recipient"
    echo " encrypt mode - $file"
    "$git_path" rm --cached "$file" &>/dev/null 
    "$git_path" add "$file.gpg"
  done
}

shopt -s nullglob
repo_root="$(git rev-parse --show-toplevel)"
if [ -z "$repo_root" ]; then
  echo "error: .gitsecret file must be present in repository root"
  exit 1
fi

mapfile -t config_lines < "$repo_root/.gitsecret"
type="${config_lines[0]:5}"


if [ "$type" == "sops" ] || [ "$type" == "SOPS" ]; then
  if ! [ -s "$repo_root/.sops.yaml" ]; then
    echo "error: if TYPE is set to sops then a .sops.yaml must be present and not empty"
    exit 1
  fi
  
  echo "[SOPS]: secrets check starting"
  mapfile -t secret_file_patterns < <(grep -e "path_regex" .sops.yaml | grep -o '"[^"]*"')
  for i in "${!secret_file_patterns[@]}"; do
    secret_file_patterns[$i]="${secret_file_patterns[$i]:1:-1}"
  done
  echo "Patterns: ${secret_file_patterns[*]}"
  for pattern in "${secret_file_patterns[@]}"; do
    encrypt_pattern "$pattern" staged_files
  done
else
  echo "[GPG]: secrets check starting"
  secret_file_patterns=("${config_lines[@]:1}")
  for pattern in "${secret_file_patterns[@]}"; do
    encrypt_pattern "$pattern" staged_files
  done
fi

"$git_path" commit --amend --no-edit
"$git_path" "$@"
directory_decrypt
