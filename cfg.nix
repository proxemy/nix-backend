{
	nginxWebRoot,
	nginxPort ? 80
}:
pkgs.writeText "nginx.conf" ''
	user nobody nobody;
	daemon off;
	error_log /dev/stdout info;
	pid /dev/null;
	events {}
	http {
		access_log /dev/stdout;
		server {
			listen ${nginxPort};
			index index.html;
			location / {
				root ${nginxWebRoot};
			}
		}
	}
'';

