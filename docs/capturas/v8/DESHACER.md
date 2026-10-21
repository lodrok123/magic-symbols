# V8 · cómo DESHACER lo aplicado (21/10/2026)

Todo está en copia en carpetas con `.gdignore` (Godot no las importa). Los comandos son de PowerShell, desde la raíz del proyecto, con Godot **cerrado**.
`$g` = ruta de `tools/godot_local.txt`:  `$g = (Get-Content tools/godot_local.txt).Trim()`

## 1. Árboles (Nivel_Bosque_01.tscn)
En `mundo/datos_nivel/Nivel_Bosque_01.tscn` la primera línea `ext_resource` decía
`path="res://arte/piezas/arbol_redondo.tscn" id="2_arbol_redondo"` y ahora dice `arbol_redondo_2.tscn` (con el mismo id). Para volver: cambia
`arbol_redondo_2.tscn" id="2_arbol_redondo"` por `arbol_redondo.tscn" id="2_arbol_redondo"` (una sola línea), o copia el nivel entero de antes:
`Copy-Item arte/piezas/_anteriores_v8/Nivel_Bosque_01_antes_v8.tscn mundo/datos_nivel/Nivel_Bosque_01.tscn -Force`
(esa copia se hizo justo antes del cambio y **también deshace** el quitar de los `uid=` obsoletos de `arbol_redondo_2` y `pino_2`; si el nivel se ha tocado desde entonces, mejor la línea).
`arbol_redondo.tscn` no se ha tocado ni borrado.

## 2. Piezas de 12 k (una por una: .glb + escena horneada, luego reimportar)
Los originales de 12 k están en `arte/meshy/piezas/_anteriores_v8/` (.glb y sus jpg) y `arte/piezas/_anteriores_v8/` (.tscn horneado).

```powershell
# roca_musgosa
Copy-Item arte/meshy/piezas/_anteriores_v8/roca_musgosa.glb arte/meshy/piezas/roca_musgosa.glb -Force
Copy-Item arte/piezas/_anteriores_v8/roca_musgosa.tscn arte/piezas/roca_musgosa.tscn -Force
# tronco_musgoso
Copy-Item arte/meshy/piezas/_anteriores_v8/tronco_musgoso.glb arte/meshy/piezas/tronco_musgoso.glb -Force
Copy-Item arte/piezas/_anteriores_v8/tronco_musgoso.tscn arte/piezas/tronco_musgoso.tscn -Force
# troncos_apilados
Copy-Item arte/meshy/piezas/_anteriores_v8/troncos_apilados.glb arte/meshy/piezas/troncos_apilados.glb -Force
Copy-Item arte/piezas/_anteriores_v8/troncos_apilados.tscn arte/piezas/troncos_apilados.tscn -Force
# y, al final (una vez, vale para las tres): reimportar para que Godot vuelva a sacar las texturas del .glb
& $g --headless --path . --import
```
Para deshacer solo una, haz solo su par de `Copy-Item` y el `--import`.

## 3. Roca a 2,5 k en vez de 6 k (para comparar en el juego)
```powershell
Copy-Item arte/meshy/aprobacion3d/v8_piezas/roca_musgosa_2500.glb arte/meshy/piezas/roca_musgosa.glb -Force
& $g --headless --path . --import
& $g --headless --path . --script res://herramientas/generar_piezas_ids.gd -- roca_musgosa
```
(Para volver a 6 k: lo mismo con `roca_musgosa_6000.glb`.) Los 6 k de las tres piezas están en `arte/meshy/aprobacion3d/v8_piezas/<id>_6000.glb`.

## 4. Capturas de comparación 12 k / 6 k / 2,5 k
`docs/capturas/v8/piezas_6k/` (se rehacen con `herramientas/captura_piezas_v8.gd`, con ventana).