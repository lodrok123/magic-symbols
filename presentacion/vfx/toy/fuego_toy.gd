class_name FuegoToy
extends EfectoToy

## FUEGO Â«TOYÂ» PARAMÃ‰TRICO (1/11/2026, rama fuego-toy-parametrico). Un solo efecto que se construye por cÃ³digo a partir de los tres semiejes del hechizo (x ancho, y alto,
## z fondo, en METROS) y de su figura, con los mismos shaders, texturas, rampas y mandos que las cuatro escenas validadas de la prueba 3 (BolaFuegoToy, MuroFuegoToy,
## PilarFuegoToy, BarreraFuegoToy, que no se tocan). Â«La lÃ³gica decide, el VFX representaÂ»: `desde_hechizo(h)` lee `Hechizo` y rellena figura y tamaÃ±os; despuÃ©s da igual
## cÃ³mo cambien los ejes, la geometrÃ­a sale sola (setters + `reconstruir()`).
##   BOLA     billboard de radio mÃ¡x(x, z) y alto y (elipsoide: el quad y su gradiente se estiran en Y), cabeza; con `viaja`: cola, jirones y estelas (proyectil).
##   MURO     banda de 2Â·x de largo, y de alto y 2Â·z de grueso. La textura de lenguas se repite UNA vez cada ~2,9 m de contorno (lo medido en el muro validado): alargar no la estira.
##   PILAR    cilindro abierto de radio x (y z si es distinto: secciÃ³n elÃ­ptica) y altura y.
##   BARRERA  elipsoide de semiejes x, y, z con el shader de la barrera (dos pasadas), la mitad de abajo hundida en el suelo como la validada.
## Origen: la bola, en su CENTRO; muro, pilar y barrera, en el suelo y centrados. Un muro se alarga por su X local (gira el nodo para ponerlo de lado).
## Los nÃºmeros de referencia (r 0,4 la bola; 3,45 Ã— 1,5 Ã— 0,3 el muro; 0,5 Ã— 4 el pilar; 1,5 la barrera) son las medidas de las escenas validadas: con ellas, FuegoToy
## produce lo mismo que esas escenas (ver docs/capturas/comparativa_vfx/godot_toy/parametrico/NOTAS.md).

## HAZ (familia LINEAL): tubo abierto de 2Â·x de largo y radio z que sale del origen (la mano) hacia -Z; el eje va a altura mÃ¡x(y, 0,4). Lenguas que corren a lo largo y punta que se disipa.
enum Figura { BOLA, MURO, PILAR, BARRERA, HAZ }

const DIR: String = "res://presentacion/vfx/toy/"
const TEX: String = "res://assets/vfx/lelu_noise/"
const SH_LELU: String = "res://presentacion/vfx/toy/fuego_lelu.gdshader"
const SH_ATRAS: String = "res://presentacion/vfx/toy/fuego_lelu_atras.gdshader"
const SH_DELANTE: String = "res://presentacion/vfx/toy/fuego_lelu_delante.gdshader"
const SH_BOLA: String = "res://presentacion/vfx/toy/fuego_lelu_bola.gdshader"
const SH_VBB: String = "res://presentacion/vfx/toy/fuego_lelu_vbb.gdshader"
const SH_BARRERA_ATRAS: String = "res://presentacion/vfx/toy/fuego_barrera_atras.gdshader"
const SH_BARRERA_DELANTE: String = "res://presentacion/vfx/toy/fuego_barrera_delante.gdshader"
const SH_BARRERA_LAMIDOS: String = "res://presentacion/vfx/toy/fuego_barrera_lamidos.gdshader"
const SH_ARO: String = "res://presentacion/vfx/toy/aro_barrera.gdshader"
const SH_HAZ: String = "res://presentacion/vfx/toy/haz_toy.gdshader"
## HAZ: radio en el origen (m: casi un hilo) y cuánto se abre (× el radio z del hechizo, que es la mitad del grosor de dibujo del haz).
## PILAR (base irregular): altura máxima (m) a la que sube el borde de contacto con el suelo y cuánto se desdibuja el charco de luz.
const PILAR_BASE_M: float = 0.45
const PILAR_IRREG_CHARCO: float = 0.28
const HAZ_R_ORIGEN: float = 0.012
const HAZ_ABRE: float = 3.0
## HAZ, ideas de la demo de gas de three.js (9/11/2026): salpicadura donde choca, punta de humo y luz en el suelo (ver `_haz`).
const SH_SALPICADURA: String = "res://presentacion/vfx/toy/salpicadura_haz.gdshader"
const SH_LUZ_SUELO: String = "res://presentacion/vfx/toy/luz_suelo_haz.gdshader"
const HAZ_MAX_CHOQUES: int = 2                   ## puntos de choque que dibuja un haz (el final contra el obstáculo y, si hay sitio, el primer enemigo que cruza)
const HAZ_MAX_SALPICADURAS: int = 6              ## tope en TODA la escena (varios dragones relanzando cada 0,8 s): pasado el tope el choque se queda sin salpicadura
const HAZ_MAX_LUCES_SUELO: int = 6               ## ídem para las manchas de luz del suelo (decals)
const HAZ_TOPE_CALOR: float = 0.38               ## tope de la rampa de la bola en el chorro y la salpicadura: naranja con contraste, nunca el tramo amarillo
const HAZ_TOPE_NUCLEO: float = 0.5               ## el núcleo puede llegar un poco más arriba (un naranja claro), pero sigue sin amarillo
const HAZ_LUZ_ANCHO: float = 3.6                 ## m de ancho de la caja del decal de luz del suelo
const HAZ_LUZ_ALTO_MAX: float = 0.45             ## m sobre el suelo: lo más alto (hombros, cabezas) no se pinta
const HAZ_GRUPO_SALPICADURA: StringName = &"salpicadura_haz"
const HAZ_GRUPO_LUZ_SUELO: StringName = &"luz_suelo_haz"
const SH_CABEZA: String = "res://presentacion/vfx/toy/cabeza_toy.gdshader"
const SH_HALO: String = "res://presentacion/vfx/toy/halo_toy.gdshader"
const SH_JIRON: String = "res://presentacion/vfx/toy/jiron_toy.gdshader"
const SH_CHISPA: String = "res://presentacion/vfx/toy/chispa_toy.gdshader"

## TamaÃ±os (semiejes en m) con los que se validÃ³ cada figura en la prueba 3.
const REF_BOLA: Vector3 = Vector3(0.4, 0.4, 0.4)
const REF_MURO: Vector3 = Vector3(3.45, 1.5, 0.3)
const REF_PILAR: Vector3 = Vector3(0.5, 4.0, 0.5)
const REF_BARRERA: Vector3 = Vector3(1.5, 1.5, 1.5)
const REF_HAZ: Vector3 = Vector3(1.5, 0.5, 0.15)          # no validado en la prueba 3: primera versiÃ³n
## BOLA EN VUELO (revisiÃ³n de Pablo 2/11: Â«la bola principal mÃ¡s grande que la estelaÂ»): la cabeza redonda manda y la cola se estrecha hacia atrÃ¡s. Solo actÃºan con `inclin` = 1 (en vuelo).
const CIERRE_VUELO: float = 0.8             ## borde mÃ¡s duro en vuelo: menos puntas alrededor de la cabeza
const CALOR_COLA: float = 0.25              ## el nÃºcleo claro no se alarga por la cola: de la cabeza blanca-amarilla a una cola naranja
const AFILA_COLA: float = 3.0              ## cuÃ¡nto se estrecha la cola con la distancia a la cabeza (fuego_lelu_bola: afila_cola)
const CABEZA_VUELO: float = 1.75            ## Ã— el radio de la cabeza en vuelo
const ALARGADO_VUELO: float = 0.16          ## cuÃ¡nto se alarga la cola (mayor = mÃ¡s corta; la validada 0,1)
const DEFORM_VUELO: float = 0.28            ## deformaciÃ³n del contorno en vuelo (la validada 0,6: la cabeza sale con puntas)
## Una repeticiÃ³n de la textura de lenguas cada tantos metros de contorno (media de lo medido en las tres escenas validadas: 2,90 Â· 3,14 Â· 3,14).
const METROS_POR_REPETICION: float = 2.9

@export_group("Figura y ejes (m)")
@export var figura: Figura = Figura.BOLA: set = _set_figura
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_x: float = 0.4: set = _set_x
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_y: float = 0.4: set = _set_y
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_z: float = 0.4: set = _set_z
## Solo BOLA: proyectil en vuelo (cola, jirones y estelas de chispas). Es el mismo `proyectil` de EfectoToy.
@export var viaja: bool = false: set = _set_viaja

## HAZ: `crece` (0 → 1: el chorro sale del origen; lo anima «nacer») y `corte` (0 → 1: el chorro se suelta del origen, avanza y se rompe en bolitas; lo anima «morir»). Con 1 y 0 es el haz completo.
@export_range(0.0, 1.0, 0.01) var crece: float = 1.0: set = _set_crece
@export_range(0.0, 1.0, 0.01) var corte: float = 0.0: set = _set_corte
## HAZ: dónde choca (lo rellena VfxToyJuego con lo que calcula la lógica; el final del alcance contra el suelo NO es un choque): [{d: m desde la mano a lo largo del haz, x: m a un lado del eje,
## n: normal de la superficie en el espacio LOCAL del toy (hacia fuera de lo golpeado)}]. Vacío = sin choque: la punta acaba en humo. Hay que ponerlo ANTES de entrar en el árbol (o llamar a `reconstruir()`).
var choques: Array = []
## Interruptor de las tres ideas de la demo de gas (salpicadura, humo en la punta, luz en el suelo, color sin amarillo, remolino): false = el haz de antes (para las capturas antes/después y por si Pablo prefiere el viejo).
static var haz_ideas: bool = true
## FORMAS (BOLA, MURO, PILAR, BARRERA, validadas por Pablo): capas NUEVAS que solo se AÑADEN, cada una con su interruptor (true = se dibuja), sin tocar nada de lo que ya hay.
##   luz_suelo_*        decal naranja-rojo en el suelo bajo la figura (sigue el terreno; no tiñe cuerpos): muro, pilar, barrera, y donde cae el impacto de la bola
##   humo_cima_*        humo pardo oscuro que se suelta de la cima del muro y del pilar, donde la llama se frena
## TODAS APAGADAS por defecto (9/11): en las capturas antes/después (docs/capturas/vfx_en_juego/haz_fuego_ideas/formas_fuego/) ninguna mejora clara lo que Pablo ya validó; las enciende quien las quiera.
##   chispas_impacto    chispas con estela que salen del impacto de la bola, caen y quedan un instante brillando en el suelo
static var formas_extra: Dictionary = {"luz_suelo_muro": false, "luz_suelo_pilar": false, "luz_suelo_barrera": false, "luz_suelo_impacto": false,
	"humo_cima_muro": false, "humo_cima_pilar": false, "chispas_impacto": false}
var _emisores_choque: Array = []       ## partículas que solo emiten con el chorro ya llegado (crece ≥ 0,85) y hasta que se suelta
var _emisores_humo: Array = []

static var _rampa_fuego: GradientTexture1D = null
static var _rampa_bola: GradientTexture1D = null
static var _rampa_azul: GradientTexture1D = null
static var _blob: GradientTexture2D = null

