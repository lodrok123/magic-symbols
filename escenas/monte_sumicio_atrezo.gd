extends RefCounted
## ATREZO DE MONTE SUMICIO (25/11/2026). Pablo: «edita Monte Sumicio con los objetos (ya con sus texturas reales) y espárcelos por el pueblo
## para darle densidad». Objetos pequeños del pack «SH assets» (arte/sh_assets/atrezo/sh_*.glb, horneados con tools/exportar_atrezo_sh.py
## --hornear; inventario en docs/INVENTARIO_ATREZO_SH.md). Fuera de git: si faltan, el pueblo queda como antes y se avisa.
## Qué se pone (semilla fija: sale igual cada vez):
##   · cada palloza: a un lado de la puerta, un rincón de cerámica (tinaja grande y cántaros, a veces flores); al otro, leña o barril y caja;
##   · la tienda: mercancía a los dos lados de la puerta (cajas, arcón, barriles, tinajas, cántaros) y el cartel;
##   · el gremio: barriles, caja y leña; el obrador: troncos, cajas abiertas y piedras; la torre: tinajas y flores;
##   · pegado a la valla por dentro, de vez en cuando, un montón de leña o una caja con un barril.
## Nada sobre el empedrado ni el camino, delante de las puertas ni junto a personajes, cofres y entradas. Lo grande (barriles, cajas,
## arcón, troncos) choca con su malla; lo pequeño se pisa. Se mira con herramientas/captura_atrezo_sumicio.gd.

const ACTIVO := true                    ## false: Sumicio sin el atrezo del pack
const CARPETA := "res://arte/sh_assets/atrezo/"
const SEMILLA := 2511
## Escala por categoría (el pack viene grande y en metros; la jugadora mide 1 u): barril ~0,6 u, caja ~0,65 u, flor ~0,5 u.
const ESCALA := {"contenedor": 0.42, "adorno": 0.42, "ceramica": 0.42, "piedra": 0.45, "vegetacion": 0.3}
const SOLIDOS := ["barril", "barril_bajo", "arcon", "cajon_abierto", "caja_cerrada", "caja_abierta", "troncos"]
const PUERTA_LIBRE := deg_to_rad(42.0)   ## medio ángulo libre delante de cada puerta
const LIBRE_PERSONAJE := 1.3
const VALLA_PROB := 0.32                 ## probabilidad de montón por cada 1,15 m de valla (por dentro)
const RINCONES := 12                     ## rincones sueltos en la hierba del castro (barril y caja, tinajas, leña, cajón con flores, piedras)
const TERCER_RINCON := 0.7               ## probabilidad de un tercer rincón por palloza, más hacia atrás
## Tinte que multiplica el color horneado (25/11: la madera del pack sale rosada y pálida junto a la paja y la empalizada).
const TINTE := {"contenedor": Color(1.0, 0.82, 0.64), "adorno": Color(1.0, 0.9, 0.8)}
const VALLA_CANCELA_LIBRE := 4           ## paneles libres a cada lado de la cancela

const CERAMICA_GRANDE := ["tinaja_a", "tinaja_b", "tinaja_c", "tinaja_d", "tinaja_e", "tinaja_f"]
const FLORES := ["flor_amarilla", "flor_blanca", "rosal"]

var _mundo: Node
var _raiz: Node3D
var _rng := RandomNumberGenerator.new()
var _evitar: Array[Vector3] = []
var _puestos: Array[Vector3] = []        ## sitios ya ocupados por el atrezo (x, z y radio en y)
var _puertas: Array = []                 ## [centro del edificio, ángulo de su puerta, alcance] de cada puerta
var _edificios: Array[Vector3] = []      ## centro (x, z) y radio de muro (y) de cada edificio: nada por dentro
var _escenas: Dictionary = {}
var _cantaros: Array[String] = []
var _mats: Dictionary = {}
var _cascos: Dictionary = {}             ## nombre -> cascos de choque ya medidos (en el espacio del objeto, a su escala)
var _cuenta := 0
var _solidos := 0
var _us_carga := 0                       ## µs leyendo los .glb (para el informe de carga)
var _us_choque := 0


