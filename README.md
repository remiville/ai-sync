# ai-sync

Keep a project's AI directives in step with a git repository of them, from one
shared clone. `git` is the only dependency.

    curl -fsSL https://raw.githubusercontent.com/remiville/ai-sync/main/install.sh | sh
    curl -fsSL .../install.sh | sh -s -- --rules git@github.com:you/your-rules.git

The first form expects the project to carry an `ai-sync.local.json` already.
The second seeds one, and is the only case in which anything here writes it —
`ai-sync.sh` itself only ever reads it.

    ai-sync.sh [-C DIR] [--update] [--force]

Clones each repository the config names into `~/.config/ai-sync/repos/`, copies
`<repo>/.claude/rules/<entry>` to `<project>/.claude/rules/<entry>`, and adds
the copy and the config to the repository's `info/exclude`. `--update` pulls
each clone first, and is how a changed directive reaches a project.

A refresh replaces the copy whole rather than writing over it, so a file
deleted upstream disappears downstream. The copy is therefore disposable and
never the place to edit a directive — change it in the rules repository.

If the destination already exists, who decides depends on who is asking:
`--update` and `--force` replace it, a terminal is asked, and a caller with
neither refuses rather than guess. Tools driving this script pass `--force` for
the path they own; `--update` needs nothing added.

    sh test.sh

The suite runs against `file://` repositories in temporary directories: no
network, and no account anywhere.
