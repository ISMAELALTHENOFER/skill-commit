---
name: commit-push
description: "Trigger: commit, push, commit y push, trabajo terminado, dale commit. Automate git add/commit/push with Spanish message generation."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming
  version: "1.1"
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
changes, pull remote changes (`git fetch` + `git pull --rebase`), build a file
inventory, filter out non-project files (skills, personal notes, config, etc.),
show a preview with ALL proposed files and any excluded files,
ALWAYS ask for explicit user confirmation, and on approval execute
selective `git add` + `git commit` + `git push`.

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
| Any other output (staged/unstaged/untracked) | Continue to Step 3.5 |

### Step 3.5: Build file inventory

Run `git status --porcelain` and parse EVERY line to build a structured
inventory of each changed file with its status:

```
# Porcelain indicators
M  = modified (staged)
 M = modified (unstaged)
A  = added (staged)
?? = untracked
D  = deleted
 R = renamed
```

From this output, build the following structured lists:

- `FILES_MODIFIED`: list of modified files (staged or unstaged)
- `FILES_ADDED`: list of added/new files
- `FILES_DELETED`: list of deleted files
- `FILES_UNTRACKED`: list of untracked files
- `FILES_RENAMED`: list of renamed files

### Step 3.6: Filter non-project files

Apply exclusion rules to separate project files from non-project files.
Non-project files are files that exist in the working tree but do NOT belong
to the project itself — personal notes, skill development files, IDE config,
OS metadata, etc.

Check for a `.commitignore` file in the repo root:
```bash
Test-Path -LiteralPath ".commitignore"
```

If it exists, read its patterns (one per line, `#` for comments) and merge
them with the default exclusion patterns below.

