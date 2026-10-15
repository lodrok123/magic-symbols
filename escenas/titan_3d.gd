class_name Titan3D
extends Node3D
## El titán de la Terra Fina, generado por código (14/10, Pablo: «dame un proc para el titán»). Un gigante de piedra y musgo
## sentado al fondo del valle, con la columna inclinada hacia atrás como en la figura de referencia: ~70 u de alto con el castillo y ~105 de largo (de la cabeza, z≈-70, a los pies, z≈+25), mirando al valle (+Z). El héroe mide 1 u, la casilla 2,3 u.
## Es un DECORADO: sin colisión, sin IA, sin sombras propias exigentes. Se usa así:
##     var t := Titan3D.new(); t.semilla = 7; mundo.add_child(t); t.position = Vector3(x, 0, z)   # x,z = borde norte del valle
## Concepto: la ilustración de Pablo (14/10) y, para la postura de la columna, su figura de referencia (sentado, inclinado hacia atrás): gigante de piedra y musgo, un pueblo que sube por su cuerpo hasta un castillo (aquí en la rodilla derecha), máscara tallada.
## Qué hace: ~35 bloques elípticos (rodillas, muslos, torso, cabeza, manos…) cuya superficie se deforma con ruido para que parezcan
## rocas; el color va en los vértices (musgo en lo que mira hacia arriba, piedra en los lados, más oscuro abajo: falsa oclusión), un
## bosquecillo de árboles, casas con tejado en las laderas y un castillo en lo alto de la rodilla derecha, dos anillos de piedra clara sobre
## la máscara y dos ojos que brillan en ámbar. Respira muy despacio.
## Todo con la misma semilla sale igual. Cambia `semilla` para otro gesto de la roca; las medidas están en PIEZAS.
## Pensado para verse de lejos con la cámara del juego (ortogonal, 60°): formas grandes y legibles, nada de detalle fino.

const MUSGO: Color = Color(0.27, 0.40, 0.13)
const ROCA: Color = Color(0.36, 0.34, 0.31)
const ROCA_CLARA: Color = Color(0.45, 0.42, 0.37)
const ALTURA_REF: float = 62.0               ## (sin uso desde la pose recostada: el titán mide ~45 u de alto y ~125 de largo)

