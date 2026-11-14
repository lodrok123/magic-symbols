extends Node3D

const MEDIA_ALTURA := 0.32
const ENTRADA := Vector2i(0, 1)
const SALIDA := Vector2i(0, 2)
const VECINO := Vector2i(-1, -1)
const COFRE := Vector2i(1, 1)
const MESA := Vector2i(1, -1)

@export var centro := Vector2i.ZERO
@export var tienda := false
@export var casa_brais := false
@export var telar := false          ## 14/11: la casa de Sabela tiene telar (DISENO_INTERIORES_SUMICIO.md)
## 14/11: dónde se entra y por dónde se sale (casillas desde `centro`). Variables para que la Torre Verde (interior_torre.gd) pueda tener otras.
var entrada := ENTRADA
var salida := SALIDA
var torre := false
@onready var camara: Camera3D = $Camara
var _tapa: MeshInstance3D


func montar() -> void:
	position = Terreno3D.centro_de(centro, Terreno3D.alto_suelo)
	var s := Terreno3D.casilla
	for z in range(-2, 3):
		for x in range(-2, 3):
			var c := centro + Vector2i(x, z)
			var borde := absi(x) == 2 or absi(z) == 2
			var umbral := Vector2i(x, z) == SALIDA
			var alto := MEDIA_ALTURA if z < 0 else 0.0
			if alto > 0.0:
				Terreno3D.realces_terreno[c] = alto
			var p := Vector3(x * s, alto, z * s)
			# 14/11: suelo de tierra pisada (lámina 9); el Ástrago algo más claro y seco, la Travariza más oscura.
			var tierra := Color(0.68, 0.6, 0.53) if z < 0 else Color(0.6, 0.5, 0.42)
			if Vector2(x, z).length() > RADIO_MURO + 0.3:
				# Las esquinas quedan fuera del muro redondo: sombra bajo el tejado de paja.
				_caja(p - Vector3.UP * 0.067, Vector3(s, 0.16, s), Color("#2a221b"))
			else:
				_caja(p - Vector3.UP * 0.067, Vector3(s, 0.16, s), tierra, _mat_tierra())
			if borde and not umbral:
				Terreno3D.bloquear_celda_completa(c)
	_muro_redondo()
	_alero_paja()
	_bordillo_astrago()
	_paja_travariza()
	# Las piezas reutilizan sus materiales y proporciones. Se distribuyen a la escala de la sala.
	var muebles := {
		"Hogar": Vector3(-1.68, MEDIA_ALTURA, -2.75),
		"VaraAhumado": Vector3(-1.68, MEDIA_ALTURA, -2.75),
		"Banco": Vector3(-1.7, MEDIA_ALTURA, -2.1),
		"Arcon": Vector3(1.65, MEDIA_ALTURA, -2.3),
		"Pesebre": Vector3(2.55, 0.0, 1.10),
		"Tabique": Vector3(2.55, 0.0, 0.35),
	}
	for nombre in muebles:
		var pieza := $Mobiliario.get_node(nombre) as Node3D
		if tienda:
			pieza.hide()
			continue
		pieza.position = muebles[nombre]
		if casa_brais and nombre == "Banco":
			pieza.position = Vector3(-2.65, MEDIA_ALTURA, -0.35)
		pieza.scale = Vector3.ONE * 1.55
		if nombre in ["Banco", "Arcon", "Pesebre", "Tabique"]:
			var celda := Terreno3D.celda_de(pieza.global_position)
			Terreno3D.bloquear_contorno(celda, pieza)
	if not tienda:
		_amueblar_astrago()
	if tienda:
		_caja(Vector3(-2.3, 0.70, -1.65), Vector3(1.65, 0.76, 0.60), Color("#674630"))
		_caja(Vector3(-2.3, 1.10, -1.65), Vector3(1.77, 0.10, 0.72), Color("#ad794e"))
		for x in [1.8, 2.8]:
			_caja(Vector3(x, 0.64, -2.80), Vector3(0.11, 0.64, 0.62), Color("#75563a"))
		_caja(Vector3(2.3, 0.98, -2.80), Vector3(1.35, 0.13, 0.85), Color("#514c58"))
		_caja(Vector3(2.55, 1.11, -2.85), Vector3(0.29, 0.14, 0.26), Color("#768769"))
		_caja(Vector3(2.10, 1.12, -2.74), Vector3(0.12, 0.17, 0.12), Color("#b47753"))
		_rotulo("Mostrador", Vector3(-2.3, 1.8, -2.3))
		_rotulo("Síntesis", Vector3(2.3, 1.65, -2.3))
	else:
		_caja(Vector3(2.3, 0.25, 2.3), Vector3(0.85, 0.5, 0.55), Color("#775132"))
		_tapa = _caja(Vector3(2.3, 0.52, 2.3), Vector3(0.90, 0.12, 0.59), Color("#9d7449"))
		if casa_brais:
			for i in range(5):
				var paja := _caja(Vector3(2.45 + (i % 3) * 0.17, 0.035, 1.45 + i * 0.15),
					Vector3(0.18, 0.03, 0.26), Color("#ad8e55"))
				paja.rotation.y = i * 0.6
		_rotulo("Ástrago", Vector3(-1.6, 0.65, -3.1))
		_rotulo("Travariza", Vector3(1.65, 0.7, 2.65))
		# 14/11: los animales de la Travariza (lámina 11: «las vacas y, en un reservado aparte, algún cerdo»), vivos (AnimalVivo).
		# La vaca dormita al oeste del umbral con la cabeza hacia el Ástrago; el cerdo hocica a su lado, junto al muro sur.
		AnimalVivo.poner(self, "vaca", Vector3(-2.5, 0.0, 1.5), -PI * 0.5)
		AnimalVivo.poner(self, "cerdo", Vector3(-1.2, 0.0, 3.0), 0.35)
		for celda in [Vector2i(-1, 1), Vector2i(-1, 0)]:
			Terreno3D.bloquear_celda_completa(centro + celda)
	_rotulo("Salida", Vector3(0, 0.65, 4.55))
	camara.look_at(global_position + Vector3.UP * 0.35)
	get_viewport().size_changed.connect(_encuadrar)
	_encuadrar()