static func sembrar(padre: Node3D, mundo: Node, anillo: Dictionary, casas: Array[Node3D], torre: Node3D, obrador: Node3D,
		evitar: Array[Vector3]) -> Node3D:
	if not ACTIVO or "sin_atrezo" in OS.get_cmdline_user_args():      # `-- sin_atrezo`: para medir el pueblo sin él
		return null
	if not ResourceLoader.exists(CARPETA + "sh_barril.glb"):
		push_warning("Atrezo de Sumicio: faltan los objetos de %s (genéralos con tools/exportar_atrezo_sh.py --hornear; ver arte/sh_assets/LEEME.md)" % CARPETA)
		return null
	var a := new()
	return a._sembrar(padre, mundo, anillo, casas, torre, obrador, evitar)


func _sembrar(padre: Node3D, mundo: Node, anillo: Dictionary, casas: Array[Node3D], torre: Node3D, obrador: Node3D,
		evitar: Array[Vector3]) -> Node3D:
	var t0 := Time.get_ticks_msec()
	_mundo = mundo
	_evitar = evitar
	_rng.seed = SEMILLA
	for i in range(1, 22):
		_cantaros.append("cantaro_%02d" % i)
	_raiz = Node3D.new()
	_raiz.name = "AtrezoSH"
	padre.add_child(_raiz)
	var edificios: Array = casas.duplicate()
	edificios.append_array([torre, obrador])
	for e: Node3D in edificios:
		if e != null:
			var frente := e.global_basis.z
			var r_e := 3.9 if e == torre else _radio_planta(e, 3.5)
			_puertas.append([e.global_position, atan2(frente.x, frente.z), r_e + 2.4])
			_edificios.append(Vector3(e.global_position.x, r_e * 0.8, e.global_position.z))
	for i in range(casas.size()):
		var casa := casas[i]
		var r := _radio_planta(casa, 3.0)
		match String(casa.name):
			"TiendaEste":
				_tienda(casa, r)
			"Gremio":
				_gremio(casa, r)
			_:
				_palloza(casa, r)
	if torre != null:
		_torre(torre)
	if obrador != null:
		_obrador(obrador, _radio_planta(obrador, 3.5))
	if not anillo.is_empty():
		_valla(anillo)
		_rincones(anillo)
	print("Atrezo de Sumicio: %d objetos (%d con choque) en %d ms (leer modelos %d ms, choques %d ms)" % [_cuenta, _solidos,
		Time.get_ticks_msec() - t0, _us_carga / 1000, _us_choque / 1000])
	return _raiz


# ---------- Escenas por edificio ----------

## Punto al pie del edificio en el ángulo `a` (respecto a su puerta, + a la derecha mirando desde fuera), a `d` del muro.
func _al_pie(casa: Node3D, radio: float, a: float, d: float) -> Vector3:
	var frente := casa.global_basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var ang := atan2(frente.x, frente.z) + a
	return casa.global_position + Vector3(sin(ang), 0.0, cos(ang)) * (radio + d)


## Giro para que un objeto apoyado en el muro mire hacia fuera (con algo de desorden).
func _giro_hacia_fuera(casa: Node3D, p: Vector3) -> float:
	var fuera := p - casa.global_position
	return atan2(fuera.x, fuera.z) + _rng.randf_range(-0.35, 0.35)


