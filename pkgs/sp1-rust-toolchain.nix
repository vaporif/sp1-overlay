{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  xz,
  zlib,
  ncurses,
  gcc-unwrapped,
  version,
  platform-hashes,
}: let
  triple =
    {
      x86_64-linux = "x86_64-unknown-linux-gnu";
      aarch64-linux = "aarch64-unknown-linux-gnu";
      x86_64-darwin = "x86_64-apple-darwin";
      aarch64-darwin = "aarch64-apple-darwin";
    }
    .${
      stdenv.hostPlatform.system
    }
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  sha256 = platform-hashes.${stdenv.hostPlatform.system}
    or (throw "No hash for system: ${stdenv.hostPlatform.system}");
in
  stdenv.mkDerivation {
    pname = "sp1-rust-toolchain";
    inherit version;

    src = fetchurl {
      url = "https://github.com/succinctlabs/rust/releases/download/succinct-${version}/rust-toolchain-${triple}.tar.gz";
      inherit sha256;
    };

    nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
      autoPatchelfHook
    ];

    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
      xz
      zlib
      ncurses
      gcc-unwrapped
      stdenv.cc.cc.lib
    ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib
      cp -r bin/* $out/bin/
      cp -r lib/* $out/lib/
      runHook postInstall
    '';

    meta = with lib; {
      description = "Succinct Labs Rust toolchain";
      homepage = "https://github.com/succinctlabs/rust";
      license = licenses.mit;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    };
  }
