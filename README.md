# sp1-overlay

[![CI](https://github.com/vaporif/sp1-overlay/actions/workflows/ci.yml/badge.svg)](https://github.com/vaporif/sp1-overlay/actions/workflows/ci.yml)

*Pure and reproducible* Nix packaging of [SP1](https://github.com/succinctlabs/sp1) (Succinct Labs' zero-knowledge proof system). Provides an overlay, flake packages, and a builder function for compiling SP1 guest programs — no rustup required.

Supported platforms: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`.

## Packages

| Package | Description |
|---------|-------------|
| `cargo-prove` | SP1 CLI tool, built from source with a rustc wrapper that handles `RUSTUP_TOOLCHAIN=succinct` dispatch |
| `sp1-rust-toolchain` | Pre-built Rust toolchain with the SP1 RISC-V target |
| `sp1-sysroot` | Combined sysroot with SP1 target libs and host std |
| `sp1-host-std` | Host-side std rebuilt with SP1's custom Rust compiler |
| `buildSp1Program` | Builder function to compile SP1 guest programs as pure Nix derivations |

## Multi-version support

Multiple SP1 versions are available through the overlay under `pkgs.sp1.<version>`:

| Version | SP1 | Toolchain | Target |
|---------|-----|-----------|--------|
| `v6.0.2` (default) | 6.0.2 | 1.93.0-64bit | `riscv64im-succinct-zkvm-elf` |
| `v5.2.4` | 5.2.4 | 1.91.1 | `riscv32im-succinct-zkvm-elf` |

```nix
# Via overlay
pkgs.sp1."v6.0.2".cargo-prove
pkgs.sp1."v5.2.4".cargo-prove

# Top-level aliases point to the default version
pkgs.cargo-prove        # = pkgs.sp1."v6.0.2".cargo-prove
pkgs.buildSp1Program    # = pkgs.sp1."v6.0.2".buildSp1Program
```

## Installation

### Quick start

```bash
nix develop github:vaporif/sp1-overlay
cargo prove --version
```

### Flake overlay

**You need to bring your own `cargo`** — this flake only provides SP1-specific tooling.

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

## Building SP1 programs as Nix derivations

`buildSp1Program` compiles SP1 guest programs to RISC-V ELF binaries as pure Nix derivations. No `cargo prove`, no network access at build time.

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

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `pname` | yes | -- | Cargo package name of the program crate |
| `src` | yes | -- | Source tree (must contain `Cargo.lock`) |
| `cargoLock` | yes | -- | `{ lockFile = ./Cargo.lock; }` -- dependencies are vendored automatically |
| `version` | no | `"0.1.0"` | Derivation version |
| `target` | no | per SP1 version | SP1 compilation target |

See [`test-app/`](test-app/) for a complete working example.

## Custom SP1 versions

Use `lib.mkSp1Packages` to build any SP1 version not included in the overlay:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sp1.url = "github:vaporif/sp1-overlay";
  };

  outputs = { nixpkgs, sp1, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      my-sp1 = sp1.lib.mkSp1Packages {
        inherit pkgs;
        versionConfig = {
          sp1-src = { owner = "succinctlabs"; repo = "sp1"; rev = "<commit>"; sha256 = "<hash>"; };
          succinct-rust = { owner = "succinctlabs"; repo = "rust"; rev = "<branch>"; sha256 = "<hash>"; };
          backtrace-rs = { owner = "rust-lang"; repo = "backtrace-rs"; rev = "<commit>"; sha256 = "<hash>"; };
          toolchain-version = "1.93.0-64bit";
          target = "riscv64im-succinct-zkvm-elf";
          edition = "2024";
          toolchain-hashes = {
            x86_64-linux = "<hash>";
            aarch64-linux = "<hash>";
            x86_64-darwin = "<hash>";
            aarch64-darwin = "<hash>";
          };
          cargo-lock-output-hashes = {};
          build-flags = [ "-C" "passes=lower-atomic" "-C" "panic=abort" ];
          extra-build-env = {};
        };
      };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ my-sp1.cargo-prove ];
      };
    };
}
```

Use an existing version from [`lib/versions.nix`](lib/versions.nix) as a template. Set `backtrace-rs = null` if the Rust fork includes its own checkout.

## How it works

`cargo-prove` normally requires rustup to dispatch between the host Rust toolchain and the SP1 cross-compiler. In Nix there is no rustup, so this flake bundles a rustc wrapper that:

- Intercepts `--print sysroot` to return a combined sysroot containing SP1's RISC-V target libs
- Routes `riscv{32,64}im-succinct-zkvm-elf` compilations to the SP1 toolchain's rustc
- Falls through to the next `rustc` on PATH for host/build dependencies (proc-macros, build scripts, etc.)

Your Rust toolchain (fenix, oxalica, nixpkgs, etc.) is used for host compilation -- `cargo-prove` only takes over for the SP1 guest target.

`buildSp1Program` replicates what `cargo prove build` does, but as a pure Nix derivation:

1. Dependencies are vendored from `Cargo.lock` via `importCargoLock`
2. The SP1 sysroot's `rustc` is used for cross-compilation to the RISC-V target
3. `CARGO_ENCODED_RUSTFLAGS` passes the same flags SP1 uses internally
4. The output is a statically-linked RISC-V ELF ready for `include_elf!` in your host program

## License

MIT
