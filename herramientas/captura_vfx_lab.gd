extends SceneTree

## CAPTURA DENTRO DEL LABORATORIO DE HECHIZOS (Pipeline, 18/10, H5): carga `LabHechizos3D.tscn` (la maqueta de verdad, con el Lanzador3D, el jugador, el
## agua y el VfxEstado3D conectado en `prueba_test2.gd`), lanza seis recetas por el camino rápido del lab (`lab.lanzar()`, la misma señal `hechizo_v2` que
## el conjuro completo) y guarda una foto a los 0,35 s y otra a los 1,2 s de cada una. Sirve para MIRAR si lo dibujado casa con lo que pasa: los bloques de
## roca sobre las casillas, las copias de lado, el camino del que viaja, el agua real bajo la masa del VFX.
## Necesita un renderizador (no vale --headless). Desde la carpeta del proyecto, en un cmd:
##   "tools\Godot_v4.7.2-stable_win64.exe" --path . --script res://herramientas/captura_vfx_lab.gd -- pipeline_output\lab [ancho alto] [receta]
##   (en Linux sin pantalla: xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_vfx_lab.gd -- /tmp/lab)
## Escribe `<prefijo>_<n>_<receta>_<momento>.png`. Con `receta` (el nombre, p. ej. `fuego_zona`) hace solo esa. Imprime las medidas de cada señal
## (volumen, estado, persiste, suelo, nº de eventos y de casillas) para compararlas con la foto.
## NO está probada por mí dentro del proyecto real (en mi sandbox no está el repo entero): si falla la carga, el aviso dice en qué paso.

const RUTA_LAB: String = "res://laboratorios/LabHechizos3D.tscn"
const MOMENTOS: Array = [0.35, 1.2]
## [nombre, elemento (el del lab: fire, water, earth, ice, lightning, wind, time), {glifo: veces}]
const RECETAS: Array = [
	["fuego_zona", "fire", {"linea_x": 2, "linea_z": 2}],
	["tierra_muro_copias", "earth", {"linea_x": 2, "altura": 1, "repeticion": 2}],
	["viento_viaja_rebota", "wind", {"flecha": 2, "rebote": 1}],
	["rayo_linea", "lightning", {"linea_z": 2}],
	["agua_masa", "water", {"linea_x": 1, "altura": 1}],
	["hielo_columna", "ice", {"linea_x": 1, "linea_z": 1, "altura": 1}],
]

var _lab: Node = null
var _medidas: Array = []


func _init() -> void:
	_correr()


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.is_empty():
		print("uso: -- <prefijo_salida> [ancho alto] [receta]")
		quit(1)
		return
	var salida: String = a[0]
	var ancho: int = int(a[1]) if a.size() > 2 else 1280
	var alto: int = int(a[2]) if a.size() > 2 else 720
	var filtro: String = a[3] if a.size() > 3 else ""
	root.size = Vector2i(ancho, alto)
	var paquete: PackedScene = load(RUTA_LAB) as PackedScene
	if paquete == null:
		print("FALLO: no carga ", RUTA_LAB)
		quit(1)
		return
	var maqueta: Node = paquete.instantiate()
	root.add_child(maqueta)
	# 1. esperar a que la maqueta monte el lanzador y el jugador, y a que se levante el velo de precalentado (compila los efectos; unos segundos de pared)
	var lanzador: Node = null
	var n: int = 0
	while n < 600 and (get_first_node_in_group("spellcaster") == null):
		await process_frame
		n += 1
	lanzador = get_first_node_in_group("spellcaster")
	if lanzador == null:
		print("FALLO: la maqueta no montó el Lanzador3D tras ", n, " fotogramas")
		quit(1)
		return
	var jugador: Object = lanzador.get("jugador")
	var pared: int = Time.get_ticks_msec()
	while jugador != null and not bool(jugador.call("puede_lanzar")) and Time.get_ticks_msec() - pared < 30000:
		await process_frame
	for _i in range(30):
		await process_frame
	_lab = maqueta.get_node_or_null("Reglas")
	if _lab == null:
		print("FALLO: la maqueta no tiene el nodo «Reglas» (el lab)")
		quit(1)
		return
	var vfx: Node = maqueta.get_node_or_null("VfxEstado3D")
	print("VfxEstado3D conectado en la maqueta: ", vfx != null)
	lanzador.connect("hechizo_v2", _al_hechizo)
	# 2. las recetas
	var i: int = 0
	for rec in RECETAS:
		i += 1
		if filtro != "" and filtro != String(rec[0]):
			continue
		_lab.call("limpiar")
		_lab.call("poner_elemento", String(rec[1]))
		for glifo in (rec[2] as Dictionary):
			_lab.call("sumar", String(glifo), int((rec[2] as Dictionary)[glifo]))
		_medidas.clear()
		_lab.call("lanzar")
		print("%s: %s" % [rec[0], str(_medidas)])
		var t_ant: float = 0.0
		for m in MOMENTOS:
			await create_timer(float(m) - t_ant).timeout
			t_ant = float(m)
			var img: Image = root.get_texture().get_image()
			var ruta: String = "%s_%d_%s_%s.png" % [salida, i, rec[0], str(m).replace(".", "")]
			img.save_png(ruta)
			print("guardada ", ruta, " ", img.get_size())
		await create_timer(10.0).timeout        # que se acabe lo de esta receta (tierra dura 8 s) antes de la siguiente
	print("hechizos vivos de VfxEstado3D al final: ", vfx.call("activos") if vfx != null else -1)
	quit(0)


func _al_hechizo(estado: String, elemento: String, g: Dictionary, _o: Vector3, _d: Vector3, p: Dictionary) -> void:
	_medidas.append({"estado": estado, "elemento": elemento, "xyz": [g.get("x"), g.get("y"), g.get("z")], "persiste": g.get("persiste"), "suelo": g.get("suelo"),
		"t_caida": g.get("t_caida"), "eventos": (g.get("eventos", []) as Array).size(), "celdas": (g.get("celdas", []) as Array).size(), "props": p})
