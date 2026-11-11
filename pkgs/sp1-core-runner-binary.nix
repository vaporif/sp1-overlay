{
  rustPlatform,
  protobuf,
  sp1-src,
  subdir,
  cargoLockOutputHashes ? {},
  cargoHash ? null,
}: let
  # importCargoLock can't vendor a crate that appears as both a registry and a git
  # source with the same name-version (SP1 v6.9.0 patches); fetchCargoVendor can.
  vendorArgs =
    if cargoHash != null
    then {inherit cargoHash;}
    else {
      cargoLock = {
        lockFile = "${sp1-src}/Cargo.lock";
        outputHashes = cargoLockOutputHashes;
      };
    };
in
  rustPlatform.buildRustPackage (vendorArgs
    // rec {
      pname = "sp1-core-executor-runner-binary";
      version = (fromTOML (builtins.readFile "${src}/Cargo.toml")).workspace.package.version;
      src = sp1-src;
      buildAndTestSubdir = subdir;
      doCheck = false;
      # nixpkgs' cargo setup hook (cargoUseSystemLibs) forces -sys crates to use
      # system libraries (e.g. LIBGIT2_NO_VENDOR=1). SP1's pinned crates need
      # versions nixpkgs doesn't ship (libgit2-sys 0.17 wants libgit2 1.8), so
      # keep building their bundled copies. Plain env vars would be overwritten.
      dontCargoUseSystemLibs = true;
      nativeBuildInputs = [
        protobuf
      ];
    })
