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
in
{
	nginx-cfg = { root, port ? "80" }:
	pkgs.writeText "nginx.conf" ''
		# see 'https://nginx.org/en/docs/' for config details.

		daemon off;
		error_log /dev/stdout ${if globalDebug then "debug" else "warn"};
		pid /dev/null;
		events {}

		http {
			access_log /dev/stdout;
			server {
				listen ${port};
				listen [::]:${port};
				index index.html;
				location / {
					root ${root};
				}
			}

			# see 'https://postgrest.org/en/stable/explanations/nginx.html'
			upstream postgrest {
				server localhost:3000; # TODO parameterize postgres port
			}

			server {
				location /api/ {
					default_type  application/json;
					proxy_hide_header Content-Location;
					add_header Content-Location  /api/$upstream_http_content_location;
					proxy_set_header  Connection "";
					proxy_http_version 1.1;
					proxy_pass http://postgrest/;
				}
			}

			# TODO: find better places or disable right away.
			client_body_temp_path /dev/null;
			proxy_temp_path       /dev/null;
			fastcgi_temp_path     /dev/null;
			uwsgi_temp_path       /dev/null;
			scgi_temp_path        /dev/null;
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

		docker-www = pkgs.dockerTools.buildImage
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
					"-c" (self.nginx-cfg { root = www-content; })
				];
			};
		};

		docker-db = pkgs.dockerTools.buildImage
		{
			name = name + "_docker";

			copyToRoot = pkgs.buildEnv
			{
				name = name;

				paths = [
					pkgs.postgresql
					pkgs.fakeNss
				];

				pathsToLink = [ pkgs.postgresql "/etc" ]; # /etc{nsswitch.conf,passwd} is required by nginx/getpwnam()
			};

			config = {
				User = "nobody:nobody";
				Cmd =
				[
					"${pkgs.postgresql}/bin/postgres"
					"--config-file" "TODO"
				];
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
