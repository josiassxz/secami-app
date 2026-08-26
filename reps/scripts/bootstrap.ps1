# bootstrap.ps1
# Scaffold mecanico do projeto reps. Roda antes de qualquer chamada ao Claude.
# Verifica dependencias, prepara .env, inicializa git, cria estado inicial.

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Write-Ok($msg) {
    Write-Host "    [OK] $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host "    [WARN] $msg" -ForegroundColor Yellow
}

function Write-Fail($msg) {
    Write-Host "    [FAIL] $msg" -ForegroundColor Red
}

function Test-Cmd($name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { return $false }
    return $true
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Magenta
Write-Host "  reps - bootstrap" -ForegroundColor Magenta
Write-Host "================================================" -ForegroundColor Magenta

# 1. Dependencias
Write-Step "Verificando dependencias"

$deps = @{
    "git"     = "https://git-scm.com/download/win"
    "flutter" = "https://docs.flutter.dev/get-started/install/windows"
    "claude"  = "https://docs.claude.com/en/docs/claude-code/setup"
}

$missing = @()
foreach ($d in $deps.Keys) {
    if (Test-Cmd $d) {
        Write-Ok "$d encontrado"
    } else {
        Write-Fail "$d nao encontrado. Instale em: $($deps[$d])"
        $missing += $d
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "Instale as dependencias acima e rode novamente." -ForegroundColor Red
    exit 1
}

# 2. Git init
Write-Step "Inicializando repositorio git"
if (Test-Path "$root\.git") {
    Write-Ok "ja inicializado"
} else {
    git init | Out-Null
    git branch -M main | Out-Null
    Write-Ok "repositorio criado em branch main"
}

# 3. .gitignore
Write-Step "Verificando .gitignore"
$gitignorePath = "$root\.gitignore"
$gitignoreLines = @(
    "# Flutter",
    ".dart_tool/",
    ".flutter-plugins",
    ".flutter-plugins-dependencies",
    ".pub-cache/",
    ".pub/",
    "build/",
    "*.g.dart",
    "*.freezed.dart",
    "ios/Pods/",
    "android/.gradle/",
    "android/local.properties",
    "",
    "# Env",
    ".env",
    ".env.local",
    "",
    "# Estado de execucao",
    "scripts/.run-log.txt",
    "scripts/.state.json",
    "scripts/.stage-*-summary.md",
    "",
    "# Artefatos temporarios",
    "_docx_extract/",
    "_docx.zip",
    "",
    "# IDEs",
    ".idea/",
    ".vscode/",
    "*.iml",
    ""
)
if (-not (Test-Path $gitignorePath) -or $Force) {
    $gitignoreLines | Out-File -FilePath $gitignorePath -Encoding utf8
    Write-Ok ".gitignore criado"
} else {
    Write-Ok ".gitignore ja existe (use -Force para sobrescrever)"
}

# 4. .env.example
Write-Step "Criando .env.example"
$envExamplePath = "$root\.env.example"
$envLines = @(
    "# === OBRIGATORIO ===",
    "# Supabase (https://supabase.com)",
    "# 1. Criar projeto free tier",
    "# 2. Settings -> API -> copiar Project URL e anon public key",
    "SUPABASE_URL=",
    "SUPABASE_ANON_KEY=",
    "",
    "# === OPCIONAL (deixe vazio se nao usar - SDK vira no-op) ===",
    "# Sentry (https://sentry.io) - crash reporting",
    "SENTRY_DSN=",
    "",
    "# PostHog (https://posthog.com) - analytics",
    "POSTHOG_API_KEY=",
    "POSTHOG_HOST=https://us.i.posthog.com",
    ""
)
$envLines | Out-File -FilePath $envExamplePath -Encoding utf8
Write-Ok ".env.example criado"

# 5. .env (so cria se nao existir, e copia do example)
$envPath = "$root\.env"
if (-not (Test-Path $envPath)) {
    Copy-Item $envExamplePath $envPath
    Write-Warn ".env criado a partir do .env.example - PREENCHA OS VALORES antes de rodar run-autonomous.ps1"
} else {
    Write-Ok ".env ja existe"
}

# 6. Estado inicial
Write-Step "Criando estado de execucao"
$stateDir = "$root\scripts"
$statePath = "$stateDir\.state.json"
$logPath = "$stateDir\.run-log.txt"

if (-not (Test-Path $statePath) -or $Force) {
    $state = @{
        current_stage = 1
        stages = @{
            "1" = @{ status = "pending" }
            "2" = @{ status = "pending" }
            "3" = @{ status = "pending" }
        }
        last_error = $null
    }
    $state | ConvertTo-Json -Depth 5 | Out-File -FilePath $statePath -Encoding utf8
    Write-Ok ".state.json criado"
} else {
    Write-Ok ".state.json ja existe (use -Force para resetar)"
}

if (-not (Test-Path $logPath)) {
    "# reps - run log" | Out-File -FilePath $logPath -Encoding utf8
    Write-Ok ".run-log.txt criado"
}

# 7. Versoes finais
Write-Step "Versoes detectadas"
Write-Host "    flutter : $((flutter --version 2>&1 | Select-Object -First 1))"
Write-Host "    git     : $(git --version)"
Write-Host "    claude  : $(claude --version 2>&1 | Select-Object -First 1)"

# 8. Resumo
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  Bootstrap completo." -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Proximos passos:"
Write-Host "  1. (OBRIGATORIO) Crie projeto no Supabase em https://supabase.com"
Write-Host "     - Settings > API: copie Project URL + anon key"
Write-Host "     - Cole em .env nas chaves SUPABASE_URL e SUPABASE_ANON_KEY"
Write-Host "  2. (OPCIONAL) Sentry e PostHog - deixe vazio em .env se nao for usar"
Write-Host "  3. Rode: .\scripts\run-autonomous.ps1"
Write-Host ""
Write-Host "Apos o Stage 1 gerar supabase/migrations/0001_init.sql:"
Write-Host "  - Abra o SQL Editor do projeto Supabase"
Write-Host "  - Cole o conteudo e execute"
Write-Host ""
