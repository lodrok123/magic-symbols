extends RefCounted
## VEGETACIÓN DE MONTE SUMICIO (14/11). Pablo: «no me convence la integración con el suelo. ¿Probamos a añadir hierba y variedad (rocas y
## otros elementos) alrededor para añadir volumen?» y «mete también dentro del pueblo, fíjate en el PPTX para integrar».
## Lo que dice Monte-Sumicio.pptx (Descargas) y se traslada aquí:
##   · lámina 4, «La muralla de leño»: la empalizada asoma entre matorral, helechos y rocas de granito con musgo; el camino llega pisado a la puerta;
##   · lámina 5, «Un lugar de cuento»: hierba alta y matas al pie de los muros de las pallozas, bordes de hierba que se comen el empedrado,
##     piedras sueltas con líquenes y manchas de helecho tostado (ocre);
##   · lámina 3, «El camino de subida»: matas de hierba seca a los lados del sendero y bolos de granito con musgo.
## Las matas, las piedras pequeñas, los juncos, las setas y la hojarasca son DECORADO: se pisan. Las rocas grandes y medianas chocan con su
## malla (14/11, «todas las colisiones por malla»); por eso solo van fuera del círculo o pegadas a la valla y a los muros, y nada se pone sobre
## el empedrado, el camino de tierra, las puertas ni junto a los personajes.
## Hierba: el matojo de la hierba del juego (Hierba3D, mismo material y viento); piezas: las de PiezaBosque3D (rocas con musgo, arbustos,
## setas, juncos, hojarasca). Semilla fija: sale igual cada vez.
##   Prueba / foto: herramientas/captura_vegetacion_sumicio.gd

const SEMILLA := 1411

## --- Hierba (matojos). Escala del matojo: a 1,0 mide ~1,2 m; la hierba del suelo usa ~0,3. ---
const MATOJO_VALLA := Vector2(0.5, 1.0)       ## escala junto a la valla (de lejos a pegado al pie)
const MATOJO_CASA := Vector2(0.42, 0.85)        ## al pie de los muros de las pallozas y la torre
const MATOJO_BORDE := Vector2(0.26, 0.5)        ## a los lados del empedrado y del camino
const MATOJO_CLARO := Vector2(0.28, 0.55)       ## matas sueltas en la hierba
const MATOJOS_VALLA_FUERA := 10                 ## por cada 1,15 m de valla
const MATOJOS_VALLA_DENTRO := 6
const MATOJOS_CASA := 55                        ## alrededor de cada palloza (la torre, el doble)
const BORDE_PASO := 0.55                        ## m entre puntos del borde del empedrado
const BORDE_PROB := 0.85                        ## probabilidad de mata en cada punto del borde
const CLAROS := 22                              ## manchas de hierba alta con alguna piedra, sueltas por la aldea
const TOSTADO := 0.2                            ## fracción de matas ocres (helecho tostado / hierba seca de la montaña)
const TINTE_VERDE := Color(0.47, 0.72, 0.31)    ## multiplica el color del matojo (que sale muy claro) hasta el verde del suelo
const TINTE_TOSTADO := Color(1.0, 0.72, 0.32)   ## ocre de helecho tostado, nunca amarillo chillón

## --- Piezas (probabilidad por cada 1,15 m de valla, o por casa) ---
const VALLA_ROCAS := 0.26           ## grupo de 1 roca mediana y 1-2 pequeñas, fuera
const VALLA_ROCA_GRANDE := 0.06     ## bolo de granito grande, fuera y algo apartado
const VALLA_MATORRAL := 0.30        ## macolla densa de hierba alta, fuera (el matorral de la lámina 4)
const VALLA_JUNCOS := 0.08          ## mata alta
const VALLA_SETAS := 0.05
const VALLA_HOJARASCA := 0.06
const VALLA_DENTRO_ROCA := 0.10     ## dentro solo cosas pequeñas: la jugadora anda por ahí
const VALLA_DENTRO_MATORRAL := 0.10
const CASA_ROCAS := 5               ## piedras pequeñas al pie de cada muro
const CASA_MATORRAL := 3           ## macollas al pie de cada muro
const RADIO_TORRE := 4.0            ## pie de la torre (su modelo trae mallas que la agrandan: se fija a mano)
const PUERTA_LIBRE := deg_to_rad(50.0)   ## medio ángulo libre delante de cada puerta
const LIBRE_PERSONAJE := 1.3        ## nada a menos de esto de un personaje, cofre o entrada


