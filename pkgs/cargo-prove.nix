{
  rustPlatform,
  protobuf,
  makeWrapper,
  sp1-src,
  sp1-sysroot,
  cargoLockOutputHashes ? {},
}:
rustPlatform.buildRustPackage rec {
  pname = "cargo-prove";
  version = (builtins.fromTOML (builtins.readFile "${src}/Cargo.toml")).workspace.package.version;
  src = sp1-src;
  buildAndTestSubdir = "crates/cli";
  doCheck = false;
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
      --prefix PATH : ${sp1-sysroot}/bin
  '';
}
