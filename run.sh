#!/usr/bin/env bash

set -xeuo pipefail


nix_build_args="--debug"
docker_run_args=()


load_docker_result()
{
	nix_result=$(readlink result)
	docker load < "$nix_result" | cut -d' ' -f3
}

reset_docker()
{
	docker rm -vf $(docker ps -aq) || true
	docker rmi -f $(docker images -aq) || true
	docker volume rm $(docker volume ls -q) || true
}

build_db()
{
	nix build .#docker-db "$nix_build_args"
	docker_run_args+=("-v data:/data $(load_docker_result)")
}

build_www()
{
	nix build .#docker-www "$nix_build_args"
	docker_run_args+=("-p 80:80 $(load_docker_result)")
}


pidof dockerd || exit 1

# stopping and removing all previous docker container/images
docker stop $(docker ps -aq) || true

for arg in "$@"; do
	case "$arg" in
		"-c") reset_docker ;;
		"db") build_db ;;
		"www") build_www ;;
	esac
done

pids=()

for run_arg in "${docker_run_args[@]}"; do
	docker run $run_arg &
	pids+=($!)
	# TODO: parameterize testnet so one can have many internal networks of containers
	# TODO: Better make flake targets for systemd unit files
done

wait ${pids[@]}

# docker volume create data
#docker run -p 80:80 --mount type=volume,src=data,target=/data "$docker_image"
#docker run -v data:/data "$docker_image"