## `anillo`: {centro: Vector3, radio, puerta (ángulo), medio_hueco} de la empalizada (monte_sumicio_maqueta._empalizada_circular).
## `casas`: las pallozas (puerta hacia su +Z local). `torre`: la Torre Verde (puerta hacia +Z). `evitar`: puntos a dejar libres.
static func sembrar(padre: Node3D, mundo: Node, anillo: Dictionary, casas: Array[Node3D], torre: Node3D, evitar: Array[Vector3]) -> Node3D:
	var v := new()
	return v._sembrar(padre, mundo, anillo, casas, torre, evitar)


var _mundo: Node
var _rng := RandomNumberGenerator.new()
var _raiz: Node3D
var _evitar: Array[Vector3] = []
var _trs: Array[Transform3D] = []
var _tintes := PackedColorArray()
var _piezas := 0
var _solidos := 0


func _sembrar(padre: Node3D, mundo: Node, anillo: Dictionary, casas: Array[Node3D], torre: Node3D, evitar: Array[Vector3]) -> Node3D:
	_mundo = mundo
	_evitar = evitar
	_rng.seed = SEMILLA
	_raiz = Node3D.new()
	_raiz.name = "Vegetacion"
	padre.add_child(_raiz)
	if not anillo.is_empty():
		_pie_de_valla(anillo)
	for casa in casas:
		_pie_de_muro(casa.global_position, _radio_planta(casa, 3.0) - 0.15, casa.global_basis.z, MATOJOS_CASA, CASA_ROCAS, CASA_MATORRAL)
	if torre != null:
		_pie_de_muro(torre.global_position, RADIO_TORRE, torre.global_basis.z, MATOJOS_CASA * 2, CASA_ROCAS * 2, CASA_MATORRAL * 2)
	if not anillo.is_empty():
		_bordes_de_camino(anillo)
		_claros(anillo)
	_volcar_matojos()
	print("Vegetación de Sumicio: %d matas, %d piezas (%d rocas con choque)" % [_trs.size(), _piezas, _solidos])
	return _raiz


# ---------- La valla ----------

func _pie_de_valla(an: Dictionary) -> void:
	var c3: Vector3 = an["centro"]
	var radio: float = an["radio"]
	var ang0: float = float(an["puerta"]) + float(an["medio_hueco"])
	var arco: float = TAU - 2.0 * float(an["medio_hueco"])
	var n := int(ceil(arco * radio / 1.15))
	var paso := arco / float(n)
	for i in range(n):
		var a := ang0 + paso * (float(i) + 0.5)
		var fuera := Vector3(sin(a), 0.0, -cos(a))
		var tan := Vector3(cos(a), 0.0, sin(a))
		var pie := c3 + fuera * radio
		var junto_puerta := i < 2 or i >= n - 2        # a los lados de la cancela: hierba y piedras, nada que tape el paso
		for k in range(MATOJOS_VALLA_FUERA):
			var d := 0.08 + pow(_rng.randf(), 1.7) * 1.1
			var p := pie + tan * _rng.randf_range(-0.62, 0.62) + fuera * d
			_matojo(p, lerpf(MATOJO_VALLA.y, MATOJO_VALLA.x, clampf(d / 1.1, 0.0, 1.0)))
		for k in range(MATOJOS_VALLA_DENTRO):
			var d := 0.08 + pow(_rng.randf(), 1.9) * 0.75
			var p := pie + tan * _rng.randf_range(-0.62, 0.62) - fuera * d
			_matojo(p, lerpf(MATOJO_VALLA.y * 0.85, MATOJO_VALLA.x, clampf(d / 0.75, 0.0, 1.0)))
		# Fuera: rocas con musgo y matorral (lámina 4).
		if _rng.randf() < VALLA_ROCAS or (junto_puerta and i % 2 == 0):
			var p := pie + tan * _rng.randf_range(-0.4, 0.4) + fuera * _rng.randf_range(0.3, 0.6)
			_roca(p, "mediana")
			for k in range(1 + _rng.randi() % 2):
				_roca(p + tan * _rng.randf_range(-0.7, 0.7) + fuera * _rng.randf_range(-0.2, 0.4), "pequena")
		if junto_puerta:
			continue
		if _rng.randf() < VALLA_ROCA_GRANDE:
			_roca(pie + fuera * _rng.randf_range(0.9, 1.4), "grande")
		if _rng.randf() < VALLA_MATORRAL:
			_matorral(pie + tan * _rng.randf_range(-0.4, 0.4) + fuera * _rng.randf_range(0.3, 0.7), 1.0)
		if _rng.randf() < VALLA_JUNCOS:
			_pieza("juncos_a" if _rng.randf() < 0.5 else "juncos_b", pie + tan * _rng.randf_range(-0.5, 0.5) + fuera * 0.25, _rng.randf_range(0.9, 1.3), 0.05)
		if _rng.randf() < VALLA_SETAS:
			_pieza("setas_grupo", pie + tan * _rng.randf_range(-0.5, 0.5) + fuera * 0.18, _rng.randf_range(0.7, 1.0), 0.0)
		if _rng.randf() < VALLA_HOJARASCA:
			_pieza("hojas_monton", pie + fuera * _rng.randf_range(0.3, 0.9), _rng.randf_range(0.8, 1.2), 0.05)
		# Dentro: poco, pequeño y pegado a la valla.
		if _rng.randf() < VALLA_DENTRO_ROCA:
			_roca(pie - fuera * _rng.randf_range(0.2, 0.4), "pequena")
		if _rng.randf() < VALLA_DENTRO_MATORRAL:
			_matorral(pie - fuera * 0.35, 0.75)


