fn main() {
    if let Err(error) = wb_runtime::cli::run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
