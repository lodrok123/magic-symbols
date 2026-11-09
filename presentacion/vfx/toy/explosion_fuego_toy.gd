class_name ExplosionFuegoToy
extends Node3D

## EXPLOSIÓN DEL BARRIL CON EL FUEGO OFICIAL (4/11/2026, decisión de Pablo: rehacer la explosión tomando FuegoToy como referencia; fuego blando tipo Echoes of Wisdom, rojos y naranjas, nunca amarillo).
## No inventa un fuego nuevo: junta piezas ya hechas, a escala de explosión y paramétricas por `radio` (el de la explosión, 2,6 u en el barril):
##   · BOLA DE FUEGO: ImpactoFuegoToy en ESTILO B (flipbook de Le Lu recoloreado con la rampa de la bola, billboard, se hincha y se enfría) con el radio de impacto = `K_BOLA · radio`; trae su destello
##     hit22 del primer instante (~0,14 s), la mancha de calor del suelo, el halo y UNA luz que se apaga. Dura 0,8 s.
##   · CHISPAS Y BRASAS hacia fuera: ImpactoFuegoToy en ESTILO C (el golpe actual de la bola) al mismo tamaño: trazos de chispa desde el punto hacia afuera, con gravedad y rozamiento, y brasas que caen.
##   · ONDA A RAS DE SUELO: el decal de explosion_suelo.gdshader (el mismo del aviso de la mecha) con un anillo de fuego cuyo frente crece de 0 a `radio` en T_ONDA s (ease-out) y llega EXACTAMENTE al
##     alcance de la explosión; detrás queda un resplandor rojo-naranja en el suelo que se apaga en ~0,8 s.
## Sin humo (si se pidiera, poco y cálido-oscuro, breve). Duración total T_TOTAL s; se libera sola con todo lo que cuelga de ella.
## Uso:  var e := ExplosionFuegoToy.crear(Barril3D.RADIO); padre.add_child(e); e.global_position = punto_en_el_suelo

const T_ONDA: float = 0.38              ## s que tarda el frente de la onda en llegar a `radio`
const T_APAGA_ONDA: float = 0.7         ## s en que el anillo ha desaparecido
const T_CALOR: float = 0.85             ## s en que se apaga el resplandor del suelo
const T_TOTAL: float = 1.5              ## s hasta liberar el nodo (la bola, las chispas y la luz acaban antes; las brasas del suelo se han ido a 1,4 s). Antes 1,35
const K_BOLA: float = 0.327             ## radio de impacto de la bola / radio de la explosión (0,85 u para 2,6): la bola mide ≈ 5,2 · 0,85 ≈ 4,4 u de lado y se hincha hasta ~el radio
const DESP_CALOR: float = -0.05         ## baja la temperatura de la rampa de la bola (ImpactoFuegoToy.desp_calor): la masa sale rojo-naranja y el amarillo queda solo en el núcleo del primer instante
## Revisión 4/11 (tarde): destello pequeño y casi blanco-crema (FLASH_K · su tamaño, FLASH_BRILLO), masa recorrida por la parte ROJA de la rampa (TRAMO_BOLA 0–0,5, núcleo naranja y bordes rojos), forma más recortada
## (RECORTE_BOLA: lóbulos de fuego, no nube), bola aplastada (APLASTA: más ancha que alta, para no tapar a la jugadora) y más corta (DUR_K: 0,8 → 0,5 s).
const FLASH_K: float = 0.45
const FLASH_BRILLO: float = 2.2
const TRAMO_BOLA: Vector2 = Vector2(0.0, 0.5)
const RECORTE_BOLA: Vector2 = Vector2(0.24, 0.62)
const APLASTA: float = 0.7
const DUR_K: float = 0.62
const GRUPO: String = "explosion_fuego_toy"

