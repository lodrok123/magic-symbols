extends Node3D

## LABORATORIO DE LA ROCA DE ROCKFORM (18/11/2026, Pablo: «hazme una roca de prueba y expórtala a Godot y probamos cómo queda»).
## Enseña la roca generada con el addon RockForm de Blender (arte/rockform/roca_rf_prueba.glb) al lado de una roca del pack
## estilizado que ya usa el juego (`roca_est_musgo_1`), sobre un suelo plano, para comparar forma, tamaño y cómo coge la luz.
## La roca de RockForm llega SIN material ni UV (el addon se lo quita a la versión low-poly): aquí se le pone un color liso.
##
##
## PLATAFORMA DE TIERRA (18/11, Pablo: «de esta lista puedes probar 8 y 13 para la plataforma de tierra»). Fila de delante: la plataforma que
## levanta hoy el hechizo (`Lanzador3D.levantar_plataforma_tierra`: la losa `TierraToy.MALLA_LOSA` estirada a una casilla) y cuatro candidatas
## de RockForm, dos de la familia 8 (Jagged Slabs) y dos de la 13 (Floating Islands, recortadas por abajo). Todas con el mismo `TierraToy.asentar`
## que usa el juego (2,3 × 0,45 × 2,3 m) y el shader de roca del juego; las candidatas en color plano porque no traen UV.
##
## Teclas: arrastrar = orbitar · rueda = zoom · C cambia el color de la roca (pardo cueva / gris / musgo) · L gira la luz
##   P plataformas: talla del juego (estiradas a la casilla) / proporción con la que salieron de Blender
## Abrir: laboratorios/LabRocaRockform.tscn y F6.
## Captura automática (para pruebas): `-- --captura=C:/ruta/imagen.png` guarda una imagen tras unos fotogramas y cierra.

const RUTA_ROCA: String = "res://arte/rockform/roca_rf_prueba.glb"
const ROCA_JUEGO: String = "roca_est_musgo_1"
const SEPARACION: float = 1.7
## Colores de prueba, sacados a ojo de las texturas del pack de rocas del juego (parda de cueva, gris neutro, verde musgo).
const COLORES: Array = [Color(0.45, 0.39, 0.33), Color(0.52, 0.52, 0.5), Color(0.36, 0.42, 0.27)]
const NOMBRES_COLOR: Array = ["pardo cueva", "gris", "musgo"]

## Candidatas a plataforma de tierra: archivo en arte/rockform y rótulo.
const PLATAFORMAS: Array = [
	["plataforma_rf_08_a", "8 · Jagged Slabs A (suave)"], ["plataforma_rf_08_b", "8 · Jagged Slabs B (facetada)"],
	["plataforma_rf_13_a", "13 · Floating Islands A (suave)"], ["plataforma_rf_13_b", "13 · Floating Islands B (facetada)"]]
const PASO_PLATAFORMA: float = 3.0     ## separación entre plataformas (m)
const Z_PLATAFORMAS: float = 3.6       ## la fila va delante de las rocas

var _plataformas: Array = []           ## MeshInstance3D de las candidatas (para alternar la talla)
var _talla_juego: bool = true
var _cam: Camera3D = null
var _luz: DirectionalLight3D = null
var _mat: StandardMaterial3D = null
var _texto: Label = null
var _yaw: float = 0.6
var _pitch: float = 0.55
var _dist: float = 13.5
var _foco: Vector3 = Vector3(0.0, 0.3, 2.8)
var _color: int = 0
var _tris: int = 0
var _tam: Vector3 = Vector3.ZERO
var _captura: String = ""
var _fotogramas: int = 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captura="):
			_captura = a.trim_prefix("--captura=")
	_montar_entorno()
	_montar_roca_rockform()
	_montar_roca_juego()
	_montar_plataformas()
	_montar_panel()
	_colocar_camara()


func _montar_entorno() -> void:
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color(0.45, 0.62, 0.85)
	cielo.sky_horizon_color = Color(0.78, 0.84, 0.88)
	cielo.ground_horizon_color = Color(0.6, 0.65, 0.6)
	var sky := Sky.new()
	sky.sky_material = cielo
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_luz = DirectionalLight3D.new()
	_luz.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	_luz.shadow_enabled = true
	_luz.light_energy = 1.2
	add_child(_luz)
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(24.0, 24.0)
	suelo.mesh = plano
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.36, 0.5, 0.28)
	ms.roughness = 1.0
	suelo.material_override = ms
	add_child(suelo)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)


