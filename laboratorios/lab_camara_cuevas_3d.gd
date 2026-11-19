extends "res://presentacion/prueba_test2.gd"
## Variante jugable de las cuevas reales; no modifica sus escenas ni mapas originales.
const BordesCueva = preload("res://laboratorios/camara_bordes_bosque.gd")
const PRUEBAS_CUEVAS: Array[String] = [
	"res://laboratorios/LabCamaraCuevas3D.tscn",
	"res://laboratorios/LabCamaraCuevaAgua3D.tscn",
	"res://laboratorios/LabCamaraCuevaResonante3D.tscn",
	"res://laboratorios/LabCamaraGrutaBatida3D.tscn"]
@export var indice_cueva: int = 0
@export var perimetro_disperso: bool = true
var bloqueo_cueva: bool = true
var por_sala: bool = true
var limites_mapa := Rect2()
var limites_vista := Rect2()
var salas_camara: Array[Rect2i] = []
var sala_actual: int = -1
var zoom_solicitado: float = 6.0
var _limites_listos: bool = false
var _texto_bordes: Label
var _inicio_camara := Vector2i.ZERO
var paredes_exteriores: int = 0
var paredes_reducidas: int = 0
var bloqueada_x: bool = false
var bloqueada_z: bool = false
var mostrar_limites: bool = true
var _guia_bordes: MeshInstance3D
var _tiempo_transicion: float = 0.0
var _delta_camara: float = 1.0/60.0
var _foco_anterior := Vector3.ZERO
var _aplicando_frame: bool = false

func _ready() -> void:
	get_tree().node_added.connect(_detener_salida)
	if OS.get_cmdline_user_args().has("--muros-completos"):
		perimetro_disperso = false
	super._ready()
	_hud.visible = false
	if _contacto_aviso != null:
		_contacto_aviso.visible = false
	for panel in find_children("*", "PanelContainer", true, false):
		if panel.get_script() != null and panel.get_script().resource_path == "res://presentacion/ui/rune_palette.gd":
			panel.visible = false # F1 permite recuperarla para lanzar hechizos.
	# La salida original devuelve al bosque de producción y cerraría esta prueba.
	for salida in find_children("*", "SalidaNivel3D", true, false):
		salida.process_mode = Node.PROCESS_MODE_DISABLED
	limites_mapa = Rect2(Vector2.ZERO, Vector2(_ancho, _alto) * S).grow(-0.15)
	limites_vista = limites_mapa
	var zonas := get_node_or_null("Zonas3D") as Zonas3D
	if zonas != null:
		for z: Dictionary in zonas.zonas:
			salas_camara.append(z["rect"] as Rect2i)
	# La luz de C1 incluye el nicho tras la pared sur: no es una sala de cámara.
	if nivel in ["Cueva", "CuevaResonante"] and not salas_camara.is_empty():
		salas_camara[0] = Rect2i(1, 11, 8, 8)
		salas_camara.append(Rect2i(5, 20, 5, 4))
	if _jugador != null:
		_inicio_camara = Terreno3D.celda_de(_jugador.position)
	zoom_solicitado = _tam_camara
	_limites_listos = true
	var capa := CanvasLayer.new()
	capa.layer = 40
	add_child(capa)
	_texto_bordes = Label.new()
	_texto_bordes.position = Vector2(16, 176)
	_texto_bordes.add_theme_font_size_override("font_size", 17)
	_texto_bordes.add_theme_color_override("font_shadow_color", Color.BLACK)
	_texto_bordes.add_theme_constant_override("shadow_offset_x", 2)
	_texto_bordes.add_theme_constant_override("shadow_offset_y", 2)
	_texto_bordes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_texto_bordes)
	_guia_bordes = MeshInstance3D.new()
	_guia_bordes.name = "LimitesCamara"
	_guia_bordes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_guia_bordes)
	_actualizar_limites(1.0, true)
	_colocar_camara()

func _detener_salida(nodo: Node) -> void:
	# Puzle3D crea algunas salidas en diferido, después del _ready de la maqueta.
	if nodo is SalidaNivel3D and is_ancestor_of(nodo):
		nodo.process_mode = Node.PROCESS_MODE_DISABLED

func _pared_cueva(c: Vector2i) -> void:
	var exterior := c.x == 0 or c.y == 0 or c.x == _ancho - 1 or c.y == _alto - 1
	if exterior:
		paredes_exteriores += 1
		var esquina := (c.x == 0 or c.x == _ancho - 1) and (c.y == 0 or c.y == _alto - 1)
		if perimetro_disperso and not esquina and (c.x + c.y) % 4 != 0:
			# _colocar_letras ya bloquea las casillas #; solo se reduce el dibujo.
			paredes_reducidas += 1
			return
	super._pared_cueva(c)