## Cada pieza: n nombre, c centro, r radios, g giro en grados (x,y,z; orden YXZ de Godot), m cuánto musgo cubre lo que mira arriba
## (0 piedra, 1 todo), a amplitud del ruido (más = más tosco), t árboles, esp simétrica en x. Origen: x=0 en el eje del cuerpo, z=0 en el
## borde norte del valle; el titán mira al valle (+Z), con la cadera en z≈-38 y los pies en el valle.
## Pose (14/10, la figura de referencia de Pablo): SENTADO en el suelo con la columna inclinada hacia atrás y curvada: la cadera apoya
## (y 12), la espalda sube hacia atrás (z de -38 a -59, unos 26° respecto a la vertical, con la lumbar algo más adelantada que el pecho),
## y el cuello y la cabeza se adelantan de nuevo hacia el valle. Rodilla izquierda alzada con el antebrazo apoyado encima, pierna derecha
## estirada hacia delante, brazo derecho caído con la mano abierta en el suelo. El castillo corona el pecho y la máscara mira al valle.
const PIEZAS: Array = [
	# la columna, de abajo arriba
	{"n": "cadera", "c": Vector3(0, 12, -38), "r": Vector3(17, 12, 13), "m": 0.8, "a": 0.13, "t": 5},
	{"n": "vientre", "c": Vector3(0, 22, -43), "r": Vector3(16, 13, 12), "g": Vector3(-8, 0, 0), "m": 0.9, "a": 0.13, "t": 6},
	{"n": "pecho", "c": Vector3(0, 36, -52), "r": Vector3(19, 15, 13), "g": Vector3(-18, 0, 0), "m": 0.9, "a": 0.12, "t": 10},
	{"n": "hombro", "c": Vector3(21, 42, -54), "r": Vector3(8, 8, 9), "m": 0.7, "a": 0.15, "t": 4, "esp": true},
	{"n": "cuello", "c": Vector3(0, 48, -58), "r": Vector3(6.5, 6.5, 6.5), "g": Vector3(-10, 0, 0), "m": 0.3, "a": 0.12, "t": 0},
	{"n": "cabeza", "c": Vector3(0, 56, -59), "r": Vector3(9.5, 10.5, 10), "g": Vector3(12, 0, 0), "m": 0.6, "a": 0.1, "t": 3},
	{"n": "mascara", "c": Vector3(0, 54.6, -50.2), "r": Vector3(8.2, 3.0, 9.0), "g": Vector3(78, 0, 0), "m": 0.0, "a": 0.28, "t": 0, "claro": true},
	# pierna izquierda: rodilla alzada, pie plantado
	{"n": "muslo_i", "c": Vector3(-12, 21, -30), "r": Vector3(8.5, 8.5, 13), "g": Vector3(-51, 0, 0), "m": 0.85, "a": 0.14, "t": 5},
	{"n": "rodilla_i", "c": Vector3(-12, 32, -20), "r": Vector3(9.5, 9.5, 9.5), "m": 0.95, "a": 0.15, "t": 6},
	{"n": "espinilla_i", "c": Vector3(-12, 18.5, -11), "r": Vector3(6.5, 6.5, 16), "g": Vector3(56, 0, 0), "m": 0.6, "a": 0.14, "t": 3},
	{"n": "pie_i", "c": Vector3(-12, 3, 7), "r": Vector3(7, 4, 10), "m": 0.1, "a": 0.15, "t": 0},
	{"n": "dedo_pie_i1", "c": Vector3(-16.5, 3, 16.5), "r": Vector3(2.5, 2.2, 3.4), "m": 0.0, "a": 0.2, "t": 0},
	{"n": "dedo_pie_i2", "c": Vector3(-12, 3, 18), "r": Vector3(2.5, 2.2, 3.8), "m": 0.0, "a": 0.2, "t": 0},
	{"n": "dedo_pie_i3", "c": Vector3(-7.5, 3, 16.5), "r": Vector3(2.3, 2.0, 3.2), "m": 0.0, "a": 0.2, "t": 0},
	# pierna derecha, estirada hacia el valle
	{"n": "muslo_d", "c": Vector3(13, 12, -28), "r": Vector3(8.5, 8, 14), "g": Vector3(6, 0, 0), "m": 0.85, "a": 0.14, "t": 5},
	{"n": "rodilla_d", "c": Vector3(13, 11, -12), "r": Vector3(8, 7.5, 8), "m": 0.8, "a": 0.12, "t": 0},
	{"n": "pierna_d", "c": Vector3(13, 8, 2), "r": Vector3(6.5, 6, 11), "g": Vector3(-6, 0, 0), "m": 0.4, "a": 0.14, "t": 2},
	{"n": "pie_d", "c": Vector3(13, 6, 15), "r": Vector3(6.5, 6, 6.5), "g": Vector3(-25, 0, 0), "m": 0.0, "a": 0.15, "t": 0},
	{"n": "dedo_pie_d1", "c": Vector3(8.5, 8, 21), "r": Vector3(2.4, 2.4, 3.4), "m": 0.0, "a": 0.2, "t": 0},
	{"n": "dedo_pie_d2", "c": Vector3(13, 8.5, 22), "r": Vector3(2.5, 2.5, 3.8), "m": 0.0, "a": 0.2, "t": 0},
	{"n": "dedo_pie_d3", "c": Vector3(17.5, 8, 21), "r": Vector3(2.3, 2.3, 3.2), "m": 0.0, "a": 0.2, "t": 0},
	# brazo izquierdo: el antebrazo descansa sobre la rodilla alzada, la mano cuelga por delante
	{"n": "brazo_i", "c": Vector3(-24, 32, -48), "r": Vector3(5, 5, 11), "g": Vector3(58, -6, 0), "m": 0.7, "a": 0.14, "t": 2},
	{"n": "antebrazo_i", "c": Vector3(-18, 35, -32), "r": Vector3(4.5, 4.5, 13), "g": Vector3(-23, 20, 0), "m": 0.4, "a": 0.14, "t": 1},
	{"n": "mano_i", "c": Vector3(-13, 42, -19), "r": Vector3(5, 2.8, 5.5), "m": 0.1, "a": 0.17, "t": 0},
	{"n": "dedo_mano_i1", "c": Vector3(-15, 42, -14), "r": Vector3(1.2, 1.2, 3.4), "m": 0.0, "a": 0.2, "t": 0},
	{"n": "dedo_mano_i2", "c": Vector3(-12.5, 42, -13.5), "r": Vector3(1.2, 1.2, 3.8), "m": 0.0, "a": 0.2, "t": 0},
	{"n": "dedo_mano_i3", "c": Vector3(-10, 42, -14.5), "r": Vector3(1.2, 1.2, 3.2), "m": 0.0, "a": 0.2, "t": 0},
	# brazo derecho: caído, con la mano abierta en el suelo
	{"n": "brazo_d", "c": Vector3(25, 28, -49), "r": Vector3(5, 5, 11), "g": Vector3(78, 10, 0), "m": 0.7, "a": 0.14, "t": 3},
	{"n": "antebrazo_d", "c": Vector3(29, 11, -39), "r": Vector3(4.5, 4.5, 10), "g": Vector3(45, 8, 0), "m": 0.4, "a": 0.14, "t": 1},
	{"n": "mano_d", "c": Vector3(30, 3, -30), "r": Vector3(6, 2.6, 6.5), "m": 0.1, "a": 0.17, "t": 0},
	{"n": "dedo_mano_d1", "c": Vector3(27, 2.6, -22.5), "r": Vector3(1.3, 1.3, 4), "m": 0.0, "a": 0.2, "t": 0},
	{"n": "dedo_mano_d2", "c": Vector3(29.5, 2.6, -21.5), "r": Vector3(1.3, 1.3, 4.4), "m": 0.0, "a": 0.2, "t": 0},
	{"n": "dedo_mano_d3", "c": Vector3(32, 2.6, -22), "r": Vector3(1.3, 1.3, 4.2), "m": 0.0, "a": 0.2, "t": 0},
	{"n": "dedo_mano_d4", "c": Vector3(34.3, 2.6, -24), "r": Vector3(1.3, 1.3, 3.6), "m": 0.0, "a": 0.2, "t": 0},
]
const CARA: Vector3 = Vector3(0, 54.6, -50.2)       ## centro de la máscara (la cara mira al valle, algo hacia abajo)
const INCL_MASCARA: float = 78.0                    ## giro en x de la máscara y de sus anillos y ojos (90° = de frente, 0 = mirando al cielo)
const OJOS: Array = [Vector3(-2.4, 55.9, -49.6), Vector3(2.4, 55.9, -49.6)]    ## los dos ojos (ámbar), delante de la máscara
## Las piezas por encima de esta altura respiran (pecho, hombros, cabeza, brazo izquierdo): el busto sube y baja un 0,8 %.
const Y_BUSTO: float = 30.0
const ESCALA_CASTILLO: float = 0.7
const CASAS: Dictionary = {"cadera": 5, "vientre": 12, "pecho": 22, "muslo_i": 4, "muslo_d": 4, "rodilla_d": 0}   ## casas por pieza (en las laderas, no arriba del todo)