## CARGA DEL HECHIZO (solo BOLA): ver `empezar_carga`. Mandos en vivo (el lab los mueve con Q / E): fracciÃ³n del tamaÃ±o final con que nace la bola en la mano, curva de
## crecimiento (< 1 rÃ¡pido al principio y asentado; > 1 tarda en arrancar), nÂº de chispas que convergen, brillo del destello al soltar y cuÃ¡nto Â«respiraÂ» al sostener.
@export_group("Carga del hechizo")
@export_range(0.03, 0.6, 0.01) var carga_tam_inicial: float = 0.12
@export_range(0.3, 3.0, 0.05) var carga_curva: float = 0.8
@export_range(0, 40, 1) var carga_chispas: int = 28: set = _set_carga_chispas      ## chispas que se aglutinan alrededor de la mano al final de la carga (la mitad al principio: crecen con ella)
@export_range(0.0, 3.0, 0.05) var carga_destello: float = 1.0
@export_range(0.0, 0.2, 0.005) var carga_respiro: float = 0.05
@export_range(0.0, 3.0, 0.05) var carga_brillo: float = 1.0: set = _set_carga_brillo       ## brillo suave de la mano (halo + punto final)
@export_range(0.5, 2.0, 0.05) var carga_radio: float = 1.0: set = _set_carga_radio         ## Ã— el radio de la nube de chispas (â‰ˆ 0,3-0,5 m con la bola de 0,4)
## false (por defecto): durante la carga NO se ve la bola, solo el brillo y las chispas en la mano; la bola aparece al soltar con un pequeÃ±o Â«popÂ». true: la bola va creciendo en la mano
## (la versiÃ³n anterior).
@export var carga_bola_visible: bool = false: set = _set_carga_bola_visible

enum EstadoCarga { NINGUNA, CARGANDO, SOLTANDO, APAGANDO, CANCELANDO }
const ESCENA_IMPACTO: String = "res://presentacion/vfx/toy/ImpactoFuegoToy.tscn"
const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")
const CargaToy = preload("res://presentacion/vfx/toy/carga_toy.gd")
const T_COLA_REBOTE: float = 0.15       ## s que la cola de la bola va acortada tras un rebote (y otros ~0,15 s en recuperar su largo)
const T_SOLTAR: float = 0.14            ## s que tarda en asentarse al tamaÃ±o final al soltar (si estaba respirando o sin acabar de crecer; o el Â«popÂ» si la bola no se veÃ­a)
const POP_DESDE: float = 0.5            ## escala con la que aparece la bola al soltar si no se veÃ­a durante la carga (y de ahÃ­ sube a 1 con un pequeÃ±o rebote)
const POP_REBOTE: float = 0.07
const T_APAGAR: float = 0.5             ## s que tarda en encogerse el fin sin choque
const T_CANCELAR: float = 0.2
const RESPIRO_HZ: float = 1.4
const RADIO_CONVERGE: float = 3.0       ## radio de la esfera de la que salen las chispas de la carga (Ã— radio final)

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
var _luz_pleno: float = 1.1
var _rango_pleno: float = 4.5
var _c_nodo: Node3D = null
var _c_visual: Node3D = null            ## CargaToy: brillo suave + chispas que se aglutinan en la mano
var _pop: bool = false                  ## al soltar, la bola no se veÃ­a: aparece con un pequeÃ±o Â«popÂ» desde POP_DESDE
var _destello: Node3D = null
var _d_t: float = 0.0
var _mat_flare_d: ShaderMaterial = null
var _cola_base: float = 1.0
var _cola_t: float = -1.0              ## tras un rebote: s desde el rebote (cola de la bola acortada ~0,15 s); < 0 = nada que hacer
var _mat_halo_d: ShaderMaterial = null
var _flash_luz: float = 0.0


func _ready() -> void:
	_construir()
	super._ready()
	_construido = true
	_set_proyectil(viaja)
	_set_crece(crece)
	_set_corte(corte)
	if escena_impacto == null and ResourceLoader.exists(ESCENA_IMPACTO):
		escena_impacto = load(ESCENA_IMPACTO) as PackedScene


# ------------------------------------------------------------------ interfaz ------------------------------------------------------------------

func _set_figura(v: Figura) -> void:
	figura = v
	_pedir()


func _set_x(v: float) -> void:
	semieje_x = maxf(v, 0.05)
	_pedir()


func _set_y(v: float) -> void:
	semieje_y = maxf(v, 0.05)
	_pedir()


func _set_z(v: float) -> void:
	semieje_z = maxf(v, 0.05)
	_pedir()


func _set_crece(v: float) -> void:
	crece = v
	_param_mats("crece", v)
	_emitir_haz()


func _set_corte(v: float) -> void:
	corte = v
	_param_mats("corte", v)
	if _listo and figura == Figura.HAZ:
		for h in _halos:
			h.set_shader_parameter("vida", 1.0 - smoothstep(0.1, 0.7, v))      # el resplandor del origen se apaga al soltarse el chorro
	_emitir_haz()


## HAZ: las chispas y brasas del choque emiten cuando el chorro ya ha llegado y hasta que se suelta; el humo de la punta, un poco antes y hasta bien entrado el corte.
func _emitir_haz() -> void:
	if figura != Figura.HAZ:
		return
	var choque_on: bool = crece >= 0.85 and corte < 0.15
	for gp in _emisores_choque:
		if is_instance_valid(gp):
			(gp as GPUParticles3D).emitting = choque_on
	var humo_on: bool = crece >= 0.6 and corte < 0.6
	for gp in _emisores_humo:
		if is_instance_valid(gp):
			(gp as GPUParticles3D).emitting = humo_on


func _set_viaja(v: bool) -> void:
	viaja = v
	_pedir()


## Pone figura, ejes y vuelo de una vez y reconstruye una sola vez.
func definir(fig: Figura, x: float, y: float, z: float, vuela: bool = false) -> void:
	_silencio = true               # los setters no piden otra reconstrucciÃ³n diferida: se rehace una sola vez, aquÃ­
	figura = fig
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


## Vuelve a hacer la geometrÃ­a con los ejes actuales (los mandos y la animaciÃ³n se conservan).
func reconstruir() -> void:
	_pendiente = false
	if not is_inside_tree() or not _construido:
		return
	_listo = false
	_construir()
	proyectil = viaja
	_recoger()
	_set_proyectil(viaja)
	_set_crece(crece)
	_set_corte(corte)


func semiejes() -> Vector3:
	return Vector3(semieje_x, semieje_y, semieje_z)


# ------------------------------------------------------------------ carga, suelta e impacto (solo BOLA) ------------------------------------------------------------------
## Ciclo de vida de un proyectil de fuego, sobre UN SOLO nodo:
##   empezar_carga(duracion, tam_final)  durante `duracion` s (el radio final es `tam_final`, en m, o semiejes Vector3) se ve un BRILLO suave en la mano y pequeÃ±as CHISPAS que se aglutinan hacia
##                                       ella (mÃ¡s y mÃ¡s juntas segÃºn avanza); la bola NO se ve (mando `carga_bola_visible`: true = la bola va creciendo en la mano, como antes) y la luz sube.
##                                       Si la carga se sostiene mÃ¡s, Â«respiraÂ» (Â±carga_respiro) sin crecer mÃ¡s. NO hace falta `lanzar()`.
##   progreso_carga() -> float           0 â†’ 1 (se queda en 1 al sostener, y tras soltar)
##   soltar(dir)                         ESA MISMA bola (mismo nodo) aparece con un pequeÃ±o Â«popÂ» (de POP_DESDE a 1 en T_SOLTAR s) y pasa a proyectil (cola, jirones, estelas) apuntando a `dir`, con
##                                       un destello breve que no la tapa; con `carga_bola_visible` no hay pop: si estaba respirando o sin acabar de crecer, se asienta al tamaÃ±o final sin salto.
##                                       Quien la mueve es el juego (HechizoVivo) o el lab; el nodo no se desplaza solo.
##   cancelar_carga()                    se encoge y se apaga en T_CANCELAR s y se libera (sin destello)
##   impactar_en(pos, normal, escala)    golpe: ImpactoFuegoToy GOLPE orientado por la normal; la bola desaparece en seguida
##   rebotar(pos, normal) -> Vector3     salpicadura pequeÃ±a; la bola SIGUE; devuelve la direcciÃ³n reflejada (y la bola mira hacia ella)
##   terminar_sin_choque()               el hechizo se agota sin chocar: la bola se encoge y se apaga en jirones (variante FIN), sin estallido
##   finalizar(motivo, pos, normal)      atajo para HechizoVivo._terminar(causa): golpe / muro / suelo â†’ impactar_en; alcance / tiempo / frenado â†’ terminar_sin_choque; retorno â†’ se apaga en la mano
## `impactar()` (contrato EfectoVfx3D) tambiÃ©n funciona: normal = hacia atrÃ¡s del vuelo, o arriba si estÃ¡ a ras de suelo.

func esta_cargando() -> bool:
	return _est == EstadoCarga.CARGANDO


func progreso_carga() -> float:
	return _c_prog


## Escala actual del cuerpo respecto al tamaÃ±o final (1 = tamaÃ±o del proyectil).
func escala_carga() -> float:
	return _c_escala


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
	aparicion = 1.0
	if _ap != null:
		_ap.stop()
	_c_dur = maxf(duracion, 0.05)
	_c_t = 0.0
	_c_prog = 0.0
	_c_escala = carga_tam_inicial
	_luz_pleno = _luz_base
	_rango_pleno = _luz.omni_range if _luz != null else 4.5
	_flash_luz = 0.0
	_est = EstadoCarga.CARGANDO
	_pop = false
	if _cuerpo != null:
		_cuerpo.visible = carga_bola_visible          # sin bola durante la carga: solo el brillo y las chispas de la mano (la luz de la bola sÃ­ sube)
	_montar_carga()
	_aplicar_escala_carga(0.0)


