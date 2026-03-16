use sp1_sdk::{ProverClient, SP1Stdin};

fn main() {
    let path = std::env::args()
        .nth(1)
        .expect("usage: verify-elf <elf-path>");
    let elf = std::fs::read(&path).expect("failed to read ELF");

    let client = ProverClient::new();
    let mut stdin = SP1Stdin::new();
    stdin.write(&20u32);

    let (output, report) = client.execute(&elf, stdin).run().expect("execution failed");
    assert!(!output.is_empty(), "execution produced no output");
    println!("ELF verified: {} cycles", report.total_instruction_count());
}
