class_name ArdiendoToy
extends Node3D

## ARDIENDO «TOY» (18/11/2026, Pablo, con una referencia de otro juego: el enemigo ENTERO envuelto en fuego, no solo un pilar de llamas delante).
## Lo que se ve sobre un cuerpo que arde, cuatro capas (cada una con su interruptor, abajo):
##   · CUERPO: el propio modelo brilla incandescente. Una capa `material_overlay` (ardiendo_cuerpo.gdshader) en TODAS sus mallas, también las que llevan esqueleto: naranja intenso por dentro,
##     rojo en el borde, manchas de calor que suben y parpadeo. Al quitarse se restaura exactamente el overlay que hubiera antes.
##   · LENGUAS: un FuegoToy pequeño (PILAR) en la cabeza, en cada hombro y en cada mano; en los huesos del esqueleto (por el final del nombre, nombres tipo Mixamo) y, si el modelo no tiene
##     esqueleto, en sitios de reserva sacados del alto y el radio. Siguen al hueso pero siempre en vertical (el fuego sube aunque el brazo se mueva).
##   · BRASAS: chispas pequeñas rojo-naranja que suben y se apagan (las partículas «brasa» de VfxPuzle3D, que ya usa la mano quemada).
##   · LUZ: una OmniLight3D naranja que parpadea (ruido, no seno) e ilumina el suelo de alrededor.
## Paleta: la del fuego de Pablo (blando, rojos y naranjas con contraste, NUNCA amarillo): los picos de brillo llegan a naranja claro, no más.
## Solo dibujo: no quema a nadie. Va de HERMANO del objetivo y lo sigue (si colgara de un enemigo cambiaría su lista de hijos, ver CongeladoToy) y se quita solo cuando el objetivo deja de
## arder (lee su `quemando` y su `muerto`), cuando pasa `dura` (si se le dio) o si el objetivo desaparece, con fundido.
##   ArdiendoToy.asegurar(enemigo, alto)          lo pone si no lo tiene ya (lo llama Combate3D mientras `quemando` > 0)
##   ArdiendoToy.poner(nodo, alto, radio, dura)   lo pone durante `dura` s (lab, usos puntuales)
##   soltar()                                     fundido de salida, las lenguas mueren, el overlay se restaura y el nodo se libera

const VfxPuzle = preload("res://presentacion/vfx_puzle_3d.gd")
const SHADER_CUERPO = preload("res://presentacion/vfx/toy/ardiendo_cuerpo.gdshader")

## false = no se pone nunca (el que arde se queda con su tinte y el pilar de llamas, como antes)
static var ACTIVO: bool = true
const CAPA_CUERPO: bool = true
const CAPA_LENGUAS: bool = true
const CAPA_BRASAS: bool = true
const CAPA_LUZ: bool = true

const META: String = "vfx_ardiendo"
const META_PREVIO: String = "ardiendo_overlay_previo"          ## en cada malla: el overlay que llevaba antes del nuestro (para restaurarlo exacto)
const META_NUESTRO: String = "ardiendo_overlay"
const T_ENTRA: float = 0.2                ## s que tarda en encenderse (cuerpo y luz)
const T_SALE: float = 0.4                 ## s que tarda en apagarse al soltar
const T_COLA: float = 1.0                 ## s que el nodo sigue vivo tras soltar (brasas y lenguas que se acaban)
const T_REVISAR: float = 0.5              ## s entre revisiones de las mallas del objetivo (un arma o pieza recién puesta también arde)

## colores (sin amarillo: g/r <= 0,6 y azul casi nulo)
const COLOR_BORDE: Color = Color(0.85, 0.12, 0.03)
const COLOR_NUCLEO: Color = Color(1.0, 0.33, 0.05)
const COLOR_FRIO: Color = Color(0.55, 0.07, 0.02)
const COLOR_PICO: Color = Color(1.0, 0.5, 0.14)
const COLOR_LUZ: Color = Color(1.0, 0.42, 0.12)
const COLOR_BRASA: Color = Color(1.0, 0.36, 0.08, 1.0)
const BRILLO_CUERPO: float = 1.0
const ALFA_CUERPO: float = 0.8            ## alfa de las manchas calientes
const ALFA_FRIO: float = 0.62             ## alfa de las zonas frías (rojo oscuro: oscurecen el modelo y dan contraste)
const ALFA_BORDE: float = 0.85