func _palloza(casa: Node3D, r: float) -> void:
	var lado := 1.0 if _rng.randf() < 0.5 else -1.0
	# Rincón de cerámica: una tinaja grande con cántaros alrededor y, a veces, flores.
	var p := _al_pie(casa, r, lado * deg_to_rad(_rng.randf_range(58.0, 80.0)), _rng.randf_range(-0.05, 0.25))
	_rincon_ceramica(p, casa, _rng.randf() < 0.5)
	# Rincón de trabajo: leña, o barril y caja.
	var q := _al_pie(casa, r, -lado * deg_to_rad(_rng.randf_range(62.0, 95.0)), _rng.randf_range(0.0, 0.3))
	match _rng.randi() % 3:
		0:
			_poner("troncos", q, _giro_hacia_fuera(casa, q) + PI * 0.5)
		1:
			_poner("barril" if _rng.randf() < 0.6 else "barril_bajo", q, _rng.randf() * TAU)
			_poner("caja_cerrada", q + _tangente(casa, q) * 0.75, _giro_hacia_fuera(casa, q))
		_:
			_poner("cajon_abierto", q, _giro_hacia_fuera(casa, q) + PI * 0.5)
			_cantaros_junto(q + _tangente(casa, q) * 0.7, 2)
	# Tercer rincón, más hacia atrás (se ve asomar por el lado): caja y cántaros, o una tinaja.
	if _rng.randf() < TERCER_RINCON:
		var s := _al_pie(casa, r, lado * deg_to_rad(_rng.randf_range(112.0, 140.0)), _rng.randf_range(0.0, 0.25))
		if _rng.randf() < 0.5:
			_poner("caja_cerrada", s, _giro_hacia_fuera(casa, s))
			_cantaros_junto(s, 2)
		else:
			_poner(CERAMICA_GRANDE[_rng.randi() % CERAMICA_GRANDE.size()], s, _rng.randf() * TAU)


func _tienda(casa: Node3D, r: float) -> void:
	for lado: float in [-1.0, 1.0]:
		var p := _al_pie(casa, r, lado * deg_to_rad(60.0), 0.1)
		_poner("caja_cerrada", p, _giro_hacia_fuera(casa, p))
		_poner("caja_abierta", p + _tangente(casa, p) * lado * 0.95, _giro_hacia_fuera(casa, p))
		var q := _al_pie(casa, r, lado * deg_to_rad(88.0), 0.15)
		_poner("barril", q, _rng.randf() * TAU)
		_poner("barril_bajo", q + _tangente(casa, q) * lado * 0.7, _rng.randf() * TAU)
		var s := _al_pie(casa, r, lado * deg_to_rad(112.0), 0.1)
		_poner("arcon" if lado < 0.0 else "cajon_abierto", s, _giro_hacia_fuera(casa, s) + PI * 0.5)
		_rincon_ceramica(_al_pie(casa, r, lado * deg_to_rad(48.0), 0.85), casa, false)
	var c := _al_pie(casa, r, deg_to_rad(50.0), 0.45)
	_poner("cartel", c, _giro_hacia_fuera(casa, c))


func _gremio(casa: Node3D, r: float) -> void:
	var p := _al_pie(casa, r, deg_to_rad(-70.0), 0.15)
	_poner("barril", p, _rng.randf() * TAU)
	_poner("barril", p + _tangente(casa, p) * -0.7, _rng.randf() * TAU)
	_poner("caja_cerrada", p + _tangente(casa, p) * 0.75, _giro_hacia_fuera(casa, p))
	var q := _al_pie(casa, r, deg_to_rad(80.0), 0.1)
	_poner("troncos", q, _giro_hacia_fuera(casa, q) + PI * 0.5)


func _obrador(obr: Node3D, r: float) -> void:
	var p := _al_pie(obr, r, deg_to_rad(-75.0), 0.2)
	_poner("troncos", p, _giro_hacia_fuera(obr, p) + PI * 0.5)
	_poner("troncos", p + _tangente(obr, p) * -1.1, _giro_hacia_fuera(obr, p) + PI * 0.5 + 0.3)
	var q := _al_pie(obr, r, deg_to_rad(70.0), 0.2)
	_poner("caja_abierta", q, _giro_hacia_fuera(obr, q))
	_poner("cajon_abierto", q + _tangente(obr, q) * 0.9, _giro_hacia_fuera(obr, q) + PI * 0.5)
	for k in range(3):
		var s := _al_pie(obr, r, deg_to_rad(_rng.randf_range(95.0, 130.0)), _rng.randf_range(0.2, 0.8))
		_poner("piedra_rota_%d" % (1 + _rng.randi() % 4), s, _rng.randf() * TAU)


