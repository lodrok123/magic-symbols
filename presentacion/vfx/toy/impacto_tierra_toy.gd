class_name ImpactoTierraToy
extends Node3D

## IMPACTO DE LA TIERRA «TOY» (6/11/2026; el equivalente de ImpactoHieloToy). Misma API: `crear(variante, normal, radio)`, `tiempo()`, `duracion()`, `avanzar_a(t)`, `lanzar()` / `morir()`.
## Es TIERRA: PIEDRECITAS (MultiMesh de piedra_est_1, la piedra pequeña del mapa, con tierra_roca.gdshader: textura gris de las rocas + luz de la escena) que salen del punto HACIA FUERA en el
## hemisferio de la normal, giran y CAEN con la gravedad real (fórmula cerrada,
## `piedras_estado(t)` las mide), se quedan en la superficie o en el suelo del mundo y se hunden al final; y una NUBE DE POLVO pardo de dos tonos (humo toon, humo_toy.gd) a ras de la
## superficie que se abre en radial y se erosiona. SIN destello, sin luz, sin aditivos, sin GPUParticles3D. Todo se libera solo.
## Variantes: GOLPE (todo), FIN (se agota en el aire: terrones que caen y un poco de polvo), REBOTE (pequeño), AREA (zona: polvo ancho y muchas piedrecitas; la normal siempre es arriba).
## TAMAÑO: `radio` = radio de la roca que choca (m; referencia 0,4; el AREA, 1,8).
## 3.ª versión (6/11 noche, referencias tierra_pack LEEME §2-3, solo la secuencia, estilo toon):
##   GOLPE: un ANILLO de tierra que se abre en la superficie (quad `Anillo`, tierra_anillo.gdshader: disco facetado, borde claro, interior oscuro agrietado; crece 0 → 1 en T_ANILLO_ABRE s
##   y se desvanece en T_ANILLO_VA s) con N_PUAS púas pequeñas (`Puas`, malla pua_1 de TierraToy, color plano) que ASOMAN en el centro y se RETIRAN; pocos cascotes; polvo pardo.
##   AREA: NUBE de polvo pardo de dos tonos con el CENTRO MÁS CLARO (`Polvo` + `PolvoCentro`: bocanadas más grandes y claras) y cascotes facetados oscuros que salen en ESPIRAL baja y caen.

const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")
const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const SH_ANILLO: String = "res://presentacion/vfx/toy/tierra_anillo.gdshader"
const TEX_MARCA: String = "res://assets/vfx/lelu_noise/T_Groundmark19.png"   ## marca de suelo (grietas negras sobre blanco) del pack de LeLu: su readme deja usarla sin credito
const MARCA_PESO: float = 0.55                       ## cuanto pinta la marca de suelo sobre el interior del anillo (0 = solo las grietas de codigo)
@export var color_marca: Color = Color(0.26, 0.16, 0.09)        ## color de la marca de suelo del anillo: el pardo de la tierra del Bosque (el suelo ronda 0,62·0,40·0,22) (el magma la pone carmesí)
@export var color_emision_marca: Color = Color(0.0, 0.0, 0.0)   ## lo que ARDE esa marca (0 en tierra; el magma la enciende)
@export var emision_marca: float = 0.0
const ALTO_DECAL: float = 1.6                         ## m de alto de la caja del decal: lo que puede subir o bajar el suelo dentro de la marca
var _marca: MeshInstance3D = null                     ## la marca de suelo, como decal pegado al relieve

enum Variante { GOLPE, FIN, REBOTE, AREA }

const PARAMS: Dictionary = {
	Variante.GOLPE: {"piedras": 12, "polvo": 10, "dur": 1.3, "anillo": true, "centro": 0},
	Variante.FIN: {"piedras": 18, "polvo": 5, "dur": 1.1, "anillo": false, "centro": 0},
	Variante.REBOTE: {"piedras": 10, "polvo": 6, "dur": 0.9, "anillo": false, "centro": 0},
	Variante.AREA: {"piedras": 30, "polvo": 20, "dur": 1.8, "anillo": false, "centro": 8}}
