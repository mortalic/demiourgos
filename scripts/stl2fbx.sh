#!/usr/bin/env bash
# stl2fbx.sh — convert project STL meshes to FBX via assimp.
#
# OpenSCAD (and so demiourgos) cannot export FBX, so this is a post-export step.
# The FBX is a plain triangle mesh (no parametric history or materials) — same
# geometry as the source STL, just in a format DCC tools / engines import.
#
# Usage:
#   scripts/stl2fbx.sh                 # convert every projects/*/stl/*.stl
#   scripts/stl2fbx.sh path/to/a.stl … # convert the given STL files
#   scripts/stl2fbx.sh path/to/dir     # convert every *.stl under dir
#
# Each <project>/stl/<name>.stl is written to <project>/fbx/<name>.fbx (a sibling
# fbx/ dir); standalone file/dir args write the .fbx next to the .stl.
set -euo pipefail

command -v assimp >/dev/null || { echo "error: assimp not found (install 'assimp' / 'assimp-utils')." >&2; exit 1; }

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Build the list of STL files to convert.
stls=()
if [[ $# -eq 0 ]]; then
  while IFS= read -r f; do stls+=("$f"); done \
    < <(find "$repo_root/projects" -type f -path '*/stl/*.stl' 2>/dev/null | sort)
else
  for arg in "$@"; do
    if [[ -d "$arg" ]]; then
      while IFS= read -r f; do stls+=("$f"); done < <(find "$arg" -type f -name '*.stl' | sort)
    elif [[ -f "$arg" ]]; then
      stls+=("$arg")
    else
      echo "warning: skipping '$arg' (not a file or directory)" >&2
    fi
  done
fi

[[ ${#stls[@]} -gt 0 ]] || { echo "no .stl files found."; exit 0; }

count=0
for stl in "${stls[@]}"; do
  dir="$(dirname "$stl")"
  base="$(basename "$stl" .stl)"
  # If it lives in a stl/ dir, write to a sibling fbx/ dir; else alongside.
  if [[ "$(basename "$dir")" == "stl" ]]; then
    out_dir="$(dirname "$dir")/fbx"
  else
    out_dir="$dir"
  fi
  mkdir -p "$out_dir"
  out="$out_dir/$base.fbx"
  assimp export "$stl" "$out" >/dev/null 2>&1
  echo "  ${stl#"$repo_root"/} -> ${out#"$repo_root"/}"
  count=$((count + 1))
done
echo "converted $count file(s)."