@export var semilla: int = 7
@export var escala: float = 1.0
@export var respira: bool = true
@export var ojos_abiertos: bool = true

var _busto: Node3D = null
var _ojos: Array[MeshInstance3D] = []
var _t: float = 0.0
var _destino: Node3D = null                ## dónde cuelgan las piezas de _pieza_c (null = el propio titán)


func _ready() -> void:
	construir()


func construir() -> void:
	for h in get_children():
		h.queue_free()
	_ojos.clear()
	scale = Vector3.ONE * escala
	_busto = Node3D.new()
	_busto.name = "Busto"
	add_child(_busto)
	var arboles: Array[Transform3D] = []
	var casas: Array[Transform3D] = []
	var cima_castillo: Vector3 = Vector3(13, 19, -12)
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var i: int = 0
	for p in PIEZAS:
		for lado in ([1.0, -1.0] if p.get("esp", false) else [1.0]):
			i += 1
			var c: Vector3 = p["c"]
			c.x *= lado
			var radios: Vector3 = p["r"]
			var m: float = p["m"]
			var sem: int = semilla + i * 31
			var giro: Vector3 = p.get("g", Vector3.ZERO)
			var base := Basis.from_euler(Vector3(deg_to_rad(giro.x), deg_to_rad(giro.y), deg_to_rad(giro.z)))
			var mi := MeshInstance3D.new()
			mi.name = "%s%s" % [p["n"], "" if lado > 0.0 or not p.get("esp", false) else "_I"]
			var claro: Color = ROCA_CLARA
			mi.mesh = malla_blob(radios, sem, float(p["a"]), 40, MUSGO.lerp(claro, 1.0 - m), claro if (m <= 0.05 or p.get("claro", false)) else ROCA)
			mi.material_override = _material()
			mi.position = c
			mi.basis = base
			(_busto if c.y > Y_BUSTO else self).add_child(mi)
			if p["n"] == "rodilla_d":
				cima_castillo = c + base * _sup(_ruido(sem), base.transposed() * Vector3.UP, radios, float(p["a"]))      # el punto más alto, aunque la pieza esté girada
			for k in int(p["t"]):
				var s: Variant = _punto_cara(radios, sem, float(p["a"]), rng, 0.55, 1.0)
				if s != null:
					var sc: float = rng.randf_range(0.8, 1.7)
					var pos: Vector3 = c + base * (s as Vector3) - Vector3(0, 0.25 * sc, 0)
					arboles.append(Transform3D(Basis.IDENTITY.scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.4), sc)).rotated(Vector3.UP, rng.randf() * TAU), pos))
			for k in int(CASAS.get(p["n"], 0)):
				var s2: Variant = _punto_cara(radios, sem, float(p["a"]), rng, 0.5, 0.88)       # laderas: ni plano de la cima ni pared vertical
				if s2 != null:
					var pos2: Vector3 = c + base * (s2 as Vector3) - Vector3(0, 0.3, 0)
					casas.append(Transform3D(Basis.IDENTITY.rotated(Vector3.UP, rng.randf() * TAU), pos2))
	_poner_arboles(arboles, rng)
	_poner_casas(casas, rng)
	_castillo(cima_castillo)
	_adorno_mascara()
	for pos_ojo in OJOS:
		var ojo := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(1.4, 0.6, 2.8)
		ojo.mesh = caja
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.68, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.6, 0.12)
		mat.emission_energy_multiplier = 2.5 if ojos_abiertos else 0.0
		ojo.material_override = mat
		ojo.position = pos_ojo
		ojo.rotation_degrees.x = INCL_MASCARA
		_busto.add_child(ojo)
		_ojos.append(ojo)


