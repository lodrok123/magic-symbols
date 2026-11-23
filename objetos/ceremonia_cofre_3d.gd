class_name CeremoniaCofre3D
extends Node
## Director único de tapa, personaje, libro y recompensa. El laboratorio usa modo_prueba.
signal glifo_escrito
signal recompensa_lista
signal terminada

const FLAG_VISTA := "global.cofre.legendario_visto"
const T_FIN := 5.35
const T_TRAVELLING := 0.85
const ORBITA_GRADOS := 55.0
const T_ONDA := 1.2
const T_ESCRIBE := 4.0
const T_AVISO_PISTA := 1.6
const TAM_PRIMER_PLANO := 6.4
const LUZ_ZONA_FRACCION := 0.75
const ROL_ANIMACION := "abrir_cofre"

var cofre: Node3D
var ctrl: Cofre3D
var mundo: Object
var glifo := ""
var calidad := "legendario"
var nivel_libro: int = 0
var objeto_presentado: String = "oro"
var modo_prueba := false
## H6 (23/11): lo que el cofre pide para la PISTA de uso inmediato (claves `reto=` y `reto_en=` del mapa; ver `PistaGlifo`). `reto` = la flag que resuelve la sala (si no, la pista se va al primer
## lanzamiento con el glifo); `reto_en` = la casilla (Vector2i) donde el suelo enseña el marcador. Vacíos = sin ellos.
var reto: String = ""
var reto_en: Variant = null
var pagina_equipada: int = -1                      ## la página donde `Grimorio.equipar_glifo_nuevo` dejó el glifo (-1 = no cabía o no era nuevo)
var glifo_nuevo: bool = false
var pista: PistaGlifo = null
var efectos_reducidos := false
var usar_mixamo := false
## Contacto calibrable: no reutiliza el instante del clip Meshy para Mixamo.
var contacto_mixamo := 1.77
var duracion_mixamo := 8.93
var saltable := false
var saltada := false
var activa := false
var hecha := false
var esperando_input := false
var _continuado := false
var _t_continuar := -1.0
var _cam_juego: Camera3D
var _cam_inicio := Transform3D.IDENTITY
var _orbita_centro := Vector3.ZERO
var _orbita_foco := Vector3.ZERO
var _orbita_angulo := 0.0
var _orbita_radio := 3.5
var _orbita_altura := 1.0
var _cam_tamano := 3.0
var _aviso_continuar: CanvasLayer
var escrito := false
var fase := ""
var t := 0.0
var luz_baja := 1.0
var pj_explicito: Pj3D
var jugador_explicito: Node3D
var camara_explicita: Camera3D
var _pj: Pj3D
var _jugador: Node3D
var _cam: Camera3D
var _env: Environment
var _sol: DirectionalLight3D
var _lanz: Node
var _visuales: Node3D
var _libro: LibroCeremonia3D
var _runa: MeshInstance3D
var _aro: MeshInstance3D
var _abanico: MeshInstance3D
var _onda: MeshInstance3D
var _estela: Array[MeshInstance3D] = []
var _nombre: Label3D
var _lamina: LaminaGlifo
var _tex: Texture2D
var _origen := Vector3.ZERO
var _alto := Vector3.ZERO
var _color := Color.WHITE
var _tam0 := 0.0
var _tam_mundo0: Variant = null
var _libro_pos := Vector3.ZERO
var _acercar_de := Vector3.ZERO
var _acercar_a := Vector3.ZERO
var _h0 := 0.0
var _v0 := 0.0
var _sol0 := 1.0
var _amb0 := 1.0
var _externa0 := false
var _bloqueado0 := false
var _confirmada := false
var _restaurado := false
var _eventos: Dictionary = {}

static func velocidad_abrir() -> float:
	return clampf(Pj3D.instante_clip(ROL_ANIMACION) / T_ONDA, 0.5, 2.0)

