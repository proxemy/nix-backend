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
in
{
	nginx-cfg = { root, port ? "80" }:
	pkgs.writeText "nginx.conf" ''
		# see 'https://nginx.org/en/docs/' for config details.

		daemon off;
		error_log /dev/stdout ${if debug then "debug" else "warn"};
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

	postgresql-cfg = { port ? "5432" }:
	pkgs.writeText "postgreql.conf" ''
			#datestyle = 'iso, mdy'
			timezone = 'America/Chicago'
			lc_messages = 'C'			# locale for system error message strings
			lc_monetary = 'C'			# locale for monetary formatting
			lc_numeric = 'C'			# locale for number formatting
			lc_time = 'C'				# locale for time formatting

			# default configuration for text search
			listen_addresses = '*'		# what IP address(es) to listen on;
			port = ${port}
			max_connections = 100			# (change requires restart)
			unix_socket_directories = '/tmp'	# comma-separated list of directories
			shared_buffers = 128MB			# min 128kB
			dynamic_shared_memory_type = posix	# the default is the first option
			max_wal_size = 1GB
			min_wal_size = 80MB

			log_timezone = 'America/Chicago'
			default_text_search_config = 'pg_catalog.english'

			# TODO: figure out, wth this is
			#shared_preload_libraries = 'auto_explain,pgsodium'
			#pgsodium.getkey_script = '@PGSODIUM_GETKEY_SCRIPT@'
	'';

	packages.${system} =
	rec {
		www-content = pkgs.writeTextDir "index.html" ''
			<html><body>
			<h1>Hello from web server.</h1>
			<form>Example form.<br>
			<input type="text">
			</form></body></html>
		'';

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
					"-c" (self.nginx-cfg { root = www-content; })
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
				chown nobody ./data/${name}
				chmod u=+rwx,go=-rwx ./data/${name}
			'';

			config = {
				User = "nobody:nobody";
				Cmd =
				[
					"${postgres}/bin/postgres"
					"-d" (if debug then "5" else "1")
					"--config-file=${self.postgresql-cfg {} }"
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
