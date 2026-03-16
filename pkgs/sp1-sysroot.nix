{
  runCommand,
  runtimeShell,
  sp1-rust-toolchain,
  sp1-host-std,
  hostTriple,
  target,
}:
# Self-referencing sysroot: bin/rustc uses $out as sysroot so that
# `rustc --print sysroot` returns a path that contains bin/rustc
runCommand "sp1-sysroot" {} ''
  mkdir -p $out/lib/rustlib $out/bin

  # Host target libs (built from source with valid .rmeta)
  ln -s ${sp1-host-std}/lib/rustlib/${hostTriple} $out/lib/rustlib/${hostTriple}

  # RISC-V target libs from SP1 toolchain
  ln -s ${sp1-rust-toolchain}/lib/rustlib/${target} $out/lib/rustlib/${target}

  # Rustc wrapper that uses this sysroot
  cat > $out/bin/rustc << SCRIPT
  #!${runtimeShell}
  exec env -u RUSTUP_TOOLCHAIN ${sp1-rust-toolchain}/bin/rustc --sysroot $out "\$@"
  SCRIPT
  chmod +x $out/bin/rustc
''
