extends SceneTree
## PRUEBA del laboratorio de humanoides (laboratorios/LabHumanoide3D.tscn, 24/10, diario 256): en modo «COMO EL JUEGO (Pj3D)» monta a jugadora_base como el juego
## (clips de ClipsFamilia, las tres prendas, los huesos capa_* y sus muelles), R quita y pone la ropa, `walk` mueve los pies; cambiar a chibi_elf vuelve al modo GLB
## con los clips del propio GLB y las cinco cámaras (la 5 = la del juego) no fallan. Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_lab_humanoide.gd

const CLIPS_MIN: int = 20
const PRENDAS: int = 3
const FOTOGRAMAS_MARCHA: int = 45
const MOVIMIENTO_PIES_MIN: float = 0.03       ## u que tiene que recorrer un pie en esos fotogramas andando
const MOVIMIENTO_CAPA_MIN: float = 0.0005     ## 1 − |q·q0| mínimo de la rotación local de un hueso capa_* corriendo: sin muelles su pose no cambia (la capa no se mece)
const TAM_CAMARA_JUEGO: float = 6.0
const MS_FOTOGRAMA: int = 33

var _fallos: int = 0


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK    ", m)
	else:
		_fallos += 1
		print("FALLO ", m)


func _initialize() -> void:
	_correr()