## lenguas: [clave, huesos por orden de preferencia (final del nombre), subida sobre el hueso (× alto) con el primero y con los demás, radio (× alto), alto de la llama (× alto), sitio de reserva sin esqueleto (x en radios, y × alto)]
## La cabeza va en la CORONILLA (HeadTop_End en Mixamo; si no hay, el hueso de la cabeza y un poco más arriba); los hombros, en la articulación del brazo (LeftArm), no en la clavícula.
const LENGUAS: Array = [
	# 18/11 (Pablo, 2ª referencia: «las lenguas son muy largas»): lamidas cortas, casi tan anchas como altas; antes 0,48 / 0,34 / 0,26.
	["cabeza", ["HeadTop_End", "Head"], -0.17, 0.1, 0.12, 0.22, Vector2(0.0, 0.92)],
	["hombro_izq", ["LeftArm", "LeftShoulder"], 0.0, 0.0, 0.10, 0.16, Vector2(-0.95, 0.72)],
	["hombro_der", ["RightArm", "RightShoulder"], 0.0, 0.0, 0.10, 0.16, Vector2(0.95, 0.72)],
	["mano_izq", ["LeftHand"], -0.03, -0.03, 0.08, 0.13, Vector2(-1.25, 0.42)],
	["mano_der", ["RightHand"], -0.03, -0.03, 0.08, 0.13, Vector2(1.25, 0.42)],
]
## El pilar de FuegoToy solo se ve bien a partir de cierto tamaño (si se le dan semiejes pequeños, sus láminas se quedan anchas y chatas): se monta a este tamaño de referencia y el nodo
## se ESCALA a lo que se quiere (más estrecho que alto).
const LENGUA_REF_RADIO: float = 0.3
const LENGUA_REF_ALTO: float = 0.9
const LENGUA_ANCHO: float = 0.85          ## × el radio pedido: las lenguas de referencia salen más gordas de lo que dicen sus semiejes
const LENGUA_LUZ: float = 0.0             ## la luz de cada lengua (0 = ninguna: la luz es una sola, la nuestra)
const LENGUA_CHISPAS: float = 0.0           ## las chispas del pilar son amarillentas y grandes: las brasas son las nuestras

const SUELO_DEL_PILAR: Array = ["Charco", "Resplandor", "Grietas", "Aviso", "HumoFinal", "Trocitos", "Chispas"]    ## partes del pilar de FuegoToy que son del suelo (o trocitos y chispas grandes) y se ocultan en las lenguas

const BRASAS_N: int = 22
const BRASAS_VIDA: float = 1.1
const BRASAS_TAM: float = 0.055           ## × alto
const BRASAS_VEL: float = 0.7             ## × alto, m/s
const BRASAS_SUBE: float = 1.6            ## gravedad hacia arriba (× alto)
const BRASAS_HDR: float = 1.9

const LUZ_ENERGIA: float = 1.4
const LUZ_ALCANCE: float = 2.5            ## × alto
const LUZ_SUBE: float = 1.15              ## × alto: a qué altura está (por encima de la cabeza: dentro del cuerpo quemaba en blanco el modelo, a 20 cm de sus superficies)
const LUZ_RUIDO_HZ: float = 5.5           ## velocidad del ruido del parpadeo
const LUZ_PARPADEO: float = 0.35          ## cuánto baja y sube (fracción de la energía)

var objetivo: Node3D = null
var alto: float = 1.6
var radio: float = 0.4
var dura: float = -1.0

var _t: float = 0.0
var _t_suelta: float = -1.0
var _fase: float = 0.0
var _mat: ShaderMaterial = null
var _mallas: Array = []                   ## MeshInstance3D a los que ya les he puesto la capa
var _t_rev: float = 0.0
var _lenguas: Array = []                  ## [{clave, nodo: FuegoToy, hueso: int (-1 = reserva), sube, local: Vector3}]
var _esqueleto: Skeleton3D = null
var _brasas: GPUParticles3D = null
var _luz: OmniLight3D = null
var _ruido: FastNoiseLite = null
var _restaurado: bool = false


static func poner(nodo: Node3D, alto_: float = 1.6, radio_: float = 0.4, dura_: float = -1.0) -> ArdiendoToy:
	if nodo == null or not is_instance_valid(nodo) or not ACTIVO:
		return null
	var e: ArdiendoToy = ArdiendoToy.new()
	e.name = "ArdiendoToy"
	e.objetivo = nodo
	e.alto = maxf(alto_, 0.3)
	e.radio = maxf(radio_, 0.12)
	e.dura = dura_
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
	if _vivo(nodo) != null:
		return
	poner(nodo, alto_, radio_ if radio_ > 0.0 else maxf(alto_ * 0.26, 0.2))


