extends "res://herramientas/escenario_base.gd"
## SILUETA DE LA JUGADORA Y LA COPA DEL ÁRBOL DEL SUR (11/11, diario): en la tala del Bosque 01 v01 (casilla 9,3) las piernas salían enteras de lavanda.
## No era la hierba ni un sesgo mal calculado: la copa del `arbol_redondo` de (9,6) queda entre la cámara y las piernas, 6-7,6 u más cerca
## (el sesgo es 0,4 u), así que la silueta hace lo que se le pidió el 4/11 (decorado entero + contorno). Esta herramienta lo enseña:
## fotos en (9,3) (copa delante: lavanda), (9,2) y (9,1) (sin copa: sin lavanda) y, en consola, qué copias de los lotes caen sobre la
## columna de las piernas y cuánto adelantan en profundidad de vista. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_silueta_copa.gd -- [carpeta]   (por defecto res://docs/capturas/silueta_copa)

const RUTA_BOSQUE_V01: String = "res://escenas/PruebaBosque01_v01.tscn"
const CASILLAS: Array = [Vector2i(9, 3), Vector2i(9, 2), Vector2i(9, 1)]
const TAM_CERCA: float = 3.4
const SESGO: float = 0.4

var _dir: String = "res://docs/capturas/silueta_copa"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	Flags.nuevo()
	Misiones.nuevo()
	await cargar(RUTA_BOSQUE_V01, true)
	if maqueta == null or jugador == null:
		return
	var pj: Pj3D = jugador.get("pj") as Pj3D
	_ocultar_ui(root)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	await avanzar(30)
	_ok("el sesgo de la silueta es 0,4 alturas en unidades de mundo", pj._sil_mat != null and is_equal_approx(float(pj._sil_mat.get_shader_parameter("sesgo")), pj.alto_modelo() * pj.scale.y * Pj3D.SILUETA_SESGO_ALTURAS),
		"sesgo=%s alto=%.3f" % [str(pj._sil_mat.get_shader_parameter("sesgo")) if pj._sil_mat else "nil", pj.alto_modelo() * pj.scale.y])
	for c in CASILLAS:
		colocar_jugador(c)
		maqueta.set("_tam_camara", TAM_CERCA)
		var cam: Camera3D = maqueta.get("_camara") as Camera3D
		if cam != null:
			cam.size = TAM_CERCA
		await avanzar_s(2.0)
		_ocultar_ui(root)
		var tapan: Array = _lotes_sobre_las_piernas(pj, cam)
		print("casilla %s: %d copias de lote sobre la columna de las piernas y más cerca que el sesgo: %s" % [str(c), tapan.size(), str(tapan)])
		await _foto("bosque_01_v01_%d_%d" % [c.x, c.y])


## Copias de los lotes (MultiMesh del decorado) con vértices que, vistos desde la cámara, caen sobre la columna de las piernas
## (±0,25 u a los lados, ±0,35 u arriba y abajo de la rodilla) y están más cerca de la cámara que la rodilla menos el sesgo.
func _lotes_sobre_las_piernas(pj: Pj3D, cam: Camera3D) -> Array:
	var res: Array = []
	if cam == null:
		return res
	var v: Vector3 = -cam.global_transform.basis.z
	var rodilla: Vector3 = pj.global_position + Vector3(0, 0.3, 0)
	var prof_rodilla: float = (rodilla - cam.global_position).dot(v)
	var lotes: Dictionary = maqueta.get("_lotes")
	for id in lotes:
		var partes: Array = maqueta.call("_plantilla", String(id))
		for t in lotes[id]:
			var tf: Transform3D = t
			if Vector2(tf.origin.x - rodilla.x, tf.origin.z - rodilla.z).length() > 10.0:
				continue
			var delante: int = 0
			var max_adel: float = -1e9
			for parte in partes:
				var caras: PackedVector3Array = (parte[0] as Mesh).get_faces()
				var tl: Transform3D = tf * (parte[1] as Transform3D)
				for k in range(caras.size()):
					var w: Vector3 = tl * caras[k]
					var r: Vector3 = w - rodilla
					if absf(r.dot(cam.global_transform.basis.x)) > 0.25 or absf(r.dot(cam.global_transform.basis.y)) > 0.35:
						continue
					var adel: float = prof_rodilla - (w - cam.global_position).dot(v)
					max_adel = maxf(max_adel, adel)
					if adel > SESGO:
						delante += 1
			if delante > 0:
				res.append("%s en %s (%d vértices, hasta %.2f u más cerca)" % [id, str(tf.origin), delante, max_adel])
	return res


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_dir.path_join(nombre + ".png")))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and h.name != Niveles.NOMBRE_FUNDIDO:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
