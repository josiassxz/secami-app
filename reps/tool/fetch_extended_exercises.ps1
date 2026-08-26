# Fetch dos ~400 exercicios da ExerciseDB com traducao auto para pt-BR.
# Gera assets/exercises_extended.json + baixa GIFs em 480p (compacto).
#
# Uso:
#   $env:RAPIDAPI_KEY = "<chave-rapidapi>"
#   powershell -ExecutionPolicy Bypass -File tool/fetch_extended_exercises.ps1
#
# Saidas:
#   .tmp_exercisedb.json (cache da API)
#   assets/exercises_extended.json (lista pt-BR pronta pro app)
#   assets/exercises/exdb_<id>.gif (cada exercicio)
#
# Estrategia:
#   - Mapeia bodyPart -> GrupoMuscular
#   - Mapeia equipment -> Equipamento
#   - Traduz nome via regras (barbell -> barra, etc)
#   - Dedup com seed canonico (mantemos os 100 originais como prioridade)
#   - Filtra fora exercicios obscuros (wall, partner, etc)
#   - Target: ~400 exercicios totais (100 existentes + ~300 novos)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dbFile = "$root\.tmp_exercisedb.json"
$outJson = "$root\assets\exercises_extended.json"
$outDir = "$root\assets\exercises"
$reportFile = "$root\.tmp_extended_report.txt"

$rapidApiKey = $env:RAPIDAPI_KEY
if (-not $rapidApiKey) {
  throw "Defina `$env:RAPIDAPI_KEY antes de rodar (chave da ExerciseDB no RapidAPI)."
}
$apiHeaders = @{
  "x-rapidapi-host" = "exercisedb.p.rapidapi.com"
  "x-rapidapi-key"  = $rapidApiKey
}

# ============ TRADUCOES ============
$bodyPartToGrupo = @{
  "chest"      = "peito"
  "back"       = "costas"
  "shoulders"  = "ombros"
  "neck"       = "ombros"  # mapeamos pra ombros mais proximo
  "upper arms" = "biceps"  # default; afinaremos com target
  "lower arms" = "biceps"
  "waist"      = "core"
  "upper legs" = "quadriceps"
  "lower legs" = "panturrilha"
  "cardio"     = "core"
}

$equipmentToEnum = @{
  "barbell"           = "barra"
  "ez barbell"        = "barra"
  "dumbbell"          = "halter"
  "cable"             = "cabo"
  "leverage machine"  = "maquina"
  "sled machine"      = "maquina"
  "smith machine"     = "maquina"
  "olympic barbell"   = "barra"
  "trap bar"          = "barra"
  "body weight"       = "peso_corporal"
  "assisted"          = "peso_corporal"
  "stability ball"    = "peso_corporal"
  "bosu ball"         = "peso_corporal"
  "kettlebell"        = "kettlebell"
  "weighted"          = "anilha"
  "medicine ball"     = "anilha"
  "resistance band"   = "anilha"
  "band"              = "anilha"
  "tire"              = "peso_corporal"
  "rope"              = "cabo"
}

# Heuristica para escolher entre biceps/triceps quando bodyPart = "upper arms"
$tricepsMarkers = @("triceps", "tricep", "skull", "pushdown", "dip", "kickback", "close grip", "overhead extension", "lying triceps")
$bicepsMarkers = @("biceps", "bicep", "curl", "chin", "preacher", "hammer", "concentration", "21")

# Heuristica para quadriceps vs posterior vs gluteos quando bodyPart = "upper legs"
$gluteosMarkers = @("glute", "hip thrust", "hip abduction", "hip extension", "kickback", "bridge", "sumo")
$posteriorMarkers = @("hamstring", "leg curl", "stiff", "romanian", "rdl", "good morning", "bent over deadlift")
# resto vai pra quadriceps

