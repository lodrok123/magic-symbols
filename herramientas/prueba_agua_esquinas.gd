extends SceneTree
## Esquinas del agua y espuma de orilla (22/10), SIN ventana: la ESTRUCTURA de la malla (un vértice por trocito y uno de centro por cuadrito, abanico de 4 triángulos),
## que el sombreado reconoce los vértices de centro, y que las constantes nuevas llegan al material. Lo que se VE (esquinas, espuma, movimiento) va en las capturas
## (captura_agua_esquinas.gd, captura_llenado_cauce.gd, captura_agua_lab.gd): sin GPU no hay sombreado que ejecutar.
##   godot --headless --path . --fixed-fps 30 -s herramientas/prueba_agua_esquinas.gd
const ANCHO: int = 6
const ALTO: int = 5
const SUB: int = 3
const LADO: float = 2.3
var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _suelo(_c: Vector2i) -> float:
	return 1.0


func _pared(_c: Vector2i) -> bool:
	return false


func _initialize() -> void:
	var sim := AguaSim3D.new()
	sim.configurar(ANCHO, ALTO, SUB, LADO, _suelo, _pared)
	var r := AguaRender3D.new()
	root.add_child(r)
	r.enlazar(sim)
	await process_frame
	var m: ArrayMesh = r.mesh as ArrayMesh
	_ok("1 hay malla", m != null)
	if m == null:
		quit(1)
		return
	var arr: Array = m.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var w: int = sim.w
	var h: int = sim.h
	var esperados: int = w * h + (w - 1) * (h - 1)
	_ok("2 vértices = trocitos + centros de cuadrito (%d, esperados %d)" % [verts.size(), esperados], verts.size() == esperados and uvs.size() == esperados)
	_ok("3 cuatro triángulos por cuadrito (%d índices, esperados %d)" % [idx.size(), (w - 1) * (h - 1) * 12], idx.size() == (w - 1) * (h - 1) * 12)
	var mal_uv: int = 0
	var mal_pos: int = 0
	for y in range(h - 1):
		for x in range(w - 1):
			var k: int = w * h + y * (w - 1) + x
			var esperada := Vector2((x + 1.0) / float(w), (y + 1.0) / float(h))
			if uvs[k].distance_to(esperada) > 1.0e-5:
				mal_uv += 1
			var centro: Vector3 = (verts[y * w + x] + verts[y * w + x + 1] + verts[(y + 1) * w + x] + verts[(y + 1) * w + x + 1]) * 0.25
			if absf(verts[k].x - centro.x) > 1.0e-4 or absf(verts[k].z - centro.z) > 1.0e-4:
				mal_pos += 1
	_ok("4 cada vértice de centro está en el centro de sus cuatro trocitos y su UV cae en la esquina entre sus cuatro texels (%d mal UV, %d mal posición)" % [mal_uv, mal_pos], mal_uv == 0 and mal_pos == 0)
	var fuera: int = 0
	for i in idx:
		if i < 0 or i >= verts.size():
			fuera += 1
	_ok("5 ningún índice fuera de la malla", fuera == 0)
	var codigo: String = (r.material_agua().shader as Shader).code
	_ok("6 el sombreado combina los centros y mide la distancia al contorno", codigo.contains("combina_centro") and codigo.contains("dist_orilla") and codigo.contains("cerca_orilla"))
	var mat: ShaderMaterial = r.material_agua()
	_ok("7 las constantes llegan al material (orilla %.2f–%.2f, avance %.1f, franjas %.2f)" % [float(mat.get_shader_parameter("orilla_dist_0")), float(mat.get_shader_parameter("orilla_dist_1")), float(mat.get_shader_parameter("avance_flujo")), float(mat.get_shader_parameter("filtro_franjas"))],
			is_equal_approx(float(mat.get_shader_parameter("orilla_dist_0")), AguaRender3D.ORILLA_DIST_0) and is_equal_approx(float(mat.get_shader_parameter("orilla_dist_1")), AguaRender3D.ORILLA_DIST_1)
			and is_equal_approx(float(mat.get_shader_parameter("avance_flujo")), AguaRender3D.AVANCE_FLUJO) and is_equal_approx(float(mat.get_shader_parameter("filtro_franjas")), AguaRender3D.FILTRO_FRANJAS))
	_ok("8 la zona de espuma (ORILLA_DIST_0 < ORILLA_DIST_1) cabe en un trocito de simulación (%.2f u)" % sim.l, AguaRender3D.ORILLA_DIST_0 < AguaRender3D.ORILLA_DIST_1 and AguaRender3D.ORILLA_DIST_1 <= sim.l)
	print("Vértices del agua: %d (antes %d)  triángulos: %d (antes %d)" % [verts.size(), w * h, idx.size() / 3, (w - 1) * (h - 1) * 2])
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
