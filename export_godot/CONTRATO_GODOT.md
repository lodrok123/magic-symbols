# Contrato de exportacion a Godot

Todo lo que entra en `export_godot\` ya esta aprobado en su `REPORTE.md`.
Godot no importa `pipeline\` ni `pipeline_output\` (llevan `.gdignore`).

## Estructura

```
export_godot/
  characters/<id>/   enemies/<id>/   terrain/<id>/
    sprites/<animacion>/<DIR>/frame_000.png   (o atlas/<animacion>.png)
    meta.json
    REPORTE.md        copia del informe de aprobacion
```

## meta.json (minimo)

```json
{
  "id": "ranger_prueba",
  "tipo": "character",
  "direcciones": ["S","SW","W","NW","N","NE","E","SE"],
  "animaciones": {"idle": {"frames": 0, "fps": 0, "loop": true}},
  "frame_px": [0, 0],
  "ancla_suelo_px": [0, 0],
  "origen": "pipeline_output/<id>/art/model/npc_processed.glb",
  "aprobado": "AAAA-MM-DD"
}
```

Enemigos: ademas `hitbox_px` y animaciones `attack`, `hit`, `death` (death sin bucle).
Terreno: sin direcciones ni animaciones; `tile_px`, `variantes`.

## Revision previa a exportar (todo en `pipeline_output/<id>/`)

- `REPORTE.md`: veredicto tecnico + arte
- `art/review/`: hojas para mirar a ojo
- `art/renders/`, `art/model/`, `art/reports/`
- `atlases/`, `reports/`

## Estructura de trabajo y contrato v1.1

    pipeline/inbox/<id>/            GLB + asset.json (id estable en minusculas, prefijo de tipo: tree_*, enemy_*, character_*)
    pipeline_output/<id>/           trabajo: intermedios, logs, REPORTE.md
    export_godot/<tipo>/<id>/       solo aprobados + meta.json
    pipeline/archive/<id>/          originales ya aprobados
    pipeline/scenes/<id>/scene.json escenas (terreno): mapa, reglas, arboles usados
    pipeline/catalogo.json          estado, version, hash, licencia de cada asset

Carpetas de export_godot: characters/, enemies/, trees/, props/, weapons/, terrain/, demo/.
trees/props/weapons/<id>/meta.json: {id, tipo, version, altura_px, angulos, sprites[], ancla:"base_centro", licencia, aprobado}.
terrain/<id>/: map*.png, sprites/, meta.json (tile_px [128,64]).
La licencia con atribucion_requerida (p.ej. CC-BY) debe acreditarse en el juego.

### Escena demo (res://export_godot/demo/demo.tscn)
Carga cada meta.json de characters/ y enemies/, valida estructura (campos, atlas, 8 direcciones, regiones, tamano de frame, ancla/offset)
y permite mover (WASD), correr (Shift), cambiar personaje (Tab/Q) y forzar idle/walk/run (1/2/3). Si falta `run` usa walk x1.6.
