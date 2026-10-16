class_name BordePiedras3D
extends Node3D
## Blandura de los cambios de altura y de las orillas (Fase 14.2 · P1, la «geometría blanda» de Echoes of Wisdom).
##
## POR QUÉ. La lógica del juego es de casillas, y un escalón de casilla acaba en arista viva: el ojo lee baldosas en vez de colinas.
## Echoes of Wisdom lo esconde de dos maneras, y aquí van las dos, SOLO como dibujo (nada de esto colisiona ni cambia la lógica):
##   1. FALDA: una tira de 0,3 u en el pie de la pared, con las normales suavizadas (la del extremo de la pared mira de lado y la del
##      extremo del suelo mira arriba, el sombreado las interpola) que «funde» la pared vertical con el suelo de abajo. Un solo segmento
##      por borde: dos triángulos.
##   2. ANILLO DE PIEDRAS: cantos rodados de 0,3–0,6 u con jitter (posición, giro, tamaño, tono) a lo largo del labio de arriba, medio
##      hundidos. Rompen la línea recta del borde y le dan un remate redondeado. Un solo MultiMesh para todos.
##
## QUÉ NECESITA. Una lista de bordes (los reúne quien conoce el mapa: la maqueta, `prueba_test2.gd`). Cada borde es un Dictionary:
##     c        Vector2i  casilla ALTA
##     v        Vector2i  dirección hacia el lado BAJO ((1,0), (-1,0), (0,1) o (0,-1))
##     y_alto   float     y de la cara de arriba de la casilla alta
##     y_bajo   float     y del suelo del lado bajo (en un río, el lecho: se ve a través del agua)
##     piedras  bool      (opcional, por defecto true) false = solo falda (p. ej. junto a un puente: las piedras taparían el paso)
## y el lado de la casilla `lado` (2,3 u) y el material de la falda (el mismo de los costados del suelo: así la tira continúa la pared).

@export var ancho_falda: float = 0.3                   ## lo que se adentra la falda en el suelo bajo (y lo que sube por la pared)
@export var piedra_min: float = 0.3                    ## diámetro menor de un canto (u)
@export var piedra_max: float = 0.6                    ## y el mayor
@export_range(1, 8) var piedras_por_borde: int = 3     ## cantos por cada lado de casilla (2,3 u): con 3 quedan huecos entre ellos
@export_range(0.0, 1.0) var hundimiento: float = 0.3   ## parte del canto que queda bajo el labio (0 = apoyado, 0,5 = medio enterrado)
@export var semilla: int = 17

var _n_bordes: int = 0
var _n_piedras: int = 0


## Borra lo anterior y dibuja la lista de bordes. Se puede llamar otra vez cuando cambian las alturas.
func construir(bordes: Array, lado: float, material_falda: Material) -> void:
	for h in get_children():
		h.queue_free()
	_n_bordes = bordes.size()
	_n_piedras = 0
	if bordes.is_empty():
		return
	_montar_faldas(bordes, lado, material_falda)
	_montar_piedras(bordes, lado)


func n_bordes() -> int:
	return _n_bordes


func n_piedras() -> int:
	return _n_piedras


## Hash estable de una casilla y una cara: el jitter es siempre el mismo para el mismo borde (no parpadea al reconstruir).
func _hash(c: Vector2i, v: Vector2i, sal: int) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663) ^ ((v.x * 3 + v.y * 5 + 11) * 83492791) ^ ((sal + semilla) * 2654435761))