func iniciar(p_cofre: Node3D, p_ctrl: Object, p_mundo: Object, p_glifo: String) -> bool:
	if activa or hecha or p_cofre == null or get_tree().get_first_node_in_group("ceremonia_cofre_activa") != null:
		return false
	add_to_group("ceremonia_cofre_activa")
	cofre = p_cofre
	ctrl = p_ctrl as Cofre3D
	mundo = p_mundo
	glifo = p_glifo
	_color = Objetos.CALIDADES.get(calidad, Objetos.CALIDADES["comun"])["color"]
	_tex = Sigils.GLYPHS.get(glifo) as Texture2D
	if glifo.is_empty():
		_tex = Objetos.icono(objeto_presentado)
	activa = true
	saltable = modo_prueba or Flags.i().tiene(FLAG_VISTA)
	_buscar()
	if ctrl != null:
		ctrl.gesto_externo = true
	if _pj != null:
		_pj.iniciar_ceremonia_libro()
	if _jugador != null:
		_acercar_de = _jugador.global_position
		var d: Vector3 = _acercar_de - cofre.global_position
		d.y = 0
		_acercar_a = _acercar_de
		if d.length() > 1.0:
			var destino: Vector3 = cofre.global_position + d.normalized()
			destino.y = _acercar_de.y
			var consulta := PhysicsRayQueryParameters3D.create(_acercar_de + Vector3.UP * 0.4, destino + Vector3.UP * 0.4)
			if _jugador is CollisionObject3D:
				consulta.exclude = [(_jugador as CollisionObject3D).get_rid()]
			if cofre.get_world_3d().direct_space_state.intersect_ray(consulta).is_empty():
				_acercar_a = destino
		_externa0 = bool(_jugador.get("animacion_externa"))
		_bloqueado0 = bool(_jugador.get("bloqueado"))
		_jugador.set("animacion_externa", true)
		if _jugador.has_method("bloquear"):
			_jugador.call("bloquear", true)
		if _jugador.has_method("mirar_hacia"):
			_jugador.call("mirar_hacia", cofre.global_position - _jugador.global_position)
	_mirar_cofre()
	if _pj != null:
		_pj.animacion_actual = ""
		if usar_mixamo:
			_pj.jugar("Mixamo_AbrirTapa", true, 1.0)
		else:
			_pj.jugar(ROL_ANIMACION, true, velocidad_abrir() if not glifo.is_empty() else 1.85)
	_crear_visuales()
	_preparar_travelling()
	fase = "anticipacion"
	return true

func _buscar() -> void:
	_lanz = get_tree().get_first_node_in_group("spellcaster")
	_jugador = jugador_explicito
	if _jugador == null and _lanz != null:
		_jugador = _lanz.get("jugador") as Node3D
	_pj = pj_explicito
	if _pj == null and _jugador != null:
		_pj = _jugador.get("pj") as Pj3D
	_cam = camara_explicita
	if _cam == null and mundo != null:
		_cam = mundo.get("_camara") as Camera3D
	if _cam == null:
		_cam = get_viewport().get_camera_3d()
	if mundo != null:
		_env = mundo.get("_env") as Environment
		_sol = mundo.get("_sol") as DirectionalLight3D
		_tam_mundo0 = mundo.get("_tam_camara")
	if _cam != null:
		_tam0 = _cam.size
		_h0 = _cam.h_offset
		_v0 = _cam.v_offset
	if _env != null:
		_amb0 = _env.ambient_light_energy
	if _sol != null:
		_sol0 = _sol.light_energy

