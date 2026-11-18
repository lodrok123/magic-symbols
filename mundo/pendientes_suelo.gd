@tool
class_name PendientesSuelo3D
extends MeshInstance3D
## Rampa suave al pie de cada desnivel del GridMap hermano `Suelo`: en vez del escalón
## vertical, una falda inclinada que baja desde la arista de la casilla alta y se apoya
## sobre la casilla baja. Solo es visual: el juego sigue contando las plantas por casilla.
## Se rehace sola en el editor al pintar el suelo. En el juego, el mundo le pone el
## shader del suelo (`material_juego`) para que la textura y las costuras sigan por la rampa.

## Cuánto entra la rampa en la casilla baja por cada metro de desnivel.
@export_range(0.5, 4.0) var tendido := 4.0
## Ancho mínimo y máximo de la rampa (m).
@export var ancho_min := 0.9
@export var ancho_max := 1.4

var material_juego: Material:
	set(v):
		material_juego = v
		for i in get_surface_override_material_count():
			set_surface_override_material(i, v)

var _firma := -1
var _espera := 0.0

const VECINOS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	construir()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	_espera += delta
	if _espera < 0.5:
		return
	_espera = 0.0
	var suelo := _suelo()
	if suelo and _firma_de(suelo) != _firma:
		construir()


func _suelo() -> GridMap:
	return get_parent().get_node_or_null("Suelo") as GridMap


func _firma_de(suelo: GridMap) -> int:
	var h := suelo.get_used_cells().size()
	for u in suelo.get_used_cells():
		h = hash([h, u, suelo.get_cell_item(u)])
	return h


func construir() -> void:
	var suelo := _suelo()
	if suelo == null or suelo.mesh_library == null:
		return
	_firma = _firma_de(suelo)
	transform = suelo.transform
	var lib := suelo.mesh_library
	var tope := topes(suelo)
	_quitar_rampas()
	var lado := suelo.cell_size.x
	var por_item: Dictionary = {}   # item -> SurfaceTool
	for c in tope:
		var y_alto: float = tope[c][0]
		var item: int = tope[c][1]
		var centro := suelo.map_to_local(Vector3i(c.x, 0, c.y))
		var bajos: Dictionary = {}  # dirección -> y del vecino bajo
		for v in VECINOS:
			var n: Vector2i = c + v
			if tope.has(n) and float(tope[n][0]) < y_alto - 0.05:
				bajos[v] = float(tope[n][0])
		if bajos.is_empty():
			continue
		if not por_item.has(item):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			por_item[item] = st
		var st: SurfaceTool = por_item[item]
		for v in bajos:
			var y_bajo: float = bajos[v]
			var w := clampf((y_alto - y_bajo) * tendido, ancho_min, ancho_max)
			var normal := Vector3(v.x, 0, v.y)
			var lateral := Vector3(-v.y, 0, v.x)
			var borde := Vector3(centro.x, 0, centro.z) + normal * lado * 0.5
			var a := borde - lateral * lado * 0.5
			var b := borde + lateral * lado * 0.5
			# Arriba arranca a la altura de la capa de costuras (+0,02) para no dejar una rendija.
			_quad(st, a + Vector3.UP * (y_alto + 0.02), b + Vector3.UP * (y_alto + 0.02),
				b + normal * w + Vector3.UP * (y_bajo + 0.035), a + normal * w + Vector3.UP * (y_bajo + 0.035))
			_registrar_rampa(borde, normal, w, y_alto - y_bajo)
		# Esquinas salientes: dos lados contiguos bajan -> cuña para cerrar el hueco.
		for i in 4:
			var v1: Vector2i = VECINOS[[0, 2, 1, 3][i]]
			var v2: Vector2i = VECINOS[[2, 1, 3, 0][i]]
			if not (bajos.has(v1) and bajos.has(v2)):
				continue
			var y_bajo := maxf(bajos[v1], bajos[v2])
			var w := clampf((y_alto - y_bajo) * tendido, ancho_min, ancho_max)
			var n1 := Vector3(v1.x, 0, v1.y)
			var n2 := Vector3(v2.x, 0, v2.y)
			var p := Vector3(centro.x, y_alto + 0.02, centro.z) + (n1 + n2) * lado * 0.5
			var yb := Vector3.UP * (y_bajo + 0.015 - y_alto)
			_tri(st, p, p + n1 * w + yb, p + (n1 + n2) * w + yb)
			_tri(st, p, p + (n1 + n2) * w + yb, p + n2 * w + yb)
	var malla := ArrayMesh.new()
	for item in por_item:
		var st: SurfaceTool = por_item[item]
		malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
		var caja := lib.get_item_mesh(item) as BoxMesh
		malla.surface_set_material(malla.get_surface_count() - 1, material_juego if material_juego else (caja.material if caja else null))
	mesh = malla


## Altura de la cara de arriba de cada columna del GridMap (en local del GridMap), con el giro
## de cada casilla. Vector2i -> [y_arriba, item]. La usan también la maqueta y las costuras.
static func topes(suelo: GridMap) -> Dictionary:
	var lib := suelo.mesh_library
	var tope: Dictionary = {}
	for u in suelo.get_used_cells():
		var item := suelo.get_cell_item(u)
		var caja := lib.get_item_mesh(item) as BoxMesh
		var giro := suelo.get_basis_with_orthogonal_index(suelo.get_cell_item_orientation(u))
		var alto_caja := absf((giro * caja.size).y) * 0.5 if caja else 0.0
		var y := suelo.map_to_local(u).y + (giro * lib.get_item_mesh_transform(item).origin).y + alto_caja
		var c := Vector2i(u.x, u.z)
		if not tope.has(c) or float(tope[c][0]) < y:
			tope[c] = [y, item]
	return tope


# En el juego, cada rampa se apunta en Terreno3D.rampas para que los pies suban por ella.
var _celdas_rampa: Array[Vector2i] = []


func _registrar_rampa(borde_local: Vector3, normal: Vector3, w: float, desnivel: float) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var borde := to_global(borde_local)
	var n := Vector2(normal.x, normal.z)
	var dato := [n, Vector2(borde.x, borde.z).dot(n), w, desnivel]
	# La rampa cae sobre la casilla baja (y, si es muy ancha, la siguiente).
	var paso := 0.0
	while paso < w:
		var p := borde + normal * (paso + 0.01)
		var c := Terreno3D.celda_de(p)
		if not Terreno3D.rampas.has(c):
			Terreno3D.rampas[c] = []
		(Terreno3D.rampas[c] as Array).append(dato)
		_celdas_rampa.append(c)
		paso += Terreno3D.casilla


func _quitar_rampas() -> void:
	for c in _celdas_rampa:
		Terreno3D.rampas.erase(c)
	_celdas_rampa.clear()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		_quitar_rampas()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Cara hacia arriba (orden antihorario visto desde arriba en Godot = horario en XZ).
	# Normal hacia arriba: el shader del suelo trata la rampa como suelo (no como lateral) y la luz no la marca.
	st.set_normal(Vector3.UP)
	var n := (b - a).cross(c - a)
	if n.y < 0.0:
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	else:
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