# ---------- Las casas ----------

## Corona de hierba, piedras y matas al pie de un muro circular, sin tocar el arco de delante de la puerta (`puerta`: hacia dónde mira).
func _pie_de_muro(centro: Vector3, radio: float, puerta: Vector3, matojos: int, rocas: int, matorral: int) -> void:
	var ang_puerta := atan2(puerta.x, puerta.z)
	var libre := func(a: float) -> bool: return absf(angle_difference(a, ang_puerta)) < PUERTA_LIBRE
	for k in range(matojos):
		var a := _rng.randf() * TAU
		if libre.call(a):
			continue
		var d := radio + pow(_rng.randf(), 1.6) * 0.75
		_matojo(centro + Vector3(sin(a), 0.0, cos(a)) * d, lerpf(MATOJO_CASA.y, MATOJO_CASA.x, (d - radio) / 0.75))
	for k in range(rocas):
		var a := _rng.randf() * TAU
		if not libre.call(a):
			_roca(centro + Vector3(sin(a), 0.0, cos(a)) * (radio + _rng.randf_range(0.1, 0.4)), "pequena" if _rng.randf() < 0.7 else "mediana")
	for k in range(matorral):
		var a := _rng.randf() * TAU
		if not libre.call(a):
			_matorral(centro + Vector3(sin(a), 0.0, cos(a)) * (radio + 0.3), 0.85)


# ---------- El empedrado y el camino ----------

## A lo largo de cada arista entre una casilla de empedrado/camino y una de hierba, matas cortas del lado de la hierba (lámina 5: la hierba
## se come el borde de las losas) y, de vez en cuando, una piedra.
func _bordes_de_camino(an: Dictionary) -> void:
	if not _mundo.has_method("_tipo_suelo"):
		return
	var c3: Vector3 = an["centro"]
	var r: float = float(an["radio"]) + 3.0
	var s := Terreno3D.casilla
	var c0 := Terreno3D.celda_de(c3 - Vector3(r, 0.0, r))
	var c1 := Terreno3D.celda_de(c3 + Vector3(r, 0.0, r))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var c := Vector2i(cx, cz)
			if _tipo(c) == 0 or Terreno3D.es_vacio(c):
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _tipo(c + d) != 0 or Terreno3D.es_vacio(c + d):
					continue
				var centro := Terreno3D.centro_de(c, 0.0)
				var normal := Vector3(d.x, 0.0, d.y)
				var a_lo_largo := Vector3(-d.y, 0.0, d.x)
				var t := -s * 0.5 + BORDE_PASO * 0.5
				while t < s * 0.5:
					if _rng.randf() < BORDE_PROB:
						var p := centro + normal * (s * 0.5 + _rng.randf_range(0.15, 0.55)) + a_lo_largo * (t + _rng.randf_range(-0.2, 0.2))
						_matojo(p, _rng.randf_range(MATOJO_BORDE.x, MATOJO_BORDE.y))
						if _rng.randf() < 0.07:
							_roca(p + normal * 0.25, "pequena")
					t += BORDE_PASO