func _crear_visuales() -> void:
	_visuales = Node3D.new()
	_visuales.name = "CeremoniaVisual"
	add_child(_visuales)
	_origen = cofre.global_position + Vector3.UP * 0.7
	if ctrl != null:
		var caja: AABB = ctrl._caja()
		_origen = ctrl.to_global(Vector3(caja.get_center().x, caja.end.y, caja.get_center().z))
	_alto = _origen + Vector3.UP * 1.0
	_abanico = CofreCeremoniaVfx3D.abanico(_color)
	_visuales.add_child(_abanico)
	_abanico.global_position = _origen
	if _cam != null:
		_abanico.global_basis = _cam.global_basis
	_abanico.visible = false
	_onda = MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.94
	toro.outer_radius = 1.0
	_onda.mesh = toro
	var onda_mat := StandardMaterial3D.new()
	onda_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	onda_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	onda_mat.albedo_color = _color
	_onda.material_override = onda_mat
	_visuales.add_child(_onda)
	_onda.global_position = cofre.global_position + Vector3.UP * 0.035
	_onda.visible = false
	for i in 10:
		var trazo := MeshInstance3D.new()
		var punto := SphereMesh.new()
		punto.radius = 0.018
		punto.height = 0.036
		trazo.mesh = punto
		var tinta := StandardMaterial3D.new()
		tinta.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tinta.albedo_color = _color
		trazo.material_override = tinta
		_visuales.add_child(trazo)
		trazo.visible = false
		_estela.append(trazo)
	_runa = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.70, 0.70)
	_runa.mesh = q
	if _tex == null:
		var moneda := CylinderMesh.new()
		moneda.top_radius = 0.20
		moneda.bottom_radius = 0.20
		moneda.height = 0.06
		moneda.radial_segments = 24
		_runa.mesh = moneda
		if objeto_presentado != "oro":
			var objeto := SphereMesh.new()
			objeto.radius = 0.22
			objeto.height = 0.44
			_runa.mesh = objeto
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = (Color(0.95, 0.65, 0.10) if _tex == null else Color.WHITE) if glifo.is_empty() else _color
	if _tex == null and glifo.is_empty() and objeto_presentado != "oro":
		mat.albedo_color = Objetos.DATOS.get(objeto_presentado, {}).get("color", _color)
	mat.albedo_texture = _tex
	mat.emission_enabled = true
	mat.emission = _color
	mat.emission_energy_multiplier = 0.5
	if _tex != null:
		mat.emission_texture = _tex
	_runa.material_override = mat
	_visuales.add_child(_runa)
	_runa.visible = false
	_aro = CofreCeremoniaVfx3D.aro(_color)
	_visuales.add_child(_aro)
	_aro.visible = false
	_nombre = Label3D.new()
	_nombre.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nombre.font_size = 32
	_nombre.pixel_size = 0.006
	_nombre.modulate = _color
	_nombre.text = Sigils.nombre_visible(glifo) if not glifo.is_empty() else Objetos.nombre(objeto_presentado)
	_visuales.add_child(_nombre)
	_nombre.global_position = _alto + Vector3.UP * 0.55
	_nombre.visible = false
	if not glifo.is_empty():
		_libro = LibroCeremonia3D.new()
		_visuales.add_child(_libro)
		_libro.preparar(nivel_libro if nivel_libro > 0 else Equipo3D.nivel_grimorio)
		var base: Vector3 = _acercar_a if _jugador != null else (_pj.global_position if _pj != null else cofre.global_position + Vector3(0, 0, 1.0))
		_libro.global_position = base + Vector3(0, 1.5, 0)
		if _cam != null:
			_libro.global_position += _cam.global_basis.x * 0.3
		# La página mira hacia la cámara conservando profundidad y las dos tapas visibles.
		if _cam != null:
			_libro.global_basis = _cam.global_basis * Basis(Vector3.RIGHT, PI * 0.33)
		_libro_pos = _libro.global_position
		_libro.visible = false

func _evento(id: String, cuando: float) -> bool:
	if t < cuando or _eventos.has(id):
		return false
	_eventos[id] = true
	return true