func _torre(torre: Node3D) -> void:
	const R := 3.9
	for lado: float in [-1.0, 1.0]:
		var p := _al_pie(torre, R, lado * deg_to_rad(52.0), 0.1)
		_poner(CERAMICA_GRANDE[_rng.randi() % CERAMICA_GRANDE.size()], p, _rng.randf() * TAU)
		_poner(FLORES[_rng.randi() % FLORES.size()], p + _tangente(torre, p) * lado * 0.6, _rng.randf() * TAU)
		_poner(FLORES[_rng.randi() % FLORES.size()], p + _tangente(torre, p) * lado * 1.0 + (p - torre.global_position).normalized() * 0.3,
			_rng.randf() * TAU)


## Tinaja grande, 2-4 cántaros alrededor y, si `flores`, una o dos flores.
func _rincon_ceramica(p: Vector3, casa: Node3D, flores: bool) -> void:
	_poner(CERAMICA_GRANDE[_rng.randi() % CERAMICA_GRANDE.size()], p, _rng.randf() * TAU)
	_cantaros_junto(p, 2 + _rng.randi() % 3)
	if flores:
		for k in range(1 + _rng.randi() % 2):
			var f := p + _tangente(casa, p) * _rng.randf_range(-0.9, 0.9) + (p - casa.global_position).normalized() * _rng.randf_range(0.2, 0.5)
			_poner(FLORES[_rng.randi() % FLORES.size()], f, _rng.randf() * TAU)


func _cantaros_junto(p: Vector3, n: int) -> void:
	for k in range(n):
		var a := _rng.randf() * TAU
		_poner(_cantaros[_rng.randi() % _cantaros.size()], p + Vector3(sin(a), 0.0, cos(a)) * _rng.randf_range(0.35, 0.6), _rng.randf() * TAU)


## A lo largo del muro (perpendicular al radio), para poner cosas una al lado de otra.
func _tangente(casa: Node3D, p: Vector3) -> Vector3:
	var fuera := p - casa.global_position
	fuera.y = 0.0
	return Vector3(-fuera.z, 0.0, fuera.x).normalized()


# ---------- La valla ----------

func _valla(an: Dictionary) -> void:
	var c3: Vector3 = an["centro"]
	var radio: float = an["radio"]
	var ang0: float = float(an["puerta"]) + float(an["medio_hueco"])
	var arco: float = TAU - 2.0 * float(an["medio_hueco"])
	var n := int(ceil(arco * radio / 1.15))
	var paso := arco / float(n)
	for i in range(VALLA_CANCELA_LIBRE, n - VALLA_CANCELA_LIBRE):
		if _rng.randf() >= VALLA_PROB:
			continue
		var a := ang0 + paso * (float(i) + 0.5)
		var fuera := Vector3(sin(a), 0.0, -cos(a))
		var tan := Vector3(cos(a), 0.0, sin(a))
		var p := c3 + fuera * (radio - 0.55)
		var giro := atan2(tan.x, tan.z)
		if _rng.randf() < 0.55:
			_poner("troncos", p, giro + _rng.randf_range(-0.15, 0.15))
		else:
			_poner("caja_cerrada", p, giro + _rng.randf_range(-0.3, 0.3))
			_poner("barril" if _rng.randf() < 0.5 else "barril_bajo", p + tan * 0.75 - fuera * 0.1, _rng.randf() * TAU)


# ---------- Rincones sueltos ----------