## 14/11: el Ástrago con las piezas de Meshy (colección del hogar rústico, separada por herramientas/separar_coleccion_hogar.gd): láminas 9, 10 y 12.
## Ancho real de cada pieza en metros (la colección no viene a escala: se escala cada una a su ancho).
const PIEZAS_HOGAR := {
	"horno_pan": 1.25, "varas_ahumado": 1.5, "arca_grano": 1.15, "yugo_aperos": 1.1, "cesto": 0.55, "telar": 1.0,
}


func _amueblar_astrago() -> void:
	var y := MEDIA_ALTURA
	# El horno de pan contra el muro norte, entre el hogar y el arca (lámina 10: «junto al fuego, el horno de pan»).
	_pieza_hogar("horno_pan", Vector3(0.25, y, -2.85), 0.0, true)
	# Las varas de ahumado colgadas sobre el hogar, con los chorizos (sustituyen a la vara de prueba).
	$Mobiliario.get_node("VaraAhumado").hide()
	_pieza_hogar("varas_ahumado", Vector3(-1.68, y + 1.05, -2.45), 0.0, false)
	# El arca del grano en el sitio del arcón de prueba (lámina 12: «arcas tradicionales guardan la harina y el grano»).
	$Mobiliario.get_node("Arcon").hide()
	_pieza_hogar("arca_grano", Vector3(1.75, y, -2.4), 0.0, false)
	# Aperos y yugo colgados del muro oeste, mirando al centro.
	_pieza_hogar("yugo_aperos", Vector3(-3.3, y + 0.35, -1.55), PI * 0.5, false)
	# Un cesto de castañas junto al fuego.
	_pieza_hogar("cesto", Vector3(-0.7, y, -1.75), 0.4, false)
	# El telar, solo en casa de Sabela.
	if telar:
		_pieza_hogar("telar", Vector3(2.75, y, -1.5), -PI * 0.5, true)


