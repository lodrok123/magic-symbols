class_name CongeladoToy
extends Node3D

## CONGELADO «TOY» (18/11/2026, Pablo, con una captura de un personaje congelado: «el efecto cuando se congela alguien, fíjate en los bloques celestes alrededor del personaje»).
## Lo que se ve sobre un cuerpo congelado, tres capas:
##   · COSTRA: unos pocos bloques de hielo pegados al cuerpo (un casquete en la cabeza, dos a media altura como hombros o manos, dos en los pies y alguno suelto), que crecen en los tres
##     escalones del hielo. Mismo cristal que el resto del hielo (hielo_cristal.gdshader, paleta del hielo del mundo).
##   · BLOQUES CELESTES: cuadraditos planos, celeste vivo, que flotan alrededor del cuerpo, suben despacio y titilan (MultiMesh de quads que miran a la cámara, sin luz, movidos por la CPU).
##   · VAHO: bocanadas pálidas de frío que salen del cuerpo y se quedan en el mundo (el humo toon de humo_toy.gd).
## Solo dibujo: no congela a nadie. Va de hermano del objetivo y lo sigue y se quita solo cuando el objetivo deja de estar congelado (lee su `congelado` y su `muerto`), cuando pasa `dura`
## (si se le dio) o si el objetivo desaparece. No hay luces ni GPUParticles3D.
##   CongeladoToy.asegurar(enemigo, alto)          lo pone si no lo tiene ya (lo llama Combate3D mientras `congelado` > 0)
##   CongeladoToy.poner(nodo, alto, radio, dura)   lo pone durante `dura` s (lab, objetos)
##   soltar()                                      la costra se encoge, los bloques y el vaho se van y el nodo se libera

const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")

## false = no se pone nunca (el congelado se queda con su tinte y su icono, como antes)
static var ACTIVO: bool = true

const META: String = "vfx_congelado"
const T_CRECE: float = 0.35               ## s que tarda la costra en formarse (tres escalones)
const T_SUELTA: float = 0.25              ## s que tarda en encogerse al soltar
const T_COLA: float = 1.3                 ## s que el nodo sigue vivo tras soltar (el vaho que queda)
const COSTRA_OPACIDAD: float = 0.72
const COSTRA_TAM: float = 0.6                ## radio de los trozos de costra, en veces lo que dice `sitios` (× el radio del cuerpo)
const N_BLOQUES: int = 48                 ## cuadraditos celestes
const BLOQUE_TAM: Vector2 = Vector2(0.035, 0.085)     ## lado (m), del más pequeño al más grande
const BLOQUE_SUBE: Vector2 = Vector2(0.25, 0.7)       ## m/s a los que suben
const COLOR_BLOQUE: Color = Color(0.42, 0.9, 1.0)     ## celeste vivo (el de la referencia): más saturado que el cristal, para que se lea encima
const VAHO_POR_S: float = 4.0           ## con 7 el vaho tapaba la costra y los cuadraditos
const VAHO_CLARO: Color = Color(0.88, 0.96, 1.0)
const VAHO_SOMBRA: Color = Color(0.62, 0.82, 0.96)
const VAHO_VIEJO: Color = Color(0.72, 0.86, 0.95)

var objetivo: Node3D = null
var alto: float = 1.6
var radio: float = 0.4
var dura: float = -1.0

var _costra: MultiMeshInstance3D = null
var _piezas: Array = []                   ## [{pos, rot, w, h, claro, fase, retraso}]
var _bloques: MultiMeshInstance3D = null
var _b: Array = []                        ## [{ang, r, y, sube, tam, fase, giro}]
var _vaho: Node3D = null
var _t: float = 0.0
var _t_suelta: float = -1.0
var _acc: float = 0.0


static func poner(nodo: Node3D, alto_: float = 1.6, radio_: float = 0.4, dura_: float = -1.0) -> CongeladoToy:
	if nodo == null or not is_instance_valid(nodo) or not ACTIVO:
		return null
	var e: CongeladoToy = CongeladoToy.new()
	e.name = "CongeladoToy"
	e.objetivo = nodo
	e.alto = maxf(alto_, 0.3)
	e.radio = maxf(radio_, 0.12)
	e.dura = dura_
	# NO cuelga del objetivo: va de HERMANO y lo sigue cada fotograma. Colgado de un enemigo cambiaba su lista de hijos y `prueba_limo_combate` fallaba (18/11).
	var padre: Node = nodo.get_parent()
	if padre == null:
		e.free()
		return null
	padre.add_child(e)
	if nodo.is_inside_tree():
		e.global_transform = Transform3D(Basis.IDENTITY, nodo.global_position)
	nodo.set_meta(META, e)
	return e