const COS_SUELO: float = 0.7
const GRAVEDAD: float = 9.8
const N_PUAS: int = 3
const T_ANILLO_ABRE: float = 0.15
const T_ANILLO_VA: float = 0.6                       ## se desvanece entre T_PUAS_FUERA y T_PUAS_FUERA + T_ANILLO_VA
const T_PUAS_ASOMAN: float = 0.05                    ## las púas empiezan a asomar
const T_PUAS_SUBEN: float = 0.16                     ## lo que tardan en salir
const T_PUAS_FUERA: float = 0.5                      ## cuándo empiezan a retirarse
const T_PUAS_RETIRAN: float = 0.3
## Polvo del CENTRO de la nube del área: más claro que el polvo de TierraToy (la nube más clara en el centro).
const CENTRO_CLARO: Color = Color(0.86, 0.72, 0.55)
const CENTRO_SOMBRA: Color = Color(0.70, 0.54, 0.37)
const CENTRO_VIEJO: Color = Color(0.60, 0.48, 0.36)

@export var variante: Variante = Variante.GOLPE
@export var normal: Vector3 = Vector3.UP
@export_range(0.05, 4.0, 0.01, "or_greater") var radio: float = 0.4
@export var altura_suelo: float = 0.7

var _t: float = -1.0
var _p: Dictionary = {}
var _dur: float = 0.8
var _plano: Node3D = null
var _mm: MultiMeshInstance3D = null
var _polvo: Node3D = null
var _pie: Array = []                       ## [{p0, v0, vida, tam, eje, vel_ang, rot0, tono}] en el espacio local del plano
var _fin_t: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _anillo: MeshInstance3D = null         ## GOLPE: el anillo que se abre en la superficie
var _puas_mm: MultiMeshInstance3D = null   ## GOLPE: púas pequeñas que asoman y se retiran
var _puas: Array = []                      ## [{pos, rot, w, h}] en el espacio local del plano
var _polvo_centro: Node3D = null           ## AREA: bocanadas claras del centro


static func crear(var_: Variante, normal_: Vector3, radio_: float) -> ImpactoTierraToy:
	var i: ImpactoTierraToy = ImpactoTierraToy.new()
	i.configurar(var_, normal_, radio_)
	return i


func configurar(var_: Variante, normal_: Vector3, radio_: float) -> void:
	variante = var_
	normal = Vector3.UP if var_ == Variante.FIN or var_ == Variante.AREA or normal_.length() < 0.001 else normal_.normalized()
	radio = maxf(radio_, 0.05)


func _ready() -> void:
	_p = PARAMS[variante]
	_dur = float(_p["dur"])
	_fin_t = _dur + 0.1
	_rng.randomize()
	_construir()


func lanzar(_v: float = -1.0) -> void:
	pass


func morir() -> void:
	queue_free()


func tiempo() -> float:
	return maxf(_t, 0.0)


func duracion() -> float:
	if not _p.is_empty():
		return _dur
	return float(PARAMS[variante]["dur"])


func es_suelo() -> bool:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	return variante != Variante.FIN and n.dot(Vector3.UP) >= COS_SUELO


func es_pared() -> bool:
	return variante != Variante.FIN and not es_suelo()


func _base_normal() -> Basis:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	if n.dot(Vector3.UP) < -0.999:
		return Basis(Quaternion(Vector3.RIGHT, PI))
	return Basis(Quaternion(Vector3.UP, n))


