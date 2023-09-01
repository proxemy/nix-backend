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
	website = import ./nix/website { inherit pkgs; };
in
{
	packages.${system} =
	rec {
		www-content = pkgs.writeTextDir "index.html" ''
			<html><body>
			<h1>Hello from web server.</h1>
			<form>Example form.<br>
			<input type="text">
			</form></body></html>
		'';

		db-structure = pkgs.stdenv.mkDerivation
		{
			name = "postgres-initdb";

			buildInputs = [ postgres ];

			dontUnpack = true; # disabling unpacking makes a 'src' variable obsolete.

			buildPhase = ''
				${postgres}/bin/initdb $out
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
			name = name + "_docker";

			copyToRoot = pkgs.buildEnv
			{
				name = "image-root";

				paths = [
					nginx
					pkgs.fakeNss
					www-content
				];

				pathsToLink = [
					nginx
					"/tmp" # TODO handle nginx store pathes via docker/etc
					"/etc" # /etc{nsswitch.conf,passwd} is required by nginx/getpwnam()
				];
			};

			config = {
				User = "nobody:nobody";
				Cmd =
				[
					"${nginx}/bin/nginx"
					"-c" (nginx-conf { root = www-content; })
				];
			};
		};

		docker-db = pkgs.dockerTools.buildLayeredImage
		{
			name = name;

			contents = [
				postgres
				pkgs.dockerTools.fakeNss
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