## Lo pone solo si `nodo` no lo lleva ya. Barato: se puede llamar cada fotograma.
static func asegurar(nodo: Node3D, alto_: float = 1.6, radio_: float = -1.0) -> void:
	if not ACTIVO or nodo == null:
		return
	var viejo: Variant = nodo.get_meta(META, null)
	if viejo != null and is_instance_valid(viejo) and not (viejo as CongeladoToy).soltado():
		return
	poner(nodo, alto_, radio_ if radio_ > 0.0 else maxf(alto_ * 0.26, 0.2))


func soltado() -> bool:
	return _t_suelta >= 0.0


func soltar() -> void:
	if _t_suelta >= 0.0:
		return
	_t_suelta = 0.0


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var sem: float = rng.randf() * 10.0
	# COSTRA: dónde va cada bloque (fracción del alto, a qué distancia del eje en radios, tamaño en radios)
	var sitios: Array = [[0.97, 0.0, 1.0], [0.6, 0.95, 0.5], [0.52, 0.95, 0.46], [0.08, 0.6, 0.55], [0.07, 0.6, 0.5], [0.36, 0.8, 0.36], [0.75, 0.75, 0.34]]
	var a0: float = rng.randf() * TAU
	for i in sitios.size():
		var s: Array = sitios[i]
		var ang: float = a0 + (PI if i % 2 == 0 else 0.0) + rng.randf_range(-0.5, 0.5) + float(i) * 0.9
		var w: float = radio * float(s[2]) * COSTRA_TAM * rng.randf_range(0.9, 1.15)                # `bloque` es de radio 1: `w` es el RADIO del trozo
		_piezas.append({"pos": Vector3(cos(ang) * radio * float(s[1]), alto * float(s[0]), sin(ang) * radio * float(s[1])),
			"rot": Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)), "w": w, "h": w * rng.randf_range(0.75, 1.1), "claro": rng.randf(), "fase": rng.randf(),
			"retraso": 0.0 if i == 0 else rng.randf_range(0.0, 0.3)})
	_costra = HieloMallas.crear_mm("Costra", _piezas.size(), HieloMallas.bloque(0.16, sem), COSTRA_OPACIDAD, 1)
	(_costra.material_override as ShaderMaterial).set_shader_parameter("escarcha_base", 0.25)
	add_child(_costra)
	# BLOQUES CELESTES
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = N_BLOQUES
	_bloques = MultiMeshInstance3D.new()
	_bloques.name = "Bloques"
	_bloques.multimesh = mm
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = COLOR_BLOQUE
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.billboard_keep_scale = true
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bloques.material_override = sm
	_bloques.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bloques)
	for i in N_BLOQUES:
		_b.append({"ang": rng.randf() * TAU, "r": radio * rng.randf_range(0.9, 2.0), "y": rng.randf() * alto * 1.1, "sube": rng.randf_range(BLOQUE_SUBE.x, BLOQUE_SUBE.y),
			"tam": rng.randf_range(BLOQUE_TAM.x, BLOQUE_TAM.y), "fase": rng.randf() * TAU, "giro": rng.randf_range(-0.6, 0.6), "largo": rng.randf_range(1.0, 2.2)})
	# VAHO
	_vaho = HumoToy.new()
	_vaho.name = "Vaho"
	add_child(_vaho)
	_vaho.call("montar", 14, {"claro": VAHO_CLARO, "sombra": VAHO_SOMBRA, "viejo": VAHO_VIEJO, "tam_ini": radio * 0.6, "tam_fin": radio * 1.6, "vida": 1.1, "deriva": Vector3(0, 0.22, 0),
		"mundo": true, "opacidad": 0.45})
	_poner(0.0)


