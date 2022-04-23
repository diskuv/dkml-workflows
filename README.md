# dkml-workflows

GitHub Action workflows used by and with Diskuv OCaml (DKML) tooling. DKML helps you
distribute native OCaml applications on the most common operating systems.

## setup-dkml: Auto-generating GitHub releases for OCaml native executables

With setup-dkml you can build and automatically create releases of OCaml native executables.
In contrast to the conventional [setup-ocaml](https://github.com/marketplace/actions/set-up-ocaml) GitHub Action:

| `setup-dkml`                         | `setup-ocaml`       | Consequence                                                                                                                                                                                                                                                                                                |
| ------------------------------------ | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GitHub child workflow                | GitHub Action       | `setup-dkml` is more complex to configure, and takes longer to run                                                                                                                                                                                                                                         |
| MSVC + MSYS2                         | GCC + Cygwin        | On Windows `setup-dkml` can let your native code use ordinary Windows libraries without ABI conflicts. You can also distribute your executables without the license headache of redistributing or statically linking `libgcc_s_seh` and `libstdc++`                                                        |
| dkml-base-compiler                   | ocaml-base-compiler | On macOS, `setup-dkml` cross-compiles to ARM64 with `dune -x darwin_arm64`                                                                                                                                                                                                                                 |
| dkml-base-compiler                   | ocaml-base-compiler | `setup-dkml` only supports 4.12.1 today. `setup-ocaml` supports all versions and variants of OCaml                                                                                                                                                                                                         |
| CentOS 7 and Linux distros from 2014 | Latest Ubuntu       | On Linx, `setup-dkml` builds with an old GLIBC. `setup-dkml` dynamically linked Linux executables will be highly portable as GLIBC compatibility issues should be rare, and compatible with the unmodified LGPL license used by common OCaml dependencies like [GNU MP](https://gmplib.org/manual/Copying) |
| 0 yrs                                | 4 yrs               | `setup-ocaml` is officially supported and well-tested.                                                                                                                                                                                                                                                     |
| Some pinned packages                 | No packages pinned  | `setup-dkml`, for some packages, must pin the version so that cross-platform patches (especially for Windows) are available. With `setup-ocaml` you are free to use any version of any package                                                                                                             |

> Put simply, use `setup-dkml` when you are distributing executables or libraries to the public. Use `setup-ocaml` for all other needs.

`setup-dkml` will setup the following OCaml build environments for you:

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
      fdopen-opamexe-bootstrap: true # Use opam.exe from fdopen's site on Windows. Temporary mitigation until a transient bug is fixed.
```

`setup-dkml` will create an Opam switch containing an OCaml compiler based on the dkml-base-compiler packages.
Only OCaml `ocaml-compiler: 4.12.1` is supported today.

The switch will have an Opam variable `ocaml-ci=true` that can be used in Opam filter expressions for advanced optimizations like:

```c
[ "make" "rebuild-expensive-assets-from-scratch" ]    {ocaml-ci}
[ "make" "download-assets-from-last-github-release" ] {!ocaml-ci}
```

### Matrix build workflow

You can copy and paste the following:

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
          import ${{ matrix.abi }}

      - name: Cache Opam downloads by host
        uses: actions/cache@v2
        with:
          path: ${{ matrix.opam-root }}/download-cache
          key: ${{ matrix.dkml-host-abi }}

      - name: Use opamrun to build your executable
        run: |
          #!/bin/sh
          set -eufx
          opamrun install . --with-test --deps-only --yes
          opamrun exec -- dune build @install

          # Package up whatever you built
          mkdir dist
          tar cvfCz dist/${{ matrix.abi }}.tar.gz _build/install/default .

      - uses: actions/upload-artifact@v3
        with:
          name: ${{ matrix.abi }}
          path: dist/${{ matrix.abi }}.tar.gz
```

The second last step ("Use opamrun to build your executable") should be custom to your application.

### Release workflow

You can copy and paste the following:

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