func soltar(dir: Vector3 = Vector3.ZERO) -> void:
	if dir.length() > 0.001 and is_inside_tree():
		var d: Vector3 = dir.normalized()
		look_at(global_position + d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
	_silencio = true
	viaja = true
	_silencio = false
	proyectil = true
	if _cuerpo != null and not _cuerpo.visible:
		_cuerpo.visible = true                        # la MISMA bola aparece con un pequeÃ±o Â«popÂ»
		_pop = true
		_c_desde = POP_DESDE
		_c_escala = POP_DESDE
		_aplicar_escala_carga(1.0)
	else:
		_pop = false
		_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.SOLTANDO
	_flash_luz = carga_destello
	_quitar_visual_carga(0.12)
	_crear_destello()


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
		_c_visual.call("poner_chispas", v)


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


## El brillo y las chispas de la carga se desvanecen en `dur` s y se liberan solos.
func _quitar_visual_carga(dur: float) -> void:
	if _c_visual != null and is_instance_valid(_c_visual):
		_c_visual.call("salir", dur)


func _escala_de_carga(p: float) -> float:
	var g: float = smoothstep(0.0, 1.0, pow(clampf(p, 0.0, 1.0), carga_curva))
	return lerpf(carga_tam_inicial, 1.0, g)


## Aplica la escala de la carga al cuerpo (junto con la de Â«aparicionÂ», que usa EfectoToy) y mueve la luz.
func _aplicar_escala_carga(luz_f: float) -> void:
	if _cuerpo != null:
		var v: float = aparicion
		_cuerpo.scale = Vector3(lerpf(0.65, 1.0, v), lerpf(0.15, 1.0, v), lerpf(0.65, 1.0, v)) * _c_escala
	if _luz != null:
		_luz_base = _luz_pleno * luz_f
		_luz.omni_range = _rango_pleno * lerpf(0.5, 1.0, clampf(luz_f, 0.0, 1.0))


func _avanzar_carga(delta: float) -> void:
	match _est:
		EstadoCarga.CARGANDO:
			_c_t += delta
			var p: float = clampf(_c_t / _c_dur, 0.0, 1.0)
			_c_prog = p
			var g: float = _escala_de_carga(p)
			var env: float = smoothstep(0.55, 1.0, p)                                # el respiro entra al llegar casi al tamaÃ±o final
			var resp: float = sin(_c_t * TAU * RESPIRO_HZ)
			_c_escala = g * (1.0 + carga_respiro * env * resp)
			_aplicar_escala_carga(lerpf(0.2, 1.0, g) * (1.0 + 0.1 * env * resp))
			if _c_visual != null and is_instance_valid(_c_visual):
				_c_visual.call("poner", _c_escala, p)
		EstadoCarga.SOLTANDO:
			_c_t += delta
			var u: float = clampf(_c_t / T_SOLTAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 1.0, smoothstep(0.0, 1.0, u)) + (POP_REBOTE * sin(u * PI) if _pop else 0.0)
			_flash_luz = carga_destello * (1.0 - u)
			_aplicar_escala_carga(1.0 + 0.8 * _flash_luz)
			if u >= 1.0:
				_est = EstadoCarga.NINGUNA
				_c_escala = 1.0
				_aplicar_escala_carga(1.0)
		EstadoCarga.CANCELANDO:
			_c_t += delta
			var u2: float = clampf(_c_t / T_CANCELAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 0.0, u2 * u2)
			_aplicar_escala_carga(1.0 - u2)
			if u2 >= 1.0:
				_est = EstadoCarga.NINGUNA
				queue_free()
		EstadoCarga.APAGANDO:
			_c_t += delta
			var u3: float = clampf(_c_t / T_APAGAR, 0.0, 1.0)
			_c_escala = lerpf(_c_desde, 0.0, u3 * u3)
			_aplicar_escala_carga(1.0 - u3)
			if u3 >= 1.0:
				_est = EstadoCarga.NINGUNA
				_c_escala = 0.001
				_aplicar_escala_carga(0.0)
				if _luz != null:
					_luz.visible = false
				get_tree().create_timer(0.85).timeout.connect(queue_free)      # deja morir las chispas de la estela, que quedan en el mundo


func _process(delta: float) -> void:
	super._process(delta)
	_avanzar_carga(delta)
	_avanzar_destello(delta)
	_avanzar_cola(delta)
	if figura == Figura.HAZ and _luz != null and _listo:
		_luz.light_energy *= (1.0 - smoothstep(0.2, 0.9, corte)) * clampf(crece * 1.5, 0.0, 1.0)      # la luz sigue al chorro: nace con él y se apaga al cortarse


## Brillo suave y chispas que se aglutinan en la mano (CargaToy). Cuelga de un nodo Â«CargaÂ» que no escala con la bola. Paleta de la bola (_rampa_bola), sin rojo oscuro.
func _montar_carga() -> void:
	var viejo: Node = get_node_or_null("Carga")
	if viejo != null:
		remove_child(viejo)
		viejo.free()
	_c_nodo = Node3D.new()
	_c_nodo.name = "Carga"
	add_child(_c_nodo)
	_c_visual = CargaToy.new()
	_c_visual.name = "Convergencia"
	_c_nodo.add_child(_c_visual)
	_c_visual.call("montar", _c_r, carga_chispas, carga_brillo, carga_radio)


## Destello breve al soltar: flare de ocho puntas (hit22) y halo aditivo, pequeÃ±os para no tapar la bola; no es una luz. Se borra solo (â‰ˆ 0,18 s).
func _crear_destello() -> void:
	if _destello != null and is_instance_valid(_destello):
		_destello.queue_free()
	_destello = null
	if carga_destello <= 0.01:
		return
	var r: float = maxf(semieje_x, semieje_z)
	var k: float = r / REF_BOLA.x
	_destello = Node3D.new()
	_destello.name = "Destello"
	add_child(_destello)
	# estrella de golpe de 8 puntas (T_VFX_hit22), aditiva, recoloreada con la rampa de la bola
	var fm: MeshInstance3D = SpriteToy.crear("Flare", SpriteToy.T_DESTELLO, SpriteToy.Modo.ADITIVO, false,
		{"recorte": Vector2(0.04, 0.9), "luminancia": Vector2(0.2, 1.0), "tramo": Vector2(0.6, 1.0), "brillo": 1.1, "giro": randf() * TAU, "vida": 0.0}, 4)
	fm.scale = Vector3(1.25 * k, 1.25 * k, 1.0)
	_mat_flare_d = SpriteToy.mat(fm)
	_destello.add_child(fm)
	var h: MeshInstance3D = _halo(_destello, "Halo", Vector2(2.4 * k, 2.4 * k), Vector3.ZERO, 0.8, 2.6, 2, Color(1.0, 0.4, 0.1), {"latido": 0.0})
	_mat_halo_d = h.material_override as ShaderMaterial
	_d_t = 0.0


func _avanzar_destello(delta: float) -> void:
	if _destello == null or not is_instance_valid(_destello):
		return
	_d_t += delta
	var u: float = clampf(_d_t / 0.18, 0.0, 1.0)
	var a: float = pow(1.0 - u, 1.8) * carga_destello
	_destello.scale = Vector3.ONE * lerpf(0.5, 1.35, 1.0 - pow(1.0 - u, 2.0))
	if _mat_flare_d != null:
		_mat_flare_d.set_shader_parameter("vida", clampf(a * 0.8, 0.0, 1.0))
	if _mat_halo_d != null:
		_mat_halo_d.set_shader_parameter("brillo", 0.8 * a)
	if u >= 1.0:
		_destello.queue_free()
		_destello = null


func _radio_impacto(escala: float) -> float:
	return escala if escala > 0.0 else maxf(semieje_x, semieje_z)


func _crear_impacto(variante: ImpactoFuegoToy.Variante, normal: Vector3, escala: float, pos: Vector3) -> Node3D:
	var padre: Node = get_parent()
	if padre == null or not ResourceLoader.exists(ESCENA_IMPACTO):
		return null
	var imp: ImpactoFuegoToy = ImpactoFuegoToy.crear(variante, normal, _radio_impacto(escala))
	padre.add_child(imp)
	imp.global_position = pos
	return imp


## Quita lo que es Â«vueloÂ» (jirones, chispas con estela) y la luz de la bola; el cuerpo se queda o se apaga segÃºn el caso.
func _quitar_vuelo() -> void:
	for gp in find_children("*", "GPUParticles3D", true, false):
		if (gp as Node).is_in_group("vuelo"):
			(gp as GPUParticles3D).emitting = false
	_quitar_visual_carga(0.05)


func impactar_en(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Node3D:
	var imp: Node3D = _crear_impacto(ImpactoFuegoToy.Variante.GOLPE, normal, escala, pos)
	_extras_impacto(pos, normal, escala)
	_est = EstadoCarga.NINGUNA
	_quitar_vuelo()
	if _luz != null:
		_luz.visible = false                      # la luz del impacto toma el relevo: nunca hay dos
	if _destello != null and is_instance_valid(_destello):
		_destello.queue_free()
		_destello = null
	if _ap != null and _ap.has_animation("morir"):
		_ap.speed_scale = 4.0                     # la bola se apaga en 0,12 s mientras florece el impacto
	morir()
	return imp


func rebotar(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Vector3:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var d: Vector3 = -global_transform.basis.z if is_inside_tree() else Vector3.FORWARD
	var nd: Vector3 = (d - 2.0 * d.dot(n) * n).normalized()
	_crear_impacto(ImpactoFuegoToy.Variante.REBOTE, n, escala, pos)
	if is_inside_tree():
		global_position = pos
		look_at(pos + nd, Vector3.UP if absf(nd.y) < 0.99 else Vector3.FORWARD)
	_acortar_cola()
	return nd


## Tras un rebote la cola vieja (jirones y chispas de estela, que quedan en el mundo y apuntan hacia la pared) se borra y la de la llama se acorta; en ~0,15 s recupera su largo.
func _acortar_cola() -> void:
	for gp in find_children("*", "GPUParticles3D", true, false):
		if (gp as Node).is_in_group("vuelo"):
			(gp as GPUParticles3D).restart()           # borra lo que ya estaba en el mundo
			(gp as GPUParticles3D).emitting = false
	if _cola_t < 0.0:
		_cola_base = 1.0
		for m in find_children("Llama", "MeshInstance3D", true, false):
			var mat: ShaderMaterial = (m as MeshInstance3D).material_override as ShaderMaterial
			if mat != null and mat.get_shader_parameter("altura") != null:
				_cola_base = float(mat.get_shader_parameter("altura"))
	_cola_t = 0.0
	_poner_cola(0.35)


## `f` = fracciÃ³n del largo de la cola (menor Â«alturaÂ» en fuego_lelu_bola = cola mÃ¡s corta).
func _poner_cola(f: float) -> void:
	for m in find_children("Llama", "MeshInstance3D", true, false):
		var mat: ShaderMaterial = (m as MeshInstance3D).material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("altura", _cola_base * f)


func _avanzar_cola(delta: float) -> void:
	if _cola_t < 0.0:
		return
	_cola_t += delta
	if _cola_t < T_COLA_REBOTE:
		return
	var u: float = clampf((_cola_t - T_COLA_REBOTE) / T_COLA_REBOTE, 0.0, 1.0)
	if u > 0.0:
		for gp in find_children("*", "GPUParticles3D", true, false):
			if (gp as Node).is_in_group("vuelo") and proyectil:
				(gp as GPUParticles3D).emitting = true
	_poner_cola(lerpf(0.35, 1.0, u))
	if u >= 1.0:
		_cola_t = -1.0


func terminar_sin_choque() -> void:
	if _est == EstadoCarga.APAGANDO or _est == EstadoCarga.CANCELANDO:
		return
	var est: Node = get_node_or_null("Cuerpo/Frente/Estrella")      # el destello de 4 puntas es un billboard de StandardMaterial3D: solo escala con el cuerpo si conserva la escala
	if est is MeshInstance3D and ((est as MeshInstance3D).mesh as QuadMesh).material is StandardMaterial3D:
		(((est as MeshInstance3D).mesh as QuadMesh).material as StandardMaterial3D).billboard_keep_scale = true
	_crear_impacto(ImpactoFuegoToy.Variante.FIN, Vector3.UP, -1.0, global_position)
	_quitar_vuelo()
	_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.APAGANDO


## Atajo para HechizoVivo._terminar(causa): quÃ© hace la bola segÃºn el motivo del fin.
func finalizar(motivo: String, pos: Vector3 = Vector3.INF, normal: Vector3 = Vector3.UP) -> void:
	var p: Vector3 = global_position if pos == Vector3.INF else pos
	match motivo:
		"golpe", "muro", "suelo":
			impactar_en(p, normal)
		"retorno":
			cancelar_carga()
		_:
			terminar_sin_choque()


## Contrato de EfectoVfx3D: sin datos de superficie, la normal es hacia atrÃ¡s del vuelo (o arriba si va a ras de suelo).
func impactar() -> void:
	var n: Vector3 = global_transform.basis.z.normalized() if proyectil else Vector3.UP
	if global_position.y < 0.3:
		n = Vector3.UP
	impactar_en(global_position, n)


## Escala el efecto a un volumen de hechizo ({x, y, z} en casillas) sin escalar el nodo: la geometrÃ­a se rehace con los semiejes en metros. `dir` orienta el eje X
## del muro de lado al tiro (como EfectoVfx3D.preparar).
func preparar(volumen: Dictionary, dir: Vector3, _elemento: String = "fuego") -> void:
	semieje_x = maxf(float(volumen.get("x", 0.5)) * casilla, 0.05)
	semieje_y = maxf(float(volumen.get("y", 0.5)) * casilla, 0.05)
	semieje_z = maxf(float(volumen.get("z", 0.5)) * casilla, 0.05)
	var plano: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if plano.length() > 0.01 and is_inside_tree():
		look_at(global_position + plano, Vector3.UP)
	if _construido:
		reconstruir()


## Elige figura, tamaÃ±o y vuelo desde un `Hechizo` (ver `describir`).
func desde_hechizo(h: Hechizo) -> void:
	var d: Dictionary = describir(h, casilla)
	definir(d["figura"], d["x"], d["y"], d["z"], d["viaja"])
	rotation.y = float(d["giro_y"])


## Figura y tamaÃ±o de un hechizo, SIN crear nada: {figura, x, y, z (m), viaja, giro_y (rad), nombre (derivado), nota}.
## Regla (plan procedural: figura explÃ­cita â†’ superficie/columna â†’ volumen; el proyectil es un comportamiento, no una figura):
##   Â· haz (á› lÃ­nea, `h.haz`): HAZ, largo = alcance del haz, radio = HAZ_ANCHO / 2, eje a la altura de la mano.
##   Â· viaja (o velocidad > 0): BOLA con cola, con los semiejes EN VUELO (Ã— Hechizo.ESCALA_PROYECTIL).
##   Â· solidez > 0 (barrera): MURO si es alargada en planta (largo â‰¥ 2 Ã— fondo), si no BARRERA (cÃºpula).
##   Â· sin solidez: nombre_derivado Â«altoÂ» â†’ PILAR; alargado en planta â†’ MURO; lo demÃ¡s (esfera, elipsoide, zona plana redonda) â†’ BOLA (nota si es plana).
## Los semiejes de Hechizo estÃ¡n en casillas y se pasan a metros con `casilla` (2,3, como VfxElemento3D).
static func describir(h: Hechizo, casilla_m: float = 2.3) -> Dictionary:
	var vuela: bool = (h.viaja or h.velocidad > 0.0) and not h.volumen_viaja      # 3/11 (R1): el volumen sólido que viaja (ᛜ + ᛇ) es un MURO/BARRERA que se desplaza, no una bola con cola
	var s: Vector3 = (h.semiejes_vuelo if vuela else h.semiejes) * casilla_m
	var nombre: String = Hechizo.nombre_derivado(h.semieje_x, h.semieje_y, h.semieje_z, vuela)
	var largo: float = maxf(s.x, s.z)
	var corto: float = minf(s.x, s.z)
	var alargado: bool = largo >= 2.0 * corto - 0.0001
	var fig: Figura = Figura.BOLA
	var nota: String = ""
	var y_haz: float = 0.0
	var z_haz: float = 0.0
	if h.haz:
		# haz (á› lÃ­nea): `nombre_derivado` no distingue el haz (da Â«x_manoÂ»), lo decide `h.haz`. Largo = alcance del haz (m-casilla) Ã— casilla; radio = la mitad del grosor de dibujo.
		fig = Figura.HAZ
		y_haz = Hechizo.ALTURA_MANO_U
		z_haz = Hechizo.HAZ_ANCHO * casilla_m * 0.5
	elif vuela:
		fig = Figura.BOLA
	elif h.solidez > 0.0:
		fig = Figura.MURO if alargado else Figura.BARRERA
	elif nombre == "alto":
		fig = Figura.PILAR
	elif alargado:
		fig = Figura.MURO
	else:
		fig = Figura.BOLA
		if nombre == "abajo":
			nota = "zona plana redonda: sin figura propia, se dibuja como BOLA aplanada"
	var x: float = s.x
	var z: float = s.z
	var giro: float = 0.0
	if fig == Figura.MURO and s.z > s.x:
		x = s.z                      # el muro se alarga por su X: se gira 90Â° si lo largo es el fondo
		z = s.x
		giro = PI * 0.5
	if fig == Figura.HAZ:
		return {"figura": fig, "x": h.alcance_haz * casilla_m * 0.5, "y": y_haz, "z": z_haz, "viaja": false, "giro_y": 0.0, "nombre": nombre, "nota": ""}
	return {"figura": fig, "x": x, "y": s.y, "z": z, "viaja": vuela and not h.haz, "giro_y": giro, "nombre": nombre, "nota": nota}


## Radio Â«grandeÂ» del efecto, en metros: lo usan la luz y la cÃ¡mara del lab.
func extension() -> float:
	return _extension(figura, semieje_x, semieje_y, semieje_z)


static func _extension(fig: Figura, x: float, y: float, z: float) -> float:
	match fig:
		Figura.BOLA:
			return maxf(x, z)
		Figura.MURO, Figura.HAZ:
			return x
		Figura.PILAR:
			return sqrt(pow(maxf(x, z), 2.0) + pow(y * 0.5, 2.0))
	return maxf(maxf(x, y), z)


static func _extension_ref(fig: Figura) -> float:
	match fig:
		Figura.BOLA:
			return _extension(fig, REF_BOLA.x, REF_BOLA.y, REF_BOLA.z)
		Figura.MURO:
			return _extension(fig, REF_MURO.x, REF_MURO.y, REF_MURO.z)
		Figura.PILAR:
			return _extension(fig, REF_PILAR.x, REF_PILAR.y, REF_PILAR.z)
		Figura.HAZ:
			return REF_HAZ.x
	return _extension(fig, REF_BARRERA.x, REF_BARRERA.y, REF_BARRERA.z)


# ------------------------------------------------------------------ construcciÃ³n ------------------------------------------------------------------

func _construir() -> void:
	var cuerpo: Node3D = get_node_or_null("Cuerpo") as Node3D
	if cuerpo == null:
		cuerpo = Node3D.new()
		cuerpo.name = "Cuerpo"
		add_child(cuerpo)
	for h in cuerpo.get_children():
		cuerpo.remove_child(h)
		h.free()
	_emisores_choque.clear()
	_emisores_humo.clear()
	var luz: OmniLight3D = get_node_or_null("Luz") as OmniLight3D
	if luz == null:
		luz = OmniLight3D.new()
		luz.name = "Luz"
		luz.light_color = Color(1.0, 0.5, 0.22)
		luz.omni_attenuation = 1.4
		luz.shadow_enabled = false
		add_child(luz)
	tam_referencia = Vector3(semieje_x, semieje_y, semieje_z) * 2.0
	_avance_cabeza = -0.12
	match figura:
		Figura.BOLA:
			_bola(cuerpo, luz)
		Figura.MURO:
			_muro(cuerpo, luz)
		Figura.PILAR:
			_pilar(cuerpo, luz)
		Figura.BARRERA:
			_barrera(cuerpo, luz)
		Figura.HAZ:
			_haz(cuerpo, luz)
	_formas_extra(cuerpo)
	_anim_si_hace_falta()


func _ajustar_luz(luz: OmniLight3D, pos: Vector3, energia: float, rango: float) -> void:
	var f: float = extension() / _extension_ref(figura)
	luz.position = pos
	luz.light_energy = energia * clampf(f, 0.4, 1.6)
	luz.omni_range = rango * clampf(f, 0.4, 2.0)


## Ruido numÃ©rico: cuÃ¡ntas partÃ­culas (mÃ­nimo 1) al tamaÃ±o dado respecto al validado.
static func _cant(base: float, factor: float, minimo: int, maximo: int) -> int:
	return clampi(int(round(base * factor)), minimo, maximo)


# ---- BOLA ----

func _bola(c: Node3D, luz: OmniLight3D) -> void:
	var r: float = maxf(semieje_x, semieje_z)
	var k: float = r / REF_BOLA.x
	var ky: float = 1.0 if viaja else clampf(semieje_y / r, 0.25, 4.0)
	_halo(c, "Halo", Vector2(2.0 * k, 2.0 * k * ky), Vector3(0, 0.05 * k, 0), 0.3, 3.0, 2, Color(1.0, 0.28, 0.06))
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.4 * k, 2.4 * k)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Llama"
	mi.mesh = q
	mi.material_override = _mat_fuego(SH_BOLA, {"semilla": 0.3, "tam": 2.4 * k, "radio": 0.52 * k, "desplaza": 0.1 * k,
		"repeticion": Vector2(0.8, 0.65) / k, "rep_ruido": Vector2(0.7, 0.5) / k,
		"afila_cola": AFILA_COLA, "cabeza_vuelo": CABEZA_VUELO, "alargado_vuelo": ALARGADO_VUELO, "deform_vuelo": DEFORM_VUELO,
		"cierre_vuelo": CIERRE_VUELO, "calor_cola": CALOR_COLA}, 0, _rampa_de_bola())
	mi.scale = Vector3(1.0, ky, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(mi)
	# frente: cabeza, halo brillante y destello de 4 puntas (solo en vuelo)
	var fr: Node3D = Node3D.new()
	fr.name = "Frente"
	c.add_child(fr)
	_halo(fr, "Destello", Vector2(0.8 * k, 0.8 * k), Vector3.ZERO, 0.4, 2.8, 2, Color(1.0, 0.4, 0.1), {"latido": 0.12})
	var cab: MeshInstance3D = MeshInstance3D.new()
	cab.name = "Cabeza"
	var cq: QuadMesh = QuadMesh.new()
	cq.size = Vector2(k, k)
	cab.mesh = cq
	var cm: ShaderMaterial = ShaderMaterial.new()
	cm.shader = load(SH_CABEZA)
	cm.render_priority = 2
	cm.set_shader_parameter("ruido", load(TEX + "T_PerlinNoise_Tiled.png"))
	cm.set_shader_parameter("radio", 0.22 * k)
	cm.set_shader_parameter("tam", k)
	cab.material_override = cm
	cab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fr.add_child(cab)
	var flare: MeshInstance3D = MeshInstance3D.new()
	flare.name = "Estrella"
	var fq: QuadMesh = QuadMesh.new()
	fq.size = Vector2(1.05 * k, 1.05 * k)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = load(TEX + "T_flare8_vfx.png")
	fm.albedo_color = Color(1.0, 0.92, 0.75, 0.85)
	fm.render_priority = 3
	fq.material = fm
	flare.mesh = fq
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fr.add_child(flare)
	_avance_cabeza = -0.12 * k
	_vuelo(c, k)
	_trocitos(c, _cant(2.0, k, 1, 6), Vector3(0.1, 0.05, 0.1) * k, Vector3(0, 0.55 * k * ky, 0), k)
	_particulas(c, "Chispas", _cant(8.0, k, 4, 24), 1.3, 0.07 * k, Vector3(0.2, 0.15 * ky, 0.2) * k, Vector2(0.3, 0.8) * k, Vector3(0, 1, 0), 40.0, Vector3(0, 0.35 * k, 0),
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.62, 0.22, 1.0), Color(1.0, 0.55, 0.15, 0.0)], "chispas", Vector3.ZERO, r * 2.0 + 4.0)
	_ajustar_luz(luz, Vector3.ZERO, 1.1, 4.5)


## Jirones de llama y chispas con estela larga y fina: solo emiten con `proyectil` (grupo Â«vueloÂ»); quedan en el mundo.
func _vuelo(c: Node3D, k: float) -> void:
	_particulas_vuelo(c, "Jirones", 5, 0.45, Vector3(0.12, 0.12, 0.05) * k, Vector2(1.0, 2.0) * k, 22.0, Vector2(0.16, 0.34),
		[Color(1.0, 0.55, 0.12, 0.95), Color(0.95, 0.28, 0.06, 0.7), Color(0.8, 0.12, 0.03, 0.0)], SH_JIRON, Vector2(k, k))
	var ch: GPUParticles3D = _particulas_vuelo(c, "ChispasEstela", 6, 0.7, Vector3(0.28, 0.28, 0.05) * k, Vector2(0.5, 1.4) * k, 38.0, Vector2(0.5, 1.2),
		[Color(1.0, 0.75, 0.3, 1.0), Color(1.0, 0.5, 0.12, 0.8), Color(1.0, 0.35, 0.08, 0.0)], SH_CHISPA, Vector2(0.05 * k, 1.0 * k))
	var cab: QuadMesh = QuadMesh.new()
	cab.size = Vector2(0.26, 0.26) * k
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = load(TEX + "T_flare8_vfx.png")
	cab.material = sm
	ch.draw_passes = 2
	ch.draw_pass_2 = cab


func _particulas_vuelo(c: Node3D, nombre: String, cantidad: int, vida_s: float, caja: Vector3, vel: Vector2, abierto: float, escala: Vector2, colores: Array,
		shader: String, tam: Vector2) -> GPUParticles3D:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.name = nombre
	gp.amount = cantidad
	gp.lifetime = vida_s
	gp.local_coords = false
	gp.emitting = false
	gp.fixed_fps = 0
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 8, 16))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caja
	pm.direction = Vector3(0, 0, 1)
	pm.spread = abierto
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = Vector3.ZERO
	pm.scale_min = escala.x
	pm.scale_max = escala.y
	pm.color_ramp = _gradiente(colores)
	gp.process_material = pm
	var malla: QuadMesh = QuadMesh.new()
	malla.size = tam
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader)
	m.set_shader_parameter("lenguas", load(TEX + "T_FirePanningCyl45.png"))
	malla.material = m
	gp.draw_pass_1 = malla
	gp.add_to_group("vuelo", true)
	c.add_child(gp)
	return gp