func _construir() -> void:
	var r: float = radio
	_plano = Node3D.new()
	_plano.name = "Plano"
	_plano.basis = _base_normal()
	add_child(_plano)
	var k: float = pow(r / 0.4, 0.7)
	var n_p: int = int(_p["piedras"])
	for i in n_p:
		var pos: Vector3
		var vel: Vector3
		if variante == Variante.FIN:
			var d: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
			pos = d * r * _rng.randf_range(0.2, 0.9)
			vel = d * _rng.randf_range(0.3, 1.2) + Vector3(0, 0.3, 0)
		else:
			var ang: float = _rng.randf() * TAU
			var alto: float = _rng.randf_range(0.25, 1.0)
			var lado: float = sqrt(1.0 - alto * alto)
			var dir: Vector3 = Vector3(cos(ang) * lado, alto, sin(ang) * lado)
			if variante == Variante.AREA:
				# espiral baja: salen de un anillo interior con velocidad sobre todo TANGENTE, algo radial y poco hacia arriba, y caen
				var rad: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
				var tang: Vector3 = Vector3(-sin(ang), 0.0, cos(ang))
				var k2: float = pow(r / 0.4, 0.4)                                           # el área es grande: la espiral se queda BAJA (menos que k)
				pos = rad * r * _rng.randf_range(0.2, 0.5) + Vector3(0, 0.05, 0)
				vel = (tang * _rng.randf_range(2.2, 3.8) + rad * _rng.randf_range(0.8, 2.0) + Vector3(0, _rng.randf_range(0.8, 1.8), 0)) * k2
			else:
				pos = Vector3(0, 0.03, 0)
				vel = dir * _rng.randf_range(1.6, 4.2) * k
		var tam_c: float = _rng.randf_range(0.03, 0.08) * pow(maxf(r / 0.4, 0.4), 0.35) if variante != Variante.FIN else _rng.randf_range(0.04, 0.11) * sqrt(maxf(r / 0.4, 0.4))      # cascotes pequeños (el FIN deshace la bola: como antes)
		_pie.append({"p0": pos, "v0": vel, "vida": _rng.randf_range(0.7, 1.2), "tam": tam_c,
			"eje": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(), "vel_ang": _rng.randf_range(4.0, 12.0),
			"rot0": Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)), "tono": _rng.randf()})
	_mm = TierraToy.crear_mm("Piedrecitas", n_p, TierraToy.Piedras.malla_piedra(), 0.2)
	_plano.add_child(_mm)
	# nube de polvo a ras de la superficie (local al plano: la deriva es a lo largo de la normal)
	var n_h: int = int(_p["polvo"])
	_polvo = HumoToy.new()
	_polvo.name = "Polvo"
	_plano.add_child(_polvo)
	var esc: float = sqrt(maxf(r / 0.4, 0.4)) if variante != Variante.AREA else 1.8
	_polvo.call("montar", n_h, TierraToy.polvo_params(0.3 * esc, 0.85 * esc, 0.95 if variante != Variante.AREA else 1.4, Vector3(0, 0.3, 0), false))
	for j in n_h:
		var a2: float = TAU * float(j) / float(n_h) + _rng.randf_range(-0.25, 0.25)
		var d2: Vector3 = Vector3(cos(a2), 0.0, sin(a2))
		if variante == Variante.FIN:
			var d3: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
			_polvo.call("emitir", d3 * r * 0.3, d3 * 0.8, 1.0, 0.8)
		elif variante == Variante.AREA:
			_polvo.call("emitir", d2 * r * _rng.randf_range(0.25, 0.7) + Vector3(0, 0.1, 0), d2 * _rng.randf_range(1.0, 2.0) * k + Vector3(0, 0.3, 0), _rng.randf_range(0.8, 1.2), _rng.randf_range(0.9, 1.4))
		else:
			_polvo.call("emitir", d2 * r * 0.2 + Vector3(0, 0.05 + 0.08 * r, 0), d2 * _rng.randf_range(1.4, 2.6) * k + Vector3(0, 0.2, 0), _rng.randf_range(0.8, 1.2), _rng.randf_range(0.8, 1.2))
	# AREA: el centro de la nube, más claro y más grande, sube despacio
	var n_c: int = int(_p["centro"])
	if n_c > 0:
		_polvo_centro = HumoToy.new()
		_polvo_centro.name = "PolvoCentro"
		_plano.add_child(_polvo_centro)
		var pc: Dictionary = TierraToy.polvo_params(0.5 * esc, 1.3 * esc, 1.5, Vector3(0, 0.45, 0), false)
		pc["claro"] = CENTRO_CLARO
		pc["sombra"] = CENTRO_SOMBRA
		pc["viejo"] = CENTRO_VIEJO
		pc["prioridad"] = 2
		_polvo_centro.call("montar", n_c, pc)
		for j in n_c:
			var a3: float = TAU * float(j) / float(n_c) + _rng.randf_range(-0.3, 0.3)
			var d3: Vector3 = Vector3(cos(a3), 0.0, sin(a3))
			_polvo_centro.call("emitir", d3 * r * _rng.randf_range(0.05, 0.3) + Vector3(0, 0.25, 0), d3 * _rng.randf_range(0.3, 0.8) + Vector3(0, 0.6, 0), _rng.randf_range(0.9, 1.1), _rng.randf_range(0.9, 1.2))
	# GOLPE: el anillo que se abre y las púas que asoman en el centro
	if bool(_p["anillo"]):
		var rc: float = clampf(r * 2.4, 0.5, 2.2)
		# 7/11: encima de las grietas de código, la MARCA DE SUELO de verdad (`T_Groundmark19.png`, del pack de LeLu que bajó Pablo), girada al azar en cada golpe
		_anillo = TierraToy.crear_quad_suelo("Anillo", 2.0 * rc, 2.0 * rc, SH_ANILLO, {"apertura": 0.0, "vida": 1.0, "semilla": _rng.randf(), "lados": 9,
			"marca_tex": load(TEX_MARCA), "marca_peso": MARCA_PESO, "marca_giro": _rng.randf() * TAU, "color_grieta": color_marca}, Vector3(0, 0.02, 0), -2)
		_anillo.rotation.y = _rng.randf() * TAU
		_plano.add_child(_anillo)
		# 7/11: la marca, además, como DECAL: se pega al relieve (en una cuesta un quad flota o se entierra). Del color se encarga `color_marca`, que el magma pone carmesí y encendido.
		_marca = TierraToy.crear_decal_suelo("Marca", 2.4 * rc, 2.4 * rc, ALTO_DECAL, {"mascara": load(TEX_MARCA), "color": color_marca,
			"color_emision": color_emision_marca, "emision": emision_marca, "vida": 1.0, "fuerza": 1.0}, Vector3(0, 0.0, 0), -3)
		_marca.rotation.y = _rng.randf() * TAU
		_plano.add_child(_marca)
		_puas_mm = TierraToy.crear_mm("Puas", N_PUAS, TierraToy.malla_roca("pua_1"), 0.0, 0.0, 1.0, TierraToy.COLOR_PUA)
		_plano.add_child(_puas_mm)
		for j in N_PUAS:
			var a4: float = TAU * float(j) / float(N_PUAS) + _rng.randf_range(-0.4, 0.4)
			var d4: Vector3 = Vector3(cos(a4), 0.0, sin(a4))
			var w: float = r * _rng.randf_range(0.5, 0.65)
			_puas.append({"pos": d4 * r * _rng.randf_range(0.15, 0.4), "rot": HieloMallas._inclinar(d4, _rng.randf_range(0.1, 0.3), _rng.randf() * TAU), "w": w, "h": r * _rng.randf_range(0.75, 1.1)})      # pequeñas: asoman y se retiran
	avanzar_a(0.0)


