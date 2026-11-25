class_name HieloToy
extends EfectoToy

## HIELO «TOY» (2/11/2026, rama claude/b1-hielo-rayo, B1 de docs/DIRECCION_2026-11-02.md §2.B). Clase HERMANA de FuegoToy y AguaToy: misma API, mismas cinco figuras (BOLA, MURO, PILAR, BARRERA, HAZ), mismos ejes
## (semieje_x / y / z en m), misma escala (`describir` / `desde_hechizo` son los de FuegoToy: un hechizo cambia de elemento sin cambiar de tamaño) y los mismos mandos (los diez de EfectoToy; valen `altura`,
## `ancho`, `brillo`, `velocidad` y `chispas` = cuántas esquirlas; los de luz, halo, tono y blandura no hacen nada en el hielo, que no brilla). FuegoToy y AguaToy no se han tocado: la máquina de carga e impacto está
## copiada, no compartida.
## Es HIELO, no luz: todos los shaders son blend_mix y unshaded (hielo_cristal.gdshader: cristal translúcido de facetas planas, cada cara es un escalón de tono, aristas claras, fresnel claro, escarcha en la base,
## grietas antes de romperse). No hay luces, ni materiales aditivos, ni GPUParticles3D: los cristales y las esquirlas son MultiMesh movidos por la CPU.
## CARÁCTER (docs/PLAN_VFX_ELEMENTOS.md): el hielo CRECE POR ETAPAS y SE ROMPE.
##   · NACER (`crece` 0 → 1, 0,9 s; la bola, `aparicion`): TRES ESCALONES visibles (a ~1/3 crece lo 34 %, luego 67 %, luego el 100 % de la altura de cada cristal, con una meseta entre cada uno) y la escarcha de la base
##     se extiende con ellos. Cada cristal empieza con su pequeño retraso: no es un bloque que se escala.
##   · VIVIR: no se mueve; una franja de brillo lento recorre los cristales en vertical.
##   · MORIR (`corte` 0 → 1): primero TIEMBLA y se AGRIETA (las grietas de T_Cracks336), luego cada cristal estalla a su hora (el reparto es aleatorio, de 0 a 0,55 de `corte`) y suelta esquirlas que
##     giran, CAEN con gravedad, rebotan una vez y se quedan en el suelo hasta desvanecerse; la escarcha se derrite.
## PALETA: la del hielo del mundo, centralizada en hielo_paleta.gd (con su procedencia). HieloMallas.material() y HieloEsquirlas la pasan a todos los shaders.
##
## FIGURAS: BOLA = bloque de hielo (icosfera de 80 facetas con púas de cristal) que gira; en vuelo, cristales largos detrás y esquirlas que caen. MURO = dos filas de cristales a lo largo de x. PILAR = una
## espiga central con dos medianas y una corona de cristales torcidos. BARRERA = jaula de cristales inclinados hacia dentro sobre la elipse del suelo, con una cúpula de cristal muy tenue. HAZ = una lanza de hielo
## que sale de la mano hacia -Z con púas a lo largo y un destello en la punta.
##
## Ciclo de vida de un proyectil de hielo, sobre UN SOLO nodo (igual que FuegoToy y AguaToy):
##   empezar_carga(duracion, tam_final)  durante `duracion` s aparecen esquirlas alrededor de la mano que CONVERGEN formando el bloque, que va creciendo en la mano; tres cristales giran alrededor y la escarcha se
##                                       extiende bajo los pies (`pies`). Sutil, SIN brillo. Si se sostiene más, «respira». NO hace falta `lanzar()`.
##   progreso_carga() -> float           0 → 1 (se queda en 1 al sostener, y tras soltar)
##   soltar(dir)                         ESE MISMO bloque (mismo nodo) pasa a proyectil apuntando a `dir`; si estaba a medio crecer se asienta al tamaño final en T_SOLTAR s sin salto.
##   cancelar_carga()                    se encoge y se apaga en T_CANCELAR s y se libera
##   impactar_en(pos, normal, escala)    ImpactoHieloToy GOLPE orientado por la normal (esquirlas, cristales que brotan y se rompen, escarcha, destello); el bloque desaparece en seguida
##   rebotar(pos, normal) -> Vector3     golpe pequeño; el bloque SIGUE; devuelve la dirección reflejada (y el bloque mira hacia ella)
##   terminar_sin_choque()               el hechizo se agota en el aire: el bloque se encoge y se deshace en esquirlas que caen (variante FIN)
##   finalizar(motivo, pos, normal)      atajo para HechizoVivo._terminar(causa)
## `impactar()` (contrato EfectoVfx3D) también funciona. `definir`, `describir`, `desde_hechizo` y `preparar` son los de FuegoToy (figura y tamaño salen del Hechizo).

## 18/11 (Pablo, con una captura de una placa de hielo flotante: «esto puede servir para las plataformas. De momento no lo enlaces a una forma existente, crea una nueva llamada "suelo"»):
## SUELO = una PLACA de hielo tumbada. Semiejes: x z = medio ancho y medio fondo, y = GROSOR (m). No sale de ningún Hechizo (`describir` no la da): se pide con `definir(Figura.SUELO, …)`.
enum Figura { BOLA, MURO, PILAR, BARRERA, HAZ, SUELO }
enum EstadoCarga { NINGUNA, CARGANDO, SOLTANDO, APAGANDO, CANCELANDO }

## HAZ (19/11, Pablo: «haz que el haz se corte y aplique el elemento. Que la corona crezca a partir del impacto»): el haz ha llegado a su punta (o a su tope). Se emite una vez
## por lanzamiento, cuando empieza a crecer la corona. Quien dibuja el golpe (el lab con su dummy) lo usa para aplicar el estado en ese momento. El toy NO congela a nadie.
signal haz_llego

const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const HieloEsquirlas = preload("res://presentacion/vfx/toy/hielo_esquirlas.gd")
const CargaHielo = preload("res://presentacion/vfx/toy/carga_hielo_toy.gd")

## Tamaños de referencia (iguales a los de FuegoToy: un hechizo cambia de elemento sin cambiar de tamaño).
const REF_BOLA: Vector3 = Vector3(0.4, 0.4, 0.4)
const REF_MURO: Vector3 = Vector3(3.45, 1.5, 0.3)
const REF_PILAR: Vector3 = Vector3(0.5, 4.0, 0.5)
const REF_BARRERA: Vector3 = Vector3(1.5, 1.5, 1.5)
const REF_HAZ: Vector3 = Vector3(1.5, 0.5, 0.15)
const REF_SUELO: Vector3 = Vector3(1.6, 0.22, 1.3)      ## placa de referencia: 3,2 × 2,6 m y 22 cm de grosor
## 18/11 (Pablo, con un vídeo de una estatua que escupe frío: «ejemplo de haz de hielo»): el HAZ es un ALIENTO DE FRÍO, no solo una lanza. Sobre la lanza de siempre, afinada
## (`HAZ_AGUJA`: una aguja de hielo dentro del chorro), van: un NÚCLEO azul a lo largo del haz (dos láminas cruzadas, mezcla normal: el hielo no es luz), un CHORRO de vaho
## pálido que corre de la mano a la punta (humo toon) y una NUBE de escarcha en la punta. A false, la lanza de antes.
const HAZ_ALIENTO: bool = true
## 19/11 (Pablo: «quita los cristales en el haz de hielo, fíjate más en lo que pase: debe sentirse como un viento helado»): el haz ya NO dibuja cristales (ni lanza ni púas, ni
## esquirlas al irse). Es aire que corre: RÁFAGAS (trazos finos y largos que vuelan de la mano a la punta girando alrededor del eje), COPOS (motas de hielo que el aire arrastra),
## el vaho estirado en la dirección del chorro y el núcleo azul, más tenue. La lista de cristales se conserva SIN ANCHO (no se ve): lleva los escalones con los que el haz se alarga.
const HAZ_SIN_CRISTALES: bool = true
const HAZ_RAFAGAS: int = 16
const HAZ_RAFAGA_VEL: Vector2 = Vector2(1.7, 2.8)       ## largos del haz por segundo a los que corre cada ráfaga
const HAZ_RAFAGA_LARGO: Vector2 = Vector2(0.18, 0.42)   ## largo de la ráfaga, en largos del haz
const HAZ_RAFAGA_ANCHO: Vector2 = Vector2(0.02, 0.05)   ## ancho (m)
const HAZ_RAFAGA_GIRO: float = 5.0                      ## rad por largo de haz que gira alrededor del eje (la hélice del viento)
const HAZ_RAFAGA_COLOR: Color = Color(0.86, 0.96, 1.0, 0.8)
const HAZ_COPOS: int = 30
const HAZ_COPO_TAM: Vector2 = Vector2(0.02, 0.05)
const HAZ_COPO_COLOR: Color = Color(0.6, 0.93, 1.0)
## 19/11 (Pablo, con un vídeo de un «ice breath»: «para el inicio el cast debe extender la mano y aparecer este sello; desde ahí debe canalizarse un haz de hielo (como un viento
## helado) que congele al impacto; te pongo una refe para los pies»). Interpretación de Claude: «los pies» = el pie del haz, donde da.
##   SELLO: un círculo mágico de copo de nieve (hielo_sello.gdshader) delante de la mano, de cara al haz. Se abre PRIMERO (`HAZ_SELLO_FRAC` del nacer) y el haz sale de él
##   después; gira despacio mientras se canaliza; al morir el haz se va antes y el sello se cierra el último.
##   CORONA: donde da el haz crece en el suelo una corona de cristales inclinados hacia fuera (en los tres escalones del hielo), con su mancha de escarcha; se queda mientras
##   el haz da y se rompe al final.
## A false, el haz sin sello ni corona.
const HAZ_SELLO: bool = true
const T_NACER_HAZ_SELLO: float = 0.9
const HAZ_SELLO_FRAC: float = 0.3                       ## fracción del nacer en la que solo se abre el sello (el haz sale después)
const HAZ_SELLO_DIAM: float = 2.4                       ## diámetro del sello, en radios del haz…
const HAZ_SELLO_DIAM_MIN: float = 0.7                   ## …y como poco esto (m)
const HAZ_SELLO_GIRO: float = 0.7                       ## rad/s
const SH_SELLO: String = "res://presentacion/vfx/toy/hielo_sello.gdshader"
const HAZ_CORONA: bool = true                          ## la corona de cristales y la escarcha donde da el haz (a false, solo el sello)
const HAZ_CORONA_N: int = 13                            ## cristales de la corona del impacto
const HAZ_CORONA_RADIO: float = 1.7                     ## radio de la corona, en radios del haz
const HAZ_CORONA_ALTO: Vector2 = Vector2(0.35, 0.95)    ## alto de sus cristales (m, del más bajo al más alto)
const HAZ_CORONA_CRECE_S: float = 0.55                  ## s que tarda en crecer desde que el haz llega
const HAZ_AGUJA: float = 0.45                           ## grosor de la lanza y de sus púas, en veces el de antes
const HAZ_NUCLEO_ANCHO: float = 1.2                     ## ancho de las láminas del núcleo, en radios del haz
const HAZ_NUCLEO_COLOR: Color = Color(0.62, 0.86, 1.0, 0.5)      ## centro de la lámina
const HAZ_NUCLEO_BORDE: Color = Color(0.22, 0.55, 1.0, 0.0)      ## hacia los lados: azul más hondo y transparente
const HAZ_VAHO_POR_S: float = 40.0                      ## bocanadas por segundo del chorro
const HAZ_VAHO_RESERVA: int = 48
const HAZ_VAHO_VIDA_S: float = 0.6
const HAZ_VAHO_TAM: Vector2 = Vector2(0.55, 1.7)         ## diámetro de la bocanada al nacer y al final, en radios del haz (con 1,6 → 4,6 era una nube que lo tapaba todo)
const HAZ_VAHO_CLARO: Color = Color(0.9, 0.97, 1.0)
const HAZ_VAHO_SOMBRA: Color = Color(0.55, 0.8, 1.0)
const HAZ_VAHO_VIEJO: Color = Color(0.7, 0.86, 0.98)
const HumoToyHielo = preload("res://presentacion/vfx/toy/humo_toy.gd")
## INICIO Y FINAL DEL MURO DE HIELO (18/11, Pablo: «ahora haz el inicio y final del muro de hielo»). Mismo esquema que los muros de fuego y de tierra, con el carácter del hielo
## (crece por escalones y se rompe). Solo dibujo. A false, el muro de antes (todos los cristales a la vez, rotura al azar).
##   INICIO (`T_NACER_MURO`): en la primera parte (`MURO_AVISO_FRAC`) una lengua de ESCARCHA corre por el suelo del centro a los dos extremos, con vaho en sus frentes; después
##   los cristales crecen en sus tres escalones, los del centro primero y los de los extremos los últimos.
##   FINAL (`T_MORIR`, sin cambiar): tiembla y se agrieta, y los cristales estallan en orden, de los EXTREMOS al CENTRO, con vaho; la escarcha es lo último que se derrite.
const MURO_INICIO_FINAL: bool = true
const T_NACER_MURO: float = 1.25
const MURO_AVISO_FRAC: float = 0.28                     ## fracción del nacer en la que la escarcha llega a los extremos (antes de que asome ningún cristal)
const MURO_ESCALON_FRAC: float = 0.3                    ## retraso de los cristales de los extremos respecto a los del centro (fracción del nacer)
const MURO_ROMPE_DESDE: float = 0.12                    ## fracción del morir a la que estalla el primer cristal (los de los extremos)
const MURO_ROMPE_TRAMO: float = 0.4                     ## …y en esta fracción estallan todos, hacia el centro
const MURO_VAHO_POR_S: float = 22.0
const MURO_VAHO_VIDA_S: float = 0.5
## 19/11 (Pablo, con una captura de la barrera: «esa pared del fondo, ¿qué es?» … «mejor quítala porque no se lee bien»): la barrera de hielo ya NO lleva la cúpula (la esfera facetada
## tenue que envolvía la jaula: su cara trasera se leía como una pared). Queda la jaula de cristales y la escarcha. A true, vuelve.
const BARRERA_CUPULA: bool = false
const SUELO_GROSOR_MIN: float = 0.08
const SUELO_GROSOR_MAX: float = 0.6
const SUELO_OPACIDAD: float = 0.8
const SUELO_GRIETA: float = 0.3                         ## grietas que la placa lleva siempre (0 = lisa, 1 = las de justo antes de romperse)
const SUELO_ROMPE: float = 0.5                          ## fracción de `corte` a la que la placa se parte (antes tiembla y se agrieta del todo)
const SUELO_ESQUIRLAS: int = 26                         ## esquirlas que suelta al partirse (por placa de referencia; con el área)

