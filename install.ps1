#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Instala la skill commit-push en uno o más agentes de IA.

.DESCRIPTION
    Copia SKILL.md a los directorios de skills de los agentes AI compatibles:
    OpenCode, Claude Code, Cursor y GitHub Copilot.
    Por defecto detecta automáticamente qué agentes están instalados.

.PARAMETER Agent
    Agente destino: Auto (detecta instalados), OpenCode, ClaudeCode, Cursor,
    Copilot, o All (todos los compatibles aunque no estén instalados).

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Agent OpenCode
    .\install.ps1 -Agent ClaudeCode
    .\install.ps1 -Agent All
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Auto", "OpenCode", "ClaudeCode", "Cursor", "Copilot", "All")]
    [string]$Agent = "Auto"
)

$ErrorActionPreference = "Stop"

$RepoRoot    = $PSScriptRoot
$SourceSkill = Join-Path $PSScriptRoot "SKILL.md"

# Fallback: si el script está en un subdirectorio del repo
if (-not (Test-Path $SourceSkill)) {
    $SourceSkill = Join-Path (Split-Path -Parent $PSScriptRoot) "SKILL.md"
}

if (-not (Test-Path $SourceSkill)) {
    Write-Error "No se encontró SKILL.md en $SourceSkill"
    exit 1
}

Write-Host "🔧 Instalando skill commit-push..." -ForegroundColor Cyan
Write-Host "  Skill source: $SourceSkill" -ForegroundColor DarkGray
Write-Host ""

# ─── Contadores ─────────────────────────────────────────────────────────────
$installed = 0
$found = 0

# ─── OpenCode ────────────────────────────────────────────────────────────────
function Install-OpenCode {
    param([string]$SkillFile)
    $configDir = "$env:USERPROFILE\.config\opencode"
    $skillsDir = "$configDir\skills\commit-push"
    $destFile  = "$skillsDir\SKILL.md"
    $configFile = "$configDir\opencode.json"

    if (-not (Test-Path $configDir)) {
        Write-Host "  ⏭️  OpenCode: no instalado (no se encontró $configDir)" -ForegroundColor DarkGray
        return $false
    }

    # Copiar SKILL.md
    if (-not (Test-Path $skillsDir)) {
        New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
    }
    Copy-Item -Path $SkillFile -Destination $destFile -Force
    Write-Host "  ✅ OpenCode: SKILL.md copiado" -ForegroundColor Green

    # Agregar sub-agente a opencode.json si existe
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile -Encoding UTF8 | ConvertFrom-Json
            $changed = $false

            if (-not $config.agent.'commit-push-agent') {
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
                $changed = $true
                Write-Host "  ✅ OpenCode: sub-agente commit-push-agent agregado" -ForegroundColor Green
            }

            $orchestrator = $config.agent.'gentle-orchestrator'
            if ($orchestrator -and $orchestrator.permission.task) {
                if (-not $orchestrator.permission.task.'commit-push-agent') {
                    $orchestrator.permission.task | Add-Member -NotePropertyName "commit-push-agent" -NotePropertyValue "allow"
                    $changed = $true
                    Write-Host "  ✅ OpenCode: commit-push-agent permitido en orchestrator" -ForegroundColor Green
                }
            }

            if ($changed) {
                $config | ConvertTo-Json -Depth 10 | Set-Content $configFile -Encoding UTF8
                Write-Host "  ✅ OpenCode: configuración guardada" -ForegroundColor Green
            } else {
                Write-Host "  ✅ OpenCode: ya configurado" -ForegroundColor DarkGray
            }
        } catch {
            Write-Warning "OpenCode: no se pudo actualizar opencode.json ($($_.Exception.Message))"
        }
    } else {
        Write-Host "  ℹ️  OpenCode: opencode.json no encontrado, SKILL.md copiado manualmente" -ForegroundColor Yellow
    }

    return $true
}

# ─── Claude Code ─────────────────────────────────────────────────────────────
function Install-ClaudeCode {
    param([string]$SkillFile)
    $skillsDir = "$env:USERPROFILE\.claude\skills\commit-push"
    $destFile  = "$skillsDir\SKILL.md"

    if (-not (Test-Path "$env:USERPROFILE\.claude")) {
        Write-Host "  ⏭️  Claude Code: no instalado (no se encontró ~\.claude)" -ForegroundColor DarkGray
        return $false
    }

    if (-not (Test-Path $skillsDir)) {
        New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
    }
    Copy-Item -Path $SkillFile -Destination $destFile -Force
    Write-Host "  ✅ Claude Code: SKILL.md copiado a $destFile" -ForegroundColor Green

    Write-Host "  ℹ️  Claude Code: referenciá la skill desde tu CLAUDE.md si es necesario" -ForegroundColor Yellow
    return $true
}