## ¿Lleva (o va a llevar) este nodo el efecto? Lo usa el pilar de llamas del cuerpo para encogerse cuando ya hay envoltura.
static func envuelve(nodo: Object) -> bool:
	if not ACTIVO or nodo == null or not is_instance_valid(nodo):
		return false
	if _vivo(nodo) != null:
		return true
	var q: Variant = nodo.get("quemando")
	return q != null and float(q) > 0.0 and nodo.get("muerto") != null


## El ArdiendoToy encendido de `nodo` (null si no lleva ninguno o ya se está apagando).
static func _vivo(nodo: Object) -> ArdiendoToy:
	if nodo == null or not nodo.has_meta(META):
		return null
	var v: Variant = nodo.get_meta(META)
	if v == null or not is_instance_valid(v) or (v as ArdiendoToy).soltado():
		return null
	return v as ArdiendoToy


func soltado() -> bool:
	return _t_suelta >= 0.0


func soltar() -> void:
	if _t_suelta >= 0.0:
		return
	_t_suelta = 0.0
	for l in _lenguas:
		var n: Variant = l["nodo"]
		if n != null and is_instance_valid(n):
			(n as FuegoToy).morir()
	if _brasas != null and is_instance_valid(_brasas):
		_brasas.emitting = false


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_fase = rng.randf() * 20.0
	_ruido = FastNoiseLite.new()
	_ruido.seed = rng.randi()
	_ruido.frequency = 1.0
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	if CAPA_CUERPO:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER_CUERPO
		_mat.set_shader_parameter("fase", _fase)
		_mat.set_shader_parameter("color_borde", Vector3(COLOR_BORDE.r, COLOR_BORDE.g, COLOR_BORDE.b))
		_mat.set_shader_parameter("color_nucleo", Vector3(COLOR_NUCLEO.r, COLOR_NUCLEO.g, COLOR_NUCLEO.b))
		_mat.set_shader_parameter("color_pico", Vector3(COLOR_PICO.r, COLOR_PICO.g, COLOR_PICO.b))
		_mat.set_shader_parameter("color_frio", Vector3(COLOR_FRIO.r, COLOR_FRIO.g, COLOR_FRIO.b))
		_mat.set_shader_parameter("alfa_frio", ALFA_FRIO)
		_mat.set_shader_parameter("brillo", BRILLO_CUERPO)
		_mat.set_shader_parameter("alfa_base", ALFA_CUERPO)
		_mat.set_shader_parameter("alfa_borde", ALFA_BORDE)
		_mat.set_shader_parameter("intensidad", 0.0)
		_revisar_mallas()
	_esqueleto = _buscar_esqueleto()
	if CAPA_LENGUAS:
		_montar_lenguas()
	if CAPA_BRASAS:
		var r: float = maxf(radio, alto * 0.3)
		_brasas = VfxPuzle._emisor(self, Vector3(0.0, alto * 0.5, 0.0), "brasa", BRASAS_N, BRASAS_VIDA, BRASAS_TAM * alto, BRASAS_VEL * alto,
			{"color": COLOR_BRASA, "aditivo": true, "hdr": BRASAS_HDR, "gravedad": BRASAS_SUBE * alto, "abanico": 25.0, "continuo": true, "radio_emision": r * 0.9})
		_brasas.name = "Brasas"
	if CAPA_LUZ:
		_luz = OmniLight3D.new()
		_luz.name = "Luz"
		_luz.light_color = COLOR_LUZ
		_luz.omni_range = LUZ_ALCANCE * alto
		_luz.omni_attenuation = 1.3
		_luz.shadow_enabled = false
		_luz.light_energy = 0.0
		_luz.position = Vector3(0.0, alto * LUZ_SUBE, 0.0)
		add_child(_luz)
	_poner(0.0)


func _exit_tree() -> void:
	_restaurar()
	if is_instance_valid(objetivo) and objetivo.has_meta(META) and objetivo.get_meta(META) == self:
		objetivo.remove_meta(META)


