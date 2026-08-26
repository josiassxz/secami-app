# Mapping slug PT-BR -> queries (em ordem de preferencia) na ExerciseDB.
# Baixa cada GIF em 1080p para assets/exercises/<slug>.gif
#
# Uso:
#   $env:RAPIDAPI_KEY = "sua-chave-rapidapi"
#   powershell -ExecutionPolicy Bypass -File tool/fetch_exercise_gifs.ps1
#
# Pre-requisito: ter rodado o coletor que gera .tmp_exercisedb.json (lista
# completa dos ~1394 exercicios da ExerciseDB).

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dbFile = "$root\.tmp_exercisedb.json"
$outDir = "$root\assets\exercises"
$reportFile = "$root\.tmp_gif_report.txt"

$rapidApiKey = $env:RAPIDAPI_KEY
if (-not $rapidApiKey) {
  throw "Defina `$env:RAPIDAPI_KEY antes de rodar (chave da ExerciseDB no RapidAPI)."
}
$apiHeaders = @{
  "x-rapidapi-host" = "exercisedb.p.rapidapi.com"
  "x-rapidapi-key" = $rapidApiKey
}

# === Mapping. Cada slug tem uma lista de queries (ordem = preferencia). ===
$mapping = [ordered]@{
  # PEITO
  "supino_reto_barra" = @("barbell bench press", "barbell flat bench press")
  "supino_inclinado_barra" = @("barbell incline bench press")
  "supino_declinado_barra" = @("barbell decline bench press")
  "supino_reto_halter" = @("dumbbell bench press", "dumbbell flat bench press")
  "supino_inclinado_halter" = @("dumbbell incline bench press")
  "crucifixo_halter" = @("dumbbell fly", "dumbbell flyes", "dumbbell chest fly")
  "crucifixo_cabo_cross" = @("cable crossover", "standing cable chest fly", "cable chest cross", "cable decline fly", "cable incline fly")
  "supino_maquina" = @("lever bench press", "machine bench press", "lever chest press")
  "voador_peitoral" = @("lever pec deck fly", "machine pec deck", "lever fly", "cable decline fly", "cable lying fly")
  "flexao_solo" = @("push-up", "push up")
  "flexao_inclinada" = @("incline push up", "push-up (wall)", "push-up against wall")
  "paralelas_peito" = @("chest dip", "dip")

  # COSTAS
  "puxada_frente_pegada_pronada" = @("cable pulldown", "lat pulldown", "wide grip lat pulldown")
  "puxada_frente_pegada_neutra" = @("cable v-bar pulldown", "v-bar pulldown", "parallel grip lat pulldown")
  "puxada_frente_pegada_supinada" = @("cable underhand pulldown", "underhand pulldown", "reverse grip lat pulldown")
  "remada_baixa_cabo" = @("cable seated row", "cable seated wide-grip row")
  "remada_curvada_barra" = @("barbell bent over row")
  "remada_curvada_halter" = @("dumbbell bent over row", "dumbbell two arm bent over row")
  "remada_cavalinho" = @("t-bar row", "lever t-bar row")
  "remada_serrote" = @("dumbbell one arm row", "dumbbell bent over one arm row", "barbell one arm bent over row", "cable one arm bent over row")
  "remada_maquina" = @("lever seated row", "lever row", "machine seated row")
  "barra_fixa_pronada" = @("pull-up", "pull up", "wide-grip pull-up")
  "barra_fixa_supinada" = @("chin-up", "chin up")
  "pulldown_estreito" = @("cable close grip pulldown", "close grip lat pulldown", "close-grip pull-down", "close-grip chin-up", "close grip chin-up")
  "levantamento_terra_convencional" = @("barbell deadlift")
  "pullover_halter" = @("dumbbell pullover", "dumbbell straight arm pullover")

  # OMBROS
  "desenvolvimento_militar_barra" = @("barbell military press", "barbell overhead press", "barbell shoulder press", "smith standing military press", "lever military press")
  "desenvolvimento_halter" = @("dumbbell shoulder press", "dumbbell seated shoulder press")
  "elevacao_lateral_halter" = @("dumbbell lateral raise", "dumbbell side lateral raise")
  "elevacao_lateral_cabo" = @("cable lateral raise", "cable one arm lateral raise")
  "elevacao_frontal_halter" = @("dumbbell front raise")
  "elevacao_frontal_barra" = @("barbell front raise")
  "encolhimento_barra" = @("barbell shrug")
  "encolhimento_halter" = @("dumbbell shrug")
  "crucifixo_invertido_halter" = @("dumbbell rear delt row", "dumbbell bent over rear delt fly", "dumbbell bent over rear lateral raise")
  "face_pull_corda" = @("cable rope face pull", "face pull", "cable rear delt row (with rope)", "cable standing rear delt row (with rope)")

  # BICEPS
  "rosca_direta_barra" = @("barbell curl", "barbell standing curl")
  "rosca_direta_halter" = @("dumbbell curl", "dumbbell standing curl", "dumbbell biceps curl")
  "rosca_alternada_halter" = @("dumbbell alternate biceps curl", "alternate dumbbell curl")
  "rosca_scott_barra" = @("barbell preacher curl")
  "rosca_scott_halter" = @("dumbbell preacher curl", "dumbbell one arm preacher curl")
  "rosca_martelo_halter" = @("dumbbell hammer curl", "dumbbell alternate hammer curl")
  "rosca_concentrada_halter" = @("dumbbell concentration curl")
  "rosca_21_barra" = @("barbell 21 curl", "barbell 21s", "barbell curl")

  # TRICEPS
  "triceps_testa_barra" = @("barbell lying triceps extension", "barbell skull crusher", "ez barbell skullcrusher")
  "triceps_frances_halter" = @("dumbbell overhead triceps extension", "dumbbell seated overhead triceps extension", "dumbbell seated triceps extension", "dumbbell standing triceps extension")
  "triceps_polia_barra" = @("cable pushdown", "cable triceps pushdown", "cable straight bar pushdown")
  "triceps_polia_corda" = @("cable rope pushdown", "cable rope tricep pushdown", "cable overhead triceps extension (rope attachment)")
  "triceps_coice_halter" = @("dumbbell kickback", "dumbbell tricep kickback", "dumbbell one arm tricep kickback")
  "triceps_banco" = @("tricep dips on bench", "bench dip", "triceps dips floor")
  "triceps_maquina" = @("lever triceps extension", "lever seated triceps extension")
  "supino_fechado_barra" = @("barbell close-grip bench press", "barbell close grip bench press")

  # QUADRICEPS
  "agachamento_livre_barra" = @("barbell full squat", "barbell squat")
  "agachamento_frontal_barra" = @("barbell front squat")
  "hack_machine" = @("hack squat", "sled hack squat")
  "leg_press_45" = @("sled 45° leg press", "sled 45 leg press", "sled 45° calf press") # fallback
  "cadeira_extensora" = @("lever leg extension")
  "agachamento_bulgaro_halter" = @("dumbbell bulgarian split squat", "dumbbell rear lunge")
  "afundo_barra" = @("barbell lunge", "barbell forward lunge")
  "afundo_halter" = @("dumbbell lunge", "dumbbell forward lunge")
  "agachamento_smith" = @("smith machine squat", "smith squat")
  "passada_halter" = @("dumbbell walking lunge", "walking lunge")

  # POSTERIOR
  "stiff_barra" = @("barbell stiff leg deadlift", "barbell straight leg deadlift")
  "stiff_halter" = @("dumbbell stiff leg deadlift", "dumbbell straight leg deadlift")
  "mesa_flexora" = @("lever lying leg curl")
  "cadeira_flexora" = @("lever seated leg curl")
  "terra_romeno_barra" = @("barbell romanian deadlift", "barbell rdl")
  "bom_dia_barra" = @("barbell good morning")

  # GLUTEOS
  "hip_thrust_barra" = @("barbell hip thrust", "barbell glute bridge")
  "hip_thrust_maquina" = @("lever hip thrust", "lever glute thrust", "lever hip extension v. 2", "lever hip extension")
  "elevacao_pelvica_halter" = @("dumbbell hip thrust", "dumbbell glute bridge", "barbell glute bridge", "low glute bridge on floor")
  "agachamento_sumo_barra" = @("barbell sumo squat", "barbell sumo deadlift")
  "abducao_quadril_maquina" = @("lever seated hip abduction", "lever hip abduction")
  "kickback_maquina" = @("cable standing rear kick", "cable glute kickback", "lever glute kickback", "cable kickback")

  # PANTURRILHA
  "panturrilha_em_pe_maquina" = @("lever standing calf raise", "lever calf raise")
  "panturrilha_sentada" = @("lever seated calf raise")
  "panturrilha_smith" = @("smith machine calf raise", "barbell standing calf raise", "bodyweight standing calf raise")
  "panturrilha_leg_press" = @("sled calf press", "sled 45° calf press")
  "panturrilha_unilateral_halter" = @("dumbbell single leg calf raise", "dumbbell one leg calf raise")
  "donkey_calf" = @("donkey calf raise")

  # CORE
  "prancha_frontal" = @("front plank", "plank")
  "prancha_lateral" = @("side bridge", "side plank")
  "abdominal_infra" = @("lying leg raise", "lying leg-hip raise")
  "abdominal_supra" = @("crunch", "cross crunch")
  "abdominal_oblicuo" = @("oblique crunch", "alternate heel touchers")
  "russian_twist" = @("russian twist")
  "prancha_elevacao_perna" = @("plank with leg lift", "side plank with leg lift")
  "abdominal_cabo" = @("cable kneeling crunch", "cable crunch")
  "ab_wheel" = @("wheel rollout", "ab roller")
  "hollow_hold" = @("hollow body hold", "hollow hold", "dead bug", "v-sit on floor", "l-sit on floor")

  # FUNCIONAL / FINISHERS
  "burpee" = @("burpee")
  "mountain_climber" = @("mountain climber")
  "jumping_jack" = @("jumping jack", "jacks", "star jump")
  "agachamento_salto" = @("jump squat", "squat jump")
  "kettlebell_swing" = @("kettlebell swing", "kettlebell two arm swing")
  "farmers_walk" = @("farmers walk", "farmer walk")
  "goblet_squat" = @("dumbbell goblet squat", "goblet squat")
  "turkish_get_up" = @("kettlebell turkish get up", "turkish get up")
  "box_jump" = @("box jump", "jump box")
  "thruster_halter" = @("dumbbell thruster", "dumbbell squat to overhead press", "barbell thruster", "kettlebell thruster")
}