const T_SOLTAR: float = 0.14            ## s que tarda en asentarse al tamaño final al soltar si estaba respirando o sin acabar de crecer
const T_APAGAR: float = 0.5             ## s que tarda en encogerse el fin sin choque
const T_CANCELAR: float = 0.2
const RESPIRO_HZ: float = 1.4
const GIRO_QUIETA: float = 0.7          ## rad/s a los que gira el bloque quieto
const GIRO_VUELO: float = 3.2           ## ... y en vuelo
const T_COLA: float = 0.16              ## s que tarda en salir la estela al empezar a volar
const T_NACER: float = 0.9              ## muro, pilar y barrera: tres escalones de 0,09 s con mesetas de 0,27 s
const T_NACER_HAZ: float = 0.6
const T_NACER_BOLA: float = 0.45
const T_MORIR: float = 0.9
const T_MORIR_HAZ: float = 0.8
const T_MORIR_BOLA: float = 0.5
const ESQ_BOLA: int = 40                ## huecos de la reserva de esquirlas de cada figura
const ESQ_HAZ: int = 72
const ESQ_PILAR: int = 64
const ESQ_MURO: int = 96
const ESQ_BARRERA: int = 80

@export_group("Figura y ejes (m)")
@export var figura: Figura = Figura.BOLA: set = _set_figura
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_x: float = 0.4: set = _set_x
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_y: float = 0.4: set = _set_y
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_z: float = 0.4: set = _set_z
@export var viaja: bool = false: set = _set_viaja
## Los cristales crecen con `crece` (0 → 1, en tres escalones; lo anima «nacer») y se rompen con `corte` (0 → 1; lo anima «morir»).
@export_range(0.0, 1.0, 0.01) var crece: float = 1.0: set = _set_crece
@export_range(0.0, 1.0, 0.01) var corte: float = 0.0: set = _set_corte
@export_group("Carga del hechizo")
@export_range(0.03, 0.6, 0.01) var carga_tam_inicial: float = 0.12
@export_range(0.3, 3.0, 0.05) var carga_curva: float = 0.8
@export_range(0, 36, 1) var carga_chispas: int = 28: set = _set_carga_chispas      ## esquirlas que convergen en la mano (la cuarta parte al principio)
@export_range(0.0, 3.0, 0.05) var carga_destello: float = 1.0                      ## sin uso en el hielo (no hay destello en la carga); existe para que los mandos del lab valgan para todos
@export_range(0.0, 0.2, 0.005) var carga_respiro: float = 0.05
@export_range(0.0, 3.0, 0.05) var carga_brillo: float = 1.0: set = _set_carga_brillo       ## opacidad de las órbitas, las esquirlas y la escarcha (el hielo no brilla)
@export_range(0.5, 2.0, 0.05) var carga_radio: float = 1.0: set = _set_carga_radio         ## × el radio de la nube de esquirlas
@export var carga_bola_visible: bool = true: set = _set_carga_bola_visible              ## true: el bloque se va formando en la mano (por defecto); false: solo esquirlas, y el bloque aparece al soltar
@export_group("Impacto")
## true: al impactar, en vez del golpe de un proyectil, estalla en ÁREA (ImpactoHieloToy.Variante.AREA). `desde_hechizo` lo pone en las zonas.
@export var area_al_impactar: bool = false
@export_group("Mundo")
## Dónde están los pies respecto al nodo (local, -Z = delante): ahí se extiende la escarcha del casteo.
@export var pies: Vector3 = Vector3(0, -0.7, 0.5)
## Altura (m) del nodo sobre el suelo: las esquirlas que caen por debajo de ella se quedan en el suelo.
@export var altura_suelo: float = 0.7

var _construido: bool = false
var _pendiente: bool = false
var _figura_anim: int = -1
var _silencio: bool = false
var _est: int = EstadoCarga.NINGUNA
var _c_t: float = 0.0
var _c_dur: float = 1.0
var _c_r: float = 0.4
var _c_prog: float = 0.0
var _c_escala: float = 1.0
var _c_desde: float = 1.0
var _c_nodo: Node3D = null
var _c_visual: Node3D = null            ## CargaHielo: esquirlas que convergen, órbitas y escarcha
var _pop: bool = false
var _esq: Node3D = null                 ## reserva de esquirlas (HieloEsquirlas), top_level
var _acc_esq: float = 0.0
var _ult_pos: Vector3 = Vector3.ZERO
var _tiene_ult: bool = false
var _vel_mundo: Vector3 = Vector3.ZERO
var _cola_f: float = 0.0
var _inclinable: Node3D = null          ## BOLA: lleva las púas y la estela, y gira
var _puas: MultiMeshInstance3D = null
var _estela: MultiMeshInstance3D = null
var _bloque: MeshInstance3D = null
var _cris: Array = []                   ## figuras de volumen: los cristales (HieloMallas._c)
var _cris_mm: MultiMeshInstance3D = null
var _roto: Array = []                   ## ¿ha estallado ya el cristal j?
var _suelo: MeshInstance3D = null       ## escarcha de la base
var _placa: MeshInstance3D = null       ## SUELO: la losa de hielo
var _aliento: Node3D = null             ## HAZ: el chorro de vaho (humo toon, en el mundo)
var _nucleo: Array = []                 ## HAZ: las dos láminas del núcleo azul
var _acc_aliento: float = 0.0
## HAZ: algo lo PARA antes de su largo. `haz_tope` = m de la mano a la cara de lo que toca (≤ 0: nada, llega a su largo); `haz_tope_radio` = radio de eso (m): la corona crece
## alrededor de su pie, no debajo. Hay que ponerlos ANTES de construir el haz (antes de entrar en el árbol o de `definir`).
var haz_tope: float = -1.0
var haz_tope_radio: float = 0.0
## HAZ que ATRAVIESA lo que toca (enemigos y objetos en el juego; 19/11, opción 19b): el haz se dibuja ENTERO (no se corta) pero la corona y la escarcha crecen alrededor del pie de eso.
## `haz_impacto` = m de la mano al CENTRO de lo que toca (≤ 0: nada); `haz_impacto_radio` = su radio (m). Si hay `haz_tope`, manda el tope. Mismo momento que los anteriores: antes de construir el haz.
var haz_impacto: float = -1.0
var haz_impacto_radio: float = 0.0
var _z_corona: float = 0.0                  ## HAZ: m (hacia -Z) del centro de la corona
var _haz_llegado: bool = false
var _haz_saliendo: bool = false           ## el haz ha empezado a salir desde cero (lanzado): recién creado está entero (`crece` 1) y eso NO es llegar
var _sello: MeshInstance3D = null           ## HAZ: el círculo mágico de la mano
var _corona: MultiMeshInstance3D = null    ## HAZ: cristales que crecen donde da
var _cor: Array = []
var _corona_t: float = 0.0
var _escarcha_punta: MeshInstance3D = null
var _giro_sello: float = 0.0
var _rafagas: MultiMeshInstance3D = null      ## HAZ: trazos del viento helado
var _raf: Array = []
var _copos: MultiMeshInstance3D = null        ## HAZ: motas de hielo que arrastra
var _cop: Array = []
var _placa_rota: bool = false
var _cupula: MeshInstance3D = null      ## BARRERA: cúpula de cristal muy tenue
var _punta: MeshInstance3D = null       ## HAZ: destello de la punta
var _haz_largo: float = 3.0
var _haz_alt: float = 0.5
var _haz_r: float = 0.36
var _bola_rota: bool = false
var _giro_bola: float = 0.0
var _escalon_ref: float = 0.0           ## (pruebas) último valor de la función de escalones
var _h_act: Array = []                  ## (pruebas) alto (m) de cada cristal en el último `_avanzar_cristales`


