#!/usr/bin/env bash
#
# Print a commit message describing the r-* pins in nemo-image-env.yaml.
#
# Compares the working-tree pins against the last committed ones and writes a
# conventional-commit subject plus an "old -> new" body. Prints to stdout, so:
#
#   scripts/pin-msg.sh                       # preview
#   git commit -F <(scripts/pin-msg.sh)      # use it
#
# With no previous commit (or no previous pins) every package is reported as
# newly pinned.

set -euo pipefail

# Path is resolved relative to the repo root, not the current directory.
ENV_YAML="${1:-nemo-image-env.yaml}"
PKGS=(nemo tidywigits tidydragen)

repo_root=$(git rev-parse --show-toplevel)
cd "${repo_root}"

if [[ ! -f "${ENV_YAML}" ]]; then
  echo "No such env yaml: ${ENV_YAML}" >&2
  exit 1
fi

# Pull "r-<pkg> ==<version>" out of a conda env yaml on stdin.
pin_of() {
  local pkg="$1"
  sed -nE "s|^[[:space:]]*-[[:space:]]*r-${pkg}[[:space:]]*==[[:space:]]*([^[:space:]#]+).*|\1|p"
}

new_yaml=$(cat "${ENV_YAML}")
old_yaml=$(git show "HEAD:${ENV_YAML}" 2>/dev/null || true)

subject_parts=()
body_lines=()
for pkg in "${PKGS[@]}"; do
  new=$(pin_of "${pkg}" <<< "${new_yaml}")
  if [[ -z "${new}" ]]; then
    echo "Expected an 'r-${pkg} ==<version>' pin in ${ENV_YAML}" >&2
    exit 1
  fi
  old=$(pin_of "${pkg}" <<< "${old_yaml}")

  if [[ "${old}" == "${new}" ]]; then
    body_lines+=("  r-${pkg} ${new} (unchanged)")
  else
    subject_parts+=("r-${pkg} ${new}")
    body_lines+=("  r-${pkg} ${old:-none} -> ${new}")
  fi
done

if [[ ${#subject_parts[@]} -eq 0 ]]; then
  echo "No pin changes in ${ENV_YAML}" >&2
  exit 1
fi

# ${arr[*]} only honours the first char of IFS, so join by hand.
joined=$(printf ', %s' "${subject_parts[@]}")
subject="pin ${joined:2}"
# Keep the subject within the usual 72-char budget; spill detail to the body.
if [[ ${#subject} -gt 72 ]]; then
  n=${#subject_parts[@]}
  [[ ${n} -eq 1 ]] && noun="package" || noun="packages"
  subject="pin ${n} conda ${noun}"
fi

printf '%s\n\n' "${subject}"
printf 'Bundled package versions:\n'
printf '%s\n' "${body_lines[@]}"