if (-not (Test-Path $dbFile)) {
  Write-Host "Lista de exercicios ainda nao foi coletada. Paginando ExerciseDB..." -ForegroundColor Cyan
  $all = @()
  $offset = 0
  while ($offset -lt 1500) {
    try {
      $r = Invoke-RestMethod -Uri "https://exercisedb.p.rapidapi.com/exercises?limit=10&offset=$offset" -Headers $apiHeaders -Method GET -TimeoutSec 30
    } catch {
      Write-Host "Erro offset $offset : $_" -ForegroundColor Red
      break
    }
    if ($r.Count -eq 0) { break }
    $all += $r
    $offset += 10
    if ($offset % 200 -eq 0) {
      Write-Host "  coletados $($all.Count)"
    }
    Start-Sleep -Milliseconds 50
  }
  Write-Host "Total: $($all.Count) exercicios"
  $all | ConvertTo-Json -Depth 5 -Compress | Out-File $dbFile -Encoding utf8
}
$db = Get-Content $dbFile -Raw | ConvertFrom-Json
Write-Host "Banco: $($db.Count) exercicios"

# Indexa por nome lowercase para match exato
$byNameExact = @{}
foreach ($ex in $db) {
  $key = $ex.name.ToLower()
  if (-not $byNameExact.ContainsKey($key)) { $byNameExact[$key] = $ex }
}

