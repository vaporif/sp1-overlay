# Upstream Reference: Where Version Config Comes From

This document maps each field in [`lib/versions.nix`](../lib/versions.nix) to its authoritative source in the SP1 codebase, so you can verify correctness when adding or updating versions.

## Quick reference

| Field | Source file (in `succinctlabs/sp1` at the version tag) |
|-------|-------------------------------------------------------|
| `toolchain-version` | `crates/cli/src/lib.rs` → `LATEST_SUPPORTED_TOOLCHAIN_VERSION_TAG` |
| `target` | `crates/build/src/lib.rs` → `DEFAULT_TARGET` (v6) or `BUILD_TARGET` (v5) |
| `build-flags` | `crates/build/src/command/utils.rs` → `get_rust_compiler_flags()` |
| `succinct-rust.rev` | Resolve the toolchain tag on `succinctlabs/rust` to a commit SHA |
| `backtrace-rs.rev` | Git submodule at `library/backtrace` in `succinctlabs/rust` |
| `toolchain-hashes` | SHA256 of release artifacts at `succinctlabs/rust/releases` |
| `skip-prebuilt-runner` | Set `true` for versions without `crates/core/runner/binary/` (pre-v6.1.0) |
| `sp1-src.sha256` | Nix-computed hash of the source tarball (self-verifying) |

## Detailed walkthrough

### toolchain-version

SP1's CLI defines which Rust toolchain to use:

```
// crates/cli/src/lib.rs
pub const LATEST_SUPPORTED_TOOLCHAIN_VERSION_TAG: &str = "succinct-1.93.0-64bit";
```

Strip the `succinct-` prefix to get the value for `versions.nix`. For v6.1.0 this is `"1.93.0-64bit"`, for v5.2.4 it's `"1.91.1"`.

### target

The RISC-V target triple is defined in the build crate:

```
// crates/build/src/lib.rs  (v6)
pub const DEFAULT_TARGET: &str = "riscv64im-succinct-zkvm-elf";

// crates/build/src/lib.rs  (v5)
const BUILD_TARGET: &str = "riscv32im-succinct-zkvm-elf";
```

v6 moved from 32-bit to 64-bit RISC-V.

### build-flags

The compiler flags are assembled in `get_rust_compiler_flags()`:

```
// crates/build/src/command/utils.rs
let rust_flags = [
    "-C", atomic_lower_pass,
    "-C", &format!("link-arg=--image-base={}", sp1_primitives::consts::STACK_TOP),
    "-C", "panic=abort",
    "--cfg", "getrandom_backend=\"custom\"",
    "-C", "llvm-args=-misched-prera-direction=bottomup",
    "-C", "llvm-args=-misched-postra-direction=bottomup",
];
```

**Important details:**

- `atomic_lower_pass` is `"passes=lower-atomic"` for rustc > 1.81.0, `"passes=loweratomic"` for older versions. All currently supported versions use the hyphenated form.
- **v6** uses `link-arg=--image-base=<STACK_TOP>` where `STACK_TOP` is defined in `crates/primitives/src/consts.rs` (currently `0x78000000`). This sets the ELF image base so the stack grows downward from this address without colliding with heap/static data.
- **v5** uses two hardcoded link args instead: `link-arg=-Ttext=0x00201000` and `link-arg=--image-base=0x00200800`.

In `versions.nix`, flags are stored as a flat array where each `-C`/`--cfg` and its argument are separate elements. These get joined with `\x1f` (Unit Separator) into `CARGO_ENCODED_RUSTFLAGS` at build time.

### succinct-rust.rev

The Rust fork commit corresponds to the toolchain release tag. To find it:

```bash
# The tag name matches the toolchain version
gh api repos/succinctlabs/rust/git/ref/tags/succinct-1.93.0-64bit --jq .object.sha
```

This gives you the commit SHA to put in `succinct-rust.rev`.

### backtrace-rs.rev

The `backtrace-rs` fork is pinned as a git submodule in the Succinct Rust fork at `library/backtrace`:

```bash
# Check the submodule pin for a given rust fork commit
gh api repos/succinctlabs/rust/contents/library/backtrace?ref=<rust-commit> --jq .sha
```

This is from `rust-lang/backtrace-rs` (not a Succinct fork).

### toolchain-hashes

Pre-built toolchain tarballs are published as GitHub releases on `succinctlabs/rust`. The download URL pattern is:

```
https://github.com/succinctlabs/rust/releases/download/succinct-{version}/rust-toolchain-{triple}.tar.gz
```

Where `{triple}` is one of:
- `x86_64-unknown-linux-gnu`
- `aarch64-unknown-linux-gnu`
- `x86_64-apple-darwin`
- `aarch64-apple-darwin`

To get the Nix hash for a new release:

```bash
nix hash to-sri --type sha256 $(nix-prefetch-url --unpack \
  "https://github.com/succinctlabs/rust/releases/download/succinct-1.93.0-64bit/rust-toolchain-aarch64-apple-darwin.tar.gz")
```

### sp1-src and succinct-rust SHA256 hashes

These are Nix content hashes of the fetched source. They are **self-verifying** — if wrong, the build fails. To compute them for a new version:

```bash
nix-prefetch-url --unpack "https://github.com/succinctlabs/sp1/archive/refs/tags/v6.1.0.tar.gz"
```

Or set `sha256 = "";` and let Nix report the correct hash on first build attempt.

### extra-build-env

Version-specific environment variables needed during compilation:

- **v5**: `CFLAGS_riscv32im_succinct_zkvm_elf = "-D__ILP32__"` — required because the 32-bit target needs ILP32 ABI flag for C code compilation.
- **v6**: empty — the 64-bit target doesn't need extra C flags.

### edition

The Rust edition used for building the host standard library. Check the `edition` field in `library/std/Cargo.toml` of the Succinct Rust fork at the relevant commit.

### skip-prebuilt-runner

Starting with v6.1.0, SP1's `crates/core/runner` has a `build.rs` that shells out to `cargo build` for an internal helper binary. The nested build breaks in the Nix sandbox because the output path doesn't match what the script expects. By default, the overlay builds the runner binary in its own derivation and feeds it back through `SP1_CORE_RUNNER_OVERRIDE_BINARY` (an escape hatch the upstream build.rs already supports).

Set `skip-prebuilt-runner = true` for older versions that don't have `crates/core/runner/binary/Cargo.toml`. When omitted, the prebuilt runner is enabled.

## Adding a new SP1 version

1. Find the SP1 release tag (e.g., `v7.0.0`)
2. Check `crates/cli/src/lib.rs` for the toolchain version tag
3. Resolve that tag to a commit on `succinctlabs/rust`
4. Check the `library/backtrace` submodule pin in that commit
5. Extract build flags from `crates/build/src/command/utils.rs`
6. Extract the target from `crates/build/src/lib.rs`
7. Compute toolchain hashes for all 4 platforms
8. Check if `crates/core/runner/binary/Cargo.toml` exists — if not, set `skip-prebuilt-runner = true`
9. Add the entry to `lib/versions.nix` using an existing version as template
10. Run CI to verify everything builds and proofs verify
