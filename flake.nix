{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {

        # used by nix shell and nix develop
        devShell =
          with pkgs;
          mkShell {
            buildInputs = [
              git
              nix
              nixfmt-rfc-style
              rubyPackages.standard
              ruby
            ];
          };
      }
    );
}
