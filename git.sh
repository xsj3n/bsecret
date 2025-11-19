if [[ "-is-bsecret" == "$1" ]]; then
  echo "[SOPS <|> GPG] bsecret is available"
  exit 0 
fi

shopt -s nullglob
repo_root="$(git rev-parse --show-toplevel)"
git_path="$(type -a git | grep -v 'bsecret')"
read -ra git_path <<< $git_path
git_path="${git_path[-1]}"

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

# $1 = filename | $2 = gpg_recipient |$3 = type 
encrypt() {
  if [[ "$3" == "gpg" ]]; then
    gpg --encrypt --recipient "$2" --yes --trust-model always --output "$1.gpg" "$1"
  else
    sops --encrypt "$1" > "$1.gpg"
  fi
}

# $1 = filename | $2 = type 
decrypt() {
  if [[ "$2" == "gpg" ]]; then
    gpg --decrypt "$1" > "${1:0:-4}"
  else
    local output_type
    output_type=$(basename "$1" | split_on_period)
    sops --output-type "$output_type" --decrypt "$1" > "${1:0:-4}" 2>/dev/null || gpg --decrypt "$1" > "${1:0:-4}" # account for mixed decryptions 
  fi
}

# $1 = filename 
git_replace() {
    "$git_path" rm --cached "$1" &>/dev/null 
    "$git_path" add "$1.gpg"
}

directory_decrypt() {
  mapfile -t gpg_files < <(find . -type f -name "*.gpg")
  for file in "${gpg_files[@]}"; do
    decrypt "$file" "$type"
    touch -r "$file" "${file:0:-4}"
    rm "$file"
  done
}

recipient="$(gpg --list-key | grep -Eo '[^ ]+@[^ ]+' | cut -c2- | rev | cut -c2- | rev)"
mapfile -t ignore_lines < "$repo_root/.gitignore"
# $1 = path
is_ignored() {
  for pattern in "${ignore_lines[@]}"; do
    [[ "$1" == $pattern ]] && return 1
  done
  return 0
}


# $1 = pattern | $2 = type 
encrypt_pattern() {
  local pattern="${1//\\\\/\\}"
  local repo_files=""
  echo "[${2^^}]: Starting encryption pattern - $pattern"
  
  if [ "$2" == "gpg" ]; then
    mapfile -t repo_files < <(find . -type f -name "$pattern")
  elif [ "$2" == "sops" ]; then
    mapfile -t repo_files < <(find . -type f -regex "$pattern")
  fi

  #echo "[${2^^}]: Discovered files: ${repo_files[@]}"
  for file in "${repo_files[@]}"; do
    [[ "${file:0:-4}" == ".gpg" ]] && continue
    if is_ignored "$file"; then continue; fi

    encrypt "$file" "$recipient" "$2"
    echo " encrypt mode - $file"
    git_replace "$file"
  done
}

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
  for pattern in "${secret_file_patterns[@]}"; do
    encrypt_pattern "$pattern" "sops"
  done

  if [ ${#config_lines[@]} -gt 1 ]; then
    # encrypt all none compatible secret files in .gitsecret below the type
    for basic_pattern in "${config_lines[@]:1}"; do
      echo "[SOPS -> GPG] Unsupported files listed in configuration, falling back to  GPG"
      encrypt_pattern "$basic_pattern" "gpg"
    done
  fi

else
  echo "[GPG]: secrets check starting"
  secret_file_patterns=("${config_lines[@]:1}")
  for pattern in "${secret_file_patterns[@]}"; do
    encrypt_pattern "$pattern" "gpg"
  done
fi

echo "======================"
"$git_path" commit --amend --no-edit
"$git_path" "$@"
directory_decrypt
