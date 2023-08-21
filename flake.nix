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

		website = pkgs.stdenv.mkDerivation
		{
			# TODO: This should be a minimal angular web app example.

			name = "test";
			src = www-content;

			#buildInputs = [ www-content ];

			installPhase = ''
				mkdir -p $out/www
				cp ${www-content} $out/www
			'';
		};

		docker =
 		pkgs.dockerTools.buildImage
		{
			name = "docker-name"; # TODO: global name variable.

			copyToRoot =
			[
				pkgs.fakeNss
				nginx
			];

			#extraCommands = "ls";

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
