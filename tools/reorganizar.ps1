# reorganizar.ps1 — De `poc_25d/` (la prueba de concepto) a carpetas por capa (docs/ARQUITECTURA_MODULAR.md §2).
# Lo escribe el Juego; lo ejecuta Pablo desde la raíz del repo, DESPUÉS de limpieza_mover.ps1 -Fase 1 y con commit hecho.
#
#   powershell -ExecutionPolicy Bypass -File tools\reorganizar.ps1 -Simular   # enseña qué movería y cuántas rutas reescribiría
#   powershell -ExecutionPolicy Bypass -File tools\reorganizar.ps1            # mueve (git mv) y reescribe las rutas res://
#
# Por qué un script y no arrastrar en Godot: el editor reescribe las rutas de escenas y recursos, pero NO las cadenas de los
# scripts (`preload("res://poc_25d/...")`, `const NIVELES = "res://poc_25d/niveles/"`, `"res://poc_25d/%s.glb"`). Aquí se mueve
# con git mv (conserva historial) y después se sustituye cada ruta vieja por la nueva en todos los .gd/.tscn/.tres/.import/.godot.
# Qué NO hace: no cambia nombres de archivo ni de clases (eso es M1–M5, módulo a módulo); no toca docs/ (las rutas antiguas en
# los documentos son historia). Los 2D que quedan en la raíz (nivel_base y su cadena, los hechizos 2D) se quedan ahí: caen en
# limpieza_mover.ps1 -Fase 2 cuando el Juego termine L2.
param([switch]$Simular)
$ErrorActionPreference = "Stop"
if (-not (Test-Path "project.godot")) { throw "Ejecutar desde la raíz del repo" }
if (-not (Test-Path "poc_25d")) { throw "No hay poc_25d/: ¿ya se reorganizó?" }
if (-not (Test-Path "_a_eliminar/2d_muertos/Mundo.tscn") -and -not $Simular) {
    throw "Primero limpieza_mover.ps1 -Fase 1 (Mundo.tscn aún no está en _a_eliminar)" }
$sucio = git status --porcelain
if ($sucio -and -not $Simular) { throw "git status no está limpio: haz commit de la Fase 1 antes de reorganizar (así el diff de esto va solo)" }

# ---------- 1. Correspondencia archivo -> carpeta nueva ----------
$mapa = [ordered]@{}
function A($carpeta, $archivos) { foreach ($f in $archivos) { $script:mapa[$f] = $carpeta } }

# nucleo/: datos puros que usa el 3D (lo que era la raíz 2D y sigue vivo)
A "nucleo" @("runes.gd","rune_data.gd","sigils.gd","spell_recipe.gd","estado.gd","objetos.gd","repertoire.gd","playlog.gd",
  "sfx.gd","sonidos.gd","gesture_library.gd","gesture_library.tres","gesture_recognizer.gd",
  "fire_rune.tres","water_rune.tres","wind_rune.tres","earth_rune.tres","lightning_rune.tres","ice_rune.tres","time_rune.tres",
  "poc_25d/playlog_3d.gd")
# magia/: el lanzador y su base 2D (spellcaster.gd se queda aquí hasta M4), la geometría de las formas
A "magia" @("poc_25d/lanzador_3d.gd","spellcaster.gd","poc_25d/formas_3d.gd")
# mundo/: casillas, agua, marcadores, horneado, vista del editor
A "mundo" @("poc_25d/agua_sim_3d.gd","poc_25d/hornear_nivel.gd","poc_25d/marcador_3d.gd","poc_25d/pieza_3d.gd","poc_25d/vista_suelo_editor.gd")
# objetos/: lo que reacciona a los elementos
A "objetos" @("poc_25d/objetos_3d.gd","poc_25d/surtidor_3d.gd","poc_25d/emisor_rayo_3d.gd","poc_25d/puente_reactivo_3d.gd",
  "poc_25d/enredadera_3d.gd","poc_25d/flotador_3d.gd")
