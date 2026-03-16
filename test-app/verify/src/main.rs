use sp1_sdk::{
    blocking::{Prover, ProverClient},
    SP1Stdin,
};

fn main() {
    let path = std::env::args()
        .nth(1)
        .expect("usage: verify-elf <elf-path>");
    let elf_bytes = std::fs::read(&path).expect("failed to read ELF");

    let client = ProverClient::from_env();
    let mut stdin = SP1Stdin::new();
    stdin.write(&20u32);

    let (output, report) = client
        .execute(elf_bytes.into(), stdin)
        .run()
        .expect("execution failed");
    assert!(
        !output.as_slice().is_empty(),
        "execution produced no output"
    );
    println!("ELF verified: {} cycles", report.total_instruction_count());
}
