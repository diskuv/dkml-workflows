#!/bin/sh
set -eufx

# empty opam repository
install -d "$GITHUB_WORKSPACE"/.ci/sd4/eor
cat > "$GITHUB_WORKSPACE".ci/sd4/eor/repo <<EOF
opam-version: "2.0"
browse: "https://opam.ocaml.org/pkg/"
upstream: "https://github.com/ocaml/opam-repository/tree/master/"
EOF

PATH="$GITHUB_WORKSPACE/.ci/sd4/bs/bin:$PATH"
if [ ! -e "$OPAMROOT/.ci.root-init" ]; then
  rm -rf "$OPAMROOT" # Clear any partial previous attempt
  if [ "$ISWINDOWS" = true ]; then
    eor=$(cygpath -am "$GITHUB_WORKSPACE"/.ci/sd4/eor)
    opam init --disable-sandboxing --no-setup --kind local --bare "$eor"
    opam option --yes --global download-command=wget
  else
    opam init --disable-sandboxing --no-setup --kind local --bare "$GITHUB_WORKSPACE/.ci/sd4/eor"
  fi
  touch "$OPAMROOT/.ci.root-init"
fi
opam var --global || true