func _process(delta: float) -> void:
	_t += delta
	if _t_suelta >= 0.0:
		_t_suelta += delta
		if _t_suelta >= T_SALE:
			_restaurar()
		if _t_suelta >= T_SALE + T_COLA:
			queue_free()
			return
	elif not is_instance_valid(objetivo) or (dura > 0.0 and _t >= dura):
		soltar()
	elif dura <= 0.0:
		var q: Variant = objetivo.get("quemando")
		if (q != null and float(q) <= 0.0) or bool(objetivo.get("muerto")):
			soltar()
	if is_instance_valid(objetivo) and objetivo.is_inside_tree() and _t_suelta < 0.0:
		global_transform = Transform3D(Basis(Vector3.UP, objetivo.global_rotation.y), objetivo.global_position)
	_t_rev += delta
	if _t_rev >= T_REVISAR and _t_suelta < 0.0 and CAPA_CUERPO:
		_t_rev = 0.0
		_revisar_mallas()
	_poner(delta)


## 0 → 1 al encenderse, 1 → 0 al soltar.
func _fundido() -> float:
	var entra: float = smoothstep(0.0, T_ENTRA, _t)
	var sale: float = 1.0 if _t_suelta < 0.0 else 1.0 - smoothstep(0.0, T_SALE, _t_suelta)
	return entra * sale


func _poner(_delta: float) -> void:
	var f: float = _fundido()
	if _mat != null:
		_mat.set_shader_parameter("intensidad", f)
	if _luz != null and is_instance_valid(_luz):
		var n: float = _ruido.get_noise_1d((_t + _fase) * LUZ_RUIDO_HZ) * 0.5 + 0.5          # 0..1, no es un seno
		_luz.light_energy = LUZ_ENERGIA * f * (1.0 - LUZ_PARPADEO + 2.0 * LUZ_PARPADEO * n)
	if is_instance_valid(objetivo) and _t_suelta < T_SALE:
		_seguir_lenguas()


# ------------------------------------------------------------------ cuerpo

func _es_cuerpo(mi: MeshInstance3D, raiz: Node) -> bool:
	if mi.mesh == null or mi.mesh is QuadMesh:
		return false
	var n: Node = mi.get_parent()
	while n != null and n != raiz:
		if n is EfectoToy or n is GPUParticles3D:
			return false
		n = n.get_parent()
	# los efectos de otros estados (hielo, vaho...) y la barra de vida no son el cuerpo
	return not (mi.name.begins_with("Barra") or mi.name.begins_with("Costra") or mi.name.begins_with("Sombra"))


func _revisar_mallas() -> void:
	if _mat == null or not is_instance_valid(objetivo):
		return
	for raiz in _raices():
		for n in (raiz as Node).find_children("*", "MeshInstance3D", true, false):
			_poner_capa(n as MeshInstance3D, raiz)


## Dónde están las mallas del cuerpo: el propio objetivo y, si es un enemigo (Combate3D), su modelo `pj`, que es un HERMANO suyo y no un hijo.
func _raices() -> Array:
	var r: Array = [objetivo]
	var pj: Variant = objetivo.get("pj")
	if pj is Node3D and is_instance_valid(pj) and not objetivo.is_ancestor_of(pj):
		r.append(pj)
	return r


func _poner_capa(mi: MeshInstance3D, raiz: Node) -> void:
	if _mallas.has(mi) or not _es_cuerpo(mi, raiz):
		return
	var actual: Material = mi.material_overlay
	if actual != null and actual.has_meta(META_NUESTRO):
		pass                                             # un ArdiendoToy anterior que se está apagando: su «previo» sigue siendo el verdadero
	elif actual != null:
		mi.set_meta(META_PREVIO, actual)                 # (set_meta con null borraría la clave: sin overlay previo no se guarda nada)
	_mat.set_meta(META_NUESTRO, true)
	mi.material_overlay = _mat
	_mallas.append(mi)


## Devuelve a cada malla el overlay que tenía (si el nuestro sigue puesto; si alguien lo cambió mientras tanto, no se toca).
func _restaurar() -> void:
	if _restaurado:
		return
	_restaurado = true
	for mi in _mallas:
		if not is_instance_valid(mi):
			continue
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.material_overlay == _mat:
			m.material_overlay = m.get_meta(META_PREVIO) as Material if m.has_meta(META_PREVIO) else null
			if m.has_meta(META_PREVIO):
				m.remove_meta(META_PREVIO)
	_mallas.clear()


# ------------------------------------------------------------------ lenguas

