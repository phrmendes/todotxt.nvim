{
  description = "todotxt.nvim Neovim plugin";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      version = (builtins.fromTOML (builtins.readFile ./.cz.toml)).tool.commitizen.version;
    in {
      packages = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          plugin = pkgs.vimUtils.buildVimPlugin {
            pname = "todotxt-nvim";
            inherit version;
            src = pkgs.lib.cleanSourceWith {
              src = self;
              filter = path: _: !(builtins.elem (baseNameOf path) [ ".git" ".devenv" ".pre-commit-config.yaml" ]);
            };
            meta.license = pkgs.lib.licenses.asl20;
          };
        in { default = plugin; todotxt-nvim = plugin; });
    };
}
