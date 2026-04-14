{
  rustPlatform,
  protobuf,
  sp1-src,
  cargoLockOutputHashes ? {},
}:
rustPlatform.buildRustPackage rec {
  pname = "sp1-core-executor-runner-binary";
  version = (fromTOML (builtins.readFile "${src}/Cargo.toml")).workspace.package.version;
  src = sp1-src;
  buildAndTestSubdir = "crates/core/runner/binary";
  doCheck = false;
  nativeBuildInputs = [
    protobuf
  ];
  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = cargoLockOutputHashes;
  };
}
