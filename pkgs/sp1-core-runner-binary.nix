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
      nativeBuildInputs = [
        protobuf
      ];
    })