# ---------- Claros ----------

## Unas manchas de hierba alta con alguna piedra, sueltas en la hierba de dentro del castro (rompen la planicie).
func _claros(an: Dictionary) -> void:
	var c3: Vector3 = an["centro"]
	var radio: float = float(an["radio"]) - 2.0
	var hechos := 0
	var intentos := 0
	while hechos < CLAROS and intentos < CLAROS * 20:
		intentos += 1
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * radio
		var p := c3 + Vector3(sin(a), 0.0, cos(a)) * d
		if not _libre(p, 1.6):
			continue
		hechos += 1
		for k in range(7 + _rng.randi() % 8):
			var q := p + Vector3(_rng.randf_range(-0.9, 0.9), 0.0, _rng.randf_range(-0.9, 0.9))
			_matojo(q, _rng.randf_range(MATOJO_CLARO.x, MATOJO_CLARO.y))
		if _rng.randf() < 0.55:
			_roca(p, "pequena" if _rng.randf() < 0.6 else "mediana")


# ---------- Piezas sueltas ----------

## ¿Se puede decorar en `p`? Hierba (no empedrado, camino ni vacío) y lejos de personajes, cofres y entradas (`radio_extra`: el hueco que se
## pide alrededor, también en hierba).
func _libre(p: Vector3, radio_extra: float = 0.0) -> bool:
	var c := Terreno3D.celda_de(p)
	if Terreno3D.es_vacio(c) or Terreno3D.es_agua(c) or _tipo(c) != 0:
		return false
	if radio_extra > 0.0:
		for d: Vector3 in [Vector3(radio_extra, 0, 0), Vector3(-radio_extra, 0, 0), Vector3(0, 0, radio_extra), Vector3(0, 0, -radio_extra)]:
			var cc := Terreno3D.celda_de(p + d)
			if Terreno3D.es_vacio(cc) or _tipo(cc) != 0 or Terreno3D.bloqueada(cc):
				return false
	for e in _evitar:
		if Vector2(p.x - e.x, p.z - e.z).length() < LIBRE_PERSONAJE:
			return false
	return true


func _tipo(c: Vector2i) -> int:
	return int(_mundo.call("_tipo_suelo", c)) if _mundo.has_method("_tipo_suelo") else 0


func _suelo(p: Vector3) -> float:
	var c := Terreno3D.celda_de(p)
	return Terreno3D.y_pies(c) + Terreno3D.realce_en(p)


func _matojo(p: Vector3, escala: float) -> void:
	if not _libre(p):
		return
	var s := escala * _rng.randf_range(0.85, 1.15)
	var base := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf() * 0.18)
	var v := 0.85 + _rng.randf() * 0.25
	var t := TINTE_TOSTADO if _rng.randf() < TOSTADO else TINTE_VERDE
	var tinte := Color(v * t.r, v * t.g, v * t.b, _rng.randf())          # alfa = fase del balanceo (como Hierba3D)
	_trs.append(Transform3D(base.scaled(Vector3(s * 1.1, s, s * 1.1)), Vector3(p.x, _suelo(p) - 0.04, p.z)))
	_tintes.append(tinte)


## Granito con musgo: «grande» (bolo de ~1,5 m), «mediana» (la misma roca a media escala) o «pequena» (la piedra suelta, crecida). La
## roca mediana de Meshy (roca_musgo_m) no se usa: lleva una mancha rojiza que desde arriba parece una seta.
func _roca(p: Vector3, tam: String) -> void:
	match tam:
		"grande":
			_pieza("roca_musgo_g", p, _rng.randf_range(1.1, 1.6), 0.3, true)
		"mediana":
			_pieza("roca_musgo_g", p, _rng.randf_range(0.5, 0.75), 0.3, true)
		_:
			_pieza("roca_musgo_p", p, _rng.randf_range(1.8, 3.0), 0.3)


