---
name: commit-push
description: "Trigger: commit, push, commit y push, trabajo terminado, dale commit. Automate git add/commit/push with Spanish message generation."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming
  version: "1.0"
  delegate_only: true
---

> **ORCHESTRATOR GATE**: If you loaded this skill via the `skill()` tool, you are
> the ORCHESTRATOR — STOP. Do NOT execute these instructions inline. Delegate to
> the dedicated `commit-push-agent` sub-agent using your platform's delegation
> primitive (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for
> EXECUTORS only.

## Executor Override

If you ARE the `commit-push-agent` sub-agent (NOT the orchestrator), the gate
above does NOT apply to you. Continue with the phase work below. Do NOT delegate.
Do NOT call the Skill tool. You are the executor — execute.

## Purpose

You automate git commit and push for a Git working tree. You analyze local
changes, pull remote changes (`git fetch` + `git pull --rebase`), generate a
professional Spanish commit message (passive "Se + verbo" style), show a preview
with file list, ask for confirmation, and on approval execute
`git add -A && git commit -m "..." && git push`.

## Workflow

### Step 1: Fetch remote status

Run `git fetch origin` with a short timeout. If the fetch fails (network error,
auth failure), print a warning that remote could not be reached but continue
with local-only mode:

```
Advertencia: no se pudo contactar el remoto. Continuando en modo local.
```

### Step 2: Check if remote is ahead

```bash
git rev-list HEAD..origin/<branch> --count
```

If the count is greater than 0, rebase onto the remote:

```bash
git pull --rebase origin <branch>
```

- If the rebase succeeds, continue to Step 3.
- If the rebase produces conflicts, run `git rebase --abort` and print:
  ```
  ❌ El rebase generó conflictos. Resolvelos manualmente y volvé a intentar.
  ```
  Then exit with code 1.

### Step 3: Evaluate working tree

Run `git status --porcelain` and inspect:

| Porcelain output | Action |
|---|---|
| Empty (no output) | Print "No hay cambios para commitear." and exit |
| Contains `UU` or `DD` (unmerged paths) | Print "❌ Hay conflictos sin resolver. Resolvelos manualmente antes de commitear." and exit |
| Contains `REBASE_HEAD` or rebase in progress marker | Print "❌ Hay un rebase en progreso. Resolvelo o abortalo manualmente." and exit |
| Any other output (staged/unstaged/untracked) | Continue to Step 4 |

### Step 4: Get diff and branch info

Run these commands to gather context:

```bash
BRANCH=$(git branch --show-current)
STATS=$(git diff --stat HEAD)
DIFF=$(git diff HEAD)
# Ticket key extraction — adapt to your shell
# Linux/macOS: grep -oP '([A-Z]+-\d+)'
# PowerShell: Select-String -Pattern '([A-Z]+-\d+)' -AllMatches
# Nushell: ... | parse -r '([A-Z]+-\d+)'
# Use whatever works on your platform to extract the first match
TICKET=$(echo "$BRANCH" | grep -oP '([A-Z]+-\d+)' | head -1)
```

- `BRANCH`: current branch name.
- `STATS`: file change summary (files changed, insertions, deletions).
- `DIFF`: full diff content for message generation.
- `TICKET`: ticket key extracted from branch name (e.g., `REM-13927`). Empty if no match.

If `DIFF` is empty after the rebase (all changes were already upstream), print
"No hay cambios nuevos después del rebase." and exit.

If only untracked files exist (`??` entries only), note this and ask the user
in the preview whether they want to include them.

### Step 5: Generate commit message

Build the message using this mandatory pattern:

```
[TICKET_KEY: ]Se [verbo] [qué] [contexto/dónde][, propósito opcional]
```

**Verbs** (past tense passive — third person singular):
- `agregó` — added new functionality/files
- `incrementó` — increased limits/values
- `modificó` — changed existing behavior
- `implementó` — implemented a feature
- `eliminó` — removed code/files
- `actualizó` — updated dependencies/versions
- `mejoró` — improved performance/quality
- `corrigió` — fixed a bug
- `refactorizó` — refactored without behavior change

**Ticket prefix**: If `TICKET` is non-empty, prepend `"{TICKET}: "`. Otherwise
omit the prefix.

**Examples** (must follow this exact style):

```
REM-13927: Se incrementó el límite máximo de caracteres (`maxlength`) del campo de texto correspondiente al motivo adicional en la pantalla de detalle de verificación.
```

```
Se agregó la funcionalidad para recuperar y mapear los comentarios de las incidencias, permitiendo su procesamiento y utilización dentro de la aplicación.
```

Technical terms (file names, component names, variable names, library names)
SHOULD be wrapped in backticks.

### Step 6: Show preview and confirm

Display the preview in a clear box:

```
┌─────────────────────────────────────────┐
│  Mensaje del commit:                    │
│  {mensaje}                              │
│                                         │
│  Rama: {branch}                         │
│                                         │
│  Archivos:                              │
│    {file1} (modificado)                 │
│    {file2} (agregado)                   │
│    {file3} (eliminado)                  │
│    ...                                  │
│                                         │
│  ¿Confirmás el commit? [s/N]            │
└─────────────────────────────────────────┘
```

Wait for user input. Accept positive replies: `s`, `sí`, `si`, `yes`, `y`, `ok`,
`dale`, `confirmo`, `daly` (case-insensitive, trimmed).

- If positive → proceed to Step 7.
- If anything else (or empty) → print "Commit cancelado." and exit cleanly.

### Step 7: Execute add → commit → push

Run sequentially:

```bash
git add -A
```

If `git add` fails → print error and exit.

```bash
git commit -m "{mensaje}"
```

If `git commit` fails → print error and exit.

```bash
git push
```

**Success**: Print "✅ Push exitoso: {branch}" and exit.

**Failure — no upstream branch**: If the push fails with an upstream error
(message contains "no upstream" or "upstream" or "no such remote"), print:

```
⚠️  No hay upstream configurado para esta rama.
Ejecutá este comando manualmente para pushear:

  git push --set-upstream origin {branch}
```

Do NOT auto-set-upstream. The user must execute the command manually.

**Failure — other (network, auth, rejection)**: Print:

```
❌ Push falló. Los cambios están commiteados localmente.
Error: {error_message}
```

The commit is NOT reverted. Changes are safe locally.

## Commit Message Grammar (MANDATORY)

```
Pattern: [TICKET_KEY:] Se [verbo] [qué] [contexto/dónde], [propósito opcional]
```

| Component | Rule |
|---|---|
| `TICKET_KEY:` | Required if ticket found in branch name. Format: `REM-13927:` followed by space. |
| `Se` | Always capitalized `Se`, never lowercase. |
| `[verbo]` | One of the listed verbs in past tense passive (agregó, incrementó, etc.). |
| `[qué]` | What was changed — the direct object. |
| `[contexto/dónde]` | Where the change was made: file names, components, screens. Use backticks for technical terms. |
| `, propósito` | Optional — reason or purpose of the change, separated by comma. |

## Edge Cases

| # | Scenario | Detection | Handling |
|---|---|---|---|
| 1 | Clean working tree | `git status --porcelain` empty | Print "No hay cambios para commitear." and exit |
| 2 | Merge conflict in progress | `git status --porcelain` shows `UU` or `DD` | Print error message and exit |
| 3 | Rebase in progress | `.git/REBASE_HEAD` exists | Print "Rebase en progreso." and exit |
| 4 | No upstream branch | `git push` fails with upstream error | Print manual `git push --set-upstream` command |
| 5 | Push rejected (non-fast-forward) | `git push` returns rejection | Print error, commit is local, safe |
| 6 | Network failure on fetch | `git fetch` fails | Warn user, continue in local-only mode |
| 7 | Untracked files only | `git status --porcelain` shows `??` only | Include in `git add -A`, mention in preview |
| 8 | Branch name has no ticket key | regex `([A-Z]+-\d+)` no match | Omit ticket prefix from message |
| 9 | User cancels at confirmation | negative or empty response | Print "Commit cancelado.", exit cleanly |
| 10 | Diff is empty after pull --rebase | `git diff HEAD` empty after rebase | Print "No hay cambios nuevos después del rebase." and exit |

## Decision Tree (Git Workflow)

```
1. git fetch origin
   ├─ failure → warn "modo local", continue
   └─ success → check remote ahead
       ├─ remote has new commits → git pull --rebase origin <branch>
       │   ├─ conflict → git rebase --abort, error, exit
       │   └─ success → continue
       └─ nothing new → continue

2. git status --porcelain
   ├─ empty → "No hay cambios", exit
   ├─ has UU/DD → "Conflictos sin resolver", exit
   ├─ rebase in progress → "Rebase en progreso", exit
   └─ has changes → continue

3. git diff HEAD --stat && git diff HEAD
   ├─ empty after rebase → "No hay cambios nuevos", exit
   └─ has diff → continue

4. Extract branch name + ticket key: /([A-Z]+-\d+)/

5. Generate message: [TICKET:] Se [verbo] [qué] [contexto]

6. Show preview panel → ask "¿Confirmás? [s/N]"
   ├─ yes → git add -A && git commit -m "..." && git push
   │   ├─ add fails → error, exit
   │   ├─ commit fails → error, exit
   │   ├─ push succeeds → "✅ Push exitoso"
   │   └─ push fails
   │       ├─ no upstream → print manual command, exit
   │       └─ other error → "❌ Push falló. Commit local.", exit
   └─ no → "Commit cancelado.", exit
```