func _montar_faldas(bordes: Array, lado: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in bordes:
		var v: Vector2i = b["v"]
		var c: Vector2i = b["c"]
		var y_alto: float = float(b["y_alto"])
		var y_bajo: float = float(b["y_bajo"])
		var caida: float = minf(ancho_falda, y_alto - y_bajo)        # una pared más baja que la falda: la falda se acorta con ella
		if caida <= 0.02:
			continue
		var d := Vector3(float(v.x), 0.0, float(v.y))                  # hacia el lado bajo
		var a := Vector3(absf(float(v.y)), 0.0, absf(float(v.x)))      # a lo largo del borde (perpendicular a d)
		var centro := Vector3((float(c.x) + 0.5) * lado, 0.0, (float(c.y) + 0.5) * lado) + d * (lado * 0.5)   # mitad del borde, en la pared
		var l2: float = lado * 0.5
		# Perfil: arriba (en la pared, a y_bajo + caida) y abajo (en el suelo bajo, a `ancho_falda` de la pared).
		var p0: Vector3 = centro - a * l2 + Vector3(0.0, y_bajo + caida, 0.0)
		var p1: Vector3 = centro + a * l2 + Vector3(0.0, y_bajo + caida, 0.0)
		var p2: Vector3 = centro + a * l2 + d * ancho_falda + Vector3(0.0, y_bajo, 0.0)
		var p3: Vector3 = centro - a * l2 + d * ancho_falda + Vector3(0.0, y_bajo, 0.0)
		var n_arriba: Vector3 = d                # la pared mira hacia el lado bajo
		var n_abajo := Vector3.UP
		# El suavizado: la normal en cada vértice es la de su extremo; el rasterizador la interpola por la tira.
		var norm: Array[Vector3] = [n_arriba, n_arriba, n_abajo, n_abajo]
		var pts: Array[Vector3] = [p0, p1, p2, p3]
		# Orden de los triángulos con la cara visible hacia (d + arriba).
		var orden: Array = [0, 2, 1, 0, 3, 2]
		# Si el orden saliera hacia el otro lado (depende de la orientación de d) se invierte: se comprueba con la normal geométrica.
		var geo: Vector3 = (pts[2] - pts[0]).cross(pts[1] - pts[0])
		if geo.dot(d + Vector3.UP) < 0.0:
			orden = [0, 1, 2, 0, 2, 3]
		for k in orden:
			st.set_normal(norm[k])
			st.set_uv(Vector2(pts[k].x, pts[k].z))
			st.add_vertex(pts[k])
	var malla: ArrayMesh = st.commit()
	if malla == null or malla.get_surface_count() == 0:
		return
	malla.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.name = "faldas"
	mi.mesh = malla
	add_child(mi)


func _montar_piedras(bordes: Array, lado: float) -> void:
	var tfs: Array[Transform3D] = []
	var cols: Array[Color] = []
	for b in bordes:
		if b.has("piedras") and not bool(b["piedras"]):
			continue
		var v: Vector2i = b["v"]
		var c: Vector2i = b["c"]
		var y_alto: float = float(b["y_alto"])
		var d := Vector3(float(v.x), 0.0, float(v.y))
		var a := Vector3(absf(float(v.y)), 0.0, absf(float(v.x)))
		var centro := Vector3((float(c.x) + 0.5) * lado, y_alto, (float(c.y) + 0.5) * lado) + d * (lado * 0.5)
		var paso: float = lado / float(piedras_por_borde)
		for k in range(piedras_por_borde):
			var h: int = _hash(c, v, k)
			if (h >> 3) % 7 == 0:
				continue          # un hueco de vez en cuando: un anillo continuo parece una cadena
			var f1: float = float(h % 1000) / 999.0
			var f2: float = float((h >> 10) % 1000) / 999.0
			var f3: float = float((h >> 20) % 1000) / 999.0
			var diam: float = lerpf(piedra_min, piedra_max, f1)
			var t_borde: float = (float(k) + 0.5) * paso - lado * 0.5 + (f2 - 0.5) * paso * 0.5     # a lo largo, con jitter de medio paso
			# Se adelanta un poco hacia el lado bajo (el canto asoma sobre el labio) y se hunde `hundimiento` de su alto.
			var alto: float = diam * 0.62
			var fuera: float = (f3 - 0.5) * 0.16 + diam * 0.08
			var pos: Vector3 = centro + a * t_borde + d * fuera
			pos.y = y_alto + alto * (0.5 - hundimiento)
			var giro: float = float((h >> 5) % 628) / 100.0
			var base := Basis(Vector3.UP, giro).scaled(Vector3(diam, alto, diam * lerpf(0.78, 1.0, f2)))
			tfs.append(Transform3D(base, pos))
			# Tono: entre las dos piedras de la paleta, con una pizca de tierra en alguno (musgo y barro del borde).
			var col: Color = Paleta3D.PIEDRA_OSCURA.lerp(Paleta3D.PIEDRA, 0.35 + 0.65 * f3)     # sesgo a la piedra clara: la oscura sola se lee como mancha
			if f1 > 0.82:
				col = col.lerp(Paleta3D.TIERRA, 0.35)
			cols.append(col)
	_n_piedras = tfs.size()
	if tfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _malla_canto()
	mm.instance_count = tfs.size()
	for i in range(tfs.size()):
		mm.set_instance_transform(i, tfs[i])
		mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "piedras"
	mi.multimesh = mm
	add_child(mi)


## Un canto rodado: esfera de 8 × 5 con cada vértice movido ±14 % por un hash de su posición (no son todos iguales, y los
## cantos de un mismo MultiMesh comparten malla, así que la variedad real viene del escalado no uniforme de cada copia) y las
## normales recalculadas planas por cara: el aspecto facetado del low-poly pastel del resto del mundo.
## Diámetro 1 en x/z y alto 1.0 (la escala de cada copia pone el tamaño real).
static func _malla_canto() -> ArrayMesh:
	var esfera := SphereMesh.new()
	esfera.radius = 0.5
	esfera.height = 1.0
	esfera.radial_segments = 8
	esfera.rings = 5
	var arr: Array = esfera.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	# Primero se mueven los vértices por un hash de su posición REDONDEADA: los vértices duplicados de la costura (mismo punto,
	# distinta normal/UV) reciben el mismo desplazamiento y no se abre una grieta.
	var mov := PackedVector3Array()
	mov.resize(vs.size())
	for i in range(vs.size()):
		var p: Vector3 = vs[i]
		var h: int = absi(int(round(p.x * 997.0)) * 73856093 ^ int(round(p.y * 997.0)) * 19349663 ^ int(round(p.z * 997.0)) * 83492791)
		var f: float = 1.0 + (float(h % 1000) / 999.0 - 0.5) * 0.28
		mov[i] = p * f
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, idx.size(), 3):
		var tri: Array[Vector3] = [mov[idx[t]], mov[idx[t + 1]], mov[idx[t + 2]]]
		var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		if n == Vector3.ZERO:
			continue
		for q in tri:
			st.set_normal(n)
			st.add_vertex(q)
	var malla: ArrayMesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	malla.surface_set_material(0, mat)
	return malla