**Default exclusion patterns** (always applied — see full list in the
[Default Exclusion Patterns](#default-exclusion-patterns) section):

| Pattern | Reason |
|---------|--------|
| `.claude/**` | Claude/OpenCode skill files and config |
| `.config/opencode/**` | OpenCode editor configuration |
| `skills/**` | AI skill files |
| `*.md` | Markdown files (personal notes, not project docs) |
| `.idea/**` | JetBrains IDE config |
| `.vscode/**` | VS Code config |
| `**/.DS_Store` | macOS metadata |
| `**/Thumbs.db` | Windows thumbnail cache |

After filtering, produce:

- `INCLUDED_FILES`: files that pass the filter (will be offered for staging)
- `EXCLUDED_FILES`: files that match exclusion patterns (will NOT be staged)

Print a summary line:

```
📋 Archivos del proyecto: {count_included}  |  ⏭️  Excluidos (no-project): {count_excluded}
```

If ALL files are excluded (no project files to commit), print:

```
⚠️  Todos los cambios son archivos no pertenecientes al proyecto.
Nada para commitear. Revisá tus exclusiones en .commitignore si es necesario.
```
and exit cleanly.

### Step 4: Get diff, branch and ticket info

Run these commands to gather context:

```bash
BRANCH=$(git branch --show-current)
DIFF=$(git diff HEAD)
DIFF_STAGED=$(git diff --cached)
FULL_DIFF="$DIFF$DIFF_STAGED"
```

Then extract TICKET from $BRANCH. Use the correct shell syntax for your runtime:

- **Linux/macOS (bash)**:
  ```bash
  TICKET=$(echo "$BRANCH" | grep -oP '([A-Z]+-\d+)' | head -1)
  ```

- **Windows (PowerShell 7+)** — use THIS on win32:
  ```powershell
  $TICKET = if ($env:BRANCH -match '([A-Z]+\-\d+)') { $matches[1] } else { '' }
  ```

- **Manual fallback** (if neither works): inspect the branch name string and manually extract the first match of the pattern `XXX-12345` (uppercase letters, dash, digits).

`TICKET` MUST be extracted and printed to the preview. If you cannot extract it, set `TICKET=""` and print a warning that the ticket could not be parsed.

- `BRANCH`: current branch name.
- `FULL_DIFF`: complete diff (staged + unstaged) for message generation.
- `TICKET`: ticket key extracted from branch name (e.g., `REM-13927`). Empty if no match.

If `FULL_DIFF` is empty after the rebase (all changes were already upstream),
print "No hay cambios nuevos después del rebase." and exit.

If the inventory has ONLY untracked files (`FILES_UNTRACKED` only), note this
and ask the user in the preview whether they want to include them.

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

**Ticket prefix**: Si `TICKET` no está vacío, **SIEMPRE** ponelo al inicio del mensaje en el formato `"{TICKET}: "`. Si está vacío, omití el prefijo.

⚠️ **REQUISITO OBLIGATORIO**: el ticket debe aparecer en el mensaje final. Si el branch tiene ticket pero no pudiste extraerlo automáticamente, inspeccioná el nombre del branch manualmente y extraelo. No es opcional saltearlo.

**Examples** (must follow this exact style):

```
REM-13927: Se incrementó el límite máximo de caracteres (`maxlength`) del campo de texto correspondiente al motivo adicional en la pantalla de detalle de verificación.
```

```
Se agregó la funcionalidad para recuperar y mapear los comentarios de las incidencias, permitiendo su procesamiento y utilización dentro de la aplicación.
```

Technical terms (file names, component names, variable names, library names)
SHOULD be wrapped in backticks.

### Step 6: Show preview and confirm (MANDATORY — NEVER SKIPPED)

The user ALWAYS sees the full preview with complete file lists.
There is NO auto-commit path. This step is NEVER bypassed.

Build the preview using the filtered inventories from Steps 3.5–3.6:

- `INCLUDED_FILES` with their status labels (modificado, agregado, eliminado)
- `EXCLUDED_FILES` shown in a separate section so the user knows what was filtered

If there are excluded files, include a note that the user can create a
`.commitignore` file in the repo root to customize exclusions.

Display the preview in a clear box:

```
┌──────────────────────────────────────────────┐
│  📝 Mensaje del commit:                      │
│  {mensaje}                                   │
│                                              │
│  🌿 Rama: {branch}                           │
│                                              │
│  📦 Archivos a commiterar ({count_included}):│
│    {file1} ({status})                        │
│    {file2} ({status})                        │
│    ...                                       │
│                                              │
│  ⏭️  Archivos excluidos ({count_excluded}):  │
│    {excluded1}                               │
│    {excluded2}                               │
│    ...                                       │
│                                              │
│  ¿Confirmás el commit con estos archivos?    │
│  [s/N]                                       │
└──────────────────────────────────────────────┘
```

Wait for user input. Accept positive replies: `s`, `sí`, `si`, `yes`, `y`, `ok`,
`dale`, `confirmo`, `daly` (case-insensitive, trimmed).

- If positive → proceed to Step 7.
- If anything else (or empty) → print "Commit cancelado." and exit cleanly.

### Step 7: Execute selective add → commit → push

Stage ONLY the included (non-excluded) files. Use one of these approaches:

**Option A — Explicit file list** (most precise):
```bash
git add -- <included_file1> <included_file2> ...
```

**Option B — Pathspec exclusions** (cleaner for many files):
```bash
git add -A -- . ':(exclude).claude/**' ':(exclude)*.md' ':(exclude)skills/**' ':(exclude).idea/**' ':(exclude).vscode/**'
```

Use Option A when there are few included files. Use Option B when there are
many included files and you want to keep the command short.

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
| 7 | Untracked files only | `git status --porcelain` shows `??` only | Ask user in preview whether to include them |
| 8 | Branch name has no ticket key | regex `([A-Z]+-\d+)` no match | Omit ticket prefix from message |
| 9 | User cancels at confirmation | negative or empty response | Print "Commit cancelado.", exit cleanly |
| 10 | Diff is empty after pull --rebase | `git diff HEAD` empty after rebase | Print "No hay cambios nuevos después del rebase." and exit |
| 11 | All files filtered out | All files match exclusion patterns | Print "⚠️  Todos los cambios son archivos no pertenecientes al proyecto." and exit |
| 12 | Some files excluded | `git status --porcelain` has files matching exclusions | Show in "⏭️  Archivos excluidos" section, do NOT stage |
| 13 | `.commitignore` exists | File exists in repo root | Read patterns and merge with default exclusions |

## Default Exclusion Patterns

These patterns are ALWAYS applied to filter out non-project files before
showing the preview and staging:

| Pattern | Reason |
|---------|--------|
| `.claude/**` | Claude/OpenCode skill files and config |
| `.config/opencode/**` | OpenCode editor configuration |
| `skills/**` | AI skill files (agent instructions) |
| `*.md` | Markdown files (personal notes, not project docs) |
| `.idea/**` | JetBrains IDE configuration |
| `.vscode/**` | VS Code configuration |
| `**/.DS_Store` | macOS filesystem metadata |
| `**/Thumbs.db` | Windows thumbnail cache |

### `.commitignore` file

Users can extend or override the default exclusions by creating a
`.commitignore` file in the repo root. Each line is a pathspec pattern
(same syntax as `.gitignore`). Lines starting with `#` are comments.

Example `.commitignore`:
```
# Project-specific exclusions
tmp/
personal/
*.log
build/
secrets/
```

The `.commitignore` patterns are merged with the defaults. User patterns
take precedence — if the same pattern appears in both, the user version wins.

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
   └─ has changes → continue to 3.5

3.5 Build file inventory (parse porcelain → status + path per file)
   └─ classify: modified, added, deleted, untracked, renamed

3.6 Apply exclusion filters
   ├─ check .commitignore (if exists) → merge with defaults
   ├─ separate files → INCLUDED vs EXCLUDED
   ├─ all excluded → "Todos no-project", exit
   └─ has included → continue to 4

4. git diff HEAD + branch + ticket
   ├─ diff empty after rebase → "No hay cambios nuevos", exit
   └─ has diff → continue

5. Generate message: [TICKET:] Se [verbo] [qué] [contexto]

6. Show preview panel → included files + excluded files → ask "¿Confirmás? [s/N]"
   ├─ yes → selective git add (included only) && git commit && git push
   │   ├─ add fails → error, exit
   │   ├─ commit fails → error, exit
   │   ├─ push succeeds → "✅ Push exitoso"
   │   └─ push fails
   │       ├─ no upstream → print manual command, exit
   │       └─ other error → "❌ Push falló. Commit local.", exit
   └─ no → "Commit cancelado.", exit
```