# ---- MURO ----

func _muro(c: Node3D, luz: OmniLight3D) -> void:
	var a: float = semieje_x
	var b: float = semieje_z
	var alto: float = semieje_y
	var fl: float = a / REF_MURO.x
	var fa: float = alto / REF_MURO.y
	var fb: float = clampf(b / REF_MURO.z, 0.5, 3.0)
	_halo(c, "Charco", Vector2(7.6 * fl, 2.4 * fb), Vector3(0, 0.04, 0), 0.5, 1.6, 0, Color(1.0, 0.28, 0.06), {"latido": 0.05})
	_halo(c, "Resplandor", Vector2(7.2 * fl, 2.2 * fa), Vector3(0, 0.55 * fa, 0), 0.22, 2.6, 2, Color(1.0, 0.28, 0.06))
	# banda exterior: el contorno es una superelipse de 2a Ã— 2b; las repeticiones de la textura se cuentan por METROS de contorno (no se estira al alargar)
	var seg: int = FuegoToyMallas.segmentos(FuegoToyMallas.largo_contorno(a, b, 6.0))
	var banda: ArrayMesh = FuegoToyMallas.banda(a, b, 6.0, FuegoToyMallas.perfil_muro(alto, 0.78), seg)
	var m: Array = FuegoToyMallas.M_MURO
	var largo: float = FuegoToyMallas.largo_contorno(a, b, 6.0)
	_fuego(c, "Banda", banda, Vector3.ZERO, {"repeticion": Vector2(FuegoToyMallas.repeticiones_u(largo, m[0]), alto / float(m[1])),
		"rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(largo, m[2]), alto / float(m[3])), "semilla": 0.05, "velocidad": 1.0, "umbral": 0.27, "desfase": 0.45,
		"fuerza_grad": 1.05, "amplitud_vert": 0.16 * clampf(b / REF_MURO.z, 0.5, 2.0)}, 0)
	var ai: float = a * 0.957
	var bi: float = b * 0.4
	var hi: float = alto * 0.7
	var largo_i: float = FuegoToyMallas.largo_contorno(ai, bi, 6.0)
	var mi_: Array = FuegoToyMallas.M_MURO_IN
	var banda_in: ArrayMesh = FuegoToyMallas.banda(ai, bi, 6.0, FuegoToyMallas.perfil_muro(hi, 0.7), FuegoToyMallas.segmentos(largo_i))
	_fuego(c, "Interior", banda_in, Vector3.ZERO, {"repeticion": Vector2(FuegoToyMallas.repeticiones_u(largo_i, mi_[0]), hi / float(mi_[1])),
		"rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(largo_i, mi_[2]), hi / float(mi_[3])), "semilla": 0.4, "velocidad": 1.5, "umbral": 0.27, "desfase": 0.45,
		"fuerza_grad": 1.0, "calor_extra": 0.3, "brillo": 1.1, "amplitud_vert": 0.16 * clampf(b / REF_MURO.z, 0.5, 2.0)}, 1)
	_laminas_vbb(c, "Lenguas", FuegoToyMallas.laminas_muro(a, b, alto), FuegoToyMallas.M_MURO, {"semilla": 0.05, "velocidad": 1.0, "umbral": 0.27, "desfase": 0.45, "fuerza_grad": 1.05,
			"amplitud_vert": 0.16 * clampf(b / REF_MURO.z, 0.5, 2.0), "afila": 0.78, "usa_normal": 1.0, "el_min": 0.9})
	var vv: float = clampf(fa, 0.5, 2.5)
	_trocitos(c, _cant(3.0, fl, 1, 10), Vector3(a * 0.87, 0.05, b * 0.5), Vector3(0, 0.667 * alto, 0), vv)
	_particulas(c, "Chispas", _cant(14.0, fl, 5, 60), 1.4, 0.07, Vector3(a * 0.93, 0.1, b * 0.67), Vector2(0.3, 0.9) * vv, Vector3(0, 1, 0), 30.0, Vector3(0, 0.3, 0) * vv,
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", Vector3(0, 0.333 * alto, 0), a * 2.0 + 4.0)
	_ajustar_luz(luz, Vector3(0, 0.467 * alto, 0), 1.6, 6.5)


# ---- PILAR ----

func _pilar(c: Node3D, luz: OmniLight3D) -> void:
	var rx: float = semieje_x
	var rz: float = semieje_z
	var alto: float = semieje_y
	var rm: float = (rx + rz) * 0.5
	var fa: float = alto / REF_PILAR.y
	var fr: float = rm / REF_PILAR.x
	_halo(c, "Charco", Vector2(5.2 * rx, 5.2 * rz), Vector3(0, 0.04, 0), 0.45, 1.8, 0, Color(1.0, 0.28, 0.06), {"anillo": 0.5, "irreg": PILAR_IRREG_CHARCO})
	_halo(c, "Resplandor", Vector2(6.8 * rm, 1.05 * alto), Vector3(0, 0.35 * alto, 0), 0.2, 2.8, 2, Color(1.0, 0.28, 0.06))
	var amp: float = clampf(fr, 0.5, 2.0)
	var base_irr: float = clampf(PILAR_BASE_M / alto, 0.03, 0.3)          # altura máx. (en V) a la que sube el contacto con el suelo según el ruido: ~0,45 m
	var l1: float = FuegoToyMallas.perimetro_elipse(rx, rz)
	var m: Array = FuegoToyMallas.M_PILAR
	_fuego(c, "Exterior", FuegoToyMallas.banda(rx, rz, 2.0, FuegoToyMallas.perfil_cilindro(0.72, alto), FuegoToyMallas.segmentos(l1)), Vector3.ZERO,
		{"repeticion": Vector2(FuegoToyMallas.repeticiones_u(l1, m[0]), alto / float(m[1])), "rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(l1, m[2]), alto / float(m[3])),
		"umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0, "pot_grad": 1.6, "semilla": 0.2, "velocidad": 0.9, "amplitud_vert": 0.2 * amp, "base_irreg": base_irr}, 0)
	var rxi: float = rx * 0.6
	var rzi: float = rz * 0.6
	var hi: float = alto * 0.775
	var l2: float = FuegoToyMallas.perimetro_elipse(rxi, rzi)
	var mn: Array = FuegoToyMallas.M_PILAR_IN
	_fuego(c, "Nucleo", FuegoToyMallas.banda(rxi, rzi, 2.0, FuegoToyMallas.perfil_cilindro(0.5333, hi), FuegoToyMallas.segmentos(l2)), Vector3.ZERO,
		{"repeticion": Vector2(FuegoToyMallas.repeticiones_u(l2, mn[0]), hi / float(mn[1])), "rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(l2, mn[2]), hi / float(mn[3])),
		"umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0, "pot_grad": 1.6, "semilla": 0.6, "velocidad": 1.5, "calor_extra": 0.3, "brillo": 1.1, "amplitud_vert": 0.12 * amp}, 1)
	# Pilares mÃ¡s gordos que el validado (r 0,5): un cilindro de lenguas con solo dos capas se ve hueco (un aro a rayas). Se aÃ±aden capas intermedias, una cada ~0,4 m de
	# radio por encima de 0,55 (mÃ¡x. 3), entre el exterior y el nÃºcleo, cada una con su semilla y su velocidad, para que el pilar se vea tan lleno como el validado.
	var n_extra: int = clampi(int(round((rm - 0.55) / 0.4)) + (1 if rm > 0.55 else 0), 0, 3)
	for i in n_extra:
		var f: float = lerpf(1.0, 0.6, float(i + 1) / float(n_extra + 1))      # fracciÃ³n del radio del exterior
		var rxc: float = rx * f
		var rzc: float = rz * f
		var hc: float = alto * lerpf(1.0, 0.775, float(i + 1) / float(n_extra + 1))
		var lc: float = FuegoToyMallas.perimetro_elipse(rxc, rzc)
		_fuego(c, "Capa%d" % i, FuegoToyMallas.banda(rxc, rzc, 2.0, FuegoToyMallas.perfil_cilindro(lerpf(0.72, 0.5333, float(i + 1) / float(n_extra + 1)), hc), FuegoToyMallas.segmentos(lc)),
			Vector3.ZERO, {"repeticion": Vector2(FuegoToyMallas.repeticiones_u(lc, m[0]), hc / float(m[1])), "rep_ruido": Vector2(FuegoToyMallas.repeticiones_u(lc, m[2]), hc / float(m[3])),
			"umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0, "pot_grad": 1.6, "semilla": 0.33 + 0.21 * float(i), "velocidad": 1.1 + 0.2 * float(i), "calor_extra": 0.15,
			"amplitud_vert": 0.16 * amp}, 1)
	_laminas_vbb(c, "Lenguas", FuegoToyMallas.laminas_pilar(rx, rz, alto), FuegoToyMallas.M_PILAR, {"umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0, "pot_grad": 1.6, "semilla": 0.45, "velocidad": 1.1,
			"amplitud_vert": 0.2 * amp, "afila": 0.72})
	_laminas_vbb(c, "BaseLenguas", FuegoToyMallas.laminas_base_pilar(rx, rz, alto), FuegoToyMallas.M_PILAR, {"umbral": 0.27, "desfase": 0.5, "fuerza_grad": 1.0, "pot_grad": 1.6, "semilla": 0.8, "velocidad": 1.3,
			"amplitud_vert": 0.1 * amp, "afila": 0.6, "el_ini": 0.99, "el_fin": 1.0})
	var area: float = sqrt(clampf(fr * fa, 0.05, 6.0))
	var vv: float = clampf(fa, 0.5, 2.5)
	_trocitos(c, _cant(3.0, area, 1, 10), Vector3(rx * 0.6, 0.1, rz * 0.6), Vector3(0, 0.75 * alto, 0), vv)
	_particulas(c, "Chispas", _cant(16.0, area, 6, 60), 1.8, 0.07, Vector3(rx * 0.6, 0.1, rz * 0.6), Vector2(0.6, 1.5) * vv, Vector3(0, 1, 0), 20.0, Vector3(0, 0.5, 0) * vv,
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", Vector3(0, 0.075 * alto, 0), rm * 2.0 + alto + 4.0)
	_ajustar_luz(luz, Vector3(0, 0.325 * alto, 0), 2.0, 7.0)


# ---- BARRERA ----

func _barrera(c: Node3D, luz: OmniLight3D) -> void:
	var rx: float = semieje_x
	var ry: float = semieje_y
	var rz: float = semieje_z
	var rh: float = maxf(rx, rz)
	var fr: float = rh / REF_BARRERA.x
	# ronda de Pablo (2/11): cúpula de fuego con BORDE brillante (fresnel), interior translúcido con jirones, LAMIDOS en la silueta y ARO brillante en el suelo (referencias ref_barrera_video_a / b).
	# El aro cae donde la cúpula corta el suelo: la malla está centrada a 0,4·ry, así que el suelo queda a -0,4·ry en coordenadas de la malla.
	var corte: float = sqrt(maxf(1.0 - 0.16, 0.0))            # radio del corte con el suelo (× semieje horizontal)
	var k_aro: float = 1.18
	var m: Array = FuegoToyMallas.M_BARRERA
	var ecuador: float = FuegoToyMallas.perimetro_elipse(rx, rz)
	var meridiano: float = FuegoToyMallas.perimetro_elipse(rh, ry) * 0.5
	var malla: ArrayMesh = FuegoToyMallas.elipsoide(rx, ry, rz, 25, clampi(int(round(ecuador / 0.12)), 48, 200))
	_halo(c, "Anillo", Vector2(2.6 * rx, 2.6 * rz), Vector3(0, 0.03, 0), 0.35, 1.0, 0, Color(1.0, 0.28, 0.06), {"anillo": 1.0, "latido": 0.04})
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.0 * rx * k_aro, 2.0 * rz * k_aro)
	q.orientation = PlaneMesh.FACE_Y
	var aro: MeshInstance3D = MeshInstance3D.new()
	aro.name = "Aro"
	aro.mesh = q
	aro.material_override = _mat_fuego(SH_ARO, {"radio_aro": corte / k_aro, "grosor": clampf(0.045 / maxf(fr, 0.3), 0.02, 0.07), "brillo": 1.0, "semilla": 0.4}, 2, _rampa_de_bola())
	aro.position = Vector3(0, 0.05, 0)
	aro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(aro)
	# mínimos de repeticiones (una barrera pequeña con 1-2 repeticiones casi no tiene lenguas): 3 por vuelta y 1 en vertical; no cambian la de 1,5 (3; 1,4) ni la de 3
	var p: Dictionary = {"repeticion": Vector2(maxf(3.0, FuegoToyMallas.repeticiones_u(ecuador, m[0])), maxf(1.0, meridiano / float(m[1]))),
		"rep_ruido": Vector2(maxf(3.0, FuegoToyMallas.repeticiones_u(ecuador, m[2])), maxf(1.5, meridiano / float(m[3]))), "semiejes": Vector3(rx, ry, rz), "suelo_y": -0.4 * ry,
		"ondulacion": 0.6, "lamido_alto": 0.22, "transparencia": 0.97,
		# ronda de Pablo (haz y barrera con cuerpo): borde más grueso y luminoso, interior lleno de corrientes anchas (≈60 % de la superficie) y lamidos amplios
		"borde_pot": 1.15, "borde_fuerza": 1.9, "borde_blanco": 1.0, "velo": 0.1, "jirones": 0.9, "cobertura": 0.92, "escala_jir": 0.5, "blandura": 0.3,
		"interior_calor": 1.0, "lam_amplio": 1.0}
	var mi: MeshInstance3D = _fuego(c, "Cascara", malla, Vector3(0, 0.4 * ry, 0), p, 0, SH_BARRERA_ATRAS, _rampa_de_bola())
	(mi.material_override as ShaderMaterial).next_pass = _mat_fuego(SH_BARRERA_DELANTE, p, 1, _rampa_de_bola())
	var p2: Dictionary = p.duplicate()
	p2["semilla"] = 0.37
	_fuego(c, "Lamidos", malla, Vector3(0, 0.4 * ry, 0), p2, 3, SH_BARRERA_LAMIDOS, _rampa_de_bola())
	var area: float = clampf(fr, 0.3, 3.0)
	var vv: float = clampf(ry / REF_BARRERA.y, 0.5, 2.5)
	_trocitos(c, _cant(3.0, area, 1, 10), Vector3(rx * 0.67, 0.1, rz * 0.67), Vector3(0, 1.2 * ry, 0), vv)
	_particulas(c, "Chispas", _cant(14.0, area * area, 5, 60), 1.6, 0.07, Vector3(rx * 0.8, 0.1, rz * 0.8), Vector2(0.3, 0.9) * vv, Vector3(0, 1, 0), 25.0, Vector3(0, 0.5, 0) * vv,
		[Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)], "chispas", Vector3(0, 0.133 * ry, 0), rh * 2.0 + ry + 4.0)
	_ajustar_luz(luz, Vector3(0, 0.467 * ry, 0), 1.5, 5.5)


# ---- HAZ ----

## Chorro cónico de lanzallamas (ronda de Pablo, 2/11: «no puede salir de un corte»): NACE DE UN PUNTO fino en el origen (la mano), se abre en bocanadas hasta `semieje_z · HAZ_ABRE` de radio y acaba en una punta
## redondeada y deshecha, hacia -Z a la altura máx(y, 0,4). Una tira con billboard de eje a lo largo del haz (haz_toy.gdshader: volumen desde cualquier ángulo) y un núcleo más fino y caliente dentro.
## `crece` (0 → 1, «nacer») lo hace salir; `corte` (0 → 1, «morir») lo suelta del origen, lo deja avanzar y lo rompe en bolitas.
func _haz(c: Node3D, luz: OmniLight3D) -> void:
	var largo: float = semieje_x * 2.0
	var r: float = semieje_z * HAZ_ABRE
	var h: float = maxf(semieje_y, 0.4)
	var malla: ArrayMesh = FuegoToyMallas.haz_cono(largo, HAZ_R_ORIGEN, r)
	# ronda de Pablo (2/11, haz con cuerpo): más ancho (HAZ_ABRE), bocanadas redondeadas (volutas), centro lleno y claro (cuerpo), más opaco, bolitas grandes al cortarse y una lámina
	# cruzada («Cruz», giro de 60° alrededor del eje) para que mirado casi a lo largo del haz (cámara del juego) siga habiendo volumen
	var p: Dictionary = {"largo": largo, "r_origen": HAZ_R_ORIGEN, "r_fin": r, "crece": crece, "corte": corte,
		"volutas": 2.0, "cuerpo": 0.3, "desfase": 1.05, "umbral": 0.24, "blandura": 0.42, "tam_bolas": 1.8, "transparencia": 1.0, "fuerza_borde": 1.0,
		"humo": 1.0 if haz_ideas else 0.0, "tope_calor": HAZ_TOPE_CALOR if haz_ideas else 1.0, "remolino": 0.55 if haz_ideas else 0.0}      # 9/11: la punta se vuelve humo, la rampa se corta en naranja (sin amarillo) y las lenguas hacen remolino
	var ext: MeshInstance3D = _fuego(c, "Chorro", malla, Vector3(0, h, 0), p, 0, SH_HAZ, _rampa_de_bola())
	ext.extra_cull_margin = 1.0
	var pc: Dictionary = p.duplicate()
	pc["rot_lamina"] = 1.05
	pc["semilla"] = 0.31
	pc["grosor"] = 0.85
	pc["v_chorro"] = 1.12
	pc["humo"] = 0.7 if haz_ideas else 0.0
	var cruz: MeshInstance3D = _fuego(c, "Cruz", malla, Vector3(0, h, 0), pc, 0, SH_HAZ, _rampa_de_bola())
	cruz.extra_cull_margin = 1.0
	var pn: Dictionary = p.duplicate()
	pn["grosor"] = 0.6
	pn["semilla"] = 0.6
	pn["calor_extra"] = 0.55
	pn["v_chorro"] = 1.35
	pn["desfase"] = 1.0
	pn["cuerpo"] = 0.8
	pn["rot_lamina"] = -0.5
	pn["humo"] = 0.0                       # el núcleo es la parte limpia y caliente: no se vuelve humo
	pn["tope_calor"] = HAZ_TOPE_NUCLEO if haz_ideas else 1.0
	var nuc: MeshInstance3D = _fuego(c, "Nucleo", malla, Vector3(0, h, 0), pn, 1, SH_HAZ, _rampa_de_bola())
	nuc.extra_cull_margin = 1.0
	_halo(c, "Base", Vector2(2.4 * r + 0.4, 2.4 * r + 0.4), Vector3(0, h, 0), 0.4, 2.4, 2, Color(1.0, 0.28, 0.06))
	var f: float = clampf(largo / (2.0 * REF_HAZ.x), 0.4, 3.0)
	# 9/11: en vez de las bolitas del final (Trocitos), la punta suelta bocanadas de humo pardo que suben y se deshacen
	if haz_ideas:
		_humo_punta(c, largo, h, r, f)
	else:
		_trocitos(c, _cant(3.0, f, 1, 10), Vector3(r, r, largo * 0.15), Vector3(0, h, -largo * 0.8), 1.0)
	_particulas(c, "Chispas", _cant(10.0, f, 4, 40), 1.0, 0.07, Vector3(r, r, largo * 0.45), Vector2(0.3, 0.9), Vector3(0, 1, 0), 30.0, Vector3(0, 0.3, 0),
		([Color(1.0, 0.55, 0.2, 0.0), Color(1.0, 0.5, 0.15, 1.0), Color(0.95, 0.32, 0.08, 0.0)] if haz_ideas else [Color(1.0, 0.8, 0.4, 0.0), Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.5, 0.12, 0.0)]), "chispas", Vector3(0, h, -largo * 0.5), largo + 6.0)
	# idea 1 (el fuego envuelve lo que golpea) e idea 3 (luz en el suelo): solo con los choques que ha calculado la lógica
	var cs: Array = []
	for ch in (choques if haz_ideas else []):
		if cs.size() >= HAZ_MAX_CHOQUES:
			break
		if ch is Dictionary and (ch as Dictionary).has("d"):
			cs.append(ch)
	for i in cs.size():
		_salpicadura(c, cs[i] as Dictionary, h, r, i)
	if haz_ideas:
		_luz_suelo(c, largo, cs)
	_ajustar_luz(luz, Vector3(0, h, -largo * (0.55 if not cs.is_empty() else 0.4)), 1.4, 5.0)


# ---- FORMAS: capas añadidas (ver `formas_extra`) ----

const FORMA_GRUPO_IMPACTO: StringName = &"impacto_extra_fuego"
const FORMA_MAX_IMPACTOS: int = 4                  ## impactos con extras vivos a la vez en toda la escena


func _formas_extra(c: Node3D) -> void:
	var viejo: Node = get_node_or_null("LuzForma")
	if viejo != null:
		remove_child(viejo)
		viejo.free()
	match figura:
		Figura.MURO:
			if formas_extra.get("luz_suelo_muro", false):
				_luz_forma(Vector2(2.0 * semieje_x + 1.8, 2.0 * semieje_z + 1.8), 0.6)
			if formas_extra.get("humo_cima_muro", false):
				var gp: GPUParticles3D = _humo_generico(c, "HumoCima", Vector3(0, semieje_y * 0.95, 0), Vector3(semieje_x * 0.8, 0.05, semieje_z), _cant(5.0, semieje_x / REF_MURO.x, 3, 12), 0.7)
				gp.emitting = true
		Figura.PILAR:
			if formas_extra.get("luz_suelo_pilar", false):
				var d: float = 2.0 * maxf(semieje_x, semieje_z) + 2.2
				_luz_forma(Vector2(d, d), 0.6)
			if formas_extra.get("humo_cima_pilar", false):
				var gp: GPUParticles3D = _humo_generico(c, "HumoCima", Vector3(0, semieje_y * 0.97, 0), Vector3(semieje_x * 0.5, 0.05, semieje_z * 0.5), 6, 0.8)
				gp.emitting = true
		Figura.BARRERA:
			if formas_extra.get("luz_suelo_barrera", false):
				var d2: float = 2.0 * maxf(semieje_x, semieje_z) * 1.3
				_luz_forma(Vector2(d2, d2), 0.5)


## Decal de luz bajo la figura (explosion_suelo.gdshader, modo «calor»: resplandor del suelo). Cuelga de la raíz (no del Cuerpo, que se encoge con `aparicion`) y respira con ella.
func _luz_forma(dim_xz: Vector2, calor: float) -> void:
	var mi: MeshInstance3D = AvisoAreaFuego.decal(1.0)
	mi.name = "LuzForma"
	mi.scale = Vector3(dim_xz.x, AvisoAreaFuego.ALTO_CAJA, dim_xz.y)
	mi.set_meta("calor", calor)
	add_child(mi)
	_calor_forma(aparicion)


func _calor_forma(v: float) -> void:
	var mi: Node = get_node_or_null("LuzForma")
	if mi != null:
		var m: ShaderMaterial = (mi as MeshInstance3D).material_override as ShaderMaterial
		if m != null:
			m.set_shader_parameter("calor", float(mi.get_meta("calor", 0.5)) * v)


func _set_aparicion(v: float) -> void:
	super._set_aparicion(v)
	_calor_forma(v)


## Extras del impacto de la bola: resplandor del suelo que se apaga y chispas con estela que caen. Cuelgan de un nodo propio (el toy se va) que se borra solo.
func _extras_impacto(pos: Vector3, normal: Vector3, escala: float) -> void:
	var padre: Node = get_parent()
	if padre == null or not is_inside_tree():
		return
	var luz_on: bool = formas_extra.get("luz_suelo_impacto", false)
	var ch_on: bool = formas_extra.get("chispas_impacto", false)
	if not (luz_on or ch_on) or get_tree().get_nodes_in_group(FORMA_GRUPO_IMPACTO).size() >= FORMA_MAX_IMPACTOS:
		return
	var nodo: Node3D = Node3D.new()
	nodo.name = "ImpactoExtra"
	nodo.add_to_group(FORMA_GRUPO_IMPACTO)
	padre.add_child(nodo)
	nodo.global_position = pos
	var r: float = _radio_impacto(escala)
	if luz_on:
		var mi: MeshInstance3D = AvisoAreaFuego.decal(1.0)
		mi.scale = Vector3(2.0 * (r * 2.2 + 0.8), AvisoAreaFuego.ALTO_CAJA, 2.0 * (r * 2.2 + 0.8))
		nodo.add_child(mi)
		var m: ShaderMaterial = mi.material_override as ShaderMaterial
		m.set_shader_parameter("calor", 0.8)
		var tw: Tween = nodo.create_tween()
		tw.tween_method(func(v: float) -> void: m.set_shader_parameter("calor", v), 0.8, 0.0, 0.9).set_ease(Tween.EASE_OUT)
	if ch_on:
		_chispas_estela(nodo, "ChispasImpacto", Vector3(0, 0.15, 0), normal if normal.length() > 0.01 else Vector3.UP, 10, true)
		var br: GPUParticles3D = _brasas_suelo(nodo, "BrasasImpacto", Vector3(0, 0.05, 0), r * 1.2 + 0.4)
		br.emitting = true
		br.one_shot = true
	nodo.get_tree().create_timer(1.5, false).timeout.connect(nodo.queue_free)


## Cuántos nodos de un grupo hay vivos (los topes de salpicaduras y de manchas de luz son de toda la escena).
func _vivos_de(grupo: StringName) -> int:
	return get_tree().get_nodes_in_group(grupo).size() if is_inside_tree() else 0


## IDEA 2: bocanadas de humo pardo oscuro en la punta del chorro; suben despacio, crecen y se deshacen (mezcla normal, no aditiva: tapan, no iluminan).
func _humo_punta(c: Node3D, largo: float, h: float, r: float, f: float) -> void:
	var gp: GPUParticles3D = _humo_generico(c, "Humo", Vector3(0, h, -largo * 0.82), Vector3(r * 0.8, r * 0.2, largo * 0.17), _cant(7.0, f, 3, 12), 1.0)
	_emisores_humo.append(gp)


## Humo pardo oscuro que sube y se deshace, desde una caja de emisión (mezcla normal). `fuerza` escala la velocidad de subida. Lo usan la punta del haz y la cima del muro y del pilar.
func _humo_generico(c: Node3D, nombre: String, pos: Vector3, caja: Vector3, cant: int, fuerza: float) -> GPUParticles3D:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.name = nombre
	gp.position = pos
	gp.amount = cant
	gp.lifetime = 1.7
	gp.local_coords = true
	gp.fixed_fps = 0
	gp.emitting = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-4, -3, -4), Vector3(8, 9, 8))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caja
	pm.direction = Vector3(0, 1, -0.3)
	pm.spread = 28.0
	pm.initial_velocity_min = 0.5 * fuerza
	pm.initial_velocity_max = 1.1 * fuerza
	pm.gravity = Vector3(0, 0.7 * fuerza, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	pm.color_ramp = _gradiente([Color(0.26, 0.13, 0.08, 0.0), Color(0.22, 0.11, 0.07, 1.0), Color(0.16, 0.09, 0.07, 0.0)], [0.0, 0.25, 1.0])
	var curva: Curve = Curve.new()
	curva.add_point(Vector2(0, 0.35))
	curva.add_point(Vector2(1, 1.25))
	var ct: CurveTexture = CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	gp.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _textura_blanda()
	sm.disable_receive_shadows = true
	sm.render_priority = -1
	q.material = sm
	gp.draw_pass_1 = q
	gp.add_to_group("humo_haz", true)
	c.add_child(gp)
	return gp


## IDEA 1: salpicadura donde el haz choca. Una lámina pegada a la superficie (su normal es la de lo golpeado) con las llamas abriéndose en abanico por los lados, más chispas con estela que salen del
## choque y brasas que caen y quedan un instante brillando en el suelo. `ch` = {d, x, n} (ver `choques`). Con el tope de la escena lleno no se dibuja.
func _salpicadura(c: Node3D, ch: Dictionary, h: float, r: float, i: int) -> void:
	if _vivos_de(HAZ_GRUPO_SALPICADURA) >= HAZ_MAX_SALPICADURAS:
		return
	var n: Vector3 = ch.get("n", Vector3(0, 0, 1)) as Vector3
	n.y = 0.0
	n = n.normalized() if n.length() > 0.01 else Vector3(0, 0, 1)
	var p: Vector3 = Vector3(float(ch.get("x", 0.0)), h, -float(ch["d"]))
	var tam: float = clampf(r * 2.6 + 0.3, 1.8, 3.6)
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(tam, tam)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Salpicadura%d" % i
	mi.mesh = q
	mi.material_override = _mat_fuego(SH_SALPICADURA, {"semilla": randf() * 4.0 + float(i) * 0.37, "tope_calor": HAZ_TOPE_CALOR}, 1, _rampa_de_bola())
	var z: Vector3 = n
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	mi.transform = Transform3D(Basis(x, Vector3.UP, z), p + n * 0.06)
	mi.extra_cull_margin = 1.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(HAZ_GRUPO_SALPICADURA, true)
	c.add_child(mi)
	# la misma salpicadura TUMBADA en el suelo delante de lo golpeado: la cámara del juego mira a lo largo de Z, y una lámina vertical de normal X se vería de canto
	var qs: QuadMesh = QuadMesh.new()
	qs.size = Vector2(tam, tam)
	qs.orientation = PlaneMesh.FACE_Y
	var ms: MeshInstance3D = MeshInstance3D.new()
	ms.name = "SalpicaduraSuelo%d" % i
	ms.mesh = qs
	ms.material_override = _mat_fuego(SH_SALPICADURA, {"semilla": randf() * 4.0 + float(i) * 0.37 + 1.3, "tope_calor": HAZ_TOPE_CALOR, "suelo": 1.0}, 1, _rampa_de_bola())
	ms.position = Vector3(p.x, 0.16, p.z) + n * tam * 0.2
	ms.extra_cull_margin = 1.0
	ms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(ms)
	var gp: GPUParticles3D = _chispas_estela(c, "ChispasChoque%d" % i, p + n * 0.1, n, 8, false)
	_emisores_choque.append(gp)
	# brasas: puntos que quedan brillando un instante en el suelo, delante de lo golpeado
	var br: GPUParticles3D = _brasas_suelo(c, "Brasas%d" % i, Vector3(p.x, 0.05, p.z) + n * 0.7, 0.75)
	_emisores_choque.append(br)


## Brasas: puntos que quedan brillando un instante en el suelo (partículas quietas en un disco de `radio`).
func _brasas_suelo(c: Node, nombre: String, pos: Vector3, radio: float) -> GPUParticles3D:
	var br: GPUParticles3D = GPUParticles3D.new()
	br.name = nombre
	br.position = pos
	br.amount = 6
	br.lifetime = 0.9
	br.local_coords = true
	br.fixed_fps = 0
	br.emitting = false
	br.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	br.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 3, 8))
	var pb: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pb.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pb.emission_sphere_radius = radio
	pb.emission_shape_scale = Vector3(1, 0, 1)
	pb.gravity = Vector3.ZERO
	pb.initial_velocity_min = 0.0
	pb.initial_velocity_max = 0.0
	pb.color_ramp = _gradiente([Color(1.0, 0.5, 0.14, 0.0), Color(1.0, 0.45, 0.1, 0.95), Color(0.85, 0.16, 0.04, 0.0)], [0.0, 0.25, 1.0])
	var cb: Curve = Curve.new()
	cb.add_point(Vector2(0, 0.4))
	cb.add_point(Vector2(0.25, 1.0))
	cb.add_point(Vector2(1, 0.2))
	var cbt: CurveTexture = CurveTexture.new()
	cbt.curve = cb
	pb.scale_curve = cbt
	br.process_material = pb
	var qb: QuadMesh = QuadMesh.new()
	qb.size = Vector2(0.13, 0.13)
	var smb: StandardMaterial3D = StandardMaterial3D.new()
	smb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smb.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smb.vertex_color_use_as_albedo = true
	smb.albedo_texture = _textura_chispa()
	smb.disable_receive_shadows = true
	qb.material = smb
	br.draw_pass_1 = qb
	br.add_to_group("brasas_choque", true)
	c.add_child(br)
	return br