## RINCONES grupitos en la hierba de dentro del castro, lejos de la valla (ya tiene lo suyo) y de los edificios.
func _rincones(an: Dictionary) -> void:
	var c3: Vector3 = an["centro"]
	var radio: float = float(an["radio"]) - 2.2
	var hechos := 0
	var intentos := 0
	while hechos < RINCONES and intentos < RINCONES * 30:
		intentos += 1
		var a := _rng.randf() * TAU
		var p := c3 + Vector3(sin(a), 0.0, cos(a)) * sqrt(_rng.randf()) * radio
		if not _libre(p, 1.8):
			continue
		hechos += 1
		var giro := _rng.randf() * TAU
		var al_lado := Vector3(cos(giro), 0.0, -sin(giro))
		match _rng.randi() % 5:
			0:
				_poner("barril", p, _rng.randf() * TAU)
				_poner("caja_cerrada", p + al_lado * 0.75, giro)
			1:
				_poner(CERAMICA_GRANDE[_rng.randi() % CERAMICA_GRANDE.size()], p, _rng.randf() * TAU)
				_poner(CERAMICA_GRANDE[_rng.randi() % CERAMICA_GRANDE.size()], p + al_lado * 0.55, _rng.randf() * TAU)
				_cantaros_junto(p, 2)
			2:
				_poner("troncos", p, giro)
			3:
				_poner("cajon_abierto", p, giro)
				for k in range(2):
					_poner(FLORES[_rng.randi() % FLORES.size()], p + al_lado * _rng.randf_range(-0.4, 0.4) + Vector3(0, 0, 0.45), _rng.randf() * TAU)
			_:
				for k in range(2 + _rng.randi() % 2):
					_poner("piedra_rota_%d" % (1 + _rng.randi() % 4), p + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6)), _rng.randf() * TAU)


# ---------- Poner un objeto ----------

## Un objeto del pack en `p` (apoyado en el suelo), girado `giro`. Se salta si el sitio no vale (camino, puerta, personaje, otro objeto).
func _poner(nombre: String, p: Vector3, giro: float) -> void:
	var escena := _escena(nombre)
	if escena == null:
		return
	var cat := _categoria(nombre)
	var esc: float = float(ESCALA.get(cat, 0.42))
	var huella := _huella(nombre) * esc
	if not _libre(p, huella):
		return
	var pivote := Node3D.new()
	pivote.name = nombre
	_raiz.add_child(pivote)
	pivote.global_position = Vector3(p.x, _suelo(p) - 0.02, p.z)
	pivote.rotation.y = giro
	var modelo := escena.instantiate() as Node3D
	modelo.scale = Vector3.ONE * esc * (1.0 if nombre in SOLIDOS else _rng.randf_range(0.9, 1.1))
	pivote.add_child(modelo)
	_convertir(modelo, cat)
	_puestos.append(Vector3(p.x, huella * 0.5, p.z))
	_cuenta += 1
	if nombre in SOLIDOS:
		_cuerpo(pivote, modelo, nombre)


## Choque: la caja de la malla (barriles, cajas, arcón y leña son macizos y casi cajas). Medirlo con ColisionPieza sobre sus 70-230 mil
## triángulos costaba ~2 s al cargar el nivel; y la leña y el cajón abierto, por bajos, se quedaban sin cuerpo. Lo bajo se sube al alto mínimo.
func _cuerpo(pivote: Node3D, modelo: Node3D, nombre: String) -> void:
	var t0 := Time.get_ticks_usec()
	if not _cascos.has(nombre):
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for mi in modelo.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var caja: AABB = (pivote.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
			lo = lo.min(caja.position)
			hi = hi.max(caja.end)
		lo.y = 0.0
		hi.y = maxf(hi.y, ColisionPieza.ALTO_MIN_SOLIDO + 0.1)
		_cascos[nombre] = [PackedVector3Array([Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z), Vector3(lo.x, 0, hi.z), Vector3(hi.x, 0, hi.z),
			Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z)])]
	var lista: Array = _cascos[nombre]
	_us_choque += Time.get_ticks_usec() - t0
	if lista.is_empty():
		return
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Solido"
	cuerpo.collision_layer = Terreno3D.CAPA_SOLIDO
	cuerpo.collision_mask = 0
	cuerpo.add_to_group("bloquea")
	for nube in lista:
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		sh.points = nube
		cs.shape = sh
		cuerpo.add_child(cs)
	pivote.add_child(cuerpo)
	_solidos += 1


