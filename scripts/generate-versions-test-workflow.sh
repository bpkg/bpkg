#!/usr/bin/env bash

declare tags="$(git tag -l)"
declare versions=".github/workflows/versions.yml"

rm -f "$versions"

cat - > "$versions" <<VERSIONS
name: versions
 on:
   - pull_request
   - push

jobs:
  verify-tags:

    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout
        with:
          force-depth: 0
      - name: Verify Setup For Tags
        run: |
          for tag in "\$(git tag -l"); do
            echo "Verify \$tag:"

            curl https://raw.githubusercontent.com/bpkg/bpkg/\$tag/setup.sh | bash
            version="\$(bpkg --version)"

            if [ "\$version" != "\$tag" ]; then
              echo "Failed to verify \$tag"
              exit 1
            fi
        done
VERSIONS