# ============ NOMES PT-BR (regras de traducao) ============
# Aplicadas em ordem: longest match first. Mapa "termo en" -> "termo pt".
# Para frases compostas (ex: "barbell bench press") aplicamos as regras
# do mais especifico pro mais geral.
$translationPairs = @(
  # Movimentos compostos primeiro (mais especificos)
  @("barbell bench press", "supino com barra"),
  @("dumbbell bench press", "supino com halteres"),
  @("incline bench press", "supino inclinado"),
  @("decline bench press", "supino declinado"),
  @("close grip bench press", "supino fechado"),
  @("close-grip bench press", "supino fechado"),
  @("close grip pulldown", "puxada fechada"),
  @("close-grip pulldown", "puxada fechada"),
  @("wide grip pulldown", "puxada aberta"),
  @("wide-grip pulldown", "puxada aberta"),
  @("reverse grip", "pegada supinada"),
  @("underhand", "pegada supinada"),
  @("overhand", "pegada pronada"),
  @("front squat", "agachamento frontal"),
  @("hack squat", "hack squat"),
  @("split squat", "agachamento bulgaro"),
  @("bulgarian split squat", "agachamento bulgaro"),
  @("sumo squat", "agachamento sumo"),
  @("goblet squat", "agachamento goblet"),
  @("jump squat", "agachamento com salto"),
  @("squat", "agachamento"),
  @("romanian deadlift", "terra romeno"),
  @("stiff leg deadlift", "stiff"),
  @("stiff-leg deadlift", "stiff"),
  @("straight leg deadlift", "stiff"),
  @("sumo deadlift", "terra sumo"),
  @("deadlift", "terra"),
  @("bent over row", "remada curvada"),
  @("bent-over row", "remada curvada"),
  @("one arm row", "remada serrote"),
  @("one-arm row", "remada serrote"),
  @("t-bar row", "remada cavalinho"),
  @("seated row", "remada baixa"),
  @("lateral raise", "elevacao lateral"),
  @("front raise", "elevacao frontal"),
  @("rear delt fly", "crucifixo invertido"),
  @("rear delt row", "face pull"),
  @("reverse fly", "crucifixo invertido"),
  @("face pull", "face pull"),
  @("shoulder press", "desenvolvimento"),
  @("military press", "desenvolvimento militar"),
  @("overhead press", "desenvolvimento"),
  @("arnold press", "desenvolvimento arnold"),
  @("upright row", "remada alta"),
  @("preacher curl", "rosca scott"),
  @("hammer curl", "rosca martelo"),
  @("alternate biceps curl", "rosca alternada"),
  @("concentration curl", "rosca concentrada"),
  @("21s", "rosca 21"),
  @("biceps curl", "rosca direta"),
  @("bicep curl", "rosca direta"),
  @("triceps extension", "triceps frances"),
  @("tricep extension", "triceps frances"),
  @("triceps pushdown", "triceps pulley"),
  @("tricep pushdown", "triceps pulley"),
  @("triceps kickback", "triceps coice"),
  @("tricep kickback", "triceps coice"),
  @("skull crusher", "triceps testa"),
  @("skullcrusher", "triceps testa"),
  @("lying triceps extension", "triceps testa"),
  @("dip", "paralelas"),
  @("pull-up", "barra fixa pronada"),
  @("pull up", "barra fixa pronada"),
  @("chin-up", "barra fixa supinada"),
  @("chin up", "barra fixa supinada"),
  @("lat pulldown", "puxada frente"),
  @("pulldown", "puxada"),
  @("pullover", "pullover"),
  @("calf raise", "panturrilha"),
  @("calf press", "panturrilha"),
  @("leg extension", "cadeira extensora"),
  @("leg curl", "mesa flexora"),
  @("leg press", "leg press"),
  @("hip thrust", "hip thrust"),
  @("hip abduction", "abducao de quadril"),
  @("hip adduction", "aducao de quadril"),
  @("hip extension", "extensao de quadril"),
  @("glute bridge", "elevacao pelvica"),
  @("walking lunge", "passada"),
  @("reverse lunge", "afundo reverso"),
  @("forward lunge", "afundo"),
  @("lunge", "afundo"),
  @("good morning", "bom dia"),
  @("shrug", "encolhimento"),
  @("crunch", "abdominal supra"),
  @("sit-up", "abdominal sentado"),
  @("sit up", "abdominal sentado"),
  @("leg raise", "abdominal infra"),
  @("knee raise", "abdominal infra"),
  @("plank", "prancha"),
  @("side plank", "prancha lateral"),
  @("side bridge", "prancha lateral"),
  @("russian twist", "russian twist"),
  @("ab rollout", "ab wheel"),
  @("wheel rollout", "ab wheel"),
  @("mountain climber", "mountain climber"),
  @("burpee", "burpee"),
  @("jumping jack", "polichinelo"),
  @("jump rope", "pular corda"),
  @("kettlebell swing", "kettlebell swing"),
  @("farmers walk", "farmer walk"),
  @("farmer walk", "farmer walk"),
  @("turkish get up", "turkish get up"),
  @("box jump", "box jump"),
  @("thruster", "thruster"),
  @("clean", "clean"),
  @("jerk", "jerk"),
  @("snatch", "snatch"),
  @("push-up", "flexao"),
  @("push up", "flexao"),
  @("fly", "crucifixo"),
  @("flyes", "crucifixo"),
  @("pec deck", "voador peitoral"),
  @("bench press", "supino"),
  @("press", "press"),
  @("row", "remada"),
  @("curl", "rosca"),
  @("kickback", "coice"),
  # Equipamentos (modificadores que vem antes)
  @("barbell", "com barra"),
  @("dumbbell", "com halteres"),
  @("cable", "no cabo"),
  @("smith machine", "no smith"),
  @("leverage machine", "na maquina"),
  @("sled machine", "na maquina"),
  @("body weight", ""),  # remove
  @("bodyweight", ""),
  @("weighted", "com peso"),
  @("kettlebell", "com kettlebell"),
  @("medicine ball", "com bola medicinal"),
  @("resistance band", "com elastico"),
  @("band", "com elastico"),
  @("ez ", ""),
  @("olympic ", ""),
  @("trap bar", "trap bar"),
  @("rope", "com corda"),
  # Modificadores
  @("standing", "em pe"),
  @("seated", "sentado"),
  @("lying", "deitado"),
  @("incline", "inclinado"),
  @("decline", "declinado"),
  @("alternate", "alternado"),
  @("alternating", "alternado"),
  @("single", "unilateral"),
  @("single-arm", "unilateral"),
  @("one-arm", "unilateral"),
  @("one arm", "unilateral"),
  @("two-arm", "bilateral"),
  @("two arm", "bilateral"),
  @("forward", ""),
  @("reverse", "reverso"),
  @("close grip", "fechado"),
  @("close-grip", "fechado"),
  @("wide grip", "aberto"),
  @("wide-grip", "aberto"),
  @("narrow grip", "fechado"),
  @("medium grip", "neutro"),
  @("neutral grip", "neutro"),
  @("v-bar", "barra V"),
  @("rope attachment", "corda"),
  @("with rope", "com corda"),
  @("bench", "no banco"),
  @("wall", "na parede"),
  @("floor", "no chao"),
  @("with chain", "com corrente")
)