func _libre(p: Vector3, huella: float) -> bool:
	var c := Terreno3D.celda_de(p)
	if Terreno3D.es_vacio(c) or Terreno3D.es_agua(c) or _tipo(c) != 0:
		return false
	# que no invada el empedrado ni el camino por un lado
	var m := huella * 0.5
	for d: Vector3 in [Vector3(m, 0, 0), Vector3(-m, 0, 0), Vector3(0, 0, m), Vector3(0, 0, -m)]:
		var cc := Terreno3D.celda_de(p + d)
		if Terreno3D.es_vacio(cc) or _tipo(cc) != 0:
			return false
	for e in _evitar:
		if Vector2(p.x - e.x, p.z - e.z).length() < LIBRE_PERSONAJE:
			return false
	for ed in _edificios:
		if Vector2(p.x - ed.x, p.z - ed.z).length() < ed.y + m * 0.5:
			return false
	for pu in _puertas:
		var v: Vector3 = p - (pu[0] as Vector3)
		if Vector2(v.x, v.z).length() < float(pu[2]) and absf(angle_difference(atan2(v.x, v.z), float(pu[1]))) < PUERTA_LIBRE:
			return false
	for o in _puestos:
		if Vector2(p.x - o.x, p.z - o.z).length() < (o.y + m) * 0.85:
			return false
	return true


## Lado mayor de la planta del objeto en metros del pack (de atrezo_sh.json).
func _huella(nombre: String) -> float:
	var d: Dictionary = _datos().get(nombre, {})
	return maxf(float(d.get("x", 0.5)), float(d.get("y", 0.5)))


func _categoria(nombre: String) -> String:
	return String((_datos().get(nombre, {}) as Dictionary).get("categoria", "ceramica"))


var _datos_cache: Dictionary = {}


func _datos() -> Dictionary:
	if _datos_cache.is_empty():
		var f := FileAccess.open(CARPETA + "atrezo_sh.json", FileAccess.READ)
		if f != null:
			for d in JSON.parse_string(f.get_as_text()):
				_datos_cache[d["nombre"]] = d
	return _datos_cache


func _escena(nombre: String) -> PackedScene:
	if not _escenas.has(nombre):
		var t0 := Time.get_ticks_usec()
		var ruta := CARPETA + "sh_%s.glb" % nombre
		_escenas[nombre] = load(ruta) as PackedScene if ResourceLoader.exists(ruta) else null
		_us_carga += Time.get_ticks_usec() - t0
	return _escenas[nombre]


## Material del juego (Ocluso3D: rampa de luz y círculo de transparencia), uno por material del glb y compartido.
func _convertir(raiz: Node, cat: String) -> void:
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in range(m.mesh.get_surface_count()):
			var orig := m.mesh.surface_get_material(s)
			if orig == null:
				continue
			if not _mats.has(orig):
				var conv: Material = Ocluso3D.convertir(orig)
				if TINTE.has(cat):
					var t: Color = TINTE[cat]
					if conv is ShaderMaterial:
						var c: Color = (conv as ShaderMaterial).get_shader_parameter("color")
						(conv as ShaderMaterial).set_shader_parameter("color", c * t)
					elif conv is StandardMaterial3D:
						conv = conv.duplicate()
						(conv as StandardMaterial3D).albedo_color *= t
				_mats[orig] = conv
			m.set_surface_override_material(s, _mats[orig])


func _tipo(c: Vector2i) -> int:
	return int(_mundo.call("_tipo_suelo", c)) if _mundo.has_method("_tipo_suelo") else 0


func _suelo(p: Vector3) -> float:
	return Terreno3D.y_pies(Terreno3D.celda_de(p)) + Terreno3D.realce_en(p)


## Radio de la planta del edificio visto desde arriba (copiado de la vegetación): el alero, con tope.
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