func _process(delta: float) -> void:
	if not activa or esperando_input:
		return
	if not is_instance_valid(cofre):
		cancelar()
		return
	var tiempo_anterior: float = t
	t += delta
	if is_instance_valid(_jugador):
		_jugador.global_position = _acercar_de.lerp(_acercar_a, smoothstep(0, 0.35, t))
	_mirar_cofre()
	var legendario: bool = not glifo.is_empty()
	var fin: float = T_FIN if legendario else 2.2
	var tapa: float = 0.8 if legendario else 0.35
	var sale: float = 1.75 if legendario else 1.3
	if usar_mixamo:
		fin = maxf(fin, duracion_mixamo + 0.25)
		tapa = maxf(contacto_mixamo - Cofre3D.T_ANTICIPA, 0.0)
		sale = maxf(sale, contacto_mixamo + 0.55)
	var retraso: float = maxf(sale - (1.75 if legendario else 1.3), 0)
	var abre_libro: float = _t_continuar if _continuado else INF
	var vuelo: float = 3.05 + retraso + T_TRAVELLING - 0.65
	var inscribe: float = 3.8 + retraso + T_TRAVELLING - 0.65
	var confirma: float = 4.5 + retraso + T_TRAVELLING - 0.65 if legendario else 1.9
	fin = maxf(fin, confirma + 0.65 if legendario else fin)
	if _continuado:
		fin = maxf(fin, _t_continuar + 0.65)
	var presentacion_en: float = sale + T_TRAVELLING
	if not _continuado and t >= presentacion_en:
		t = maxf(tiempo_anterior, presentacion_en)
	_actualizar_travelling(sale, fin)
	if _evento("tapa", tapa):
		if ctrl != null:
			ctrl.abrir()
		fase = "apertura"
	if _evento("sale", sale):
		_runa.visible = true
		_abanico.visible = not efectos_reducidos
		Sfx.play(cofre, "logro_acierto" if legendario else "logro_brillo")
		fase = "runa" if legendario else "recompensa"
		if _pj != null and not usar_mixamo:
			_pj.animacion_actual = ""
			_pj.jugar("idle")
	if _libro != null:
		_libro.visible = _continuado and t >= abre_libro
		var abre: float = smoothstep(abre_libro, vuelo, t) if _continuado else 0.0
		var cierra: float = 1.0 - smoothstep(fin - 0.4, fin, t) if _continuado else 1.0
		_libro.poner_apertura(abre * cierra)
		var recogida: float = smoothstep(fin - 0.4, fin, t) if _continuado else 0.0
		var cinto: Vector3 = _pj.punto_ceremonia_libro() if _pj != null else _libro_pos - Vector3.UP * 0.6
		_libro.global_position = _libro_pos.lerp(cinto, recogida)
		_libro.scale = Vector3.ONE * lerpf(1.0, 0.25, recogida)
		if _evento("libro", abre_libro):
			Sfx.play(cofre, "libro_abre")
		if _evento("vuelo", vuelo):
			fase = "vuelo"
		if t >= vuelo:
			var k: float = smoothstep(vuelo, inscribe, t)
			var destino: Vector3 = _libro.pagina.global_position
			_runa.global_position = _alto.lerp(destino, k) + Vector3.UP * sin(k * PI) * 0.3
			var q0: Quaternion = _cam.global_basis.get_rotation_quaternion() if _cam != null else Quaternion.IDENTITY
			var q1: Quaternion = (_libro.pagina.global_basis * Basis(Vector3.RIGHT, -PI / 2)).get_rotation_quaternion()
			_runa.global_basis = Basis(q0.slerp(q1, k)).scaled(Vector3.ONE * lerpf(1.0, 0.45, k))
			for i in _estela.size():
				var h: float = k - (i + 1) * 0.035
				_estela[i].visible = h > 0 and t < inscribe and not efectos_reducidos
				_estela[i].global_position = _alto.lerp(destino, maxf(h, 0)) + Vector3.UP * sin(maxf(h, 0) * PI) * 0.3
				_estela[i].scale = Vector3.ONE * (1.0 - i / 12.0)
			if t >= inscribe:
				fase = "inscripcion"
				var tinta_v: float = smoothstep(inscribe, inscribe + 0.18, t)
				_runa.visible = tinta_v < 1.0
				(_runa.material_override as StandardMaterial3D).albedo_color.a = 1.0 - tinta_v
				_libro.inscribir(_tex, tinta_v)
				_nombre.global_position = _libro.global_position + Vector3.UP * 0.65
		if _evento("inscribir", inscribe):
			Sfx.play(cofre, "pulso_resonante")
		if _continuado and _evento("cierra", fin - 0.4):
			Sfx.play(cofre, "libro_cierra")
	if t < vuelo or not legendario:
		_runa.global_position = _origen.lerp(_alto, smoothstep(sale, sale + 0.4, t))
		if _cam != null:
			_runa.global_basis = _cam.global_basis * Basis(Vector3.FORWARD, sin(t * 2) * 0.10)
			if _tex == null and objeto_presentado == "oro":
				_runa.rotate_object_local(Vector3.RIGHT, PI / 2)
	_aro.visible = legendario and t >= sale and t < vuelo and not efectos_reducidos
	_aro.global_position = _runa.global_position - (_cam.global_basis.z * 0.03 if _cam != null else Vector3.ZERO)
	if _cam != null:
		_aro.global_basis = _cam.global_basis * Basis(Vector3.FORWARD, t * 0.15)
	_aro.scale = Vector3.ONE * smoothstep(sale, sale + 0.45, t)
	(_aro.material_override as ShaderMaterial).set_shader_parameter("progreso", smoothstep(sale, sale + 0.6, t))
	var onda_t: float = clampf((t - tapa - Cofre3D.T_ANTICIPA) / 0.85, 0, 1)
	_onda.visible = legendario and onda_t > 0 and onda_t < 1 and not efectos_reducidos
	_onda.scale = Vector3.ONE * lerpf(0.25, 2.1, onda_t)
	(_onda.material_override as StandardMaterial3D).albedo_color.a = (1.0 - onda_t) * 0.35
	_abanico.scale = Vector3.ONE * maxf(0.01, 1.0 - smoothstep(sale, sale + 0.8, t))
	_nombre.visible = t >= (inscribe if legendario else sale)
	var entrada: float = smoothstep(0, 0.55, t)
	var salida: float = 1.0 - smoothstep(fin - 0.65, fin, t) if _continuado else 1.0
	var cine: float = entrada * salida if not efectos_reducidos else 0.0
	luz_baja = lerpf(1.0, LUZ_ZONA_FRACCION, cine)
	if _sol != null:
		_sol.light_energy = _sol0 * luz_baja
	if _env != null:
		_env.ambient_light_energy = _amb0 * luz_baja
	if _evento("confirmar", confirma):
		_confirmar()
	if not _continuado and t >= presentacion_en:
		_esperar_confirmacion()
	elif saltada or (_continuado and t >= fin):
		_finalizar()