func _ready() -> void:
	_construir()
	super._ready()
	_construido = true
	_set_proyectil(viaja)
	_montar_esquirlas()
	_avanzar_cristales(0.0)


# ------------------------------------------------------------------ interfaz ------------------------------------------------------------------

func _set_figura(v: Figura) -> void:
	figura = v
	_pedir()


func _set_crece(v: float) -> void:
	crece = v


func _set_corte(v: float) -> void:
	corte = v


func _set_x(v: float) -> void:
	semieje_x = maxf(v, 0.05)
	_pedir()


func _set_y(v: float) -> void:
	semieje_y = maxf(v, 0.05)
	_pedir()


func _set_z(v: float) -> void:
	semieje_z = maxf(v, 0.05)
	_pedir()


func _set_viaja(v: bool) -> void:
	viaja = v
	_pedir()


## Pone figura, ejes y vuelo de una vez y reconstruye una sola vez.
func definir(fig: int, x: float, y: float, z: float, vuela: bool = false) -> void:
	_silencio = true
	figura = fig as Figura
	semieje_x = maxf(x, 0.05)
	semieje_y = maxf(y, 0.05)
	semieje_z = maxf(z, 0.05)
	viaja = vuela
	_silencio = false
	if _construido:
		reconstruir()


func _pedir() -> void:
	if _silencio:
		return
	if _construido and is_inside_tree() and not _pendiente:
		_pendiente = true
		call_deferred("reconstruir")


## Vuelve a hacer la geometría con los ejes actuales (los mandos y la animación se conservan).
func reconstruir() -> void:
	_pendiente = false
	if not is_inside_tree() or not _construido:
		return
	_listo = false
	_construir()
	proyectil = viaja
	_recoger()
	_set_proyectil(viaja)
	_montar_esquirlas()
	_avanzar_cristales(0.0)


func semiejes() -> Vector3:
	return Vector3(semieje_x, semieje_y, semieje_z)


func esta_cargando() -> bool:
	return _est == EstadoCarga.CARGANDO


func progreso_carga() -> float:
	return _c_prog


## Escala actual del cuerpo respecto al tamaño final (1 = tamaño del proyectil).
func escala_carga() -> float:
	return _c_escala


# ------------------------------------------------------------------ carga, suelta e impacto ------------------------------------------------------------------

func empezar_carga(duracion: float, tam_final: Variant = null) -> void:
	var r: float = maxf(semieje_x, semieje_z)
	if tam_final is Vector3:
		r = maxf((tam_final as Vector3).x, (tam_final as Vector3).z)
	elif tam_final is float or tam_final is int:
		r = float(tam_final)
	r = maxf(r, 0.05)
	_c_r = r
	definir(Figura.BOLA, r, r, r, false)
	proyectil = false
	_aplicar_vuelo(false)
	aparicion = 1.0
	if _ap != null:
		_ap.stop()
	_c_dur = maxf(duracion, 0.05)
	_c_t = 0.0
	_c_prog = 0.0
	_c_escala = carga_tam_inicial
	_est = EstadoCarga.CARGANDO
	_pop = false
	_bola_rota = false
	if _cuerpo != null:
		_cuerpo.visible = carga_bola_visible
	_montar_carga()
	_aplicar_escala_carga()


