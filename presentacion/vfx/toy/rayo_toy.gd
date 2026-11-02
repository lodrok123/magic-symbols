class_name RayoToy
extends EfectoToy

## RAYO «TOY» (3/11/2026, rama claude/b1-hielo-rayo, B1 de docs/DIRECCION_2026-11-02.md §2.B). Clase HERMANA de FuegoToy, AguaToy y HieloToy: misma API, mismas cinco figuras (BOLA, MURO, PILAR, BARRERA, HAZ), mismos ejes
## (semieje_x / y / z en m), misma escala (`describir` / `desde_hechizo` son los de FuegoToy: un hechizo cambia de elemento sin cambiar de tamaño) y los mismos mandos (los diez de EfectoToy; valen `brillo` y
## `velocidad` (del parpadeo), `chispas` (cuántas chispas), `luz` y `ancho`; `altura`, `halo`, `tono` y `blandura` no hacen nada). FuegoToy, AguaToy y HieloToy no se han tocado: la máquina de carga e impacto
## está copiada, no compartida.
## Es LUZ: el único de los elementos nuevos que BRILLA. Todos los shaders son blend_add y unshaded (rayo_trazo.gdshader: tramos rectos que miran a la cámara, hilo blanco, cuerpo amarillo y halo azul; rayo_destello.gdshader:
## estrella de T_flare8 teñida igual). NO hay GPUParticles3D: los trazos y los destellos son MultiMesh movidos por la CPU. UNA luz (OmniLight3D «Luz», blanco azulada, parpadea con el rayo): el destello que ilumina
## el suelo es lo que da la identidad al rayo, y el fuego usa también una; VfxToyJuego la apaga en las copias sobrantes (≤ 1 luz por hechizo).
## CARÁCTER (docs/PLAN_VFX_ELEMENTOS.md): el rayo DURA MUY POCO.
##   · NACER (`crece` 0 → 1, 0,06 s; la bola, `aparicion`): el trazo se extiende de golpe: el pilar CAE del cielo, la valla salta de poste en poste, el aro se cierra, el haz sale de la mano.
##   · VIVIR: PARPADEA. La línea quebrada se REDIBUJA cada 0,05 s (3 fotogramas a 60 Hz) con otros desplazamientos y otras ramas, cada redibujo con su intensidad (de 0,55 a 1; un 10 % de las veces cae a 0,2) y su luz.
##   · MORIR (`corte` 0 → 1, 0,18 s; la bola, 0,15 s): se redibuja cada fotograma mientras se apaga (crepita) y se acaba.
## PALETA: la del rayo del juego, centralizada en rayo_paleta.gd (con su procedencia).
##
## FIGURAS: BOLA = núcleo blanco con halo y seis descargas cortas que saltan de él; en vuelo, un zigzag quebrado detrás. MURO = una VALLA DE DESCARGAS entre postes (cada poste es un trazo vertical con su
## destello, y entre postes saltan dos arcos). PILAR = una COLUMNA DE DESCARGA (de dos a cuatro rayos entrelazados que caen del cielo, con destello arriba y abajo). BARRERA = un ARO CHISPEANTE (tres aros quebrados a
## distintas alturas sobre el elipsoide y cuatro arcos que los unen). HAZ = un ARCO entre la mano y el objetivo, con una segunda línea más fina y tres ramas.
##
## Ciclo de vida de un proyectil de rayo, sobre UN SOLO nodo (igual que FuegoToy, AguaToy y HieloToy):
##   empezar_carga(duracion, tam_final)  durante `duracion` s aparecen chispas alrededor de la mano que CONVERGEN formando la bola, que va creciendo en la mano; tres arcos cortos saltan a su alrededor y un halo late
##                                       en el suelo bajo los pies (`pies`). Si se sostiene más, «respira». NO hace falta `lanzar()`.
##   progreso_carga() -> float           0 → 1 (se queda en 1 al sostener, y tras soltar)
##   soltar(dir)                         ESA MISMA bola (mismo nodo) pasa a proyectil apuntando a `dir`; si estaba a medio crecer se asienta al tamaño final en T_SOLTAR s sin salto.
##   cancelar_carga()                    se encoge y se apaga en T_CANCELAR s y se libera
##   impactar_en(pos, normal, escala)    ImpactoRayoToy GOLPE orientado por la normal (descargas, destello, chispas); la bola desaparece en seguida
##   rebotar(pos, normal) -> Vector3     golpe pequeño; la bola SIGUE; devuelve la dirección reflejada (y la bola mira hacia ella)
##   terminar_sin_choque()               el hechizo se agota en el aire: la bola se encoge y revienta en chispas y arcos cortos (variante FIN)
##   finalizar(motivo, pos, normal)      atajo para HechizoVivo._terminar(causa)
## `impactar()` (contrato EfectoVfx3D) también funciona. `definir`, `describir`, `desde_hechizo` y `preparar` son los de FuegoToy (figura y tamaño salen del Hechizo).