func rect_sala(indice: int) -> Rect2:
	var r := salas_camara[indice]
	# Sin margen lateral exterior: debe frenarse ANTES de tocar el muro.
	# Solo al norte se reserva media casilla para proyectar la cabeza completa.
	return Rect2(Vector2(r.position) * S, Vector2(r.size) * S).grow_individual(0, S * 0.5, 0, S * 0.25).intersection(limites_mapa)

func _actualizar_limites(delta: float, inmediato: bool = false) -> void:
	if not _limites_listos or _jugador == null:
		return
	var celda := Terreno3D.celda_de(_jugador.position)
	var anterior := sala_actual
	sala_actual = -1
	for i in range(salas_camara.size() - 1, -1, -1):
		if salas_camara[i].has_point(celda):
			sala_actual = i
			break
	if inmediato:
		_tiempo_transicion = 0.0
	elif anterior != sala_actual:
		_tiempo_transicion = 0.9
	# En pasillos se libera el encuadre dentro del mapa; no se retiene la sala anterior.
	var destino := rect_sala(sala_actual) if por_sala and sala_actual >= 0 else limites_mapa
	var mezcla := 1.0 if inmediato else 1.0 - exp(-7.0 * delta)
	limites_vista = Rect2(limites_vista.position.lerp(destino.position, mezcla), limites_vista.size.lerp(destino.size, mezcla))

func _colocar_camara() -> void:
	super._colocar_camara()
	bloqueada_x = false
	bloqueada_z = false
	if not _limites_listos or not bloqueo_cueva:
		return
	# La altura del foco y la vista real se conservan (incluido el seguimiento del juego).
	_camara.size = minf(zoom_solicitado, BordesCueva.tamanio_maximo(_camara, limites_vista))
	var vista := BordesCueva.huella_desde_foco(_camara, _foco, ALTO)
	var limitado := BordesCueva.limitar(_foco, limites_vista, vista)
	bloqueada_x = absf(limitado.x - _foco.x) > 0.0001
	bloqueada_z = absf(limitado.z - _foco.z) > 0.0001
	if _aplicando_frame:
		# El nuevo rectángulo puede quedar lejos del encuadre del pasillo.
		# Acercar el foco en vez de aplicarle de golpe ese recorte.
		var suave := _foco_anterior.lerp(limitado,1.0-exp(-9.0*_delta_camara)) if _tiempo_transicion > 0 else limitado
		_foco = _foco_anterior.move_toward(suave,8.0*_delta_camara)
	else:
		_foco = limitado
	# La cabeza cruza el umbral ANTES que los pies cambien de sala.
	# Protegerla también al aproximarse a la puerta, no solo tras cambiar de área.
	_foco = _mantener_personaje_visible(_foco,vista)
	_foco = BordesCueva.limitar(_foco,limites_mapa,vista)
	bloqueada_x = bloqueada_x and absf(_foco.x-limitado.x)<0.001
	bloqueada_z = bloqueada_z and absf(_foco.z-limitado.z)<0.001
	super._colocar_camara()

func _mantener_personaje_visible(foco: Vector3, vista: Rect2) -> Vector3:
	var pies := _jugador.position
	var altura := _jugador.alto_modelo()*_jugador.scale.y
	var dir := -_camara.global_basis.z
	var suelo_pies := pies + dir*((pies.y-ALTO)/-dir.y)
	var cabeza := pies+Vector3(0,altura,0)
	var suelo_cabeza := cabeza+dir*((cabeza.y-ALTO)/-dir.y)
	# Proyectar ambos extremos al suelo da el intervalo de focos que los muestra.
	var menor := Vector2(suelo_pies.x,suelo_pies.z).min(Vector2(suelo_cabeza.x,suelo_cabeza.z))-Vector2(0.35,0.2)
	var mayor := Vector2(suelo_pies.x,suelo_pies.z).max(Vector2(suelo_cabeza.x,suelo_cabeza.z))+Vector2(0.35,0.2)
	var desde := mayor-vista.end
	var hasta := menor-vista.position
	foco.x = clampf(foco.x,desde.x,hasta.x)
	foco.z = clampf(foco.z,desde.y,hasta.y)
	return foco