func soltar(dir: Vector3 = Vector3.ZERO) -> void:
	if dir.length() > 0.001 and is_inside_tree():
		var d: Vector3 = dir.normalized()
		look_at(global_position + d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
	_silencio = true
	viaja = true
	_silencio = false
	proyectil = true
	_aplicar_vuelo(true)
	if _cuerpo != null and not _cuerpo.visible:
		_cuerpo.visible = true                        # el MISMO bloque aparece con un pequeño «pop»
		_pop = true
		_c_desde = 0.5
		_c_escala = 0.5
		_aplicar_escala_carga()
	else:
		_pop = false
		_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.SOLTANDO
	_quitar_visual_carga(0.12)


func cancelar_carga() -> void:
	if _est == EstadoCarga.CANCELANDO:
		return
	_quitar_visual_carga(0.15)
	_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.CANCELANDO


func _set_carga_chispas(v: int) -> void:
	carga_chispas = v
	if _c_visual != null and is_instance_valid(_c_visual):
		_c_visual.call("poner_gotas", v)


func _set_carga_brillo(v: float) -> void:
	carga_brillo = v
	if _c_visual != null and is_instance_valid(_c_visual):
		_c_visual.call("poner_brillo", v)


func _set_carga_radio(v: float) -> void:
	carga_radio = v
	if _c_visual != null and is_instance_valid(_c_visual):
		_c_visual.call("poner_radio", v)


func _set_carga_bola_visible(v: bool) -> void:
	carga_bola_visible = v
	if _est == EstadoCarga.CARGANDO and _cuerpo != null:
		_cuerpo.visible = v


## Las esquirlas, las órbitas y la escarcha de la carga se desvanecen en `dur` s y se liberan solas.
func _quitar_visual_carga(dur: float) -> void:
	if _c_visual != null and is_instance_valid(_c_visual):
		_c_visual.call("salir", dur)


func _escala_de_carga(p: float) -> float:
	var g: float = smoothstep(0.0, 1.0, pow(clampf(p, 0.0, 1.0), carga_curva))
	return lerpf(carga_tam_inicial, 1.0, g)


## Aplica la escala de la carga al cuerpo (junto con la de «aparicion», que usa EfectoToy).
func _aplicar_escala_carga() -> void:
	if _cuerpo != null:
		var v: float = aparicion
		_cuerpo.scale = Vector3(lerpf(0.65, 1.0, v), lerpf(0.15, 1.0, v), lerpf(0.65, 1.0, v)) * _c_escala


func _avanzar_carga(delta: float) -> void:
	match _est:
		EstadoCarga.CARGANDO:
			_c_t += delta
			var p: float = clampf(_c_t / _c_dur, 0.0, 1.0)
			_c_prog = p
			var g: float = _escala_de_carga(p)
			var env: float = smoothstep(0.55, 1.0, p)
			var resp: float = sin(_c_t * TAU * RESPIRO_HZ)
			_c_escala = g * (1.0 + carga_respiro * env * resp)
			_aplicar_escala_carga()
			if _c_visual != null and is_instance_valid(_c_visual):
				_c_visual.call("poner", _c_escala, p)
		EstadoCarga.SOLTANDO:
			_c_t += delta
			var u: float = clampf(_c_t / T_SOLTAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 1.0, smoothstep(0.0, 1.0, u)) + (0.07 * sin(u * PI) if _pop else 0.0)
			_aplicar_escala_carga()
			if u >= 1.0:
				_est = EstadoCarga.NINGUNA
				_c_escala = 1.0
				_aplicar_escala_carga()
		EstadoCarga.CANCELANDO:
			_c_t += delta
			var u2: float = clampf(_c_t / T_CANCELAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 0.0, u2 * u2)
			_aplicar_escala_carga()
			if u2 >= 1.0:
				_est = EstadoCarga.NINGUNA
				queue_free()
		EstadoCarga.APAGANDO:
			_c_t += delta
			var u3: float = clampf(_c_t / T_APAGAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 0.0, u3 * u3)
			_vida_erosion(1.0 - u3 * u3)                  # la misma rampa que el encogido: la bola se come por ruido mientras se encoge
			_aplicar_escala_carga()
			if u3 >= 1.0:
				_est = EstadoCarga.NINGUNA
				_c_escala = 0.001
				_aplicar_escala_carga()
				get_tree().create_timer(0.85).timeout.connect(queue_free)      # deja caer las esquirlas que quedan en el mundo


## Esquirlas, órbitas y escarcha del casteo (CargaHielo). Cuelga de un nodo «Carga» que no escala con el bloque.
func _montar_carga() -> void:
	var viejo: Node = get_node_or_null("Carga")
	if viejo != null:
		remove_child(viejo)
		viejo.free()
	_c_nodo = Node3D.new()
	_c_nodo.name = "Carga"
	add_child(_c_nodo)
	_c_visual = CargaHielo.new()
	_c_visual.name = "Convergencia"
	_c_nodo.add_child(_c_visual)
	_c_visual.call("montar", _c_r, carga_chispas, carga_brillo, carga_radio, pies)


func _radio_impacto(escala: float) -> float:
	return escala if escala > 0.0 else maxf(semieje_x, semieje_z)


func _crear_impacto(variante: ImpactoHieloToy.Variante, normal: Vector3, escala: float, pos: Vector3) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var imp: ImpactoHieloToy = ImpactoHieloToy.crear(variante, normal, _radio_impacto(escala))
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


func _quitar_vuelo() -> void:
	_quitar_visual_carga(0.05)


## Las esquirlas sueltas siguen cayendo aunque el bloque desaparezca: la reserva pasa al padre y se libera sola al cabo de un par de segundos.
func _soltar_esquirlas() -> void:
	if _esq == null or not is_instance_valid(_esq) or get_parent() == null or not is_inside_tree():
		return
	var padre: Node = get_parent()
	remove_child(_esq)
	padre.add_child(_esq)
	_esq.top_level = true
	get_tree().create_timer(2.0).timeout.connect(_esq.queue_free)
	_esq = null


## Explosión de ÁREA de hielo (ImpactoHieloToy.Variante.AREA) en `pos` (sobre el suelo, normal arriba) con `radio` m de radio: corona de cristales que brotan, escarcha ancha y esquirlas. No toca al bloque.
func explotar_area(pos: Vector3, radio: float = -1.0) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var r: float = radio if radio > 0.0 else maxf(maxf(semieje_x, semieje_z), 0.3)
	var imp: ImpactoHieloToy = ImpactoHieloToy.crear(ImpactoHieloToy.Variante.AREA, Vector3.UP, r)
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


func impactar_en(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Node3D:
	var imp: Node3D
	if area_al_impactar:
		imp = explotar_area(pos, escala)
	else:
		imp = _crear_impacto(ImpactoHieloToy.Variante.GOLPE, normal, escala, pos)
	_est = EstadoCarga.NINGUNA
	_bola_rota = true                             # el impacto ya trae sus esquirlas: el bloque no se rompe además
	_quitar_vuelo()
	_soltar_esquirlas()
	if _ap != null and _ap.has_animation("morir"):
		_ap.speed_scale = 4.0                     # el bloque se apaga en 0,12 s mientras el golpe se abre
	morir()
	return imp


func rebotar(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Vector3:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var d: Vector3 = -global_transform.basis.z if is_inside_tree() else Vector3.FORWARD
	var nd: Vector3 = (d - 2.0 * d.dot(n) * n).normalized()
	_crear_impacto(ImpactoHieloToy.Variante.REBOTE, n, escala, pos)
	if is_inside_tree():
		global_position = pos
		look_at(pos + nd, Vector3.UP if absf(nd.y) < 0.99 else Vector3.FORWARD)
		_ult_pos = pos
	if _esq != null and is_instance_valid(_esq):
		_esq.call("vaciar")                       # la cola vieja apuntaba a la pared
	_cola_f = 0.3
	return nd


func terminar_sin_choque() -> void:
	if _est == EstadoCarga.APAGANDO or _est == EstadoCarga.CANCELANDO:
		return
	_crear_impacto(ImpactoHieloToy.Variante.FIN, Vector3.UP, -1.0, global_position)
	_bola_rota = true
	_quitar_vuelo()
	_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.APAGANDO


## Atajo para HechizoVivo._terminar(causa): qué hace el bloque según el motivo del fin.
func finalizar(motivo: String, pos: Vector3 = Vector3.INF, normal: Vector3 = Vector3.UP) -> void:
	var p: Vector3 = global_position if pos == Vector3.INF else pos
	match motivo:
		"golpe", "muro", "suelo":
			impactar_en(p, normal)
		"retorno":
			cancelar_carga()
		_:
			terminar_sin_choque()


## Contrato de EfectoVfx3D: sin datos de superficie, la normal es hacia atrás del vuelo (o arriba si va a ras de suelo).
func impactar() -> void:
	var n: Vector3 = global_transform.basis.z.normalized() if proyectil else Vector3.UP
	if global_position.y < 0.3:
		n = Vector3.UP
	impactar_en(global_position, n)


## Una bola que muere sin impacto (su vida se acabó): el bloque se rompe en esquirlas además de apagarse. Las demás figuras se rompen solas con `corte`.
func morir() -> void:
	if figura == Figura.BOLA and not _bola_rota and _esq != null and is_instance_valid(_esq) and is_inside_tree():
		_bola_rota = true
		_romper_bola()
	super.morir()


## Escala el efecto a un volumen de hechizo ({x, y, z} en casillas) sin escalar el nodo: la geometría se rehace con los semiejes en metros.
func preparar(volumen: Dictionary, dir: Vector3, _elemento: String = "hielo") -> void:
	semieje_x = maxf(float(volumen.get("x", 0.5)) * casilla, 0.05)
	semieje_y = maxf(float(volumen.get("y", 0.5)) * casilla, 0.05)
	semieje_z = maxf(float(volumen.get("z", 0.5)) * casilla, 0.05)
	var plano: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if plano.length() > 0.01 and is_inside_tree():
		look_at(global_position + plano, Vector3.UP)
	if _construido:
		reconstruir()


## Elige figura, tamaño y vuelo desde un `Hechizo` (la misma regla que FuegoToy.describir: el elemento no cambia la figura ni el tamaño).
func desde_hechizo(h: Hechizo) -> void:
	var d: Dictionary = describir(h, casilla)
	definir(int(d["figura"]), d["x"], d["y"], d["z"], d["viaja"])
	rotation.y = float(d["giro_y"])
	# una zona (esfera o elipsoide que no viaja ni es muro, pilar, barrera ni haz) estalla en área al acabar; un proyectil, no
	area_al_impactar = int(d["figura"]) == Figura.BOLA and not bool(d["viaja"])


static func describir(h: Hechizo, casilla_m: float = 2.3) -> Dictionary:
	return FuegoToy.describir(h, casilla_m)


## Radio «grande» del efecto, en metros: lo usan la cámara del lab.
func extension() -> float:
	return FuegoToy._extension(int(figura) as FuegoToy.Figura, semieje_x, semieje_y, semieje_z)


static func _extension_ref(fig: int) -> float:
	return FuegoToy._extension_ref(fig as FuegoToy.Figura)


# ------------------------------------------------------------------ construcción ------------------------------------------------------------------

func _construir() -> void:
	var cuerpo: Node3D = get_node_or_null("Cuerpo") as Node3D
	if cuerpo == null:
		cuerpo = Node3D.new()
		cuerpo.name = "Cuerpo"
		add_child(cuerpo)
	for h in cuerpo.get_children():
		cuerpo.remove_child(h)
		h.free()
	_inclinable = null
	_puas = null
	_estela = null
	_bloque = null
	_cris = []
	_cris_mm = null
	_roto = []
	_suelo = null
	_cupula = null
	_placa = null
	_placa_rota = false
	_aliento = null
	_nucleo = []
	_acc_aliento = 0.0
	_sello = null
	_corona = null
	_cor = []
	_corona_t = 0.0
	_escarcha_punta = null
	_rafagas = null
	_raf = []
	_copos = null
	_cop = []
	_punta = null
	tam_referencia = Vector3(semieje_x, semieje_y, semieje_z) * 2.0
	_avance_cabeza = 0.0
	match figura:
		Figura.BOLA:
			_bola(cuerpo)
		Figura.HAZ:
			_haz(cuerpo)
		Figura.PILAR:
			_pilar(cuerpo)
		Figura.MURO:
			_muro(cuerpo)
		Figura.SUELO:
			_suelo_placa(cuerpo)
		_:
			_barrera(cuerpo)
	_anim_si_hace_falta()


func _mi_hielo(c: Node3D, nombre: String, malla: Mesh, mat: ShaderMaterial) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = malla
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(mi)
	return mi


## Los cristales de una figura de volumen: un MultiMesh con el reparto `capa` (se corta a HieloMallas.MAX_CRISTALES).
func _montar_cristales(c: Node3D, capa: Array, semilla: float) -> void:
	if capa.size() > HieloMallas.MAX_CRISTALES:
		capa = capa.slice(0, HieloMallas.MAX_CRISTALES)
	_cris = capa
	_roto = []
	_roto.resize(_cris.size())
	_roto.fill(false)
	_cris_mm = HieloMallas.crear_mm("Cristales", _cris.size(), HieloMallas.cristal(6, semilla), 0.62, 1)
	c.add_child(_cris_mm)


func _escarcha_base(c: Node3D, ancho_x: float, ancho_z: float, pos: Vector3 = Vector3.ZERO) -> void:
	_suelo = HieloMallas.escarcha("Escarcha", 0.7, randf())
	_suelo.position = pos + Vector3(0, 0.012, 0)
	_suelo.scale = Vector3(ancho_x, 1.0, ancho_z)
	_suelo.set_meta("ancho", Vector2(ancho_x, ancho_z))
	c.add_child(_suelo)


# ------------------------------------------------------------------ BOLA ------------------------------------------------------------------

## Bloque de hielo (icosfera de 80 facetas, rugosa) con púas de cristal que giran con él; en vuelo salen detrás cristales largos y finos.
func _bola(c: Node3D) -> void:
	var r: float = maxf(semieje_x, semieje_z)
	var sem: float = randf() * 10.0
	_bloque = _mi_hielo(c, "Esfera", HieloMallas.bloque(0.09, sem), HieloMallas.material(HieloMallas.SH_CRISTAL, {"opacidad": 0.6, "escarcha_base": 0.0, "semilla": sem}, 0))
	_bloque.scale = Vector3(r, r * semieje_y / maxf(r, 0.001), r)
	_inclinable = Node3D.new()
	_inclinable.name = "Inclinable"
	c.add_child(_inclinable)
	var puas: Array = HieloMallas.puas_bola(r, 7, sem)
	_puas = HieloMallas.crear_mm("Puas", puas.size(), HieloMallas.cristal(6, sem + 1.0), 0.66, 1)
	_inclinable.add_child(_puas)
	for i in puas.size():
		var d: Dictionary = puas[i]
		HieloMallas.poner(_puas.multimesh, i, d["pos"], d["rot"], float(d["wx"]), float(d["h"]), float(d["wz"]), float(d["claro"]), 0.95, float(d["fase"]))
	var est: Array = HieloMallas.estela_bola(r, 4, sem + 2.0)
	_estela = HieloMallas.crear_mm("Estela", est.size(), HieloMallas.cristal(6, sem + 2.0), 0.55, 1)
	_estela.set_meta("capa", est)
	_inclinable.add_child(_estela)
	_estela.visible = false


# ------------------------------------------------------------------ MURO ------------------------------------------------------------------

## MURO DE HIELO. Semiejes: x = ANCHO (se tiende a lo largo de x), y = ALTO de los cristales más altos, z = fondo. Dos filas de cristales (la de delante más baja y fina), más altos hacia el centro; escarcha en el pie.
func _muro(c: Node3D) -> void:
	var capa: Array = HieloMallas.capa_muro(semieje_x, semieje_z, semieje_y, 1.0 + semieje_x)
	if MURO_INICIO_FINAL:
		for d in capa:
			var lejos: float = clampf(absf((d["pos"] as Vector3).x) / maxf(semieje_x, 0.01), 0.0, 1.0)
			d["retraso"] = MURO_AVISO_FRAC + MURO_ESCALON_FRAC * lejos + float(d["retraso"]) * 0.3
			d["rompe"] = MURO_ROMPE_DESDE + MURO_ROMPE_TRAMO * (1.0 - lejos) + float(d["rompe"]) * 0.08
		_aliento = HumoToyHielo.new()                                        # el vaho del muro (el mismo humo toon del aliento del haz)
		_aliento.name = "Vaho"
		c.add_child(_aliento)
		_aliento.call("montar", 30, {"claro": HAZ_VAHO_CLARO, "sombra": HAZ_VAHO_SOMBRA, "viejo": HAZ_VAHO_VIEJO, "tam_ini": 0.22, "tam_fin": 0.7, "vida": MURO_VAHO_VIDA_S,
			"deriva": Vector3(0, 0.3, 0), "mundo": true, "opacidad": 0.6})
	_montar_cristales(c, capa, 2.0)
	_escarcha_base(c, 2.0 * semieje_x + 0.9, 2.0 * semieje_z + 1.3, Vector3(0, 0, 0))


# ------------------------------------------------------------------ PILAR ------------------------------------------------------------------

## PILAR DE HIELO. Semiejes: x z = radios de la base, y = ALTO de la espiga central (m). Origen en el suelo, centrado.
func _pilar(c: Node3D) -> void:
	_montar_cristales(c, HieloMallas.capa_pilar(semieje_x, semieje_z, semieje_y, 1.0 + semieje_y), 3.0)
	_escarcha_base(c, 2.0 * semieje_x * 2.4 + 0.5, 2.0 * semieje_z * 2.4 + 0.5)


# ------------------------------------------------------------------ BARRERA ------------------------------------------------------------------

## BARRERA DE HIELO. Elipsoide x y z con el centro a 0,4·y sobre el suelo (como la del fuego): una jaula de cristales sobre la elipse del suelo inclinados hacia dentro, y una cúpula de cristal muy tenue.
func _barrera(c: Node3D) -> void:
	_montar_cristales(c, HieloMallas.capa_barrera(semieje_x, semieje_y, semieje_z, 1.0 + semieje_x), 4.0)
	if BARRERA_CUPULA:
		_cupula = _mi_hielo(c, "Cupula", HieloMallas.bloque(0.04, 7.0), HieloMallas.material(HieloMallas.SH_CRISTAL, {"opacidad": 0.13, "escarcha_base": 0.0, "rim_pot": 2.6}, 0))
		_cupula.position = Vector3(0, 0.4 * semieje_y, 0)
		_cupula.scale = Vector3(semieje_x, semieje_y, semieje_z)
	_escarcha_base(c, 2.0 * semieje_x * 1.3, 2.0 * semieje_z * 1.3)


# ------------------------------------------------------------------ SUELO ------------------------------------------------------------------

## PLACA DE HIELO (figura SUELO). Semiejes: x z = medio ancho y medio fondo, y = grosor. Una losa translúcida de contorno irregular con sus grietas, el canto blanco de cristalitos de
## escarcha y un halo de escarcha en el suelo alrededor. Crece desde el centro en los tres escalones del hielo; al morir tiembla, se agrieta, se parte en esquirlas y la escarcha se derrite.
func _suelo_placa(c: Node3D) -> void:
	var g: float = clampf(semieje_y, SUELO_GROSOR_MIN, SUELO_GROSOR_MAX)
	var sem: float = 6.0 + semieje_x
	_placa = _mi_hielo(c, "Placa", HieloMallas.placa(sem), HieloMallas.material(HieloMallas.SH_CRISTAL, {"opacidad": SUELO_OPACIDAD, "escarcha_base": 0.85, "grieta": SUELO_GRIETA, "semilla": sem}, 0))
	_placa.scale = Vector3(semieje_x, g, semieje_z)
	_montar_cristales(c, HieloMallas.capa_borde_placa(semieje_x, semieje_z, g, sem), 6.0)
	_escarcha_base(c, 2.0 * semieje_x * 1.22 + 0.3, 2.0 * semieje_z * 1.22 + 0.3)


## SUELO: la placa sigue a `crece` (se extiende desde el centro por escalones) y a `corte` (se agrieta, tiembla y se parte).
func _avanzar_placa(esc: float, co: float, tt: float) -> void:
	if _placa == null or not is_instance_valid(_placa):
		return
	var g: float = clampf(semieje_y, SUELO_GROSOR_MIN, SUELO_GROSOR_MAX) * altura
	var k: float = lerpf(0.12, 1.0, esc)
	var entera: float = 1.0 - smoothstep(SUELO_ROMPE, SUELO_ROMPE + 0.08, co)
	_placa.scale = Vector3(semieje_x * ancho * k, maxf(g * lerpf(0.3, 1.0, esc), 0.001), semieje_z * ancho * k) if (esc > 0.001 and entera > 0.001) else Vector3.ONE * 0.0001
	_placa.position = Vector3(sin(tt * 53.0), 0.0, cos(tt * 47.0)) * 0.012 * minf(co * 6.0, 1.0) if co > 0.0 else Vector3.ZERO
	var m: ShaderMaterial = _placa.material_override as ShaderMaterial
	m.set_shader_parameter("grieta", maxf(SUELO_GRIETA, smoothstep(0.0, SUELO_ROMPE * 0.8, co)))
	m.set_shader_parameter("opacidad", SUELO_OPACIDAD * entera)
	if co <= 0.001:
		_placa_rota = false
	elif co > SUELO_ROMPE and not _placa_rota:
		_placa_rota = true
		if _esq != null and is_instance_valid(_esq) and is_inside_tree():
			_esq.set("suelo_y", global_position.y - 0.02)
			var tr: Transform3D = global_transform
			var n: int = int(round(float(SUELO_ESQUIRLAS) * clampf(semieje_x * semieje_z / (REF_SUELO.x * REF_SUELO.z), 0.3, 2.5) * clampf(chispas, 0.0, 1.0)))
			for q in n:
				var loc: Vector3 = Vector3(randf_range(-0.9, 0.9) * semieje_x, g * randf_range(0.3, 1.0), randf_range(-0.9, 0.9) * semieje_z)
				var fuera: Vector3 = Vector3(loc.x, 0.0, loc.z).normalized() if Vector2(loc.x, loc.z).length() > 0.01 else Vector3.RIGHT
				_esq.call("emitir", tr * loc, tr.basis * (fuera * randf_range(0.3, 1.4) + Vector3(0, randf_range(0.8, 2.2), 0)), randf_range(0.8, 1.3), randf_range(0.07, 0.18), 0.88, randf(), Vector3.ZERO)


# ------------------------------------------------------------------ HAZ ------------------------------------------------------------------

## HAZ DE HIELO: una lanza que NACE de un punto en el origen (la mano) hacia -Z a la altura máx(y, 0,4), con púas a lo largo y un destello en la punta. `crece` la alarga en tres escalones y `corte` la rompe de la
## mano hacia fuera (la punta es lo último).
func _haz(c: Node3D) -> void:
	_haz_largo = semieje_x * 2.0
	if haz_tope > 0.0:
		_haz_largo = minf(_haz_largo, haz_tope)                                # se corta en lo que toca
	# dónde crece la corona: tras el tope (su cara + su radio); si no hay tope, en el centro de lo que atraviesa (dentro del largo dibujado); si no, en la punta
	if haz_tope > 0.0:
		_z_corona = -_haz_largo - haz_tope_radio
	elif haz_impacto > 0.0:
		_z_corona = -minf(haz_impacto, _haz_largo)
	else:
		_z_corona = -_haz_largo
	_haz_r = semieje_z * FuegoToy.HAZ_ABRE
	_haz_alt = maxf(semieje_y, 0.4)
	var capa: Array = HieloMallas.capa_haz(_haz_largo, _haz_r, _haz_alt, 1.0 + semieje_x)
	for d in capa:
		var dist: float = clampf(-(d["pos"] as Vector3).z / maxf(_haz_largo, 0.01), 0.0, 1.0)
		d["rompe"] = clampf(dist * 0.55, 0.0, 0.55) if float(d["h"]) < _haz_largo * 0.9 else 0.3
		if HAZ_ALIENTO:
			d["wx"] = 0.0 if HAZ_SIN_CRISTALES else float(d["wx"]) * HAZ_AGUJA
			d["wz"] = 0.0 if HAZ_SIN_CRISTALES else float(d["wz"]) * HAZ_AGUJA
			if HAZ_SIN_CRISTALES:
				d["esq"] = 0                                                  # ni esquirlas al irse: el viento no se rompe
	_montar_cristales(c, capa, 5.0)
	_punta = HieloMallas.destello("Punta")
	_punta.position = Vector3(0, _haz_alt, -_haz_largo)
	c.add_child(_punta)
	if not HAZ_ALIENTO:
		return
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([HAZ_NUCLEO_BORDE, HAZ_NUCLEO_COLOR, HAZ_NUCLEO_BORDE])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 64
	gt.height = 4
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	for k2 in 2:
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2.ONE
		var sm: StandardMaterial3D = StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.albedo_texture = gt
		sm.albedo_color = Color(1, 1, 1, 0)
		sm.render_priority = -1
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Nucleo%d" % k2
		mi.mesh = q
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.add_child(mi)
		_nucleo.append(mi)
	_aliento = HumoToyHielo.new()
	_aliento.name = "Aliento"
	c.add_child(_aliento)
	_aliento.call("montar", HAZ_VAHO_RESERVA, {"claro": HAZ_VAHO_CLARO, "sombra": HAZ_VAHO_SOMBRA, "viejo": HAZ_VAHO_VIEJO, "tam_ini": HAZ_VAHO_TAM.x * _haz_r, "tam_fin": HAZ_VAHO_TAM.y * _haz_r,
		"vida": HAZ_VAHO_VIDA_S, "deriva": Vector3(0, 0.15, 0), "mundo": true, "opacidad": 0.7})
	if HAZ_SELLO:
		var qs: QuadMesh = QuadMesh.new()
		qs.size = Vector2.ONE * minf(maxf(_haz_r * HAZ_SELLO_DIAM, HAZ_SELLO_DIAM_MIN), _haz_alt * 1.9)           # nunca más que la altura de la mano: con 6,5 radios el suelo lo cortaba por la mitad
		var msello: ShaderMaterial = ShaderMaterial.new()                    # material propio: el sello no usa las texturas ni la paleta que pone HieloMallas.material
		msello.shader = load(SH_SELLO)
		msello.render_priority = 2
		msello.set_shader_parameter("vida", 0.0)
		msello.set_shader_parameter("abre", 0.0)
		_sello = _mi_hielo(c, "Sello", qs, msello)
		_sello.position = Vector3(0, _haz_alt, -0.12)                           # el quad mira a ±Z: de cara al haz
		if HAZ_CORONA:
			var rngc: RandomNumberGenerator = RandomNumberGenerator.new()
			rngc.seed = 97
			var rc: float = _haz_r * HAZ_CORONA_RADIO
			for i in HAZ_CORONA_N:
				var ang: float = TAU * float(i) / float(HAZ_CORONA_N) + rngc.randf_range(-0.2, 0.2)
				var dd: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
				var r_blanco: float = haz_tope_radio if haz_tope > 0.0 else (haz_impacto_radio if haz_impacto > 0.0 else 0.0)
				var rr: float = r_blanco + rc * rngc.randf_range(0.25 if r_blanco <= 0.0 else 0.1, 1.0)
				var hh: float = rngc.randf_range(HAZ_CORONA_ALTO.x, HAZ_CORONA_ALTO.y) * lerpf(1.0, 0.6, rr / maxf(rc, 0.01))
				var ww: float = hh * rngc.randf_range(0.13, 0.2)
				_cor.append({"pos": Vector3(dd.x * rr, 0.0, _z_corona + dd.z * rr), "rot": HieloMallas._inclinar(dd, rngc.randf_range(0.55, 1.05), rngc.randf() * TAU), "w": ww, "h": hh,
					"claro": rngc.randf(), "fase": rngc.randf(), "retraso": rngc.randf_range(0.0, 0.35)})
			_corona = HieloMallas.crear_mm("Corona", _cor.size(), HieloMallas.cristal(6, 9.0), 0.7, 1)
			c.add_child(_corona)
			_escarcha_punta = HieloMallas.escarcha("EscarchaPunta", 0.7, 0.4)
			_escarcha_punta.position = Vector3(0, 0.012, _z_corona)
			_escarcha_punta.set_meta("lado", (rc + (haz_tope_radio if haz_tope > 0.0 else (haz_impacto_radio if haz_impacto > 0.0 else 0.0))) * 2.6)
			c.add_child(_escarcha_punta)
	if not HAZ_SIN_CRISTALES:
		return
	if _punta != null:
		_punta.visible = false                                               # el destello de cristal de la punta tampoco: en la punta hay nube
	for tipo in 2:
		var n: int = HAZ_RAFAGAS if tipo == 0 else HAZ_COPOS
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var qm: QuadMesh = QuadMesh.new()
		qm.size = Vector2.ONE
		mm.mesh = qm
		mm.instance_count = n
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "Rafagas" if tipo == 0 else "Copos"
		mmi.multimesh = mm
		var sm2: StandardMaterial3D = StandardMaterial3D.new()
		sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm2.cull_mode = BaseMaterial3D.CULL_DISABLED
		if tipo == 0:
			sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm2.albedo_color = HAZ_RAFAGA_COLOR
		else:
			sm2.albedo_color = HAZ_COPO_COLOR
			sm2.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			sm2.billboard_keep_scale = true
		mmi.material_override = sm2
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3.ONE * -40.0, Vector3.ONE * 80.0)
		c.add_child(mmi)
		for i in n:
			var it: Dictionary = {"p": randf(), "ang": randf() * TAU, "r": randf_range(0.25, 1.35), "vel": randf_range(HAZ_RAFAGA_VEL.x, HAZ_RAFAGA_VEL.y) * (1.0 if tipo == 0 else 0.7),
				"largo": randf_range(HAZ_RAFAGA_LARGO.x, HAZ_RAFAGA_LARGO.y), "ancho": randf_range(HAZ_RAFAGA_ANCHO.x, HAZ_RAFAGA_ANCHO.y), "tam": randf_range(HAZ_COPO_TAM.x, HAZ_COPO_TAM.y), "fase": randf() * TAU}
			if tipo == 0:
				_raf.append(it)
			else:
				_cop.append(it)
		if tipo == 0:
			_rafagas = mmi
		else:
			_copos = mmi


## HAZ, aliento de frío: el núcleo azul se alarga con la lanza y se apaga con `corte`; el vaho sale de la mano y corre hasta la punta mientras el haz vive, con más nube en la punta.
func _avanzar_aliento(delta: float, cr: float, co: float) -> void:
	if _nucleo.is_empty():
		return
	var largo: float = maxf(-_haz_z_punta(), 0.001)
	var ch: float = _crece_haz()
	var vive: float = smoothstep(0.0, 0.15, ch) * (1.0 - smoothstep(0.05, 0.5, co))
	_avanzar_sello_y_corona(delta, cr, ch, co)
	var w: float = _haz_r * HAZ_NUCLEO_ANCHO * ancho
	for k2 in _nucleo.size():
		var mi: MeshInstance3D = _nucleo[k2]
		if mi == null or not is_instance_valid(mi):
			continue
		# el quad mide 1 × 1 en su XY: su X se pone a lo ancho (tumbada: X del mundo; de canto: Y) y su Y a lo largo del haz (−Z)
		var eje_x: Vector3 = (Vector3.RIGHT if k2 == 0 else Vector3.UP) * w
		var eje_y: Vector3 = Vector3.FORWARD * largo
		mi.transform = Transform3D(Basis(eje_x, eje_y, eje_x.cross(eje_y).normalized()), Vector3(0, _haz_alt, -largo * 0.5))
		(mi.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, vive)
	_avanzar_viento_helado(delta, largo, vive)
	if delta <= 0.0 or vive <= 0.05 or _aliento == null or not is_instance_valid(_aliento) or not is_inside_tree():
		return
	var tr: Transform3D = global_transform
	_acc_aliento += HAZ_VAHO_POR_S * clampf(chispas, 0.0, 1.0) * delta
	while _acc_aliento >= 1.0:
		_acc_aliento -= 1.0
		var en_punta: bool = randf() < 0.3
		var z0: float = -largo * (randf_range(0.85, 1.0) if en_punta else randf_range(0.0, 0.25))
		var loc: Vector3 = Vector3(randf_range(-1.0, 1.0) * _haz_r, _haz_alt + randf_range(-1.0, 1.0) * _haz_r, z0)
		# el del chorro corre hacia la punta (con la fricción del humo llega más o menos a ella); el de la punta se abre en nube
		var vel: Vector3 = Vector3(randf_range(-0.6, 0.6), randf_range(-0.1, 0.5), randf_range(-0.6, 0.3)) if en_punta else Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.2), -largo * 2.3)
		_aliento.call("emitir", tr * loc, tr.basis * vel, randf_range(0.85, 1.15), randf_range(0.8, 1.2) * (1.25 if en_punta else 1.0), -1.0, 1.0 if en_punta else 1.7)       # el del chorro, estirado: jirón, no bola