## Chispas con estela (RibbonTrailMesh): salen de `pos` hacia fuera (`n`) y hacia arriba, caen con gravedad y se apagan. `uno_solo`: una ráfaga y se acaba (el impacto de la bola).
func _chispas_estela(c: Node, nombre: String, pos: Vector3, n: Vector3, cant: int, uno_solo: bool) -> GPUParticles3D:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.name = nombre
	gp.position = pos
	gp.amount = cant
	gp.lifetime = 0.75
	gp.local_coords = true
	gp.fixed_fps = 0
	gp.emitting = uno_solo
	gp.one_shot = uno_solo
	gp.explosiveness = 0.85 if uno_solo else 0.0
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-4, -3, -4), Vector3(8, 8, 8))
	gp.trail_enabled = true
	gp.trail_lifetime = 0.16
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = (n + Vector3(0, 0.9, 0)).normalized()
	pm.spread = 55.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.2
	pm.gravity = Vector3(0, -9.5, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	pm.color_ramp = _gradiente([Color(1.0, 0.55, 0.16, 1.0), Color(1.0, 0.42, 0.1, 1.0), Color(0.9, 0.2, 0.05, 0.0)], [0.0, 0.6, 1.0])
	gp.process_material = pm
	var cinta: RibbonTrailMesh = RibbonTrailMesh.new()
	cinta.size = 0.07
	cinta.sections = 3
	cinta.section_length = 0.07
	cinta.section_segments = 2
	var sc: Curve = Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.0))
	cinta.curve = sc
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.use_particle_trails = true
	sm.vertex_color_use_as_albedo = true
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.disable_receive_shadows = true
	cinta.material = sm
	gp.draw_pass_1 = cinta
	gp.add_to_group("chispas_choque", true)
	c.add_child(gp)
	return gp