## Altura (0..1 de su alto) de una púa del golpe en `t`: asoma con sobrepaso desde T_PUAS_ASOMAN, se queda y se retira desde T_PUAS_FUERA.
static func altura_pua(t: float) -> float:
	var sube: float = clampf((t - T_PUAS_ASOMAN) / T_PUAS_SUBEN, 0.0, 1.0)
	var fuera: float = 1.0 + TierraToy.subida(sube)                                   # -1 → 0 (bajo tierra → su sitio), con el sobrepaso de las rocas
	var retira: float = smoothstep(0.0, 1.0, clampf((t - T_PUAS_FUERA) / T_PUAS_RETIRAN, 0.0, 1.0))
	return clampf(fuera * (1.0 - retira), 0.0, 1.2)


## Apertura (0..1) y vida (1..0) del anillo del golpe en `t`.
static func anillo_en(t: float) -> Dictionary:
	return {"apertura": smoothstep(0.0, T_ANILLO_ABRE, t), "vida": 1.0 - smoothstep(T_PUAS_FUERA, T_PUAS_FUERA + T_ANILLO_VA, t)}


## (pruebas) alturas (m) de las púas del golpe en `t` (vacío si no las hay).
func puas_estado(t: float) -> Array:
	var r: Array = []
	for d in _puas:
		r.append(float(d["h"]) * altura_pua(t))
	return r


## (pruebas) ¿hay anillo? y sus parámetros actuales.
func anillo_estado() -> Dictionary:
	if _anillo == null or not is_instance_valid(_anillo):
		return {"hay": false}
	var m: ShaderMaterial = _anillo.material_override as ShaderMaterial
	return {"hay": true, "apertura": float(m.get_shader_parameter("apertura")), "vida": float(m.get_shader_parameter("vida")), "radio": (_anillo.mesh as PlaneMesh).size.x * 0.5}


func _gravedad_local() -> Vector3:
	var b: Basis = _plano.basis if _plano != null else _base_normal()
	if is_inside_tree():
		b = global_transform.basis * b
	return b.inverse() * Vector3(0, -GRAVEDAD, 0)