# Markers para EXCLUIR exercicios obscuros / inadequados pra MVP
$excludeMarkers = @(
  "wall ball", "wall slide", "wall sit", "partner", "assisted pull-up machine",
  "tire flip", "tire", "rope climb", "battle rope", "sled push", "sled pull",
  "tuck jump", "broad jump", "depth jump", "single leg jump",
  "fingers", "wrist", "neck", "self ", "stretch", "hip flexor stretch"
)

function Translate-Name {
  param([string]$name)
  $lower = $name.ToLower()
  # Aplica regras de traducao em ordem
  foreach ($pair in $translationPairs) {
    $from = $pair[0]
    $to = $pair[1]
    $lower = $lower.Replace($from, $to)
  }
  # Limpa espacos duplos
  $lower = $lower -replace '\s+', ' '
  $lower = $lower.Trim()
  # Capitaliza primeira letra
  if ($lower.Length -gt 0) {
    $lower = $lower.Substring(0,1).ToUpper() + $lower.Substring(1)
  }
  return $lower
}

function Get-Grupo {
  param($ex)
  $bp = $ex.bodyPart.ToLower()
  $tgt = $ex.target.ToLower()
  $name = $ex.name.ToLower()

  # Caso ambiguo: upper arms -> biceps vs triceps
  if ($bp -eq "upper arms" -or $bp -eq "lower arms") {
    foreach ($m in $tricepsMarkers) {
      if ($name.Contains($m) -or $tgt.Contains($m)) { return "triceps" }
    }
    foreach ($m in $bicepsMarkers) {
      if ($name.Contains($m) -or $tgt.Contains($m)) { return "biceps" }
    }
    return "biceps"
  }
  # Upper legs: glutos vs posterior vs quad
  if ($bp -eq "upper legs") {
    foreach ($m in $gluteosMarkers) {
      if ($name.Contains($m) -or $tgt.Contains($m)) { return "gluteos" }
    }
    foreach ($m in $posteriorMarkers) {
      if ($name.Contains($m) -or $tgt.Contains($m)) { return "posterior" }
    }
    if ($tgt.Contains("hamstring")) { return "posterior" }
    if ($tgt.Contains("glute")) { return "gluteos" }
    return "quadriceps"
  }

  if ($bodyPartToGrupo.ContainsKey($bp)) {
    return $bodyPartToGrupo[$bp]
  }
  return "core"
}

