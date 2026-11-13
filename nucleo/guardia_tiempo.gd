class_name GuardiaTiempo
extends Node
## TOPE DE LA CÁMARA LENTA (13/11/2026, playtest de Pablo: tras matar a un enemigo el juego se quedó ralentizado).
## Varios efectos bajan `Engine.time_scale` y guardan «lo que había» para devolverlo (pausa de impacto, cámara lenta del último enemigo,
## modo lanzar, libro, tiempo bruja). Si dos se pisan, uno puede devolver la escala lenta del otro y el juego se queda a 0,3 para siempre.
## Este guardián cuenta el tiempo REAL con la escala por debajo de 1: si pasa de TOPE_S y nadie con derecho a ralentizar lo está haciendo
## (libro abierto, apuntando, grimorio abierto, tiempo bruja, árbol en pausa), devuelve el tiempo a 1. Lo monta Jugador3D con cada nivel.

const TOPE_S := 2.0                 ## s reales: los efectos de impacto duran ≤ 0,7 s
static var correcciones := 0        ## veces que ha tenido que intervenir (las pruebas y el diario de juego)

var _lento_ms := 0                  ## ticks en que empezó la escala lenta (0 = va a 1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if Engine.time_scale >= 0.99 or get_tree().paused or _ralentizado_con_derecho():
		_lento_ms = 0
		return
	var ahora := Time.get_ticks_msec()
	if _lento_ms == 0:
		_lento_ms = ahora
		return
	if ahora - _lento_ms >= int(TOPE_S * 1000.0):
		PlayLog.event("tiempo_corregido", {"escala": snappedf(Engine.time_scale, 0.01), "segundos": snappedf((ahora - _lento_ms) / 1000.0, 0.1)})
		Logros3D.restaurar_tiempo()
		Engine.time_scale = 1.0
		correcciones += 1
		_lento_ms = 0


func _ralentizado_con_derecho() -> bool:
	if TiempoBruja.activa():
		return true
	var lz: Node = get_tree().get_first_node_in_group("spellcaster")
	if lz != null and (bool(lz.get("modo_lanzar")) or (lz.has_method("libro_abierto") and bool(lz.call("libro_abierto")))):
		return true
	for g in get_tree().root.find_children("*", "GrimorioUI", true, false):
		if bool(g.get("abierto")):
			return true
	return false
