# commit-push: Git automation skill for AI agents

Skill para **agentes de IA** que automatiza `git add`, `git commit` y `git push`
con mensajes de commit profesionales en español.

> 🇦🇷 Genera mensajes estilo *"Se agregó…"*, *"Se corrigió…"*, con formato pasivo
> profesional y prefijo de ticket opcional extraído del nombre de la rama.

Compatible con: **OpenCode** · **Claude Code** · **Cursor** · **GitHub Copilot**
· **cualquier agente AI con soporte de instrucciones personalizadas**.

---

## ✨ Funcionalidades

- **Detección automática de cambios**: analiza el working tree con `git status --porcelain`
- **Rebase seguro**: hace `git fetch` + `git pull --rebase` antes de commitear
- **Mensaje profesional en español**: formato `[TICKET:] Se [verbo] [qué] [contexto]`
- **Preview obligatorio con confirmación**: muestra el mensaje, la lista de archivos a commiterar, y los archivos excluidos — nunca commitea sin aprobación explícita
- **Inventario de archivos**: parsea `git status --porcelain` y clasifica cada archivo (modificado, agregado, eliminado, renombrado, untracked)
- **Filtro de archivos no-project**: excluye automáticamente skills (`.claude/`, `skills/`), notas personales (`*.md`), config de IDE (`.idea/`, `.vscode/`), metadatos de SO (`.DS_Store`, `Thumbs.db`), etc.
- **`.commitignore`**: creá un archivo en la raíz del repo para agregar tus propias exclusiones
- **`git add` selectivo**: solo stagea los archivos del proyecto, no los filtrados
- **9 verbos en pasado pasivo**: `agregó`, `modificó`, `corrigió`, `implementó`, `eliminó`, etc.
- **Prefijo de ticket automático**: extrae `PROYECTO-123` del nombre de la rama
- **13 edge cases cubiertos**: conflictos, rebase, push sin upstream, push fallido, todo filtrado, `.commitignore`, etc.

---

## 🚀 Instalación

### Requisitos

- Un agente de IA compatible (OpenCode, Claude Code, Cursor, Copilot, etc.)
- Git configurado

---

### OpenCode / Gentle AI

#### Opción 1: Instalación automática (PowerShell)

```powershell
.\install.ps1
```

#### Opción 2: Manual

1. Copiá `SKILL.md` al directorio de skills:

```bash
mkdir -p ~/.config/opencode/skills/commit-push
cp SKILL.md ~/.config/opencode/skills/commit-push/SKILL.md
```

2. Agregá el sub-agente `commit-push-agent` a tu `opencode.json`:

```json
"commit-push-agent": {
  "description": "Commit & Push Agent - analiza cambios, genera mensaje en español profesional, y ejecuta git add/commit/push.",
  "hidden": true,
  "mode": "subagent",
  "prompt": "You are the Commit & Push Agent executor, not the orchestrator. Do this work yourself. Read your skill file at ~/.config/opencode/skills/commit-push/SKILL.md and follow it exactly. Do NOT delegate. Do NOT call task to spawn sub-agents.",
  "tools": {
    "bash": true,
    "read": true,
    "write": true,
    "task": false
  }
}
```

3. En tu orchestrator (`gentle-orchestrator`), agregá `"commit-push-agent": "allow"` en `permission > task`.

4. Agregá los triggers al prompt del orchestrator (ver sección **Commit & Push Triggers** en `opencode.example.json`).

---

### Claude Code

1. Copiá `SKILL.md` al directorio de skills de Claude:

```bash
mkdir -p ~/.claude/skills/commit-push
cp SKILL.md ~/.claude/skills/commit-push/SKILL.md
```

2. Referenciá la skill desde tu `CLAUDE.md` o archivo de instrucciones del proyecto.

O simplemente incluí el contenido de `SKILL.md` en tu `CLAUDE.md` del proyecto si preferís tenerlo inline.

---

### Cursor

1. Copiá `SKILL.md` como regla de Cursor:

```bash
mkdir -p .cursor/rules
cp SKILL.md .cursor/rules/commit-push.mdc
```

2. Cursor cargará la regla automáticamente cuando trabajes en el repo.

O agregá el contenido a tu `.cursorrules` raíz si preferís un archivo único.

---

### GitHub Copilot

Agregá el contenido de `SKILL.md` a `.github/copilot-instructions.md` en tu repo:

```bash
mkdir -p .github
cat SKILL.md >> .github/copilot-instructions.md
```

