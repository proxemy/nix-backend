{ pkgs ? import <nixpkgs> {} }:
let
  nginxPort = "80";
  nginxConf = pkgs.writeText "nginx.conf" ''
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
  nginxWebRoot = pkgs.writeTextDir "index.html" ''
    <html><body>
	<h1>Hello from NGINX</h1>
	<form>Example form.<br>
	<input type="text">

	</form>
	</body></html>
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "nginx-container";
  tag = "latest";
  contents = [
    pkgs.fakeNss
    pkgs.nginx
  ];

  extraCommands = ''
    mkdir -p tmp/nginx_client_body

    # nginx still tries to read this directory even if error_log
    # directive is specifying another file :/
    mkdir -p var/log/nginx
  '';

  config = {
    Cmd = [ "nginx" "-c" nginxConf ];
    ExposedPorts = {
      "${nginxPort}/tcp" = {};
    };
  };
}
