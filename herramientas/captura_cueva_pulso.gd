extends "res://herramientas/escenario_base.gd"
## HOJAS D1 «pulso» y D2 «recompensas» + PARED DEL FOSO en la Cueva (23/10). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_cueva_pulso.gd -- [carpeta]   (por defecto res://docs/capturas/cueva_pulso)
## 1 · Las piezas, de frente y a 3/4 (se gira la pieza, no la cámara), cada una sobre su casilla de 2,3 (marco claro) y con la jugadora al lado
##     para la escala. Los cofres, cerrados y con la tapa abierta (Cofre3D.abrir_ya: la bisagra es la del origen de la tapa).
## 2 · La pared del foso de la charca y el borde del mapa en la Cueva, de cerca.
## Lo que es contrato (los modelos se instancian, los cofres abren, las medidas son las del prompt) va con `_ok`; lo demás se mira en las fotos.

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const FILA: int = 14                       ## fila de C1 (la boca) donde se alinean las piezas; la jugadora va en FILA + 1
const COLUMNA0: int = 2
const GIRO_34: float = 40.0                ## grados sobre Y para la vista a 3/4
const TAM_CAMARA: float = 7.0
const GRUPOS: Dictionary = {
	"pulso_a": ["cristal_resonante", "prisma_orientable", "receptor_runico", "bloque_enlace"],
	"pulso_b": ["estatua_piedra", "columna_agrietada", "cofre_legendario", "cofre_epico"],
}
## Alto o ancho esperados (de PROMPTS_CUEVA D1/D2 y de `Pieza3D.MEDIDA`/`MEDIDA_ANCHO`): id → [medida, "alto"|"ancho"].
const ESPERADAS: Dictionary = {
	"cristal_resonante": [1.5, "alto"], "prisma_orientable": [1.2, "alto"], "receptor_runico": [1.1, "alto"], "estatua_piedra": [1.7, "alto"],
	"columna_agrietada": [2.5, "alto"], "bloque_enlace": [1.0, "ancho"], "cofre_legendario": [1.6, "ancho"], "cofre_epico": [1.1, "ancho"],
	"placa_presion_cueva": [1.8, "ancho"],
}

var _dir: String = "res://docs/capturas/cueva_pulso"
var _extra: Array[Node] = []


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
	var cam: Camera3D = maqueta.get("_camara") as Camera3D

	# 1 · Medidas y fotos de las piezas
	for id in ESPERADAS:
		var esc: PackedScene = load("res://arte/piezas/%s.tscn" % id) as PackedScene
		_ok("1 %s: la escena horneada existe y carga" % id, esc != null)
		if esc == null:
			continue
		var n: Node3D = esc.instantiate() as Node3D
		var caja: AABB = _caja(n, Transform3D.IDENTITY)
		var medida: float = caja.size.y if String(ESPERADAS[id][1]) == "alto" else maxf(caja.size.x, caja.size.z)
		_ok("1 %s: %s %.2f u (prompt %.2f)" % [id, ESPERADAS[id][1], medida, float(ESPERADAS[id][0])], absf(medida - float(ESPERADAS[id][0])) < 0.12,
			"caja %s" % str(caja.size))
		_ok("1 %s: base en y = 0" % id, absf(caja.position.y) < 0.25, "y0 = %.2f" % caja.position.y)
		n.free()
	for grupo in GRUPOS:
		for giro in [0.0, GIRO_34]:
			await _foto_grupo(grupo, GRUPOS[grupo], giro, false, cam)
	# cofres con la tapa abierta + la placa
	await _foto_grupo("recompensas_abiertos", ["cofre_legendario", "cofre_epico", "placa_presion_cueva"], 20.0, true, cam)
	_ok("1 los cofres de la hoja D2 traen Cofre3D y se abren (tapa girada)", _cofres_abiertos == 2, "%d abiertos" % _cofres_abiertos)

	# 2 · Pared del foso y borde del mapa
	for n in _extra:
		if is_instance_valid(n):
			n.queue_free()
	_extra.clear()
	await _mirar(Vector2i(22, 17), 4.5, 2.0)
	_foto("pared_charca_de_cerca")
	await _mirar(Vector2i(14, 19), 4.5, 2.0)
	_foto("borde_mapa_de_cerca")
	await _mirar(Vector2i(22, 18), 9.0, 1.0)
	_foto("pared_charca_general")


var _cofres_abiertos: int = 0


