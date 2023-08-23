#!/usr/bin/env bash

set -xeuo pipefail

pidof dockerd || exit 1

# stopping and removing all previous docker container/images
docker stop   $(docker ps -aq) || true
docker rm -vf $(docker ps -aq) || true
docker rmi -f $(docker images -aq) || true

if [ -z ${1-""} ]; then
	echo "using default flake"
	nix build .#docker-www
	#nix build .#docker-db
	nix_result=$(readlink result)
else
	nix_result=$(nix build .#"$1")
fi

docker_image=$(docker load < "$nix_result" | cut -d' ' -f3)

docker run -p 80:80 "$docker_image"


# shell into into runnig container
#sleep 5
#container_id=$(docker container ls | tail -1 | cut -d' ' -f1)
#docker exec -it "$container_id" sh
