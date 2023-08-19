{ pkgs ? import <nixpkgs> {} }:
pkgs.dockerTools.buildImage
{
	name = "test";
	config.Cmd = [ "${pkgs.hello}/bin/hello" ];
}