func _foto_grupo(nombre: String, ids: Array, giro: float, abrir: bool, cam: Camera3D) -> void:
	for n in _extra:
		if is_instance_valid(n):
			n.queue_free()
	_extra.clear()
	_cofres_abiertos = 0 if abrir else _cofres_abiertos
	var c0 := Vector2i(COLUMNA0, FILA)
	for i in range(ids.size()):
		var c: Vector2i = c0 + Vector2i(i, 0)
		var base: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
		_extra.append(_casilla(base))
		var esc: PackedScene = load("res://arte/piezas/%s.tscn" % ids[i]) as PackedScene
		if esc == null:
			continue
		var n: Node3D = esc.instantiate() as Node3D
		maqueta.add_child(n)
		n.global_position = base
		n.rotation_degrees.y = giro
		_extra.append(n)
		if abrir:
			var ctrl: Cofre3D = Cofre3D.en(n)
			if ctrl != null:
				ctrl.abrir_ya()
				_cofres_abiertos += 1
	colocar_jugador(c0 + Vector2i(ids.size() / 2, 1))      # delante y en medio de la fila: la cámara la sigue y deja las piezas centradas
	maqueta.set("_tam_camara", TAM_CAMARA)
	if cam != null:
		cam.size = TAM_CAMARA
	await avanzar_s(2.2)
	if abrir:
		for n in _extra:
			var ctrl2: Node = n.find_child("Cofre3D", true, false) if is_instance_valid(n) else null
			if ctrl2 != null:
				# Una sola tapa y un solo cuerpo en la escena (el horneado de arte/piezas duplicaba el subárbol del .glb y el controlador movía solo una copia),
				# y la tapa abierta sube por encima del cuerpo (gira sobre la bisagra del origen de la tapa).
				var tapas: Array = n.find_children("cofre_tapa", "", true, false)
				var tapa: Node3D = ctrl2.get("_tapa") as Node3D
				_ok("1 %s: una sola tapa y es la que mueve Cofre3D" % n.name, tapas.size() == 1 and tapas[0] == tapa, "%d tapas" % tapas.size())
				var cuerpo: MeshInstance3D = n.find_child("cofre_cuerpo", true, false) as MeshInstance3D
				var borde: float = (cuerpo.global_transform * cuerpo.get_aabb()).end.y
				var cima: float = (tapa.global_transform * (tapa as MeshInstance3D).get_aabb()).end.y
				_ok("1 %s: con la tapa abierta sube sobre el borde del cuerpo" % n.name, cima > borde + 0.15, "cima %.2f, borde %.2f" % [cima, borde])
	_foto("%s_%s" % [nombre, "34" if giro > 1.0 and not abrir else ("frente" if not abrir else "tapa_abierta")])


## Marco de una casilla (2,3 × 2,3) a ras de suelo, para comparar el tamaño de la pieza con la rejilla.
func _casilla(centro: Vector3) -> Node3D:
	var r := Node3D.new()
	maqueta.add_child(r)
	r.global_position = centro + Vector3(0.0, 0.03, 0.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var lado: float = Terreno3D.casilla
	for lado_i in [[Vector3(0.0, 0.0, lado * 0.5), Vector3(lado, 0.02, 0.04)], [Vector3(0.0, 0.0, -lado * 0.5), Vector3(lado, 0.02, 0.04)],
			[Vector3(lado * 0.5, 0.0, 0.0), Vector3(0.04, 0.02, lado)], [Vector3(-lado * 0.5, 0.0, 0.0), Vector3(0.04, 0.02, lado)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = lado_i[1]
		mi.mesh = bm
		mi.material_override = m
		mi.position = lado_i[0]
		r.add_child(mi)
	return r


func _mirar(c: Vector2i, tam: float, s: float) -> void:
	colocar_jugador(c)
	maqueta.set("_tam_camara", tam)
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	if cam != null:
		cam.size = tam
	await avanzar_s(s)


func _caja(n: Node, acum: Transform3D) -> AABB:
	var t: Transform3D = acum
	if n is Node3D:
		t = acum * (n as Node3D).transform
	var res := AABB()
	var vacia: bool = true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		res = t * (n as MeshInstance3D).mesh.get_aabb()
		vacia = false
	for h in n.get_children():
		var sub: AABB = _caja(h, t)
		if sub.size != Vector3.ZERO:
			res = sub if vacia else res.merge(sub)
			vacia = false
	return res


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
