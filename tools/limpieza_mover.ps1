# limpieza_mover.ps1 — Limpieza de primavera (docs/LIMPIEZA.md). Lo escribe el Juego, lo ejecuta Pablo.
# Uso, desde la raíz del repo con `git status` limpio:
#   powershell -ExecutionPolicy Bypass -File tools\limpieza_mover.ps1 -Fase 1            # 2D muertos + copias 3D + test2d
#   powershell -ExecutionPolicy Bypass -File tools\limpieza_mover.ps1 -Fase 1 -Simular   # solo enseña lo que haría
#   -Fase 2  → tras L2.1/L2.2 del Juego (nivel_base y su cadena; hechizos 2D arrastrados)
#   -Fase 3  → lo del Pipeline (arte 2D, pipeline de sprites, tests) cuando él lo confirme
# Por qué `git mv` y no Move-Item: conserva el historial. Por qué `.gdignore`: Godot deja de importar y compilar lo movido,
# así desaparecen los class_name duplicados sin borrar nada. Cada archivo se mueve con su .uid / .import si existen.
param([int]$Fase = 1, [switch]$Simular)
$ErrorActionPreference = "Stop"
if (-not (Test-Path "project.godot")) { throw "Ejecutar desde la raíz del repo (donde está project.godot)" }
if (-not (Test-Path "docs/DIARIO.md") -or (Get-Item "docs/DIARIO.md").Length -lt 260000) {
    throw "Este repo no parece estar al día (DIARIO.md < 260 KB). Haz git pull antes." }
# Si hay cambios sin commit, solo avisa: lo normal es que sean los documentos de la limpieza recién escritos. Lo que importa es
# que el commit de los movimientos vaya aparte de otros cambios; eso lo decide Pablo al hacer commit.
$sucio = git status --porcelain
if ($sucio -and -not $Simular) {
    Write-Host "AVISO: hay cambios sin commit (se mueven igual; haz un commit solo con la limpieza):"
    $sucio | ForEach-Object { Write-Host "   $_" }
}

function Mover($rel, $destino) {
    if (-not (Test-Path $rel)) { Write-Host "  (no existe) $rel"; return }
    $dir = Join-Path "_a_eliminar" $destino
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    foreach ($f in @($rel, "$rel.uid", "$rel.import")) {
        if (Test-Path $f) {
            $a = Join-Path $dir (Split-Path $f -Leaf)
            Write-Host "  $f -> $a"
            if (-not $Simular) {
                $seguido = git ls-files --error-unmatch $f 2>$null
                if ($LASTEXITCODE -eq 0) { git mv $f $a } else { Move-Item $f $a }
            }
        }
    }
}
function MoverCarpeta($rel, $destino) {
    if (-not (Test-Path $rel)) { Write-Host "  (no existe) $rel"; return }
    $dir = Join-Path "_a_eliminar" $destino
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $a = Join-Path $dir (Split-Path $rel -Leaf)
    Write-Host "  $rel\ -> $a\"
    if (-not $Simular) {
        $seguido = git ls-files $rel
        if ($seguido) { git mv $rel $a } else { Move-Item $rel $a }
    }
}

if (-not (Test-Path "_a_eliminar")) { New-Item -ItemType Directory -Path "_a_eliminar" | Out-Null }
if (-not (Test-Path "_a_eliminar/.gdignore")) { New-Item -ItemType File -Path "_a_eliminar/.gdignore" | Out-Null }
if (-not (Test-Path "_a_eliminar/LEEME.md")) {
@"
# _a_eliminar

Archivos que el 3D ya no usa (medido: docs/LIMPIEZA.md, 13/10/2026). Godot no los importa (.gdignore).
Pendientes de la última revisión de Pablo; cuando dé el visto bueno se borra la carpeta entera.
Subcarpetas: 2d_muertos (ninguna escena los carga) · 2d_nivel_base (los arrastraba test_2.gd) · 2d_hechizos (lanzamiento 2D)
· 2d_prerender (test2d) · 3d_copias (escenas y copias antiguas) · 2d_arte / 2d_pipeline_sprites (Pipeline).
"@ | Set-Content -Encoding UTF8 "_a_eliminar/LEEME.md"
}

