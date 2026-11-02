extends "res://herramientas/escenario_base.gd"
## CAPTURAS DE LUCES A VARIAS HORAS (Bosque 01 v01, 2/11). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_luces_horas.gd -- [carpeta]   (por defecto res://docs/capturas/luces_horas)
## Dos sitios del mapa (el prado y el santuario) a varias horas del ciclo de día y noche (CicloDia3D), cada hora con las sombras del sol activadas y desactivadas.
## El reloj del día se para (DURACION_DIA_S = 0) y la hora se fija a mano. Al terminar deja la hora y la duración del día como estaban por defecto.

const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"
const HORAS: Array = [4.0, 7.0, 10.0, 13.0, 17.0, 19.5, 22.0]
const SITIOS: Array = [["prado", Vector2i(13, 15)], ["santuario", Vector2i(24, 15)]]
const TAM_REGION: float = 12.0
const T_ASENTAR: float = 1.5
const DURACION_DIA_DEFECTO: float = 600.0

var _dir: String = "res://docs/capturas/luces_horas"


func _escenario() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
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
	CicloDia3D.DURACION_DIA_S = 0.0
	var ciclo: CicloDia3D = maqueta.get_node_or_null("CicloDia3D") as CicloDia3D
	if ciclo == null:
		ciclo = CicloDia3D.montar(maqueta as Node3D, true)
	if ciclo == null:
		print("AVISO: no hay CicloDia3D en el mapa; las fotos saldrán sin ciclo")
	var sol: DirectionalLight3D = maqueta.get("_sol") as DirectionalLight3D
	if sol == null:
		print("AVISO: la maqueta no tiene _sol; no se pueden alternar las sombras")
		return
	var sombra_inicial: bool = sol.shadow_enabled
	for s in SITIOS:
		var sitio: String = String(s[0])
		await _mirar(s[1] as Vector2i, TAM_REGION, T_ASENTAR)
		for h in HORAS:
			var hora: float = float(h)
			CicloDia3D.HORA = hora
			if ciclo != null:
				ciclo.aplicar()
			sol.shadow_enabled = true
			await avanzar_s(0.5)
			_foto("%s_%s_sombra" % [sitio, _nombre_hora(hora)])
			sol.shadow_enabled = false
			await avanzar_s(0.5)
			_foto("%s_%s_sin_sombra" % [sitio, _nombre_hora(hora)])
	sol.shadow_enabled = sombra_inicial
	CicloDia3D.HORA = CicloDia3D.HORA_INICIO
	CicloDia3D.DURACION_DIA_S = DURACION_DIA_DEFECTO
	print("capturas en " + _dir)


## 4.0 -> "h04", 19.5 -> "h19m30".
func _nombre_hora(h: float) -> String:
	var horas: int = int(h)
	var minutos: int = roundi((h - float(horas)) * 60.0)
	if minutos == 0:
		return "h%02d" % horas
	return "h%02dm%02d" % [horas, minutos]


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