## HAZ: el sello se abre antes que el haz (con un pequeño sobrepaso), gira mientras se canaliza y se cierra el último; la corona crece en el suelo donde da el haz, por escalones,
## desde que llega, y se rompe al final.
func _avanzar_sello_y_corona(delta: float, cr: float, ch: float, co: float) -> void:
	if _sello != null and is_instance_valid(_sello):
		_giro_sello += HAZ_SELLO_GIRO * delta
		var ab: float = smoothstep(0.0, HAZ_SELLO_FRAC, cr)
		ab = ab * (1.0 + 0.18 * sin(ab * PI)) * (1.0 - smoothstep(0.55, 0.97, co))
		var ms: ShaderMaterial = _sello.material_override as ShaderMaterial
		ms.set_shader_parameter("abre", ab)
		ms.set_shader_parameter("giro", _giro_sello)
		ms.set_shader_parameter("vida", smoothstep(0.0, 0.06, cr) * (1.0 - smoothstep(0.8, 1.0, co)))
	if _corona == null or not is_instance_valid(_corona):
		return
	if ch >= 0.97 and co < 0.55:
		if _haz_saliendo and not _haz_llegado and delta > 0.0:
			_haz_llegado = true
			haz_llego.emit()                                                     # el impacto: desde aquí crece la corona
		_corona_t += delta
	elif cr <= 0.001:
		_corona_t = 0.0
		_haz_llegado = false
		_haz_saliendo = true
	var g: float = clampf(_corona_t / HAZ_CORONA_CRECE_S, 0.0, 1.0)
	var rota: float = 1.0 - smoothstep(0.6, 0.85, co)
	var mm: MultiMesh = _corona.multimesh
	for i in _cor.size():
		var d: Dictionary = _cor[i]
		var ret: float = float(d["retraso"])
		var f: float = escalon(clampf((g - ret) / maxf(1.0 - ret, 0.01), 0.0, 1.0)) * rota
		if f <= 0.001:
			HieloMallas.ocultar(mm, i)
		else:
			HieloMallas.poner(mm, i, d["pos"], d["rot"], float(d["w"]) * ancho, float(d["h"]) * altura * f, float(d["w"]) * ancho, float(d["claro"]), 0.95, float(d["fase"]))
	if _escarcha_punta != null and is_instance_valid(_escarcha_punta):
		var lado: float = float(_escarcha_punta.get_meta("lado", 1.0)) * lerpf(0.25, 1.0, escalon(g))
		_escarcha_punta.scale = Vector3(lado, 1.0, lado)
		var me: ShaderMaterial = _escarcha_punta.material_override as ShaderMaterial
		me.set_shader_parameter("u", escalon(g))
		me.set_shader_parameter("vida", 0.9 * smoothstep(0.0, 0.1, g) * (1.0 - smoothstep(0.7, 1.0, co)))


