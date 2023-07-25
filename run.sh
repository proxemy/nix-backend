#!/usr/bin/env bash

set -xeuo pipefail

pidof dockerd || exit 1

nix_result=$(nix-build docker.nix)

docker_image=$(docker load < "$nix_result" | cut -d' ' -f3)

docker run "$docker_image"
