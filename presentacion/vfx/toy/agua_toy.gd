class_name AguaToy
extends EfectoToy

## AGUA «TOY» (3/11/2026, FASE 1 de docs/PROPUESTA_AGUA_TOY_2026-11-02.md: el ciclo completo de un PROYECTIL). Clase HERMANA de FuegoToy: misma API, mismos ejes (semieje_x / y / z en m), misma escala y
## los mismos mandos (los diez de EfectoToy; los de luz y halo no hacen nada en el agua, que no brilla). FuegoToy no se ha tocado: la máquina de carga e impacto está copiada, no compartida (la unificación
## en una base común queda para cuando los dos elementos estén aprobados).
## Es AGUA, no luz: todos los shaders son blend_mix y unshaded (agua_toy.gdshaderinc: tres tonos por umbral, fresnel, cáusticas T_Noise_Wf4 que se mueven, flujo de ruido, espuma por umbral, fundido de
## canto y de profundidad). No hay luces, ni materiales aditivos, ni GPUParticles3D: las gotas son un MultiMesh movido por la CPU.
##
## FIGURAS: BOLA, HAZ (fase 2), PILAR / géiser (fase 3) y MURO = OLA (fase 4) están hechas. Solo la BARRERA (cúpula, fase 5) cae a un MARCADOR PROVISIONAL: un elipsoide de agua con el tamaño de los semiejes.
## PALETA: la del agua del mundo, centralizada en agua_paleta.gd (hondo / somero / espuma, cáusticas, lecho, tinte de fresnel); AguaMallas.material() y AguaGotas la pasan a todos los shaders.
##
## BOLA: esfera translúcida con cáusticas, borde claro por fresnel y un núcleo más claro; 3 cintas de agua en espiral alrededor que giran. En vuelo (`viaja` / `proyectil`) las cintas se alargan hacia atrás
## en una estela más fina que la cabeza y la bola suelta gotitas que se quedan en el mundo y CAEN con gravedad. Quieta, suelta alguna gota de vez en cuando.
##
## Ciclo de vida de un proyectil de agua, sobre UN SOLO nodo (igual que FuegoToy):
##   empezar_carga(duracion, tam_final)  durante `duracion` s (radio final `tam_final`, en m, o semiejes Vector3) aparecen gotitas alrededor de la mano que CONVERGEN formando la esfera, que va
##                                       creciendo en la mano; un remolino pequeño de cintas gira alrededor y dos anillos de ondas se expanden en el suelo bajo los pies (`pies`). Sutil, SIN brillo.
##                                       Si se sostiene más, «respira» (±carga_respiro). NO hace falta `lanzar()`.
##   progreso_carga() -> float           0 → 1 (se queda en 1 al sostener, y tras soltar)
##   soltar(dir)                         ESA MISMA bola (mismo nodo) pasa a proyectil apuntando a `dir`; si estaba a medio crecer se asienta al tamaño final en T_SOLTAR s sin salto. Quien la mueve es
##                                       el juego (HechizoVivo) o el lab.
##   cancelar_carga()                    se encoge y se apaga en T_CANCELAR s y se libera
##   impactar_en(pos, normal, escala)    ImpactoAguaToy GOLPE orientado por la normal (corona de gotas que caen, lámina, anillo de ondas, vaho); la bola desaparece en seguida
##   rebotar(pos, normal) -> Vector3     salpicadura pequeña; la bola SIGUE; devuelve la dirección reflejada (y la bola mira hacia ella)
##   terminar_sin_choque()               el hechizo se agota en el aire: la bola se encoge y se deshace en gotas que caen (variante FIN)
##   finalizar(motivo, pos, normal)      atajo para HechizoVivo._terminar(causa)
## `impactar()` (contrato EfectoVfx3D) también funciona. `definir`, `describir`, `desde_hechizo` y `preparar` son los de FuegoToy (figura y tamaño salen del Hechizo).

enum Figura { BOLA, MURO, PILAR, BARRERA, HAZ }
enum EstadoCarga { NINGUNA, CARGANDO, SOLTANDO, APAGANDO, CANCELANDO }

const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")
const AguaGotas = preload("res://presentacion/vfx/toy/agua_gotas.gd")
const AguaMallas = preload("res://presentacion/vfx/toy/agua_mallas.gd")
const CargaAgua = preload("res://presentacion/vfx/toy/carga_agua_toy.gd")

## Tamaños de referencia (iguales a los de FuegoToy: un hechizo cambia de elemento sin cambiar de tamaño).
const REF_BOLA: Vector3 = Vector3(0.4, 0.4, 0.4)
const REF_MURO: Vector3 = Vector3(3.45, 1.5, 0.3)
const REF_PILAR: Vector3 = Vector3(0.5, 4.0, 0.5)
const REF_BARRERA: Vector3 = Vector3(1.5, 1.5, 1.5)
const REF_HAZ: Vector3 = Vector3(1.5, 0.5, 0.15)

const T_SOLTAR: float = 0.14            ## s que tarda en asentarse al tamaño final al soltar si estaba respirando o sin acabar de crecer
const T_APAGAR: float = 0.5             ## s que tarda en encogerse el fin sin choque
const T_CANCELAR: float = 0.2
const RESPIRO_HZ: float = 1.4
const GOTAS_RESERVA: int = 44           ## huecos de la reserva de gotas de la bola
const GIRO_QUIETA: float = 1.5          ## rad/s de las cintas con la bola quieta
const GIRO_VUELO: float = 6.5           ## ... y en vuelo
const INCLINACION_QUIETA: float = 24.0  ## ° que se inclina el eje de las cintas con la bola quieta (en vuelo van sobre el eje del vuelo)
const N_CINTAS: int = 2                 ## cintas finas que envuelven la bola sin taparla (cobertura de la esfera < ~30 %)
const N_ESTELA: int = 2                 ## cintas de la estela en vuelo
const GOTAS_RESERVA_HAZ: int = 72       ## huecos de la reserva de gotas del haz
const T_COLA: float = 0.16             ## s que tarda en salir la estela al empezar a volar
const GOTAS_RESERVA_PILAR: int = 56     ## huecos de la reserva de gotas del pilar (suben y caen)
const N_ESPUMA_BASE: int = 10           ## bocanadas de espuma alrededor de la base del pilar
const N_ESPUMA_CRESTA: int = 4          ## ... y en la cresta
const GOTAS_RESERVA_OLA: int = 60         ## huecos de la reserva de gotas de la ola (saltan de la cresta y caen)
const N_FRANJAS_OLA: int = 12            ## franjas de espuma tumbadas en el pie de la ola
const T_OLA_NACER: float = 0.75
const T_OLA_MORIR: float = 1.9
const T_PILAR_NACER: float = 0.6
const T_PILAR_MORIR: float = 1.2