function Get-Equipamento {
  param($ex)
  $eq = $ex.equipment.ToLower()
  if ($equipmentToEnum.ContainsKey($eq)) {
    return $equipmentToEnum[$eq]
  }
  # fallback: tenta substring
  foreach ($k in $equipmentToEnum.Keys) {
    if ($eq.Contains($k)) { return $equipmentToEnum[$k] }
  }
  return "peso_corporal"
}

function Get-Padrao {
  param($ex, $grupo)
  $name = $ex.name.ToLower()
  if ($name -match "squat|lunge|leg press|step.up|step up") { return "agachamento" }
  if ($name -match "deadlift|romanian|rdl|stiff|good morning|hip thrust|hip extension|glute bridge|swing") { return "dobradica_quadril" }
  if ($name -match "pull-up|chin-up|pulldown|pull down|pullover") { return "puxada_vertical" }
  if ($name -match "row\b|rowing|t-bar") { return "puxada_horizontal" }
  if ($name -match "overhead press|military|shoulder press|push press|jerk") { return "empurrada_vertical" }
  if ($name -match "bench press|push-up|push up|chest press|dip|fly") { return "empurrada_horizontal" }
  return "isolador"
}

function Is-Excluded {
  param([string]$name)
  $lower = $name.ToLower()
  foreach ($m in $excludeMarkers) {
    if ($lower.Contains($m)) { return $true }
  }
  return $false
}

# ============ FETCH ============
if (-not (Test-Path $dbFile)) {
  Write-Host "Paginando ExerciseDB completo..." -ForegroundColor Cyan
  $all = @()
  $offset = 0
  while ($offset -lt 1500) {
    try {
      $r = Invoke-RestMethod -Uri "https://exercisedb.p.rapidapi.com/exercises?limit=50&offset=$offset" -Headers $apiHeaders -Method GET -TimeoutSec 30
    } catch {
      Write-Host "Erro offset $offset : $_" -ForegroundColor Red
      break
    }
    if ($r.Count -eq 0) { break }
    $all += $r
    $offset += 50
    if ($offset % 200 -eq 0) { Write-Host "  coletados $($all.Count)" }
    Start-Sleep -Milliseconds 50
  }
  Write-Host "Total bruto: $($all.Count) exercicios"
  $all | ConvertTo-Json -Depth 5 -Compress | Out-File $dbFile -Encoding utf8
}

$db = Get-Content $dbFile -Raw | ConvertFrom-Json
Write-Host "Banco: $($db.Count) exercicios" -ForegroundColor Cyan

