extends "res://herramientas/escenario_base.gd"
## V7 de docs/PLAN_EOW_VISUAL.md: TERRAZAS CON EL SHADER DEL SUELO Y SU FALDA (Juego/Pipeline, 21/10). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_terrazas_v7.gd
## HONESTO: en headless no hay GPU; esto mide qué material lleva cada cosa, que la geometría de la tapa cae en la casilla correcta (el shader lee el mapa y
## los estados por posición XZ) y que el interruptor y las colisiones se portan. Cómo SE VE se mide con `captura_v7.gd` (con ventana).
##
##   1  con `TerraFina3D.terrazas_shader_suelo = true`: la malla «Terrazas» tiene 2 superficies, la tapa con `_mat_suelo` y el muro con `_mat_lado_suelo`
##   2  la tapa: 6 vértices por casilla elevada, todos mirando arriba, y la altura de cada vértice es la de la casilla que contiene su XZ
##   3  el labio y la falda de los escalones (BordePiedras3D de la maqueta) existen; el labio lleva el shader del suelo
##   4  el estado del juego sobre una terraza llega al shader por la misma textura que el suelo (misma casilla XZ)
##   5  interruptor apagado: una sola superficie de color por vértice y el labio de vértices, como antes
##   6  colisiones idénticas con y sin, y Terreno3D.alturas / mapa intactos

const RUTA: String = "res://escenas/PruebaTerraFina.tscn"
const LADO: float = 2.3

var _col_con: int = 0
var _h_alturas: int = 0
var _h_mapa: int = 0


func _escenario() -> void:
	TerraFina3D.terrazas_shader_suelo = true
	await cargar(RUTA)
	if maqueta == null:
		return
	await avanzar_s(1.5)               # _vigilar_alturas sondea cada 0,5 s
	_h_alturas = Terreno3D.alturas.hash()
	_h_mapa = hash(Terreno3D.mapa)
	_col_con = _contar_colisiones(maqueta)
	var mi: MeshInstance3D = _terrazas(maqueta)
	_ok("0 existe la malla Terrazas", mi != null)
	if mi == null:
		return
	_con_shader(mi)
	_tapa(mi)
	_labio_y_falda()
	await _estado()
	await _apagado()
	TerraFina3D.terrazas_shader_suelo = true


func _terrazas(raiz: Node) -> MeshInstance3D:
	for h in raiz.get_children():
		if h.name == "Terrazas" and h is MeshInstance3D and not h.is_queued_for_deletion():
			return h as MeshInstance3D
	return null


func _contar_colisiones(n: Node) -> int:
	var k: int = 0
	for h in n.get_children():
		if h is CollisionObject3D or h is CollisionShape3D:
			k += 1
		k += _contar_colisiones(h)
	return k


func _con_shader(mi: MeshInstance3D) -> void:
	var mat_suelo: Material = maqueta.get("_mat_suelo") as Material
	var mat_lado: Material = maqueta.get("_mat_lado_suelo") as Material
	var malla: ArrayMesh = mi.mesh as ArrayMesh
	_ok("1.1 la malla tiene 2 superficies (tapa y muro)", malla != null and malla.get_surface_count() == 2, "%d" % (malla.get_surface_count() if malla != null else -1))
	_ok("1.2 la tapa lleva EL MISMO material del suelo de la maqueta (shader)", malla != null and malla.surface_get_material(0) == mat_suelo and mat_suelo is ShaderMaterial)
	_ok("1.3 el muro lleva EL MISMO material del costado del suelo (triplanar)", malla != null and malla.surface_get_material(1) == mat_lado and mat_lado != null)
	_ok("1.4 sin material_override que lo pise", mi.material_override == null)


func _tapa(mi: MeshInstance3D) -> void:
	var arr: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var n_elev: int = 0
	for c in Terreno3D.alturas.keys():
		if Terreno3D.altura_en(c) > 0:
			n_elev += 1
	_ok("2.1 6 vértices por casilla elevada (%d casillas)" % n_elev, vs.size() == 6 * n_elev, "%d vértices" % vs.size())
	var todas_arriba: bool = true
	var mal_altura: int = 0
	for i in range(vs.size()):
		if ns[i].dot(Vector3.UP) < 0.999:
			todas_arriba = false
		# El vértice cae en una esquina: se desplaza un pelín hacia el centro de su triángulo para saber a qué casilla pertenece. Aquí basta con el centroide de cada triángulo.
	for t in range(0, vs.size(), 3):
		var cen: Vector3 = (vs[t] + vs[t + 1] + vs[t + 2]) / 3.0
		var c := Vector2i(int(floorf(cen.x / LADO)), int(floorf(cen.z / LADO)))
		var y_esp: float = Terreno3D.alto_suelo + float(Terreno3D.altura_en(c)) * Terreno3D.ALTO_NIVEL
		if absf(vs[t].y - y_esp) > 0.001 or Terreno3D.altura_en(c) <= 0:
			mal_altura += 1
	_ok("2.2 toda la tapa mira hacia arriba", todas_arriba)
	_ok("2.3 cada triángulo de la tapa está a la altura de la casilla que contiene su XZ (el shader lee esa casilla del mapa)", mal_altura == 0, "%d mal" % mal_altura)


