class_name Sonidos
extends RefCounted

## ALIAS de `Sfx.play_ui` (31/10, gamefeel tarea M0). Antes este archivo sintetizaba en código cinco sonidos (bolsa, moneda, pocion, recoger, golpe, comprar); ahora son
## .wav en `audio/` (audio/gen_sfx_interfaz.py) dados de alta en `Sfx.CATALOGO` (bus «Interfaz»). Se conserva la firma antigua por si algún código aún la llama;
## los dB del catálogo mandan salvo que se pase `db` (el antiguo -6 por defecto ya no se aplica). Código nuevo: `Sfx.play_ui(nombre)`.

const ALIAS: Dictionary = {"golpe": "golpe_ui"}


## `origen` ya no hace falta (se conserva en la firma). `db` = INF usa el del catálogo; `tono` > 0 fija el pitch.
static func play(_origen: Node, nombre: String, db: float = INF, tono: float = 0.0) -> void:
	Sfx.play_ui(String(ALIAS.get(nombre, nombre)), db, tono)
