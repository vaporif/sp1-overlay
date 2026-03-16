{
  stdenv,
  cargo,
  rustPlatform,
  sp1-sysroot,
  defaultTarget,
  defaultBuildFlags,
  extraBuildEnv ? {},
}: {
  pname,
  src,
  cargoLock,
  version ? "0.1.0",
  target ? defaultTarget,
}: let
  flagsList = defaultBuildFlags;
in
  stdenv.mkDerivation ({
      inherit pname version src;

      nativeBuildInputs = [
        cargo
        rustPlatform.cargoSetupHook
      ];

      cargoDeps = rustPlatform.importCargoLock cargoLock;

      dontStrip = true;

      buildPhase = ''
        runHook preBuild

        # Encode flags with Unit Separator (0x1F) as required by CARGO_ENCODED_RUSTFLAGS
        SEP=$'\x1f'
        FLAGS=""
        ${builtins.concatStringsSep "\n" (builtins.genList (
          i: let
            flag = builtins.elemAt flagsList i;
            escapedFlag = builtins.replaceStrings [''"''] [''\"''] flag;
          in ''FLAGS="''${FLAGS:+$FLAGS$SEP}${escapedFlag}"''
        ) (builtins.length flagsList))}

        RUSTC=${sp1-sysroot}/bin/rustc \
        CARGO_ENCODED_RUSTFLAGS="$FLAGS" \
        RUSTC_BOOTSTRAP=1 \
        RUSTUP_TOOLCHAIN="" \
        cargo build -p ${pname} --target ${target} --release

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp target/${target}/release/${pname} $out/
        runHook postInstall
      '';
    }
    // extraBuildEnv)
