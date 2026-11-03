extends SceneTree
## HORNEAR «BOSQUE 02» (Juego, 3/11): genera mundo/datos_nivel/Nivel_Bosque_02.tscn DESDE mapas/Bosque_02.txt.
##   godot --headless --path . --script res://herramientas/hornear_bosque_02.gd
##
## Carga escenas/PruebaBosque02.tscn con `usar_escena = false` (el nivel sale de las LETRAS del .txt, como en `hornear_bosque_01_v01.gd`), le quita las reglas y los puzles (no hay .tscn que leer
## todavía) y llama a `hornear()`, que es lo que hace la tecla F9. Las líneas `; nombre`, `; marcador` y `; decorado` del .txt las pone HorneadorNivel.leer_extras.
## A diferencia del v01 NO hay segundo paso de «retoques»: el Bosque 02 es nuevo y no hereda ediciones de otro nivel.
##
## CUIDADO, ESCRIBE EN EL REPO: pisa Nivel_Bosque_02.tscn (si ya existía, HorneadorNivel lo aparta como `..._copia_<hora>.tscn`; esa copia se borra salvo con `-- conservar`).
## No lo lances con Godot abierto sobre el proyecto.

const ESCENA: String = "res://escenas/PruebaBosque02.tscn"
const FOTOGRAMAS_ESPERA: int = 60

var _copias_antes: PackedStringArray = []


func _initialize() -> void:
	await process_frame
	_copias_antes = _copias()
	var ok: bool = await _hornear()
	for f in _copias():
		if not _copias_antes.has(f) and not OS.get_cmdline_user_args().has("conservar"):
			print("  (se borra la copia que apartó el horneado: ", f, ")")
			DirAccess.remove_absolute(HorneadorNivel.NIVELES + f)
	quit(0 if ok else 1)


func _hornear() -> bool:
	var ps: PackedScene = load(ESCENA) as PackedScene
	if ps == null:
		push_error("no carga " + ESCENA)
		return false
	var maqueta: Node = ps.instantiate()
	for n in ["Reglas", "Puzles"]:
		var h: Node = maqueta.get_node_or_null(n)
		if h != null:
			maqueta.remove_child(h)
			h.free()
	maqueta.set("usar_escena", false)
	root.add_child(maqueta)
	for _i in range(FOTOGRAMAS_ESPERA):
		await process_frame
	var ruta: String = String(maqueta.call("hornear"))
	print("horneado: ", ruta if ruta != "" else "(nada: mira la consola)")
	maqueta.queue_free()
	await process_frame
	return ruta != ""


func _copias() -> PackedStringArray:
	var r: PackedStringArray = []
	var d: DirAccess = DirAccess.open(HorneadorNivel.NIVELES)
	if d != null:
		for f in d.get_files():
			if f.begins_with("Nivel_Bosque_02_copia_"):
				r.append(f)
	r.sort()
	return r
