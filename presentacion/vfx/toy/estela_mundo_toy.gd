extends Node3D

## ESTELA QUE SE QUEDA EN EL MUNDO (25/11/2026, comparativa con ef_fire01_projectile de Effekseer, aprobado por Pablo para fuego, agua y tierra).
## La técnica de Effekseer: la bola no arrastra su cola; cada instante SUELTA una bocanada que se queda donde nació (en el mundo), vive muy poco, encoge y se enfría. La cola sale sola:
## larga, irregular, más fina y más «vieja» cuanto más lejos de la cabeza, y deja leer el recorrido. Más unas pocas motas que se desprenden en curva.
## Con nuestras piezas y la paleta de cada elemento:
##   · fuego  → bocanadas del flipbook de la bola (SpriteToy, parte ROJA de la rampa) que encogen y se enfrían + brasas que se desprenden (chispa_impacto)
##   · agua   → vaho de espuma (humo toon con los colores del agua) que encoge + gotas que caen (AguaGotas)
##   · tierra → polvo pardo (humo toon de TierraToy) que se queda y se abre + granitos que caen (piedra pequeña de TierraToy)
## Va SUELTA en la escena (hermana de la bola, top_level, transformación identidad): sigue a `objetivo` mientras exista y vuele; luego deja de soltar, se apaga sola y se libera.
## La crea EfectoToy cuando la bola vuela y `activa` está encendida (el lab la alterna con Ctrl+8). Sin class_name: preload("res://presentacion/vfx/toy/estela_mundo_toy.gd").

const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")
const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")
const AguaGotas = preload("res://presentacion/vfx/toy/agua_gotas.gd")
const AguaPaleta = preload("res://presentacion/vfx/toy/agua_paleta.gd")
const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const RADIO_REF: float = 0.4
const GRAVEDAD: float = 9.8

## Interruptor global (lo de serie del juego; el lab lo alterna para comparar).
static var activa: bool = false

## Receta por elemento (tamaños en m para una bola de RADIO_REF). Escalan con K_TAM(radio): la raíz de radio / RADIO_REF, con suelo 0,6 (la bola del juego mide 0,12 m de radio y
## a escala lineal la estela quedaba de pocos centímetros, invisible con la cámara del juego; en Effekseer la estela es más ancha que la bola).
##   paso: m recorridos entre bocanada y bocanada · vida: s de cada bocanada · tam: [al nacer, al morir] (diámetro) · deriva: m/s (subir el humo, caer el polvo)
##   motas: cuántas motas por bocanada (probabilidad si < 1) · vida_mota · vel_mota (m/s, hacia fuera) · g_mota (× gravedad)
const RECETAS: Dictionary = {
	"fuego": {"paso": 0.055, "vida": [0.12, 0.3], "tam": [0.4, 0.06], "deriva": 0.35, "disperso": 0.035, "abre": 0.55, "n": 64,
		"motas": 0.45, "n_motas": 40, "vida_mota": [0.3, 0.6], "vel_mota": [0.5, 1.4], "g_mota": -0.08},
	"agua": {"paso": 0.1, "vida": [0.25, 0.45], "tam": [0.55, 0.15], "deriva": 0.1, "disperso": 0.07, "n": 40,
		"motas": 0.9, "n_motas": 44, "vida_mota": [0.3, 0.55], "vel_mota": [0.4, 1.2], "g_mota": 0.9},
	"tierra": {"paso": 0.12, "vida": [0.35, 0.6], "tam": [0.3, 0.75], "deriva": 0.12, "disperso": 0.06, "n": 40,
		"motas": 0.6, "n_motas": 30, "vida_mota": [0.35, 0.6], "vel_mota": [0.3, 1.0], "g_mota": 1.0},
}

var objetivo: Node3D = null
var elemento: String = "fuego"
var radio: float = RADIO_REF

var _r: Dictionary = {}
var _k: float = 1.0
var _t: float = 0.0
var _ult: Vector3 = Vector3.ZERO
var _hay_ult: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sprites: Array = []          ## fuego: [{mi, t0, vida, pos, giro, tam_k}] (reserva circular)
var _sig: int = 0
var _humo: Node3D = null          ## agua y tierra
var _mm: MultiMeshInstance3D = null
var _motas: Array = []            ## [{p0, v0, t0, vida, g, tono, ancho, eje, rot0}]
var _sig_m: int = 0
var _sueltas: int = 0             ## bocanadas soltadas (para las pruebas)