func _montar_roca_rockform() -> void:
	var escena := load(RUTA_ROCA) as PackedScene
	if escena == null:
		push_error("LabRocaRockform: no se pudo cargar %s (¿falta importarla? abre el editor una vez)" % RUTA_ROCA)
		return
	var roca := escena.instantiate() as Node3D
	roca.position = Vector3(-SEPARACION, 0.0, 0.0)
	add_child(roca)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLORES[_color]
	_mat.roughness = 0.9
	var caja := AABB()
	var primera: bool = true
	for mi in _mallas(roca):
		(mi as MeshInstance3D).material_override = _mat
		var m: Mesh = (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var datos: Array = m.surface_get_arrays(s)
			var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
			_tris += (indices.size() if indices.size() > 0 else (datos[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var ab: AABB = m.get_aabb()
		caja = ab if primera else caja.merge(ab)
		primera = false
	_tam = caja.size
	_etiqueta("RockForm (Blender)", roca.position + Vector3(0.0, _tam.y + 0.35, 0.0))


func _montar_roca_juego() -> void:
	var v: Node3D = Pieza3D.crear_visual(ROCA_JUEGO)
	if v == null:
		push_warning("LabRocaRockform: no hay modelo para %s; se enseña solo la roca de RockForm" % ROCA_JUEGO)
		return
	v.position = Vector3(SEPARACION, 0.0, 0.0)
	add_child(v)
	_etiqueta("Juego: %s" % ROCA_JUEGO, v.position + Vector3(0.0, float(Pieza3D.MEDIDA.get(ROCA_JUEGO, 1.3)) + 0.35, 0.0))


## Fila de plataformas: primero la del juego, luego las candidatas. Mismo tamaño y misma colocación que `Lanzador3D.levantar_plataforma_tierra`.
func _montar_plataformas() -> void:
	var n: int = PLATAFORMAS.size() + 1
	var x0: float = -PASO_PLATAFORMA * float(n - 1) * 0.5
	var actual := MeshInstance3D.new()
	actual.mesh = TierraToy.malla_roca(TierraToy.MALLA_LOSA)
	actual.material_override = TierraToy.material_roca({"base_tierra": 1.0})
	actual.position = Vector3(x0, 0.0, Z_PLATAFORMAS)
	add_child(actual)
	_asentar(actual, true)
	_etiqueta("Juego: plataforma actual", actual.position + Vector3(0.0, 1.0, 0.0), 30)
	for i in PLATAFORMAS.size():
		var escena := load("res://arte/rockform/%s.glb" % PLATAFORMAS[i][0]) as PackedScene
		if escena == null:
			push_error("LabRocaRockform: falta %s.glb" % PLATAFORMAS[i][0])
			continue
		var raiz: Node = escena.instantiate()
		var mallas: Array = _mallas(raiz)
		var mi := MeshInstance3D.new()
		mi.mesh = (mallas[0] as MeshInstance3D).mesh
		raiz.free()
		mi.material_override = TierraToy.material_roca({"base_tierra": 1.0, "plano": 1.0})
		mi.position = Vector3(x0 + PASO_PLATAFORMA * float(i + 1), 0.0, Z_PLATAFORMAS)
		add_child(mi)
		_asentar(mi, true)
		_plataformas.append(mi)
		_etiqueta(str(PLATAFORMAS[i][1]), mi.position + Vector3(0.0, 1.0, 0.0), 30)


## Estira la malla a la casilla de la plataforma (como el juego) o la deja con su proporción de Blender (solo centrada y apoyada).
func _asentar(mi: MeshInstance3D, talla_juego: bool) -> void:
	var p: Vector3 = mi.position
	if talla_juego:
		mi.transform = TierraToy.asentar(mi.mesh, Basis.IDENTITY, Terreno3D.casilla, Lanzador3D.ALTO_PLATAFORMA_TIERRA, Terreno3D.casilla, Vector3.ZERO)
	else:
		var a: AABB = mi.mesh.get_aabb()
		mi.transform = Transform3D(Basis.IDENTITY, -Vector3(a.position.x + a.size.x * 0.5, a.position.y, a.position.z + a.size.z * 0.5))
	mi.position += p


func _mallas(n: Node) -> Array:
	var r: Array = []
	if n is MeshInstance3D:
		r.append(n)
	for h in n.get_children():
		r.append_array(_mallas(h))
	return r


func _etiqueta(texto: String, pos: Vector3, cuerpo: int = 40) -> void:
	var l := Label3D.new()
	l.text = texto
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = cuerpo
	l.pixel_size = 0.005
	l.outline_size = 10
	l.position = pos
	add_child(l)


func _montar_panel() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	_texto = Label.new()
	_texto.position = Vector2(16.0, 12.0)
	_texto.add_theme_font_size_override("font_size", 18)
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_texto.add_theme_constant_override("outline_size", 6)
	capa.add_child(_texto)
	_refrescar_texto()


func _refrescar_texto() -> void:
	_texto.text = "Roca de RockForm: %d triángulos · %.2f × %.2f × %.2f m (ancho × alto × fondo) · color: %s\nPlataformas: %s (P cambia)\nArrastrar = orbitar · rueda = zoom · C color · L girar la luz" % [
		_tris, _tam.x, _tam.y, _tam.z, NOMBRES_COLOR[_color],
		"talla del juego 2,30 × 0,45 × 2,30 m" if _talla_juego else "proporción de Blender, sin estirar"]


func _colocar_camara() -> void:
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	_cam.position = _foco + dir * _dist
	_cam.look_at(_foco, Vector3.UP)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (e as InputEventMouseMotion).button_mask != 0:
		var mm := e as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.008
		_pitch = clampf(_pitch + mm.relative.y * 0.006, 0.05, 1.45)
		_colocar_camara()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(1.5, _dist - 0.4)
			_colocar_camara()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(20.0, _dist + 0.4)
			_colocar_camara()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var k := e as InputEventKey
		if k.keycode == KEY_C and _mat != null:
			_color = (_color + 1) % COLORES.size()
			_mat.albedo_color = COLORES[_color]
			_refrescar_texto()
		elif k.keycode == KEY_L:
			_luz.rotate_y(deg_to_rad(30.0))
		elif k.keycode == KEY_P:
			_talla_juego = not _talla_juego
			for mi in _plataformas:
				var p: Vector3 = Vector3((mi as MeshInstance3D).position.x, 0.0, Z_PLATAFORMAS)
				(mi as MeshInstance3D).transform = Transform3D.IDENTITY
				(mi as MeshInstance3D).position = p
				_asentar(mi, _talla_juego)
			_refrescar_texto()


func _process(_dt: float) -> void:
	if _captura == "":
		return
	_fotogramas += 1
	if _fotogramas == 30:
		get_viewport().get_texture().get_image().save_png(_captura)
		get_tree().quit()