func _pieza_hogar(nombre: String, pos: Vector3, giro: float, bloquea: bool) -> MeshInstance3D:
	var ruta := "res://arte/meshy/piezas/hogar_%s.res" % nombre
	if not ResourceLoader.exists(ruta):
		return null
	var mi := MeshInstance3D.new()
	mi.name = nombre.capitalize().replace(" ", "")
	mi.mesh = load(ruta)
	mi.scale = Vector3.ONE * (float(PIEZAS_HOGAR[nombre]) / maxf(mi.mesh.get_aabb().size.x, 0.001))
	add_child(mi)
	mi.position = pos
	mi.rotation.y = giro
	if bloquea:
		Terreno3D.bloquear_contorno(Terreno3D.celda_de(mi.global_position), mi)
	return mi


func _encuadrar() -> void:
	var ventana := get_viewport().get_visible_rect().size
	var aspecto := ventana.x / maxf(ventana.y, 1.0)
	# En la referencia los cinco módulos ocupan el ancho y el suelo entre muros, tres quintos.
	var ancho_palloza := Terreno3D.casilla * 5.0
	# En panorámico se puede recortar el exterior, con margen vertical para la salida.
	var alto_minimo := Terreno3D.casilla * 3.85
	camara.size = maxf(ancho_palloza / maxf(aspecto, 0.01), alto_minimo)


func contiene(c: Vector2i) -> bool:
	return Rect2i(centro - Vector2i(2, 2), Vector2i(5, 5)).has_point(c)


func mostrar_cofre(abierto: bool) -> void:
	if _tapa != null:
		_tapa.position = Vector3(2.3, 0.73, 2.03) if abierto else Vector3(2.3, 0.52, 2.3)
		_tapa.rotation.x = -1.15 if abierto else 0.0


## 14/11: muros y suelo coherentes con el concepto (láminas 6 y 9): planta CIRCULAR de granito en seco, cantos redondeados con musgo y
## liquen, más alto al norte y bajo al sur (la cámara mira desde el sur), con el hueco de la puerta; suelo de tierra pisada; el Ástrago
## elevado con un bordillo de piedras; paja en la Travariza. Las piedras son las de Meshy con musgo (piedra_est_musgo_*).
const RADIO_MURO := 2.2          # en casillas: los cantos caen sobre la corona de casillas bloqueadas
const ALTO_NORTE := 1.35
const ALTO_SUR := 0.4
const PIEDRAS_MUSGO := ["res://arte/meshy/piezas/piedra_est_musgo_0.glb", "res://arte/meshy/piezas/piedra_est_musgo_1.glb",
	"res://arte/meshy/piezas/piedra_est_musgo_2.glb", "res://arte/meshy/piezas/piedra_est_musgo_3.glb", "res://arte/meshy/piezas/piedra_est_musgo_4.glb"]
static var _mallas_piedra: Array = []
static var _tierra: StandardMaterial3D
static var _gris := {}


func _mat_tierra() -> StandardMaterial3D:
	if _tierra == null:
		_tierra = StandardMaterial3D.new()
		_tierra.roughness = 1.0
		var tex := "res://arte/suelo_meshy/tierra_arriba.png"
		if ResourceLoader.exists(tex):
			_tierra.albedo_texture = load(tex)
			_tierra.uv1_triplanar = true
			_tierra.uv1_scale = Vector3.ONE * 0.35
	return _tierra


func _piedras() -> Array:
	if _mallas_piedra.is_empty():
		for ruta in PIEDRAS_MUSGO:
			if ResourceLoader.exists(ruta):
				var n := (load(ruta) as PackedScene).instantiate()
				var mi := n.find_children("*", "MeshInstance3D", true, false)
				if not mi.is_empty():
					_mallas_piedra.append((mi[0] as MeshInstance3D).mesh)
				n.free()
	return _mallas_piedra


