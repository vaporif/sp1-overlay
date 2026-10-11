{
  rustPlatform,
  protobuf,
  sp1-src,
  subdir,
  cargoLockOutputHashes ? {},
}:
rustPlatform.buildRustPackage rec {
  pname = "sp1-core-executor-runner-binary";
  version = (fromTOML (builtins.readFile "${src}/Cargo.toml")).workspace.package.version;
  src = sp1-src;
  buildAndTestSubdir = subdir;
  doCheck = false;
  nativeBuildInputs = [
    protobuf
  ];
  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = cargoLockOutputHashes;
  };
}
