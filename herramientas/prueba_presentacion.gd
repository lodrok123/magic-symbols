extends SceneTree
## Presentación del escenario (Fase 14.2, Pipeline, 16/10): Paleta3D, BordePiedras3D, SombraContacto3D, las sombras de PiezaPuzle3D y el
## montaje en la maqueta (bordes del río, lecho, diorama). El DESENFOQUE en sí no se puede probar sin ventana ni en Compatibilidad: aquí
## solo se comprueba su cálculo (distancia al jugador, zona nítida, apagado) y que no da error.
##   godot --headless --path . --script res://herramientas/prueba_presentacion.gd
## Prueba la lógica y los números, no «que se vea bien»: eso son las capturas antes/después (docs/ARTE.md §10).

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


## Leer de vuelta las transformaciones de un MultiMesh necesita un renderizador real: el ficticio de `--headless` devuelve ceros. Sin ventana se avisa y se salta.
func _ok_render(nombre: String, bien: bool, info: String = "") -> void:
	if DisplayServer.get_name() == "headless":
		print("AVISO saltada sin renderizador (usa xvfb): " + nombre)
		return
	_ok(nombre, bien, info)


func _initialize() -> void:
	_paleta()
	_bordes()
	_sombra()
	_piezas()
	await _maqueta()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _paleta() -> void:
	_ok("P1 un tinte hacia el mismo color con fuerza 0 es blanco", Paleta3D.tinte_hacia(Color(0.5, 0.6, 0.4), Color(0.9, 0.9, 0.9), 0.0).is_equal_approx(Color.WHITE))
	var t: Color = Paleta3D.tinte_hacia(Color(0.1, 0.1, 0.1), Color(1, 1, 1), 1.0)
	_ok("P2 el tinte se acota a 1,35 por canal (no quema)", t.r <= 1.35 + 0.0001 and t.g <= 1.35 + 0.0001 and t.b <= 1.35 + 0.0001, str(t))
	var u: Color = Paleta3D.tinte_hacia(Color(1, 1, 1), Color(0.05, 0.05, 0.05), 1.0)
	_ok("P3 y a 0,6 por abajo (no ennegrece)", u.r >= 0.6 - 0.0001, str(u))
	var h: Color = Paleta3D.tinte_de_pieza("helecho")
	_ok("P4 el helecho (verde olivo) recibe un tinte que no es blanco y está en rango", h != Color.WHITE and h.r >= 0.6 and h.b <= 1.35 + 0.0001, str(h))
	_ok("P5 una pieza que no está en la tabla no se tiñe", Paleta3D.tinte_de_pieza("barril") == Color.WHITE and Paleta3D.tinte_de_pieza("tinaja_ruina") == Color.WHITE)
	var env := Environment.new()
	Paleta3D.aplicar_ajuste(env)
	_ok("P6 el ajuste único se aplica al entorno", env.adjustment_enabled and is_equal_approx(env.adjustment_saturation, Paleta3D.AJUSTE_SATURACION))
	Paleta3D.aplicar_ajuste(env, 0.0)
	_ok("P7 con intensidad 0 el ajuste se apaga", not env.adjustment_enabled)
	# La paleta del código y la de docs/ARTE.md §10 son la misma: cada color tiene que estar escrito en el documento.
	var f: FileAccess = FileAccess.open("res://docs/ARTE.md", FileAccess.READ)
	var doc: String = f.get_as_text().to_upper() if f != null else ""
	var faltan: Array = []
	for c in [Paleta3D.HIERBA_SOMBRA, Paleta3D.HIERBA, Paleta3D.HIERBA_LUZ, Paleta3D.TIERRA, Paleta3D.TIERRA_FLANCO, Paleta3D.PIEDRA,
			Paleta3D.PIEDRA_OSCURA, Paleta3D.AGUA_SOMERA, Paleta3D.AGUA_HONDA, Paleta3D.MADERA, Paleta3D.METAL, Paleta3D.CAMINO_ARENA]:
		if not doc.contains((c as Color).to_html(false).to_upper()):
			faltan.append((c as Color).to_html(false))
	_ok("P8 todos los colores de Paleta3D están en docs/ARTE.md §10", f != null and faltan.is_empty(), "faltan: " + str(faltan))