## Matorral: una macolla de 6-9 matojos altos y juntos, a veces con juncos en medio (los arbustos de Meshy, desde arriba, parecían guijarros).
func _matorral(p: Vector3, escala: float) -> void:
	if not _libre(p):
		return
	for k in range(6 + _rng.randi() % 4):
		var q := p + Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.4, 0.4))
		_matojo(q, _rng.randf_range(0.6, 0.95) * escala)
	if _rng.randf() < 0.4:
		_pieza("juncos_a" if _rng.randf() < 0.5 else "juncos_b", p, _rng.randf_range(1.0, 1.4) * escala, 0.05)


## Radio de la planta de una casa vista desde arriba: el alero del tejado (la caja de sus mallas visibles), para que la corona de hierba no
## quede escondida debajo.
func _radio_planta(casa: Node3D, tope: float) -> float:
	var r := 1.6
	for mi in casa.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.layers == 0 or not m.is_visible_in_tree() or m.mesh == null:
			continue
		var caja := m.global_transform * m.get_aabb()
		r = maxf(r, maxf(maxf(absf(caja.position.x - casa.global_position.x), absf(caja.end.x - casa.global_position.x)),
			maxf(absf(caja.position.z - casa.global_position.z), absf(caja.end.z - casa.global_position.z))))
	return minf(r, tope)


## Una pieza de PiezaBosque3D apoyada en el suelo y hundida `hundir` (fracción de su alto), con giro y escala al azar.
## `solido` (14/11): la pieza choca con su malla (ColisionPieza, la franja del cuerpo); si asoma menos de ALTO_MIN_SOLIDO, se pisa igual.
func _pieza(id: String, p: Vector3, escala: float, hundir: float, solido: bool = false) -> void:
	if not _libre(p):
		return
	var mi := PiezaBosque3D.crear(id)
	if mi == null:
		return
	_raiz.add_child(mi)
	var alto := mi.mesh.get_aabb().size.y * escala
	mi.global_position = Vector3(p.x, _suelo(p) - alto * hundir, p.z)
	mi.rotation = Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf() * TAU, _rng.randf_range(-0.08, 0.08))
	mi.scale = Vector3.ONE * escala * Vector3(_rng.randf_range(0.9, 1.1), _rng.randf_range(0.85, 1.1), _rng.randf_range(0.9, 1.1))
	_piezas += 1
	if solido:
		_cuerpo_de(mi, Vector3(p.x, _suelo(p), p.z))


## Cuerpo de choque de `mi` medido sobre su malla, con la base en el suelo `pie` (la roca está hundida: lo enterrado no cuenta).
func _cuerpo_de(mi: MeshInstance3D, pie: Vector3) -> void:
	var t := Transform3D(mi.global_basis, mi.global_position - pie)
	var tris := PackedVector3Array()
	for v in mi.mesh.get_faces():
		tris.append(t * v)
	var lista := ColisionPieza.cascos_triangulos(tris, "contorno")
	if lista.is_empty():
		return
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Solido"
	cuerpo.collision_layer = Terreno3D.CAPA_SOLIDO
	cuerpo.collision_mask = 0
	for nube in lista:
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		sh.points = nube
		cs.shape = sh
		cuerpo.add_child(cs)
	_raiz.add_child(cuerpo)
	cuerpo.global_position = pie
	_solidos += 1


## Todos los matojos en un MultiMesh con la malla y el material de la hierba del nivel (Hierba3D), para que sean la misma hierba.
func _volcar_matojos() -> void:
	if _trs.is_empty():
		return
	var hierba: Node = null
	for h in _mundo.find_children("*", "Hierba3D", true, false):
		hierba = h
		break
	if hierba == null:
		push_warning("Vegetación de Sumicio: el nivel no tiene Hierba3D; sin matas.")
		_trs.clear()
		return
	hierba.call("_preparar")
	var malla: Mesh = hierba.get("_malla")
	hierba.call("_multimalla", malla, _trs, _tintes, _raiz, "Matojos")
