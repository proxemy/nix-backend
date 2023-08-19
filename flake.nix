{
	description = "Bare minimum example flake";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
	};

	outputs = { self, nixpkgs }:
	let
		system = "x86_64-linux";
		pkgs = nixpkgs.legacyPackages.${system};
	in
	{
		packages.${system} =
		{
			# TODO: externalize the static www content into a dedicated file.
			www-content = pkgs.writeTextDir "index.html" ''
				<html><body>
				<h1>Hello from web server.</h1>
				<form>Example form.<br>
				<input type="text">
				</form></body></html>
			'';

			webserver = pkgs.apacheHttpd;
		};

		apps.${system}.default =
		let
			hello = pkgs.hello;
		in
		{
			type = "app";
			program = "${hello}/bin/hello"; #pkgs.dockerTools.buildImage;
		};
	};
}
