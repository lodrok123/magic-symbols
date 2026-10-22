class_name BordePiedras3D
extends Node3D
## Blandura de los cambios de altura y de las orillas (Fase 14.2 · P1, la «geometría blanda» de Echoes of Wisdom).
##
## POR QUÉ. La lógica del juego es de casillas, y un escalón de casilla acaba en arista viva: el ojo lee baldosas en vez de colinas.
## Echoes of Wisdom lo esconde de dos maneras, y aquí van las dos, SOLO como dibujo (nada de esto colisiona ni cambia la lógica):
##   1. FALDA: una tira de 0,3 u en el pie de la pared, con las normales suavizadas (la del extremo de la pared mira de lado y la del
##      extremo del suelo mira arriba, el sombreado las interpola) que «funde» la pared vertical con el suelo de abajo. Un solo segmento
##      por borde: dos triángulos.
##   2. LABIO (V3 de PLAN_EOW_VISUAL, 21/10): la arista de ARRIBA de la pared (la del bloque o del escalón) también era viva. Una tira de
##      `ancho_labio` u que arranca en la cara de arriba, sube un pelín (`sobresale_labio`) sobre la esquina y baja por la pared, con las
##      normales de sus tres vértices (arriba · 45° · lado) para que el sombreado la lea redondeada. Es una tira ENCIMA de la malla del
##      bloque, no un chaflán dentro de ella, a propósito: un bisel en `_malla_bloque` también abriría un surco en cada junta entre dos
##      bloques del mismo nivel (el MultiMesh usa una sola malla para todos), y aquí solo se pone donde hay arista de verdad. Cuatro
##      triángulos por borde. Se apaga con `labio_activo = false` o `PruebaTest2.bisel_suelo = false`.
##   3. ANILLO DE PIEDRAS: cantos rodados de 0,3–0,6 u con jitter (posición, giro, tamaño, tono) a lo largo del labio de arriba, medio
##      hundidos. Rompen la línea recta del borde y le dan un remate redondeado. Un solo MultiMesh para todos.
##
## QUÉ NECESITA. Una lista de bordes (los reúne quien conoce el mapa: la maqueta, `prueba_test2.gd`). Cada borde es un Dictionary:
##     c        Vector2i  casilla ALTA
##     v        Vector2i  dirección hacia el lado BAJO ((1,0), (-1,0), (0,1) o (0,-1))
##     y_alto   float     y de la cara de arriba de la casilla alta
##     y_bajo   float     y del suelo del lado bajo (en un río, el lecho: se ve a través del agua)
##     piedras  bool      (opcional, por defecto true) false = solo falda (p. ej. junto a un puente: las piedras taparían el paso)
##     solo_labio bool    (opcional, por defecto false) true = ni falda ni piedras, solo el labio (el borde del mapa: no hay suelo bajo el que fundirla)
##     color    Color     (opcional) color de vértice del labio, para un material que lo use (las terrazas, que se pintan por vértice)
## y el lado de la casilla `lado` (2,3 u) y el material de la falda (el mismo de los costados del suelo: así la tira continúa la pared).
## El material del labio (opcional) es el de la TAPA de ese suelo: el shader del suelo en la maqueta, el de vértices en las terrazas.

