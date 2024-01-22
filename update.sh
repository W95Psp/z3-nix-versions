TEMP=$(mktemp)

VERSIONS=$(git ls-remote --tags https://github.com/Z3Prover/z3.git | grep -Po ".*refs/tags/z3-\K\d+\.\d+\.\d+$")
for version in $VERSIONS; do
    tag="z3-$version"
    if cat versions.json | jq --arg version "$version" -e 'any(.version == $version) | not' > /dev/null; then
      JSON=$(nix-prefetch-git --quiet --url https://github.com/Z3Prover/z3.git --rev "refs/tags/$tag")
      SHA256=$(echo "$JSON" | jq '.hash' -r)
      echo "{version: $version, sha256: $SHA256}"
      echo "$version" >> new_versions
      cat versions.json | \
          jq --arg sha256 "$SHA256" --arg version "$version" \
             '. + [{"version": $version, "sha256": $sha256}]' \
             > "$TEMP"
      cat "$TEMP" > versions.json
    fi
done

cat versions.json \
    | jq '. | sort_by(.version | (split(".") | .[] | tonumber | -.))' \
         > "$TEMP"
cat "$TEMP" > versions.json
         
         