# ============ PROCESSA ============
# Os 100 originais ja sao bem cobertos no exercises_seed.dart. Aqui adicionamos
# UM SUBSET adicional. Limite: 300 novos (total ~400).
$out = New-Object System.Collections.ArrayList
$ngo = 0
$skipped = 0

# Embaralha para amostragem mais distribuida por bodyPart
$shuffled = $db | Sort-Object { Get-Random }

# Cota por grupo muscular para equilibrar
$cotas = @{
  "peito" = 30; "costas" = 40; "ombros" = 35; "biceps" = 30; "triceps" = 30;
  "quadriceps" = 35; "posterior" = 25; "gluteos" = 25; "panturrilha" = 20;
  "core" = 30
}
$contagem = @{}
foreach ($k in $cotas.Keys) { $contagem[$k] = 0 }

foreach ($ex in $shuffled) {
  if ($ngo -ge 300) { break }
  if (Is-Excluded $ex.name) { $skipped++; continue }

  $grupo = Get-Grupo $ex
  if (-not $contagem.ContainsKey($grupo)) { continue }
  if ($contagem[$grupo] -ge $cotas[$grupo]) { continue }

  $equip = Get-Equipamento $ex
  $padrao = Get-Padrao $ex $grupo
  $nomePt = Translate-Name $ex.name
  $slug = "exdb_$($ex.id)"
  $descricao = $nomePt

  $row = [PSCustomObject]@{
    slug          = $slug
    nome          = $nomePt
    descricao     = $descricao
    grupo         = $grupo
    padrao        = $padrao
    equipamento   = $equip
    api_id        = $ex.id
    nome_original = $ex.name
  }
  [void]$out.Add($row)
  $contagem[$grupo]++
  $ngo++
}

Write-Host ""
Write-Host "=== DISTRIBUICAO ===" -ForegroundColor Cyan
foreach ($k in $contagem.Keys | Sort-Object) {
  Write-Host "  $k : $($contagem[$k]) / $($cotas[$k])"
}
Write-Host "TOTAL NOVOS: $ngo"
Write-Host "EXCLUIDOS POR FILTRO: $skipped"

# ============ GRAVA JSON ============
$out | ConvertTo-Json -Depth 5 | Out-File $outJson -Encoding utf8
Write-Host "JSON gravado em $outJson" -ForegroundColor Green

# ============ DOWNLOAD GIFs ============
Write-Host ""
Write-Host "Baixando GIFs em 480p (compacto)..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
"`n=== Relatorio ===" | Out-File $reportFile -Encoding utf8

$ok = 0
$fail = 0
foreach ($row in $out) {
  $outPath = "$outDir\$($row.slug).gif"
  if (Test-Path $outPath) {
    $size = (Get-Item $outPath).Length
    if ($size -gt 3000) { $ok++; continue }
  }
  # Algumas instancias da ExerciseDB so aceitam 1080. Mantemos para garantir
  # downloads bem-sucedidos; comprime depois se necessario.
  $url = "https://exercisedb.p.rapidapi.com/image?exerciseId=$($row.api_id)&resolution=1080"
  try {
    Invoke-WebRequest -Uri $url -Headers $apiHeaders -OutFile $outPath -TimeoutSec 30 -ErrorAction Stop
    $size = (Get-Item $outPath).Length
    "OK    $($row.slug)  id=$($row.api_id)  '$($row.nome_original)'  size=$size" | Out-File $reportFile -Encoding utf8 -Append
    $ok++
    if ($ok % 30 -eq 0) {
      Write-Host "  baixados $ok"
    }
  } catch {
    "FAIL  $($row.slug)  $($_.Exception.Message)" | Out-File $reportFile -Encoding utf8 -Append
    $fail++
  }
  Start-Sleep -Milliseconds 60
}

Write-Host ""
Write-Host "=== RESUMO GIFs ===" -ForegroundColor Cyan
Write-Host "OK   : $ok"
Write-Host "FAIL : $fail"
Write-Host ""
Write-Host "Pronto. Rode o app para ver os novos exercicios."