enum Figura { BOLA, MURO, PILAR, BARRERA, HAZ }
enum EstadoCarga { NINGUNA, CARGANDO, SOLTANDO, APAGANDO, CANCELANDO }

const RayoTrazos = preload("res://presentacion/vfx/toy/rayo_trazos.gd")
const RayoPaleta = preload("res://presentacion/vfx/toy/rayo_paleta.gd")
const CargaRayo = preload("res://presentacion/vfx/toy/carga_rayo_toy.gd")

## Tamaños de referencia (iguales a los de FuegoToy: un hechizo cambia de elemento sin cambiar de tamaño).
const REF_BOLA: Vector3 = Vector3(0.4, 0.4, 0.4)
const REF_MURO: Vector3 = Vector3(3.45, 1.5, 0.3)
const REF_PILAR: Vector3 = Vector3(0.5, 4.0, 0.5)
const REF_BARRERA: Vector3 = Vector3(1.5, 1.5, 1.5)
const REF_HAZ: Vector3 = Vector3(1.5, 0.5, 0.15)

const T_SOLTAR: float = 0.14            ## s que tarda en asentarse al tamaño final al soltar si estaba respirando o sin acabar de crecer
const T_APAGAR: float = 0.35            ## s que tarda en encogerse el fin sin choque
const T_CANCELAR: float = 0.2
const RESPIRO_HZ: float = 1.4
const T_COLA: float = 0.1               ## s que tarda en salir el zigzag de detrás al empezar a volar
const T_NACER: float = 0.06             ## el rayo NACE en menos de 0,1 s
const T_MORIR: float = 0.18             ## y MUERE en menos de 0,2 s
const T_NACER_BOLA: float = 0.06
const T_MORIR_BOLA: float = 0.15
const T_REDIBUJO: float = 0.05          ## s entre redibujos de la línea quebrada (3 fotogramas a 60 Hz)
const N_TRAZOS_BOLA: int = 48           ## tramos que caben en el MultiMesh de cada figura
const N_TRAZOS_HAZ: int = 64
const N_TRAZOS_PILAR: int = 96
const N_TRAZOS_MURO: int = 140
const N_TRAZOS_BARRERA: int = 120
const N_BRILLOS: int = 40
const LUZ_ENERGIA: float = 1.6          ## energía de la luz con el rayo a pleno (× `luz` × el parpadeo)

