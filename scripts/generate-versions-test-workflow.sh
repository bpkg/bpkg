#!/usr/bin/env bash

declare -a tags=($(git tag -l))
declare versions=".github/workflows/versions.yml"

rm -f "$versions"

{
  echo "name: versions"
  echo "on:"
  echo "  - pull_request"
  echo "  - push"
  echo

  echo "jobs:" >> "$versions"

  for tag in "${tags[@]}"; do
    echo "  v$(echo "$tag" | tr '.' '-'):"
    echo "    runs-on: ubuntu-latest"
    echo "    steps:"
    echo "      - name: Verify Setup For $tag"
    echo "        run: |"
    echo "          curl https://raw.githubusercontent.com/bpkg/bpkg/$tag/setup.sh | bash"
    echo "          bpkg --version | grep $tag"
    echo
    break
  done

} >> "$versions"
