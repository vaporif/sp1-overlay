{
  pkgs,
  versionConfig,
}: let
  sp1-src = pkgs.fetchFromGitHub {
    inherit (versionConfig.sp1-src) owner repo rev sha256;
  };

  succinct-rust = pkgs.fetchFromGitHub {
    inherit (versionConfig.succinct-rust) owner repo rev sha256;
  };
  backtrace-rs =
    if versionConfig.backtrace-rs != null
    then
      pkgs.fetchFromGitHub {
        inherit (versionConfig.backtrace-rs) owner repo rev sha256;
      }
    else null;

  hostTriple =
    {
      x86_64-linux = "x86_64-unknown-linux-gnu";
      aarch64-linux = "aarch64-unknown-linux-gnu";
      x86_64-darwin = "x86_64-apple-darwin";
      aarch64-darwin = "aarch64-apple-darwin";
    }
    .${
      pkgs.stdenv.hostPlatform.system
    }
      or (throw "Unsupported system: ${pkgs.stdenv.hostPlatform.system}");

  sp1-rust-toolchain = pkgs.callPackage ../pkgs/sp1-rust-toolchain.nix {
    version = versionConfig.toolchain-version;
    platform-hashes = versionConfig.toolchain-hashes;
  };

  sp1-host-std = pkgs.callPackage ../pkgs/sp1-host-std.nix {
    inherit sp1-rust-toolchain succinct-rust backtrace-rs hostTriple;
    edition = versionConfig.edition;
  };

  sp1-sysroot = pkgs.callPackage ../pkgs/sp1-sysroot.nix {
    inherit sp1-rust-toolchain sp1-host-std hostTriple;
    target = versionConfig.target;
  };

  sp1-core-runner-binary =
    if !(versionConfig.skip-prebuilt-runner or false)
    then
      pkgs.callPackage ../pkgs/sp1-core-runner-binary.nix {
        inherit sp1-src;
        cargoLockOutputHashes = versionConfig.cargo-lock-output-hashes;
      }
    else null;

  cargo-prove = pkgs.callPackage ../pkgs/cargo-prove.nix {
    inherit sp1-sysroot sp1-src sp1-core-runner-binary;
    sp1-rev = versionConfig.sp1-src.rev;
    sp1-timestamp = "";
    cargoLockOutputHashes = versionConfig.cargo-lock-output-hashes;
    wrapperEnv = versionConfig.cargo-prove-wrapper-env or {};
  };

  buildSp1Program = pkgs.callPackage ../pkgs/buildSp1Program.nix {
    inherit sp1-sysroot;
    defaultTarget = versionConfig.target;
    defaultBuildFlags = versionConfig.build-flags;
    extraBuildEnv = versionConfig.extra-build-env;
  };
in {
  inherit sp1-rust-toolchain sp1-host-std sp1-sysroot cargo-prove buildSp1Program;
}