A "enemigos" @("poc_25d/combate_3d.gd")
A "jugador" @("poc_25d/jugador_3d.gd","poc_25d/pj_3d.gd","poc_25d/equipo_3d.gd","poc_25d/proporcion_chibi.gd")
# presentacion/: la maqueta (dibujo del mundo), VFX, dibujo del agua, hierba, oclusión, HUD y grimorio
A "presentacion" @("poc_25d/prueba_test2.gd","poc_25d/vfx_3d.gd","poc_25d/vfx_kit_3d.gd","poc_25d/agua_render_3d.gd",
  "poc_25d/agua_ondas_3d.gd","poc_25d/agua_metaballs_3d.gd","poc_25d/costra_hielo_3d.gd","poc_25d/canal_3d.gd",
  "poc_25d/hierba_3d.gd","poc_25d/ocluso_3d.gd","poc_25d/hilo_luz_3d.gd")
A "presentacion/ui" @("spellbook.gd","page_hud.gd","rune_palette.gd","bolsa_ui.gd")
# escenas/: reglas por nivel y las escenas que se juegan (F5/F6)
A "escenas" @("poc_25d/bosque_3d.gd","poc_25d/jugabilidad_3d.gd","poc_25d/nivel_pruebas.gd",
  "poc_25d/PruebaBosque.tscn","poc_25d/PruebaTest2.tscn","poc_25d/PruebaJugabilidad3D.tscn","poc_25d/PruebaNivelPruebas3D.tscn",
  "poc_25d/PruebaJugabilidadBosque.tscn","poc_25d/PruebaJugabilidadBosque_1.tscn","poc_25d/PruebaNivelBosque.tscn")
A "laboratorios" @("poc_25d/lab_agua_3d.gd","poc_25d/lab_vfx_3d.gd","poc_25d/lab_gato_3d.gd","poc_25d/lab_grandmaster_3d.gd",
  "poc_25d/lab_humanoide_3d.gd","poc_25d/LabAgua3D.tscn","poc_25d/LabVfx3D.tscn","poc_25d/LabGato3D.tscn",
  "poc_25d/LabGrandmaster3D.tscn","poc_25d/LabHumanoide3D.tscn","poc_25d/catalogo_assets.gd","poc_25d/CatalogoAssets.tscn")
A "arte" @("poc_25d/COPIAR_MODELOS.cmd")
A "docs/maqueta_3d" @("poc_25d/LEEME.md")   # docs/LEEME.md ya existe: va en su carpeta
A "_a_eliminar/3d_copias" @("poc_25d/ORDENAR_POC.cmd")

# Carpetas enteras (se mueven con su contenido; las rutas se reescriben por prefijo)
$carpetas = [ordered]@{
  "poc_25d/niveles"       = "mundo/datos_nivel"      # Nivel_<X>.tscn horneados, mapas/<X>.txt, suelo_tipos.tres, luz_juego.tscn
  "poc_25d/herramientas"  = "herramientas"           # pruebas headless y generador de piezas
  "poc_25d/grimorio"      = "presentacion/grimorio"
  "poc_25d/ui"            = "presentacion/ui/laminas"
  "poc_25d/vfx"           = "presentacion/vfx"
  "poc_25d/vfx_elementos" = "presentacion/vfx_elementos"
  "poc_25d/piezas"        = "arte/piezas"
  "poc_25d/meshy"         = "arte/meshy"
  "poc_25d/suelo_meshy"   = "arte/suelo_meshy"
  "poc_25d/equipo"        = "arte/equipo"
}
# Los modelos sueltos de poc_25d/ (.glb con sus .jpg/.png al lado: el .glb los busca por ruta relativa, así que van juntos)
$modelos = Get-ChildItem poc_25d -File | Where-Object { $_.Extension -in ".glb",".jpg",".png" } | ForEach-Object { "poc_25d/" + $_.Name }
A "arte/modelos" $modelos