func _confirmar() -> void:
	if _confirmada:
		return
	_confirmada = true
	escrito = true
	if not modo_prueba and not glifo.is_empty():
		glifo_nuevo = Repertoire.conseguir_sigil(glifo)
		Flags.i().poner(Puzle3D.FLAG_GLIFO_GANADO + glifo)
		if glifo_nuevo:
			pagina_equipada = _equipar()
	if not glifo.is_empty():
		glifo_escrito.emit()
	recompensa_lista.emit()

func saltar() -> bool:
	if esperando_input:
		return continuar()
	if not activa or not saltable or saltada:
		return false
	saltada = true
	_finalizar()
	return true

func _finalizar() -> void:
	if hecha:
		return
	_confirmar()
	if ctrl != null and is_instance_valid(ctrl):
		ctrl.abrir_ya()
	_cerrar_lamina()
	_restaurar()
	activa = false
	esperando_input = false
	remove_from_group("ceremonia_cofre_activa")
	hecha = true
	fase = "fin"
	if not modo_prueba and not glifo.is_empty():
		Flags.i().poner(FLAG_VISTA)
		if is_instance_valid(_lanz):
			AvisoObjeto.mostrar_texto(_lanz, "Runa inscrita: " + Sigils.nombre_visible(glifo), calidad, "glifo:" + glifo)
		_mostrar_pista()
	terminada.emit()
	if not modo_prueba:
		get_tree().create_timer(2.6).timeout.connect(queue_free)

func _restaurar() -> void:
	if _restaurado:
		return
	_restaurado = true
	if is_instance_valid(_cam_juego):
		_cam_juego.make_current()
		_cam = _cam_juego
	if is_instance_valid(_aviso_continuar):
		_aviso_continuar.queue_free()
	if is_instance_valid(_cam):
		_cam.size = _tam0
		_cam.h_offset = _h0
		_cam.v_offset = _v0
	if is_instance_valid(mundo) and _tam_mundo0 != null:
		mundo.set("_tam_camara", _tam_mundo0)
	if is_instance_valid(_sol):
		_sol.light_energy = _sol0
	if is_instance_valid(_env):
		_env.ambient_light_energy = _amb0
	if is_instance_valid(_pj):
		_pj.terminar_ceremonia_libro()
		_pj.animacion_actual = ""
		_pj.jugar("idle")
	if is_instance_valid(_jugador):
		_jugador.set("animacion_externa", _externa0)
		if _jugador.has_method("bloquear"):
			_jugador.call("bloquear", _bloqueado0)
	if is_instance_valid(ctrl):
		ctrl.gesto_externo = false
	if is_instance_valid(_visuales):
		_visuales.queue_free()

