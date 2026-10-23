extends "res://herramientas/escenario_base.gd"
## LA CUEVA (23/10, docs/PLAN_BOSQUE_EOW.md §6): monta, fotografía cada sala y recorre el bucle. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_cueva.gd -- [carpeta]   (por defecto res://docs/capturas/cueva)
## 1 · Puzle3D monta todas las piezas del mapa sin avisos.
## 2 · Una foto por sala (la jugadora en el centro, la cámara abierta): para mirar paredes, esquinas y luz.
## 3 · El recorrido, haciendo por código lo que haría la jugadora:
##     C1 los dos braseros → se abre el paso norte · C2 dos golpes de tierra → el muro cae · C3 agua → la lava se enfría
##     C4 caen los goblins → aparece el cofre → al abrirlo, la llave → se abre la puerta de C6 · setas: coger una y otra tras fuego.

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const SALAS: Dictionary = {"C1_boca": Vector2i(4, 14), "C2_grietas": Vector2i(4, 4), "C3_lava": Vector2i(11, 4),
	"C4_cerrada": Vector2i(21, 4), "C5_charca": Vector2i(22, 18), "C6_tesoro": Vector2i(13, 15)}

var _dir: String = "res://docs/capturas/cueva"
var _z: Puzle3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	await avanzar(30)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D

	# 1 · Montaje
	_ok("1 Puzle3D está y monta piezas", _z != null and _z.piezas().size() >= 20, "%d piezas" % (_z.piezas().size() if _z != null else 0))
	if _z != null:
		_ok("1 sin avisos de montaje", _z.avisos.is_empty(), str(_z.avisos))
	var zonas: Zonas3D = maqueta.get_node_or_null("Zonas3D") as Zonas3D
	_ok("1 seis zonas de luz, sin avisos", zonas != null and zonas.zonas.size() == 6 and zonas.avisos.is_empty(), str(zonas.avisos) if zonas != null else "")

	# 2 · Fotos por sala
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	for nombre in SALAS:
		colocar_jugador(SALAS[nombre])
		maqueta.set("_tam_camara", 11.0)
		if cam != null:
			cam.size = 11.0
		await avanzar_s(2.0)       # que entre la luz de la zona (1,5 s)
		_foto(nombre)

	if _z == null:
		return
	# 3 · El recorrido
	# C1: braseros → paso norte
	var paso: Node = _z.nodo("paso_norte")
	_ok("3 C1 el paso norte empieza cerrado", paso != null and not bool(paso.get("abierta")))
	for c in [Vector2i(2, 12), Vector2i(7, 12)]:
		var b: Node = _reactivo_en(c)
		if b != null:
			b.call("encender_llama")
	await avanzar_s(0.5)
	_ok("3 C1 con los dos braseros encendidos se abre el paso norte", paso != null and bool(paso.get("abierta")))
	# C2: dos golpes de tierra al muro
	var muro: MuroAgrietado3D = _z.nodo("grieta") as MuroAgrietado3D
	var tierra: RuneData = load("res://nucleo/earth_rune.tres") as RuneData
	if muro != null:
		colocar_jugador(Vector2i(6, 4))
		await avanzar_s(0.5)
		muro.on_spell_hit(tierra)
		await avanzar_s(0.4)
		_foto("C2_muro_agrietado")
		muro.on_spell_hit(tierra)
		await avanzar_s(0.3)
		_foto("C2_muro_rompiendose")
		await avanzar_s(1.0)
	_ok("3 C2 el muro cae con dos golpes de tierra y libera el paso", muro != null and muro.roto_ya and not Terreno3D.bloqueada(Vector2i(9, 4)))
	# C3: agua sobre la lava (por el impacto del mundo, como cualquier hechizo)
	var lava: Lava3D = _z.nodo("rio") as Lava3D
	if lava != null:
		colocar_jugador(Vector2i(11, 4))
		await avanzar_s(0.5)
		_foto("C3_lava")
		Mundo3D.actual.impacto.emit(Terreno3D.centro_de(Vector2i(13, 4), Terreno3D.y_pies(Vector2i(13, 4))), "agua", 0.5)
		Mundo3D.actual.impacto.emit(Terreno3D.centro_de(Vector2i(14, 4), Terreno3D.y_pies(Vector2i(14, 4))), "agua", 0.5)
		await avanzar_s(0.6)
		_foto("C3_lava_enfriada")
	_ok("3 C3 el agua enfría un paso por la lava", lava != null and not Terreno3D.bloqueada(Vector2i(13, 4)) and not Terreno3D.bloqueada(Vector2i(14, 4)))
	# C4: caen los goblins → cofre → llave → puerta de C6
	var puerta: Node = _z.nodo("puerta_llave")
	for g in maqueta.find_children("*", "Combate3D", true, false):
		var cg: Vector2i = Terreno3D.celda_de((g as Node3D).global_position)
		if cg.x >= 19 and cg.y <= 8:
			g.call("receive_damage", 9999.0)
	await avanzar_s(3.0)
	var cofre: Node = _z.nodo("cofre_llave")
	_ok("3 C4 al caer los goblins aparece el cofre", cofre != null and not bool(cofre.get("es_oculto")))
	if cofre != null:
		cofre.call("abrir")
		await avanzar_s(3.0)
	_ok("3 C4/C6 al abrir el cofre (la llave) se abre la puerta de C6", puerta != null and bool(puerta.get("abierta")))
	# Setas: una tal cual y otra tras fuego
	var s1: Recolectable3D = _z.nodo("seta_c1a") as Recolectable3D
	var s2: Recolectable3D = _z.nodo("seta_c1b") as Recolectable3D
	var antes_seta: int = int(Estado.i().items.get("seta", 0)) if "items" in Estado.i() else 0
	if s1 != null and s2 != null:
		s2.on_spell_hit(load("res://nucleo/fire_rune.tres") as RuneData)
		_ok("3 setas: el fuego la convierte en seta asada", s2.objeto == "seta_asada", s2.objeto)
		s1.recoger()
		s2.recoger()
		_ok("3 setas: se cogen y desaparecen", s1.recogido_ya and s2.recogido_ya)
		_aviso("3 setas en la mochila", "seta %s · seta asada %s" % [str(Estado.i().items.get("seta", 0)) if "items" in Estado.i() else "?", str(Estado.i().items.get("seta_asada", 0)) if "items" in Estado.i() else "?"])
	var variantes: Dictionary = {}
	for n in maqueta.find_children("*", "Recolectable3D", true, false):
		variantes[(n as Recolectable3D).variante] = true
	_ok("3 las setas se intercalan (las tres variantes)", variantes.size() == 3, str(variantes.keys()))


func _reactivo_en(c: Vector2i) -> Node:
	for r in root.get_tree().get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		if is_instance_valid(r) and r.get("celda") == c:
			return r
	return null


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