func _labio_y_falda() -> void:
	var tz: BordePiedras3D = maqueta.get("_bordes_terraza") as BordePiedras3D
	_ok("3.1 la maqueta tiene BordesTerraza con bordes", tz != null and tz.n_bordes() > 0, "%d bordes" % (tz.n_bordes() if tz != null else -1))
	if tz == null:
		return
	_ok("3.2 con labio (4 triángulos por borde)", tz.n_triangulos_labio() > 0, "%d" % tz.n_triangulos_labio())
	var mi_labio: MeshInstance3D = null
	var mi_falda: MeshInstance3D = null
	for h in tz.get_children():
		if h.is_queued_for_deletion():
			continue
		if String(h.name).begins_with("labio"):
			mi_labio = h as MeshInstance3D
		elif String(h.name).begins_with("faldas"):
			mi_falda = h as MeshInstance3D
	_ok("3.3 el labio lleva el shader del suelo", mi_labio != null and mi_labio.mesh.surface_get_material(0) == maqueta.get("_mat_suelo"))
	_ok("3.4 y la falda el material del costado del suelo", mi_falda != null and mi_falda.mesh.surface_get_material(0) == maqueta.get("_mat_lado_suelo"))


func _estado() -> void:
	# Una casilla de terraza quemada, mojada y helada: el estado del juego la tiene y el shader del suelo recibe LA MISMA textura (V4).
	var celda: Vector2i = Vector2i(-1, -1)
	for c in Terreno3D.alturas.keys():
		if Terreno3D.altura_en(c) > 0:
			celda = c
			break
	_ok("4.0 hay una casilla elevada", celda.x >= 0)
	if celda.x < 0:
		return
	Terreno3D.estados.poner(celda, "quemada", true)
	var tex: ImageTexture = Mundo3D.textura_estados()
	var px: Color = Terreno3D.estados.imagen().get_pixel(celda.x, celda.y)
	var mat: ShaderMaterial = maqueta.get("_mat_suelo") as ShaderMaterial
	_ok("4.1 el estado quemado de una casilla de terraza está en la textura del juego (R > 0)", px.r > 0.5, str(px))
	_ok("4.2 y el shader que pinta la tapa recibe esa misma textura", mat.get_shader_parameter("estado_juego") == tex)
	Terreno3D.estados.poner(celda, "quemada", false)


func _apagado() -> void:
	maqueta.queue_free()
	await avanzar(5)
	TerraFina3D.terrazas_shader_suelo = false
	await cargar(RUTA)
	await avanzar_s(1.5)
	var mi: MeshInstance3D = _terrazas(maqueta)
	_ok("5.0 existe la malla Terrazas", mi != null)
	if mi != null:
		var malla: ArrayMesh = mi.mesh as ArrayMesh
		var mo: StandardMaterial3D = mi.material_override as StandardMaterial3D
		_ok("5.1 una sola superficie", malla.get_surface_count() == 1, "%d" % malla.get_surface_count())
		_ok("5.2 con color por vértice y no el shader del suelo", mo != null and mo.vertex_color_use_as_albedo and malla.surface_get_material(0) != maqueta.get("_mat_suelo"))
	var tz: BordePiedras3D = maqueta.get("_bordes_terraza") as BordePiedras3D
	var labio_ok: bool = false
	if tz != null:
		for h in tz.get_children():
			if String(h.name).begins_with("labio") and not h.is_queued_for_deletion():
				var mt: Material = (h as MeshInstance3D).mesh.surface_get_material(0)
				labio_ok = mt != maqueta.get("_mat_suelo") and mt is StandardMaterial3D
	_ok("5.3 el labio vuelve al material de vértices", labio_ok)
	var sin: int = _contar_colisiones(maqueta)
	_ok("6.1 colisiones idénticas con y sin el shader (%d)" % _col_con, sin == _col_con, "con %d · sin %d" % [_col_con, sin])
	_ok("6.2 Terreno3D.alturas y el mapa son los mismos", Terreno3D.alturas.hash() == _h_alturas and hash(Terreno3D.mapa) == _h_mapa)
	maqueta.queue_free()
	await avanzar(3)
