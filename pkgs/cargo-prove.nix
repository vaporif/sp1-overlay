{
  rustPlatform,
  protobuf,
  makeWrapper,
  sp1-src,
  sp1-sysroot,
  sp1-rev,
  sp1-timestamp,
  cargoLockOutputHashes ? {},
}:
rustPlatform.buildRustPackage rec {
  pname = "cargo-prove";
  version = (fromTOML (builtins.readFile "${src}/Cargo.toml")).workspace.package.version;
  src = sp1-src;
  buildAndTestSubdir = "crates/cli";
  doCheck = false;
  env = {
    VERGEN_GIT_SHA = sp1-rev;
    VERGEN_BUILD_TIMESTAMP = sp1-timestamp;
  };
  nativeBuildInputs = [
    protobuf
    makeWrapper
  ];
  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = cargoLockOutputHashes;
  };
  postFixup = ''
    wrapProgram $out/bin/cargo-prove \
      --prefix PATH : ${sp1-sysroot}/bin \
      --set CARGO_PROFILE_RELEASE_TRIM_PATHS false
  '';
}