static func crear(objetivo_: Node3D, elemento_: String, radio_: float) -> Node3D:
	var e: Node3D = (load("res://presentacion/vfx/toy/estela_mundo_toy.gd") as GDScript).new()
	e.objetivo = objetivo_
	e.elemento = elemento_ if RECETAS.has(elemento_) else "fuego"
	e.radio = maxf(radio_, 0.05)
	e.name = "EstelaMundo_" + e.elemento
	return e


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_rng.randomize()
	_r = RECETAS[elemento]
	_k = clampf(sqrt(radio / RADIO_REF), 0.6, 2.0)
	match elemento:
		"fuego":
			FuegoToy._rampas()
			for i in int(_r["n"]):
				var s: MeshInstance3D = SpriteToy.crear("Bocanada", SpriteToy.T_FLIPBOOK, SpriteToy.Modo.MEZCLA_SIN_PROF, false,
					{"usar_alfa": 1.0, "fb_cols": 5, "fb_filas": 5, "fotograma": 0.0, "fotograma_max": float(SpriteToy.FOTOGRAMAS_FUEGO - 1), "luminancia": Vector2(0.12, 0.95),
					"tramo": Vector2(0.02, 0.68), "recorte": Vector2(0.28, 0.6), "brillo": 1.0, "giro": 0.0, "vida": 0.0}, 0)
				SpriteToy.mat(s).set_shader_parameter("rampa", FuegoToy._rampa_bola)
				s.visible = false
				add_child(s)
				_sprites.append({"mi": s, "t0": -10.0, "vida": 0.2, "pos": Vector3.ZERO, "giro": 0.0, "tam_k": 1.0, "lat": Vector3.ZERO, "fase": 0.0})
			_mm = SpriteToy.chispas_mm("Brasas", int(_r["n_motas"]), 1.6)
			(_mm.material_override as ShaderMaterial).set_shader_parameter("rampa", FuegoToy._rampa_bola)
		"agua":
			_humo = HumoToy.new()
			_humo.name = "Vaho"
			add_child(_humo)
			_humo.call("montar", int(_r["n"]), {"claro": AguaPaleta.ESPUMA, "sombra": AguaPaleta.CAUSTICAS, "viejo": AguaPaleta.SOMERO, "tam_ini": float(_r["tam"][0]) * _k,
				"tam_fin": float(_r["tam"][1]) * _k, "vida": float(_r["vida"][1]), "deriva": Vector3(0, float(_r["deriva"]), 0), "mundo": true, "friccion": 3.0, "erosion": 0.9})
			_mm = AguaGotas.crear_mm("Gotas", int(_r["n_motas"]))
		"tierra":
			_humo = HumoToy.new()
			_humo.name = "Polvo"
			add_child(_humo)
			var q: Dictionary = TierraToy.polvo_params(float(_r["tam"][0]) * _k, float(_r["tam"][1]) * _k, float(_r["vida"][1]), Vector3(0, float(_r["deriva"]), 0), true)
			q["friccion"] = 3.0
			_humo.call("montar", int(_r["n"]), q)
			_mm = TierraToy.crear_mm("Granitos", int(_r["n_motas"]), TierraToy.Piedras.malla_piedra(), 0.2)
	add_child(_mm)
	_mm.top_level = true
	_mm.global_transform = Transform3D.IDENTITY
	for i in int(_r["n_motas"]):
		_motas.append({"t0": -10.0, "vida": 0.1, "p0": Vector3.ZERO, "v0": Vector3.ZERO, "g": 0.0, "tono": 0.0, "ancho": 0.0,
			"eje": Vector3.UP, "rot0": Basis.IDENTITY})
	_ocultar_motas()
	# Los MultiMesh (gotas, granitos, el humo toon) calculan su caja de visibilidad alrededor del ORIGEN; con la estela en el mundo las instancias están a decenas de metros y Godot
	# las descartaba (en el juego no se veía nada; en el lab, junto al origen, sí). Caja que cubre todo el mapa.
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).custom_aabb = AABB(Vector3(-2000, -500, -2000), Vector3(4000, 1000, 4000))