## (pruebas) apertura del sello (0-1,x), cristales de la corona visibles y cuánto ha crecido (0-1).
func estado_sello() -> Dictionary:
	var n: int = 0
	if _corona != null and is_instance_valid(_corona):
		for i in _cor.size():
			if _corona.multimesh.get_instance_transform(i).basis.get_scale().y > 0.01:
				n += 1
	return {"abre": float((_sello.material_override as ShaderMaterial).get_shader_parameter("abre")) if (_sello != null and is_instance_valid(_sello)) else -1.0,
		"corona": n, "crecida": clampf(_corona_t / HAZ_CORONA_CRECE_S, 0.0, 1.0), "largo": -_haz_z_punta(), "largo_total": _haz_largo, "z_corona": -_z_corona}


## HAZ, viento helado: las ráfagas y los copos corren de la mano a la punta (`p` 0 → 1 y vuelta a empezar), girando alrededor del eje; nacen y se apagan en los extremos.
func _avanzar_viento_helado(delta: float, largo: float, vive: float) -> void:
	var oculto: Transform3D = Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3(0, -50, 0))
	if _rafagas != null and is_instance_valid(_rafagas):
		var mm: MultiMesh = _rafagas.multimesh
		for i in _raf.size():
			var it: Dictionary = _raf[i]
			it["p"] = fposmod(float(it["p"]) + float(it["vel"]) * delta, 1.0)
			var pr: float = float(it["p"])
			var k2: float = sin(pr * PI) * vive
			if k2 <= 0.02:
				mm.set_instance_transform(i, oculto)
				continue
			var ang: float = float(it["ang"]) + pr * HAZ_RAFAGA_GIRO
			var rr: float = _haz_r * float(it["r"]) * lerpf(0.6, 1.25, pr)                       # el chorro se abre un poco hacia la punta
			var radial: Vector3 = Vector3(cos(ang), sin(ang), 0.0)
			var lr: float = largo * float(it["largo"])
			var centro: Vector3 = Vector3(radial.x * rr, _haz_alt + radial.y * rr, -largo * pr)
			# el quad (1 × 1 en su XY): su Y a lo largo del haz, su X en la tangente del giro (se ve fino desde cualquier lado porque cada una mira distinto)
			var eje_y: Vector3 = (Vector3.FORWARD + Vector3(-radial.y, radial.x, 0.0) * 0.12).normalized() * lr
			var eje_x: Vector3 = Vector3(-radial.y, radial.x, 0.0) * float(it["ancho"]) * k2
			mm.set_instance_transform(i, Transform3D(Basis(eje_x, eje_y, eje_x.cross(eje_y).normalized()), centro))
	if _copos != null and is_instance_valid(_copos):
		var mc: MultiMesh = _copos.multimesh
		var tt: float = Time.get_ticks_msec() * 0.001
		for i in _cop.size():
			var ic: Dictionary = _cop[i]
			ic["p"] = fposmod(float(ic["p"]) + float(ic["vel"]) * delta, 1.0)
			var pc: float = float(ic["p"])
			var kc: float = sin(pc * PI) * vive * (0.6 + 0.4 * sin(tt * 11.0 + float(ic["fase"])))
			if kc <= 0.02:
				mc.set_instance_transform(i, oculto)
				continue
			var ac: float = float(ic["ang"]) + pc * HAZ_RAFAGA_GIRO * 0.7
			var rc: float = _haz_r * float(ic["r"]) * lerpf(0.7, 1.5, pc)
			var tam: float = float(ic["tam"]) * kc
			mc.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(tam, tam, tam)), Vector3(cos(ac) * rc, _haz_alt + sin(ac) * rc, -largo * pc)))


