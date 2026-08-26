# run-autonomous.ps1
# Executa Claude Code em modo headless sobre cada prompt em prompts/, em sequencia.
# Skip permissions habilitado: nao pede aprovacao por tool call.
# Le e atualiza estado em scripts/.state.json.

[CmdletBinding()]
param(
    [switch]$Reset,
    [int]$OnlyStage = 0,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$statePath = "$root\scripts\.state.json"
$logPath = "$root\scripts\.run-log.txt"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    [WARN] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "    [FAIL] $msg" -ForegroundColor Red }

function Append-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$ts] $msg" | Out-File -FilePath $logPath -Encoding utf8 -Append
}

function Read-State {
    if (-not (Test-Path $statePath)) {
        Write-Fail "Estado nao encontrado. Rode bootstrap.ps1 primeiro."
        exit 1
    }
    return Get-Content $statePath -Raw | ConvertFrom-Json
}

function Save-State($state) {
    $state | ConvertTo-Json -Depth 5 | Out-File -FilePath $statePath -Encoding utf8
}

function Get-PromptPath($stage) {
    $padded = "{0:D2}" -f $stage
    return "$root\prompts\$padded-stage-$padded.md"
}

function Get-StageSummaryPath($stage) {
    $padded = "{0:D2}" -f $stage
    return "$root\scripts\.stage-$padded-summary.md"
}

# Reset opcional
if ($Reset) {
    Write-Step "Resetando estado"
    $state = @{
        current_stage = 1
        stages = @{
            "1" = @{ status = "pending" }
            "2" = @{ status = "pending" }
            "3" = @{ status = "pending" }
        }
        last_error = $null
    }
    Save-State $state
    Write-Ok "Estado resetado"
}

$state = Read-State

# Pre-flight: .env preenchido
Write-Step "Pre-flight"
$envPath = "$root\.env"
if (-not (Test-Path $envPath)) {
    Write-Fail ".env nao encontrado. Rode bootstrap.ps1."
    exit 1
}
$envContent = Get-Content $envPath -Raw

# Obrigatorios: Supabase
$requiredKeys = @("SUPABASE_URL", "SUPABASE_ANON_KEY")
$missingRequired = @()
foreach ($k in $requiredKeys) {
    if (-not ($envContent -match "(?m)^$k=.+")) {
        $missingRequired += $k
    }
}
if ($missingRequired.Count -gt 0) {
    Write-Fail "Chaves OBRIGATORIAS vazias em .env: $($missingRequired -join ', ')"
    Write-Fail "Crie projeto em https://supabase.com, copie Project URL + anon key, e edite .env"
    exit 1
}
Write-Ok "Chaves obrigatorias presentes (Supabase)"

# Opcionais: Sentry, PostHog
$optionalKeys = @("SENTRY_DSN", "POSTHOG_API_KEY")
$missingOptional = @()
foreach ($k in $optionalKeys) {
    if (-not ($envContent -match "(?m)^$k=.+")) {
        $missingOptional += $k
    }
}
if ($missingOptional.Count -gt 0) {
    Write-Warn "Chaves opcionais vazias (SDKs ficam em no-op): $($missingOptional -join ', ')"
} else {
    Write-Ok "Chaves opcionais tambem presentes"
}

if (-not (Test-Path "$root\prompts\01-stage-01.md")) {
    Write-Fail "Prompts nao encontrados em prompts/. Algo de errado com o setup."
    exit 1
}

# Stages a executar
$stagesToRun = @()
if ($OnlyStage -gt 0) {
    if ($OnlyStage -lt 1 -or $OnlyStage -gt 3) {
        Write-Fail "OnlyStage deve ser 1, 2 ou 3"
        exit 1
    }
    $stagesToRun = @($OnlyStage)
} else {
    foreach ($s in 1..3) {
        $status = $state.stages."$s".status
        if ($status -ne "done") { $stagesToRun += $s }
    }
}

if ($stagesToRun.Count -eq 0) {
    Write-Ok "Todas as etapas ja estao done. Use -Reset para reexecutar."
    exit 0
}

Write-Step "Etapas a executar: $($stagesToRun -join ', ')"
Append-Log "Iniciando execucao das etapas: $($stagesToRun -join ', ')"

foreach ($stage in $stagesToRun) {
    $promptPath = Get-PromptPath $stage
    if (-not (Test-Path $promptPath)) {
        Write-Fail "Prompt nao encontrado: $promptPath"
        Append-Log "ERRO: prompt nao encontrado para stage $stage"
        exit 1
    }

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Magenta
    Write-Host "  Executando Stage $stage" -ForegroundColor Magenta
    Write-Host "================================================" -ForegroundColor Magenta

    $state.current_stage = $stage
    $state.stages."$stage".status = "in_progress"
    $state.stages."$stage" | Add-Member -NotePropertyName "started_at" -NotePropertyValue (Get-Date -Format "o") -Force
    Save-State $state
    Append-Log "Stage $stage iniciado"

    $promptContent = Get-Content $promptPath -Raw

    if ($DryRun) {
        Write-Warn "DryRun ativo - nao invocando Claude. Prompt seria:"
        Write-Host $promptContent
        continue
    }

    # Invoca Claude Code headless
    # --dangerously-skip-permissions: nao pede aprovacao por tool call
    # -p <prompt>: passa o prompt na cli
    Write-Step "Invocando Claude Code (modo headless, skip-permissions)"
    Append-Log "Invocando: claude -p <prompt-stage-$stage>"

    $exitCode = 0
    try {
        # Salva prompt em temp file para evitar problemas de escape em linha de comando longa
        $tmpPrompt = New-TemporaryFile
        $promptContent | Out-File -FilePath $tmpPrompt.FullName -Encoding utf8

        # & operador pra invocar
        # nota: claude espera prompt na flag -p; passamos via Get-Content -Raw
        $promptRaw = Get-Content $tmpPrompt.FullName -Raw
        & claude -p $promptRaw --dangerously-skip-permissions 2>&1 | Tee-Object -FilePath $logPath -Append
        $exitCode = $LASTEXITCODE
        Remove-Item $tmpPrompt.FullName -Force -ErrorAction SilentlyContinue
    } catch {
        $exitCode = 1
        $errMsg = $_.Exception.Message
        Append-Log "Excecao ao invocar claude: $errMsg"
        Write-Fail "Excecao: $errMsg"
    }

    if ($exitCode -ne 0) {
        Write-Fail "Claude retornou exit code $exitCode no Stage $stage"
        $state.stages."$stage".status = "failed"
        $state.last_error = "Stage $stage exit $exitCode"
        Save-State $state
        Append-Log "Stage $stage FAILED com exit $exitCode"
        exit $exitCode
    }

    # Verifica sumario
    $summaryPath = Get-StageSummaryPath $stage
    if (-not (Test-Path $summaryPath)) {
        Write-Warn "Sumario nao encontrado em $summaryPath. Stage marcado como done mesmo assim."
    } else {
        Write-Ok "Sumario encontrado: $summaryPath"
    }

    $state.stages."$stage".status = "done"
    $state.stages."$stage" | Add-Member -NotePropertyName "finished_at" -NotePropertyValue (Get-Date -Format "o") -Force
    Save-State $state
    Append-Log "Stage $stage DONE"
    Write-Ok "Stage $stage concluido"
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  Execucao autonoma finalizada." -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Verifique os sumarios:"
foreach ($s in 1..3) {
    $p = Get-StageSummaryPath $s
    if (Test-Path $p) { Write-Host "  - $p" }
}
Write-Host ""
Write-Host "Log completo: $logPath"
