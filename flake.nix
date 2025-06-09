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
      bash-language-server
    ];
    shellHook = "alias git='./git_wrapper.sh'";
  in
  {
    devShells."${system}".default = pkgs.mkShell
    {
      inherit name packages shellHook;
    };
    packages.${system}.default = pkgs.stdenv.mkDerivation {
      name = "git";
      src = ./.;
      buildPhase = "true";
      installPhase = ''
        echo "Directory: $(pwd)"
        mkdir -p $out/bin
        cp bsecret.sh $out/bin/.
        chmod +x $out/bin/bsecret.sh
      '';
    };
  };
}

