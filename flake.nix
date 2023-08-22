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
	globalDebug = true;
	cfg = ./cfg.nix;
in
{
	nginx-cfg = { root, port ? "80" }:
	pkgs.writeText "nginx.conf" ''
		user nobody nobody;
		daemon off;
		error_log /dev/stdout ${if globalDebug then "debug" else "info"};
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
			# TODO: find better places or disable right away.
			client_body_temp_path /tmp;
			proxy_temp_path /tmp;
			fastcgi_temp_path /tmp;
			uwsgi_temp_path /tmp;
			scgi_temp_path /tmp;
		}
	'';


	packages.${system} =
	rec {
		# TODO: externalize the static www content into a dedicated file.
		www-content = pkgs.writeTextDir "index.html" ''
			<html><body>
			<h1>Hello from web server.</h1>
			<form>Example form.<br>
			<input type="text">
			</form></body></html>
		'';

		nginx = pkgs.nginx.overrideAttrs
		{
			withDebug = globalDebug;
			withStream = false;
			withPerl = false;
		};

		docker = pkgs.dockerTools.buildImage
		{
			name = name + "_docker";

			copyToRoot = pkgs.buildEnv
			{
				name = name;

				paths = [
					nginx
					pkgs.fakeNss
					www-content
				];

				pathsToLink = [ nginx "/etc" ]; # /etc{nsswitch.conf,passwd} is required by nginx/getpwnam()
			};

			config = {
				Cmd =
				[
					"${nginx}/bin/nginx"
					"-c" (self.nginx-cfg { root = www-content; })
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
