#!/usr/bin/env bash

declare shell_targets=(setup.sh bpkg.sh)
declare json_targets=(bpkg.json)
declare latest="$(git describe --tags --abbrev=0)"

for target in "${shell_targets[@]}"; do
  sed -i "s/VERSION=.*/VERSION=\"$latest\"/g" "$target"
done

for target in "${json_targets[@]}"; do
  sed -i "s/\"version\"\s*:\s*\".*\",/\"version\": \"$latest\",/g" "$target"
done