## Un canto de granito de `ancho` metros, apoyado con la base en `pos`, girado `giro` y algo aplastado (los de la lámina son más largos que altos).
func _canto(pos: Vector3, ancho: float, alto: float, giro: float, rng: RandomNumberGenerator) -> void:
	var mallas := _piedras()
	if mallas.is_empty():
		_caja(pos + Vector3.UP * alto * 0.5, Vector3(ancho, alto, ancho * 0.7), Color("#7d786b"))
		return
	var malla: Mesh = mallas[rng.randi() % mallas.size()]
	var bb := malla.get_aabb()
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	# Granito gris con liquen (lámina 6), no la piedra verde del bosque: se agrisa el material de Meshy.
	var orig := malla.surface_get_material(0) as StandardMaterial3D
	if orig != null:
		if not _gris.has(orig):
			var m := orig.duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.82, 0.8, 0.74)
			_gris[orig] = m
		mi.material_override = _gris[orig]
	add_child(mi)
	mi.scale = Vector3(ancho / maxf(bb.size.x, 0.001), alto / maxf(bb.size.y, 0.001), ancho * 0.75 / maxf(bb.size.z, 0.001))
	mi.rotation = Vector3(rng.randf_range(-0.08, 0.08), giro, rng.randf_range(-0.08, 0.08))
	mi.position = pos - Vector3(0, bb.position.y * mi.scale.y, 0)


func _muro_redondo() -> void:
	var s := Terreno3D.casilla
	var r := RADIO_MURO * s
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(centro)
	var hueco := s * 0.48                     # media anchura de la puerta (casilla SALIDA)
	# Muro grueso (lámina 6, planta: doble anillo de cantos): una hoja exterior más alta tapa el hueco hasta las esquinas.
	var vueltas_fuera := int(TAU * (r + 0.85) / 1.1)
	vueltas_fuera = 0       # 14/11 (Pablo): con el fondo negro la hoja exterior quedaba en piedras sueltas flotando
	for i in range(vueltas_fuera):
		var a := TAU * float(i) / vueltas_fuera
		var p := Vector3(sin(a), 0.0, -cos(a)) * (r + 0.85)
		if p.z > 0.0 and absf(p.x) < hueco + 0.3:
			continue
		var alto_f := lerpf(ALTO_NORTE + 0.2, ALTO_SUR + 0.1, (1.0 - cos(a)) * 0.5)
		_canto(p, 1.25, alto_f, -a + rng.randf_range(-0.2, 0.2), rng)
	var vueltas := int(TAU * r / 0.85)
	for i in range(vueltas):
		var a := TAU * float(i) / vueltas
		var dir := Vector3(sin(a), 0.0, -cos(a))       # a = 0 es el norte
		var pos := dir * r
		if pos.z > 0.0 and absf(pos.x) < hueco:
			continue
		var base := MEDIA_ALTURA if pos.z < -s * 0.5 else 0.0
		var alto := lerpf(ALTO_NORTE, ALTO_SUR, (1.0 - cos(a)) * 0.5)
		var y := 0.0 - 0.05
		var hilada := 0
		while y < alto:
			var h := rng.randf_range(0.34, 0.46)
			var desfase := 0.42 if hilada % 2 == 1 else 0.0       # a soga: cada hilada tapa las juntas de la de abajo
			var aa := a + desfase * 0.85 / r
			var d := Vector3(sin(aa), 0.0, -cos(aa))
			var p := d * (r + rng.randf_range(-0.08, 0.08))
			if not (p.z > 0.0 and absf(p.x) < hueco):
				_canto(p + Vector3.UP * (y + base * 0.0), rng.randf_range(0.85, 1.05), h, -aa + rng.randf_range(-0.2, 0.2), rng)
			y += h * 0.82
			hilada += 1
	# Las jambas de la puerta: dos cantos altos a cada lado del hueco (lámina 6, detalle de la puerta).
	for lado in [-1.0, 1.0]:
		_canto(Vector3(lado * (hueco + 0.25), 0.0, sqrt(maxf(r * r - hueco * hueco, 0.0))), 0.6, ALTO_SUR + 0.25, PI * 0.5, rng)


