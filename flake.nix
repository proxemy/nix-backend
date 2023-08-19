{
description = "Bare minimum example flake";

inputs = {
	nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
};

outputs = { self, nixpkgs }:
let
	system = "x86_64-linux";
	pkgs = nixpkgs.legacyPackages.${system};
	globalDebug = true;
	cfg = ./cfg.nix;
in
{
	nginx-cfg = { root, port ? "80" }:
	pkgs.writeText "nginx.conf" ''
		user nobody nobody;
		daemon off;
		error_log /dev/stdout info;
		pid /dev/null;
		events {}
		http {
			access_log /dev/stdout;
			server {
				listen ${port};
				index index.html;
				location / {
					root ${root};
				}
			}
		}
	'';


	packages.${system} =
	rec {
		# TODO: externalize the static www content into a dedicated file.
		www-content = pkgs.writeText "index.html" ''
			<html><body>
			<h1>Hello from web server.</h1>
			<form>Example form.<br>
			<input type="text">
			</form></body></html>
		'';

		# the apache server is not used. left it here for future consideration.
		apache = pkgs.apacheHttpd.override
		{
			proxySupport  = false;
			#ldapSupport   = false; # TODO: commented out because of compilation errors.
			luaSupport    = false;
			brotliSupport = false; # TODO: brotli compression might be needed.
		};

		nginx = pkgs.nginx.override
		{
			withDebug = globalDebug;
			withStream = false;
			withPerl = false;
		};

		docker =
 		pkgs.dockerTools.buildImage
		{
			name = "docker-name"; # TODO

			copyToRoot =
			[
				pkgs.fakeNss
				nginx
			];

			config = {
				Cmd =
				[
					"${nginx}/bin/nginx"
					"-c" (self.nginx-cfg { root = www-content; })
					"-e" "/tmp"
				];
			};
		};
	};

	apps.${system}.default =
	{
		type = "app";
		program = "${pkgs.hello}/bin/hello";
	};
};
}