## IDEA 3: una mancha naranja-roja blanda en el suelo a lo largo del chorro, más fuerte en el punto de choque (decal que lee la profundidad: luz_suelo_haz.gdshader). Solo superficies horizontales
## y a `alto_max` sobre el suelo: no tiñe a la jugadora ni a los enemigos. Late con el chorro y se apaga al soltarse. No es una luz de verdad: la luz del hechizo sigue siendo UNA.
func _luz_suelo(c: Node3D, largo: float, cs: Array) -> void:
	if _vivos_de(HAZ_GRUPO_LUZ_SUELO) >= HAZ_MAX_LUCES_SUELO:
		return
	var longitud: float = largo + 1.8
	var centro_u: float = (largo + 0.6) * 0.5          # la caja cubre de u = -0,6 (detrás de la mano) a u = largo + 1,2 (pasada la punta, para el choque)
	var dim: Vector3 = Vector3(HAZ_LUZ_ANCHO, AvisoAreaFuego.ALTO_CAJA, longitud)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_LUZ_SUELO)
	m.render_priority = -2
	m.set_shader_parameter("rampa", _rampa_de_bola())
	m.set_shader_parameter("semilla", randf())
	m.set_shader_parameter("dim", dim)
	m.set_shader_parameter("centro_u", centro_u)
	m.set_shader_parameter("largo", largo)
	m.set_shader_parameter("centro_y", AvisoAreaFuego.CENTRO_Y)
	m.set_shader_parameter("alto_max", HAZ_LUZ_ALTO_MAX)
	for k in cs.size():
		var ch: Dictionary = cs[k]
		m.set_shader_parameter("choque_a" if k == 0 else "choque_b", Vector4(float(ch["d"]), float(ch.get("x", 0.0)), 1.3, 0.62))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "LuzSuelo"
	var caja: BoxMesh = BoxMesh.new()
	caja.size = Vector3.ONE
	mi.mesh = caja
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = dim
	mi.position = Vector3(0.0, AvisoAreaFuego.CENTRO_Y, -centro_u)
	mi.extra_cull_margin = 2.0
	mi.add_to_group(HAZ_GRUPO_LUZ_SUELO, true)
	c.add_child(mi)