func _process(delta: float) -> void:
	_delta_camara = delta
	_foco_anterior = _foco
	_tiempo_transicion = maxf(_tiempo_transicion-delta,0.0)
	_actualizar_limites(delta)
	_aplicando_frame = true
	super._process(delta)
	_aplicando_frame = false
	if _texto_bordes != null:
		_texto_bordes.modulate = Color("ffd16b") if bloqueada_x or bloqueada_z else Color.WHITE
		_texto_bordes.text = "CÁMARA v3 · %s · %s · sala %s\nX: %s · Z: %s · cámara X %.2f / Z %.2f\nFIN: probar borde oeste · INSERT: guías · WASD mover\nF6: con/sin límite · Mayús+F6: sala/mapa · Tab: cueva\nRePág/AvPág: sala · Inicio: entrada" % [nivel, "LÍMITE ACTIVO" if bloqueo_cueva else "SIN LÍMITE", str(sala_actual + 1) if sala_actual >= 0 else "pasillo", "BLOQUEADA" if bloqueada_x else "sigue", "BLOQUEADA" if bloqueada_z else "sigue", _camara.position.x, _camara.position.z]
	_dibujar_limites()

func _dibujar_limites() -> void:
	if _guia_bordes == null:
		return
	_guia_bordes.visible = mostrar_limites
	if not mostrar_limites:
		return
	var vista := BordesCueva.huella_desde_foco(_camara, _foco, ALTO)
	var minimo := limites_vista.position - vista.position
	var maximo := limites_vista.end - vista.end
	var zona_foco := Rect2(minimo, (maximo - minimo).max(Vector2.ZERO))
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for indice in 2:
		var rect := limites_vista if indice == 0 else zona_foco
		var puntos: Array[Vector2] = [rect.position, Vector2(rect.end.x,rect.position.y), rect.end, Vector2(rect.position.x,rect.end.y)]
		for i in 4:
			mesh.surface_set_color(Color.CYAN if indice == 0 else Color.GOLD)
			mesh.surface_add_vertex(Vector3(puntos[i].x, ALTO+0.05, puntos[i].y))
			mesh.surface_add_vertex(Vector3(puntos[(i+1)%4].x, ALTO+0.05, puntos[(i+1)%4].y))
	mesh.surface_end()
	_guia_bordes.mesh = mesh

func preparar_borde_oeste() -> void:
	# C1: fila de entrada despejada, sin la veta y las setas del centro de la sala.
	bloqueo_cueva = true
	por_sala = true
	zoom_solicitado = 6.0
	_tam_camara = 6.0
	if nivel in ["Cueva", "CuevaResonante"]:
		ir_a(Vector2i(3,17))
		_actualizar_limites(1.0,true)
		_colocar_camara()
	else:
		ir_a_revision(maxi(sala_actual,0),Vector2(0.3,0.85))

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_END:
				preparar_borde_oeste()
				get_viewport().set_input_as_handled()
				return
			KEY_INSERT:
				mostrar_limites = not mostrar_limites
				get_viewport().set_input_as_handled()
				return
			KEY_F6:
				if ev.shift_pressed:
					por_sala = not por_sala
				else:
					bloqueo_cueva = not bloqueo_cueva
					_camara.size = zoom_solicitado
				get_viewport().set_input_as_handled()
				return
			KEY_TAB:
				get_tree().change_scene_to_file(PRUEBAS_CUEVAS[(indice_cueva + 1) % PRUEBAS_CUEVAS.size()])
				get_viewport().set_input_as_handled()
				return
			KEY_PAGEUP, KEY_PAGEDOWN:
				if not salas_camara.is_empty():
					ir_a_sala(posmod(sala_actual + (1 if ev.keycode == KEY_PAGEDOWN else -1), salas_camara.size()))
				get_viewport().set_input_as_handled()
				return
			KEY_HOME:
				ir_a(_inicio_camara)
				_actualizar_limites(1.0, true)
				_colocar_camara()
				get_viewport().set_input_as_handled()
				return
	# Se conserva el zoom solicitado del juego, aunque el efectivo esté limitado por la sala.
	super._unhandled_input(ev)
	zoom_solicitado = _tam_camara

func ir_a_sala(indice: int) -> void:
	ir_a_revision(indice, Vector2(0.5, 0.5))

func ir_a_revision(indice: int, fraccion: Vector2) -> void:
	if indice < 0 or indice >= salas_camara.size():
		return
	var r := salas_camara[indice]
	var objetivo := Vector2(r.position) + Vector2(r.size - Vector2i.ONE) * fraccion
	var destino := Vector2i(-1,-1)
	var distancia := INF
	# No teleportar sobre agua, lava, una pieza sólida o una pared.
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x,y)
			if not Terreno3D.bloqueada(c) and _letra(c) not in ["~", "R", "c", " ", "#"]:
				var d := Vector2(c).distance_squared_to(objetivo)
				if d < distancia:
					distancia = d
					destino = c
	if destino.x >= 0:
		ir_a(destino)
		_actualizar_limites(1.0, true)
		_colocar_camara()