# ─── Cursor ──────────────────────────────────────────────────────────────────
function Install-Cursor {
    param([string]$SkillFile)
    $cursorDir = "$env:USERPROFILE\.cursor"
    $rulesDir  = "$cursorDir\rules"
    $destFile  = "$rulesDir\commit-push.mdc"

    if (-not (Test-Path $cursorDir)) {
        Write-Host "  ⏭️  Cursor: no instalado (no se encontró ~\.cursor)" -ForegroundColor DarkGray
        return $false
    }

    if (-not (Test-Path $rulesDir)) {
        New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null
    }
    Copy-Item -Path $SkillFile -Destination $destFile -Force
    Write-Host "  ✅ Cursor: SKILL.md copiado a $destFile" -ForegroundColor Green
    return $true
}

# ─── GitHub Copilot ──────────────────────────────────────────────────────────
function Install-Copilot {
    param([string]$SkillFile)
    $githubDir = "$RepoRoot\.github"
    $copilotFile = "$githubDir\copilot-instructions.md"

    if (-not (Test-Path $githubDir)) {
        New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
    }

    # Agregar contenido al archivo de instrucciones de Copilot
    $separator = "`n---`n"
    $content = Get-Content $SkillFile -Raw
    $header = "## commit-push: Git automation`n"

    if (Test-Path $copilotFile) {
        # Verificar si ya está instalado
        $existing = Get-Content $copilotFile -Raw
        if ($existing -match "commit-push") {
            Write-Host "  ✅ Copilot: ya instalado en $copilotFile" -ForegroundColor DarkGray
            return $true
        }
        Add-Content -Path $copilotFile -Value "$separator$header$content" -Encoding UTF8
    } else {
        Set-Content -Path $copilotFile -Value "$header$content" -Encoding UTF8
    }

    Write-Host "  ✅ Copilot: instrucciones agregadas a $copilotFile" -ForegroundColor Green
    return $true
}

# ─── Resolver agentes destino ────────────────────────────────────────────────
$targets = @()

switch ($Agent) {
    "Auto" {
        Write-Host "🔍 Detectando agentes instalados..." -ForegroundColor Cyan
        if (Test-Path "$env:USERPROFILE\.config\opencode")   { $targets += "OpenCode" }
        if (Test-Path "$env:USERPROFILE\.claude")             { $targets += "ClaudeCode" }
        if (Test-Path "$env:USERPROFILE\.cursor")             { $targets += "Cursor" }
        # Copilot no tiene directorio de instalación fácil de detectar,
        # pero podemos ofrecerlo como opción
        if ($targets.Count -eq 0) {
            Write-Host "  ⚠️  No se detectaron agentes instalados." -ForegroundColor Yellow
            Write-Host "  Intentando instalar en todos los destinos compatibles..." -ForegroundColor Yellow
            $targets = @("OpenCode", "ClaudeCode", "Cursor", "Copilot")
        }
    }
    "All" {
        $targets = @("OpenCode", "ClaudeCode", "Cursor", "Copilot")
    }
    default {
        $targets = @($Agent)
    }
}

# ─── Ejecutar instalación ────────────────────────────────────────────────────
foreach ($agent in $targets) {
    Write-Host "» $agent..." -ForegroundColor Cyan
    $result = $false
    switch ($agent) {
        "OpenCode"    { $result = Install-OpenCode -SkillFile $SourceSkill }
        "ClaudeCode"  { $result = Install-ClaudeCode -SkillFile $SourceSkill }
        "Cursor"      { $result = Install-Cursor -SkillFile $SourceSkill }
        "Copilot"     { $result = Install-Copilot -SkillFile $SourceSkill }
    }
    if ($result) { $installed++; $found++ } else { $found++ }
}

# ─── Resumen ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✅ Instalación completada." -ForegroundColor Green
Write-Host "  Agentes configurados: $installed de $found" -ForegroundColor Cyan

if ($Agent -eq "Auto" -and $installed -eq 0) {
    Write-Host ""
    Write-Host "💡 Para instalar manualmente en un agente específico:" -ForegroundColor Yellow
    Write-Host "  .\install.ps1 -Agent OpenCode     # OpenCode / Gentle AI" -ForegroundColor White
    Write-Host "  .\install.ps1 -Agent ClaudeCode   # Claude Code" -ForegroundColor White
    Write-Host "  .\install.ps1 -Agent Cursor       # Cursor" -ForegroundColor White
    Write-Host "  .\install.ps1 -Agent Copilot      # GitHub Copilot" -ForegroundColor White
    Write-Host "  .\install.ps1 -Agent All          # Todos los compatibles" -ForegroundColor White
}

Write-Host ""
Write-Host "📌 Próximo paso: reiniciá tu agente AI para que tome los cambios." -ForegroundColor Cyan
