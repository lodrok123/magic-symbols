extends "res://herramientas/escenario_base.gd"
## CAPTURAS COMPARATIVAS DE LA CAPA 1 DE CONTRASTE (5/11). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_contraste_capa1.gd -- [carpeta] [grados]   (por defecto res://docs/capturas/contraste_capa1 y 0 grados: `grados` se suma a la inclinación del sol, p. ej. 20 = sol más bajo y sombras largas)
## Tres sitios del Bosque 01 (prado, santuario, linde) a tres horas (10, 17 y 22 h), cada uno con la luz de antes (`ContrasteLuz3D.ACTIVO = false`) y con la capa 1.
## El reloj del día se para; al final se deja la hora y el preset como estaban. Se miran a ojo (no hay `_ok`); el contraste se mide aparte.

const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"
const SITIOS: Array = [["prado", Vector2i(13, 15)], ["santuario", Vector2i(24, 15)], ["linde", Vector2i(3, 10)]]
const HORAS: Array = [10.0, 17.0, 22.0]
const TAM_REGION: float = 12.0
const T_ASENTAR: float = 1.5
var _dir: String = "res://docs/capturas/contraste_capa1"
var _inclinacion_extra: float = 0.0        ## grados que se suman al sol (0 = como en el juego)


func _escenario() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	if a.size() > 1 and a[1].is_valid_float():
		_inclinacion_extra = float(a[1])
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Flags.nuevo()
	Misiones.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	lanzador.tinta = null
	_ocultar_ui(root)
	await avanzar(30)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	var activo_inicial: bool = ContrasteLuz3D.ACTIVO
	CicloDia3D.DURACION_DIA_S = 0.0
	LuzZona3D.SOL_INCLINACION_EXTRA = _inclinacion_extra
	for s in SITIOS:
		var sitio: String = String(s[0])
		await _mirar(s[1] as Vector2i, TAM_REGION, T_ASENTAR)
		for h in HORAS:
			CicloDia3D.HORA = float(h)
			for con in [false, true]:
				ContrasteLuz3D.poner(con, maqueta as Node3D)
				await avanzar_s(0.6)
				_foto("%s_h%02d_%s" % [sitio, int(h), "capa1" if con else "antes"])
	ContrasteLuz3D.poner(activo_inicial, maqueta as Node3D)
	LuzZona3D.SOL_INCLINACION_EXTRA = 0.0
	CicloDia3D.reiniciar()
	CicloDia3D.DURACION_DIA_S = 600.0
	print("capturas en " + _dir)


func _mirar(c: Vector2i, tam: float, s: float) -> void:
	colocar_jugador(c)
	maqueta.set("_tam_camara", tam)
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	if cam != null:
		cam.size = tam
	await avanzar_s(s)


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