## Posición local de la punta de la lanza con `crece` actual.
func _haz_z_punta() -> float:
	return -_escalon(_crece_haz()) * _haz_largo * 0.97


## `crece` del HAZ descontando el tramo en que solo se abre el sello (con sello, el haz empieza a salir a `HAZ_SELLO_FRAC`).
func _crece_haz() -> float:
	if not (HAZ_ALIENTO and HAZ_SELLO) or _sello == null:
		return crece
	return clampf((crece - HAZ_SELLO_FRAC) / (1.0 - HAZ_SELLO_FRAC), 0.0, 1.0)


# ------------------------------------------------------------------ crecer y romperse ------------------------------------------------------------------

## Los tres escalones: 0 → 0,34 → 0,67 → 1 con una meseta entre cada uno (cada subida ocupa el 10 % de `c`).
static func escalon(c: float) -> float:
	return 0.34 * smoothstep(0.0, 0.1, c) + 0.33 * smoothstep(0.33, 0.43, c) + 0.33 * smoothstep(0.66, 0.76, c)


func _escalon(c: float) -> float:
	_escalon_ref = escalon(c)
	return _escalon_ref


## (pruebas) Alto actual (m) de cada cristal, y cuántos han estallado ya.
func alturas_actuales() -> Array:
	return _h_act


func rotos() -> int:
	var n: int = 0
	for r in _roto:
		if bool(r):
			n += 1
	return n


## Posición, tamaño y estado de cada cristal según `crece` (escalones, con su retraso) y `corte` (tiembla, se agrieta y estalla a su hora). Cuando un cristal estalla suelta sus esquirlas.
func _avanzar_cristales(delta: float) -> void:
	if _cris_mm == null or not is_instance_valid(_cris_mm) or _cris.is_empty():
		return
	var mm: MultiMesh = _cris_mm.multimesh
	var cr: float = clampf(crece, 0.0, 1.0)
	var co: float = clampf(corte, 0.0, 1.0)
	var tt: float = Time.get_ticks_msec() * 0.001
	_h_act = []
	for j in _cris.size():
		var c: Dictionary = _cris[j]
		var ret: float = float(c["retraso"])
		var s: float = _escalon(clampf((cr - ret) / maxf(1.0 - ret, 0.01), 0.0, 1.0))
		var tb: float = float(c["rompe"])
		var rompe: float = 1.0 - smoothstep(tb, tb + 0.06, co)
		if co > tb + 0.02 and not bool(_roto[j]):
			_roto[j] = true
			_emitir_rotura(c, s)
		elif co <= 0.001:
			_roto[j] = false
		var pos: Vector3 = c["pos"]
		if figura == Figura.SUELO:
			pos *= lerpf(0.12, 1.0, _escalon(cr))                             # el canto de cristalitos va con el borde de la placa mientras se extiende
		if co > 0.0 and rompe > 0.001:                                     # antes de estallar, tiembla
			pos += Vector3(sin(tt * 53.0 + float(j) * 1.7), 0.0, cos(tt * 47.0 + float(j))) * 0.012 * minf(co * 6.0, 1.0)
		var f: float = s * rompe
		_h_act.append(float(c["h"]) * altura * f)
		HieloMallas.poner(mm, j, pos, c["rot"], float(c["wx"]) * ancho, float(c["h"]) * altura * f, float(c["wz"]) * ancho, float(c["claro"]), 0.95 if f > 0.001 else 0.0, float(c["fase"]))
	var ms: ShaderMaterial = _cris_mm.material_override as ShaderMaterial
	ms.set_shader_parameter("grieta", smoothstep(0.0, 0.35, co))
	var esc: float = _escalon(cr)
	_avanzar_placa(esc, co, tt)
	if _suelo != null and is_instance_valid(_suelo):
		var an: Vector2 = _suelo.get_meta("ancho", Vector2.ONE)
		var k: float = lerpf(0.3, 1.0, esc)
		_suelo.scale = Vector3(an.x * k, 1.0, an.y * k)
		var mf: ShaderMaterial = _suelo.material_override as ShaderMaterial
		mf.set_shader_parameter("u", esc)
		mf.set_shader_parameter("vida", 0.9 * smoothstep(0.0, 0.12, cr) * (1.0 - smoothstep(0.45, 1.0, co)))
		if figura == Figura.MURO and MURO_INICIO_FINAL:
			# la escarcha corre por el suelo ANTES que los cristales (del centro a los extremos) y es lo último que se derrite
			var kx: float = smoothstep(0.0, MURO_AVISO_FRAC, cr)
			_suelo.scale = Vector3(an.x * lerpf(0.06, 1.0, kx), 1.0, an.y * lerpf(0.45, 1.0, maxf(kx * 0.6, esc)))
			mf.set_shader_parameter("u", maxf(esc, kx))
			mf.set_shader_parameter("vida", 0.9 * smoothstep(0.0, 0.04, cr) * (1.0 - smoothstep(0.62, 1.0, co)))
			_avanzar_vaho_muro(delta, cr, co, kx)
	if _cupula != null and is_instance_valid(_cupula):
		var kc: float = maxf(esc * (1.0 - smoothstep(0.1, 0.5, co)), 0.001)
		_cupula.scale = Vector3(semieje_x, semieje_y, semieje_z) * kc
		_cupula.position = Vector3(0, 0.4 * semieje_y * kc, 0)
	_avanzar_aliento(delta, cr, co)
	if _punta != null and is_instance_valid(_punta):
		var vive: float = smoothstep(0.7, 1.0, cr) * (1.0 - smoothstep(0.0, 0.3, co))
		_punta.position = Vector3(0, _haz_alt, _haz_z_punta())
		var sz: float = _haz_r * 2.6 * (0.85 + 0.15 * sin(tt * 11.0))
		_punta.scale = Vector3(sz, sz, 1.0) if vive > 0.001 else Vector3.ONE * 0.001
		var mp: ShaderMaterial = _punta.material_override as ShaderMaterial
		mp.set_shader_parameter("vida", 0.9 * vive)
		mp.set_shader_parameter("giro", tt * 0.4)
	if co >= 0.98 and _esq != null and is_instance_valid(_esq) and is_inside_tree():
		_soltar_esquirlas()                                                  # todo roto: las esquirlas se quedan en el mundo cuando el nodo se libere


## MURO: vaho en los dos frentes de la escarcha mientras corre y, al morir, por donde van estallando los cristales (de los extremos al centro).
func _avanzar_vaho_muro(delta: float, cr: float, co: float, kx: float) -> void:
	if delta <= 0.0 or _aliento == null or not is_instance_valid(_aliento) or not is_inside_tree():
		return
	var naciendo: bool = cr > 0.0 and cr < MURO_AVISO_FRAC + 0.08 and co <= 0.0
	var rompiendo: bool = co > MURO_ROMPE_DESDE * 0.5 and co < MURO_ROMPE_DESDE + MURO_ROMPE_TRAMO
	if not naciendo and not rompiendo:
		return
	var tr: Transform3D = global_transform
	_acc_aliento += MURO_VAHO_POR_S * clampf(chispas, 0.0, 1.0) * delta
	while _acc_aliento >= 1.0:
		_acc_aliento -= 1.0
		var lado: float = 1.0 if randf() < 0.5 else -1.0
		# al nacer, en el frente de la escarcha; al morir, a la altura de los cristales que están estallando (el frente va de los extremos al centro)
		var frente: float = kx if naciendo else 1.0 - clampf((co - MURO_ROMPE_DESDE) / MURO_ROMPE_TRAMO, 0.0, 1.0)
		var x: float = lado * semieje_x * clampf(frente + randf_range(-0.12, 0.08), 0.0, 1.0)
		var y: float = 0.08 if naciendo else semieje_y * randf_range(0.1, 0.7)
		_aliento.call("emitir", tr * Vector3(x, y, randf_range(-1.0, 1.0) * maxf(semieje_z, 0.15)), tr.basis * Vector3(lado * randf_range(0.1, 0.5), randf_range(0.1, 0.4), randf_range(-0.3, 0.3)),
			randf_range(0.85, 1.15), randf_range(0.8, 1.3) * (1.0 if naciendo else 1.4))