## Dos anillos de piedra clara sobre la máscara: es lo que de lejos hace de «tallado» (el entrelazado del concepto, sin dibujarlo).
func _adorno_mascara() -> void:
	for par in [[6.4, 8.2, CARA + Vector3(0, 0.4, 0.9)], [3.0, 4.4, CARA + Vector3(0, 0.5, 1.6)]]:
		var t := TorusMesh.new()
		t.inner_radius = par[0]
		t.outer_radius = par[1]
		t.rings = 24
		t.ring_segments = 8
		var mi := MeshInstance3D.new()
		mi.name = "AnilloMascara"
		mi.mesh = t
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.5, 0.47, 0.41)
		m.roughness = 1.0
		mi.material_override = m
		mi.position = par[2]
		mi.rotation_degrees.x = INCL_MASCARA
		mi.scale = Vector3(1.0, 0.5, 1.15)
		_busto.add_child(mi)


## El castillo, en lo alto de la rodilla derecha (la del pecho chocaba con la cara al sentarlo): un edificio central con torre alta, cuatro torres en las esquinas y un muro. Cajas y conos, a escala 0,7.
func _castillo(cima: Vector3) -> void:
	var piedra := Color(0.56, 0.51, 0.45)
	var teja := Color(0.58, 0.27, 0.16)
	var raiz := Node3D.new()
	raiz.name = "Castillo"
	raiz.position = cima - Vector3(0, 0.4, 0)
	raiz.scale = Vector3.ONE * ESCALA_CASTILLO
	add_child(raiz)
	_destino = raiz
	var base: Vector3 = Vector3.ZERO
	_pieza_c("Castillo_cuerpo", BoxMesh.new(), Vector3(8, 4.5, 6), base + Vector3(0, 2.25, 0), piedra)
	_pieza_c("Castillo_tejado", _cono(1.0, 1.0, 4), Vector3(6.4, 2.2, 5.0), base + Vector3(0, 4.5 + 1.1, 0), teja, 45.0)
	_pieza_c("Castillo_torre", _cil(1.0, 1.0), Vector3(1.7, 10.5, 1.7), base + Vector3(0, 5.25, -0.5), piedra)
	_pieza_c("Castillo_torre_tejado", _cono(1.0, 1.0, 8), Vector3(2.4, 3.6, 2.4), base + Vector3(0, 10.5 + 1.8, -0.5), teja)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var q: Vector3 = base + Vector3(sx * 5.6, 0, sz * 4.6)
			_pieza_c("Castillo_torreta", _cil(1.0, 1.0), Vector3(1.2, 6.5, 1.2), q + Vector3(0, 3.25, 0), piedra)
			_pieza_c("Castillo_torreta_tejado", _cono(1.0, 1.0, 8), Vector3(1.8, 2.4, 1.8), q + Vector3(0, 6.5 + 1.2, 0), teja)
	for sz in [-1.0, 1.0]:                                                                                        # el muro
		_pieza_c("Castillo_muro", BoxMesh.new(), Vector3(11.2, 1.8, 0.7), base + Vector3(0, 0.9, sz * 4.6), piedra)
	for sx in [-1.0, 1.0]:
		_pieza_c("Castillo_muro", BoxMesh.new(), Vector3(0.7, 1.8, 9.2), base + Vector3(sx * 5.6, 0.9, 0), piedra)
	_destino = null


