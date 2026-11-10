# schema

The Postgres schema for Zayden. It holds the `sqlx` migrations in
`migrations/`, immutable once applied, and embeds them in a small Rust crate so
every other repo can run them. Nothing in this repo depends on another Zayden
repo.

## Layout

| Path          | What it is                                                      |
| ------------- | --------------------------------------------------------------- |
| `src/lib.rs`  | the `schema` crate: exports `MIGRATOR` and `migrator()`         |
| `build.rs`    | reruns the build when `migrations/` changes                     |
| `migrations/` | the sqlx migrations, immutable once applied                     |
| `.sqlx/`      | offline query cache; committed, regenerated on any query change |
| `deny.toml`   | `cargo-deny` policy                                             |

## What the crate exports

| Item                | Use                                                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------------------ |
| `schema::MIGRATOR`  | static `Migrator` for `#[sqlx::test(migrator = "schema::MIGRATOR")]`                                   |
| `schema::migrator()` | runtime `Migrator` that tolerates versions already applied by a newer binary (`set_ignore_missing`) |

Migrations are embedded at compile time, so tests that use `MIGRATOR` need only
`DATABASE_URL`.

Other repos take the crate as a git dependency and track the default branch;
`Cargo.lock` pins the commit:

```toml
schema = { git = "https://github.com/zayden-bots/schema" }
```

## Migration rules

- Never edit a migration that has been applied anywhere. Add a new one.
- Add each change as a `<version>_<name>.up.sql` and `<version>_<name>.down.sql`
  pair, named like the existing files in `migrations/`.
- Number a migration when you write it; do not reserve numbers.
- Migrations must stay backward-compatible: an older binary may still be running
  against a newer schema.

## Commands

```bash
cargo fmt --check
cargo clippy --workspace --all-targets -- -D warnings
cargo build --workspace --all-targets
cargo test --workspace
cargo deny check
```

`--all-targets` defaults to _off_ and silently skips tests, benches and
examples. Always pass it.

Clippy never codegens or links, so it reports green while the build is broken.
Only a real build exercises linking.

## Database

Mutating `sqlx` commands run only against a throwaway database:

```bash
docker run --rm -d --name zayden-prepare -p 55432:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=zayden_prepare postgres:18-alpine
export DATABASE_URL="postgres://postgres:postgres@localhost:55432/zayden_prepare"
sqlx migrate run
```

**Never mutate the live database** (the `DATABASE_URL` in a `.env`) without
explicit confirmation. Read-only queries are fine.

`.sqlx/` must be committed: CI sets `SQLX_OFFLINE=true` for most jobs, and
dependents check their queries against the `.sqlx/` inside this checkout.
Regenerate it against an **empty, freshly-migrated** database, because `LEFT
JOIN` nullability inference is plan-sensitive:

```bash
cargo sqlx prepare -- --all-targets
```

If prepare fails, `git restore .sqlx`.

## CI

`.github/workflows/ci.yml` runs these jobs in parallel:

| Job                       | Runs                                                                  |
| ------------------------- | --------------------------------------------------------------------- |
| `rustfmt`                 | `cargo fmt --all --check` on nightly                                  |
| `clippy (-D warnings)`    | `cargo clippy --workspace --all-targets --locked -- -D warnings`      |
| `test`                    | `cargo test --workspace --all-targets --locked` against Postgres 18   |
| `cargo-deny`              | `cargo-deny check`                                                    |
| `sqlx prepare --check`    | applies the migrations, then `cargo sqlx prepare --workspace --check` |

Everything except `rustfmt` builds on **stable**: `RUSTUP_TOOLCHAIN=stable`
outranks `rust-toolchain.toml`, and `RUSTFLAGS=""` clears nightly-only flags.
The workflow runs on pushes to `main`, `v*` tags, pull requests, manually and
weekly.

## Conventions

- Lints are declared once in the root `Cargo.toml` under `[workspace.lints]`;
  the crate opts in with `[lints] workspace = true`. The tables are kept
  identical across the Zayden repos by hand.
- Dependency versions are pinned once in `[workspace.dependencies]`; the crate
  says `foo.workspace = true` and may _add_ features, never restate a version.
- `unwrap`/`expect`/`panic`/`todo`/`dbg!` are **denied** outside tests;
  `clippy.toml` re-permits them under `#[cfg(test)]`.
- `rustfmt.toml` uses unstable options, so `rust-toolchain.toml` pins nightly
  for local work. Never write `cargo +nightly`; the prefix is redundant.
- `deny.toml` allows git sources from the orgs under `[sources.allow-org]`; any
  other git source needs an `allow-git` entry.
