use alloy_sol_types::SolType;
use fibonacci_lib::PublicValuesStruct;
use sp1_sdk::{
    blocking::{ProveRequest, Prover, ProverClient},
    ProvingKey, SP1Stdin,
};

fn main() {
    sp1_sdk::utils::setup_logger();

    let path = std::env::args()
        .nth(1)
        .expect("usage: verify-elf <elf-path> [--prove]");
    let prove = std::env::args().any(|a| a == "--prove");
    let elf_bytes = std::fs::read(&path).expect("failed to read ELF");

    let client = ProverClient::from_env();
    let mut stdin = SP1Stdin::new();
    stdin.write(&2u32);

    // Execute and verify output values
    let (output, report) = client
        .execute(elf_bytes.clone().into(), stdin)
        .run()
        .expect("execution failed");

    let decoded =
        PublicValuesStruct::abi_decode(output.as_slice()).expect("failed to decode output");
    let (expected_a, expected_b) = fibonacci_lib::fibonacci(2);
    assert_eq!(decoded.n, 2);
    assert_eq!(decoded.a, expected_a);
    assert_eq!(decoded.b, expected_b);
    println!(
        "Output verified: fib(20) = ({}, {}), cycles: {}",
        expected_a,
        expected_b,
        report.total_instruction_count()
    );

    if prove {
        let mut stdin = SP1Stdin::new();
        stdin.write(&2u32);

        let pk = client.setup(elf_bytes.into()).expect("failed to setup elf");
        let proof = client
            .prove(&pk, stdin)
            .run()
            .expect("failed to generate proof");
        println!("Proof generated!");

        client
            .verify(&proof, pk.verifying_key(), None)
            .expect("failed to verify proof");
        println!("Proof verified!");
    }
}