## 5/11/2026 (Pablo: «que se sienta un poco más como fuego»; mismo tamaño): además de la bola, las chispas y la onda, sube FUEGO de verdad. Todo es FuegoToy (su textura de lenguas, sus shaders y su rampa):
##   · LENGUAS: un pilar de FuegoToy central y unos pocos alrededor (alturas y retrasos distintos) que suben desde la bola y se deshacen. Cada uno se anima con su `aparicion` (0 → 1 → 0: el cuerpo crece desde el suelo y se apaga).
##   · BRASAS: unos pocos pilares enanos de FuegoToy repartidos DENTRO del radio que se quedan ardiendo en el suelo ≈ 1 s y se apagan (marcan el área que acaba de arder).
##   · HUMO cálido: una bocanada breve (VfxPuzle3D, marrón rojizo, poco opaco) que sube tras la bola, ya con el fuego en lo suyo.
## Los tamaños salen de `radio / RADIO_REF` (el barril grande, 2,6 u): un barril pequeño de radio 1,6 lo hace todo ×0,62.
const RADIO_REF: float = 2.6
## Lenguas: [ángulo (°), distancia al centro (× radio), alto (u a RADIO_REF), ancho (u), t de nacimiento (s), t en que empieza a apagarse (s), t en que se ha ido (s)]. La primera es la central.
const LENGUAS: Array = [
	[0.0, 0.0, 2.3, 0.55, 0.04, 0.46, 0.88],
	[20.0, 0.30, 1.6, 0.32, 0.08, 0.40, 0.76],
	[95.0, 0.34, 1.9, 0.34, 0.12, 0.46, 0.84],
	[170.0, 0.28, 1.45, 0.30, 0.16, 0.38, 0.74],
	[235.0, 0.36, 1.75, 0.32, 0.10, 0.44, 0.82],
	[310.0, 0.32, 1.35, 0.28, 0.19, 0.36, 0.72],
]
## Brasas: [ángulo (°), distancia (× radio), t de nacimiento, t en que empieza a apagarse, t en que se ha ido]
const BRASAS: Array = [
	[40.0, 0.42, 0.22, 0.90, 1.35],
	[125.0, 0.60, 0.28, 0.85, 1.30],
	[205.0, 0.38, 0.25, 0.95, 1.40],
	[285.0, 0.66, 0.32, 0.80, 1.25],
	[340.0, 0.50, 0.30, 0.92, 1.38],
]
const BRASA_ALTO: float = 0.34
const BRASA_ANCHO: float = 0.13
const T_HUMO: float = 0.10              ## s en que sale la bocanada de humo
const BRILLO_LENGUA: float = 1.0
const BLANDURA_LENGUA: float = 0.22     ## la del pilar validado
const ESCALA_RAMPA_LENGUA: float = 0.72 ## fracción de la rampa que recorren las lenguas (1 = hasta el amarillo pálido)
const CONTRASTE_LENGUA: float = 1.2

var radio: float = 2.6
var _t: float = 0.0
var _decal: MeshInstance3D = null
var _mat: ShaderMaterial = null
var _bola: ImpactoFuegoToy = null
var _chispas: ImpactoFuegoToy = null
var _lenguas: Array = []          ## [{nodo: FuegoToy, t0, t1, t2}]
var _brasas: Array = []
var _humo_puesto: bool = false


static func crear(radio_: float) -> ExplosionFuegoToy:
	var e := ExplosionFuegoToy.new()
	e.radio = maxf(radio_, 0.3)
	return e


func _ready() -> void:
	add_to_group(GRUPO)
	var r_bola: float = K_BOLA * radio
	_bola = ImpactoFuegoToy.crear(ImpactoFuegoToy.Variante.GOLPE, Vector3.UP, r_bola, ImpactoFuegoToy.Estilo.B)
	_bola.name = "Bola"
	_bola.desp_calor = DESP_CALOR
	_bola.flash_k = FLASH_K
	_bola.flash_brillo = FLASH_BRILLO
	_bola.tramo_bola = TRAMO_BOLA
	_bola.recorte_bola = RECORTE_BOLA
	_bola.aplasta_bola = APLASTA
	_bola.dur_k = DUR_K
	add_child(_bola)
	_chispas = ImpactoFuegoToy.crear(ImpactoFuegoToy.Variante.GOLPE, Vector3.UP, r_bola, ImpactoFuegoToy.Estilo.C)
	_chispas.name = "Chispas"
	_chispas.desp_calor = DESP_CALOR
	_chispas.flash_k = FLASH_K
	_chispas.flash_brillo = FLASH_BRILLO
	add_child(_chispas)
	_decal = AvisoAreaFuego.decal(radio)
	_decal.name = "Onda"
	_mat = _decal.material_override as ShaderMaterial
	add_child(_decal)
	var k: float = radio / RADIO_REF
	for d in LENGUAS:
		var l: Array = d
		_lenguas.append(_pilar(float(l[0]), float(l[1]) * radio, float(l[3]) * k, float(l[2]) * k, float(l[4]), float(l[5]), float(l[6]), 1.0 if _lenguas.is_empty() else 0.0, 1.0))
	for d in BRASAS:
		var b: Array = d
		_brasas.append(_pilar(float(b[0]), float(b[1]) * radio, BRASA_ANCHO * k, BRASA_ALTO * k, float(b[2]), float(b[3]), float(b[4]), 0.0, 0.35))
	avanzar_a(0.0)


