# ai-sync

Link a git repository of AI directives into a project as a symlink, instead of
copying it. `git` is the only dependency.

    curl -fsSL https://raw.githubusercontent.com/remiville/ai-sync/main/install.sh | sh
    curl -fsSL .../install.sh | sh -s -- --rules git@github.com:you/your-rules.git

The first form expects the project to carry an `ai-sync.local.json` already.
The second seeds one, and is the only case in which anything here writes it —
`ai-sync.sh` itself only ever reads it.

    ai-sync.sh [-C DIR] [--update]

Clones each repository the config names into `~/.config/ai-sync/repos/`,
symlinks `<repo>/.claude/rules/<entry>` into `<project>/.claude/rules/<entry>`,
and adds the link and the config to the repository's `info/exclude`. `--update`
pulls each clone first. Running it twice changes nothing.

    sh test.sh

The suite runs against `file://` repositories in temporary directories: no
network, and no account anywhere.