## 14/11: fuera del muro no hay vacío: se ve el arranque del tejado cónico de paja cortado (láminas 6 y 9), que baja desde la coronación
## del muro hacia fuera y se oscurece, hasta más allá de lo que enseña la cámara. Anillo con colores por vértice y briznas en franjas.
func _alero_paja() -> void:
	var s := Terreno3D.casilla
	# 14/11 (Pablo): fuera del muro, NEGRO. El borde no es un círculo: el plano negro queda un poco por debajo de la coronación de la hoja
	# exterior, así que el contorno lo dibujan las propias piedras que asoman; con algo de ruido en el radio para que no se adivine el anillo.
	var r0 := RADIO_MURO * s + 0.3
	var r1 := r0 + 12.0
	var n := 160
	var v := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var bandas := 6
	for i in range(n + 1):
		var a := TAU * float(i) / n
		var d := Vector3(sin(a), 0.0, -cos(a))
		var alto := lerpf(ALTO_NORTE, ALTO_SUR, (1.0 - cos(a)) * 0.5) * 0.8
		var ruido := 0.1 * sin(a * 23.0) + 0.07 * sin(a * 57.0 + 1.3) + 0.05 * sin(a * 131.0 + 0.4)
		for b in range(bandas + 1):
			var t := float(b) / bandas
			var rr := lerpf(r0 + ruido, r1, t * t)
			var y := alto
			# Las casas están en fila cada 7 casillas: el alero no pasa de la mitad para no meterse en la vecina.
			var pv := d * rr + Vector3.UP * y
			pv.x = clampf(pv.x, -3.45 * s, 3.45 * s)
			v.append(pv)
			col.append(Color.BLACK)
	for i in range(n):
		for b in range(bandas):
			var k := i * (bandas + 1) + b
			var k2 := k + bandas + 1
			idx.append_array([k, k2, k + 1, k + 1, k2, k2 + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true            # la niebla del mundo lo aclaraba hasta parecer vacío
	mat.vertex_color_is_srgb = true
	var mi := MeshInstance3D.new()
	mi.name = "AleroPaja"
	mi.mesh = am
	mi.material_override = mat
	add_child(mi)
	# Entre dos casas vecinas queda una franja sin fondo: también negra, hasta donde empieza la otra.
	for lado in [-1.0, 1.0]:
		var franja := _caja(Vector3(lado * 3.98 * s, ALTO_SUR * 0.7, 0.0), Vector3(1.08 * s, 0.05, 30.0), Color.BLACK)
		(franja.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(franja.material_override as StandardMaterial3D).disable_fog = true


## El escalón del Ástrago (la parte noble, elevada) rematado con una fila de piedras planas.
func _bordillo_astrago() -> void:
	var s := Terreno3D.casilla
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(centro) + 7
	# el bordillo muere contra el muro redondo (si no, asoma por fuera, sobre el fondo negro)
	var lim := sqrt(pow(RADIO_MURO * s, 2.0) - pow(s * 0.5, 2.0)) - 0.6
	var x := -lim
	while x < lim - 0.5:
		var ancho := rng.randf_range(0.5, 0.7)
		if true:
			_canto(Vector3(x + ancho * 0.5, -0.04, -s * 0.5 + 0.05), ancho, MEDIA_ALTURA + 0.08, rng.randf_range(-0.15, 0.15), rng)
		x += ancho * 0.92


## Paja suelta sobre la tierra de la Travariza (la cama del ganado), en manchas.
func _paja_travariza() -> void:
	if tienda:
		return
	var s := Terreno3D.casilla
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(centro) + 13
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	for i in range(70):
		# más densa bajo los animales (oeste), rala hacia la puerta
		var p := Vector3(rng.randf_range(-1.7, 0.2) * s * (1.0 - rng.randf() * 0.3), 0.02, rng.randf_range(0.05, 1.45) * s)
		var tono := Color("#8f7546").lerp(Color("#b39a62"), rng.randf())
		var brizna := _caja(p, Vector3(rng.randf_range(0.2, 0.42), 0.015, rng.randf_range(0.025, 0.05)), tono, mat)
		brizna.rotation.y = rng.randf() * PI


func _caja(p: Vector3, tam: Vector3, color: Color, mat: Material = null) -> MeshInstance3D:
	var caja := BoxMesh.new()
	caja.size = tam
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if mat is StandardMaterial3D:
		material = (mat as StandardMaterial3D).duplicate()
		material.albedo_color = color
	var pieza := MeshInstance3D.new()
	pieza.mesh = caja
	pieza.material_override = material
	add_child(pieza)
	pieza.position = p
	return pieza


func _rotulo(texto: String, p: Vector3) -> void:
	var rotulo := Label3D.new()
	rotulo.text = texto
	rotulo.position = p
	rotulo.pixel_size = 0.012
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(rotulo)
