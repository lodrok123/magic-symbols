# Pack «SH assets» (prueba, 25/11/2026)

Kit de casa rústica de entramado de madera y piedra que Pablo pasó como `C:\Users\pablo\Downloads\SH assets.blend`.
El inventario completo está en `C:\Users\pablo\Documents\magic-symbols\INVENTARIO_SH_ASSETS_2026-11-25.md`.

**Licencia y autor: sin identificar.** Por eso no viaja nada del pack en git (ver `.gitignore`): solo este LEEME.

## Qué hay aquí (fuera de git)
- `casa_sh_sin_optimizar.glb`: una casa montada con las piezas del pack **tal cual** (1,68 M triángulos, 391 objetos, 21 materiales).
  Los materiales procedurales del pack se sustituyen por un color plano con el mismo nombre.
- `casa_sh_d50.glb`: la misma casa con un Decimate al 50 % en cada pieza (838 k triángulos, 391 objetos).
- `casa_sh_d50_unida.glb`: diezmada al 50 % y unida en UN objeto (838 k triángulos, 1 objeto, 21 superficies).
- `*.json`: las cifras de cada una.

Comparativa medida (25/11/2026, RTX 3070): `docs/capturas/casas_sh/comparativa_pasada1.txt` y `_pasada2.txt`.

- `atrezo/sh_*.glb`: los 64 objetos pequeños (contenedores, adornos, cerámica, piedra, vegetación), uno por archivo, con sus
  TEXTURAS REALES horneadas (`--hornear`: una malla y un material por objeto); `atrezo/atrezo_sh.json` con sus cifras.
  Inventario para niveles: `docs/INVENTARIO_ATREZO_SH.md`. Se ven en `laboratorios/LabAtrezoSH.tscn`.
  **Monte Sumicio los usa** (`escenas/monte_sumicio_atrezo.gd`): sin estos archivos el pueblo sale sin atrezo y lo avisa.

## Regenerar
```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b "C:\Users\pablo\Downloads\SH assets.blend" --python E:\magic-symbols\tools\montar_casa_sh.py -- E:\magic-symbols\arte\sh_assets\casa_sh_sin_optimizar.glb
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b "C:\Users\pablo\Downloads\SH assets.blend" --python E:\magic-symbols\tools\montar_casa_sh.py -- E:\magic-symbols\arte\sh_assets\casa_sh_d50.glb --diezmar 0.5
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b "C:\Users\pablo\Downloads\SH assets.blend" --python E:\magic-symbols\tools\montar_casa_sh.py -- E:\magic-symbols\arte\sh_assets\casa_sh_d50_unida.glb --diezmar 0.5 --unir
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b "C:\Users\pablo\Downloads\SH assets.blend" --python E:\magic-symbols\tools\exportar_atrezo_sh.py -- E:\magic-symbols\arte\sh_assets\atrezo --hornear --bajo
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --headless --path E:\magic-symbols --import
```

## Dónde se ve
`laboratorios/LabCasasSH.tscn`: rejilla de 0 a 25 casas con la luz y la cámara del juego, y medición de rendimiento (`-- --medir`).
