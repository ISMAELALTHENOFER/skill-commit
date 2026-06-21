# commit-push skill

Skill para **OpenCode** / **Gentle AI** que automatiza `git add`, `git commit` y `git push` con mensajes de commit profesionales en español.

> 🇦🇷 Genera mensajes estilo *"Se agregó…"*, *"Se corrigió…"*, con formato pasivo profesional y prefijo de ticket opcional extraído del nombre de la rama.

## ✨ Funcionalidades

- **Detección automática de cambios**: analiza el working tree con `git status --porcelain`
- **Rebase seguro**: hace `git fetch` + `git pull --rebase` antes de commitear
- **Mensaje profesional en español**: formato `[TICKET:] Se [verbo] [qué] [contexto]`
- **Preview con confirmación**: muestra el mensaje y la lista de archivos modificados, pide aprobación
- **9 verbos en pasado pasivo**: `agregó`, `modificó`, `corrigió`, `implementó`, `eliminó`, etc.
- **Prefijo de ticket automático**: extrae `PROYECTO-123` del nombre de la rama
- **Edge cases cubiertos**: conflictos, rebase, push sin upstream, push fallido, etc.

## 🚀 Instalación

### Requisitos

- [OpenCode](https://opencode.ai) instalado
- Git configurado

### Opción 1: Instalación automática (PowerShell)

```powershell
.\install.ps1
```

### Opción 2: Manual

1. Copiá `SKILL.md` a tu directorio de skills:

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
2. Analiza los cambios
3. Genera un mensaje en español profesional
4. Muestra preview con la lista de archivos
5. Pide confirmación antes de ejecutar

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

## 📁 Estructura del repo

```
skill-commit/
├── SKILL.md                # La skill en sí
├── README.md               # Este archivo
├── install.ps1             # Script de instalación automática
├── opencode.example.json   # Fragmento de configuración de ejemplo
└── .atl/
    └── skill-registry.md   # Registry de skills instaladas
```

## 📄 Licencia

MIT