func _buscar_esqueleto() -> Skeleton3D:
	if not is_instance_valid(objetivo):
		return null
	var pj: Variant = objetivo.get("pj")
	if pj is Node and is_instance_valid(pj):
		var sks: Array[Node] = (pj as Node).find_children("*", "Skeleton3D", true, false)
		if not sks.is_empty():
			return sks[0] as Skeleton3D
	var l: Array[Node] = objetivo.find_children("*", "Skeleton3D", true, false)
	return l[0] as Skeleton3D if not l.is_empty() else null


static func _hueso(sk: Skeleton3D, fin: String) -> int:
	for i in range(sk.get_bone_count()):
		var nombre: String = sk.get_bone_name(i)
		if nombre == fin or nombre.ends_with(":" + fin) or nombre.ends_with("_" + fin):
			return i
	return -1


func _montar_lenguas() -> void:
	for d in LENGUAS:
		var h: int = -1
		var cual: int = -1
		if _esqueleto != null:
			for k in (d[1] as Array).size():
				h = _hueso(_esqueleto, String((d[1] as Array)[k]))
				if h >= 0:
					cual = k
					break
		var sitio: Vector2 = d[6]
		var llama: FuegoToy = VfxReaccion3D.llama_vertical(self, Vector3.ZERO, LENGUA_REF_RADIO, LENGUA_REF_ALTO, LENGUA_LUZ, -1.0)
		llama.name = "Lengua_" + String(d[0])
		llama.chispas = LENGUA_CHISPAS
		var r: float = float(d[4]) * alto * LENGUA_ANCHO
		llama.scale = Vector3(r / LENGUA_REF_RADIO, float(d[5]) * alto / LENGUA_REF_ALTO, r / LENGUA_REF_RADIO)
		_quitar_suelo(llama)
		_lenguas.append({"clave": String(d[0]), "nodo": llama, "hueso": h, "sube": (float(d[2]) if cual <= 0 else float(d[3])) * alto,
			"local": Vector3(sitio.x * radio, sitio.y * alto, 0.0)})
	_seguir_lenguas()


## El pilar de FuegoToy está pensado para el suelo: charco, grietas, anillo de aviso, resplandor plano y humo del final. Una lengua que flota en un hombro no los quiere
## (salían como losas planas y tacos naranjas en el aire): se ocultan (no se liberan: el FuegoToy guarda referencias y reparte el rescoldo del final con ellos).
## 19/11: también se usa para el pilar del cuerpo (`VfxReaccion3D.llamas_cuerpo`) cuando el enemigo lleva ArdiendoToy: sus trozos de suelo salían como losas rectangulares a los pies.
static func quitar_suelo(llama: FuegoToy) -> void:
	_quitar_suelo(llama)


static func _quitar_suelo(llama: FuegoToy) -> void:
	var cuerpo: Node = llama.get_node_or_null("Cuerpo")
	if cuerpo == null:
		return
	for n in SUELO_DEL_PILAR:
		var h: Node3D = cuerpo.get_node_or_null(n) as Node3D
		if h != null:
			h.visible = false


## Cada lengua a su hueso (o a su sitio de reserva), con la llama siempre en vertical.
func _seguir_lenguas() -> void:
	if not is_inside_tree():
		return
	for l in _lenguas:
		var n: FuegoToy = l["nodo"] as FuegoToy
		if n == null or not is_instance_valid(n):
			continue
		var h: int = int(l["hueso"])
		if h >= 0 and _esqueleto != null and is_instance_valid(_esqueleto) and _esqueleto.is_inside_tree():
			var p: Vector3 = (_esqueleto.global_transform * _esqueleto.get_bone_global_pose(h)).origin
			n.global_position = p + Vector3.UP * float(l["sube"])
		else:
			n.position = l["local"]


## (pruebas) lo que hay puesto ahora mismo.
func estado() -> Dictionary:
	var en_huesos: int = 0
	var vivas: int = 0
	for l in _lenguas:
		if l["nodo"] != null and is_instance_valid(l["nodo"]):
			vivas += 1
		if int(l["hueso"]) >= 0:
			en_huesos += 1
	return {"mallas": _mallas.size(), "lenguas": vivas, "lenguas_en_huesos": en_huesos, "brasas": _brasas != null and is_instance_valid(_brasas), "luz": _luz != null and is_instance_valid(_luz),
		"energia_luz": _luz.light_energy if _luz != null and is_instance_valid(_luz) else 0.0, "fundido": _fundido(), "soltado": soltado(), "restaurado": _restaurado}