## Un cristal estalla: suelta sus esquirlas desde varios puntos de su eje, hacia fuera de la figura y arriba.
func _emitir_rotura(c: Dictionary, _escalon_actual: float) -> void:
	if _esq == null or not is_instance_valid(_esq) or not is_inside_tree():
		return
	_esq.set("suelo_y", global_position.y - 0.02)
	var tr: Transform3D = global_transform
	var base: Vector3 = c["pos"]
	var rot: Basis = c["rot"]
	var h: float = float(c["h"]) * altura
	var w: float = float(c["wx"]) * ancho
	var n: int = int(round(float(c["esq"]) * clampf(chispas, 0.0, 1.0)))
	for k in n:
		var loc: Vector3 = base + rot * Vector3(0, h * randf_range(0.1, 0.9), 0)
		var fuera: Vector3 = Vector3(loc.x, 0.0, loc.z) if figura != Figura.HAZ else Vector3(loc.x, loc.y - _haz_alt, 0.0)
		fuera = fuera.normalized() if fuera.length() > 0.01 else Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
		var vel: Vector3 = tr.basis * (fuera * randf_range(0.4, 1.8) + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 1.6), randf_range(-0.5, 0.5)))
		_esq.call("emitir", tr * loc, vel, randf_range(0.8, 1.3), clampf(w * randf_range(0.8, 1.5), 0.05, 0.2), 0.88, randf(), Vector3.ZERO)


## La bola que muere sin impacto: unas 18 esquirlas de la superficie del bloque.
func _romper_bola() -> void:
	var r: float = maxf(semieje_x, semieje_z) * clampf(_c_escala, 0.1, 1.5)
	var tr: Transform3D = global_transform
	_esq.set("suelo_y", global_position.y - altura_suelo)
	for k in 18:
		var d: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_esq.call("emitir", tr * (d * r * randf_range(0.3, 1.0)), tr.basis * (d * randf_range(0.6, 2.0)) + _vel_mundo * 0.3, randf_range(0.7, 1.2), randf_range(0.05, 0.12) * sqrt(maxf(r / 0.4, 0.4)), 0.88, randf(), Vector3.ZERO)


func _anim_si_hace_falta() -> void:
	var ap: AnimationPlayer = get_node_or_null("Anim") as AnimationPlayer
	if ap != null and _figura_anim == int(figura):
		return
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "Anim"
		add_child(ap)
	_figura_anim = int(figura)
	var es_vol: bool = figura != Figura.BOLA                       # las figuras de volumen no se encogen: animan `crece` (nacer) y `corte` (morir)
	var nacer: float = T_NACER_BOLA
	var morir_s: float = T_MORIR_BOLA
	if figura == Figura.HAZ:
		nacer = T_NACER_HAZ_SELLO if (HAZ_ALIENTO and HAZ_SELLO) else T_NACER_HAZ
		morir_s = T_MORIR_HAZ
	elif figura == Figura.MURO and MURO_INICIO_FINAL:
		nacer = T_NACER_MURO
		morir_s = T_MORIR
	elif es_vol:
		nacer = T_NACER
		morir_s = T_MORIR
	var lib: AnimationLibrary = AnimationLibrary.new()
	for nom in ["nacer", "vivir", "morir"]:
		var an: Animation = Animation.new()
		var pista: int = an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(pista, NodePath(".:crece" if (es_vol and nom == "nacer") else (".:corte" if es_vol else ".:aparicion")))
		match nom:
			"nacer":
				an.length = nacer
				if es_vol:
					an.track_insert_key(pista, 0.0, 0.0)
					an.track_insert_key(pista, nacer, 1.0)               # lineal: los escalones los pone la función `escalon`
				else:
					for kv in [[0.0, 0.0], [0.10, 0.38], [0.18, 0.42], [0.28, 0.72], [0.36, 0.76], [0.45, 1.0]]:         # el bloque crece en tres escalones
						an.track_insert_key(pista, float(kv[0]), float(kv[1]))
				an.track_set_interpolation_type(pista, Animation.INTERPOLATION_LINEAR)
			"vivir":
				an.length = 1.0
				an.loop_mode = Animation.LOOP_LINEAR
				an.track_insert_key(pista, 0.0, 0.0 if es_vol else 1.0)
			"morir":
				an.length = morir_s
				an.track_insert_key(pista, 0.0, 0.0 if es_vol else 1.0)
				an.track_insert_key(pista, morir_s, 1.0 if es_vol else 0.0)
				an.track_set_interpolation_type(pista, Animation.INTERPOLATION_LINEAR if es_vol else Animation.INTERPOLATION_CUBIC)
		lib.add_animation(nom, an)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	dura_morir = morir_s


# ------------------------------------------------------------------ vuelo y esquirlas ------------------------------------------------------------------

func _set_proyectil(v: bool) -> void:
	proyectil = v
	_aplicar_vuelo(v)


## En vuelo gira más deprisa y sale la estela de cristales; quieto, gira despacio y no hay estela.
func _aplicar_vuelo(v: bool) -> void:
	if not _listo or _inclinable == null:
		return
	if _estela != null:
		_estela.visible = v
		if not v:
			_cola_f = 0.0
	if v and _cola_f <= 0.0:
		_cola_f = 0.0001


## Reserva de esquirlas de la figura. Si la figura cambia, se rehace.
func _montar_esquirlas() -> void:
	var cap: int = 0
	match figura:
		Figura.BOLA:
			cap = ESQ_BOLA
		Figura.HAZ:
			cap = ESQ_HAZ
		Figura.PILAR:
			cap = ESQ_PILAR
		Figura.MURO:
			cap = ESQ_MURO
		Figura.BARRERA:
			cap = ESQ_BARRERA
	if _esq != null and is_instance_valid(_esq) and int(_esq.call("capacidad")) == cap:
		return
	if _esq != null and is_instance_valid(_esq):
		remove_child(_esq)
		_esq.free()
	_esq = null
	if cap == 0:
		return
	_esq = HieloEsquirlas.new()
	_esq.name = "Esquirlas"
	add_child(_esq)
	_esq.call("montar", cap)


func _process(delta: float) -> void:
	super._process(delta)
	_avanzar_carga(delta)
	_avanzar_bola(delta)
	_avanzar_cristales(delta)
	_emitir_esquirlas(delta)


func _avanzar_bola(delta: float) -> void:
	if _inclinable == null or not is_instance_valid(_inclinable):
		return
	var vuela: bool = proyectil and _est != EstadoCarga.APAGANDO
	_giro_bola += (GIRO_VUELO if vuela else GIRO_QUIETA) * velocidad * delta
	if vuela:
		_inclinable.rotation = Vector3(0, 0, _giro_bola)             # en vuelo gira sobre el eje del vuelo (-Z)
	else:
		_inclinable.rotation = Vector3(0.35, _giro_bola, 0)
	if _bloque != null and is_instance_valid(_bloque):
		_bloque.rotation = _inclinable.rotation
	if _estela != null and _estela.visible:
		_cola_f = minf(_cola_f + delta / T_COLA, 1.0)
		var f: float = smoothstep(0.0, 1.0, _cola_f)
		var capa: Array = _estela.get_meta("capa", [])
		for i in capa.size():
			var d: Dictionary = capa[i]
			HieloMallas.poner(_estela.multimesh, i, d["pos"], d["rot"], float(d["wx"]), float(d["h"]) * f, float(d["wz"]), float(d["claro"]), 0.9, float(d["fase"]))


## Esquirlas que se desprenden del bloque en vuelo y caen: salen por detrás y heredan algo de la velocidad.
func _emitir_esquirlas(delta: float) -> void:
	if _esq == null or not is_instance_valid(_esq) or not _listo or delta <= 0.0 or not is_inside_tree():
		return
	if figura != Figura.BOLA:
		if figura == Figura.HAZ:
			_emitir_haz(delta)
		return
	var pos: Vector3 = global_position
	if _tiene_ult:
		_vel_mundo = (pos - _ult_pos) / delta
	_ult_pos = pos
	_tiene_ult = true
	if _cuerpo == null or not _cuerpo.visible or _est == EstadoCarga.CANCELANDO or _est == EstadoCarga.APAGANDO:
		return
	var vuela: bool = proyectil
	var tasa: float = (12.0 if vuela else 1.2) * clampf(chispas, 0.0, 1.0) * clampf(_c_escala, 0.0, 1.0)
	_acc_esq += tasa * delta
	var r: float = maxf(semieje_x, semieje_z) * clampf(_c_escala, 0.1, 1.5)
	_esq.set("suelo_y", pos.y - altura_suelo)
	while _acc_esq >= 1.0:
		_acc_esq -= 1.0
		var tam: float = randf_range(0.04, 0.09) * sqrt(maxf(r / 0.4, 0.3))
		if vuela:
			var loc: Vector3 = Vector3(randf_range(-0.5, 0.5) * r, randf_range(-0.5, 0.4) * r, r * randf_range(0.6, 2.4))
			var lat: Vector3 = global_transform.basis * Vector3(randf_range(-1.0, 1.0), randf_range(-0.4, 1.0), randf_range(-0.2, 0.6)) * 0.6
			_esq.call("emitir", global_transform * loc, _vel_mundo * 0.3 + lat, randf_range(0.6, 1.0), tam, 0.88, randf(), Vector3.ZERO)
		else:
			var abajo: Vector3 = pos + Vector3(randf_range(-0.4, 0.4) * r, -0.85 * r, randf_range(-0.4, 0.4) * r)
			_esq.call("emitir", abajo, Vector3(0, -0.3, 0), randf_range(0.6, 0.9), tam * 0.9, 0.88, randf(), Vector3.ZERO)


## El haz suelta esquirlas de la punta mientras vive (se desprenden y caen).
func _emitir_haz(delta: float) -> void:
	var vive: float = smoothstep(0.7, 1.0, crece) * (1.0 - smoothstep(0.0, 0.2, corte)) * clampf(chispas, 0.0, 1.0)
	if vive <= 0.001:
		return
	_esq.set("suelo_y", global_position.y - 0.02)
	_acc_esq += 8.0 * vive * delta
	var tr: Transform3D = global_transform
	while _acc_esq >= 1.0:
		_acc_esq -= 1.0
		var loc: Vector3 = Vector3(randf_range(-0.5, 0.5) * _haz_r, _haz_alt + randf_range(-0.5, 0.5) * _haz_r, _haz_z_punta() * randf_range(0.6, 1.0))
		var vel: Vector3 = tr.basis * Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.8), -randf_range(0.2, 1.2))
		_esq.call("emitir", tr * loc, vel, randf_range(0.6, 1.0), randf_range(0.04, 0.08), 0.88, randf(), Vector3.ZERO)


## Estela que se queda en el mundo (EstelaMundoToy, 25/11/2026): solo la BOLA.
func _estela_elemento() -> String:
	return "hielo" if figura == Figura.BOLA else ""
