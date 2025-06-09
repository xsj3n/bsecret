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
  };
}