## ¿Sigue soltando? Mientras el objetivo exista, esté en el árbol y vuele.
func emitiendo() -> bool:
	return objetivo != null and is_instance_valid(objetivo) and objetivo.is_inside_tree() and bool(objetivo.get("proyectil"))


func soltadas() -> int:
	return _sueltas


func _process(delta: float) -> void:
	_t += delta
	if emitiendo():
		var p: Vector3 = objetivo.global_position
		if not _hay_ult:
			_ult = p
			_hay_ult = true
		var paso: float = float(_r["paso"]) * _k
		var d: float = _ult.distance_to(p)
		var n: int = 0
		while d >= paso and n < 6:                # una bocanada cada `paso` m (si la bola va muy rápido, como mucho 6 por fotograma)
			_ult = _ult.move_toward(p, paso)
			d -= paso
			_soltar(_ult, (p - _ult).normalized() if p.distance_to(_ult) > 0.001 else Vector3.ZERO)
			n += 1
	elif _vivo_hasta() < _t:
		queue_free()
		return
	_animar()


## Último instante en que algo de la estela sigue vivo.
func _vivo_hasta() -> float:
	var f: float = 0.0
	for s in _sprites:
		f = maxf(f, float(s["t0"]) + float(s["vida"]))
	for m in _motas:
		f = maxf(f, float(m["t0"]) + float(m["vida"]))
	if _humo != null:
		f = maxf(f, _t + (0.05 if int(_humo.call("vivas")) > 0 else -1.0))
	return f


func _rango(v: Array) -> float:
	return _rng.randf_range(float(v[0]), float(v[1]))


func _soltar(pos: Vector3, _dir: Vector3) -> void:
	_sueltas += 1
	var off: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * float(_r["disperso"]) * _k
	var vida: float = _rango(_r["vida"])
	match elemento:
		"fuego":
			var s: Dictionary = _sprites[_sig]
			_sig = (_sig + 1) % _sprites.size()
			s["t0"] = _t
			s["vida"] = vida
			s["pos"] = pos + off
			s["giro"] = _rng.randf() * TAU
			s["tam_k"] = _rng.randf_range(0.8, 1.2)
			# 25/11 (Pablo: «la cola no es realista»): cada bocanada se aparta un poco hacia un lado al azar (y algo hacia arriba), así la cola se ABRE y ondula según se queda atrás
			# en vez de ser un palo recto; `fase` le da un vaivén propio.
			s["lat"] = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 1.0), _rng.randf_range(-1, 1)).normalized() * float(_r.get("abre", 0.0)) * _rng.randf_range(0.4, 1.0)
			s["fase"] = _rng.randf() * TAU
		_:
			var lado: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 0.6), _rng.randf_range(-1, 1)).normalized()
			_humo.call("emitir", pos + off, lado * 0.25 * _k, vida / float(_r["vida"][1]), _rng.randf_range(0.8, 1.2))
	# motas que se desprenden hacia fuera
	var pm: float = float(_r["motas"])
	var cuantas: int = int(pm) + (1 if _rng.randf() < pm - floorf(pm) else 0)
	for j in cuantas:
		var m: Dictionary = _motas[_sig_m]
		_sig_m = (_sig_m + 1) % _motas.size()
		var dir: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.2, 1.0), _rng.randf_range(-1, 1)).normalized()
		m["t0"] = _t
		m["vida"] = _rango(_r["vida_mota"])
		m["p0"] = pos + off * 0.5
		m["v0"] = dir * _rango(_r["vel_mota"]) * sqrt(_k)
		m["g"] = float(_r["g_mota"]) * GRAVEDAD
		m["tono"] = _rng.randf()
		m["ancho"] = (_rng.randf_range(0.025, 0.045) if elemento != "tierra" else _rng.randf_range(0.012, 0.026)) * pow(_k, 0.5)
		m["eje"] = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
		m["rot0"] = Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))