## Un pilar de FuegoToy (semiejes `ancho` × `alto` × `ancho`, en u) a `dist` u del centro y `ang` grados, que nace en `t0`, empieza a apagarse en `t1` y se ha ido en `t2`. `luz` = su mando de luz (solo la lengua central ilumina);
## `chispas` = proporción de chispas.
func _pilar(ang: float, dist: float, ancho: float, alto: float, t0: float, t1: float, t2: float, luz_: float, chispas_: float) -> Dictionary:
	var f := FuegoToy.new()
	f.definir(FuegoToy.Figura.PILAR, ancho, alto, ancho)
	f.aparicion = 0.0
	f.luz = luz_
	f.chispas = chispas_
	f.brillo = BRILLO_LENGUA
	f.blandura = BLANDURA_LENGUA
	f.name = "Lengua"
	add_child(f)
	f._param_mats("escala_rampa", ESCALA_RAMPA_LENGUA)       # la rampa de fuego acaba en amarillo pálido: se recorre solo hasta el naranja (rojos y naranjas, nunca amarillo)
	f._param_mats("contraste", CONTRASTE_LENGUA)
	var a: float = deg_to_rad(ang)
	f.position = Vector3(cos(a) * dist, 0.0, sin(a) * dist)
	return {"nodo": f, "t0": t0, "t1": t1, "t2": t2}


## Cuánto se ve (0..1) un pilar en `t`: sube desde su nacimiento (0,12 s) y se apaga entre `t1` y `t2`.
static func envolvente(t: float, t0: float, t1: float, t2: float) -> float:
	return smoothstep(t0, t0 + 0.12, t) * (1.0 - smoothstep(t1, t2, t))


## Fracción 0..1 del radio a la que está el frente de la onda en el instante `t` (s).
static func onda_en(t: float) -> float:
	var u: float = clampf(t / T_ONDA, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 2.5)


## Radio real (u) del frente de la onda en `t`: llega a `radio` en T_ONDA.
func radio_onda(t: float) -> float:
	return onda_en(t) * radio


func tiempo() -> float:
	return _t


func _process(delta: float) -> void:
	if _t == 0.0:
		HumoRegla.enganchar_barril(self)          # humo por regla (apagado por defecto): el anillo donde la onda se frena
	_t += delta
	avanzar_a(_t)
	if _t >= T_TOTAL:
		queue_free()


## Pone el decal (anillo y resplandor) en el instante `t`. La bola y las chispas se mueven solas (ImpactoFuegoToy._process).
func avanzar_a(t: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("onda", onda_en(t))
	_mat.set_shader_parameter("onda_vida", smoothstep(0.0, 0.02, t) * (1.0 - smoothstep(T_ONDA * 0.8, T_APAGA_ONDA, t)))
	_mat.set_shader_parameter("calor", smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(0.08, T_CALOR, t)))
	for d in _lenguas:
		_poner_pilar(d as Dictionary, t)
	for d in _brasas:
		_poner_pilar(d as Dictionary, t)
	if not _humo_puesto and t >= T_HUMO and is_inside_tree():
		_humo_puesto = true
		var k: float = radio / RADIO_REF
		VfxPuzle3D._emisor(self, Vector3(0.0, 0.5 * k, 0.0), "humo", 7, 0.9, 1.1 * k, 1.2 * k,
			{"color": Color(0.36, 0.2, 0.14, 0.4), "gravedad": 0.9, "abanico": 40.0, "crece": true, "radio_emision": 0.55 * k, "amortigua": 1.2})


func _poner_pilar(d: Dictionary, t: float) -> void:
	var f: FuegoToy = d["nodo"] as FuegoToy
	if f == null or not is_instance_valid(f):
		return
	var e: float = envolvente(t, float(d["t0"]), float(d["t1"]), float(d["t2"]))
	f.aparicion = e
	f.visible = e > 0.01
