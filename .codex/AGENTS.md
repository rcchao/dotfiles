# Global Codex Rules

## Scope of changes

Only modify code that is directly relevant to the current task. Specifically:

- Do **not** fix pre-existing linting or type errors in code you didn't write for this task
- Do **not** remove or uncomment commented-out code unless the task requires it
- Do **not** reformat, rename, or refactor code that exists outside the scope of the task
- If you notice something worth fixing that is out of scope, mention it but do not touch it

## Shell command output formatting

When showing a shell command the user might run, format it for clean copy-paste:

- Put each command in its own fenced code block (```` ```bash ````), not inline backticks or prose
- One command per block — don't pack multiple unrelated commands into a single block
- No leading indentation, no leading `$` prompt character, no trailing comments on the same line
- No line continuations (`\`) unless the command truly requires multi-line; prefer a single long line
- If env vars are needed, put them on the same line as the command (`FOO=bar mycmd`) so a single copy captures them

## Sendable text (messages, emails, PR descriptions, etc.)

When asked to draft text the user will send somewhere:

- Display the text in the terminal so the user can read and review it
- Also pipe it to `pbcopy` so it's on the clipboard ready to paste without reformatting

## External action bans

These are personal hard limits. Do not perform these actions, even if a tool is available or a plugin/connector is installed:

- Do **not** run `git push` or otherwise push commits/branches/tags to any remote.
- Do **not** post, submit, publish, or create comments/reviews on pull requests. Draft text locally for the user instead.
- Do **not** send Slack messages, replies, drafts, canvases, reactions, or other Slack writes. Read/search Slack only when asked.
- Do **not** create, update, assign, transition, comment on, or otherwise edit Linear tickets. Read/search Linear only when asked.

When the user asks for one of these actions, prepare the content or command for the user to perform manually instead of executing it.

