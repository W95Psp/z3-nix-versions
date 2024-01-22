# Z3 Nix versions
This repository makes available as many versions of Z3 as possible via
a Nix flake. The versions available can be listed with `nix flake show
github:W95Psp/z3-nix-versions`.

This repo also defines a github action to test the build of those Z3
versions, and another to automatically add (daily) new Z3 versions, if
any.

## Cachix
Prebuilt Z3 are cached using Cachix https://app.cachix.org/cache/z3-nix-versions#pull