@export var ancho_falda: float = 0.3                   ## lo que se adentra la falda en el suelo bajo (y lo que sube por la pared)
## labio cauce: cuánto de «arriba» lleva la normal del extremo de la falda que toca la pared (0 = horizontal, como la pared, de serie; 1 = 45°). Con una pared de 10 cm (el cauce seco)
## la falda es una rampa más que una pared, y con la normal horizontal salía como una banda negra pegada al labio.
@export_range(0.0, 1.0) var falda_arriba: float = 0.0
## labio cauce: el orden de los vértices de la falda y del labio lo elegía la normal geométrica CCW hacia fuera, pero Godot da la cara FRONTAL a los triángulos en sentido HORARIO: con un material
## de caras de atrás recortadas (StandardMaterial3D de serie) las dos tiras quedan invisibles; solo se ven con materiales de doble cara (el shader del suelo, el del lecho del cauce), y entonces
## se iluminan con la normal dada la vuelta. `caras_frontales = true` las orienta bien. De serie false: no cambia lo que ya hay (orillas, escalones, borde del mapa) hasta que se decida.
@export var caras_frontales: bool = false
@export var piedra_min: float = 0.3                   ## diámetro menor de un canto (u)
@export var piedra_max: float = 0.6                    ## y el mayor
@export_range(1, 8) var piedras_por_borde: int = 3     ## cantos por cada lado de casilla (2,3 u): con 3 quedan huecos entre ellos
@export_range(0.0, 1.0) var hundimiento: float = 0.3   ## parte del canto que queda bajo el labio (0 = apoyado, 0,5 = medio enterrado)
@export var semilla: int = 17
## V3: el labio redondeado de arriba. `labio_activo = false` lo quita (queda lo de antes: falda y piedras).
@export var labio_activo: bool = true
@export var ancho_labio: float = 0.2                   ## lo que se adentra el labio en la cara de arriba (y lo que baja por la pared), 0,15–0,25 u
@export var sobresale_labio: float = 0.05              ## lo que asoma sobre la esquina viva (la tira queda por FUERA del bloque, así la tapa)
## Un centímetro por encima de la tapa en el arranque del labio: coplanar con la tapa titilaría (z-fighting).
const ELEVA_ARRANQUE: float = 0.012
## Cuánto de «arriba» lleva la normal del pie del labio (0 = horizontal, como la pared; 1 = 45°). Menos oscuro el pie sin romper la lectura del remate.
const LABIO_PIE_ARRIBA: float = 0.3

var _n_bordes: int = 0
var _n_piedras: int = 0
var _n_tris_labio: int = 0


## Borra lo anterior y dibuja la lista de bordes. Se puede llamar otra vez cuando cambian las alturas.
## `material_labio` (opcional): el de la tapa del suelo; sin él no hay labio (como antes de V3).
func construir(bordes: Array, lado: float, material_falda: Material, material_labio: Material = null) -> void:
	for h in get_children():
		h.queue_free()
	_n_bordes = bordes.size()
	_n_piedras = 0
	_n_tris_labio = 0
	if bordes.is_empty():
		return
	var con_falda: Array = bordes.filter(func(b): return not bool(b.get("solo_labio", false)))
	if not con_falda.is_empty():
		_montar_faldas(con_falda, lado, material_falda)
		_montar_piedras(con_falda, lado)
	if labio_activo and material_labio != null:
		_montar_labio(bordes, lado, material_labio)


## Triángulos del labio (V3): 4 por borde con pared suficiente.
func n_triangulos_labio() -> int:
	return _n_tris_labio


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
		var n_arriba: Vector3 = d if falda_arriba <= 0.0 else (d + Vector3.UP * falda_arriba).normalized()    # la pared mira hacia el lado bajo
		var n_abajo := Vector3.UP
		# El suavizado: la normal en cada vértice es la de su extremo; el rasterizador la interpola por la tira.
		var norm: Array[Vector3] = [n_arriba, n_arriba, n_abajo, n_abajo]
		var pts: Array[Vector3] = [p0, p1, p2, p3]
		# Orden de los triángulos con la cara visible hacia (d + arriba).
		var orden: Array = [0, 2, 1, 0, 3, 2]
		# Si el orden saliera hacia el otro lado (depende de la orientación de d) se invierte: se comprueba con la normal geométrica.
		var geo: Vector3 = (pts[2] - pts[0]).cross(pts[1] - pts[0])
		if (geo.dot(d + Vector3.UP) < 0.0) != caras_frontales:
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