function Find-Match {
  param($queries, $db, $byNameExact)
  foreach ($q in $queries) {
    $qLower = $q.ToLower()
    # Exact match
    if ($byNameExact.ContainsKey($qLower)) {
      return $byNameExact[$qLower]
    }
    # Substring match
    $hits = $db | Where-Object { $_.name.ToLower().Contains($qLower) }
    if ($hits) { return $hits[0] }
  }
  return $null
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
"`n=== Relatorio de download de GIFs ===" | Out-File $reportFile -Encoding utf8

$ok = 0
$miss = 0
$missList = @()

foreach ($slug in $mapping.Keys) {
  $queries = $mapping[$slug]
  $match = Find-Match -queries $queries -db $db -byNameExact $byNameExact
  if (-not $match) {
    Write-Host "[?] $slug -> nenhum match" -ForegroundColor Yellow
    $miss++
    $missList += $slug
    "MISS  $slug  (queries: $($queries -join '; '))" | Out-File $reportFile -Encoding utf8 -Append
    continue
  }

  $outPath = "$outDir\$slug.gif"
  # Skip se ja existe e tem tamanho razoavel (evita re-download)
  if (Test-Path $outPath) {
    $existing = (Get-Item $outPath).Length
    if ($existing -gt 5000) {
      Write-Host "[~] $slug ja baixado ($existing bytes), pulando" -ForegroundColor DarkGray
      $ok++
      continue
    }
  }
  $url = "https://exercisedb.p.rapidapi.com/image?exerciseId=$($match.id)&resolution=1080"

  try {
    Invoke-WebRequest -Uri $url -Headers $apiHeaders -OutFile $outPath -TimeoutSec 30 -ErrorAction Stop
    $size = (Get-Item $outPath).Length
    if ($size -lt 2000) {
      Write-Host "[!] $slug -> arquivo suspeito ($size bytes)" -ForegroundColor Yellow
    }
    "OK    $slug  id=$($match.id)  name='$($match.name)'  size=$size" | Out-File $reportFile -Encoding utf8 -Append
    Write-Host "[v] $slug <- $($match.name) ($size bytes)" -ForegroundColor Green
    $ok++
  } catch {
    Write-Host "[X] $slug erro: $($_.Exception.Message)" -ForegroundColor Red
    "FAIL  $slug  $($_.Exception.Message)" | Out-File $reportFile -Encoding utf8 -Append
    $miss++
    $missList += $slug
  }
  Start-Sleep -Milliseconds 100
}

Write-Host ""
Write-Host "=== RESUMO ===" -ForegroundColor Cyan
Write-Host "OK   : $ok"
Write-Host "MISS : $miss"
if ($missList.Count -gt 0) {
  Write-Host "Sem match:"
  $missList | ForEach-Object { Write-Host "  - $_" }
}
Write-Host ""
Write-Host "Detalhes em $reportFile"
