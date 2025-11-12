{
  description = "bsecret development shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };
  outputs = { self, nixpkgs }: 
  let
    name = "bsecret";
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };
    
    packages = with pkgs; [
      gh
      sops
      bash-language-server
    ];
  in
  {
    devShells."${system}".default = pkgs.mkShell
    {
      inherit name packages;
    };

    packages.${system}.default = pkgs.stdenv.mkDerivation {
      name = "bsecret-git";
      src = ./.;
      buildPhase = "true";
      installPhase = ''
        mkdir -p $out/bin
        cp ./git $out/bin/.
        chmod +x $out/bin/git
      '';
    };
  };
}