if ($Fase -eq 1) {
  Write-Host "== Fase 1: 2D muertos"
  foreach ($f in @(
    "Blockout.tscn",
    "Brazier.tscn",
    "IsoTest.tscn",
    "Mundo.tscn",
    "ReactionLab.tscn",
    "Test2.tscn",
    "TestJugabilidad.tscn",
    "VfxLab.tscn",
    "VfxLabMundo.tscn",
    "adventurer_visual_smoketest.gd",
    "adventurer_visual_smoketest.tscn",
    "blockout.gd",
    "brazier.gd",
    "cartografa_arcana.tres",
    "conductor.gd",
    "iso_test.gd",
    "mundo.gd",
    "node_2d.gd",
    "node_2d.tscn",
    "progresion.gd",
    "prop.gd",
    "reaction_lab.gd",
    "sprite_2d.gd",
    "test_jugabilidad.gd",
    "vfx_lab.gd",
    "vfx_lab_mundo.gd"
  )) { Mover $f "2d_muertos" }
  Mover "cartografa_arcana.png" "2d_muertos"
  Write-Host "== Fase 1: copias y escenas antiguas del 3D"
  foreach ($f in @(
    "poc_25d/niveles/jugabilidad_copia_20261007_115151.tscn",
    "poc_25d/niveles/test2_copia_20261007_115221.tscn",
    "poc_25d/niveles/nivel_Bosque.tscn"
  )) { Mover $f "3d_copias" }
  # Estas tres solo si Pablo lo confirma (LIMPIEZA.md §2.D): quitar el # para moverlas.
  # Mover "poc_25d/PruebaJugabilidadBosque.tscn" "3d_copias"
  # Mover "poc_25d/PruebaNivelBosque.tscn" "3d_copias"
  # Mover "poc_25d/PruebaJugabilidadBosque_1.tscn" "3d_copias"
  # Mover "poc_25d/niveles/jugabilidad.tscn" "3d_copias"
  # Mover "poc_25d/niveles/test2.tscn" "3d_copias"
  Write-Host "== Fase 1: prueba 2D prerenderizada y descartados"
  MoverCarpeta "poc_25d/test2d" "2d_prerender"
  MoverCarpeta "poc_25d/_descartado" "3d_descartado"
  Write-Host ""
  Write-Host "AHORA (Pablo): en project.godot cambiar run/main_scene a res://poc_25d/PruebaBosque.tscn, abrir Godot y arrancar."
}
if ($Fase -eq 2) {
  Write-Host "== Fase 2: nivel_base y su cadena (requiere L2.1 hecho: prueba_test2 ya no preload test_2.gd)"
  if (Select-String -Path "presentacion\prueba_test2.gd" -Pattern 'res://poc_25d/' -Quiet) { throw "presentacion\prueba_test2.gd es una copia vieja (rutas poc_25d): restaurar antes" }
  $maqueta = (Get-ChildItem -Path . -Recurse -Filter prueba_test2.gd | Where-Object { $_.FullName -notmatch "_a_eliminar" } | Select-Object -First 1).FullName   # en poc_25d/ o en presentacion/
  if (Select-String -Path $maqueta -Pattern 'res://test_2.gd' -Quiet) { throw "prueba_test2.gd aún carga test_2.gd: L2.1 no está hecho" }
  foreach ($f in @(
    "Archer.tscn",
    "Arrow.tscn",
    "EarthBlock.tscn",
    "Goal.tscn",
    "GrassBlock.tscn",
    "NeutralBlock.tscn",
    "WaterBlock.tscn",
    "alquimia.gd",
    "archer.gd",
    "arrow.gd",
    "circuit.gd",
    "combustible.gd",
    "door.gd",
    "earth_block.gd",
    "earth_builder.gd",
    "electric_sparks.gd",
    "enemy.gd",
    "enemy.tscn",
    "fogata.gd",
    "goal.gd",
    "goblin_arquero.gd",
    "goblin_escarcha.gd",
    "goblin_guerrero.gd",
    "grass_blades.gd",
    "grass_block.gd",
    "grass_burn.gd",
    "health_bar.gd",
    "level_controller.gd",
    "misiones.gd",
    "neutral_block.gd",
    "nivel_base.gd",
    "pantalla_muerte.gd",
    "player.gd",
    "reagente.gd",
    "recolectable.gd",
    "steam_rune.tres",
    "test_2.gd",
    "water_block.gd"
  )) { Mover $f "2d_nivel_base" }
  Write-Host "== Fase 2: lanzamiento 2D arrastrado (requiere L2.2: SpellRecipe sin SpellFactory, Combate3D sin CombateComun)"
  if (Select-String -Path "nucleo\spell_recipe.gd" -Pattern 'SpellFactory' -Quiet) { throw "spell_recipe.gd aún usa SpellFactory: L2.2 no está hecho" }
  foreach ($f in @(
    "spell.gd",
    "spell.tscn",
    "spell_factory.gd",
    "spell_form.gd",
    "spell_material.gd",
    "spell_impact.gd",
    "spell_beam.gd",
    "glow.gd",
    "block_fx.gd",
    "iso_grid.gd",
    "botin.gd"
  )) { Mover $f "2d_hechizos" }
  $combate = (Get-ChildItem -Path . -Recurse -Filter combate_3d.gd | Where-Object { $_.FullName -notmatch "_a_eliminar" } | Select-Object -First 1).FullName
  if (-not (Select-String -Path $combate -Pattern 'CombateComun' -Quiet)) { Mover "combate_comun.gd" "2d_hechizos" }
}
if ($Fase -eq 3) {
  Write-Host "== Fase 3: todo lo que queda del 2D y del pipeline de sprites (medido 13/10: cero referencias desde el 3D)"
  foreach ($f in @("actor_animator.gd","ms_actor.gd","ms_atlas.gd")) { Mover $f "2d_pipeline_sprites" }
  foreach ($d in @("pipeline","export_godot","Render Studio","tests","Sprites","Spellbook","assets")) { MoverCarpeta $d "2d_pipeline_sprites" }
  Get-ChildItem tools -Filter "gen_*.py" | ForEach-Object { Mover ("tools/" + $_.Name) "2d_pipeline_sprites/tools" }
  foreach ($f in @("tools/video_a_fila.py","tools/empezar_prueba_iso.bat","tools/grabar_laboratorio.bat")) { Mover $f "2d_pipeline_sprites/tools" }
  # art/: el 3D usa SOLO art/ui (grimorio y los 17 glifos: sigils.gd, spellbook.gd) y art/fx (9 iconos de elemento: *_rune.tres).
  # Esas dos carpetas se quedan en art/; el resto (sprites 2D, particles, bosque) se va.
  Get-ChildItem art -File | Where-Object { $_.Extension -ne ".import" } | ForEach-Object { Mover ("art/" + $_.Name) "2d_arte" }
  Get-ChildItem art -Directory | Where-Object { $_.Name -notin "ui","fx" } | ForEach-Object { MoverCarpeta ("art/" + $_.Name) "2d_arte" }
}
if ($Simular) { Write-Host "SIMULACIÓN: no se ha movido nada. Si la lista es la esperada, vuelve a ejecutar sin -Simular." }
else { Write-Host "Hecho. Revisa con: git status; abre Godot; ejecuta las pruebas headless (herramientas/prueba_*.gd)." }