func cancelar() -> void:
	# Una interacción ya aceptada debe dejar cofre y progreso concordantes incluso al salir.
	if activa:
		_finalizar()

func _exit_tree() -> void:
	if activa:
		_confirmar()
		_cerrar_lamina()
		_restaurar()
		activa = false

func _input(ev: InputEvent) -> void:
	if not activa:
		return
	var nueva: bool = false
	if ev is InputEventKey:
		nueva = ev.pressed and not ev.echo and (ev.keycode in [KEY_E, KEY_ENTER, KEY_SPACE] or ev.is_action_pressed("interactuar") or ev.is_action_pressed("ui_accept"))
	elif ev is InputEventJoypadButton:
		nueva = ev.pressed and (ev.button_index == JOY_BUTTON_A or ev.is_action_pressed("ui_accept") or ev.is_action_pressed("interactuar"))
	if esperando_input and nueva and _pulsar_continuar():
		get_viewport().set_input_as_handled()
	elif not esperando_input and saltable and ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		if saltar():
			get_viewport().set_input_as_handled()

func continuar() -> bool:
	if not activa or not esperando_input:
		return false
	esperando_input = false
	_continuado = true
	_cerrar_lamina()
	_t_continuar = t
	fase = "libro" if _libro != null else "recompensa"
	if is_instance_valid(_aviso_continuar):
		_aviso_continuar.visible = false
	return true

func _esperar_confirmacion() -> void:
	esperando_input = true
	fase = "presentacion"
	if not glifo.is_empty():
		_lamina = LaminaGlifo.mostrar(self, glifo, true, false)      # la ficha de la runa (23/11): trae su propio nombre, así que se oculta el rótulo 3D
		_nombre.visible = false
	else:
		_nombre.visible = true
	_nombre.global_position = _alto + Vector3.UP * 0.52
	_mirar_cofre()
	if _aviso_continuar == null:
		_aviso_continuar = CanvasLayer.new()
		_aviso_continuar.layer = 80
		add_child(_aviso_continuar)
		var panel := Control.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aviso_continuar.add_child(panel)
		var boton := Button.new()
		boton.text = "Continuar  ·  E / Espacio / Intro / A"
		boton.focus_mode = Control.FOCUS_NONE
		panel.add_child(boton)
		boton.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		boton.offset_left = -230
		boton.offset_right = 230
		boton.offset_top = -72
		boton.offset_bottom = -24
		boton.pressed.connect(_pulsar_continuar)

func _preparar_travelling() -> void:
	if _cam == null:
		return
	_cam_juego = _cam
	_cam_inicio = _cam.global_transform
	var cine := Camera3D.new()
	cine.name = "CamaraTesoro"
	cine.projection = _cam.projection
	cine.fov = _cam.fov
	cine.size = _cam.size
	cine.near = minf(_cam.near, 0.05)
	cine.far = _cam.far
	cine.keep_aspect = _cam.keep_aspect
	cine.cull_mask = _cam.cull_mask
	_visuales.add_child(cine)
	cine.global_transform = _cam_inicio
	cine.h_offset = _h0
	cine.v_offset = _v0
	var base: Vector3 = _acercar_a if _jugador != null else (_pj.global_position if _pj != null else cofre.global_position)
	_orbita_centro = base + Vector3.UP * 0.9
	_orbita_foco = (base + Vector3.UP * 0.75 + _alto) * 0.5
	var relativo: Vector3 = _cam_inicio.origin - _orbita_centro
	_orbita_radio = maxf(Vector2(relativo.x, relativo.z).length(), 0.1)
	_orbita_altura = relativo.y
	_orbita_angulo = atan2(relativo.x, relativo.z)
	_cam_tamano = clampf(_tam0 * 0.55, 2.6, 3.6)
	_cam = cine
	cine.make_current()

