# parse-meta.nix
#
#--- eval store path for nixpkgs flakeref (example rev from flake.lock)
# nix flake metadata 'github:NixOS/nixpkgs?rev=9355fa86e6f27422963132c2c9aeedb0fb963d93' --json | jq -r .path
#
#--- nix-env metadata output reference (try to keep out output format structured like this)
# nix-env -qa --meta --json -f /nix/store/77ijmdbv96rhqj2sr7aq0i5q8p16ii0d-source
#
#--- use this to parse select package metadata
# nix eval --json -f parse-meta.nix --apply 'f: f { ps = ["hello" "vim"]; pkgs = import /nix/store/77ijmdbv96rhqj2sr7aq0i5q8p16ii0d-source {}; }' | jq .
#
#--- or (see that non-existent pkg names are excluded from output)
# nix eval --json -f parse-meta.nix --apply 'f: f { ps = ["hello" "vim" "asdfasdfasdfasdfasfd"]; pkgs = import /nix/store/77ijmdbv96rhqj2sr7aq0i5q8p16ii0d-source {}; }' | jq .

#--- breadcrumbs (default to some sane "all"?)
#{ ps ? (import (pkgs.path + "/pkgs/top-level/release-attrpaths-superset.nix") { }).names
{ ps ? [ ]
, pkgs
}:
with builtins;
let
  safeAttr = k: v: (k ? ${v}) && (tryEval k.${v}).success;
  optionalAttrSet = cond: a: if cond then a else { };
  valForPkg = v: p: optionalAttrSet ((safeAttr pkgs p) && (safeAttr pkgs.${p} v)) { ${v} = pkgs.${p}.${v}; };
  # TODO
  srcUrlForPkg = p: optionalAttrSet ((safeAttr pkgs p) && (safeAttr pkgs.${p} "src") && (safeAttr pkgs.${p}.src "url")) { "urls" = pkgs.${p}.src.url; };
  infoForPkg = p: foldl'
    (cur: nxt: let ret = valForPkg nxt p; in cur // ret)
    { }
    [ "meta" "name" "outputName" "outputs" "pname" "system" "version" ];
  infoForPkgs = packages: map
    (x: optionalAttrSet (safeAttr pkgs x) { ${x} = (infoForPkg x) // (srcUrlForPkg x); })
    packages;
in
foldl' (cur: nxt: cur // nxt) { } (infoForPkgs ps)


