extends "res://herramientas/escenario_base.gd"
## CAPTURA DE LA LUZ POR BIOMA (26/11/2026, Pablo: «revisa la iluminación y cómo afecta en los distintos biomas: ruinas y bosque»).
## Los mismos sitios del bosque y de las ruinas con la cámara del juego, cada uno de tres maneras:
##   · «propia»: la luz que tiene ahí en el juego (zona del mapa con Zonas3D, ciclo de día parado a las 10 h = la zona tal cual).
##   · «bosque» y «ruinas»: la misma vista con esa fila de LuzZona3D forzada (Zonas3D y el ciclo parados).
## Imprime el sol y el ambiente que quedan de verdad en cada foto (LUZ …). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_luz_biomas.gd [-- carpeta [prefijo]]   (prefijo: solo esos sitios, p. ej. «ruinas»)
## Fotos en docs/capturas/luz_biomas/ (<sitio>_<luz>.png).

const SITIOS: Array = [
	# [nombre, escena, casilla (-1 = donde aparece la jugadora)]
	["b01_explanada", "res://escenas/PruebaBosque01_v01.tscn", Vector2i(24, 30)],
	["b01_prado", "res://escenas/PruebaBosque01_v01.tscn", Vector2i(13, 15)],
	["b01_hondonada", "res://escenas/PruebaBosque01_v01.tscn", Vector2i(40, 19)],
	["b01_escondite", "res://escenas/PruebaBosque01_v01.tscn", Vector2i(14, 26)],
	["b02_plaza_oeste", "res://escenas/PruebaBosque02.tscn", Vector2i(9, 20)],
	["ruinas_gen", "res://escenas/PruebaRuinasGen.tscn", Vector2i(-1, -1)],
	["ruinas_trampas", "res://escenas/PruebaRuinasTrampas.tscn", Vector2i(-1, -1)],
]
const LUCES_FORZADAS: Array = ["bosque", "ruinas"]
const TAM_CAMARA: float = 12.0

var _dir: String = "res://docs/capturas/luz_biomas"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	CicloDia3D.HORA = 10.0
	CicloDia3D.DURACION_DIA_S = 0.0
	var escena_cargada: String = ""
	var solo: String = a[1] if a.size() > 1 else ""       # «-- carpeta prefijo»: solo los sitios que empiezan así
	for s in SITIOS:
		if solo != "" and not String(s[0]).begins_with(solo):
			continue
		if String(s[1]) != escena_cargada:
			if maqueta != null:
				maqueta.queue_free()
				await avanzar(3)
			Flags.nuevo()
			Misiones.nuevo()
			await cargar(String(s[1]), true)
			if maqueta == null:
				print("NO CARGA ", s[1])
				continue
			escena_cargada = String(s[1])
			for n in get_nodes_in_group("combate3d"):
				(n as Combate3D).quieto = true
			_ocultar_ui(root)
			await avanzar(20)
		var c: Vector2i = s[2]
		if c.x >= 0:
			colocar_jugador(c)
		maqueta.set("_tam_camara", TAM_CAMARA)
		var cam: Camera3D = maqueta.get("_camara") as Camera3D
		if cam != null:
			cam.size = TAM_CAMARA
		_parar(false)
		await avanzar_s(6.5)                   # Zonas3D mezcla hasta 5 s al entrar
		await _foto("%s_propia" % s[0])
		_parar(true)
		for z in LUCES_FORZADAS:
			LuzZona3D.aplicar(maqueta.get("_env") as Environment, maqueta.get("_sol") as DirectionalLight3D, String(z))
			await avanzar(8)
			await _foto("%s_%s" % [s[0], z])
	quit(0)


## Para (o reanuda) lo que reescribe la luz cada fotograma: las zonas del mapa y el ciclo de día.
func _parar(si: bool) -> void:
	for n in maqueta.find_children("*", "", true, false):
		if n is Zonas3D or n is CicloDia3D:
			n.set_process(not si)
			n.set_physics_process(not si)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	var sol: DirectionalLight3D = maqueta.get("_sol") as DirectionalLight3D
	var env: Environment = maqueta.get("_env") as Environment
	var cielo: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial if env != null and env.sky != null else null
	var z: Node = null
	for n in maqueta.find_children("*", "", true, false):
		if n is Zonas3D:
			z = n
	print("LUZ %s | zona=%s | sol %s x%.2f pitch %.0f | amb arriba %s abajo %s x%.2f | exp %.2f" % [nombre,
		String(z.get("nombre_actual")) if z != null else "-",
		_c(sol.light_color), sol.light_energy, sol.rotation_degrees.x,
		_c(cielo.sky_top_color) if cielo else "-", _c(cielo.ground_bottom_color) if cielo else "-", env.ambient_light_energy, env.tonemap_exposure])


func _c(c: Color) -> String:
	return "(%.2f %.2f %.2f)" % [c.r, c.g, c.b]


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