# ------------------------------------------------------------------ ladrillos ------------------------------------------------------------------

static func _gradiente(colores: Array, offs: Array = []) -> GradientTexture1D:
	var g: Gradient = Gradient.new()
	var o: PackedFloat32Array = PackedFloat32Array()
	var cs: PackedColorArray = PackedColorArray()
	for i in colores.size():
		o.append(float(offs[i]) if offs.size() == colores.size() else float(i) / float(maxi(colores.size() - 1, 1)))
		cs.append(colores[i])
	g.offsets = o
	g.colors = cs
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	return t


static func _rampas() -> void:
	if _rampa_fuego != null:
		return
	var offs: Array = [0.0, 0.22, 0.62, 0.9, 1.0]
	_rampa_fuego = _gradiente([Color(0.85, 0.12, 0.03), Color(1.0, 0.32, 0.03), Color(1.0, 0.52, 0.08), Color(1.0, 0.74, 0.2), Color(1.0, 0.93, 0.62)], offs)
	_rampa_fuego.width = 128
	_rampa_bola = _gradiente([Color(0.85, 0.12, 0.03), Color(1.0, 0.32, 0.03), Color(1.0, 0.52, 0.08), Color(1.0, 0.64, 0.14), Color(1.0, 0.8, 0.42)], offs)
	_rampa_bola.width = 128
	_rampa_azul = _gradiente([Color(0.05, 0.2, 0.85), Color(0.15, 0.4, 1.0), Color(0.3, 0.65, 1.0), Color(0.55, 0.85, 1.0), Color(0.9, 0.98, 1.0)], offs)
	_rampa_azul.width = 128


