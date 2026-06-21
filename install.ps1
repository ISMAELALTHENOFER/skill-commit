#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Instala la skill commit-push en OpenCode / Gentle AI.
.DESCRIPTION
    Copia SKILL.md a ~/.config/opencode/skills/commit-push/ y
    agrega la configuración necesaria en opencode.json.
.NOTES
    Ejecutar: .\install.ps1
#>

$ErrorActionPreference = "Stop"

# ─── Rutas ──────────────────────────────────────────────────────────────────
$ConfigDir    = "$env:USERPROFILE\.config\opencode"
$SkillsDir    = "$ConfigDir\skills\commit-push"
$SkillFile    = "$SkillsDir\SKILL.md"
$ConfigFile   = "$ConfigDir\opencode.json"
$SourceSkill  = Join-Path (Split-Path $PSScriptRoot -Parent) "SKILL.md"

# Si el script se ejecuta desde el repo mismo, el SKILL.md está al lado
if (-not (Test-Path $SourceSkill)) {
    $SourceSkill = Join-Path $PSScriptRoot "SKILL.md"
}

Write-Host "🔧 Instalando skill commit-push..." -ForegroundColor Cyan

# ─── 1. Crear directorio de skills ──────────────────────────────────────────
if (-not (Test-Path $SkillsDir)) {
    New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
    Write-Host "  ✅ Creado: $SkillsDir" -ForegroundColor Green
} else {
    Write-Host "  ✅ Ya existe: $SkillsDir" -ForegroundColor DarkGray
}

# ─── 2. Copiar SKILL.md ────────────────────────────────────────────────────
if (Test-Path $SourceSkill) {
    Copy-Item -Path $SourceSkill -Destination $SkillFile -Force
    Write-Host "  ✅ Copiado: $SkillFile" -ForegroundColor Green
} else {
    Write-Warning "No se encontró SKILL.md en $SourceSkill"
    exit 1
}

# ─── 3. Verificar que opencode.json existe ──────────────────────────────────
if (-not (Test-Path $ConfigFile)) {
    Write-Warning "No se encontró opencode.json en $ConfigFile"
    Write-Host "  ℹ️  Creá el archivo manualmente o primero instalá OpenCode." -ForegroundColor Yellow
    exit 1
}

# ─── 4. Agregar sub-agente commit-push-agent ────────────────────────────────
$config = Get-Content $ConfigFile -Encoding UTF8 | ConvertFrom-Json

$agentAdded = $false
if (-not $config.agent.commit-push-agent) {
    $commitPushAgent = @{
        description = "Commit & Push Agent - analiza cambios, genera mensaje en español profesional, y ejecuta git add/commit/push."
        hidden      = $true
        mode        = "subagent"
        prompt      = "You are the Commit & Push Agent executor, not the orchestrator. Do this work yourself. Read your skill file at ~/.config/opencode/skills/commit-push/SKILL.md and follow it exactly. Do NOT delegate. Do NOT call task to spawn sub-agents."
        tools       = @{
            bash  = $true
            read  = $true
            write = $true
            task  = $false
        }
    }
    $config.agent | Add-Member -NotePropertyName "commit-push-agent" -NotePropertyValue $commitPushAgent
    $agentAdded = $true
    Write-Host "  ✅ Agregado sub-agente: commit-push-agent" -ForegroundColor Green
} else {
    Write-Host "  ✅ Ya existe: commit-push-agent en agent" -ForegroundColor DarkGray
}

# ─── 5. Agregar allowlist en el orchestrator ────────────────────────────────
$orchestrator = $config.agent."gentle-orchestrator"
if ($orchestrator -and $orchestrator.permission.task) {
    $allowList = $orchestrator.permission.task
    if (-not $allowList."commit-push-agent") {
        $allowList | Add-Member -NotePropertyName "commit-push-agent" -NotePropertyValue "allow"
        Write-Host "  ✅ Agregado commit-push-agent a allowlist del orchestrator" -ForegroundColor Green
    } else {
        Write-Host "  ✅ Ya permitido: commit-push-agent en orchestrator" -ForegroundColor DarkGray
    }
} else {
    Write-Warning "No se encontró gentle-orchestrator.permission.task en opencode.json"
    Write-Host "  ℹ️  Agregalo manualmente (ver opencode.example.json)" -ForegroundColor Yellow
}

# ─── 6. Guardar configuración ──────────────────────────────────────────────
$config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Encoding UTF8
Write-Host ""
Write-Host "✅ Instalación completada." -ForegroundColor Green
Write-Host ""
Write-Host "📌 Próximo paso: reiniciá OpenCode para que tome los cambios." -ForegroundColor Cyan
Write-Host "📌 Luego probalo con: 'termine mi trabajo commitea'" -ForegroundColor Cyan
