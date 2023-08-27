#!/usr/bin/env bash

set -xeuo pipefail

pidof dockerd || exit 1

# stopping and removing all previous docker container/images
docker stop   $(docker ps -aq) || true

if [[ "$@" =~ ^-c$ ]]; then
	docker rm -vf $(docker ps -aq) || true
	docker rmi -f $(docker images -aq) || true
	docker volume rm $(docker volume ls -q) || true
	exit 0
fi

if [ -z ${1-""} ] || [[ "$@" =~ ^- ]]; then
	#nix build .#docker-www
	nix build .#docker-db --debug
else
	nix build .#"$1"
fi

nix_result=$(readlink result)

docker_image=$(docker load < "$nix_result" | cut -d' ' -f3)

if [[ "$@" =~ ^-i$ ]]; then
	docker run -it -v data:/data "$docker_image" sh
else
	# docker volume create data
	#docker run -p 80:80 --mount type=volume,src=data,target=/data "$docker_image"
	#docker run -v data:/data "$docker_image"
	docker run -v data:/data "$docker_image"
fi
