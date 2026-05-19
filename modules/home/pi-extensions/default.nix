{ ... }:
{
  home.file.".pi/agent/AGENTS.md".text = ''
    # Local workflow

    - For GitHub repositories, prefer retrieving them locally with `h` before using HTTP fetches.
    - In interactive shells, `h owner/repo` jumps to an existing checkout or clones it under `$HOME/go/src/github.com/owner/repo`.
    - In non-interactive shells, use `repo=$(command h --resolve "$HOME/go/src" owner/repo)` or `repo=$(command h --resolve "$HOME/go/src" https://github.com/owner/repo)`, then inspect files from `$repo`.
    - `workmux` is available for parallel git-worktree/tmux workflows. Use `/worktree` to dispatch implementation tasks into background worktree agents; the dispatcher should write prompt files and run `workmux add`, not inspect or implement the task itself.
  '';

  # pi auto-discovers *.ts and subdir/index.ts from ~/.pi/agent/extensions/.
  # recursive=true symlinks individual files, leaving the directory writable so
  # ad-hoc extensions can still be dropped alongside without home-manager
  # complaining.
  home.file.".pi/agent/extensions" = {
    source = ./files;
    recursive = true;
  };

  home.file.".pi/agent/prompts" = {
    source = ./prompts;
    recursive = true;
  };

  home.file.".pi/agent/skills" = {
    source = ./skills;
    recursive = true;
  };
}