func _animar() -> void:
	for s in _sprites:
		var mi: MeshInstance3D = s["mi"]
		var ta: float = _t - float(s["t0"])
		var u: float = ta / float(s["vida"])
		if u < 0.0 or u >= 1.0:
			mi.visible = false
			continue
		mi.visible = true
		var tam: Array = _r["tam"]
		var sz: float = lerpf(float(tam[0]), float(tam[1]), 1.0 - pow(1.0 - u, 1.6)) * _k * float(s["tam_k"])
		mi.scale = Vector3(sz, sz, 1.0)
		var vaiven: Vector3 = Vector3(sin(ta * 17.0 + float(s["fase"])), 0.0, cos(ta * 13.0 + float(s["fase"]))) * 0.03 * _k * u
		mi.global_position = (s["pos"] as Vector3) + Vector3(0, float(_r["deriva"]) * ta * _k, 0) + (s["lat"] as Vector3) * ta * _k + vaiven
		var m: ShaderMaterial = SpriteToy.mat(mi)
		m.set_shader_parameter("vida", smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.55, 1.0, u)))
		m.set_shader_parameter("calor", lerpf(0.04, -0.22, pow(u, 0.7)))       # se enfría deprisa: del naranja de la cabeza al rojo (25/11: más contraste)
		m.set_shader_parameter("giro", float(s["giro"]) + ta * 2.0)
		m.set_shader_parameter("fotograma", clampf(u * float(SpriteToy.FOTOGRAMAS_FUEGO), 0.0, float(SpriteToy.FOTOGRAMAS_FUEGO) - 1.001))
	var mm: MultiMesh = _mm.multimesh
	for i in _motas.size():
		var p: Dictionary = _motas[i]
		var ta2: float = _t - float(p["t0"])
		var u2: float = ta2 / float(p["vida"])
		if u2 < 0.0 or u2 >= 1.0:
			_ocultar_mota(mm, i)
			continue
		var v0: Vector3 = p["v0"]
		var roce: float = 2.5
		var fr: float = (1.0 - exp(-roce * ta2)) / roce
		var pos: Vector3 = (p["p0"] as Vector3) + v0 * fr + Vector3(0, -0.5 * float(p["g"]) * ta2 * ta2, 0)
		var vel: Vector3 = v0 * exp(-roce * ta2) + Vector3(0, -float(p["g"]) * ta2, 0)
		var alfa: float = smoothstep(0.0, 0.08, u2) * (1.0 - smoothstep(0.6, 1.0, u2))
		match elemento:
			"fuego":
				SpriteToy.poner_chispa(mm, i, pos, vel.normalized() if vel.length() > 0.01 else Vector3.UP, 0.0, float(p["ancho"]) * (1.0 - 0.5 * u2), 0.32 - 0.25 * u2, alfa, true)      # brasas naranja-rojo, nunca amarillo pálido
			"agua":
				AguaGotas.poner(mm, i, pos, vel.normalized() if vel.length() > 0.01 else Vector3.DOWN, float(p["ancho"]) * 2.2, float(p["ancho"]), float(p["tono"]), alfa, false)
			"tierra":
				var rot: Basis = (Basis(p["eje"], 14.0 * ta2) * (p["rot0"] as Basis)).orthonormalized()
				var esc: float = float(p["ancho"]) * (1.0 - smoothstep(0.75, 1.0, u2)) * 2.0 / TierraToy.lado_malla(mm.mesh)
				mm.set_instance_transform(i, TierraToy.centrar(mm.mesh, rot * Basis.from_scale(Vector3.ONE * esc), pos))
				mm.set_instance_custom_data(i, Color(float(p["tono"]), 1.0, 0.0, 0.0))


func _ocultar_motas() -> void:
	for i in _motas.size():
		_ocultar_mota(_mm.multimesh, i)


func _ocultar_mota(mm: MultiMesh, i: int) -> void:
	match elemento:
		"fuego":
			SpriteToy.poner_chispa(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, false)
		"agua":
			AguaGotas.poner(mm, i, Vector3.ZERO, Vector3.DOWN, 0.0, 0.0, 0.0, 0.0, false)
		_:
			HieloMallas.ocultar(mm, i)