# ---------- 2. Mover ----------
$reescrituras = [ordered]@{}     # ruta res:// vieja -> nueva (las más largas primero al aplicar)
function Mover($rel, $carpeta) {
    if (-not (Test-Path $rel)) { Write-Host "  (no existe) $rel"; return }
    if (-not (Test-Path $carpeta)) { if (-not $Simular) { New-Item -ItemType Directory -Path $carpeta -Force | Out-Null } }
    $nombre = Split-Path $rel -Leaf
    $nuevo = "$carpeta/$nombre"
    $reescrituras["res://$rel"] = "res://$nuevo"
    foreach ($f in @($rel, "$rel.uid", "$rel.import")) {
        if (Test-Path $f) {
            $a = "$carpeta/" + (Split-Path $f -Leaf)
            Write-Host "  $f -> $a"
            if (-not $Simular) { if (git ls-files $f) { git mv $f $a } else { Move-Item $f $a } }
        }
    }
}
Write-Host "== Archivos"
foreach ($k in $mapa.Keys) { Mover $k $mapa[$k] }
Write-Host "== Carpetas"
foreach ($k in $carpetas.Keys) {
    $d = $carpetas[$k]
    if (-not (Test-Path $k)) { Write-Host "  (no existe) $k"; continue }
    Write-Host "  $k/ -> $d/"
    $reescrituras["res://$k/"] = "res://$d/"
    if (-not $Simular) {
        $padre = Split-Path $d -Parent
        if ($padre -and -not (Test-Path $padre)) { New-Item -ItemType Directory -Path $padre -Force | Out-Null }
        git mv $k $d
    }
}
# Lo que quede en poc_25d/ apuntando a modelos por patrón ("res://poc_25d/%s.glb", RAIZ): va a arte/modelos/
$reescrituras["res://poc_25d/"] = "res://arte/modelos/"

# ---------- 3. Reescribir rutas ----------
Write-Host "== Rutas"
$claves = $reescrituras.Keys | Sort-Object { $_.Length } -Descending
$textos = Get-ChildItem -Path . -Recurse -File | Where-Object { $_.Extension -in ".gd",".tscn",".tres",".import",".godot",".cfg" -and $_.FullName -notmatch "\\\.godot\\|\\_a_eliminar\\" }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$n = 0
foreach ($f in $textos) {
    $t = [IO.File]::ReadAllText($f.FullName)
    $t0 = $t
    foreach ($k in $claves) { $t = $t.Replace($k, $reescrituras[$k]) }
    if ($t -ne $t0) {
        $n++
        $cuantas = ([regex]::Matches($t0, "res://")).Count
        Write-Host "  $($f.FullName.Substring((Get-Location).Path.Length + 1))"
        if (-not $Simular) {
            # Conserva el BOM si lo tenía (los .gd del proyecto no lo llevan; los .ps1 sí)
            $bytes = [IO.File]::ReadAllBytes($f.FullName)
            $conBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            [IO.File]::WriteAllText($f.FullName, $t, $(if ($conBom) { New-Object System.Text.UTF8Encoding($true) } else { $utf8 }))
        }
    }
}
Write-Host "Archivos con rutas reescritas: $n"
if (-not $Simular) {
    if (Test-Path "poc_25d") { $resto = Get-ChildItem poc_25d -Recurse -File; if ($resto) { Write-Host "QUEDA en poc_25d/ (revisar a mano):"; $resto | ForEach-Object { Write-Host "   $($_.FullName)" } } else { Remove-Item poc_25d -Recurse -Force } }
    $huerfanas = Select-String -Path ($textos | Where-Object { $_.Extension -in ".gd",".tscn",".tres" }).FullName -Pattern "res://poc_25d/" -SimpleMatch
    if ($huerfanas) { Write-Host "AVISO: quedan rutas res://poc_25d/ (revisar):"; $huerfanas | ForEach-Object { Write-Host "   $($_.Path):$($_.LineNumber)" } }
    else { Write-Host "OK: ninguna ruta res://poc_25d/ queda en el código." }
}
Write-Host ""
Write-Host "Después (Pablo): project.godot -> run/main_scene=`"res://escenas/PruebaBosque.tscn`"; abrir Godot (reimporta los modelos: tarda);"
Write-Host "arrancar el Bosque; pruebas: godot --headless --path . --script res://herramientas/prueba_agua_sim.gd (y las demás prueba_*.gd)."
