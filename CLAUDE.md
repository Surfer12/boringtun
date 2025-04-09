# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- Build: `cargo build`
- Run: `cargo run`
- Test all: `cargo test`
- Test single: `cargo test <test_name>`
- Integration tests: `cargo test <test_name> -- --ignored`
- Benchmarks: `cargo bench`
- Lint: `cargo clippy`
- Format: `cargo fmt`

## Code Style Guidelines
- **Formatting**: Use `cargo fmt` for consistent code formatting
- **Linting**: Use `cargo clippy` to detect common Rust code issues
- **Imports**: Group imports by standard lib, external crates, then internal modules
- **Naming**: Use snake_case for variables/functions, CamelCase for types/traits
- **Types**: Use strong typing; prefer Option<T> over nullable types
- **Error Handling**: Use Result<T, E> for functions that can fail; avoid unwrap()/expect() in production code
- **Documentation**: Document public APIs with rustdoc /// comments
- **Constants**: Use ALL_CAPS for constants and static variables