@export_group("Figura y ejes (m)")
@export var figura: Figura = Figura.BOLA: set = _set_figura
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_x: float = 0.4: set = _set_x
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_y: float = 0.4: set = _set_y
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_z: float = 0.4: set = _set_z
@export var viaja: bool = false: set = _set_viaja
## HAZ: `crece` (0 → 1: el chorro sale del origen; lo anima «nacer») y `corte` (0 → 1: se suelta del origen, avanza y se rompe en gotas que caen; lo anima «morir»).
@export_range(0.0, 1.0, 0.01) var crece: float = 1.0: set = _set_crece
@export_range(0.0, 1.0, 0.01) var corte: float = 0.0: set = _set_corte
@export_group("Carga del hechizo")
@export_range(0.03, 0.6, 0.01) var carga_tam_inicial: float = 0.12
@export_range(0.3, 3.0, 0.05) var carga_curva: float = 0.8
@export_range(0, 36, 1) var carga_chispas: int = 28: set = _set_carga_chispas      ## gotitas que convergen en la mano (la cuarta parte al principio: crecen con la carga)
@export_range(0.0, 3.0, 0.05) var carga_destello: float = 1.0                      ## sin uso en el agua (no hay destello); existe para que los mandos del lab valgan para los dos elementos
@export_range(0.0, 0.2, 0.005) var carga_respiro: float = 0.05
@export_range(0.0, 3.0, 0.05) var carga_brillo: float = 1.0: set = _set_carga_brillo       ## opacidad del remolino y de las ondas (el agua no brilla)
@export_range(0.5, 2.0, 0.05) var carga_radio: float = 1.0: set = _set_carga_radio         ## × el radio de la nube de gotitas
@export var carga_bola_visible: bool = true: set = _set_carga_bola_visible              ## true: la esfera se va formando en la mano (por defecto); false: solo gotitas y remolino, y la bola aparece al soltar
@export_group("Impacto")
## true: al impactar, en vez de la salpicadura de un proyectil, explota en ÁREA (ImpactoAguaToy.Variante.AREA, escala con `escala` o con el radio de la bola). `desde_hechizo` lo pone en las zonas.
@export var area_al_impactar: bool = false
@export_group("Mundo")
## Dónde están los pies respecto al nodo (local, -Z = delante): ahí nacen las ondas del casteo.
@export var pies: Vector3 = Vector3(0, -0.7, 0.5)
## Altura (m) del nodo sobre el suelo: las gotas que caen por debajo de ella desaparecen.
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
var _c_visual: Node3D = null            ## CargaAgua: gotitas que convergen, remolino y ondas
var _pop: bool = false
var _gotas: Node3D = null               ## reserva de gotas (AguaGotas), top_level
var _acc_gotas: float = 0.0
var _ult_pos: Vector3 = Vector3.ZERO
var _tiene_ult: bool = false
var _vel_mundo: Vector3 = Vector3.ZERO
var _inclin: float = INCLINACION_QUIETA
var _cola_f: float = 0.0
var _cintas: Node3D = null
var _inclinable: Node3D = null
var _estela: Node3D = null
var _marcador: bool = false
var _haz_cintas: Node3D = null          ## cintas enrolladas en el haz (giran despacio alrededor de su eje)
var _haz_punta: Node3D = null           ## abanico de salpicadura y espuma al final del haz (sigue a la punta)
var _haz_largo: float = 3.0
var _haz_alt: float = 0.5
var _haz_r: float = 0.36
var _acc_haz: float = 0.0
var _acc_abanico: float = 0.0
var _acc_corte: float = 0.0
var _pil_lam: MultiMeshInstance3D = null    ## PILAR: corona de lenguas (láminas Y-billboard)
var _pil_esp: MultiMeshInstance3D = null    ## PILAR: bocanadas de espuma de la cresta
var _pil_fra: MultiMeshInstance3D = null    ## PILAR: franjas de espuma tumbadas en el borde de la base (fase 4: ya no son bolas de algodón)
var _pil_charco: MeshInstance3D = null      ## PILAR: anillo de ondas / charco en el suelo
var _pil_cr_ant: float = 0.0
var _pil_acc: float = 0.0
var _pil_acc2: float = 0.0
var _pil_acc3: float = 0.0
var _pil_esp_datos: Array = []              ## (pruebas) última espuma puesta: [{pos, tam, alfa}]
var _pil_charco_u: float = 0.0
var _ola_cuerpo: MultiMeshInstance3D = null  ## OLA: láminas Y-billboard de cuerpo (filas de profundidad)
var _ola_cresta: MultiMeshInstance3D = null  ## OLA: láminas Y-billboard de cresta (T_Wave66)
var _ola_fra: MultiMeshInstance3D = null     ## OLA: franjas de espuma del pie
var _ola_charco: MeshInstance3D = null       ## OLA: charco que deja al caer
var _ola_hojas: Array = []                   ## OLA: las tres cortinas
var _ola_t: float = 0.0                      ## s que lleva viva (asentada)
var _ola_avance: float = 0.0
var _ola_acc: float = 0.0
var _ola_acc2: float = 0.0
var _ola_charco_u: float = 0.0
var _ola_franjas_datos: Array = []           ## (pruebas) [{pos, largo, alfa}]


func _ready() -> void:
	_construir()
	super._ready()
	_construido = true
	_set_proyectil(viaja)
	_montar_gotas()


# ------------------------------------------------------------------ interfaz ------------------------------------------------------------------

func _set_figura(v: Figura) -> void:
	figura = v
	_pedir()


func _set_crece(v: float) -> void:
	crece = v
	_param_mats("crece", v)


func _set_corte(v: float) -> void:
	corte = v
	_param_mats("corte", v)


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
	_montar_gotas()


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
		_cuerpo.visible = true                        # la MISMA bola aparece con un pequeño «pop»
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


## Las gotitas y el remolino de la carga se desvanecen en `dur` s y se liberan solos.
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
			_aplicar_escala_carga()
			if u3 >= 1.0:
				_est = EstadoCarga.NINGUNA
				_c_escala = 0.001
				_aplicar_escala_carga()
				get_tree().create_timer(0.85).timeout.connect(queue_free)      # deja caer las gotas que quedan en el mundo


## Gotitas, remolino y ondas del casteo (CargaAgua). Cuelga de un nodo «Carga» que no escala con la bola.
func _montar_carga() -> void:
	var viejo: Node = get_node_or_null("Carga")
	if viejo != null:
		remove_child(viejo)
		viejo.free()
	_c_nodo = Node3D.new()
	_c_nodo.name = "Carga"
	add_child(_c_nodo)
	_c_visual = CargaAgua.new()
	_c_visual.name = "Convergencia"
	_c_nodo.add_child(_c_visual)
	_c_visual.call("montar", _c_r, carga_chispas, carga_brillo, carga_radio, pies)


func _radio_impacto(escala: float) -> float:
	return escala if escala > 0.0 else maxf(semieje_x, semieje_z)


func _crear_impacto(variante: ImpactoAguaToy.Variante, normal: Vector3, escala: float, pos: Vector3) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var imp: ImpactoAguaToy = ImpactoAguaToy.crear(variante, normal, _radio_impacto(escala))
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


func _quitar_vuelo() -> void:
	_quitar_visual_carga(0.05)


## Las gotas sueltas siguen cayendo aunque la bola desaparezca: la reserva pasa al padre y se libera sola al cabo de un segundo.
func _soltar_gotas() -> void:
	if _gotas == null or not is_instance_valid(_gotas) or get_parent() == null or not is_inside_tree():
		return
	var padre: Node = get_parent()
	remove_child(_gotas)
	padre.add_child(_gotas)
	_gotas.top_level = true
	get_tree().create_timer(1.0).timeout.connect(_gotas.queue_free)
	_gotas = null


## Explosión de ÁREA de agua (ImpactoAguaToy.Variante.AREA) en `pos` (sobre el suelo, normal arriba) con `radio` m de radio: estallido blanco-celeste, columnas de lenguas que suben desde charcos repartidos,
## cuernos que se curvan hacia fuera y caen, y un charco grande con anillos. No toca a la bola (si hay una, hay que quitarla aparte): sirve también suelta, sin AguaToy vivo.
func explotar_area(pos: Vector3, radio: float = -1.0) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var r: float = radio if radio > 0.0 else maxf(maxf(semieje_x, semieje_z), 0.3)
	var imp: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.AREA, Vector3.UP, r)
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