func _process(delta: float) -> void:
	_t += delta
	if _t_suelta >= 0.0:
		_t_suelta += delta
		if _t_suelta >= T_SUELTA + T_COLA:
			queue_free()
			return
	elif not is_instance_valid(objetivo) or (dura > 0.0 and _t >= dura):
		soltar()
	elif objetivo.get("_congelado_s") != null and float(objetivo.get("_congelado_s")) <= 0.0:
		soltar()                                      # un objeto `congelable` (Objeto3D) que se ha descongelado antes de tiempo (calor)
	elif dura <= 0.0:
		var c: Variant = objetivo.get("congelado")
		if (c != null and float(c) <= 0.0) or bool(objetivo.get("muerto")):
			soltar()
	if is_instance_valid(objetivo) and objetivo.is_inside_tree() and _t_suelta < 0.0:
		global_transform = Transform3D(Basis(Vector3.UP, objetivo.global_rotation.y), objetivo.global_position)
	_poner(delta)


## Coloca la costra y los bloques con el tiempo de ahora y suelta el vaho.
func _poner(delta: float) -> void:
	var vive: float = 1.0 if _t_suelta < 0.0 else 1.0 - smoothstep(0.0, T_SUELTA, _t_suelta)
	var cr: float = clampf(_t / T_CRECE, 0.0, 1.0)
	var mmc: MultiMesh = _costra.multimesh
	for i in _piezas.size():
		var p: Dictionary = _piezas[i]
		var ret: float = float(p["retraso"])
		var s: float = HieloToy.escalon(clampf((cr - ret) / maxf(1.0 - ret, 0.01), 0.0, 1.0)) * vive
		if s <= 0.001:
			HieloMallas.ocultar(mmc, i)
		else:
			HieloMallas.poner(mmc, i, p["pos"], p["rot"], float(p["w"]) * s, float(p["h"]) * s, float(p["w"]) * s, float(p["claro"]), 0.95, float(p["fase"]))
	var mmb: MultiMesh = _bloques.multimesh
	var techo: float = alto * 1.15
	for i in _b.size():
		var b: Dictionary = _b[i]
		b["y"] = fposmod(float(b["y"]) + float(b["sube"]) * delta, techo)
		b["ang"] = float(b["ang"]) + float(b["giro"]) * delta
		var y: float = float(b["y"])
		# nace pequeño abajo, se apaga arriba, y titila
		var k: float = smoothstep(0.0, 0.12, y / techo) * (1.0 - smoothstep(0.75, 1.0, y / techo)) * (0.6 + 0.4 * sin(_t * 9.0 + float(b["fase"]))) * vive * smoothstep(0.0, 0.2, _t)
		var tam: float = float(b["tam"]) * k
		if tam <= 0.002:
			mmb.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3(0, -50, 0)))
			continue
		var pos: Vector3 = Vector3(cos(float(b["ang"])) * float(b["r"]), y, sin(float(b["ang"])) * float(b["r"]))
		mmb.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(tam, tam * float(b["largo"]), tam)), pos))
	if delta > 0.0 and _t_suelta < 0.0 and is_inside_tree() and _vaho != null and is_instance_valid(_vaho):
		_acc += VAHO_POR_S * delta
		while _acc >= 1.0:
			_acc -= 1.0
			var a: float = randf() * TAU
			var loc: Vector3 = Vector3(cos(a) * radio * randf_range(0.6, 1.3), alto * randf_range(0.05, 0.8), sin(a) * radio * randf_range(0.6, 1.3))
			_vaho.call("emitir", global_transform * loc, Vector3(cos(a) * 0.25, randf_range(0.05, 0.25), sin(a) * 0.25), randf_range(0.85, 1.15), randf_range(0.8, 1.2))


## (pruebas) piezas de costra visibles, bloques celestes visibles y bocanadas de vaho vivas.
func estado() -> Dictionary:
	var nb: int = 0
	for i in _b.size():
		if _bloques.multimesh.get_instance_transform(i).origin.y > -10.0:
			nb += 1
	var nc: int = 0
	for i in _piezas.size():
		if _costra.multimesh.get_instance_transform(i).basis.get_scale().x > 0.005:
			nc += 1
	return {"costra": nc, "bloques": nb, "vaho": int(_vaho.call("vivas")) if _vaho != null and is_instance_valid(_vaho) else 0, "soltado": soltado()}