static func _rampa_de_bola() -> GradientTexture1D:
	_rampas()
	return _rampa_bola


func _mat_fuego(shader: String, p: Dictionary, prio: int = 0, rampa: GradientTexture1D = null) -> ShaderMaterial:
	_rampas()
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader)
	m.render_priority = prio
	m.set_shader_parameter("lenguas", load(TEX + "T_FirePanningCyl45.png"))
	m.set_shader_parameter("ruido_a", load(TEX + "T_PerlinNoise_Tiled.png"))
	m.set_shader_parameter("ruido_v", load(TEX + "T_CloudNoise_Tiled.png"))
	m.set_shader_parameter("ruido_fino", load(TEX + "T_Noise1_tiled.png"))
	m.set_shader_parameter("rampa", rampa if rampa != null else _rampa_fuego)
	m.set_shader_parameter("rampa_azul", _rampa_azul)
	if not p.has("fade_canto"):
		m.set_shader_parameter("fade_canto", _fade_canto())
	if not p.has("suave_prof"):
		m.set_shader_parameter("suave_prof", _suave_prof())
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


## SUAVIZADO de las lÃ¡minas (revisiÃ³n de Pablo, Â«se notan muy 2DÂ» y Â«el corte recto con el sueloÂ»): las escenas validadas lo tienen apagado (valor 0 del shader); FuegoToy lo enciende.
## `fade_canto`: la superficie se desvanece cuando se ve de canto (|normal Â· vista| < valor): el muro, el pilar y el haz ya no se quedan en una raya fina con la cÃ¡mara baja; la bola es un billboard
## (nunca estÃ¡ de canto) y la barrera es una cÃºpula (su borde brillante es a propÃ³sito). `suave_prof`: fundido (m) contra la geometrÃ­a de detrÃ¡s, sin corte recto.
## `suavizado` = false lo apaga todo (para las capturas Â«antes / despuÃ©sÂ»).
static var suavizado: bool = true


func _fade_canto() -> float:
	if not suavizado:
		return 0.0
	match figura:
		Figura.MURO, Figura.PILAR, Figura.HAZ:
			return 0.3
	return 0.0


func _suave_prof() -> float:
	if not suavizado:
		return 0.0
	match figura:
		Figura.BOLA:
			return 0.15
		Figura.BARRERA:
			return 0.3
	return 0.22


## LÃMINAS Y-BILLBOARD (revisiÃ³n de Pablo, Â«las lÃ¡minas se notan muy 2D, sobre todo en las tomas horizontalesÂ»). Un MultiMesh (un solo draw call) de lÃ¡minas de lenguas que GIRAN alrededor de su
## eje vertical para mirar a la cÃ¡mara (fuego_lelu_vbb.gdshader) y estÃ¡n repartidas por el volumen del hechizo, en varias filas de profundidad y con su propia semilla / fase: con la cÃ¡mara baja
## se ve una masa de llama y no una tira plana, ni de frente ni de canto. Complementan a la banda (que sigue siendo la figura vista desde arriba): el shader las atenÃºa segÃºn la elevaciÃ³n de la
## cÃ¡mara, asÃ­ que con la del juego apenas se notan. `volumen` = false las apaga (capturas Â«antesÂ»). `metros`: [m por repeticiÃ³n horizontal, vertical, de ruido horizontal, de ruido vertical].
static var volumen: bool = true


func _laminas_vbb(padre: Node, nombre: String, laminas: Array, metros: Array, p: Dictionary) -> MultiMeshInstance3D:
	if not volumen or laminas.is_empty():
		return null
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = FuegoToyMallas.quad_vbb()
	mm.instance_count = laminas.size()
	for i in laminas.size():
		var l: Dictionary = laminas[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(float(l["w"]), float(l["h"]), 1.0)), l["pos"]))
		mm.set_instance_custom_data(i, Color(float(l["sem"]), float(l["hot"]), float(l["fase"]), float(l["alfa"])))
	var q: Dictionary = {"repeticion": Vector2(1.0 / float(metros[0]), 1.0 / float(metros[1])), "rep_ruido": Vector2(1.0 / float(metros[2]), 1.0 / float(metros[3])), "fade_canto": 0.0}
	for k in p:
		q[k] = p[k]
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = _mat_fuego(SH_VBB, q, 0)
	mi.extra_cull_margin = 0.6 + semieje_y * 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi

func _fuego(padre: Node, nombre: String, malla: Mesh, pos: Vector3, p: Dictionary, prio: int = 0, shader: String = SH_LELU, rampa: GradientTexture1D = null) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = malla
	mi.material_override = _mat_fuego(shader, p, prio, rampa)
	mi.position = pos
	mi.extra_cull_margin = 0.6 + semieje_y * 2.0          # las mallas se estiran con el mando `altura` (hasta 3) y se desplazan con el ruido
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


func _halo(padre: Node, nombre: String, tam: Vector2, pos: Vector3, brillo: float, caida: float, billboard: int, color: Color, extra: Dictionary = {}) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	var q: QuadMesh = QuadMesh.new()
	q.size = tam
	if billboard == 0:
		q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_HALO)
	m.set_shader_parameter("brillo", brillo)
	m.set_shader_parameter("caida", caida)
	m.set_shader_parameter("billboard", billboard)
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("semilla", randf())
	if suavizado:
		if billboard == 0:
			m.set_shader_parameter("fade_canto", 0.45)       # disco tumbado en el suelo (charco): de canto desaparece, no se queda en una raya
		else:
			m.set_shader_parameter("suave_prof", 0.3)        # resplandor billboard: sin corte recto contra el suelo o la pared
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	m.render_priority = -1
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


static func _textura_blanda() -> GradientTexture2D:
	if _blob != null:
		return _blob
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	_blob = GradientTexture2D.new()
	_blob.gradient = g
	_blob.fill = GradientTexture2D.FILL_RADIAL
	_blob.fill_from = Vector2(0.5, 0.5)
	_blob.fill_to = Vector2(1.0, 0.5)
	_blob.width = 64
	_blob.height = 64
	return _blob


## Punto de chispa: nÃºcleo brillante y caÃ­da rÃ¡pida (mÃ¡s concentrada que `_textura_blanda`, que en una chispa pequeÃ±a se ve como una burbuja pÃ¡lida).
static var _punto: GradientTexture2D = null


static func _textura_chispa() -> GradientTexture2D:
	if _punto != null:
		return _punto
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
	_punto = GradientTexture2D.new()
	_punto.gradient = g
	_punto.fill = GradientTexture2D.FILL_RADIAL
	_punto.fill_from = Vector2(0.5, 0.5)
	_punto.fill_to = Vector2(1.0, 0.5)
	_punto.width = 64
	_punto.height = 64
	return _punto


## PartÃ­culas blandas y pequeÃ±as (la rampa de colores va de nacer a morir). `visto`: radio en planta que cubre su caja de visibilidad.
func _particulas(padre: Node, nombre: String, cantidad: int, vida_s: float, tam: float, caja: Vector3, vel: Vector2, dir: Vector3, abierto: float, gravedad: Vector3,
		colores: Array, grupo: String, pos: Vector3, visto: float) -> GPUParticles3D:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.name = nombre
	gp.position = pos
	gp.amount = cantidad
	gp.lifetime = vida_s
	gp.local_coords = true
	gp.fixed_fps = 0
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var e: float = maxf(6.0, visto)
	gp.visibility_aabb = AABB(Vector3(-e, -3, -e), Vector3(2.0 * e, 12.0 + semieje_y * 2.0, 2.0 * e))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caja
	pm.direction = dir
	pm.spread = abierto
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = gravedad
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	pm.color_ramp = _gradiente(colores)
	var curva: Curve = Curve.new()
	curva.add_point(Vector2(0, 0.0))
	curva.add_point(Vector2(0.15, 1.0))
	curva.add_point(Vector2(1, 0.15))
	var ct: CurveTexture = CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	gp.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(tam, tam)
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _textura_blanda()
	sm.disable_receive_shadows = true
	q.material = sm
	gp.draw_pass_1 = q
	gp.add_to_group(grupo, true)
	padre.add_child(gp)
	return gp


## Trocitos de llama que se desprenden de las puntas (rampa amarillo â†’ naranja â†’ rojo). `v`: factor de velocidad.
func _trocitos(c: Node, cantidad: int, caja: Vector3, pos: Vector3, v: float) -> void:
	_particulas(c, "Trocitos", cantidad, 0.5, 0.2, caja, Vector2(0.7, 1.4) * v, Vector3(0, 1, 0), 15.0, Vector3(0, 0.4, 0) * v,
		[Color(1.0, 0.7, 0.2, 0.9), Color(1.0, 0.38, 0.08, 0.8), Color(0.85, 0.15, 0.04, 0.0)], "trocitos", pos, maxf(caja.x, caja.z) * 2.0 + 4.0)


func _anim_si_hace_falta() -> void:
	var ap: AnimationPlayer = get_node_or_null("Anim") as AnimationPlayer
	if ap != null and _figura_anim == int(figura):
		return
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "Anim"
		add_child(ap)
	_figura_anim = int(figura)
	var nacer: float = 0.3
	var morir_s: float = 0.5
	match figura:
		Figura.PILAR:
			nacer = 0.4
			morir_s = 0.6
		Figura.BARRERA:
			nacer = 0.5
			morir_s = 0.6
		Figura.HAZ:
			nacer = 0.4
			morir_s = 1.0
	var lib: AnimationLibrary = AnimationLibrary.new()
	var es_haz: bool = figura == Figura.HAZ
	for nom in ["nacer", "vivir", "morir"]:
		var an: Animation = Animation.new()
		var pista: int = an.add_track(Animation.TYPE_VALUE)
		# el haz no se encoge: «nacer» lo hace SALIR del origen (crece 0 → 1) y «morir» lo SUELTA (corte 0 → 1); el resto de figuras anima `aparicion`
		an.track_set_path(pista, NodePath(".:crece" if (es_haz and nom == "nacer") else (".:corte" if es_haz else ".:aparicion")))
		match nom:
			"nacer":
				an.length = nacer
				an.track_insert_key(pista, 0.0, 0.0)
				an.track_insert_key(pista, nacer, 1.0)
				an.track_set_interpolation_type(pista, Animation.INTERPOLATION_CUBIC)
			"vivir":
				an.length = 1.0
				an.loop_mode = Animation.LOOP_LINEAR
				an.track_insert_key(pista, 0.0, 0.0 if es_haz else 1.0)
			"morir":
				an.length = morir_s
				an.track_insert_key(pista, 0.0, 0.0 if es_haz else 1.0)
				an.track_insert_key(pista, morir_s, 1.0 if es_haz else 0.0)
				an.track_set_interpolation_type(pista, Animation.INTERPOLATION_CUBIC)
		lib.add_animation(nom, an)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	dura_morir = morir_s
