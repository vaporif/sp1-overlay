{
  lib,
  stdenv,
  rustc,
  cargo,
  rustPlatform,
  writeShellScriptBin,
  sp1-rust-toolchain,
  succinct-rust,
  backtrace-rs,
  hostTriple,
  edition ? "2024",
}: let
  sp1Rustc = "${sp1-rust-toolchain}/bin/rustc";

  # Assemble the library source with backtrace submodule populated
  rustLibSrc = stdenv.mkDerivation {
    name = "succinct-rust-lib-src";
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      cp -r ${succinct-rust}/library/* $out/
      ${lib.optionalString (backtrace-rs != null) ''
        # Replace empty backtrace submodule stub with real source
        rm -rf $out/backtrace
        cp -r ${backtrace-rs} $out/backtrace
      ''}
    '';
  };

  # Phase 2 dispatcher: SP1 rustc for library crates + queries, nixpkgs rustc for build scripts
  phase2Dispatcher = writeShellScriptBin "rustc" ''
    is_query=false
    has_target=false
    for arg in "$@"; do
      case "$arg" in
        --print|--print=*) is_query=true ;;
        --target|--target=*) has_target=true ;;
      esac
    done

    if [ "$is_query" = "true" ] || [ "$has_target" = "true" ]; then
      exec ${sp1Rustc} --sysroot "$SP1_TEMP_SYSROOT" "$@"
    else
      exec ${rustc}/bin/rustc "$@"
    fi
  '';
in
  stdenv.mkDerivation {
    name = "sp1-host-std";

    # Use library source as src so cargoSetupHook can find Cargo.lock
    src = rustLibSrc;

    # Prevent stripping — it removes .rmeta sections from rlibs
    dontStrip = true;

    nativeBuildInputs = [
      cargo
      rustPlatform.cargoSetupHook
    ];

    # Vendor crate dependencies that cargo -Zbuild-std needs (libc, cfg-if, hashbrown, etc.)
    # These are pinned by library/Cargo.lock in the Succinct fork.
    cargoDeps = rustPlatform.importCargoLock {
      lockFile = "${succinct-rust}/library/Cargo.lock";
    };

    buildPhase = ''
      runHook preBuild

      export HOME=$TMPDIR

      # ── Phase 1: Direct rustc invocations for core, compiler_builtins, alloc ──
      echo "Phase 1: Building core, compiler_builtins, alloc..."

      mkdir -p phase1

      ${sp1Rustc} --edition ${edition} --crate-type rlib --crate-name core \
        -Z force-unstable-if-unmarked \
        --target ${hostTriple} -O \
        ${rustLibSrc}/core/src/lib.rs -o phase1/libcore.rlib

      ${sp1Rustc} --edition ${edition} --crate-type rlib --crate-name compiler_builtins \
        --extern core=phase1/libcore.rlib \
        --cfg 'feature="compiler-builtins"' --cfg 'feature="mem"' --cfg 'feature="rustc-dep-of-std"' \
        -Z force-unstable-if-unmarked \
        --target ${hostTriple} -O \
        ${rustLibSrc}/compiler-builtins/compiler-builtins/src/lib.rs -o phase1/libcompiler_builtins.rlib

      ${sp1Rustc} --edition ${edition} --crate-type rlib --crate-name alloc \
        -Z force-unstable-if-unmarked \
        --extern core=phase1/libcore.rlib \
        --extern compiler_builtins=phase1/libcompiler_builtins.rlib \
        --target ${hostTriple} -O \
        ${rustLibSrc}/alloc/src/lib.rs -o phase1/liballoc.rlib

      echo "Phase 1 complete."

      # ── Phase 2: cargo -Zbuild-std for full std ──
      echo "Phase 2: Building full std via cargo -Zbuild-std..."

      # Create temporary sysroot with phase 1 rlibs + rust-src
      mkdir -p temp-sysroot/lib/rustlib/${hostTriple}/lib
      mkdir -p temp-sysroot/lib/rustlib/src/rust
      cp phase1/*.rlib temp-sysroot/lib/rustlib/${hostTriple}/lib/
      ln -s ${rustLibSrc} temp-sysroot/lib/rustlib/src/rust/library

      export SP1_TEMP_SYSROOT=$PWD/temp-sysroot

      # Create dummy crate outside source tree to avoid workspace detection
      mkdir -p $TMPDIR/dummy/src
      echo 'fn main() {}' > $TMPDIR/dummy/src/main.rs
      cat > $TMPDIR/dummy/Cargo.toml << 'TOML'
      [package]
      name = "sp1-std-builder"
      version = "0.1.0"
      edition = "2021"
      TOML

      # Run cargo -Zbuild-std with the dispatcher
      RUSTC=${phase2Dispatcher}/bin/rustc \
      RUSTC_BOOTSTRAP=1 \
      cargo build \
        --manifest-path $TMPDIR/dummy/Cargo.toml \
        -Zbuild-std=std,panic_abort \
        --target ${hostTriple} \
        --release

      echo "Phase 2 complete."

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/rustlib/${hostTriple}/lib
      cp $TMPDIR/dummy/target/${hostTriple}/release/lib*.rlib $out/lib/rustlib/${hostTriple}/lib/ 2>/dev/null || true
      cp $TMPDIR/dummy/target/${hostTriple}/release/deps/lib*.rlib $out/lib/rustlib/${hostTriple}/lib/ 2>/dev/null || true

      if [ -z "$(ls $out/lib/rustlib/${hostTriple}/lib/*.rlib 2>/dev/null)" ]; then
        echo "ERROR: no rlibs produced — sp1-host-std build failed silently"
        exit 1
      fi

      runHook postInstall
    '';

    meta = with lib; {
      description = "Host standard library built from Succinct's Rust fork for SP1's rustc";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    };
  }
