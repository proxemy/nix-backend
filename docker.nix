#TODO:
# * Cmd "-e" parameter needs a persistent/secure location to store logs to

{
	pkgs ? import <nixpkgs> {},
}:
pkgs.dockerTools.buildImage
{
	name = "docker-test";
	copyToRoot = [ pkgs.nginx pkgs.coreutils ]; #pkgs.fakeNss

	created = "now";

	config = {
		Cmd = [
			"${pkgs.nginx}/bin/nginx"
			"-e" "/tmp"
		];
	};
}