@export_group("Figura y ejes (m)")
@export var figura: Figura = Figura.BOLA: set = _set_figura
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_x: float = 0.4: set = _set_x
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_y: float = 0.4: set = _set_y
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_z: float = 0.4: set = _set_z
@export var viaja: bool = false: set = _set_viaja
## `crece` (0 → 1: el trazo se extiende; lo anima «nacer», 0,06 s) y `corte` (0 → 1: se apaga crepitando; lo anima «morir», 0,18 s).
@export_range(0.0, 1.0, 0.01) var crece: float = 1.0: set = _set_crece
@export_range(0.0, 1.0, 0.01) var corte: float = 0.0: set = _set_corte
@export_group("Carga del hechizo")
@export_range(0.03, 0.6, 0.01) var carga_tam_inicial: float = 0.12
@export_range(0.3, 3.0, 0.05) var carga_curva: float = 0.8
@export_range(0, 36, 1) var carga_chispas: int = 28: set = _set_carga_chispas      ## chispas que convergen en la mano (la cuarta parte al principio)
@export_range(0.0, 3.0, 0.05) var carga_destello: float = 1.0                      ## sin uso en el rayo (la carga ya es toda destellos); existe para que los mandos del lab valgan para todos
@export_range(0.0, 0.2, 0.005) var carga_respiro: float = 0.05
@export_range(0.0, 3.0, 0.05) var carga_brillo: float = 1.0: set = _set_carga_brillo       ## opacidad de las chispas, los arcos y el halo del suelo
@export_range(0.5, 2.0, 0.05) var carga_radio: float = 1.0: set = _set_carga_radio         ## × el radio de la nube de chispas
@export var carga_bola_visible: bool = true: set = _set_carga_bola_visible              ## true: la bola se va formando en la mano (por defecto); false: solo chispas y arcos, y la bola aparece al soltar
@export_group("Impacto")
## true: al impactar, en vez del golpe de un proyectil, caen cinco descargas sobre el área (ImpactoRayoToy.Variante.AREA). `desde_hechizo` lo pone en las zonas.
@export var area_al_impactar: bool = false
@export_group("Mundo")
## Dónde están los pies respecto al nodo (local, -Z = delante): ahí late el halo del casteo.
@export var pies: Vector3 = Vector3(0, -0.7, 0.5)
## Altura (m) del nodo sobre el suelo: las chispas que caen por debajo de ella se apagan.
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
var _c_visual: Node3D = null            ## CargaRayo: chispas que convergen, arcos y halo del suelo
var _pop: bool = false
var _esq: Node3D = null                 ## (sin uso: el rayo no tiene reserva de esquirlas; existe para que la máquina copiada de HieloToy sea la misma)
var _bola_rota: bool = false
var _ult_pos: Vector3 = Vector3.ZERO
var _tiene_ult: bool = false
var _vel_mundo: Vector3 = Vector3.ZERO
var _cola_f: float = 0.0
var _trazos: MultiMeshInstance3D = null     ## los tramos de la línea quebrada
var _brillos: MultiMeshInstance3D = null    ## destellos: núcleo de la bola, puntas, postes y chispas
var _lista: Array = []                      ## los tramos del último redibujo [{a, b, ancho, alfa, halo, parpadeo, fase}] (pruebas)
var _brillos_n: int = 0                     ## destellos puestos en el último redibujo (pruebas)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _t_red: float = 0.0
var _n_red: int = 0                         ## cuántos redibujos lleva (pruebas)
var _fl: float = 1.0                        ## intensidad del último redibujo (0,2 a 1)
var _cr_ult: float = -1.0
var _co_ult: float = -1.0
var _haz_largo: float = 3.0
var _haz_alt: float = 0.5
var _haz_r: float = 0.36
var _pos_luz: Vector3 = Vector3.ZERO
var _semilla: int = 1


func _ready() -> void:
	_semilla = randi() % 100000
	_construir()
	super._ready()
	_construido = true
	_set_proyectil(viaja)
	_redibujar(true)


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
	_redibujar(true)


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


## Las chispas, los arcos y el halo de la carga se desvanecen en `dur` s y se liberan solas.
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
				get_tree().create_timer(0.3).timeout.connect(queue_free)


## Chispas, arcos y halo del casteo (CargaRayo). Cuelga de un nodo «Carga» que no escala con la bola.
func _montar_carga() -> void:
	var viejo: Node = get_node_or_null("Carga")
	if viejo != null:
		remove_child(viejo)
		viejo.free()
	_c_nodo = Node3D.new()
	_c_nodo.name = "Carga"
	add_child(_c_nodo)
	_c_visual = CargaRayo.new()
	_c_visual.name = "Convergencia"
	_c_nodo.add_child(_c_visual)
	_c_visual.call("montar", _c_r, carga_chispas, carga_brillo, carga_radio, pies)


func _radio_impacto(escala: float) -> float:
	return escala if escala > 0.0 else maxf(semieje_x, semieje_z)


func _crear_impacto(variante: ImpactoRayoToy.Variante, normal: Vector3, escala: float, pos: Vector3) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var imp: ImpactoRayoToy = ImpactoRayoToy.crear(variante, normal, _radio_impacto(escala))
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


func _quitar_vuelo() -> void:
	_quitar_visual_carga(0.05)