## V3 · el labio de arriba de cada borde. Perfil (visto de lado, `d` = hacia fuera de la pared, y = arriba):
##     arranque  `ancho_labio` DENTRO de la cara de arriba, 1 cm por encima, normal arriba
##     esquina   un pelín fuera de la arista y por encima de ella (`sobresale_labio`), normal a 45° (arriba + fuera)
##     pie       en la pared, `ancho_labio` más abajo (o lo que mida la pared), normal hacia fuera
## Los tres vértices comparten color y UV de mundo; el sombreado interpola las normales entre ellos y la arista deja de leerse como un corte.
func _montar_labio(bordes: Array, lado: float, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris: int = 0
	for b in bordes:
		var v: Vector2i = b["v"]
		var c: Vector2i = b["c"]
		var y_alto: float = float(b["y_alto"])
		var y_bajo: float = float(b["y_bajo"])
		var baja: float = minf(ancho_labio, y_alto - y_bajo)          # una pared más baja que el labio: el labio se acorta con ella
		if baja <= 0.04:
			continue
		var d := Vector3(float(v.x), 0.0, float(v.y))
		var a := Vector3(absf(float(v.y)), 0.0, absf(float(v.x)))
		var pared := Vector3((float(c.x) + 0.5) * lado, 0.0, (float(c.y) + 0.5) * lado) + d * (lado * 0.5)   # mitad del borde, en la pared
		var l2: float = lado * 0.5
		# Un pelín de diferencia de altura según la dirección: en una esquina exterior las dos tiras se cruzan y, sin ella, serían coplanares.
		var eleva: float = ELEVA_ARRANQUE + 0.003 * float(absi(v.x) + 2 * absi(v.y))
		var s: float = sobresale_labio
		# [posición, normal, UV2]. UV2 = cuánto hay que correr (x, z) la posición de mundo para MUESTREAR la textura: el shader del suelo pinta por
		# coordenadas de mundo en planta, y en la parte que baja por la pared eso estira un hilo vertical de colores (rayas). Con este corrimiento la
		# textura de la tapa «se dobla hacia dentro»: el pie del labio muestrea lo que hay `baja` u dentro de la arista, sin rayas ni salirse de la casilla.
		var perfil: Array = [
			[pared - d * ancho_labio + Vector3(0.0, y_alto + eleva, 0.0), Vector3.UP, Vector2.ZERO],
			[pared + d * s + Vector3(0.0, y_alto + s, 0.0), (d + Vector3.UP).normalized(), Vector2(-d.x, -d.z) * s],
			# La normal del pie se inclina un poco hacia arriba (no es la de la pared, que es horizontal): la pared tiene su propia luz y el pie del labio
			# no debe quedar tan oscuro como ella (sale una banda sucia pegada a la tapa); la tira se lee como un remate, no como un trozo de pared.
			[pared + d * s + Vector3(0.0, y_alto - baja, 0.0), (d + Vector3.UP * LABIO_PIE_ARRIBA).normalized(), Vector2(-d.x, -d.z) * (s + baja)]]
		var col: Color = b.get("color", Color(1.0, 1.0, 1.0)) as Color
		for k in range(2):
			var p: Array = perfil[k]
			var q: Array = perfil[k + 1]
			# Cuadrilátero p0 p1 q1 q0 (p a lo largo -a..+a); cada triángulo con la cara visible hacia (fuera + arriba).
			var p0: Array = [(p[0] as Vector3) - a * l2, p[1], p[2]]
			var p1: Array = [(p[0] as Vector3) + a * l2, p[1], p[2]]
			var q0: Array = [(q[0] as Vector3) - a * l2, q[1], q[2]]
			var q1: Array = [(q[0] as Vector3) + a * l2, q[1], q[2]]
			var ref: Vector3 = d + Vector3.UP
			for t in [[p0, p1, q1], [p0, q1, q0]]:
				var geo: Vector3 = ((t[1][0] as Vector3) - (t[0][0] as Vector3)).cross((t[2][0] as Vector3) - (t[0][0] as Vector3))
				var orden: Array = [0, 1, 2] if (geo.dot(ref) > 0.0) != caras_frontales else [0, 2, 1]
				for i in orden:
					var vtx: Array = t[i]
					st.set_color(col)
					st.set_normal(vtx[1] as Vector3)
					st.set_uv(Vector2((vtx[0] as Vector3).x, (vtx[0] as Vector3).z))
					st.set_uv2(vtx[2] as Vector2)
					st.add_vertex(vtx[0] as Vector3)
				tris += 1
	if tris == 0:
		return
	var malla: ArrayMesh = st.commit()
	if malla == null or malla.get_surface_count() == 0:
		return
	malla.surface_set_material(0, material)
	_n_tris_labio = tris
	var mi := MeshInstance3D.new()
	mi.name = "labio"
	mi.mesh = malla
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # asoma 5 cm: la sombra del bloque ya la cubre y no merece un caster
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