func _actualizar_travelling(sale: float, fin: float) -> void:
	if not is_instance_valid(_cam) or not is_instance_valid(_cam_juego):
		return
	var k: float = smoothstep(sale, sale + T_TRAVELLING, t) if not efectos_reducidos else 0.0
	var regreso: float = smoothstep(fin - 0.65, fin, t) if _continuado else 0.0
	var pose: Transform3D = _pose_orbita(k * (1.0 - regreso))
	var tam: float = lerpf(_tam0, _cam_tamano, k)
	_cam.global_transform = pose.interpolate_with(_cam_juego.global_transform, regreso)
	_cam.size = lerpf(tam, _tam0, regreso)
	_cam.h_offset = lerpf(_h0, 0.0, k * (1.0 - regreso))
	_cam.v_offset = lerpf(_v0, 0.0, k * (1.0 - regreso))
	if _libro != null and not _continuado:
		_libro.global_basis = _cam.global_basis * Basis(Vector3.RIGHT, PI * 0.33)

## Espiral en coordenadas polares: el centro es el personaje, no la cámara.
func _pose_orbita(k: float) -> Transform3D:
	var avance: float = clampf(k, 0.0, 1.0)
	var angulo: float = _orbita_angulo + deg_to_rad(ORBITA_GRADOS) * avance
	var radio: float = lerpf(_orbita_radio, 3.3, avance)
	var altura: float = lerpf(_orbita_altura, 1.05, avance)
	var posicion: Vector3 = _orbita_centro + Vector3(sin(angulo) * radio, altura, cos(angulo) * radio)
	var mirada := Basis.looking_at(_orbita_foco - posicion, Vector3.UP)
	var giro: Quaternion = _cam_inicio.basis.get_rotation_quaternion().slerp(mirada.get_rotation_quaternion(), avance)
	return Transform3D(Basis(giro), posicion)

## Mirar usa también el yaw interno de Pj3D; tocar solo rotation deja el gesto girado al repetir.
func _mirar_cofre() -> void:
	if not is_instance_valid(_pj) or not is_instance_valid(cofre):
		return
	var desde: Vector3 = _jugador.global_position if is_instance_valid(_jugador) else _pj.global_position
	var hacia: Vector3 = cofre.global_position - desde
	hacia.y = 0.0
	if hacia.length_squared() < 0.0001:
		return
	if is_instance_valid(_jugador) and _jugador.has_method("mirar_hacia"):
		_jugador.call("mirar_hacia", hacia)
	_pj.mirar(hacia, 1.0)


## Una pulsación de «continuar» (E, Espacio, Intro, A o el botón): si la ficha de la runa aún se está escribiendo, la completa de golpe; si no, sigue como siempre.
func _pulsar_continuar() -> bool:
	if is_instance_valid(_lamina) and not _lamina.texto_completo():
		_lamina.completar_texto()
		return true
	return continuar()


func _cerrar_lamina() -> void:
	if is_instance_valid(_lamina):
		_lamina.cerrar()
	_lamina = null


## H6 (23/11): el glifo NUEVO se deja escrito en una página y esa página queda seleccionada (`Grimorio.equipar_glifo_nuevo`; el libro sigue anotándolo en su cola `_por_escribir`).
## Devuelve la página o -1 (no cabe en ninguna, o no hay libro: no se toca nada).
func _equipar() -> int:
	if _lanz == null or not _lanz.has_method("equipar_glifo_nuevo"):
		return -1
	return int(_lanz.call("equipar_glifo_nuevo", glifo))


## Al cerrarse la ceremonia: si el glifo se equipó, la pista de uso inmediato (HUD + marcador, `PistaGlifo`); si no cupo en ninguna página, el aviso de siempre. No sale en `modo_prueba`.
func _mostrar_pista() -> void:
	if modo_prueba or glifo.is_empty() or not glifo_nuevo or not is_instance_valid(_lanz):
		return
	if pagina_equipada >= 0:
		var celda: Variant = reto_en if reto_en is Vector2i else null
		pista = PistaGlifo.crear(_lanz, glifo, pagina_equipada, reto, celda)
	else:
		var lz: Node = _lanz
		var tecla: String = Controles.texto_teclas("libro")
		get_tree().create_timer(2.4).timeout.connect(func():
			if is_instance_valid(lz) and lz.has_method("avisar"):
				lz.call("avisar", "Escríbelo en el libro (%s)" % tecla, Color(1.0, 0.9, 0.6)))
