{
description = "Bare minimum example flake";

inputs = {
	nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
};

outputs = { self, nixpkgs }:
let
	name = "webapp";
	system = "x86_64-linux";
	pkgs = nixpkgs.legacyPackages.${system};
	debug = true;

	nginx-conf = import ./nix/nginx-conf.nix { inherit pkgs; };
	postgres-conf = import ./nix/postgres-conf.nix { inherit pkgs; };
	website = import ./nix/website.nix { inherit pkgs; };
in
{
	packages.${system} =
	rec {

		db-structure = pkgs.stdenv.mkDerivation
		{
			name = "postgres-initdb";

			buildInputs = [ postgres ];

			dontUnpack = true; # disabling unpacking makes a 'src' variable obsolete.

			buildPhase = ''
				${postgres}/bin/initdb $out
				#"-A" "scram-sha-512" # disables default 'trusted' authentification
			'';
		};

		nginx = pkgs.nginx.overrideAttrs
		{
			withDebug = debug;
			withStream = false;
			withPerl = false;
		};

		postgres = pkgs.postgresql.overrideAttrs
		{
			enableSystemd = false;
			gssSupport = false;
			jitSupport = false;
		};

		docker-www = pkgs.dockerTools.buildImage
		{
			name = name + "_nginx";

			copyToRoot = pkgs.buildEnv
			{
				name = "image-root";

				paths = [
					nginx
					pkgs.fakeNss
					website
				];

				pathsToLink = [
					nginx
					"/etc" # /etc{nsswitch.conf,passwd} is required by nginx/getpwnam()
				];
			};

			config = {
				User = "nobody:nobody";
				Cmd =
				[
					"${nginx}/bin/nginx"
					"-c" (nginx-conf { root = website; })
					# TODO: maybe reintroduce the '-e' parameter again to fix:
					# [alert] could not open error log file: open() "/var/log/nginx/error.log" failed
				];
			};
		};

		docker-db = pkgs.dockerTools.buildLayeredImage
		{
			name = name + "_postgres";

			maxLayers = 2; # for better build times

			contents = [
				postgres
				pkgs.dockerTools.fakeNss

				# TMP
				pkgs.coreutils-full
				pkgs.dockerTools.binSh
				pkgs.findutils
			];

			fakeRootCommands = ''
				mkdir -p ./data/${name}
				mkdir -p ./run/postgresql
				cp -r ${db-structure}/* ./data/${name}/
				cp -r ${postgres-conf {}} ./data/${name}/
				chown -R nobody ./data/${name} ./run/postgresql
				chmod -R u=+rwx,go=-rwx ./data/${name}
				chmod -R u=+rwx,go=-rwx ./run/postgresql
			'';

			config = {
				User = "nobody:nobody";
				Cmd =
				[
					"${postgres}/bin/postgres"
					"-d" (if debug then "5" else "1")
					"-D" "/data/${name}"
				];
				WorkingDir = "/data/${name}";
				Volumes = { "/data" = {}; };
			};
		};
	};

	apps.${system}.default =
	{
		type = "app";
		program = "${pkgs.hello}/bin/hello";
	};

	formatter.${system} = pkgs.nixpkgs-fmt;
};
}
