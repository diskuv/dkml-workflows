#!/bin/sh
set -eufx
[ -d "$OPAMROOT/installer-$INSTALLERNAME/.opam-switch" ] || PATH="$GITHUB_WORKSPACE/.ci/sd4/bs/bin:$PATH" opam switch create installer-"$INSTALLERNAME" --repos diskuv,default --empty
