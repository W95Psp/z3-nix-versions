{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    flake-utils,
    nixpkgs,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
        z3-factory = import ./package.nix;
        # z3-factory = pkgs.callPackage ./package.nix {};
        versions = builtins.fromJSON (builtins.readFile ./versions.json);
        z3-set = pkgs.lib.listToAttrs (map (
            o: let
              version = pkgs.lib.replaceStrings ["."] ["_"] o.version;
              name = "z3_${version}";
              diff = ./patches + "/${version}.diff";
              args =
                o
                // (
                  if builtins.pathExists diff
                  then {patches = [diff];}
                  else {}
                );
              value = pkgs.callPackage (z3-factory args) {
                python = pkgs.python3;
              };
            in {inherit name value;}
          )
          (pkgs.lib.filter (o: !(o.broken or false)) versions));
        mk-bundle = z3-versions:
          pkgs.stdenv.mkDerivation {
            name = "z3-bundle";
            unpackPhase = "true";
            buildPhase = "true";
            installPhase = "
              mkdir -p $out/bin
              ${pkgs.lib.strings.concatMapStringsSep "\n" (
                version: let
                  z3 = z3-set.${"z3_${pkgs.lib.replaceStrings ["."] ["_"] version}"};
                  ver = pkgs.lib.replaceStrings ["_"] ["."] version;
                in ''ln -s "${z3}/bin/z3" $out/bin/z3-${ver}''
              )
              z3-versions}
            ";
          };
      in {
        packages =
          z3-set
          // {
            z3-bundle = pkgs.stdenv.mkDerivation {
              name = "z3-bundle";
              unpackPhase = "true";
              buildPhase = "true";
              installPhase = "
                  mkdir -p $out/bin
                  echo '${builtins.toJSON (map (d: d.version) (pkgs.lib.attrValues z3-set))}' > $out/xx
                ";
            };
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
      }
    );
}