Copilot usará estas instrucciones como contexto cuando le pidas commits.

---

### Cualquier otro agente

La mayoría de los agentes AI modernos soportan instrucciones personalizadas.
Simplemente proveé el contenido de `SKILL.md` como instrucción del agente, ya sea:

- En un archivo de instrucciones del proyecto
- En tu prompt de sistema o configuración del agente
- Como parte de un archivo de reglas del asistente

La skill fue diseñada para ser **autónoma**: cualquier agente puede leerla y
ejecutar Steps 1–7 directamente sin necesidad de infraestructura adicional.

---

### Instalación multi-agente con install.ps1

El script `install.ps1` detecta automáticamente qué agentes tenés instalados
y copia la skill a todos los destinos compatibles:

```powershell
.\install.ps1              # Auto-detecta todos los agentes instalados
.\install.ps1 -Agent OpenCode     # Solo OpenCode
.\install.ps1 -Agent ClaudeCode   # Solo Claude Code
.\install.ps1 -Agent All          # Instala en todos los agentes detectados
```

---

## 🎯 Cómo se usa

Una vez instalado, simplemente decí cualquiera de estas frases cuando tengas cambios para commitear:

| Frase | Acción |
|---|---|
| "termine mi trabajo commitea" | Analiza cambios, genera mensaje, muestra preview |
| "dale commit" | Lo mismo |
| "commit y push" | Lo mismo |
| "trabajo terminado" | Lo mismo |
| "estamos ok para el push" | Lo mismo |
| "comitea y pushea" | Lo mismo |

El agente:
1. Hace `git fetch` + `git pull --rebase`
2. Analiza los cambios y construye un inventario de archivos
3. Filtra archivos no pertenecientes al proyecto (skills, notas `.md`, config IDE)
4. Genera un mensaje en español profesional
5. Muestra preview con dos secciones: archivos a commiterar y archivos excluidos
6. Pide confirmación explícita antes de ejecutar cualquier comando

---

## 📝 Ejemplos de mensajes generados

```
REM-13927: Se incrementó el límite máximo de caracteres (`maxlength`) del campo
de texto correspondiente al motivo adicional en la pantalla de detalle de
verificación.
```

```
Se agregó la funcionalidad para recuperar y mapear los comentarios de las
incidencias, permitiendo su procesamiento y utilización dentro de la aplicación.
```

---

## 🛡️ Edge cases manejados

| # | Situación | Qué pasa |
|---|---|---|
| 1 | No hay cambios | "No hay cambios para commitear." |
| 2 | Conflictos sin resolver | ❌ Error y sale |
| 3 | Rebase en progreso | ❌ Error y sale |
| 4 | Push sin upstream | ⚠️ Muestra comando manual |
| 5 | Push rechazado | Commit seguro local, error |
| 6 | Sin conexión al remoto | Modo local, commit igual |
| 7 | Solo archivos nuevos | Pregunta si incluirlos |
| 8 | Rama sin ticket | Mensaje sin prefijo |
| 9 | Usuario cancela | "Commit cancelado." |
| 10 | Diff vacío tras rebase | "No hay cambios nuevos." |
| 11 | Todos los archivos filtrados | "⚠️ Todos los cambios son archivos no-project" |
| 12 | Algunos archivos excluidos | Se muestran en sección "⏭️ Excluidos" del preview |
| 13 | `.commitignore` presente | Se mergean sus patrones con las exclusiones default |

---

## 📁 Estructura del repo

```
skill-commit/
├── SKILL.md                # La skill en sí — instrucciones para cualquier agente AI
├── README.md               # Este archivo
├── install.ps1             # Script de instalación multi-agente
├── opencode.example.json   # Configuración de ejemplo para OpenCode
└── .atl/
    └── skill-registry.md   # Registry de skills instaladas
```

---

## 🔧 Compatibilidad

| Plataforma | Ruta de instalación | Modo de ejecución |
|---|---|---|
| OpenCode / Gentle AI | `~/.config/opencode/skills/commit-push/SKILL.md` | Delegación orchestrator → sub‑agent |
| Claude Code | `~/.claude/skills/commit-push/SKILL.md` | Ejecución directa |
| Cursor | `.cursor/rules/commit-push.mdc` | Ejecución directa |
| GitHub Copilot | `.github/copilot-instructions.md` | Ejecución contextual |
| Cualquier agente | Instrucciones personalizadas del agente | Ejecución directa |

---

## 📄 Licencia

MIT
