{
  inputs = { flake-utils.url = "github:numtide/flake-utils"; };

  outputs = { flake-utils, nixpkgs, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
        z3-factory = import ./package.nix;
        versions = builtins.fromJSON (builtins.readFile ./versions.json);
        # A set mapping a version of Z3 to its derivations
        z3-set = lib.listToAttrs (map (o:
          let
            version = lib.replaceStrings [ "." ] [ "_" ] o.version;
            name = "z3_${version}";
            diff = ./patches + "/${version}.diff";
            args = o // (if builtins.pathExists diff then {
              patches = [ diff ];
            } else
              { });
            value =
              pkgs.callPackage (z3-factory args) { python = pkgs.python3; };
          in { inherit name value; })
          (lib.filter (o: !(o.broken or false)) versions));
        # Given a list of Z3 versions `[V1 ... VN]`, `mk-bundle [V1 ... VN]` is a derivation that contains binaries `z3-V1`, ..., `z3-VN`.
        mk-bundle = z3-versions:
          pkgs.stdenv.mkDerivation {
            name = "z3-bundle";
            unpackPhase = "true";
            buildPhase = "true";
            installPhase = ''
              mkdir -p $out/bin
              ${lib.strings.concatMapStringsSep "\n" (version:
                let
                  z3 = z3-set.${
                      "z3_${lib.replaceStrings [ "." ] [ "_" ] version}"
                    };
                  ver = lib.replaceStrings [ "_" ] [ "." ] version;
                in ''ln -s "${z3}/bin/z3" $out/bin/z3-${ver}'') z3-versions}
            '';
          };
      in {
        packages = z3-set // {
          bundles = let
            versions-list = map (o: o.version) versions;
            mk = included:
              let
                bundle =
                  if lib.length included == 0 then { } else mk-bundle included;
                available =
                  lib.filter (o: !(lib.elem o included)) versions-list;
              in bundle // (if lib.length available == 0 then
                { }
              else
                (lib.listToAttrs (map (version: {
                  name = "z3_${lib.replaceStrings [ "." ] [ "_" ] version}";
                  value = mk (included ++ [ version ]);
                }) available)));
          in mk [ ];
        };

        lib.mk-z3-bundle = mk-bundle;

        apps = {
          test-z3-builds = {
            type = "app";
            program = "${pkgs.writeScript "test-z3-builds" ''
              for i in $(cat versions.json | ${pkgs.jq}/bin/jq '.[] | select(.broken? | not) | .version | split(".") | join("_")' -r);
                 do echo "z3_$i"; nix build .#"z3_$i";
              done
            ''}";
          };
        };
      });
}
