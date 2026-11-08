# Commit messages

Follow conventional commits:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Guidelines

- Types: `feat`, `fix`, `build`, `chore`, `ci`, `docs`, `style`, `test`, `perf`, `refactor`.
- Keep the title under 60 characters.
- Lowercase only, in the title and the body.
- Present tense in the title and the body.
- Many changes: more body bullets. Few changes: terse or no body.
- Never add `Co-Authored-By` or any AI attribution.
- Never commit unless explicitly told to. Finish the work, report it, leave it in
  the working tree. Approval of the work is not approval to commit.

## Body and footers

- Detailed body: pass multiple `-m` flags to `git commit`.
- Resolved issues go in the footer: `resolves #12, resolves #34`.

# Comments

Default to none. Code says what it does; a comment exists only to carry what
the code cannot.

## The test

Delete the comment. If nothing is lost, it should not exist. If the answer is
"but it explains the code", delete it — that is what the code is for.

## A comment is earned only for

- **A rejected alternative**: why this way and not the obvious one.
- **An external constraint**: upstream bug, api quirk, protocol or spec
  requirement, hardware behaviour. Name the source — version, link, or ticket.
- **A non-obvious consequence**: ordering that matters, a lock the caller must
  hold, a side effect outside this file.
- **A deliberate shortcut**: name the ceiling and the upgrade path.

## Never

- Restating the line, the signature, or the name above it.
- Section headers inside a function (`// setup`, `// main logic`) — that is a
  function asking to be split.
- Narrating the change (`// added`, `// now handles`, `// new`, `// updated`).
  The commit is the changelog, the code is not.
- Docstrings that retype the parameters and add nothing.
- `todo` with no owner and no condition for doing it.

## Shape

- Assume a reader who knows the language and can read code, but was not there
  when the decision was made. Write for that gap only.
- If a function needs more than one comment to be understood, fix the function —
  split it or rename it. Do not narrate it.
- Write only what you would say out loud in code review. Nothing else.