func impactar_en(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Node3D:
	var imp: Node3D
	if area_al_impactar:
		imp = explotar_area(pos, escala)
	else:
		imp = _crear_impacto(ImpactoAguaToy.Variante.GOLPE, normal, escala, pos)
	_est = EstadoCarga.NINGUNA
	_quitar_vuelo()
	_soltar_gotas()
	if _ap != null and _ap.has_animation("morir"):
		_ap.speed_scale = 4.0                     # la bola se apaga en 0,12 s mientras la salpicadura se abre
	morir()
	return imp


func rebotar(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Vector3:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var d: Vector3 = -global_transform.basis.z if is_inside_tree() else Vector3.FORWARD
	var nd: Vector3 = (d - 2.0 * d.dot(n) * n).normalized()
	_crear_impacto(ImpactoAguaToy.Variante.REBOTE, n, escala, pos)
	if is_inside_tree():
		global_position = pos
		look_at(pos + nd, Vector3.UP if absf(nd.y) < 0.99 else Vector3.FORWARD)
		_ult_pos = pos
	if _gotas != null and is_instance_valid(_gotas):
		_gotas.call("vaciar")                     # la cola vieja apuntaba a la pared
	_cola_f = 0.3
	return nd


func terminar_sin_choque() -> void:
	if _est == EstadoCarga.APAGANDO or _est == EstadoCarga.CANCELANDO:
		return
	_crear_impacto(ImpactoAguaToy.Variante.FIN, Vector3.UP, -1.0, global_position)
	_quitar_vuelo()
	_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.APAGANDO


## Atajo para HechizoVivo._terminar(causa): qué hace la bola según el motivo del fin.
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


## Escala el efecto a un volumen de hechizo ({x, y, z} en casillas) sin escalar el nodo: la geometría se rehace con los semiejes en metros.
func preparar(volumen: Dictionary, dir: Vector3, _elemento: String = "agua") -> void:
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
	# una zona (esfera o elipsoide que no viaja ni es muro, pilar, barrera ni haz) explota en área al acabar; un proyectil, no
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
	_cintas = null
	_inclinable = null
	_estela = null
	_marcador = false
	_haz_cintas = null
	_haz_punta = null
	_pil_lam = null
	_pil_esp = null
	_pil_fra = null
	_pil_charco = null
	_ola_cuerpo = null
	_ola_cresta = null
	_ola_fra = null
	_ola_charco = null
	_ola_hojas = []
	_ola_t = 0.0
	_ola_avance = 0.0
	_pil_cr_ant = 0.0
	tam_referencia = Vector3(semieje_x, semieje_y, semieje_z) * 2.0
	_avance_cabeza = 0.0
	if figura == Figura.BOLA:
		_bola(cuerpo)
	elif figura == Figura.HAZ:
		_haz(cuerpo)
	elif figura == Figura.PILAR:
		_pilar(cuerpo)
	elif figura == Figura.MURO:
		_ola(cuerpo)
	else:
		_marcador_provisional(cuerpo)
	_anim_si_hace_falta()


## Material de la esfera: la cara de atrás (más tenue) y, encima, la de delante (next_pass).
func _mat_esfera(radio_malla: float, semilla: float, prio: int) -> ShaderMaterial:
	var p: Dictionary = {"radio": radio_malla, "semilla": semilla, "suave_prof": 0.15}
	var atras: ShaderMaterial = AguaMallas.material(AguaMallas.SH_ESFERA_ATRAS, p, prio)
	atras.next_pass = AguaMallas.material(AguaMallas.SH_ESFERA, p, prio)
	return atras


func _bola(c: Node3D) -> void:
	var r: float = maxf(semieje_x, semieje_z)
	var sem: float = randf()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = 2.0 * r
	sm.radial_segments = 48
	sm.rings = 24
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Esfera"
	mi.mesh = sm
	mi.material_override = _mat_esfera(r, sem, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(mi)
	# cintas en espiral alrededor de la bola (eje Z: en vuelo es el del vuelo; quieta se inclina)
	_inclinable = Node3D.new()
	_inclinable.name = "Inclinable"
	c.add_child(_inclinable)
	_cintas = Node3D.new()
	_cintas.name = "Cintas"
	_inclinable.add_child(_cintas)
	var rb: float = 1.14 * r
	for k in N_CINTAS:
		var f: float = float(k) / float(N_CINTAS) + 0.08
		var malla: ArrayMesh = AguaMallas.cinta(-0.74 * rb, 0.74 * rb, 1.0 + 0.25 * float(k), f, 44,
			func(_u: float, z: float) -> float: return sqrt(maxf(rb * rb - z * z, 0.0)) + 0.02 * r,
			func(u: float) -> float: return r * 0.105 * pow(sin(PI * clampf(u, 0.02, 0.98)), 0.6))
		var m: MeshInstance3D = MeshInstance3D.new()
		m.name = "Env%d" % k
		m.mesh = malla
		m.material_override = AguaMallas.material(AguaMallas.SH_CINTA, {"fase": f * 2.3, "repeticion": 1.5, "opacidad": 0.66, "suave_prof": 0.15, "extremos": 0.22, "punta": 0.22}, 1)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cintas.add_child(m)
	# estela (solo en vuelo): 2 cintas que se ARRASTRAN detrás, más estrechas que la cabeza, con ondulación irregular (no giran con la cinta envolvente: no es una hélice) y se deshacen
	_estela = Node3D.new()
	_estela.name = "Estela"
	_inclinable.add_child(_estela)
	var largos: Array = [3.1, 2.3]
	var vueltas: Array = [0.55, 0.85]
	for k in N_ESTELA:
		var f2: float = 0.17 + 0.43 * float(k)
		var L: float = r * float(largos[k])
		var mal2: float = 3.0 + 2.2 * float(k)            # frecuencia de la ondulación irregular de cada cinta
		var malla2: ArrayMesh = AguaMallas.cinta(0.5 * r, 0.5 * r + L, float(vueltas[k]), f2, 56,
			func(u: float, _z: float) -> float: return r * (0.40 * pow(1.0 - u, 0.9) + 0.04) * (1.0 + 0.32 * sin(u * mal2 * 2.3 + f2 * 11.0) * sin(u * 5.1 + f2 * 3.0 + 1.0)),
			func(u: float) -> float: return r * 0.17 * pow(1.0 - u, 0.6) * (0.8 + 0.4 * sin(u * 9.0 + f2 * 5.0)) + 0.004)
		var m2: MeshInstance3D = MeshInstance3D.new()
		m2.name = "Est%d" % k
		m2.mesh = malla2
		m2.material_override = AguaMallas.material(AguaMallas.SH_CINTA, {"fase": f2 * 3.1, "repeticion": 1.4, "opacidad": 0.5, "suave_prof": 0.15, "extremos": 0.1, "punta": 0.7, "ritmo": 0.9}, 1)
		m2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_estela.add_child(m2)
	_estela.visible = false


# ------------------------------------------------------------------ HAZ ------------------------------------------------------------------

## HAZ DE AGUA (fase 2): chorro que NACE DE UN PUNTO en el origen (la mano) hacia -Z a la altura máx(y, 0,4). Reutiliza la geometría del haz de fuego (FuegoToyMallas.haz_cono, sin tocarla) con un
## shader de agua (agua_haz.gdshader): tubo translúcido celeste con flujo rápido hacia fuera, un núcleo más claro y más fino, 2 cintas enrolladas, gotas que se desprenden a lo largo y caen, y un
## abanico de salpicadura (SparklesF21 recoloreado + espuma + gotas hacia delante) donde termina. `crece` lo hace salir y `corte` lo suelta y lo rompe en gotas.
func _haz(c: Node3D) -> void:
	_haz_largo = semieje_x * 2.0
	_haz_r = semieje_z * FuegoToy.HAZ_ABRE
	_haz_alt = maxf(semieje_y, 0.4)
	var largo: float = _haz_largo
	var r: float = _haz_r
	var malla: ArrayMesh = FuegoToyMallas.haz_cono(largo, FuegoToy.HAZ_R_ORIGEN, r)
	var p: Dictionary = {"largo": largo, "r_origen": FuegoToy.HAZ_R_ORIGEN, "r_fin": r, "crece": crece, "corte": corte, "suave_prof": 0.15, "opacidad": 0.6, "semilla": 0.0}
	var tubo: MeshInstance3D = _mi_agua(c, "Chorro", malla, AguaMallas.material(AguaMallas.SH_HAZ, p, 0))
	tubo.position = Vector3(0, _haz_alt, 0)
	tubo.extra_cull_margin = 1.0
	var pn: Dictionary = p.duplicate()
	pn["grosor"] = 0.5
	pn["semilla"] = 0.6
	pn["nucleo"] = 1.0
	pn["opacidad"] = 0.6
	pn["v_chorro"] = 1.45
	pn["desfase"] = 1.0
	var nuc: MeshInstance3D = _mi_agua(c, "Nucleo", malla, AguaMallas.material(AguaMallas.SH_HAZ, pn, 1))
	nuc.position = Vector3(0, _haz_alt, 0)
	nuc.extra_cull_margin = 1.0
	# 2 cintas enrolladas alrededor del chorro (giran despacio): sus radios siguen al cono
	_haz_cintas = Node3D.new()
	_haz_cintas.name = "Cintas"
	_haz_cintas.position = Vector3(0, _haz_alt, 0)
	c.add_child(_haz_cintas)
	for k in 2:
		var f: float = 0.5 * float(k) + 0.1
		var vueltas: float = 2.4 + 0.9 * float(k)
		var malla2: ArrayMesh = AguaMallas.cinta(0.0, -largo, vueltas, f, 90,
			func(u: float, _z: float) -> float: return 0.7 * FuegoToyMallas.ancho_haz(u, FuegoToy.HAZ_R_ORIGEN, r) * (1.0 + 0.18 * sin(u * 11.0 + f * 7.0)),
			func(u: float) -> float: return largo * 0.05 * pow(sin(PI * clampf(u, 0.01, 0.99)), 0.5) + 0.004)
		var m: MeshInstance3D = MeshInstance3D.new()
		m.name = "Cinta%d" % k
		m.mesh = malla2
		m.material_override = AguaMallas.material(AguaMallas.SH_HAZ_CINTA, {"largo": largo, "crece": crece, "corte": corte, "fase": f * 2.7, "opacidad": 0.55, "suave_prof": 0.15, "ritmo": 1.4 + 0.3 * float(k)}, 2)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.extra_cull_margin = 1.0
		_haz_cintas.add_child(m)
	# abanico de salpicadura y espuma en la punta
	_haz_punta = Node3D.new()
	_haz_punta.name = "Punta"
	c.add_child(_haz_punta)
	var fan: MeshInstance3D = SpriteToy.crear("Abanico", "T_VFX_SparklesF21.jpg", SpriteToy.Modo.MEZCLA, false,
		{"recorte": Vector2(0.18, 0.75), "luminancia": Vector2(0.1, 0.95), "tramo": Vector2(0.3, 1.0), "brillo": 1.0, "giro": randf() * TAU, "vida": 0.0}, 3)
	SpriteToy.mat(fan).set_shader_parameter("rampa", AguaMallas.rampa_sprites())
	fan.scale = Vector3.ONE * 0.001
	_haz_punta.add_child(fan)
	for k in 3:
		var pf: MeshInstance3D = AguaMallas.puff("Espuma%d" % k, Vector2(0.62, 0.95))
		pf.set_meta("ang", TAU * float(k) / 3.0 + randf())
		_haz_punta.add_child(pf)


func _mi_agua(c: Node3D, nombre: String, malla: Mesh, mat: ShaderMaterial) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = malla
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(mi)
	return mi


## Posición local de la punta del chorro (se desplaza con `corte`: el chorro suelto avanza).
func _haz_z_punta() -> float:
	return -(crece + corte * 0.6) * _haz_largo * 0.97


func _avanzar_haz(delta: float) -> void:
	if figura != Figura.HAZ or _haz_punta == null or not is_instance_valid(_haz_punta) or not _listo:
		return
	if _haz_cintas != null and is_instance_valid(_haz_cintas):
		_haz_cintas.rotate_object_local(Vector3(0, 0, 1), 2.6 * velocidad * delta)
	_haz_punta.position = Vector3(0, _haz_alt, _haz_z_punta())
	var vive: float = smoothstep(0.6, 1.0, crece) * (1.0 - smoothstep(0.0, 0.5, corte))
	var r: float = _haz_r
	var tt: float = Time.get_ticks_msec() * 0.001
	var fan: MeshInstance3D = _haz_punta.get_node_or_null("Abanico") as MeshInstance3D
	if fan != null:
		var s: float = r * 2.7 * (0.85 + 0.15 * sin(tt * 13.0))
		fan.scale = Vector3(s, s, 1.0)
		SpriteToy.mat(fan).set_shader_parameter("vida", 0.4 * vive)
		SpriteToy.mat(fan).set_shader_parameter("giro", tt * 0.5)
	for k in 3:
		var pf: MeshInstance3D = _haz_punta.get_node_or_null("Espuma%d" % k) as MeshInstance3D
		if pf == null:
			continue
		var ang: float = float(pf.get_meta("ang", 0.0)) + tt * 1.6
		pf.position = Vector3(cos(ang) * r * 0.9, sin(ang) * r * 0.9 + r * 0.2, r * 0.5 * float(k))
		var sz: float = r * (1.1 + 0.25 * sin(tt * 7.0 + float(k)))
		pf.scale = Vector3(sz, sz, 1.0)
		(pf.material_override as ShaderMaterial).set_shader_parameter("vida", 0.26 * vive)


## Gotas del haz (reserva top_level: se quedan en el mundo y caen): se desprenden a lo largo, SALPICAN en abanico hacia delante en la punta y, al cortarse, el chorro se rompe en gotas.
func _emitir_haz(delta: float) -> void:
	var g: Node3D = _gotas
	g.set("suelo_y", global_position.y - 0.02)
	var cr: float = crece
	var co: float = corte
	var largo: float = _haz_largo
	var r: float = _haz_r
	var vive: float = smoothstep(0.1, 0.9, cr) * (1.0 - smoothstep(0.85, 1.0, co)) * clampf(chispas, 0.0, 1.0)
	if vive <= 0.001:
		return
	var tr: Transform3D = global_transform
	var bas: Basis = tr.basis
	# 1) a lo largo: gotitas que se despegan del chorro y caen
	_acc_haz += 24.0 * vive * delta
	while _acc_haz >= 1.0:
		_acc_haz -= 1.0
		var s: float = randf_range(0.12, 0.98) * cr + co * 0.6
		var rad: float = FuegoToyMallas.ancho_haz(s / maxf(cr, 0.05), FuegoToy.HAZ_R_ORIGEN, r)
		var loc: Vector3 = Vector3(randf_range(-0.9, 0.9) * rad, _haz_alt + randf_range(-0.2, 1.0) * rad, -s * largo)
		var vel: Vector3 = bas * Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.9), -randf_range(0.5, 2.2))
		var burb: bool = randf() < 0.1
		g.call("emitir", tr * loc, vel, randf_range(0.45, 0.8), randf_range(0.04, 0.085), 1 if burb else 0, 0.9, randf(), 1.0)
	# 2) abanico de salpicadura en la punta (mientras el chorro llega)
	var punta: float = smoothstep(0.7, 1.0, cr) * (1.0 - smoothstep(0.0, 0.5, co))
	_acc_abanico += 38.0 * punta * clampf(chispas, 0.0, 1.0) * delta
	var z_p: float = _haz_z_punta()
	while _acc_abanico >= 1.0:
		_acc_abanico -= 1.0
		var ang: float = randf() * TAU
		var abre: float = randf_range(0.2, 1.0)
		var dir: Vector3 = Vector3(cos(ang) * abre * 0.95, sin(ang) * abre * 0.8 + 0.25, -randf_range(0.35, 1.0)).normalized()
		var rapidez: float = randf_range(1.9, 4.6)
		var tam: float = randf_range(0.05, 0.12)
		g.call("emitir", tr * Vector3(randf_range(-0.3, 0.3) * r, _haz_alt + randf_range(-0.2, 0.2) * r, z_p), bas * dir * rapidez, randf_range(0.4, 0.75), tam, 0, 0.92, randf_range(0.4, 1.0), 1.0)
	# 3) al cortarse: el chorro se rompe en gotas a lo largo de todo su cuerpo
	var rompe: float = smoothstep(0.0, 0.25, co) * (1.0 - smoothstep(0.45, 0.75, co))
	_acc_corte += 70.0 * rompe * delta
	while _acc_corte >= 1.0:
		_acc_corte -= 1.0
		var s2: float = randf_range(co * 0.6, co * 0.6 + cr)
		var rad2: float = FuegoToyMallas.ancho_haz((s2 - co * 0.6) / maxf(cr, 0.05), FuegoToy.HAZ_R_ORIGEN, r)
		var loc2: Vector3 = Vector3(randf_range(-0.8, 0.8) * rad2, _haz_alt + randf_range(-0.5, 0.8) * rad2, -s2 * largo)
		g.call("emitir", tr * loc2, bas * Vector3(randf_range(-0.7, 0.7), randf_range(-0.2, 0.9), -randf_range(0.3, 1.8)), randf_range(0.4, 0.8), randf_range(0.05, 0.11), 0, 0.9, randf(), 1.0)


# ------------------------------------------------------------------ PILAR / GÉISER ------------------------------------------------------------------

## PILAR DE AGUA = GÉISER (fase 3, 3/11/2026). Semiejes: x y z = radios de la base, y = ALTO de la columna (m). Origen en el suelo, centrado.
##   · CORTINA + NÚCLEO (agua_pilar.gdshader, un tubo cada uno): la columna que brota; T_LiquidVertical_Wave fluye hacia arriba, tres tonos, borde claro por fresnel, labio irregular arriba.
##   · CORONA (agua_lamina.gdshader, 1 MultiMesh): 7-13 lenguas altas de distinta altura alrededor de la base + 5 bajas sueltas, T_wavesKI96 en láminas Y-billboard (como el muro y el pilar de fuego).
##   · ESPUMA: FRANJAS tumbadas en el borde de la base (agua_franja.gdshader, 1 MultiMesh; fase 4: ya no son bolas de algodón) y unas pocas bocanadas (agua_espuma.gdshader) en la cresta.
##   · GOTAS (reserva AguaGotas): suben desde la cresta y CAEN con gravedad alrededor; salpican en la base al brotar y se sueltan del cuerpo al desplomarse.
##   · CHARCO (agua_onda.gdshader): anillos de ondas que salen de la base al nacer; al morir se ensancha y se desvanece.
## `crece` (animación «nacer», 0 → pico 1,15 → 1) la sube desde el suelo con un pico de altura que se asienta; `corte` («morir», 0 → 1) la DESPLOMA con la gravedad y deja el charco, que se desvanece.
func _pilar(c: Node3D) -> void:
	var rx: float = semieje_x
	var rz: float = semieje_z
	var alto: float = semieje_y
	var rad: float = maxf(rx, rz)
	var malla: ArrayMesh = AguaMallas.tubo(28, 18)
	var rep: float = float(maxi(2, int(round(FuegoToyMallas.perimetro_elipse(rx, rz) / 1.5))))     # entero: sin costura alrededor
	var p: Dictionary = {"rx": rx, "rz": rz, "alto": alto, "rep_x": rep, "crece": crece, "corte": corte, "suave_prof": 0.15, "opacidad": 0.62, "semilla": 0.0}
	var caja: AABB = AABB(Vector3(-rad * 4.0, -0.3, -rad * 4.0), Vector3(rad * 8.0, alto * 1.5 + 0.6, rad * 8.0))
	var cortina: MeshInstance3D = _mi_agua(c, "Cortina", malla, AguaMallas.material(AguaMallas.SH_PILAR, p, 0))
	cortina.custom_aabb = caja
	var pn: Dictionary = p.duplicate()
	pn["grosor"] = 0.55
	pn["nucleo"] = 1.0
	pn["ritmo"] = 0.85
	pn["semilla"] = 0.37
	pn["opacidad"] = 0.6
	var nuc: MeshInstance3D = _mi_agua(c, "Nucleo", malla, AguaMallas.material(AguaMallas.SH_PILAR, pn, 1))
	nuc.custom_aabb = caja
	# charco / anillos de ondas en el suelo
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	_pil_charco = MeshInstance3D.new()
	_pil_charco.name = "Charco"
	_pil_charco.mesh = q
	_pil_charco.material_override = AguaMallas.material(AguaMallas.SH_ONDA, {"anillos": 2.0, "charco": 0.5, "u": 0.0, "vida": 1.0, "semilla": randf(), "se_va": 0.78, "fade_canto": 0.3, "suave_prof": 0.0}, 0)
	_pil_charco.position = Vector3(0, 0.012, 0)
	var lado: float = 2.0 * (rad * 2.4 + 0.45) / 0.74
	_pil_charco.scale = Vector3(lado, 1.0, lado)
	_pil_charco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(_pil_charco)
	# corona de lenguas
	_pil_lam = AguaMallas.lenguas_mm("Corona", AguaMallas.lenguas_corona(rx, rz, alto), {"subida": 0.0, "curva": 0.0, "caida": 0.0, "suave_prof": 0.15, "opacidad": 0.82})
	c.add_child(_pil_lam)
	# espuma de la base y de la cresta
	_pil_esp = AguaMallas.espuma_mm("Espuma", N_ESPUMA_CRESTA)
	c.add_child(_pil_esp)
	_pil_fra = AguaMallas.franjas_mm("Franjas", N_ESPUMA_BASE)
	c.add_child(_pil_fra)
	_pil_esp_datos.clear()


## Altura (m) de la cresta de la cortina con los valores actuales de `crece` y `corte`.
func pilar_cresta() -> float:
	var cai: float = clampf(corte / 0.7, 0.0, 1.0)
	return semieje_y * clampf(crece, 0.0, 1.3) * (1.0 - cai * cai)


func _avanzar_pilar(delta: float) -> void:
	if figura != Figura.PILAR or _pil_lam == null or not is_instance_valid(_pil_lam) or not _listo:
		return
	var cr: float = clampf(crece, 0.0, 1.3)
	var co: float = corte
	var grow: float = clampf(cr, 0.0, 1.0)
	var rad: float = maxf(semieje_x, semieje_z)
	var rm: float = (semieje_x + semieje_z) * 0.5
	var tt: float = Time.get_ticks_msec() * 0.001 * velocidad
	var top: float = pilar_cresta()
	# corona de lenguas: suben con el brote, se curvan un poco al asentarse y se doblan hacia fuera y caen al desplomarse
	var ml: ShaderMaterial = _pil_lam.material_override as ShaderMaterial
	ml.set_shader_parameter("subida", grow)
	ml.set_shader_parameter("curva", 0.62 * smoothstep(0.6, 1.2, cr) + 0.38 * smoothstep(0.0, 0.4, co))
	ml.set_shader_parameter("caida", smoothstep(0.05, 0.7, co))
	# charco: anillos que salen de la base al nacer; al morir se ensancha y se va
	_pil_charco_u = 0.45 * smoothstep(0.0, 0.9, grow) if co <= 0.0 else 0.45 + 0.55 * co
	(_pil_charco.material_override as ShaderMaterial).set_shader_parameter("u", _pil_charco_u)
	# espuma
	var mm: MultiMesh = _pil_esp.multimesh
	var mf: MultiMesh = _pil_fra.multimesh
	_pil_esp_datos.resize(N_ESPUMA_BASE + N_ESPUMA_CRESTA)
	# base: FRANJAS de espuma tumbadas y tangentes al borde del charco (dos coronas, una dentro de otra), como la espuma de franjas del agua del mundo; no bolas
	for i in N_ESPUMA_BASE:
		var f: float = float(i) / float(N_ESPUMA_BASE)
		var ang: float = TAU * f + 0.25 * sin(float(i) * 2.9) + tt * 0.08
		var rr: float = rad * (1.12 if i % 2 == 0 else 1.5) + 0.16 + 0.9 * co * (0.6 + 0.4 * f)
		var pos: Vector3 = Vector3(cos(ang) * rr, 0.03 + 0.02 * float(i % 2) + 0.06 * co * (1.0 - co), sin(ang) * rr)
		var largo: float = clampf(TAU * rr / float(N_ESPUMA_BASE) * (1.9 if i % 2 == 0 else 1.5), 0.3, 2.0) * (0.5 + 0.5 * grow) * (1.0 + 0.5 * co)
		var ancho: float = (0.16 + 0.07 * fposmod(f * 7.3, 1.0)) * (0.7 + rm * 0.8) * (0.4 + 0.6 * grow)
		var al: float = 0.9 * smoothstep(0.0, 0.25, cr) * (1.0 - smoothstep(0.35, 0.95, co))
		AguaMallas.franja_poner(mf, i, pos, largo, ancho, al, 0.5 + 0.5 * fposmod(f * 3.7, 1.0), -ang - PI * 0.5, f * 9.0)
		_pil_esp_datos[i] = {"pos": pos, "tam": largo, "alfa": al}
	for k in N_ESPUMA_CRESTA:
		var f2: float = float(k) / float(N_ESPUMA_CRESTA)
		var ang2: float = TAU * f2 + tt * 1.1
		var rr2: float = rm * (0.55 + 0.45 * sin(tt * 2.0 + float(k) * 1.7)) + 0.05
		var pos2: Vector3 = Vector3(cos(ang2) * rr2, top + 0.05 + 0.05 * sin(tt * 3.0 + float(k)), sin(ang2) * rr2)
		var tam2: float = (0.3 + 0.12 * sin(float(k) * 3.1)) * (0.5 + rm * 1.2) * (1.0 + 0.5 * co)
		var al2: float = 0.65 * smoothstep(0.35, 0.9, cr) * (1.0 - smoothstep(0.05, 0.45, co))
		AguaMallas.espuma_poner(mm, k, pos2, tam2 * 0.8, al2 * 0.75, 1.0, f2 * 4.0)
		_pil_esp_datos[N_ESPUMA_BASE + k] = {"pos": pos2, "tam": tam2, "alfa": al2}


## Gotas del pilar (reserva top_level: viven en el mundo y caen con gravedad): suben desde la cresta, salpican en la base al brotar y se sueltan del cuerpo al desplomarse.
func _emitir_pilar(delta: float) -> void:
	var g: Node3D = _gotas
	g.set("suelo_y", global_position.y - 0.02)
	var cr: float = clampf(crece, 0.0, 1.3)
	var co: float = corte
	var dcr: float = clampf((cr - _pil_cr_ant) / maxf(delta, 0.0001), 0.0, 4.0)
	_pil_cr_ant = cr
	var alto: float = semieje_y
	var rx: float = semieje_x
	var rz: float = semieje_z
	var rm: float = (rx + rz) * 0.5
	var k: float = clampf(sqrt(alto / 4.0), 0.6, 1.7)
	var tr: Transform3D = global_transform
	var bas: Basis = tr.basis
	var top: float = pilar_cresta()
	var vive: float = clampf(chispas, 0.0, 1.0)
	# 1) desde la cresta: suben y caen alrededor (al brotar, muchas; luego alguna)
	_pil_acc += (34.0 * dcr + 14.0 * smoothstep(0.7, 1.0, cr) * (1.0 - smoothstep(0.0, 0.3, co))) * vive * delta
	while _pil_acc >= 1.0:
		_pil_acc -= 1.0
		var ang: float = randf() * TAU
		var d: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var r0: float = randf_range(0.0, 0.9)
		var loc: Vector3 = Vector3(d.x * rx * r0, top + randf_range(0.0, 0.25), d.z * rz * r0)
		var vel: Vector3 = bas * (d * randf_range(0.3, 1.9) * (0.7 + rm) + Vector3(0, randf_range(2.6, 5.8) * k, 0))
		g.call("emitir", tr * loc, vel, randf_range(1.0, 1.5), randf_range(0.07, 0.14), 0, 0.9, randf_range(0.3, 1.0), 1.0)
	# 2) salpicadura en la base al brotar: gotas que salen hacia fuera y suben un poco
	_pil_acc2 += 16.0 * dcr * vive * delta
	while _pil_acc2 >= 1.0:
		_pil_acc2 -= 1.0
		var ang2: float = randf() * TAU
		var d2: Vector3 = Vector3(cos(ang2), 0.0, sin(ang2))
		var loc2: Vector3 = Vector3(d2.x * rx * 1.15, 0.12, d2.z * rz * 1.15)
		g.call("emitir", tr * loc2, bas * (d2 * randf_range(1.6, 3.4) + Vector3(0, randf_range(1.8, 3.6), 0)), randf_range(0.5, 0.8), randf_range(0.05, 0.1), 0, 0.9, randf_range(0.4, 1.0), 1.0)
	# 3) al desplomarse: se desprenden del cuerpo hacia fuera
	var cae: float = smoothstep(0.0, 0.2, co) * (1.0 - smoothstep(0.55, 0.9, co))
	_pil_acc3 += 52.0 * cae * vive * delta
	while _pil_acc3 >= 1.0:
		_pil_acc3 -= 1.0
		var ang3: float = randf() * TAU
		var d3: Vector3 = Vector3(cos(ang3), 0.0, sin(ang3))
		var loc3: Vector3 = Vector3(d3.x * rx * 1.3, randf_range(0.1, 1.0) * maxf(top, 0.3), d3.z * rz * 1.3)
		g.call("emitir", tr * loc3, bas * (d3 * randf_range(1.0, 3.0) * (0.7 + rm) + Vector3(0, randf_range(-0.5, 1.6), 0)), randf_range(0.45, 0.8), randf_range(0.06, 0.12), 0, 0.9, randf_range(0.4, 1.0), 1.0)


# ------------------------------------------------------------------ OLA (fase 4) ------------------------------------------------------------------

## OLA = AguaToy.Figura.MURO (3/11/2026). Semiejes: x = ANCHO (la ola se tiende a lo largo de x), y = ALTO de la cresta, z = fondo; avanza hacia -Z (el frente del nodo).
##   · CORTINAS (agua_ola.gdshader, 3 mallas a distinta profundidad): el PERFIL de la ola dibujado por el vertex shader: espalda que sube, cresta, labio que se RIZA hacia delante y cara cóncava. Translúcidas, con
##     bandas hondo / somero (agua del mundo), borde claro por fresnel y espuma en el labio y en los pies.
##   · CUERPO (agua_ola_lamina.gdshader modo 0, 1 MultiMesh) y CRESTA (modo 1, T_Wave66): láminas Y-billboard en varias filas de profundidad, como el muro de fuego: de canto la ola no es una raya.
##   · FRANJAS de espuma tumbadas en el pie, GOTAS que saltan de la cresta y caen, y un CHARCO ancho que deja al caer y se desvanece.
## `crece` (nacer) la sube desde el suelo; vivir: la cresta ondula y avanza un poco; `corte` (morir) la hace CAER hacia delante y deja el charco.
func _ola(c: Node3D) -> void:
	var a: float = semieje_x
	var b: float = semieje_z
	var alto: float = semieje_y
	var nx: int = clampi(int(round(a * 14.0)), 32, 110)
	var malla: ArrayMesh = AguaMallas.plano_ola(nx, 36)
	var caja: AABB = AABB(Vector3(-a - 1.0, -0.3, -alto * 2.0 - b * 3.0), Vector3(2.0 * a + 2.0, alto * 1.7 + 0.6, alto * 3.0 + b * 6.0))
	_ola_hojas = []
	for k in 3:
		var capa: float = float(k - 1)
		var p: Dictionary = {"a": a, "b": b, "alto": alto, "crece": crece, "corte": corte, "capa": capa, "semilla": 0.19 * float(k), "suave_prof": 0.15, "opacidad": 0.5 if k == 1 else 0.4, "ritmo": 0.45 + 0.08 * float(k)}
		var mi: MeshInstance3D = _mi_agua(c, "Ola%d" % k, malla, AguaMallas.material(AguaMallas.SH_OLA, p, k))
		mi.custom_aabb = caja
		_ola_hojas.append(mi)
	var pl: Dictionary = {"a": a, "alto": alto, "crece": crece, "corte": corte, "suave_prof": 0.15}
	_ola_cuerpo = AguaMallas.ola_mm("Masa", AguaMallas.ola_laminas(a, b, alto, true), 0, pl.merged({"opacidad": 0.46}))
	c.add_child(_ola_cuerpo)
	_ola_cresta = AguaMallas.ola_mm("Cresta", AguaMallas.ola_laminas(a, b, alto, false), 1, pl.merged({"opacidad": 0.5}))
	c.add_child(_ola_cresta)
	# espuma en franjas, pegada al pie delantero
	_ola_fra = AguaMallas.franjas_mm("Franjas", N_FRANJAS_OLA)
	c.add_child(_ola_fra)
	# charco ancho que deja al caer
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	_ola_charco = MeshInstance3D.new()
	_ola_charco.name = "Charco"
	_ola_charco.mesh = q
	_ola_charco.material_override = AguaMallas.material(AguaMallas.SH_ONDA, {"anillos": 2.0, "charco": 0.8, "u": 0.0, "vida": 1.0, "semilla": randf(), "se_va": 0.9, "fade_canto": 0.3, "suave_prof": 0.0}, 0)
	_ola_charco.position = Vector3(0, 0.012, -alto * 0.3)
	_ola_charco.scale = Vector3(2.0 * (a + 0.7) / 0.9, 1.0, 2.0 * (b + alto * 0.85) / 0.9)
	_ola_charco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(_ola_charco)
	_ola_franjas_datos.clear()


## Altura (m) de la cresta en el centro (x = 0) con los valores actuales de `crece` y `corte` (sin el ruido de la ondulación).
func ola_altura() -> float:
	var rise: float = smoothstep(0.0, 1.0, crece)
	var f2: float = pow(clampf(corte, 0.0, 1.0), 1.4)
	return semieje_y * rise * (1.0 - 0.88 * f2)


## Cuánto se ha inclinado hacia delante (m) la cabeza de la ola respecto al pie (positivo = hacia -Z): crece al caer.
func ola_inclinacion() -> float:
	var f2: float = pow(clampf(corte, 0.0, 1.0), 1.4)
	return f2 * 1.25 * semieje_y * smoothstep(0.0, 1.0, crece) * (1.0 - 0.88 * f2)


func ola_avance() -> float:
	return _ola_avance


func ola_charco_u() -> float:
	return _ola_charco_u


func _avanzar_ola(delta: float) -> void:
	if figura != Figura.MURO or _ola_cuerpo == null or not is_instance_valid(_ola_cuerpo) or not _listo:
		return
	var cr: float = crece
	var co: float = corte
	if cr >= 0.999 and co <= 0.0:
		_ola_t += delta * velocidad
	_ola_avance = 0.5 * (1.0 - exp(-_ola_t * 0.6)) + 0.55 * co
	for h in _ola_hojas:
		((h as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("avance", _ola_avance)
	(_ola_cuerpo.material_override as ShaderMaterial).set_shader_parameter("avance", _ola_avance)
	(_ola_cresta.material_override as ShaderMaterial).set_shader_parameter("avance", _ola_avance)
	# charco: se abre cuando la ola cae y se desvanece al final
	_ola_charco_u = smoothstep(0.1, 1.0, co)
	(_ola_charco.material_override as ShaderMaterial).set_shader_parameter("u", _ola_charco_u)
	# franjas de espuma del pie: delante de la cortina, tendidas a lo largo de x
	var a: float = semieje_x
	var b: float = semieje_z
	var alto: float = semieje_y
	var tt: float = Time.get_ticks_msec() * 0.001 * velocidad
	var mf: MultiMesh = _ola_fra.multimesh
	_ola_franjas_datos.resize(N_FRANJAS_OLA)
	for i in N_FRANJAS_OLA:
		var f: float = float(i) / float(N_FRANJAS_OLA - 1)
		var x: float = lerpf(-a * 0.9, a * 0.9, f) + 0.25 * sin(float(i) * 2.7)
		var env: float = 1.0 - 0.6 * pow(absf(x) / a, 4.0)
		var z: float = -_ola_avance - (b * 0.9 + 0.25 * alto * smoothstep(0.0, 1.0, cr)) - 0.12 - 0.55 * co * (0.5 + 0.5 * fposmod(f * 5.3, 1.0))
		var pos: Vector3 = Vector3(x, 0.03 + 0.015 * float(i % 2), z + 0.06 * sin(tt * 1.3 + float(i)))
		var largo: float = clampf(2.0 * a / float(N_FRANJAS_OLA) * (1.7 if i % 2 == 0 else 1.3), 0.4, 2.2) * (0.4 + 0.6 * smoothstep(0.0, 1.0, cr)) * (1.0 + 0.4 * co)
		var ancho: float = (0.2 + 0.1 * fposmod(f * 7.1, 1.0)) * (0.7 + 0.5 * alto / 1.5) * (0.4 + 0.6 * smoothstep(0.0, 1.0, cr)) * (1.0 + 0.8 * co)
		var al: float = 0.9 * smoothstep(0.05, 0.5, cr) * (1.0 - smoothstep(0.6, 1.0, co)) * (0.5 + 0.5 * env)
		AguaMallas.franja_poner(mf, i, pos, largo, ancho, al, 0.5 + 0.5 * fposmod(f * 3.7, 1.0), 0.1 * sin(float(i) * 1.9), f * 9.0)
		_ola_franjas_datos[i] = {"pos": pos, "largo": largo, "alfa": al}


## Gotas de la ola (reserva top_level: se quedan en el mundo y caen): saltan de la cresta mientras vive, y al caer salpican hacia delante.
func _emitir_ola(delta: float) -> void:
	var g: Node3D = _gotas
	g.set("suelo_y", global_position.y - 0.02)
	var cr: float = crece
	var co: float = corte
	var a: float = semieje_x
	var b: float = semieje_z
	var alto: float = semieje_y
	var vive: float = clampf(chispas, 0.0, 1.0)
	var tr: Transform3D = global_transform
	var bas: Basis = tr.basis
	var altura: float = ola_altura()
	if altura < 0.05:
		return
	# 1) de la cresta: saltan hacia delante y arriba y caen
	_ola_acc += (9.0 * smoothstep(0.3, 1.0, cr) * (1.0 - smoothstep(0.0, 0.3, co)) + 14.0 * smoothstep(0.0, 0.25, co) * (1.0 - smoothstep(0.5, 0.9, co))) * (a / 3.45) * vive * delta
	while _ola_acc >= 1.0:
		_ola_acc -= 1.0
		var x: float = randf_range(-0.92, 0.92) * a
		var env: float = 1.0 - 0.6 * pow(absf(x) / a, 4.0)
		var loc: Vector3 = Vector3(x, altura * env * randf_range(0.8, 1.0), -_ola_avance - 0.2 * alto * randf())
		var vel: Vector3 = bas * Vector3(randf_range(-0.5, 0.5), randf_range(0.8, 2.4), -randf_range(0.8, 2.6) * (0.7 + 0.7 * co))
		g.call("emitir", tr * loc, vel, randf_range(0.5, 0.9), randf_range(0.05, 0.11), 0, 0.9, randf_range(0.5, 1.0), 1.0)
	# 2) al caer: salpicadura a lo largo del pie delantero
	var cae: float = smoothstep(0.1, 0.35, co) * (1.0 - smoothstep(0.55, 0.85, co))
	_ola_acc2 += 34.0 * cae * (a / 3.45) * vive * delta
	while _ola_acc2 >= 1.0:
		_ola_acc2 -= 1.0
		var x2: float = randf_range(-0.92, 0.92) * a
		var loc2: Vector3 = Vector3(x2, 0.1, -_ola_avance - alto * randf_range(0.2, 0.6))
		var vel2: Vector3 = bas * Vector3(randf_range(-0.6, 0.6), randf_range(1.2, 3.0), -randf_range(0.5, 2.0))
		g.call("emitir", tr * loc2, vel2, randf_range(0.45, 0.8), randf_range(0.06, 0.12), 0, 0.9, randf_range(0.4, 1.0), 1.0)

## FIGURAS AÚN SIN HACER (fases 4-5): un elipsoide de agua con el tamaño de los semiejes, para ver el tamaño y la posición. NO es el aspecto final.
func _marcador_provisional(c: Node3D) -> void:
	_marcador = true
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 40
	sm.rings = 20
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Marcador"
	mi.mesh = sm
	mi.material_override = _mat_esfera(1.0, randf(), 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match figura:
		Figura.MURO, Figura.PILAR:
			mi.position = Vector3(0, semieje_y * 0.5, 0)
			mi.scale = Vector3(semieje_x, semieje_y * 0.5, semieje_z)
		Figura.HAZ:
			mi.position = Vector3(0, semieje_y, -semieje_x)
			mi.scale = Vector3(semieje_z, semieje_z, semieje_x)
		_:
			mi.scale = Vector3(semieje_x, semieje_y, semieje_z)
	c.add_child(mi)


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
	if figura != Figura.BOLA:
		nacer = 0.4
		morir_s = 0.6
	var es_pilar: bool = figura == Figura.PILAR
	var es_ola: bool = figura == Figura.MURO
	var es_haz: bool = figura == Figura.HAZ or es_pilar or es_ola         # el haz y el pilar no se encogen: animan `crece` (nacer) y `corte` (morir)
	if figura == Figura.HAZ:
		morir_s = 1.0
	elif es_pilar:
		nacer = T_PILAR_NACER
		morir_s = T_PILAR_MORIR
	elif es_ola:
		nacer = T_OLA_NACER
		morir_s = T_OLA_MORIR
	var lib: AnimationLibrary = AnimationLibrary.new()
	for nom in ["nacer", "vivir", "morir"]:
		var an: Animation = Animation.new()
		var pista: int = an.add_track(Animation.TYPE_VALUE)
		# el haz no se encoge: «nacer» lo hace SALIR del origen (crece 0 → 1) y «morir» lo SUELTA (corte 0 → 1); el resto anima `aparicion`
		an.track_set_path(pista, NodePath(".:crece" if (es_haz and nom == "nacer") else (".:corte" if es_haz else ".:aparicion")))
		match nom:
			"nacer":
				an.length = nacer
				an.track_insert_key(pista, 0.0, 0.0)
				if es_pilar:
					an.track_insert_key(pista, nacer * 0.16, 0.55)       # brota rápido...
					an.track_insert_key(pista, nacer * 0.45, 1.16)       # ...con un pico de altura que se asienta
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


# ------------------------------------------------------------------ vuelo, cintas y gotas ------------------------------------------------------------------

func _set_proyectil(v: bool) -> void:
	proyectil = v
	_aplicar_vuelo(v)


## En vuelo las cintas van sobre el eje del vuelo y sale la estela; quieta se inclinan y no hay estela.
func _aplicar_vuelo(v: bool) -> void:
	if not _listo or _cintas == null:
		return
	if _estela != null:
		_estela.visible = v
		if not v:
			_cola_f = 0.0
	if v and _cola_f <= 0.0:
		_cola_f = 0.0001
	_param_mats("espuma_frente", 1.0 if v else 0.0)         # espuma blanca suave en el borde delantero solo en vuelo


## Reserva de gotas: la BOLA (44 huecos) y el HAZ (72) tienen; el marcador provisional no. Si la figura cambia, se rehace.
func _montar_gotas() -> void:
	var cap: int = 0
	match figura:
		Figura.BOLA:
			cap = GOTAS_RESERVA
		Figura.HAZ:
			cap = GOTAS_RESERVA_HAZ
		Figura.PILAR:
			cap = GOTAS_RESERVA_PILAR
		Figura.MURO:
			cap = GOTAS_RESERVA_OLA
	if _gotas != null and is_instance_valid(_gotas) and int(_gotas.call("capacidad")) == cap:
		return
	if _gotas != null and is_instance_valid(_gotas):
		remove_child(_gotas)
		_gotas.free()
	_gotas = null
	if cap == 0:
		return
	_gotas = AguaGotas.new()
	_gotas.name = "Gotas"
	add_child(_gotas)
	_gotas.call("montar", cap)


func _process(delta: float) -> void:
	super._process(delta)
	_avanzar_carga(delta)
	_avanzar_cintas(delta)
	_avanzar_haz(delta)
	_avanzar_pilar(delta)
	_avanzar_ola(delta)
	_emitir_gotas(delta)


func _avanzar_cintas(delta: float) -> void:
	if _cintas == null or not is_instance_valid(_cintas):
		return
	var vuela: bool = proyectil and _est != EstadoCarga.APAGANDO
	var meta: float = 0.0 if vuela else INCLINACION_QUIETA
	_inclin = lerpf(_inclin, meta, minf(delta * 9.0, 1.0))
	if _inclinable != null:
		_inclinable.rotation_degrees = Vector3(_inclin, 0.0, 0.0)
	_cintas.rotate_object_local(Vector3(0, 0, 1), (GIRO_VUELO if vuela else GIRO_QUIETA) * velocidad * delta)
	if _estela != null and _estela.visible:
		_cola_f = minf(_cola_f + delta / T_COLA, 1.0)
		var f: float = smoothstep(0.0, 1.0, _cola_f)
		_estela.scale = Vector3(lerpf(0.4, 1.0, f), lerpf(0.4, 1.0, f), maxf(f, 0.02))
		# se arrastra con un balanceo lento e irregular (dos senos que no encajan): nunca es una hélice regular
		var tt: float = Time.get_ticks_msec() * 0.001 * velocidad
		_estela.rotation = Vector3(0.12 * sin(tt * 3.1) * sin(tt * 1.3), 0.14 * sin(tt * 2.3 + 1.0), 0.9 * sin(tt * 1.7) + 0.6 * sin(tt * 0.9 + 2.0))


## Gotitas que se desprenden de la bola y caen. En vuelo salen por detrás (heredan algo de la velocidad); quieta, alguna gota se desprende por abajo.
func _emitir_gotas(delta: float) -> void:
	if _gotas == null or not is_instance_valid(_gotas) or not _listo or delta <= 0.0 or not is_inside_tree():
		return
	if figura == Figura.HAZ:
		_emitir_haz(delta)
		return
	if figura == Figura.PILAR:
		_emitir_pilar(delta)
		return
	if figura == Figura.MURO:
		_emitir_ola(delta)
		return
	if figura != Figura.BOLA:
		return
	var pos: Vector3 = global_position
	if _tiene_ult:
		_vel_mundo = (pos - _ult_pos) / delta
	_ult_pos = pos
	_tiene_ult = true
	if _cuerpo == null or not _cuerpo.visible or _est == EstadoCarga.CANCELANDO:
		return
	var vuela: bool = proyectil and _est != EstadoCarga.APAGANDO
	var tasa: float = (34.0 if vuela else 3.5) * clampf(chispas, 0.0, 1.0) * clampf(_c_escala, 0.0, 1.0)
	if _est == EstadoCarga.APAGANDO:
		tasa = 0.0
	_acc_gotas += tasa * delta
	var r: float = maxf(semieje_x, semieje_z) * clampf(_c_escala, 0.1, 1.5)
	var k: float = r / 0.4
	_gotas.set("suelo_y", pos.y - altura_suelo)
	while _acc_gotas >= 1.0:
		_acc_gotas -= 1.0
		var bur: bool = randf() < 0.12
		var tam: float = (randf_range(0.035, 0.07) if not bur else randf_range(0.035, 0.05)) * sqrt(maxf(k, 0.3))
		if vuela:
			var loc: Vector3 = Vector3(randf_range(-0.55, 0.55) * r, randf_range(-0.55, 0.45) * r, r * randf_range(0.6, 2.6))
			var lat: Vector3 = global_transform.basis * Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 1.0), randf_range(-0.2, 0.6)) * 0.7
			_gotas.call("emitir", global_transform * loc, _vel_mundo * 0.3 + lat, randf_range(0.5, 0.85), tam, 1 if bur else 0, 0.9, randf(), 1.0)
		else:
			var abajo: Vector3 = pos + Vector3(randf_range(-0.4, 0.4) * r, -0.85 * r, randf_range(-0.4, 0.4) * r)
			_gotas.call("emitir", abajo, Vector3(0, -0.3, 0), randf_range(0.5, 0.8), tam * 0.9, 0, 0.9, randf(), 1.0)
