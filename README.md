# sp1-overlay

[![CI](https://github.com/vaporif/sp1.nix/actions/workflows/ci.yml/badge.svg)](https://github.com/vaporif/sp1.nix/actions/workflows/ci.yml)

Nix flake packaging [SP1](https://github.com/succinctlabs/sp1) (Succinct Labs' zero-knowledge proof system) for reproducible, cross-platform use.

## Packages

- **cargo-prove** — SP1's CLI tool, built from source with a bundled rustc wrapper that handles `RUSTUP_TOOLCHAIN=succinct` dispatch automatically
- **sp1-rust-toolchain** — Pre-built Rust toolchain (v1.93.0-64bit) with `riscv64im-succinct-zkvm-elf` target
- **buildSp1Program** — Builder function to compile SP1 guest programs to RISC-V ELF as pure Nix derivations

Supported platforms: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`

## Usage

### Quick start (standalone devShell)

```bash
nix develop github:vaporif/sp1.nix
cargo prove --version
```

### In your flake's devShell

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sp1-nix.url = "github:vaporif/sp1.nix";
  };

  outputs = { nixpkgs, sp1-nix, ... }:
    let
      system = "aarch64-darwin"; # or x86_64-linux, etc.
      pkgs = import nixpkgs { inherit system; };
      sp1Pkgs = sp1-nix.packages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.cargo  # cargo-prove is a cargo subcommand, so cargo must be on PATH
          sp1Pkgs.cargo-prove
          # sp1Pkgs.sp1-rust-toolchain  # included via cargo-prove, only needed if you want rustc directly
        ];
      };
    };
}
```


### Building SP1 programs as Nix derivations

The overlay also provides `buildSp1Program` — a builder function (like `buildRustPackage`) that compiles SP1 guest programs to RISC-V ELF binaries as pure Nix derivations. No `cargo prove`, no network access at build time.

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sp1-nix.url = "github:vaporif/sp1.nix";
  };

  outputs = { nixpkgs, sp1-nix, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ sp1-nix.overlays.default ];
      };
    in {
      packages.${system}.my-program-elf = pkgs.buildSp1Program {
        pname = "my-program";       # Cargo package name of the guest program
        src = ./.;                   # Workspace root containing Cargo.lock
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
| `pname` | yes | — | Cargo package name of the program crate |
| `src` | yes | — | Source tree (must contain `Cargo.lock`) |
| `cargoLock` | yes | — | `{ lockFile = ./Cargo.lock; }` — dependencies are vendored automatically |
| `version` | no | `"0.1.0"` | Derivation version |
| `target` | no | `"riscv64im-succinct-zkvm-elf"` | SP1 compilation target |

See [`test-app/flake.nix`](test-app/flake.nix) for a complete working example.

## Available commands

Once `cargo-prove` is in your environment, you can use all SP1 CLI utilities:

```bash
cargo prove build            # Build an SP1 program
cargo prove new <name>       # Create a new SP1 project
cargo prove build-toolchain  # Build the SP1 toolchain from source
cargo prove --help           # See all available commands
```

## How it works

`cargo-prove` normally requires rustup to dispatch between the host Rust toolchain and the SP1 cross-compiler. In Nix there is no rustup, so this flake bundles a rustc wrapper that:

- Intercepts `--print sysroot` to return a combined sysroot containing SP1's riscv target libs
- Routes `riscv64im-succinct-zkvm-elf` compilations to the SP1 toolchain's rustc
- Falls through to the next `rustc` on PATH for host/build dependencies (proc-macros, build scripts, etc.)

This means **your** Rust toolchain (fenix, oxalica, nightly, etc.) is used for host compilation — `cargo-prove` only takes over for the SP1 guest target. No extra configuration needed.

### `buildSp1Program`

Under the hood, `buildSp1Program` replicates what `cargo prove build` does, but as a pure Nix derivation:

1. Dependencies are vendored from `Cargo.lock` via `importCargoLock` (registry-only — no manual hashes needed)
2. The SP1 sysroot's `rustc` is used for cross-compilation to the RISC-V target
3. `CARGO_ENCODED_RUSTFLAGS` passes the same flags SP1 uses internally (`lower-atomic`, `panic=abort`, `getrandom_backend="custom"`, LLVM scheduling hints)
4. The output is a statically-linked RISC-V ELF ready for use with `include_elf!` in your host program
