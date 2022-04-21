# dkml-workflows

A set of GitHub Action workflows for use with Diskuv OCaml (DKML) tooling.

## Auto-generating GitHub releases for OCaml native executables

The following OCaml build environments will be setup for you:

| ABIs                       | Native `ocamlopt` compiler supports the following operating systems:                                                                 |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| win32-windows_x86          | 32-bit Windows for Intel/AMD CPUs                                                                                                    |
| win32-windows_x86_64       | 64-bit Windows for Intel/AMD CPUs                                                                                                    |
| macos-darwin_all           | 64-bit macOS for Intel and Apple Silicon CPUs. Using `dune -x darwin_arm64` will cross-compile to both; otherwise defaults to Intel. |
| manylinux2014-linux_x86    | 32-bit Linux: CentOS 7, CentOS 8, Fedora 32+, Mageia 8+, openSUSE 15.3+, Photon OS 4.0+ (3.0+ with updates), Ubuntu 20.04+           |
| manylinux2014-linux_x86_64 | 64-bit Linux: CentOS 7, CentOS 8, Fedora 32+, Mageia 8+, openSUSE 15.3+, Photon OS 4.0+ (3.0+ with updates), Ubuntu 20.04+           |

> Cross-compiling typically requires that you use Dune to build all your OCaml package dependencies.
> [opam monorepo](https://github.com/ocamllabs/opam-monorepo#readme) makes it easy to do exactly that.
> Alternatively you can directly use [findlib toolchains](http://projects.camlcity.org/projects/dl/findlib-1.9.3/doc/ref-html/r865.html).

You will need three sections in your GitHub Actions `.yml` file to build your executables:

1. A `setup-dkml` workflow to create the above build environments
2. A "matrix build" workflow to build your OCaml native executables on each
3. A "release" workflow to assemble all of your native executables into a single release

### `setup-dkml` workflow

Add the `setup-dkml` child workflow to your own GitHub Actions `.yml` file:

```yaml
jobs:
  setup-dkml:
    uses: 'diskuv/dkml-workflows/.github/workflows/setup-dkml.yml@v0'
    with:
      ocaml-compiler: 4.12.1
```

Only OCaml `4.12.1` is supported today.

### matrix build workflow

```yaml
jobs:
  setup-dkml:
    # ...
  build:
    # Wait until `setup-dkml` is finished
    needs: setup-dkml
    
    # Five (5) build environments will be available. You can include
    # all of them or a subset of them.
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: windows-2019
            abi: win32-windows_x86
            dkml-host-abi: windows_x86
            default_shell: msys2 {0}
          - os: windows-2019
            abi: win32-windows_x86_64
            dkml-host-abi: windows_x86_64
            default_shell: msys2 {0}
          - os: macos-latest
            abi: macos-darwin_all
            dkml-host-abi: darwin_x86_64
            default_shell: sh
          - os: ubuntu-latest
            abi: manylinux2014-linux_x86
            default_shell: sh
            dkml-host-abi: linux_x86
          - os: ubuntu-latest
            abi: manylinux2014-linux_x86_64
            default_shell: sh
            dkml-host-abi: linux_x86_64

    runs-on: ${{ matrix.os }}
    name: build-${{ matrix.abi }}

    # Use a Unix shell by default, even on Windows
    defaults:
      run:
        shell: ${{ matrix.default_shell }}

    steps:
      # Checkout your source code however you'd like. Typically it is:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Install MSYS2 to provide Unix shell (Windows only)
        if: startsWith(matrix.dkml-host-abi, 'windows')
        uses: msys2/setup-msys2@v2
        with:
          msystem: MSYS
          update: true
          install: >-
            tree
            wget
            make
            pkg-config
            rsync
            diffutils
            patch
            unzip
            git
            xz
            tar

      - name: Download setup-dkml artifacts
        uses: actions/download-artifact@v3
        with:
          path: .ci/dist

      - name: Import build environments from setup-dkml
        run: |
          ${{ needs.setup-dkml.outputs.import_func }}
          import ${{ matrix.host_target_abis }}

      - name: Cache Opam downloads by host
        uses: actions/cache@v2
        with:
          path: ${{ matrix.opam-root }}/download-cache
          key: ${{ matrix.dkml-host-abi }}

      - name: Use opamrun to build your executable
        run: |
          #!/bin/sh
          set -eufx
          opamrun install . --with-test --deps-only
          opamrun exec -- dune build @install
```

### release workflow

```yaml
jobs:
  setup-dkml:
    # ...
  build:
    # ...
  release:
    runs-on: ubuntu-latest
    # Wait until `build` complete
    needs:
      - build
    steps:
      - uses: actions/download-artifact@v3
        with:
          path: dist

      - name: Remove setup artifacts
        run: rm -rf setup-*
        working-directory: dist

      - name: Display files to be distributed
        run: ls -R
        working-directory: dist

      - name: Release (only when Git tag pushed)
        uses: softprops/action-gh-release@v1
        if: startsWith(github.ref, 'refs/tags/')
        with:
          files: |
            dist/*
```