## Explosión de ÁREA de rayo (cinco descargas que caen sobre el área) (ImpactoRayoToy.Variante.AREA) en `pos` (sobre el suelo, normal arriba) con `radio` m de radio: una descarga en el centro y cuatro alrededor, con su destello y sus chispas. No toca a la bola.
func explotar_area(pos: Vector3, radio: float = -1.0) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var r: float = radio if radio > 0.0 else maxf(maxf(semieje_x, semieje_z), 0.3)
	var imp: ImpactoRayoToy = ImpactoRayoToy.crear(ImpactoRayoToy.Variante.AREA, Vector3.UP, r)
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


func impactar_en(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Node3D:
	var imp: Node3D
	if area_al_impactar:
		imp = explotar_area(pos, escala)
	else:
		imp = _crear_impacto(ImpactoRayoToy.Variante.GOLPE, normal, escala, pos)
	_est = EstadoCarga.NINGUNA
	_bola_rota = true                             # el impacto ya trae sus chispas: la bola no se rompe además
	_quitar_vuelo()
	_soltar_chispas()
	if _ap != null and _ap.has_animation("morir"):
		_ap.speed_scale = 4.0                     # la bola se apaga en 0,12 s mientras el golpe se abre
	morir()
	return imp


func rebotar(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Vector3:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var d: Vector3 = -global_transform.basis.z if is_inside_tree() else Vector3.FORWARD
	var nd: Vector3 = (d - 2.0 * d.dot(n) * n).normalized()
	_crear_impacto(ImpactoRayoToy.Variante.REBOTE, n, escala, pos)
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
	_crear_impacto(ImpactoRayoToy.Variante.FIN, Vector3.UP, -1.0, global_position)
	_bola_rota = true
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
func preparar(volumen: Dictionary, dir: Vector3, _elemento: String = "rayo") -> void:
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
	tam_referencia = Vector3(semieje_x, semieje_y, semieje_z) * 2.0
	_avance_cabeza = 0.0
	_haz_largo = semieje_x * 2.0
	_haz_r = semieje_z * FuegoToy.HAZ_ABRE
	_haz_alt = maxf(semieje_y, 0.4)
	var cap: int = N_TRAZOS_BOLA
	match figura:
		Figura.HAZ:
			cap = N_TRAZOS_HAZ
		Figura.PILAR:
			cap = N_TRAZOS_PILAR
		Figura.MURO:
			cap = N_TRAZOS_MURO
		Figura.BARRERA:
			cap = N_TRAZOS_BARRERA
	_trazos = RayoTrazos.crear_trazos("Trazos", cap)
	cuerpo.add_child(_trazos)
	_brillos = RayoTrazos.crear_destellos("Brillos", N_BRILLOS)
	cuerpo.add_child(_brillos)
	_lista = []
	_cr_ult = -1.0
	_co_ult = -1.0
	# la luz cuelga del raíz (no escala con el cuerpo)
	var luz_nodo: OmniLight3D = get_node_or_null("Luz") as OmniLight3D
	if luz_nodo == null:
		luz_nodo = OmniLight3D.new()
		luz_nodo.name = "Luz"
		luz_nodo.light_color = RayoPaleta.LUZ
		luz_nodo.light_energy = LUZ_ENERGIA
		luz_nodo.shadow_enabled = false
		add_child(luz_nodo)
	luz_nodo.omni_range = clampf(3.0 + 0.7 * extension(), 3.0, 9.0)
	_anim_si_hace_falta()


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
	var nacer: float = T_NACER if es_vol else T_NACER_BOLA
	var morir_s: float = T_MORIR if es_vol else T_MORIR_BOLA
	var lib: AnimationLibrary = AnimationLibrary.new()
	for nom in ["nacer", "vivir", "morir"]:
		var an: Animation = Animation.new()
		var pista: int = an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(pista, NodePath(".:crece" if (es_vol and nom == "nacer") else (".:corte" if es_vol else ".:aparicion")))
		match nom:
			"nacer":
				an.length = nacer
				an.track_insert_key(pista, 0.0, 0.0)
				an.track_insert_key(pista, nacer, 1.0)
			"vivir":
				an.length = 1.0
				an.loop_mode = Animation.LOOP_LINEAR
				an.track_insert_key(pista, 0.0, 0.0 if es_vol else 1.0)
			"morir":
				an.length = morir_s
				an.track_insert_key(pista, 0.0, 0.0 if es_vol else 1.0)
				an.track_insert_key(pista, morir_s, 1.0 if es_vol else 0.0)
		an.track_set_interpolation_type(pista, Animation.INTERPOLATION_LINEAR)
		lib.add_animation(nom, an)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	dura_morir = morir_s


# ------------------------------------------------------------------ vuelo ------------------------------------------------------------------

func _set_proyectil(v: bool) -> void:
	proyectil = v
	_aplicar_vuelo(v)


## En vuelo sale el zigzag de detrás; quieto, no.
func _aplicar_vuelo(v: bool) -> void:
	if not v:
		_cola_f = 0.0
	elif _cola_f <= 0.0:
		_cola_f = 0.0001


func _soltar_chispas() -> void:
	pass                                        # el rayo no tiene esquirlas que sobrevivan al nodo (sus chispas son del impacto)


# ------------------------------------------------------------------ redibujo ------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_avanzar_carga(delta)
	if proyectil and _est != EstadoCarga.APAGANDO:
		_cola_f = minf(_cola_f + delta / T_COLA, 1.0)
	if delta > 0.0 and is_inside_tree():
		if _tiene_ult:
			_vel_mundo = (global_position - _ult_pos) / delta
		_ult_pos = global_position
		_tiene_ult = true
	_t_red += delta
	var cambia: bool = absf(crece - _cr_ult) > 0.02 or absf(corte - _co_ult) > 0.02
	if _t_red >= T_REDIBUJO or cambia:
		_redibujar(false)
	_actualizar_luz()


func _actualizar_luz() -> void:
	if _luz == null or not is_instance_valid(_luz):
		return
	var vive: float = clampf(crece, 0.0, 1.0) * (1.0 - clampf(corte, 0.0, 1.0)) * (aparicion if figura == Figura.BOLA else 1.0)
	_luz.position = _pos_luz
	_luz.light_energy = LUZ_ENERGIA * luz * _fl * vive
	_luz.visible = _luz.light_energy > 0.01


## Nº de redibujos que lleva la línea quebrada (pruebas).
func redibujos() -> int:
	return _n_red


## Los tramos del último redibujo (pruebas): [{a, b, ancho, alfa, halo, parpadeo, fase}] en el espacio local del cuerpo.
func trazos_actuales() -> Array:
	return _lista


func intensidad_actual() -> float:
	return _fl


## Línea quebrada nueva (otros desplazamientos, otras ramas, otra intensidad) y su vuelco a los MultiMesh. `forzar` = aunque no toque (al nacer y al reconstruir).
func _redibujar(forzar: bool) -> void:
	if _trazos == null or not is_instance_valid(_trazos) or _brillos == null:
		return
	_t_red = 0.0
	_n_red += 1
	_cr_ult = crece
	_co_ult = corte
	_rng.seed = _semilla * 7919 + _n_red * 104729 + int(figura) * 13
	_fl = 0.55 + 0.45 * _rng.randf()
	if _rng.randf() < 0.10:
		_fl = 0.2                                                           # de vez en cuando casi se apaga: parpadea
	var lista: Array = []
	var bril: Array = []                                                    # [{pos, tam, alfa, estrella}]
	var cr: float = clampf(crece, 0.0, 1.0)
	var co: float = clampf(corte, 0.0, 1.0)
	var env: float = _fl * pow(1.0 - co, 1.5)
	match figura:
		Figura.BOLA:
			_gen_bola(lista, bril, env)
		Figura.PILAR:
			_gen_pilar(lista, bril, env, cr)
		Figura.MURO:
			_gen_muro(lista, bril, env, cr)
		Figura.BARRERA:
			_gen_barrera(lista, bril, env, cr)
		Figura.HAZ:
			_gen_haz(lista, bril, env, cr)
	for s in lista:
		s["ancho"] = float(s["ancho"]) * ancho
	_brillos_n = bril.size()
	RayoTrazos.volcar(_trazos.multimesh, lista)
	_lista = lista
	var mb: MultiMesh = _brillos.multimesh
	for i in N_BRILLOS:
		if i < bril.size():
			var b: Dictionary = bril[i]
			RayoTrazos.poner_destello(mb, i, b["pos"], float(b["tam"]), float(b["alfa"]) * brillo_chispas(), float(b["estrella"]), _rng.randf() * TAU, float(i) * 0.17)
		else:
			RayoTrazos.ocultar(mb, i)


## Cuánto pesan las chispas y los destellos (el mando `chispas`).
func brillo_chispas() -> float:
	return clampf(chispas, 0.0, 1.0) * 0.5 + 0.5


## Grosor de un tronco de rayo de una escala `k` (m): crece despacio con el tamaño de la figura.
func _grosor(k: float) -> float:
	return 0.12 + 0.11 * clampf(k, 0.0, 3.0)


func _gen_bola(lista: Array, bril: Array, env: float) -> void:
	var r: float = maxf(semieje_x, semieje_z)
	var g: float = _grosor(r / 0.4 * 0.5)
	_pos_luz = Vector3.ZERO
	bril.append({"pos": Vector3.ZERO, "tam": r * 3.0, "alfa": 0.5 * env, "estrella": 0.0})            # halo
	bril.append({"pos": Vector3.ZERO, "tam": r * 1.5, "alfa": 0.95 * env, "estrella": 1.0})           # núcleo
	for k in 6:
		var d: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
		var pts: PackedVector3Array = RayoTrazos.camino(d * r * 0.2, d * r * _rng.randf_range(1.1, 1.8), 3, 0.3 * r, _rng)
		RayoTrazos.trazar(lista, pts, g * 0.8, 0.95 * env, 1.0, 1.0, 0.5, float(k))
	if proyectil:
		# zigzag detrás (+Z): dos líneas que se alejan de la bola y se afinan
		var cola: float = r * 5.5 * smoothstep(0.0, 1.0, _cola_f)
		for k2 in 2:
			var lado: Vector3 = Vector3(float(k2) * 0.35 - 0.17, 0.0, 0.0) * r
			var pts2: PackedVector3Array = RayoTrazos.camino(Vector3(0, 0, r * 0.4) + lado, Vector3(0, 0, r * 0.4 + cola) + lado, 9, 0.38 * r, _rng)
			RayoTrazos.trazar(lista, pts2, g * (0.8 - 0.25 * float(k2)), 0.8 * env, 1.0, 0.8, 0.7, 3.0 + float(k2))
			if k2 == 0:
				RayoTrazos.ramas(lista, pts2, 2, r * 1.2, g * 0.5, 0.7 * env, 1.0, _rng, 2)
		for k3 in 3:
			bril.append({"pos": Vector3(_rng.randf_range(-0.4, 0.4) * r, _rng.randf_range(-0.4, 0.4) * r, r * (1.0 + _rng.randf() * 4.0 * _cola_f)), "tam": r * 0.5, "alfa": 0.8 * env, "estrella": 0.9})


## PILAR = COLUMNA DE DESCARGA: de 2 a 4 rayos entrelazados que CAEN de la cima (`crece` = hasta dónde han llegado), cada uno con dos ramas; destello arriba y en el suelo.
func _gen_pilar(lista: Array, bril: Array, env: float, cr: float) -> void:
	var rx: float = semieje_x
	var rz: float = semieje_z
	var alto: float = semieje_y
	var rm: float = (rx + rz) * 0.5
	_pos_luz = Vector3(0, alto * 0.5, 0)
	var nb: int = clampi(2 + int(rm * 3.0), 2, 4)
	var n: int = clampi(int(round(alto / 0.35)), 8, 16)
	var g: float = _grosor(rm / 0.5)
	for k in nb:
		var a: float = TAU * float(k) / float(nb) + _rng.randf_range(-0.4, 0.4)
		var a2: float = a + _rng.randf_range(0.8, 2.0)
		var cima: Vector3 = Vector3(cos(a) * rx * 0.3, alto, sin(a) * rz * 0.3)
		var pie: Vector3 = Vector3(cos(a2) * rx * 0.85, 0.0, sin(a2) * rz * 0.85)
		var pts: PackedVector3Array = RayoTrazos.camino(cima, pie, n, 0.10 + 0.5 * rm, _rng)
		RayoTrazos.trazar(lista, pts, g, 0.95 * env, cr, 1.0, 0.5, float(k) * 2.0)
		RayoTrazos.ramas(lista, pts, 2, 0.5 + rm, g * 0.55, 0.8 * env, cr, _rng, 3)
	bril.append({"pos": Vector3(0, alto, 0), "tam": 0.7 + rm * 1.4, "alfa": 0.9 * env * smoothstep(0.0, 0.3, cr), "estrella": 0.9})
	bril.append({"pos": Vector3(0, 0.15, 0), "tam": 1.4 + rm * 3.2, "alfa": 0.55 * env * smoothstep(0.7, 1.0, cr), "estrella": 0.0})
	for k2 in 3:
		var a3: float = _rng.randf() * TAU
		bril.append({"pos": Vector3(cos(a3) * rx * 1.3, 0.12, sin(a3) * rz * 1.3), "tam": 0.3 + 0.2 * rm, "alfa": 0.8 * env * smoothstep(0.7, 1.0, cr), "estrella": 0.9})


## MURO = VALLA DE DESCARGAS entre postes. Semiejes: x = ANCHO, y = ALTO de los postes, z = fondo (los postes se alternan a un lado y otro). `crece` hace saltar los arcos de poste en poste de izquierda a derecha.
func _gen_muro(lista: Array, bril: Array, env: float, cr: float) -> void:
	var a: float = semieje_x
	var b: float = semieje_z
	var alto: float = semieje_y
	_pos_luz = Vector3(0, alto * 0.6, 0)
	var np: int = clampi(int(round(2.0 * a / 1.15)) + 1, 2, 8)
	var g: float = _grosor(alto / 1.5 * 0.5)
	var xs: Array = []
	for i in np:
		xs.append(lerpf(-a, a, float(i) / float(np - 1)))
	for i in np:
		var x: float = xs[i]
		var z: float = (0.5 if i % 2 == 0 else -0.5) * b
		var base: Vector3 = Vector3(x, 0.0, z)
		var cima: Vector3 = Vector3(x, alto * _rng.randf_range(0.9, 1.0), z)
		RayoTrazos.trazar(lista, RayoTrazos.camino(base, cima, 3, 0.03, _rng), g * 0.9, 0.95 * env, minf(cr * 3.0, 1.0), 1.0, 0.4, float(i))
		bril.append({"pos": cima, "tam": 0.45 + 0.12 * alto, "alfa": 0.85 * env * smoothstep(0.0, 0.25, cr), "estrella": 0.9})
	for i in np - 1:
		var u0: float = float(i) / float(np - 1)
		var tramo: float = clampf((cr - u0 * 0.7) / 0.3, 0.0, 1.0)             # los arcos saltan en cadena de izquierda a derecha
		if tramo <= 0.0:
			continue
		var z0: float = (0.5 if i % 2 == 0 else -0.5) * b
		var z1: float = (0.5 if (i + 1) % 2 == 0 else -0.5) * b
		for h in 2:
			var hh: float = alto * (0.3 + 0.48 * float(h)) * _rng.randf_range(0.85, 1.1)
			var p0: Vector3 = Vector3(xs[i], hh, z0)
			var p1: Vector3 = Vector3(xs[i + 1], hh + _rng.randf_range(-0.12, 0.12) * alto, z1)
			var pts: PackedVector3Array = RayoTrazos.camino(p0, p1, 6, 0.12 + 0.06 * alto, _rng)
			RayoTrazos.trazar(lista, pts, g * 0.8, 0.9 * env, tramo, 1.0, 0.6, float(i * 2 + h))
		if _rng.randf() < 0.35:
			var pts2: PackedVector3Array = RayoTrazos.camino(Vector3(xs[i], alto * 0.95, z0), Vector3(xs[i + 1], alto * 0.5, z1), 5, 0.12 + 0.05 * alto, _rng)
			RayoTrazos.trazar(lista, pts2, g * 0.6, 0.8 * env, tramo, 0.7, 0.7, float(i) * 5.0)


## BARRERA = ARO CHISPEANTE sobre el elipsoide (centro a 0,4·y como la del fuego): tres aros quebrados a 0,12·y, 0,65·y y 1,2·y (el radio sigue la curva del elipsoide) y cuatro arcos que los unen. `crece` cierra los aros.
func _gen_barrera(lista: Array, bril: Array, env: float, cr: float) -> void:
	var x: float = semieje_x
	var y: float = semieje_y
	var z: float = semieje_z
	_pos_luz = Vector3(0, 0.4 * y, 0)
	var g: float = _grosor((x + z) * 0.5 / 1.5 * 0.5)
	var alturas: Array = [0.12 * y, 0.65 * y, 1.2 * y]
	var anillos: Array = []
	for h in alturas:
		var s: float = sqrt(maxf(1.0 - pow((float(h) - 0.4 * y) / y, 2.0), 0.0))
		var nr: int = clampi(int(round(FuegoToyMallas.perimetro_elipse(x * s, z * s) / 0.45)), 12, 26)
		var pts: PackedVector3Array = PackedVector3Array()
		for i in nr + 1:
			var ang: float = TAU * float(i % nr) / float(nr)
			var d: float = 0.0 if (i == 0 or i == nr) else 1.0
			pts.append(Vector3(cos(ang) * x * s * 0.93, float(h), sin(ang) * z * s * 0.93) + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * (0.04 + 0.03 * y) * d)
		pts[nr] = pts[0]
		RayoTrazos.trazar(lista, pts, g * 0.8, 0.9 * env, cr, 1.0, 0.6, float(h))
		anillos.append({"s": s, "n": nr})
	for k in 4:
		var ang2: float = _rng.randf() * TAU
		var puntos: Array = []
		for h2 in alturas:
			var s2: float = sqrt(maxf(1.0 - pow((float(h2) - 0.4 * y) / y, 2.0), 0.0))
			puntos.append(Vector3(cos(ang2) * x * s2 * 0.93, float(h2), sin(ang2) * z * s2 * 0.93))
		for q in 2:
			RayoTrazos.trazar(lista, RayoTrazos.camino(puntos[q], puntos[q + 1], 4, 0.06 * y + 0.03, _rng), g * 0.6, 0.85 * env, cr, 0.8, 0.7, float(k))
		if k < 3:
			bril.append({"pos": puntos[0] + Vector3(0, 0.05, 0), "tam": 0.35 + 0.1 * y, "alfa": 0.8 * env, "estrella": 0.9})
	bril.append({"pos": Vector3(0, 0.1, 0), "tam": (x + z) * 1.2, "alfa": 0.3 * env, "estrella": 0.0})


## HAZ = ARCO entre la mano (el origen) y el objetivo (hacia -Z, a la altura máx(y, 0,4)): un tronco quebrado, una segunda línea más fina que lo acompaña y tres ramas; `crece` lo extiende de golpe hasta la punta.
func _gen_haz(lista: Array, bril: Array, env: float, cr: float) -> void:
	var largo: float = _haz_largo
	var alt: float = _haz_alt
	_pos_luz = Vector3(0, alt, -largo * 0.5)
	var n: int = clampi(int(round(largo / 0.28)), 8, 20)
	var g: float = _grosor(_haz_r / 0.45 * 0.6)
	var amp: float = 0.1 + 0.5 * _haz_r * 0.5
	var pts: PackedVector3Array = RayoTrazos.camino(Vector3(0, alt, 0), Vector3(0, alt, -largo), n, amp, _rng)
	RayoTrazos.trazar(lista, pts, g, 0.95 * env, cr, 1.0, 0.5, 0.0)
	var pts2: PackedVector3Array = RayoTrazos.camino(Vector3(0, alt, 0), Vector3(0, alt, -largo), n, amp * 1.3, _rng)
	RayoTrazos.trazar(lista, pts2, g * 0.55, 0.7 * env, cr, 0.7, 0.7, 4.0)
	RayoTrazos.ramas(lista, pts, 3, 0.35 + 0.4 * largo * 0.2, g * 0.5, 0.8 * env, cr, _rng, 3)
	bril.append({"pos": Vector3(0, alt, 0), "tam": 0.5 + _haz_r, "alfa": 0.8 * env, "estrella": 0.9})
	bril.append({"pos": pts[mini(int(floor(cr * float(n))), n)], "tam": 0.6 + _haz_r * 1.5, "alfa": 0.9 * env * smoothstep(0.5, 1.0, cr), "estrella": 0.9})
	for k in 3:
		bril.append({"pos": Vector3(_rng.randf_range(-0.2, 0.2), alt + _rng.randf_range(-0.2, 0.2), -largo * _rng.randf_range(0.2, 1.0) * cr), "tam": 0.25, "alfa": 0.7 * env, "estrella": 0.9})
