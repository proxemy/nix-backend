#!/usr/bin/env bash

set -xeuo pipefail

pidof dockerd || exit 1
#mkdir -p /tmp/nginx_client_body

# stopping and removing all previous docker container/images
docker stop   $(docker ps -aq) || true
docker rm -vf $(docker ps -aq) || true
docker rmi -f $(docker images -aq) || true

if [ -z ${1-""} ]; then
	echo "building default flake"
	nix build flake.nix#docker
	nix_result=$(readlink result)
else
	nix_result=$(nix-build docker"$1".nix)
fi

docker_image=$(docker load < "$nix_result" | cut -d' ' -f3)

docker run -p 80:80 "$docker_image"
#docker run "$docker_image"
# shell into into runnig container
#docker run -it --entrypoint /bin/bash "$docker_image"
