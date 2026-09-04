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
