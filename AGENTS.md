# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix`: Entry point. Uses Blueprint to map folders to flake outputs.
- `hosts/<name>/`: NixOS machines → `nixosConfigurations.<name>` (e.g., `p1`).
- `modules/nixos/*.nix`: NixOS modules → `nixosModules.<module>`.
- `modules/home/*`: Home Manager modules → `homeModules.<module>`.
- `packages/<pkg>/default.nix`: Packages → `packages.<system>.<pkg>` (e.g., `docs`, `myvim`).
- `docs/` + `mkdocs.yml`: Site content built via `mkdocs-numtide` (packaged under `packages.<system>.docs`).
- `.envrc` + `devshell.nix`: Direnv + devshell with `nixos-rebuild`, `sops`, formatter.

## Build, Test, and Development Commands
- `direnv allow && nix develop`: Enter dev shell.
- `nix fmt`: Format Nix/shell/markdown via treefmt.
- `nix flake check`: Run repository checks (evaluation, formatting, etc.).
- `nixos-rebuild --flake .#<host> switch`: Rebuild a host (wrapper adds `--sudo`).
- `nix build .#packages.<system>.<pkg>`: Build a package (e.g., `docs`).
- `nix build .#checks.<system>.<name>`: Run a specific check quickly.

## Coding Style & Naming Conventions
- Nix: 2‑space indent; one option per line; keep modules small and focused.
- Filenames: `default.nix` for modules/packages; kebab/snake as seen in repo.
- Formatting: Always run `nix fmt` before pushing; CI enforces treefmt.

## Testing Guidelines
- Prefer fast checks locally: `nix build .#checks.<system>.pkgs-formatter` and `nixos-rebuild build --flake .#<host>`.
- Build packages you touch: `nix build .#packages.<system>.<pkg>`.
- Full sweep: `nix flake check` prior to PRs.

## Commit & Pull Request Guidelines
- Commits: Imperative, concise. Optional scope, e.g., `fix(no1): ...`, `flake update`.
- PRs: Include summary, impacted hosts/modules/packages, and sample commands used to verify (e.g., `nixos-rebuild build`, `nix flake check`). Link related issues.
- Keep diffs minimal; run `nix fmt`; avoid unrelated refactors.

## Security & Configuration Tips
- Secrets: Store per‑host in `hosts/<name>/secrets.yaml` managed by SOPS; do not commit plaintext. See `.sops.yaml`. Use `sops` and `ssh-to-age` from the dev shell.
- Rebuilds use sudo via the provided wrapper; ensure you have appropriate privileges on target hosts.

