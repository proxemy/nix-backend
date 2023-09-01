{ pkgs }: { root, port ? "80", debug ? false }:
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
}''
