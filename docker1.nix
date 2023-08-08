# * Cmd "-e" parameter needs a persistent/secure location to store logs to

{ pkgs ? import <nixpkgs> {} }:
let
	nginxConf = pkgs.writeText "nginx.conf" ''
		user nobody nobody;
		pid /dev/null;
		events {}
	'';
in
pkgs.dockerTools.buildImage
{
	name = "docker-test";
	copyToRoot = [ pkgs.nginx pkgs.fakeNss ];

	created = "now";

	config = {
		Cmd = [
			"${pkgs.nginx}/bin/nginx"
			"-c" nginxConf
			"-e" "/tmp"
		];
	};
}
