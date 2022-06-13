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

  echo "jobs:"
  echo "  verify-tags:"
  echo "    runs-on: ubuntu-latest"
  echo "    steps:"
  echo "      - name: Verify Setup For Tags"
  echo "        run: |"

  for tag in "${tags[@]}"; do
    echo "          echo \"Verify $tag:\""
    echo "          curl https://raw.githubusercontent.com/bpkg/bpkg/$tag/setup.sh | bash"
    echo "          bpkg --version | grep $tag"
    echo
  done

} >> "$versions"
