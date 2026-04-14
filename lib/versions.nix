{
  default-version = "v6.1.0";

  "v6.1.0" = {
    sp1-src = {
      owner = "succinctlabs";
      repo = "sp1";
      rev = "v6.1.0";
      sha256 = "sha256-V59lA3VrPxVfeqbnjnofUPGsKViiVFsTByx1ng7CZpg=";
    };
    succinct-rust = {
      owner = "succinctlabs";
      repo = "rust";
      rev = "e4545c06c345d76aefe89d59ebd86b926f9f1279";
      sha256 = "sha256-DQZmuZlDMetowQjUo0AC6f0IltgBbWLia0r9JyN5kiI=";
    };
    backtrace-rs = {
      owner = "rust-lang";
      repo = "backtrace-rs";
      rev = "b65ab935fb2e0d59dba8966ffca09c9cc5a5f57c";
      sha256 = "sha256-fG907gkqVC+7V4STVEzPIPGJU+FJX9m/kteb3hmo1ec=";
    };
    toolchain-version = "1.93.0-64bit";
    target = "riscv64im-succinct-zkvm-elf";
    edition = "2024";
    toolchain-hashes = {
      x86_64-linux = "sha256-meaN2GTdfulogzM0a0KEUscF2CoRCY5RFGOJQX4MgsY=";
      aarch64-linux = "sha256-AzmcLjFWHc79WP4fRnuO9E/Gk1MfEyZSBROzlhp6kmc=";
      x86_64-darwin = "sha256-TYCXpLpdJxK/pur0nPYo5ITkBywgkI7LWmoj4iap52A=";
      aarch64-darwin = "sha256-juTqDyfvv3Pd/oogOM7UwIAv3Pnh7hCTSXY7n0qAjPY=";
    };
    cargo-lock-output-hashes = {};
    build-flags = [
      "-C"
      "passes=lower-atomic"
      "-C"
      "link-arg=--image-base=0x78000000"
      "-C"
      "panic=abort"
      "--cfg"
      "getrandom_backend=\"custom\""
      "-C"
      "llvm-args=-misched-prera-direction=bottomup"
      "-C"
      "llvm-args=-misched-postra-direction=bottomup"
    ];
    extra-build-env = {};
    prebuilt-runner = true;
  };

  "v5.2.4" = {
    sp1-src = {
      owner = "succinctlabs";
      repo = "sp1";
      rev = "v5.2.4";
      sha256 = "sha256-sCQOZmhuMETn08eYtIDO2Vckx/oBclmReoVYYNGEb38=";
    };
    succinct-rust = {
      owner = "succinctlabs";
      repo = "rust";
      rev = "0ea3299154194b51eae050236621798ab9a4fa66";
      sha256 = "sha256-v/mY2SlD3L5A3XUYOrGQi/APqpfVczl3wY5h0evpeqw=";
    };
    backtrace-rs = {
      owner = "rust-lang";
      repo = "backtrace-rs";
      rev = "b65ab935fb2e0d59dba8966ffca09c9cc5a5f57c";
      sha256 = "sha256-fG907gkqVC+7V4STVEzPIPGJU+FJX9m/kteb3hmo1ec=";
    };
    toolchain-version = "1.91.1";
    target = "riscv32im-succinct-zkvm-elf";
    edition = "2024";
    toolchain-hashes = {
      x86_64-linux = "sha256-n+L+4BkI/M8y6hg3N5zoNqJPPaw6gMok4zyHplmcNuw=";
      aarch64-linux = "sha256-pvsdzN9VUrMd1QJM8RqrIM8PyJRW4JxD4+CsaQ0NQTQ=";
      x86_64-darwin = "sha256-jsQ18AWBlIAkyBMpIesUSdQLLJ6k5imZ/AGW2F0ek5A=";
      aarch64-darwin = "sha256-GvU/SINTrSSi+bHXCvNot0IjHDkG8EiMbbn9xZWfhpo=";
    };
    cargo-lock-output-hashes = {};
    build-flags = [
      "-C"
      "passes=lower-atomic"
      "-C"
      "link-arg=-Ttext=0x00201000"
      "-C"
      "link-arg=--image-base=0x00200800"
      "-C"
      "panic=abort"
      "--cfg"
      "getrandom_backend=\"custom\""
      "-C"
      "llvm-args=-misched-prera-direction=bottomup"
      "-C"
      "llvm-args=-misched-postra-direction=bottomup"
    ];
    extra-build-env = {
      "CFLAGS_riscv32im_succinct_zkvm_elf" = "-D__ILP32__";
    };
    prebuilt-runner = false;
  };
}
