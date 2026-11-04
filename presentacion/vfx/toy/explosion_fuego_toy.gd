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
const T_TOTAL: float = 1.35             ## s hasta liberar el nodo (la bola, las chispas y la luz acaban antes: 1,25 s la que más)
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

var radio: float = 2.6
var _t: float = 0.0
var _decal: MeshInstance3D = null
var _mat: ShaderMaterial = null
var _bola: ImpactoFuegoToy = null
var _chispas: ImpactoFuegoToy = null


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
	avanzar_a(0.0)


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