func _cono(r_abajo: float, alto: float, lados: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r_abajo * 0.5
	c.height = alto
	c.radial_segments = lados
	c.rings = 1
	return c


func _cil(r: float, alto: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r * 0.5
	c.bottom_radius = r * 0.5
	c.height = alto
	c.radial_segments = 10
	c.rings = 1
	return c


func _pieza_c(nombre: String, malla: Mesh, tam: Vector3, pos: Vector3, color: Color, giro_y: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = malla
	mi.scale = tam
	mi.position = pos
	mi.rotation_degrees.y = giro_y
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	mi.material_override = m
	(_destino if _destino != null else self).add_child(mi)


## Las casas de las laderas: una caja y un tejado piramidal por casa, en dos MultiMesh. De lejos son el «pueblo» que sube por el cuerpo.
func _poner_casas(trans: Array[Transform3D], rng: RandomNumberGenerator) -> void:
	if trans.is_empty():
		return
	var cuerpo := BoxMesh.new()
	cuerpo.size = Vector3(2.8, 1.8, 2.8)
	var tejado := _cono(2.6, 1.5, 4)
	for par in [[cuerpo, 0.9, "Casas"], [tejado, 2.55, "Tejados"]]:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color.WHITE
		mat.roughness = 1.0
		(par[0] as PrimitiveMesh).material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = par[0]
		mm.instance_count = trans.size()
		for j in trans.size():
			var t: Transform3D = trans[j]
			t.origin.y += float(par[1])
			if par[2] == "Tejados":
				t.basis = t.basis.rotated(Vector3.UP, PI * 0.25)
			mm.set_instance_transform(j, t)
			mm.set_instance_color(j, Color(0.60, 0.50, 0.38).lerp(Color(0.68, 0.6, 0.48), rng.randf()) if par[2] == "Casas" else Color(0.58, 0.27, 0.16).lerp(Color(0.50, 0.22, 0.14), rng.randf()))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = par[2]
		mmi.multimesh = mm
		add_child(mmi)


func _process(delta: float) -> void:
	if not respira or _busto == null:
		return
	_t += delta
	var k: float = 1.0 + 0.008 * sin(_t * 0.55)          # un ciclo cada ~11 s: se nota apenas
	_busto.scale = Vector3(1.0, k, 1.0)
	_busto.position.y = 24.0 * (1.0 - k)                  # pivota en la cintura, no en el suelo
	for ojo in _ojos:
		var mat := ojo.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = (2.2 + 0.6 * sin(_t * 0.9)) if ojos_abiertos else 0.0


func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	return m


func _poner_arboles(trans: Array[Transform3D], rng: RandomNumberGenerator) -> void:
	if trans.is_empty():
		return
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.9
	cono.height = 2.8
	cono.radial_segments = 6
	cono.rings = 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.roughness = 1.0
	cono.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cono
	mm.instance_count = trans.size()
	for j in trans.size():
		var t: Transform3D = trans[j]
		t.origin.y += 1.4 * t.basis.get_scale().y          # el cono tiene el centro a media altura: se apoya en la roca
		mm.set_instance_transform(j, t)
		mm.set_instance_color(j, Color(0.16, 0.30, 0.13).lerp(Color(0.26, 0.40, 0.16), rng.randf()))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Arboles"
	mmi.multimesh = mm
	add_child(mmi)


## --- Geometría: una elipse de radios `r` deformada con ruido. Estático para que el valle use la misma roca para sus montes. ---

static func _ruido(semilla_: int) -> FastNoiseLite:
	var r := FastNoiseLite.new()
	r.seed = semilla_
	r.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	r.frequency = 1.0
	r.fractal_octaves = 3
	return r


## Punto de la superficie en la dirección `n` (unitaria): radio 1 ± ruido, escalado a la elipse.
static func _sup(ruido: FastNoiseLite, n: Vector3, radios: Vector3, amp: float) -> Vector3:
	return n * (1.0 + ruido.get_noise_3dv(n * 1.6) * amp) * radios


## Malla de un bloque de roca. `color_alto` cubre lo que mira hacia arriba (musgo), `color_lado` el resto.
static func malla_blob(radios: Vector3, semilla_: int, amp: float = 0.14, res: int = 40, color_alto: Color = MUSGO, color_lado: Color = ROCA) -> ArrayMesh:
	var ruido: FastNoiseLite = _ruido(semilla_)
	var esf := SphereMesh.new()
	esf.radius = 1.0
	esf.height = 2.0
	esf.radial_segments = res
	esf.rings = maxi(res / 2, 6)
	var a: Array = esf.get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nor := PackedVector3Array()
	nor.resize(v.size())
	var col := PackedColorArray()
	col.resize(v.size())
	for i in v.size():
		var n: Vector3 = v[i].normalized()
		var p0: Vector3 = _sup(ruido, n, radios, amp)
		var t1: Vector3 = n.cross(Vector3.UP if absf(n.y) < 0.99 else Vector3.RIGHT).normalized()
		var t2: Vector3 = n.cross(t1)
		var p1: Vector3 = _sup(ruido, (n + t1 * 0.03).normalized(), radios, amp)
		var p2: Vector3 = _sup(ruido, (n + t2 * 0.03).normalized(), radios, amp)
		var nn: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
		if nn.dot(n) < 0.0:
			nn = -nn
		var arriba: float = nn.y + ruido.get_noise_3dv(n * 3.0 + Vector3(9, 9, 9)) * 0.35
		var c: Color = color_lado.lerp(color_alto, smoothstep(0.30, 0.62, arriba))
		var sombra: float = lerpf(0.60, 1.0, smoothstep(-0.9, 0.3, n.y)) + ruido.get_noise_3dv(n * 5.0) * 0.06     # lo de abajo, más oscuro
		v[i] = p0
		nor[i] = nn
		col[i] = Color(c.r * sombra, c.g * sombra, c.b * sombra, 1.0)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = nor
	a[Mesh.ARRAY_COLOR] = col
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return malla


## Un punto al azar de la superficie del bloque cuya normal vertical (n.y) esté entre `min_y` y `max_y`, o null si no lo encuentra en 40 intentos.
static func _punto_cara(radios: Vector3, semilla_: int, amp: float, rng: RandomNumberGenerator, min_y: float, max_y: float) -> Variant:
	var ruido: FastNoiseLite = _ruido(semilla_)
	for _i in 40:
		var n := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if n.y >= min_y and n.y <= max_y:
			return _sup(ruido, n, radios, amp)
	return null