func _correr() -> void:
	Estado.nuevo()
	await process_frame
	var lab: Node = (load("res://laboratorios/LabHumanoide3D.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	for _i in 4:
		await process_frame
	# ---- jugadora_base, como el juego ----
	_ok(lab._id == "jugadora_base", "la escena arranca con jugadora_base (%s)" % lab._id)
	_ok(lab._juego and lab._pj != null, "modo «como el juego» encendido de serie para jugadora_base")
	_ok(lab._chk_juego.button_pressed, "la casilla refleja el modo")
	var n_clips: int = lab._ap.get_animation_list().size()
	_ok(n_clips >= CLIPS_MIN, "%d clips en el reproductor (mínimo %d)" % [n_clips, CLIPS_MIN])
	_ok(lab._opt_clip.item_count == n_clips, "la lista del panel trae todos (%d)" % lab._opt_clip.item_count)
	var con_rol: int = 0
	for i in range(lab._opt_clip.item_count):
		if lab._opt_clip.get_item_text(i).contains("("):
			con_rol += 1
	_ok(con_rol > 0, "la lista enseña el rol de Pj3D entre paréntesis (%d clips con rol)" % con_rol)
	var sk: Skeleton3D = lab._sk
	var capas: Array[String] = []
	for b in range(sk.get_bone_count()):
		if sk.get_bone_name(b).begins_with("capa_"):
			capas.append(sk.get_bone_name(b))
	_ok(not capas.is_empty(), "el esqueleto tiene huesos capa_* (%d)" % capas.size())
	var grupos_capa: Array = []
	for h in capas:
		grupos_capa.append(lab._grupo_hueso.get(h, "?"))
	_ok(not capas.is_empty() and grupos_capa.all(func(g: Variant) -> bool: return String(g) != "?"), "los capa_* entran en _deducir_grupos (%s)" % [grupos_capa.slice(0, 3)])
	_ok(lab._pj.ropa_puesta().size() == PRENDAS, "las %d prendas puestas (%s)" % [PRENDAS, lab._pj.ropa_puesta()])
	var est: Dictionary = lab._est.get("jugadora_base#juego", {})
	_ok((est.get("todos", {"x": 1}) as Dictionary).is_empty(), "el giro fijo por hueso arranca en cero (encima de la postura del juego)")
	_ok(lab._tit_giro.text.contains("ENCIMA"), "la etiqueta lo dice: «%s»" % lab._tit_giro.text)
	_ok(absf(lab._pj.alto_modelo() * lab._pj.scale.y - 1.0) < 0.01, "mide 1,0 u, escalada una sola vez (%.3f)" % (lab._pj.alto_modelo() * lab._pj.scale.y))
	_ok(lab._modelo.scale.y == lab._pj.scale.y, "el lab no la vuelve a escalar")
	# ---- R quita y pone la ropa ----
	lab._unhandled_input(_tecla(KEY_R))
	_ok(lab._pj.ropa_puesta().is_empty(), "R quita la ropa (%s)" % [lab._pj.ropa_puesta()])
	_ok(not lab._chk_ropa.button_pressed, "la casilla de ropa se apaga")
	lab._unhandled_input(_tecla(KEY_R))
	_ok(lab._pj.ropa_puesta().size() == PRENDAS, "R vuelve a poner las %d prendas" % PRENDAS)
	# ---- walk: se reproduce y los pies se mueven ----
	var walk: String = lab._pj.clip_de("walk")
	lab._elegir_clip(walk)
	_ok(lab._ap.is_playing() and lab._ap.current_animation == walk, "walk (%s) se reproduce" % walk)
	var pies: Array = lab._pies
	_ok(not pies.is_empty(), "el lab encuentra los pies (%d)" % pies.size())
	var min_p: Vector3 = Vector3(1e9, 1e9, 1e9)
	var max_p: Vector3 = Vector3(-1e9, -1e9, -1e9)
	for _f in FOTOGRAMAS_MARCHA:
		await _fotograma()
		if not pies.is_empty():
			var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(int(pies[0])).origin      # en el mundo: el esqueleto del GLB va a otra escala
			min_p = min_p.min(p)
			max_p = max_p.max(p)
	_ok((max_p - min_p).length() > MOVIMIENTO_PIES_MIN, "los pies se mueven andando (%.3f u)" % (max_p - min_p).length())
	# ---- la capa se mece corriendo (CapaMuelles3D sigue viva) ----
	lab._elegir_clip(lab._pj.clip_de("run"))
	var m: CapaMuelles3D = Ropa3D.muelles(lab._pj, "capa")
	_ok(m != null, "CapaMuelles3D existe en el Pj3D del lab")
	# El esqueleto restaura las poses tras los modificadores, así que lo que hacen los muelles se lee en su señal `modification_processed` (como prueba_lab_jugadora):
	# se anota el giro de TODOS los huesos capa_* respecto a su padre en cada pasada, y se compara el primero con cualquier otro.
	var rots: Array = []
	var anotar: Callable = func() -> void:
		var fila: Array[Quaternion] = []
		for nombre in capas:
			var h: int = sk.find_bone(nombre)
			var gp: Transform3D = sk.get_bone_global_pose(sk.get_bone_parent(h))
			fila.append((gp.basis.orthonormalized().inverse() * sk.get_bone_global_pose(h).basis.orthonormalized()).get_rotation_quaternion())
		rots.append(fila)
	if m != null:
		m.modification_processed.connect(anotar)
	for f in FOTOGRAMAS_MARCHA:
		await _fotograma()
	var cambio: float = 0.0
	for fila in rots:
		for k in range((fila as Array).size()):
			cambio = maxf(cambio, 1.0 - absf((fila[k] as Quaternion).dot((rots[0][k]) as Quaternion)))
	_ok(not capas.is_empty() and rots.size() > 1 and cambio > MOVIMIENTO_CAPA_MIN, "la capa se mece corriendo (%d pasadas de los muelles; el giro de sus huesos capa_* cambia %.5f)" % [rots.size(), cambio])	# ---- cámaras 1-5 ----
	for i in range(5):
		lab._camara_preset(i)
		await process_frame
		lab._colocar_camara()
		var ortogonal: bool = lab._cam.projection == Camera3D.PROJECTION_ORTHOGONAL
		_ok(ortogonal == (i == 4), "cámara %d: %s" % [i + 1, "ortográfica (la del juego)" if ortogonal else "perspectiva"])
	_ok(is_equal_approx(lab._cam.size, TAM_CAMARA_JUEGO), "la cámara 5 tiene tamaño %.1f" % lab._cam.size)
	lab._camara_preset(0)
	# ---- comparar con otro personaje en modo juego y en modo GLB ----
	lab._elegir_comparacion("chibi_elf")
	await process_frame
	_ok(lab._modelo2 != null and lab._ap2 != null, "comparar con chibi_elf (GLB) tiene reproductor")
	lab._elegir_comparacion("elfo_base")
	await process_frame
	_ok(lab._pj2 != null and lab._ap2 != null, "comparar con elfo_base (ClipsFamilia) se monta con Pj3D")
	lab._elegir_comparacion("")
	# ---- cambiar a chibi_elf: modo GLB, clips del GLB como antes ----
	lab._elegir_personaje("chibi_elf")
	await process_frame
	await process_frame
	_ok(not lab._juego and lab._pj == null, "chibi_elf: modo GLB, sin Pj3D")
	_ok(not lab._chk_juego.button_pressed, "la casilla se apaga")
	_ok(lab._ap.get_animation_list().size() > 0 and (lab._ap.has_animation("Walking") or lab._ap.has_animation("walking")), "chibi_elf: clips del GLB (%d)" % lab._ap.get_animation_list().size())
	_ok(lab._opt_clip.item_count == lab._ap.get_animation_list().size() and not lab._opt_clip.get_item_text(0).contains("("), "la lista del modo GLB no lleva roles")
	_ok(lab._tit_giro.text.begins_with("Hueso"), "el título del giro vuelve a ser el de siempre")
	var vacio: bool = true
	for h in (lab._est["chibi_elf"]["todos"] as Dictionary).keys():
		vacio = false
	_ok(vacio == not Pj3D.CORRECCION_POSTURA.has("chibi_elf"), "chibi_elf (GLB) arranca con su CORRECCION_POSTURA del juego, si la tiene")
	_ok(lab._ap.is_playing(), "chibi_elf anima")
	# la casilla enciende el modo juego en un id que no lo traía de serie, y vuelve
	lab._chk_juego.button_pressed = true
	await process_frame
	_ok(lab._juego and lab._pj != null and lab._id == "chibi_elf", "la casilla enciende «como el juego» en chibi_elf")
	_ok(lab._est.has("chibi_elf#juego") and lab._est.has("chibi_elf"), "cada modo guarda sus propios giros")
	lab._chk_juego.button_pressed = false
	await process_frame
	_ok(not lab._juego, "y lo apaga")
	# la heroína con sus casts y su libro siguen como antes
	lab._probar_cast("CastOneHandFront")
	await process_frame
	_ok(lab._id == "woodland_wanderer" and not lab._juego and lab._clip == "CastOneHandFront", "woodland_wanderer: modo GLB y botones de cast como siempre")
	_ok(lab._libro_caja != null, "el libro cerrado se pone en la mano izquierda")
	_ok(lab._cast.has("traza"), "se mide el cast")
	print("")
	print("FALLOS: ", _fallos)
	quit(1 if _fallos > 0 else 0)


## Sin ventana los fotogramas salen sin tiempo entre ellos (delta ≈ 0) y ni el reproductor ni los muelles avanzan: se espera un fotograma de verdad (30 fps).
func _fotograma() -> void:
	OS.delay_msec(MS_FOTOGRAMA)
	await process_frame


func _tecla(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	return e
