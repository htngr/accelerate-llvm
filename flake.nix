{
  description = "Accelerate llvm backend";
  nixConfig = {
    bash-prompt = "\\e[34;1maccelerate-llvm-devShell ~ \\e[0m";

    allow-import-from-derivation = true;

    substituters = [
      "https://cache.nixos.org" # nixos cache
      "https://hydra.iohk.io" # iog hydra cache
      "https://iohk.cachix.org" # iog cachix cache
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" # nixos pubkey
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" # iog hydra pubkey
      "iohk.cachix.org-1:DpRUyj7h7V830dp/i6Nti+NEO2/nhblbov/8MW7Rqoo=" # iog cachix pubkey
    ];
  };
  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    haskell-nix.url = "github:input-output-hk/haskell.nix";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    flake-utils.url = "github:numtide/flake-utils";
    accelerate.url = "github:mangoiv/accelerate/mangoiv/switch-to-haskell-nix";
  };

  outputs = inputs @ {
    haskell-nix,
    nixpkgs,
    pre-commit-hooks,
    flake-utils,
    ...
  }: let
    supportedsystems =
      if builtins.hasAttr "currentSystem" builtins
      then [builtins.currentSystem]
      else nixpkgs.lib.systems.flakeExposed;
  in
    flake-utils.lib.eachSystem supportedsystems (system: let
      pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [
        inputs.accelerate.overlays.accelerate-overlay
        haskell-nix.overlay
      ];
      inherit (inputs.accelerate) lib;
      src = ./.;
      pchs = pre-commit-hooks.lib.${system}.run {
        inherit src;
        settings = {
          ormolu.defaultExtensions = [];
        };

        hooks = {
          cabal-fmt.enable = false;
          fourmolu.enable = false;
          hlint.enable = false;

          alejandra.enable = true;
          statix.enable = true;
          deadnix.enable = true;
        };
      };
      project = pkgs.haskell-nix.cabalProject' {
        inherit src;
        modules = [];

        compiler-nix-name = lib.mkDefault "ghc927";

        cabalProjectLocal = ''
          allow-newer:
            , llvm-hs-pure:bytestring
            , llvm-hs-pure:transformers
            , llvm-hs:transformers
        '';

        shell = {
          shellHook = ''
            ${pchs.shellHook}
          '';
          tools = {
            haskell-language-server = "latest";
          };
          exactDeps = true;
          withHoogle = false;
        };
      };
    in
      project.flake {
        variants = {
          ghc810.compiler-nix-name = "ghc8107";
          ghc94.compiler-nix-name = "ghc945";
          ghc96.compiler-nix-name = "ghc961";
        };
      });
}
