# Pack «SH assets» (prueba, 25/11/2026)

Kit de casa rústica de entramado de madera y piedra que Pablo pasó como `C:\Users\pablo\Downloads\SH assets.blend`.
El inventario completo está en `C:\Users\pablo\Documents\magic-symbols\INVENTARIO_SH_ASSETS_2026-11-25.md`.

**Licencia y autor: sin identificar.** Por eso no viaja nada del pack en git (ver `.gitignore`): solo este LEEME.

## Qué hay aquí (fuera de git)
- `casa_sh_sin_optimizar.glb`: una casa montada con las piezas del pack **tal cual** (1,68 M triángulos, 391 objetos, 21 materiales).
  Los materiales procedurales del pack se sustituyen por un color plano con el mismo nombre.
- `casa_sh_sin_optimizar.json`: sus cifras.

## Regenerar
```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b "C:\Users\pablo\Downloads\SH assets.blend" --python E:\magic-symbols\tools\montar_casa_sh.py -- E:\magic-symbols\arte\sh_assets\casa_sh_sin_optimizar.glb
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --headless --path E:\magic-symbols --import
```

## Dónde se ve
`laboratorios/LabCasasSH.tscn`: rejilla de 0 a 25 casas con la luz y la cámara del juego, y medición de rendimiento (`-- --medir`).