func _bordes() -> void:
	var b := BordePiedras3D.new()
	b.con_piedras = true          # 22/10: de serie ya no hay cantos; aquí se prueba que siguen funcionando si se encienden
	root.add_child(b)
	var mat := StandardMaterial3D.new()
	var lista: Array = [
		{"c": Vector2i(2, 2), "v": Vector2i(1, 0), "y_alto": 1.0, "y_bajo": 0.1},
		{"c": Vector2i(3, 5), "v": Vector2i(0, 1), "y_alto": 1.0, "y_bajo": 0.1, "piedras": false},
		{"c": Vector2i(1, 1), "v": Vector2i(-1, 0), "y_alto": 1.0, "y_bajo": 0.995},      # pared de 0,5 cm: sin falda
	]
	b.construir(lista, 2.3, mat)
	_ok("B1 el borde con `piedras: false` no lleva piedras y los otros sí", b.n_piedras() > 0 and b.n_piedras() <= 2 * b.piedras_por_borde, "piedras=%d" % b.n_piedras())
	var faldas: MeshInstance3D = b.get_node_or_null("faldas")
	var verts: int = 0
	if faldas != null:
		verts = (faldas.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	_ok("B2 una falda por borde con pared (dos triángulos) y ninguna donde la pared es de 5 mm", faldas != null and verts == 12, "vértices=%d" % verts)
	# La normal de la falda: arriba para el extremo del suelo y horizontal para el de la pared.
	var normales: PackedVector3Array = faldas.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] if faldas != null else PackedVector3Array()
	var hay_arriba: bool = false
	var hay_lado: bool = false
	for n in normales:
		hay_arriba = hay_arriba or n.dot(Vector3.UP) > 0.99
		hay_lado = hay_lado or absf(n.y) < 0.01
	_ok("B3 las normales de la falda van de la pared (de lado) al suelo (arriba)", hay_arriba and hay_lado)
	# Los cantos: tamaño entre piedra_min y piedra_max, en el labio.
	var pie: MultiMeshInstance3D = b.get_node_or_null("piedras")
	var bien_tam: bool = pie != null
	var bien_y: bool = pie != null
	if pie != null:
		for i in pie.multimesh.instance_count:
			var tf: Transform3D = pie.multimesh.get_instance_transform(i)
			var diam: float = tf.basis.get_scale().x
			bien_tam = bien_tam and diam >= b.piedra_min - 0.001 and diam <= b.piedra_max + 0.001
			bien_y = bien_y and absf(tf.origin.y - 1.0) < 0.4
	_ok_render("B4 cada canto mide entre 0,3 y 0,6 u y está en el labio de arriba", bien_tam and bien_y)
	# Determinismo: reconstruir da lo mismo (el jitter sale de un hash, no de randf).
	var antes: Transform3D = pie.multimesh.get_instance_transform(0) if pie != null else Transform3D.IDENTITY
	var n_antes: int = b.n_piedras()
	b.construir(lista, 2.3, mat)
	await process_frame
	var pie2: MultiMeshInstance3D = null
	for h in b.get_children():
		if h is MultiMeshInstance3D and not h.is_queued_for_deletion():
			pie2 = h
	_ok("B5 reconstruir da los mismos cantos (sin parpadeo)", pie2 != null and b.n_piedras() == n_antes and pie2.multimesh.get_instance_transform(0).is_equal_approx(antes))
	b.construir([], 2.3, mat)
	_ok("B6 una lista vacía no dibuja nada", b.n_bordes() == 0 and b.n_piedras() == 0)
	b.queue_free()


