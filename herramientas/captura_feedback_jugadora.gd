extends "res://herramientas/escenario_base.gd"
## FEEDBACK DE LA JUGADORA AL RECIBIR UN GOLPE (22/11, dirección; revisión pedida por Pablo: «creo que es pobre»).
## Graba, fotograma a fotograma, lo que se ve cuando la jugadora encaja un golpe: (1) uno pequeño (12, flecha del arquero) con la vida llena;
## (2) uno grande (45, puñetazo del elemental); (3) uno que la deja con poca vida (por debajo del 25 %). Cada foto: la pantalla entera reducida
## y, al lado, un recorte alrededor de ella. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_feedback_jugadora.gd -- [carpeta]

const PASO_FOTOGRAMAS: int = 2
const DURA_S: float = 0.9
var _dir: String = "res://docs/capturas/feedback_jugadora"


func _escenario() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "":
		_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaSalaGolem.tscn", true)
	if maqueta == null or jugador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var g: Node3D = z.nodo("golem_a") as Node3D if z != null else null
	if g != null:
		g.set("quieto", true)
		g.position = Terreno3D.centro_de(Vector2i(14, 1), Terreno3D.y_pies(Vector2i(14, 1)))
	colocar_jugador(Vector2i(6, 6))
	await avanzar_s(1.0)
	var j: Jugador3D = jugador as Jugador3D
	var vmax: float = Estado.i().vida_max
	j.vida = vmax
	await _golpe(j, 12.0, "pequeno")
	await avanzar_s(1.5)
	j.vida = vmax
	await _golpe(j, 45.0, "grande")
	await avanzar_s(1.5)
	j.vida = vmax * 0.35
	await _golpe(j, 15.0, "vida_baja")
	await avanzar_s(0.5)


func _golpe(j: Jugador3D, cantidad: float, nombre: String) -> void:
	await _foto(j, "%s_00_antes" % nombre)
	j.recibir_dano(cantidad, j.global_position + Vector3(1.5, 0.0, 0.0))
	print("golpe %s: %.0f de daño, vida %.0f" % [nombre, cantidad, j.vida])
	var k: int = 1
	var t0: float = reloj.t
	while reloj.t - t0 < DURA_S:
		await _foto(j, "%s_%02d_t%.2f" % [nombre, k, reloj.t - t0])
		k += 1
		for _i in range(PASO_FOTOGRAMAS - 1):
			await process_frame


func _foto(j: Node3D, archivo: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var c: Vector2 = lanzador.camara.unproject_position(j.global_position + Vector3(0.0, 0.8, 0.0))
	var w: int = 360
	var h: int = 360
	var x0: int = clampi(int(c.x) - w / 2, 0, img.get_width() - w)
	var y0: int = clampi(int(c.y) - h / 2, 0, img.get_height() - h)
	var rec: Image = img.get_region(Rect2i(x0, y0, w, h))
	var peq: Image = img.duplicate()
	peq.resize(640, 360)
	var hoja := Image.create(640 + 360, 360, false, img.get_format())
	hoja.blit_rect(peq, Rect2i(0, 0, 640, 360), Vector2i(0, 0))
	hoja.blit_rect(rec, Rect2i(0, 0, w, h), Vector2i(640, 0))
	hoja.save_png(_dir.path_join(archivo + ".png"))
