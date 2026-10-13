# sp1-overlay

[![CI](https://github.com/vaporif/sp1-overlay/actions/workflows/ci.yml/badge.svg)](https://github.com/vaporif/sp1-overlay/actions/workflows/ci.yml)

Nix packaging for [SP1](https://github.com/succinctlabs/sp1), the zero-knowledge proof system from Succinct Labs. You get an overlay, flake packages, and a builder function for compiling SP1 guest programs. Builds are pure and reproducible, and you don't need rustup.

Supported platforms: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`.

## Packages

| Package | Description |
|---------|-------------|
| `cargo-prove` | The SP1 CLI, built from source. It ships with a rustc wrapper that handles `RUSTUP_TOOLCHAIN=succinct` dispatch. |
| `sp1-rust-toolchain` | Prebuilt Rust toolchain with the SP1 RISC-V target |
| `sp1-sysroot` | One sysroot with the SP1 target libs and the host std |
| `sp1-host-std` | Host std rebuilt with SP1's custom Rust compiler |
| `buildSp1Program` | Builds SP1 guest programs as pure Nix derivations |

## SP1 versions

The overlay ships several SP1 versions under `pkgs.sp1.<version>`:

| Version | SP1 | Toolchain | Target |
|---------|-----|-----------|--------|
| `v6.9.0` (default) | 6.9.0 | 1.96.0-64bit-v3 | `riscv64im-succinct-zkvm-elf` |
| `v6.1.0` | 6.1.0 | 1.93.0-64bit | `riscv64im-succinct-zkvm-elf` |
| `v5.2.4` | 5.2.4 | 1.91.1 | `riscv32im-succinct-zkvm-elf` |

```nix
# Via overlay
pkgs.sp1."v6.9.0".cargo-prove
pkgs.sp1."v6.1.0".cargo-prove
pkgs.sp1."v5.2.4".cargo-prove

# Top-level aliases point to the default version
pkgs.cargo-prove        # = pkgs.sp1."v6.9.0".cargo-prove
pkgs.buildSp1Program    # = pkgs.sp1."v6.9.0".buildSp1Program
```

## Installation

### Quick start

```bash
nix develop github:vaporif/sp1-overlay
cargo prove --version
```

### Flake overlay

This flake only provides the SP1 tooling, so you need to add your own `cargo`.

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sp1.url = "github:vaporif/sp1-overlay";
  };

  outputs = { nixpkgs, sp1, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ sp1.overlays.default ];
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.cargo
          pkgs.cargo-prove
        ];
      };
    };
}
```

## Building SP1 programs with Nix

`buildSp1Program` compiles an SP1 guest program to a RISC-V ELF binary inside a pure Nix derivation. It doesn't call `cargo prove` and doesn't touch the network during the build.

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sp1.url = "github:vaporif/sp1-overlay";
  };

  outputs = { nixpkgs, sp1, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ sp1.overlays.default ];
      };
    in {
      packages.${system}.my-program-elf = pkgs.buildSp1Program {
        pname = "my-program";
        src = ./.;
        cargoLock = { lockFile = ./Cargo.lock; };
      };
    };
}
```

```bash
nix build .#my-program-elf
file result/my-program  # ELF 64-bit LSB executable, UCB RISC-V
```

Parameters:

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `pname` | yes | | Cargo package name of the program crate |
| `src` | yes | | Source tree. Must contain `Cargo.lock`. |
| `cargoLock` | yes | | `{ lockFile = ./Cargo.lock; }`. Dependencies are vendored for you. |
| `version` | no | `"0.1.0"` | Derivation version |
| `target` | no | depends on SP1 version | SP1 compilation target |

[`test-app/`](test-app/) has a full working example.

## Other SP1 versions

To build an SP1 version the overlay doesn't include, use `lib.mkSp1Packages`. Copy an entry from [`lib/versions.nix`](lib/versions.nix) and change the values.

[`docs/upstream-reference.md`](docs/upstream-reference.md) explains where each field comes from in SP1's source and how to find the right values for a new version.

## How it works

`cargo-prove` normally relies on rustup to switch between your host Rust toolchain and the SP1 cross-compiler. Nix has no rustup, so this flake bundles a rustc wrapper. The wrapper:

- answers `--print sysroot` with a combined sysroot that includes SP1's RISC-V target libs
- sends `riscv{32,64}im-succinct-zkvm-elf` builds to the SP1 toolchain's rustc
- passes everything else (proc-macros, build scripts, other host dependencies) to the next `rustc` on PATH

Host code is compiled by whatever Rust toolchain you already use: fenix, oxalica, nixpkgs, or something else. `cargo-prove` only takes over for the SP1 guest target.

`buildSp1Program` does what `cargo prove build` does, inside a pure Nix derivation:

1. `importCargoLock` vendors the dependencies from `Cargo.lock`.
2. The `rustc` from the SP1 sysroot cross-compiles to the RISC-V target.
3. `CARGO_ENCODED_RUSTFLAGS` passes the same flags SP1 uses internally.
4. The result is a statically linked RISC-V ELF that your host program can load with `include_elf!`.

## License

MIT