func _sombra() -> void:
	var m: ShaderMaterial = SombraContacto3D.material(0.4, 0.0)
	_ok("S1 el material de la sombra lleva alfa y dureza", is_equal_approx(float(m.get_shader_parameter("alfa")), 0.4) and is_equal_approx(float(m.get_shader_parameter("dureza")), 0.0))
	var p := Node3D.new()
	root.add_child(p)
	var s: MeshInstance3D = SombraContacto3D.poner(p, 1.0, 0.8, 0.02)
	_ok("S2 una sombra suelta cuelga del padre con sus dos diámetros y sin proyectar sombra", s.get_parent() == p and is_equal_approx(s.scale.x, 1.0) and is_equal_approx(s.scale.z, 0.8) and s.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	p.queue_free()


func _piezas() -> void:
	var sin_sombra: Array = []
	for fam in PiezaPuzle3D.ESTADOS.keys():
		var pz: PiezaPuzle3D = PiezaPuzle3D.crear(String(fam))
		var tiene: bool = pz.get_node_or_null("sombra_contacto") != null
		if fam == "placa":
			_ok("S3 la placa de presión (a ras del suelo) no lleva sombra", not tiene)
		elif not tiene:
			sin_sombra.append(fam)
		pz.free()
	_ok("S4 el resto de familias de puzle llevan sombra de contacto", sin_sombra.is_empty(), "sin sombra: " + str(sin_sombra))
	var hielo: PiezaPuzle3D = PiezaPuzle3D.crear("tapon_hielo")
	hielo.sonido = false
	var sh: Node = hielo.get_node("sombra_contacto")
	hielo.poner_estado("nada", false)
	var oculta: bool = not (sh as Node3D).visible
	hielo.poner_estado("entero", false)
	_ok("S5 la sombra se esconde cuando el hielo desaparece y vuelve con la pieza", oculta and (sh as Node3D).visible)
	hielo.free()


func _maqueta() -> void:
	var m: Node3D = (load("res://escenas/PruebaBosque.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for _i in 20:
		await process_frame
	var bordes: BordePiedras3D = m.get("_bordes")
	_ok("M1 el Bosque monta los bordes blandos del río", bordes != null and bordes.n_bordes() > 0 and bordes.n_piedras() == 0,     # 22/10: sin cantos de serie
		"bordes=%d piedras=%d" % [bordes.n_bordes() if bordes != null else -1, bordes.n_piedras() if bordes != null else -1])
	_ok("M2 el Bosque monta el lecho del río con guijarros", m.get_node_or_null("lecho_rio") != null)
	var dof: CameraAttributesPractical = m.get("_camara_dof")
	_ok("M3 la cámara lleva atributos de profundidad de campo", dof != null and (m.get("_camara") as Camera3D).attributes == dof)
	var compat: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if not compat and dof != null:
		var cam: Camera3D = m.get("_camara")
		var d: float = (m.get("_foco") - cam.global_position).length()
		_ok("M4 el desenfoque lejano empieza más allá del jugador, a la distancia de la cámara + la zona nítida", dof.dof_blur_far_enabled and dof.dof_blur_far_distance > d, "far=%.1f d=%.1f" % [dof.dof_blur_far_distance, d])
		var antes: float = dof.dof_blur_far_distance
		m.set("_tam_camara", float(m.get("_tam_camara")) * 3.0)
		await process_frame
		await process_frame
		_ok("M5 con más zoom (cámara más abierta) la zona nítida crece", dof.dof_blur_far_distance > antes, "%.1f → %.1f" % [antes, dof.dof_blur_far_distance])
		m.set("diorama", false)
		await process_frame
		await process_frame
		_ok("M6 apagado el diorama no desenfoca", not dof.dof_blur_far_enabled)
	else:
		_ok("M4 en Compatibilidad el diorama se apaga solo", dof != null and not dof.dof_blur_far_enabled)
	m.queue_free()