## Estado de la piedra `d` en el instante `t`: cae con la gravedad; al tocar la superficie (o el suelo del mundo) se queda quieta.
func _estado_pie(d: Dictionary, t: float, g: Vector3) -> Dictionary:
	var p: Vector3 = (d["p0"] as Vector3) + (d["v0"] as Vector3) * t + 0.5 * g * t * t
	var v: Vector3 = (d["v0"] as Vector3) + g * t
	var quieta: bool = false
	if variante != Variante.FIN and p.y < 0.0:
		p.y = 0.0
		v = Vector3.ZERO
		quieta = true
	if is_inside_tree():
		var pm: Vector3 = global_transform * (_plano.basis * p)
		var y_min: float = global_position.y - altura_suelo
		if pm.y < y_min:
			p += (global_transform.basis * _plano.basis).inverse() * Vector3(0, y_min - pm.y, 0)
			v = Vector3.ZERO
			quieta = true
	var u: float = t / float(d["vida"])
	return {"pos": p, "vel": v, "u": u, "vivo": u < 1.0, "quieta": quieta}


## Medición para las pruebas: una entrada por piedra con su estado en `t`: {pos (mundo), dir, dist, altura (sobre la superficie), vy (mundo), vivo, vida}.
func piedras_estado(t: float) -> Array:
	var res: Array = []
	var g: Vector3 = _gravedad_local()
	for d in _pie:
		var e: Dictionary = _estado_pie(d, t, g)
		var p: Vector3 = e["pos"]
		var vm: Vector3 = global_transform.basis * (_plano.basis * (e["vel"] as Vector3))
		res.append({"pos": global_transform * (_plano.basis * p), "dir": vm.normalized(), "dist": p.length(), "altura": p.y, "vy": vm.y, "vivo": bool(e["vivo"]), "vida": float(d["vida"])})
	return res


## (piedras, bocanadas de polvo contando las del centro) que lleva.
func recuento() -> Array:
	return [_pie.size(), int(_p.get("polvo", 0)) + int(_p.get("centro", 0))]


func _process(delta: float) -> void:
	if _p.is_empty():
		return
	if _t < 0.0:
		_t = 0.0
		HumoRegla.enganchar_polvo(self, "polvo_tierra")       # polvo por regla (apagado por defecto): aire rápido a ras de suelo
	_t += delta
	avanzar_a(_t)
	if _t >= _fin_t:
		queue_free()


## Pone las piedras como en el instante `t` (fórmula cerrada). El polvo se mueve solo (humo_toy.gd).
func avanzar_a(t: float) -> void:
	if _p.is_empty() or _plano == null:
		return
	var g: Vector3 = _gravedad_local()
	var mm: MultiMesh = _mm.multimesh
	for i in _pie.size():
		var d: Dictionary = _pie[i]
		var e: Dictionary = _estado_pie(d, t, g)
		var u: float = float(e["u"])
		if not bool(e["vivo"]):
			HieloMallas.ocultar(mm, i)
			continue
		var rot: Basis = (Basis(d["eje"], float(d["vel_ang"]) * t * (0.0 if bool(e["quieta"]) else 1.0)) * (d["rot0"] as Basis)).orthonormalized()
		var s: float = float(d["tam"]) * (1.0 - smoothstep(0.75, 1.0, u)) * 2.0 / TierraToy.lado_malla(mm.mesh)   # `tam` = radio; al final se hunde en el suelo (encoge)
		mm.set_instance_transform(i, TierraToy.centrar(mm.mesh, rot * Basis.from_scale(Vector3.ONE * s), e["pos"]))
		mm.set_instance_custom_data(i, Color(float(d["tono"]), 1.0, 0.0, 0.0))
	if _anillo != null and is_instance_valid(_anillo):
		var an: Dictionary = anillo_en(t)
		var ma: ShaderMaterial = _anillo.material_override as ShaderMaterial
		ma.set_shader_parameter("apertura", an["apertura"])
		ma.set_shader_parameter("vida", an["vida"])
	if _puas_mm != null and is_instance_valid(_puas_mm):
		var mp: MultiMesh = _puas_mm.multimesh
		var f: float = altura_pua(t)
		for j in _puas.size():
			var d: Dictionary = _puas[j]
			var h: float = float(d["h"]) * f
			if h < 0.003:
				HieloMallas.ocultar(mp, j)
				continue
			mp.set_instance_transform(j, TierraToy.asentar(mp.mesh, d["rot"], float(d["w"]), h, float(d["w"]), d["pos"]))
			mp.set_instance_custom_data(j, Color(0.3 + 0.2 * float(j), 1.0, 0.0, 0.0))
