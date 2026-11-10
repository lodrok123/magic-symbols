class_name RayoToy
extends EfectoToy

## RAYO «TOY» (2/11/2026, rama claude/b1-hielo-rayo, B1 de docs/DIRECCION_2026-11-02.md §2.B). Clase HERMANA de FuegoToy, AguaToy y HieloToy: misma API, mismas cinco figuras (BOLA, MURO, PILAR, BARRERA, HAZ), mismos ejes
## (semieje_x / y / z en m), misma escala (`describir` / `desde_hechizo` son los de FuegoToy: un hechizo cambia de elemento sin cambiar de tamaño) y los mismos mandos (los diez de EfectoToy; valen `brillo` y
## `velocidad` (del parpadeo), `chispas` (cuántas chispas), `luz` y `ancho`; `altura`, `halo`, `tono` y `blandura` no hacen nada). FuegoToy, AguaToy y HieloToy no se han tocado: la máquina de carga e impacto
## está copiada, no compartida.
## Es LUZ: el único de los elementos nuevos que BRILLA. Los shaders son blend_add y unshaded (rayo_trazo.gdshader: tramos rectos que miran a la cámara, hilo blanco y halo azul), salvo el CUERPO AMARILLO del trazo, que va debajo en mezcla normal (rayo_trazo_cuerpo.gdshader: sumar amarillo a un suelo claro da blanco y el rayo del juego es amarillo-blanco con halo azul; rayo_destello.gdshader:
## estrella de T_flare8 teñida igual). NO hay GPUParticles3D: los trazos y los destellos son MultiMesh movidos por la CPU. UNA luz (OmniLight3D «Luz», blanco azulada, parpadea con el rayo): el destello que ilumina
## el suelo es lo que da la identidad al rayo, y el fuego usa también una; VfxToyJuego la apaga en las copias sobrantes (≤ 1 luz por hechizo).
## CARÁCTER (docs/PLAN_VFX_ELEMENTOS.md): el rayo DURA MUY POCO.
##   · NACER (`crece` 0 → 1, 0,06 s; la bola, `aparicion`): el trazo se extiende de golpe: el pilar CAE del cielo, la valla salta de poste en poste, el aro se cierra, el haz sale de la mano.
##   · VIVIR: PARPADEA. La línea quebrada se REDIBUJA cada 0,05 s (3 fotogramas a 60 Hz) con otros desplazamientos y otras ramas, cada redibujo con su intensidad (de 0,55 a 1; un 10 % de las veces cae a 0,2) y su luz.
##   · MORIR (`corte` 0 → 1, 0,18 s; la bola, 0,15 s): se redibuja cada fotograma mientras se apaga (crepita) y se acaba.
## PALETA: la del rayo del juego, centralizada en rayo_paleta.gd (con su procedencia).
##
## FIGURAS: BOLA = ESFERA DE ENERGÍA (ronda de la bola, 3/11/2026): cuerpo esférico blanco-amarillo con fresnel y halo azul, seis arcos que recorren su superficie y tres que saltan y vuelven; en vuelo, la cabeza con su destello,
## una cola quebrada corta pegada a ella y chispas que se quedan atrás y caen; al morir se contrae y revienta en arcos y chispas. MURO = una VALLA DE DESCARGAS entre postes (cada poste es un trazo vertical con su
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
const N_TRAZOS_BOLA: int = 90           ## tramos que caben en el MultiMesh de cada figura (la bola: meridianos, saltos, cola o reventón)
const N_FIJOS_BOLA: int = 24            ## BOLA: destellos 0..23 se redibujan cada 0,05 s; del 24 al 39, las chispas que caen detrás en vuelo (cada fotograma)
const N_CHISPAS_VUELO: int = 16
const PERIODO_CHISPA: float = 0.035     ## s entre chispa y chispa que deja la bola en vuelo
const COLA_BOLA: float = 3.4            ## largo de la estela recta y fina en vuelo, en radios (≤ 2 diámetros: referencia en vídeo, «Projectile»)
const NUCLEO_MIN: float = 0.6           ## el núcleo de la bola nunca baja de esta intensidad
const N_TRAZOS_HAZ: int = 90
const N_TRAZOS_PILAR: int = 120
const N_TRAZOS_MURO: int = 160
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
@export var area_al_impactar: bool = false: set = _set_area_al_impactar
@export_group("Mundo")
## Dónde están los pies respecto al nodo (local, -Z = delante): ahí late el halo del casteo.
@export var pies: Vector3 = Vector3(0, -0.7, 0.5)
## Altura (m) del nodo sobre el suelo: las chispas que caen por debajo de ella se apagan.
@export var altura_suelo: float = 0.7

var _sello: SelloRayo = null                  ## PILAR y zona (BOLA quieta que estalla en área): el sello circular del suelo (referencia en vídeo: «Ultimate» y «Area of effect»)
var _sello_cerrado: bool = false
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
var _esfera: MeshInstance3D = null          ## BOLA: el cuerpo esférico (rayo_bola.gdshader)
var _halo_bola: MultiMeshInstance3D = null  ## BOLA: el halo azul redondo, detrás de la esfera
var _nuc: float = 1.0                       ## BOLA: intensidad del núcleo en el último redibujo (0,6 a 1 mientras vive)
var _chispas_v: Array = []                  ## BOLA en vuelo: chispas que se quedan atrás [{p (mundo), v, edad, vida, tam}]
var _t_chispa: float = 0.0
var _trazos: MultiMeshInstance3D = null     ## los tramos de la línea quebrada
var _cinta: MeshInstance3D = null
var _cintas: Array = []
var _estela_mundo: Array[Vector3] = []
var _reloj_estela: float = 0.0
var _ruido_descarga: FastNoiseLite = null
var _brillos: MultiMeshInstance3D = null    ## destellos: núcleo de la bola, puntas, postes y chispas
var _lista: Array = []                      ## los tramos del último redibujo [{a, b, ancho, alfa, halo, parpadeo, fase}] (pruebas)
var _brillos_n: int = 0                     ## destellos puestos en el último redibujo (pruebas)
var _bril_lista: Array = []                 ## los destellos del último redibujo [{pos, tam, alfa, estrella}] (pruebas)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _t_red: float = 0.0
var _n_red: int = 0                         ## cuántos redibujos lleva (pruebas)
var _fl: float = 1.0                        ## intensidad del último redibujo (0,2 a 1)
var _cr_ult: float = -1.0
var _co_ult: float = -1.0
var _haz_largo: float = 3.0
var _haz_alt: float = 0.5
var _haz_r: float = 0.36
## HAZ: dónde choca (lo rellena VfxToyJuego; ver FuegoToy.choques). Lo dibuja HazChoque.rayo (apagable con FuegoToy.haz_ideas).
var choques: Array = []
var _golpe_haz: MultiMeshInstance3D = null
var _inicio_haz: float = -1.0
var _contacto_haz: float = -1.0
var _frame_contacto_haz: int = -1
var _nube_tormenta: Node3D = null
var _cupula_barrera: MeshInstance3D = null
var _material_tormenta: ShaderMaterial = null
var _inicio_tormenta: float = -1.0
var _ultimo_impacto_tormenta: int = -1
const CARGA_TORMENTA: float = 0.11
const PERIODO_TORMENTA: float = 0.21
const CAIDA_TORMENTA: float = 0.055
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
	if figura == Figura.HAZ and _construido:
		HazChoque.param(self, "crece", v)


func _set_corte(v: float) -> void:
	corte = v
	if figura == Figura.HAZ and _construido:
		HazChoque.param(self, "corte", v)


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
		_cuerpo.visible = carga_bola_visible and not RayoTrazos.prueba_reeboo
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
		_cuerpo.visible = v and not RayoTrazos.prueba_reeboo


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
			if _c_nodo != null and _c_nodo.top_level:
				_c_nodo.global_transform = global_transform
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
	if RayoTrazos.prueba_reeboo:
		# Al soltar el proyectil, las últimas chispas se apagan junto a la mano.
		_c_nodo.top_level = true
		_c_nodo.global_transform = global_transform
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
	imp.con_sello = _sello == null or not is_instance_valid(_sello)                  # el sello de la zona sigue vivo en la explosión (no se pinta otro encima)
	padre.add_child(imp)
	imp.global_position = pos
	if _sello != null and is_instance_valid(_sello) and not _sello_cerrado:
		_sello_cerrado = true
		_sello.reparent(padre, true)
		padre.get_tree().create_timer(0.55, false).timeout.connect(Callable(_sello, "cerrar"))
		_sello = null
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
	_haz_largo = HazChoque.largo_corte(choques, semieje_x * 2.0) if figura == Figura.HAZ else semieje_x * 2.0       # el haz se corta en el primer tope (muro)
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
	_esfera = null
	_halo_bola = null
	_cinta = null
	_chispas_v = []
	if figura == Figura.BOLA:
		_halo_bola = RayoTrazos.crear_destellos("Halo", 1, -1)          # detrás de la esfera
		cuerpo.add_child(_halo_bola)
		_esfera = RayoTrazos.crear_esfera("Esfera", 0)
		cuerpo.add_child(_esfera)
	_trazos = RayoTrazos.crear_trazos("Trazos", cap)
	cuerpo.add_child(_trazos)
	_brillos = RayoTrazos.crear_destellos("Brillos", N_BRILLOS)
	cuerpo.add_child(_brillos)
	_golpe_haz = null
	_nube_tormenta = null
	_cupula_barrera = null
	if figura == Figura.HAZ and RayoTrazos.prueba_descarga:
		_golpe_haz = RayoTrazos.crear_golpe_haz()
		cuerpo.add_child(_golpe_haz)
	if figura == Figura.PILAR and RayoTrazos.prueba_reeboo:
		_montar_nube_tormenta(cuerpo)
	if figura == Figura.BARRERA and RayoTrazos.prueba_reeboo:
		var malla := SphereMesh.new()
		malla.radius = 1.0
		malla.height = 2.0
		malla.radial_segments = 48
		malla.rings = 24
		_cupula_barrera = MeshInstance3D.new()
		_cupula_barrera.name = "CupulaElectrica"
		_cupula_barrera.mesh = malla
		_cupula_barrera.material_override = RayoTrazos.material(RayoTrazos.DIR + "rayo_cupula.gdshader")
		_cupula_barrera.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cuerpo.add_child(_cupula_barrera)
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
	_montar_sello()
	if figura == Figura.HAZ and FuegoToy.haz_ideas and not choques.is_empty():
		HazChoque.rayo(cuerpo, choques, _haz_largo, _haz_alt, _haz_r)
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
		# la bola nace con `aparicion` (0 → 1) y MUERE con `corte` (0 → 1: la esfera se contrae y revienta); las figuras de volumen, con `crece` y `corte`
		var prop: String = ".:crece" if (es_vol and nom == "nacer") else (".:corte" if (es_vol or nom == "morir") else ".:aparicion")
		an.track_set_path(pista, NodePath(prop))
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
				an.track_insert_key(pista, 0.0, 0.0)
				an.track_insert_key(pista, morir_s, 1.0)
		an.track_set_interpolation_type(pista, Animation.INTERPOLATION_LINEAR)
		lib.add_animation(nom, an)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	dura_morir = morir_s


# ------------------------------------------------------------------ sello del suelo ------------------------------------------------------------------

func _set_area_al_impactar(v: bool) -> void:
	area_al_impactar = v
	if _construido and is_inside_tree():
		_montar_sello()


## ¿Es una zona (bola quieta que estalla en área al acabar)?
func es_zona() -> bool:
	return figura == Figura.BOLA and area_al_impactar and not viaja and _est == EstadoCarga.NINGUNA


## Radio (m) del sello del suelo de esta figura, o 0 si no lleva: el pilar, de 0,9 a 3,2 m según su anchura; la zona, el radio de su área.
func radio_sello() -> float:
	if figura == Figura.PILAR:
		return clampf((semieje_x + semieje_z) * 0.5 * 2.6 + 0.55, 0.9, 3.2)
	if es_zona():
		return clampf(maxf(semieje_x, semieje_z) * 1.0 + 0.3, 0.9, 3.5)
	return 0.0


## Pone (o quita) el sello bajo la figura. El origen del PILAR es el suelo; el de la bola quieta está a media altura sobre él (VfxToyJuego la sube `semieje_y`).
func _montar_sello() -> void:
	if _sello != null and is_instance_valid(_sello):
		_sello.queue_free()
	_sello = null
	_sello_cerrado = false
	var r: float = radio_sello()
	if r <= 0.0 or not is_inside_tree():
		return
	_sello = SelloRayo.crear(r)
	_sello.name = "Sello"
	add_child(_sello)
	_sello.position = Vector3(0, 0.0 if figura == Figura.PILAR else -maxf(semieje_y, 0.3), 0)
	_sello.rotation = -rotation                                                     # el círculo no depende de hacia dónde mira el nodo


func sello() -> SelloRayo:
	return _sello


# ------------------------------------------------------------------ vuelo ------------------------------------------------------------------

func _set_proyectil(v: bool) -> void:
	proyectil = v
	_aplicar_vuelo(v)


## En vuelo sale el zigzag de detrás; quieto, no.
func _aplicar_vuelo(v: bool) -> void:
	if not v:
		_cola_f = 0.0
		_estela_mundo.clear()
		_reloj_estela = 0.0
	elif _cola_f <= 0.0:
		_cola_f = 0.0001


func _soltar_chispas() -> void:
	pass                                        # el rayo no tiene esquirlas que sobrevivan al nodo (sus chispas son del impacto)


# ------------------------------------------------------------------ redibujo ------------------------------------------------------------------

func lanzar(v: float = -1.0) -> void:
	_inicio_haz = -1.0
	_contacto_haz = -1.0
	_frame_contacto_haz = -1
	_inicio_tormenta = -1.0
	_ultimo_impacto_tormenta = -1
	if _golpe_haz != null or _nube_tormenta != null:
		crece = 0.0
		corte = 0.0
	super.lanzar(v)


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
	if RayoTrazos.prueba_cinta and proyectil:
		_muestrear_estela(delta)
	var cambia_tormenta: bool = _nube_tormenta != null and _actualizar_tormenta()
	_t_red += delta
	var cambia: bool = absf(crece - _cr_ult) > 0.02 or absf(corte - _co_ult) > 0.02
	var cambia_espejo: bool = figura == Figura.HAZ and RayoTrazos.prueba_descarga and _fase_espejo(_t) != _fase_espejo(_t - _t_red)
	if _t_red >= T_REDIBUJO or cambia or cambia_espejo or cambia_tormenta:
		_redibujar(false)
	if _golpe_haz != null:
		_actualizar_golpe_haz()
	_avanzar_chispas_vuelo(delta)
	_actualizar_luz()
	if _sello != null and is_instance_valid(_sello) and not _sello_cerrado and (corte > 0.05 or _est == EstadoCarga.APAGANDO):
		_sello_cerrado = true
		_sello.cerrar()


func _actualizar_golpe_haz() -> void:
	var fotograma: int = Engine.get_process_frames()
	if _inicio_haz < 0.0 and crece > 0.02:
		_inicio_haz = _t
	if _contacto_haz < 0.0 and crece >= 0.98:
		_contacto_haz = _t
		_frame_contacto_haz = fotograma
	var mm: MultiMesh = _golpe_haz.multimesh
	var origen := Vector3(0, _haz_alt, 0)
	var contacto := origen + Vector3.FORWARD * maxf(0.0, _haz_largo - 0.065)
	var apagado: float = 1.0 - clampf(corte, 0.0, 1.0)
	var salida: float = clampf((_t - _inicio_haz) / 0.11, 0.0, 1.0) if _inicio_haz >= 0.0 else 1.0
	var escala: float = clampf(_haz_r / 0.4, 0.65, 1.35)
	RayoTrazos.poner_destello(mm, 0, origen, lerpf(0.9, 1.6, salida) * escala, (1.0 - salida) * apagado, 0.0, 0.2)
	var fotograma_golpe: int = fotograma - _frame_contacto_haz
	if RayoTrazos.prueba_reeboo:
		if _frame_contacto_haz >= 0 and fotograma_golpe == 0:
			_impacto_reeboo(contacto, escala * 0.70, Basis.IDENTITY)
		return
	var llegada: float = clampf((_t - _contacto_haz) / 0.16, 0.0, 1.0) if _contacto_haz >= 0.0 else 1.0
	RayoTrazos.poner_destello(mm, 1, contacto, lerpf(1.65, 2.5, llegada) * escala, (1.0 - llegada) * apagado, 0.0, 0.65)
	if _frame_contacto_haz >= 0 and fotograma_golpe < 2:
		RayoTrazos.poner_destello(mm, 2, contacto, (1.9 + float(fotograma_golpe) * 0.38) * escala, apagado, 1.0, 0.3, float(fotograma_golpe))
	else:
		RayoTrazos.ocultar(mm, 2)


func _impacto_reeboo(punto: Vector3, escala: float, orientacion: Basis) -> void:
	var escena := preload("res://presentacion/vfx/toy/reeboo_hit_spark/hit_spark_rayo.tscn")
	var impacto := escena.instantiate() as Node3D
	impacto.transform = Transform3D(orientacion.scaled(Vector3.ONE * escala), punto)
	_cuerpo.add_child(impacto)
	(impacto.get_node("Sparks") as GPUParticles3D).finished.connect(impacto.queue_free)
	for emisor: GPUParticles3D in impacto.get_children():
		emisor.restart()


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
	_cintas.clear()
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
	_bril_lista = bril
	RayoTrazos.volcar(_trazos.multimesh, lista)
	if not _cintas.is_empty() and _cinta == null:
		_cinta = RayoTrazos.crear_cinta()
		_cuerpo.add_child(_cinta)
		var material_cinta := _cinta.material_override as ShaderMaterial
		material_cinta.set_shader_parameter("brillo", brillo)
		material_cinta.set_shader_parameter("velocidad", velocidad)
		material_cinta.set_shader_parameter("chisporroteo", chisporroteo)
		material_cinta.set_shader_parameter("fase_descarga", float(_semilla % 127) * 0.37)
		_mats.append(material_cinta)
	if _cinta != null:
		RayoTrazos.volcar_cintas(_cinta, _cintas, ancho)
	_lista = lista
	var mb: MultiMesh = _brillos.multimesh
	for i in (N_FIJOS_BOLA if figura == Figura.BOLA else N_BRILLOS):       # en la bola, del 24 en adelante son las chispas que caen detrás (cada fotograma)
		if i < bril.size():
			var b: Dictionary = bril[i]
			RayoTrazos.poner_destello(mb, i, b["pos"], float(b["tam"]), float(b["alfa"]) * brillo_chispas(), float(b["estrella"]), _rng.randf() * TAU, float(i) * 0.17)
		else:
			RayoTrazos.ocultar(mb, i)


## BOLA en vuelo: chispas que salen de la cabeza y SE QUEDAN ATRÁS (en coordenadas del mundo: la bola se aleja) y caen con la gravedad hasta apagarse. Se mueven cada fotograma (no a 20 Hz).
func _avanzar_chispas_vuelo(delta: float) -> void:
	if figura != Figura.BOLA or _brillos == null or not is_instance_valid(_brillos) or not is_inside_tree():
		return
	var mb: MultiMesh = _brillos.multimesh
	var vuela: bool = proyectil and _est != EstadoCarga.APAGANDO and corte < 0.05 and _cola_f > 0.3
	var r: float = maxf(semieje_x, maxf(semieje_y, semieje_z))
	if vuela:
		_t_chispa += delta
		if _t_chispa >= PERIODO_CHISPA:
			_t_chispa = 0.0
			if _chispas_v.size() < N_CHISPAS_VUELO:
				var d: Vector3 = _dir_azar_libre()
				_chispas_v.append({"p": global_transform * (d * r * 0.8 + Vector3(0, 0, r * 0.4)), "v": d * (0.6 + randf() * 0.8) + Vector3(0, 0.4, 0), "edad": 0.0, "vida": randf_range(0.25, 0.45), "tam": randf_range(0.5, 0.85) * r})
	var piso: float = global_position.y - altura_suelo
	var vivas: Array = []
	for c in _chispas_v:
		var s: Dictionary = c
		s["edad"] = float(s["edad"]) + delta
		var v: Vector3 = s["v"]
		v.y -= 9.8 * delta
		s["v"] = v
		s["p"] = (s["p"] as Vector3) + v * delta
		if float(s["edad"]) < float(s["vida"]) and (s["p"] as Vector3).y > piso:
			vivas.append(s)
	_chispas_v = vivas
	for i in N_CHISPAS_VUELO:
		var slot: int = N_FIJOS_BOLA + i
		if i < _chispas_v.size():
			var q: Dictionary = _chispas_v[i]
			var u: float = float(q["edad"]) / float(q["vida"])
			RayoTrazos.poner_destello(mb, slot, _brillos.to_local(q["p"]), float(q["tam"]) * (1.0 - 0.45 * u), 0.9 * (1.0 - smoothstep(0.5, 1.0, u)) * brillo_chispas() * clampf(_fl + 0.3, 0.0, 1.0), 0.9, float(i) * 1.7 + u * 6.0, float(i) * 0.31)
		else:
			RayoTrazos.ocultar(mb, slot)


func _dir_azar_libre() -> Vector3:
	var v: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	return v.normalized() if v.length() > 0.05 else Vector3.UP


## Chispas de vuelo vivas ahora (pruebas): [{p (mundo), v, edad, vida}].
func chispas_vuelo() -> Array:
	return _chispas_v


## Los destellos del último redibujo (pruebas): [{pos, tam, alfa, estrella}].
func brillos_actuales() -> Array:
	return _bril_lista


## Intensidad actual del núcleo de la bola (pruebas): 0,6 a 1 mientras vive.
func nucleo_actual() -> float:
	return _nuc


## Cuánto pesan las chispas y los destellos (el mando `chispas`).
func brillo_chispas() -> float:
	return clampf(chispas, 0.0, 1.0) * 0.5 + 0.5


## Grosor de un tronco de rayo de una escala `k` (m): crece despacio con el tamaño de la figura.
func _grosor(k: float) -> float:
	return 0.12 + 0.11 * clampf(k, 0.0, 3.0)


## Dirección al azar (nunca nula).
func _dir_azar() -> Vector3:
	var v: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
	return v.normalized() if v.length() > 0.05 else Vector3.UP


## Punto del elipsoide de la bola (semiejes) en la dirección `d` (unitaria), a `k` veces su superficie.
func _sup(d: Vector3, k: float) -> Vector3:
	return Vector3(d.x * semieje_x, d.y * semieje_y, d.z * semieje_z) * k


## Añade a `lista` los tramos de `pts` con el ancho y la opacidad yendo de una punta a la otra (para la cola: gruesa en la cabeza y fina al final).
func _afilado(lista: Array, pts: PackedVector3Array, ancho0: float, ancho1: float, alfa0: float, alfa1: float, halo: float, parpadeo: float, fase: float) -> void:
	var n: int = pts.size() - 1
	for i in n:
		var u: float = float(i) / float(maxi(n - 1, 1))
		lista.append({"a": pts[i], "b": pts[i + 1], "ancho": lerpf(ancho0, ancho1, u), "alfa": lerpf(alfa0, alfa1, u), "halo": halo, "parpadeo": parpadeo, "fase": fase + float(i) * 0.37})


## BOLA = ESFERA DE ENERGÍA QUE CREPITA. Un cuerpo esférico (rayo_bola.gdshader: núcleo blanco-amarillo con fresnel, mezcla normal) con un halo azul breve detrás; seis ARCOS que recorren su SUPERFICIE
## (meridianos quebrados) y tres que SALTAN hacia fuera y vuelven; todo se redibuja cada 0,05 s. El núcleo parpadea pero nunca baja de NUCLEO_MIN. En vuelo: la cabeza delante con su destello, una cola quebrada
## corta PEGADA a ella y las chispas que caen detrás (`_avanzar_chispas_vuelo`). Al morir (`corte` 0 → 1, 0,15 s): la esfera se contrae y revienta en ocho arcos cortos y chispas.
func _gen_bola(lista: Array, bril: Array, env: float) -> void:
	var rx: float = semieje_x
	var ry: float = semieje_y
	var rz: float = semieje_z
	var r: float = maxf(rx, maxf(ry, rz))
	var g: float = _grosor(r / 0.4 * 0.5)
	var co: float = clampf(corte, 0.0, 1.0)
	var ub: float = clampf((co - 0.25) / 0.75, 0.0, 1.0)                              # 0 → 1: el reventón
	var kr: float = lerpf(1.0, 0.3, smoothstep(0.0, 0.6, co))                         # la esfera se contrae
	var vuelo: float = smoothstep(0.0, 1.0, _cola_f) if proyectil else 0.0
	var vuelo_reeboo: bool = proyectil and RayoTrazos.prueba_reeboo
	_pos_luz = Vector3.ZERO
	_nuc = (NUCLEO_MIN + (1.0 - NUCLEO_MIN) * smoothstep(0.2, 1.0, _fl)) * (1.0 - smoothstep(0.5, 0.75, co))
	if _esfera != null and is_instance_valid(_esfera):
		_esfera.visible = _nuc > 0.01
		var escala_vuelo: float = lerpf(1.0, 0.74, vuelo) if vuelo_reeboo else 1.0
		_esfera.scale = Vector3(rx, ry, rz * (1.0 + 0.14 * vuelo)) * kr * escala_vuelo
		var ms: ShaderMaterial = _esfera.material_override as ShaderMaterial
		if ms != null:
			ms.set_shader_parameter("intensidad", _nuc)
			ms.set_shader_parameter("agitacion", 0.45 + 0.4 * vuelo)
			ms.set_shader_parameter("difusion", vuelo if vuelo_reeboo else 0.0)
	if _halo_bola != null and is_instance_valid(_halo_bola):
		var halo_radio: float = 3.0 + (2.2 if vuelo_reeboo else 0.6) * vuelo
		var halo_alfa: float = (0.26 + (0.48 if vuelo_reeboo else 0.1) * vuelo) * _nuc
		RayoTrazos.poner_destello(_halo_bola.multimesh, 0, Vector3.ZERO, r * halo_radio * lerpf(1.0, 0.5, co), halo_alfa * pow(1.0 - co, 1.5), 0.0, 0.0, 0.0)
	if proyectil:
		# destello de cabeza: solo en vuelo
		var tam_frente: float = 2.8 if RayoTrazos.prueba_toon else 5.0
		var estrella: float = 0.25 if vuelo_reeboo else 1.0
		bril.append({"pos": Vector3.ZERO, "tam": r * tam_frente * kr, "alfa": clampf(env + 0.25, 0.0, 1.0) * vuelo, "estrella": estrella})
	var vivo: float = 1.0 - ub
	if co < 0.9 and not vuelo_reeboo:
		# SEIS arcos que recorren la superficie (meridianos quebrados, de un lado a otro)
		for k in (3 if proyectil and RayoTrazos.prueba_descarga else 6):
			var d0: Vector3 = _dir_azar()
			var eje: Vector3 = d0.cross(_dir_azar())
			eje = eje.normalized() if eje.length() > 0.05 else Vector3.RIGHT
			var span: float = _rng.randf_range(0.9, 2.1)
			var pts: PackedVector3Array = PackedVector3Array()
			for i in 6:
				var u: float = float(i) / 5.0
				var p: Vector3 = _sup(d0.rotated(eje, span * u), 1.06 * kr + _rng.randf_range(-0.07, 0.09))
				pts.append(p + eje * _rng.randf_range(-1.0, 1.0) * 0.1 * r * kr)
			RayoTrazos.trazar(lista, pts, g * 0.42, 0.98 * env * vivo, 1.0, 1.0, 0.5, float(k))
		# CUATRO que saltan hacia fuera (más lejos que antes: «arcos que salen de la cabeza») y vuelven a la superficie
		if ub <= 0.0:
			for k2 in (2 if proyectil and RayoTrazos.prueba_descarga else 4):
				var da: Vector3 = _dir_azar()
				var eje2: Vector3 = da.cross(_dir_azar())
				eje2 = eje2.normalized() if eje2.length() > 0.05 else Vector3.RIGHT
				var db: Vector3 = da.rotated(eje2, _rng.randf_range(0.8, 1.5))
				var alto: float = r * _rng.randf_range(0.6, 1.15)
				var pts2: PackedVector3Array = PackedVector3Array()
				for i2 in 6:
					var u2: float = float(i2) / 5.0
					var dd: Vector3 = da.slerp(db, u2)
					var lev: float = pow(sin(PI * u2), 0.8)
					var perp: Vector3 = dd.cross(eje2).normalized()
					pts2.append(_sup(dd, 1.02) + dd * alto * lev + perp * _rng.randf_range(-1.0, 1.0) * 0.16 * r * lev)
				RayoTrazos.trazar(lista, pts2, g * 0.4, 0.95 * env, 1.0, 1.0, 0.6, 7.0 + float(k2))
				bril.append({"pos": pts2[2], "tam": r * 0.5, "alfa": 0.7 * env, "estrella": 0.9})
	if proyectil and co < 0.5:
		if vuelo_reeboo:
			_estela_proyectil_reeboo(r, vuelo, env)
		else:
			_estela_bola(lista, r, g, vuelo, env)
	if es_zona() and co < 0.5:
		# ZONA (referencia en vídeo, «Area of effect»): descargas que CAEN del cielo dentro del sello, de vez en cuando (a 20 Hz: una de cada dos redibujos)
		var rs: float = radio_sello()
		var suelo_y: float = -maxf(semieje_y, 0.3)
		var n_caen: int = 1 + int(_rng.randf() < 0.35)
		for kc in n_caen:
			if _rng.randf() < 0.55:
				var ac: float = _rng.randf() * TAU
				var rc: float = sqrt(_rng.randf()) * rs * 0.8
				var pie: Vector3 = Vector3(cos(ac) * rc, suelo_y + 0.03, sin(ac) * rc)
				var cima: Vector3 = pie + Vector3(_rng.randf_range(-0.2, 0.2), 2.6 + 0.4 * rs, _rng.randf_range(-0.2, 0.2))
				var ptc: PackedVector3Array = RayoTrazos.camino(cima, pie, 9, 0.14 + 0.05 * rs, _rng)
				RayoTrazos.trazar(lista, ptc, g * 0.7, 0.95 * env, 1.0, 1.0, 0.5, 21.0 + float(kc))
				RayoTrazos.ramas(lista, ptc, 2, 0.4 + 0.15 * rs, g * 0.4, 0.75 * env, 1.0, _rng, 3)
				bril.append({"pos": pie + Vector3(0, 0.1, 0), "tam": 0.35 + 0.15 * rs, "alfa": 0.9 * env, "estrella": 0.9})
	if ub > 0.0:
		# REVENTÓN: ocho arcos cortos que salen de la esfera que se contrae, y chispas que se alejan
		for k3 in 8:
			var d3: Vector3 = _dir_azar()
			var p0: Vector3 = _sup(d3, 0.8 * kr)
			var largo3: float = r * (0.5 + 1.7 * ub) * _rng.randf_range(0.7, 1.1)
			var pts3: PackedVector3Array = RayoTrazos.camino(p0, p0 + d3 * largo3, 3, 0.2 * r, _rng)
			RayoTrazos.trazar(lista, pts3, g * 0.5, 0.95 * _fl * vivo, clampf(ub * 4.0, 0.0, 1.0), 1.0, 0.5, 11.0 + float(k3))
			bril.append({"pos": d3 * r * (0.5 + 2.4 * ub), "tam": r * 0.38 * (1.0 - 0.5 * ub), "alfa": 0.95 * vivo, "estrella": 0.9})


## PILAR = COLUMNA DE DESCARGA (referencia en vídeo, «Ultimate»: un rayo GRUESO que cae del cielo sobre un sello circular y se RAMIFICA al tocar el suelo, con chispas): de 2 a 4 rayos entrelazados que CAEN de la cima
## (`crece` = hasta dónde han llegado; el primero, el tronco, es un 60 % más grueso), cada uno con dos ramas; destello arriba y en el suelo, raíces que reptan por el suelo al llegar y chispas. El sello circular lo pone `_montar_sello`.
func _gen_pilar(lista: Array, bril: Array, env: float, cr: float) -> void:
	if _nube_tormenta != null:
		_gen_tormenta(bril, cr)
		return
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
		RayoTrazos.trazar(lista, pts, g * (1.6 if k == 0 else 1.0), 0.95 * env, cr, 1.0, 0.5, float(k) * 2.0)
		RayoTrazos.ramas(lista, pts, 2, 0.5 + rm, g * 0.55, 0.8 * env, cr, _rng, 3)
	bril.append({"pos": Vector3(0, alto, 0), "tam": 0.7 + rm * 1.4, "alfa": 0.9 * env * smoothstep(0.0, 0.3, cr), "estrella": 0.9})
	bril.append({"pos": Vector3(0, 0.15, 0), "tam": 1.4 + rm * 3.2, "alfa": 0.5 * env * smoothstep(0.7, 1.0, cr), "estrella": 0.0})
	bril.append({"pos": Vector3(0, 0.3, 0), "tam": 0.9 + rm * 1.6, "alfa": 0.95 * env * smoothstep(0.7, 1.0, cr), "estrella": 1.0})      # el destello del impacto en el suelo
	# RAÍCES: al tocar el suelo el rayo se ramifica a ras de tierra (cinco arcos que reptan hacia fuera)
	var llega: float = smoothstep(0.75, 1.0, cr)
	for kr in 5:
		var ar: float = TAU * float(kr) / 5.0 + _rng.randf_range(-0.35, 0.35)
		var lr: float = (0.45 + 1.4 * rm) * _rng.randf_range(0.7, 1.1)
		var pr: PackedVector3Array = RayoTrazos.camino(Vector3(0, 0.05, 0), Vector3(cos(ar) * lr, 0.05, sin(ar) * lr), 5, 0.1 + 0.2 * rm, _rng)
		for q in pr.size():
			var pq: Vector3 = pr[q]
			pq.y = 0.05 + 0.05 * float(q % 2)
			pr[q] = pq
		RayoTrazos.trazar(lista, pr, g * 0.55, 0.85 * env * llega, 1.0, 0.8, 0.7, float(kr) * 1.3)
		if kr < 3:
			bril.append({"pos": pr[pr.size() - 1] + Vector3(0, 0.08, 0), "tam": 0.28 + 0.2 * rm, "alfa": 0.8 * env * llega, "estrella": 0.9})
	for k2 in 3:
		var a3: float = _rng.randf() * TAU
		bril.append({"pos": Vector3(cos(a3) * rx * 1.3, 0.12, sin(a3) * rz * 1.3), "tam": 0.3 + 0.2 * rm, "alfa": 0.8 * env * smoothstep(0.7, 1.0, cr), "estrella": 0.9})


func _montar_nube_tormenta(cuerpo: Node3D) -> void:
	_nube_tormenta = Node3D.new()
	_nube_tormenta.name = "NubeTormenta"
	_nube_tormenta.position.y = clampf(semieje_y, 2.8, 4.4)
	_nube_tormenta.hide()
	cuerpo.add_child(_nube_tormenta)
	_material_tormenta = ShaderMaterial.new()
	_material_tormenta.shader = preload("res://presentacion/vfx/toy/rayo_nube_tormenta.gdshader")
	_material_tormenta.set_shader_parameter("centros", PackedVector3Array([
		Vector3(-0.76, -0.03, 0.02), Vector3(-0.48, 0.12, -0.17),
		Vector3(-0.12, 0.23, -0.17), Vector3(0.28, 0.18, -0.20),
		Vector3(0.62, 0.07, -0.09), Vector3(0.76, -0.04, 0.13),
		Vector3(0.38, -0.07, 0.33), Vector3(-0.05, -0.11, 0.42),
		Vector3(-0.49, -0.08, 0.31), Vector3(0.03, -0.01, 0.04),
	]))
	var malla := BoxMesh.new()
	malla.size = Vector3(2.68, 1.16, 2.30)
	malla.material = _material_tormenta
	var volumen := MeshInstance3D.new()
	volumen.mesh = malla
	volumen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	volumen.scale = Vector3.ONE * radio_sello()
	_nube_tormenta.add_child(volumen)


func _pie_tormenta(indice: int) -> Vector3:
	var angulo: float = float(indice) * 2.39996 + float(_semilla % 31) * 0.2
	var distancia: float = radio_sello() * (0.43 + 0.13 * float(indice % 3))
	return Vector3(cos(angulo) * distancia, 0.055, sin(angulo) * distancia)


func _actualizar_tormenta() -> bool:
	if _inicio_tormenta < 0.0 and crece > 0.02:
		_inicio_tormenta = _t
		var camara := get_viewport().get_camera_3d()
		if camara != null:
			var derecha: Vector3 = camara.global_basis.x
			derecha.y = 0.0
			var eje: Vector3 = _cuerpo.global_basis.inverse() * derecha
			_nube_tormenta.rotation.y = atan2(-eje.z, eje.x)
	var vida_nube: float = smoothstep(0.0, 1.0, crece) * (1.0 - clampf(corte, 0.0, 1.0))
	_nube_tormenta.visible = vida_nube > 0.01
	_nube_tormenta.scale = Vector3.ONE * lerpf(0.52, 1.0, vida_nube)
	_material_tormenta.set_shader_parameter("vida", vida_nube)
	var tiempo: float = _t - _inicio_tormenta - CARGA_TORMENTA
	if _inicio_tormenta < 0.0 or tiempo < 0.0 or corte > 0.0:
		_material_tormenta.set_shader_parameter("relampago", 0.0)
		return false
	var indice: int = int(tiempo / PERIODO_TORMENTA)
	var edad: float = fposmod(tiempo, PERIODO_TORMENTA)
	_material_tormenta.set_shader_parameter("relampago", 1.0 - smoothstep(0.025, 0.11, edad))
	if edad >= CAIDA_TORMENTA and indice != _ultimo_impacto_tormenta:
		_ultimo_impacto_tormenta = indice
		_impacto_reeboo(_pie_tormenta(indice), 0.36, Basis(Vector3.RIGHT, -PI * 0.5))
		return true
	return edad < CAIDA_TORMENTA


func _gen_tormenta(bril: Array, cr: float) -> void:
	if _inicio_tormenta < 0.0:
		return
	var edad_nube: float = _t - _inicio_tormenta
	var vida_nube: float = smoothstep(0.0, 1.0, cr) * (1.0 - clampf(corte, 0.0, 1.0))
	_chispas_borde_tormenta(bril, edad_nube, vida_nube)
	var tiempo: float = edad_nube - CARGA_TORMENTA
	if tiempo < 0.0 or corte > 0.0:
		return
	var indice: int = int(tiempo / PERIODO_TORMENTA)
	var edad: float = fposmod(tiempo, PERIODO_TORMENTA)
	var alfa: float = cr * (1.0 - smoothstep(CAIDA_TORMENTA + 0.025, PERIODO_TORMENTA - 0.015, edad))
	if alfa < 0.01:
		return
	var pie: Vector3 = _pie_tormenta(indice)
	var cima := Vector3(pie.x, _nube_tormenta.position.y - 0.13, pie.z)
	var orientacion := Basis(Vector3.UP, float(indice) * 2.39996) * Basis(Vector3.RIGHT, -PI * 0.5)
	_dibujar_descarga(cima, pie, orientacion, 0.17, alfa, minf(edad / CAIDA_TORMENTA, 1.0))
	bril.append({"pos": cima, "tam": 0.64, "alfa": alfa * 0.8, "estrella": 0.5})
	_chispas_nacimiento_tormenta(bril, cima, indice, edad, cr)


func _chispas_borde_tormenta(bril: Array, edad_nube: float, vida_nube: float) -> void:
	if vida_nube <= 0.01:
		return
	var radio: float = radio_sello()
	var periodo: float = 0.38
	for i in 12:
		var reloj: float = edad_nube + float(i) * 0.107
		var edad: float = fposmod(reloj, periodo)
		var duracion: float = 0.12 + float(i % 4) * 0.022
		if edad >= duracion:
			continue
		var u: float = edad / duracion
		var angulo: float = float(i) * 2.39996 + floor(reloj / periodo) * 1.31 + float(_semilla % 31)
		var pos := Vector3(cos(angulo) * 1.12, 0.16 * sin(angulo * 3.0), sin(angulo) * 0.81)
		pos *= radio * (0.96 + 0.17 * u)
		pos.y -= 0.18 * u
		var pulso: float = smoothstep(0.0, 0.17, u) * (1.0 - smoothstep(0.30, 1.0, u))
		bril.append({
			"pos": _nube_tormenta.transform * pos,
			"tam": (0.13 + float(i % 3) * 0.035) * (1.0 - 0.33 * u),
			"alfa": vida_nube * pulso * 0.85,
			"estrella": 0.88,
		})


func _chispas_nacimiento_tormenta(bril: Array, cima: Vector3, indice: int, edad: float, cr: float) -> void:
	for i in 8:
		var duracion: float = 0.074 + float(i % 4) * 0.019
		if edad >= duracion:
			continue
		var u: float = edad / duracion
		var angulo: float = float(i) * 2.39996 + float(indice) * 1.61
		var salida := Vector3(cos(angulo), -0.35 - float(i % 3) * 0.36, sin(angulo))
		var distancia: float = 0.08 + edad * (3.0 + float(i % 4) * 1.3)
		bril.append({
			"pos": cima + salida * distancia,
			"tam": (0.15 + float(i % 3) * 0.042) * (1.0 - 0.40 * u),
			"alfa": cr * (1.0 - smoothstep(0.25, 1.0, u)),
			"estrella": 1.0,
		})


## MURO = CORTINA DE ARCOS VERTICALES densos sobre una LÍNEA BRILLANTE en el suelo (referencia en vídeo, «Wall»). Semiejes: x = ANCHO, y = ALTO de los arcos, z = fondo (los arcos se reparten en él). Un arco cada ~0,2 m de ancho,
## cada uno de una altura distinta (de la mitad a la entera) y algo inclinado; la línea del suelo es un hilo recto y blanco con destellos. `crece` los hace saltar en cadena de izquierda a derecha.
func _gen_muro(lista: Array, bril: Array, env: float, cr: float) -> void:
	if RayoTrazos.prueba_reeboo:
		_gen_muro_descargas(bril, env, cr)
		return
	var a: float = semieje_x
	var b: float = semieje_z
	var alto: float = semieje_y
	_pos_luz = Vector3(0, alto * 0.5, 0)
	var nc: int = clampi(int(round(2.0 * a / 0.2)) + 1, 6, 24)
	var g: float = _grosor(alto / 1.5 * 0.5)
	var xs: Array = []
	for i in nc:
		xs.append(lerpf(-a, a, float(i) / float(nc - 1)))
	# la LÍNEA BRILLANTE del suelo: recta, de punta a punta, con destellos en los extremos y uno en medio
	var base: PackedVector3Array = PackedVector3Array([Vector3(-a, 0.04, 0.0), Vector3(a, 0.04, 0.0)])
	RayoTrazos.trazar(lista, base, g * 0.9, 0.95 * env, minf(cr * 1.6, 1.0), 1.0, 0.3, 0.0)
	bril.append({"pos": Vector3(-a, 0.08, 0.0), "tam": 0.5 + 0.1 * alto, "alfa": 0.85 * env, "estrella": 0.9})
	bril.append({"pos": Vector3(a, 0.08, 0.0), "tam": 0.5 + 0.1 * alto, "alfa": 0.85 * env * smoothstep(0.5, 1.0, cr), "estrella": 0.9})
	bril.append({"pos": Vector3(0.0, 0.05, 0.0), "tam": 0.4 + a * 0.35, "alfa": 0.3 * env, "estrella": 0.0})
	var altos: Array = []
	for i in nc:
		var u0: float = float(i) / float(nc - 1)
		var tramo: float = clampf((cr - u0 * 0.6) / 0.4, 0.0, 1.0)
		var h: float = alto * _rng.randf_range(0.5, 1.0)
		altos.append(h)
		if tramo <= 0.0:
			continue
		var z: float = _rng.randf_range(-0.5, 0.5) * b
		var x: float = xs[i]
		var pts: PackedVector3Array = RayoTrazos.camino(Vector3(x, 0.04, z), Vector3(x + _rng.randf_range(-0.12, 0.12), h, z), 4, 0.04 + 0.025 * alto, _rng)
		for q in pts.size():
			var pq: Vector3 = pts[q]
			pq.x = clampf(pq.x, -a, a)                                          # ningún arco se sale del ancho del muro
			pts[q] = pq
		RayoTrazos.trazar(lista, pts, g * 0.85, 0.95 * env, tramo, 0.9, 0.7, float(i))
		if _rng.randf() < 0.25:
			bril.append({"pos": pts[pts.size() - 1], "tam": 0.2 + 0.05 * alto, "alfa": 0.75 * env * tramo, "estrella": 0.9})
	# unos pocos arcos que unen la cima de un arco con la del vecino
	for k in 3:
		var i2: int = _rng.randi_range(0, nc - 2)
		var u1: float = float(i2) / float(nc - 1)
		var tr2: float = clampf((cr - u1 * 0.6) / 0.4, 0.0, 1.0)
		if tr2 <= 0.0:
			continue
		var p0: Vector3 = Vector3(xs[i2], float(altos[i2]) * 0.9, 0.0)
		var p1: Vector3 = Vector3(xs[i2 + 1], float(altos[i2 + 1]) * 0.9, 0.0)
		RayoTrazos.trazar(lista, RayoTrazos.camino(p0, p1, 3, 0.06 + 0.03 * alto, _rng), g * 0.4, 0.7 * env, tr2, 0.7, 0.7, float(i2) * 5.0)


## Descargas que se cruzan a distintas alturas. Los contactos con el suelo son puntuales.
func _gen_muro_descargas(bril: Array, env: float, cr: float) -> void:
	if cr <= 0.01:
		return
	var alto: float = semieje_y * cr
	var ancho_muro: float = semieje_x * 2.0
	var cantidad: int = clampi(ceili(ancho_muro / maxf(semieje_y * 0.95, 0.8)), 4, 9)
	var grueso: float = clampf(semieje_y * 0.10, 0.085, 0.21)
	_pos_luz = Vector3(0.0, alto * 0.42, 0.0)
	for i in cantidad:
		var reloj: float = _t * velocidad / (0.19 + float(i % 4) * 0.041) + float(i) * 0.37
		var ciclo: float = floorf(reloj)
		var fase: float = reloj - ciclo
		var pulso: float = smoothstep(0.0, 0.10, fase) * (1.0 - smoothstep(0.59, 1.0, fase))
		var alfa: float = env * cr * pulso
		if alfa < 0.015:
			continue
		var variacion: float = sin(ciclo * 3.23 + float(i) * 4.17 + float(_semilla % 97))
		var centro: float = (float(i) + 0.5 + variacion * 0.22) / float(cantidad)
		var alcance: float = (1.20 + 0.24 * float(i % 3)) / float(cantidad)
		var x0: float = lerpf(-semieje_x, semieje_x, clampf(centro - alcance, 0.0, 1.0))
		var x1: float = lerpf(-semieje_x, semieje_x, clampf(centro + alcance, 0.0, 1.0))
		var z: float = clampf(semieje_z * 0.55, 0.03, 0.48) * sin(float(i) * 2.41 + ciclo)
		var pie: bool = (i + int(ciclo)) % 3 != 1
		var altura_inicio: float = 0.05 if pie else maxf(0.05, alto * 0.58)
		var inicio := Vector3(x0, altura_inicio, z)
		var fin := Vector3(x1, alto * (0.35 + 0.15 * variacion) + 0.05, -z)
		if (i + int(ciclo)) % 2 != 0:
			var intercambio: Vector3 = inicio
			inicio = fin
			fin = intercambio
		var elevacion: float = alto * (0.20 + 0.17 * float(i % 3) + 0.10 * variacion)
		var arco: PackedVector3Array = _trazo_muro_descarga(inicio, fin, elevacion, alto, 16)
		_guardar_cinta(arco, grueso, grueso * 0.52, alfa, alfa * 0.78)
		var nudo: Vector3 = arco[5 + i % 4]
		var x_rama: float = lerpf(nudo.x, x1 if i % 2 == 0 else x0, 0.73)
		var contacto := Vector3(x_rama, 0.05, -z * 0.7)
		var rama: PackedVector3Array = _trazo_muro_descarga(nudo, contacto, alto * 0.08, alto, 8)
		_guardar_cinta(rama, grueso * 0.54, grueso * 0.09, alfa * 0.86, alfa * 0.51)
		bril.append({"pos": contacto, "tam": 0.22 + grueso, "alfa": alfa * 0.60, "estrella": 0.45})


func _trazo_muro_descarga(inicio: Vector3, fin: Vector3, elevacion: float, alto: float, pasos: int) -> PackedVector3Array:
	var trazo := PackedVector3Array([inicio])
	var amplitud: float = clampf(alto * 0.48, 0.06, 0.66)
	for i in range(1, pasos):
		var u: float = float(i) / float(pasos)
		var guia: Vector3 = inicio.lerp(fin, u)
		guia.y += (sin(PI * u) + 0.32 * sin(TAU * u)) * elevacion
		var punto: Vector3 = _muestra_descarga(guia, _t - (1.0 - u) * 0.07, amplitud * sin(PI * u))
		punto.x = clampf(punto.x, -semieje_x, semieje_x)
		punto.y = clampf(punto.y, 0.05, alto + 0.05)
		trazo.append(punto)
	trazo.append(fin)
	return trazo


## BARRERA = ARO CHISPEANTE sobre el elipsoide (centro a 0,4·y como la del fuego): tres aros quebrados a 0,12·y, 0,65·y y 1,2·y (el radio sigue la curva del elipsoide) y cuatro arcos que los unen. `crece` cierra los aros.
func _gen_barrera(lista: Array, bril: Array, env: float, cr: float) -> void:
	if _cupula_barrera != null:
		_gen_cupula_electrica(bril, env, cr)
		return
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
	bril.append({"pos": Vector3(0, 0.1, 0), "tam": (x + z) * 1.2, "alfa": 0.2 * env, "estrella": 0.0})


func _gen_cupula_electrica(bril: Array, env: float, cr: float) -> void:
	var crecimiento: float = lerpf(0.62, 1.0, smoothstep(0.0, 1.0, cr))
	var radio: float = minf(semieje_x, semieje_z)
	var alto: float = maxf(semieje_y, radio * 0.64)
	var centro := Vector3.UP * (alto * 0.48 * crecimiento)
	var radios := Vector3(semieje_x, alto * 0.72, semieje_z) * crecimiento
	_cupula_barrera.position = centro
	_cupula_barrera.scale = radios
	var material := _cupula_barrera.material_override as ShaderMaterial
	material.set_shader_parameter("aparicion_cupula", cr * (1.0 - clampf(corte, 0.0, 1.0)))
	_pos_luz = centro
	var grueso: float = clampf(radio * 0.11, 0.045, 0.14)
	for i in 7:
		var reloj: float = _t * velocidad / (0.17 + 0.043 * float(i % 4)) + float(i) * 0.37
		var ciclo: float = floorf(reloj)
		var fase: float = reloj - ciclo
		var alfa: float = env * cr * smoothstep(0.0, 0.10, fase) * (1.0 - smoothstep(0.56, 1.0, fase))
		if alfa < 0.02:
			continue
		var angulo: float = float(i) * 2.39996 + ciclo * 1.71 + float(_semilla % 31) * 0.2
		var latitud: float = 0.14 + 0.43 * sin(angulo * 1.73 + float(i))
		var giro: float = (0.55 + 0.29 * float(i % 3)) * lerpf(0.48, 1.0, smoothstep(0.0, 0.52, fase))
		var desnivel: float = 0.75 * sin(angulo * 2.13)
		var arco := PackedVector3Array()
		for j in 11:
			var u: float = float(j) / 10.0
			var a: float = angulo + giro * u
			var l: float = clampf(latitud + desnivel * u + 0.18 * sin(u * PI), -0.61, 1.22)
			var normal := Vector3(cos(a) * cos(l), sin(l), sin(a) * cos(l))
			var pos: Vector3 = centro + normal * radios * 1.014
			var tangente := Vector3(-sin(a), 0.0, cos(a))
			var ruido: Basis = Basis(tangente, normal.cross(tangente), normal)
			arco.append(_muestra_descarga(pos, _t - u * 0.07, grueso * 1.7 * sin(u * PI), ruido))
		_guardar_cinta(arco, grueso * (1.0 if i % 3 == 0 else 0.57), grueso * 0.12, alfa, alfa * 0.46)
		if i % 2 == 0:
			bril.append({"pos": arco[6], "tam": grueso * 2.5, "alfa": alfa * 0.66, "estrella": 0.8})


## HAZ = TUBO DE ENERGÍA recto entre la mano (el origen) y el objetivo (hacia -Z, a la altura máx(y, 0,4)) con arcos que se ENROSCAN alrededor y destellos en los dos extremos (referencia en vídeo, «Beam»): un tronco casi recto
## y grueso (blanco con el halo del rayo), una segunda línea fina con algo de desviación, dos hélices de arcos cortos que lo rodean (cambian de fase en cada redibujo) y tres ramas. `crece` lo extiende de golpe hasta la punta.
func _gen_haz(lista: Array, bril: Array, env: float, cr: float) -> void:
	if RayoTrazos.prueba_descarga:
		_gen_haz_descarga(bril, env, cr)
		return
	if RayoTrazos.prueba_toon:
		_gen_haz_toon(lista, bril, env, cr)
		return
	var largo: float = _haz_largo
	var alt: float = _haz_alt
	_pos_luz = Vector3(0, alt, -largo * 0.5)
	var n: int = clampi(int(round(largo / 0.28)), 8, 20)
	var g: float = _grosor(_haz_r / 0.45 * 0.6)
	var amp: float = 0.1 + 0.5 * _haz_r * 0.5
	# el TUBO: una recta de punta a punta (grueso y blanco) y, encima, su línea quebrada fina
	var tubo: PackedVector3Array = PackedVector3Array([Vector3(0, alt, 0), Vector3(0, alt, -largo)])
	RayoTrazos.trazar(lista, tubo, g * 1.5, 0.97 * env, cr, 1.0, 0.35, 0.0)
	var pts: PackedVector3Array = RayoTrazos.camino(Vector3(0, alt, 0), Vector3(0, alt, -largo), n, amp * 0.35, _rng)
	RayoTrazos.trazar(lista, pts, g * 0.7, 0.9 * env, cr, 1.0, 0.5, 4.0)
	# las HÉLICES: dos arcos que se enroscan alrededor del tubo
	var hr: float = clampf(0.05 + 0.3 * _haz_r, 0.06, 0.22)
	for k in 2:
		var fase: float = _rng.randf() * TAU
		var vueltas: float = _rng.randf_range(1.5, 3.0) * (1.0 if k == 0 else -1.0)
		var m: int = clampi(int(round(largo / 0.2)), 8, 18)
		var hel: PackedVector3Array = PackedVector3Array()
		for q in m + 1:
			var u: float = float(q) / float(m)
			var ang: float = fase + vueltas * TAU * u
			var rr: float = hr * (0.55 + 0.45 * sin(PI * u)) * _rng.randf_range(0.8, 1.25)
			hel.append(Vector3(cos(ang) * rr, alt + sin(ang) * rr, -largo * u))
		RayoTrazos.trazar(lista, hel, g * 0.42, 0.85 * env, cr, 0.8, 0.8, 7.0 + float(k) * 3.0)
	RayoTrazos.ramas(lista, pts, 3, 0.35 + 0.4 * largo * 0.2, g * 0.5, 0.8 * env, cr, _rng, 3)
	# destellos en los dos extremos (la mano y la punta) y chispas a lo largo
	bril.append({"pos": Vector3(0, alt, 0), "tam": 0.9 + _haz_r * 1.6, "alfa": 0.95 * env, "estrella": 0.95})
	bril.append({"pos": Vector3(0, alt, -largo * cr), "tam": 1.0 + _haz_r * 2.0, "alfa": 0.95 * env * smoothstep(0.5, 1.0, cr), "estrella": 0.95})
	for k in 3:
		bril.append({"pos": Vector3(_rng.randf_range(-0.2, 0.2), alt + _rng.randf_range(-0.2, 0.2), -largo * _rng.randf_range(0.2, 1.0) * cr), "tam": 0.25, "alfa": 0.7 * env, "estrella": 0.9})


func _estela_bola(lista: Array, r: float, g: float, vuelo: float, env: float) -> void:
	if RayoTrazos.prueba_cinta:
		_estela_cinta(r, g, vuelo, env)
		return
	var largo: float = r * COLA_BOLA * vuelo
	var z0: float = r * 0.5
	if RayoTrazos.prueba_toon:
		var intensidad: float = maxf(env, 0.55) * vuelo
		var grueso: float = g * 1.65
		var origen := Vector3(0, 0, z0)
		var punta := origen + Vector3.BACK * largo * 2.15
		var arco := Vector3(1.0, 1.1, 0.0) * r * 1.45 * vuelo
		var quiebro := Vector3(-0.35, 1.0, 0.0) * r * 1.15 * vuelo
		var tronco := _relampago(origen, punta, arco, quiebro)
		_afilado(lista, tronco, grueso, grueso * 0.14, intensidad, intensidad * 0.65, 0.78, 0.18, 3.0)
		var rama := PackedVector3Array([tronco[2], tronco[3] - arco * 1.45, punta - arco * 0.9])
		_afilado(lista, rama, grueso * 0.55, grueso * 0.1, intensidad, intensidad * 0.40, 0.66, 0.22, 4.0)
		return
	var pc := RayoTrazos.camino(Vector3(0, 0, z0), Vector3(0, 0, z0 + largo), 6, 0.05 * r, _rng)
	_afilado(lista, pc, g * 0.62, g * 0.12, 0.98 * env, 0.3 * env, 0.8, 0.35, 3.0)
	var pc2 := RayoTrazos.camino(Vector3(0.12 * r, 0.06 * r, z0), Vector3(-0.1 * r, 0.05 * r, z0 + largo * 0.7), 5, 0.1 * r, _rng)
	_afilado(lista, pc2, g * 0.3, g * 0.08, 0.7 * env, 0.25 * env, 0.8, 0.5, 4.0)


## Una estela tenue sigue el recorrido; los arcos nacen en la cabeza y se abren al aire.
func _estela_proyectil_reeboo(r: float, vuelo: float, env: float) -> void:
	var alfa: float = maxf(env, 0.56) * vuelo
	if alfa <= 0.01:
		return
	var estela := PackedVector3Array([Vector3.ZERO])
	var restante: float = r * 6.0
	for muestra in _estela_mundo:
		var local: Vector3 = _cuerpo.to_local(muestra)
		var tramo: float = estela[-1].distance_to(local)
		if tramo < r * 0.25:
			continue
		estela.append(estela[-1].lerp(local, minf(1.0, restante / tramo)))
		restante -= tramo
		if restante <= 0.0:
			break
	if estela.size() > 1:
		_cintas.append({
			"puntos": estela, "ancho": r * 1.25, "punta": r * 0.35,
			"alfa": alfa * 0.43, "alfa_punta": 0.0, "suave": true,
		})
	var plano_vista: Basis = _plano_proyectil_en_vista()
	var espejo := Transform3D(plano_vista * Basis.from_scale(Vector3(1.0, 1.0, -1.0)) * plano_vista.inverse(), Vector3.ZERO)
	var reflejos: Array[Dictionary] = []
	for i in 5:
		var reloj: float = _t * velocidad / (0.105 + 0.027 * float(i)) + float(i) * 0.43
		var fase: float = fposmod(reloj, 1.0)
		var angulo: float = float(i) * 2.39996 + sin(floorf(reloj) * 2.3 + float(_semilla % 97)) * 0.85
		var radial := Vector3(cos(angulo), sin(angulo), 0.0)
		var lado := Vector3(-radial.y, radial.x, 0.0)
		var largo: float = r * (2.7 + 0.65 * float(i % 3)) * lerpf(0.62, 1.13, smoothstep(0.0, 0.65, fase))
		var salida: Vector3 = (radial + Vector3.BACK * (0.32 + 0.35 * float(i % 3))) * largo
		var pulso: float = alfa * lerpf(1.0, 0.58, smoothstep(0.55, 1.0, fase)) * (1.0 if i < 3 else 0.68)
		var origen: Vector3 = radial * r * 0.28
		var curva: Vector3 = (lado + Vector3.BACK * 0.65) * largo * 0.30
		var arco: PackedVector3Array = _relampago(origen, origen + salida, curva, lado * largo * 0.18)
		_guardar_cinta(arco, r * (0.43 if i < 3 else 0.24), r * 0.075, pulso, pulso * 0.56)
		if i == 1 or i == 2:
			# Copia los dos trazos animados, sin volver a sortear su forma ni su pulso.
			reflejos.append({"puntos": espejo * arco, "ancho": r * 0.43, "punta": r * 0.075,
				"alfa": pulso, "alfa_punta": pulso * 0.56})
		if i < 3:
			var punta_rama: Vector3 = arco[2] + (radial * 0.48 - lado * 0.66 + Vector3.BACK * 0.50) * largo * 0.65
			var rama: PackedVector3Array = _relampago(arco[2], punta_rama, -lado * largo * 0.12, radial * largo * 0.075)
			_guardar_cinta(rama, r * 0.20, r * 0.042, pulso * 0.80, pulso * 0.38)
	_cintas.append_array(reflejos)


## Da el eje de vuelo en pantalla para reflejar los rayos de la bola.
func _plano_proyectil_en_vista() -> Basis:
	var camara := get_viewport().get_camera_3d()
	if camara == null:
		return Basis.IDENTITY
	var centro: Vector3 = _cuerpo.global_position
	var destino: Vector3 = centro - _cuerpo.global_basis.z
	var direccion: Vector2 = camara.unproject_position(destino) - camara.unproject_position(centro)
	direccion = direccion.normalized() if direccion.length_squared() > 0.25 else Vector2.RIGHT
	var vista: Basis = camara.global_basis.orthonormalized()
	var frente: Vector3 = vista.x * direccion.x - vista.y * direccion.y
	var arriba: Vector3 = vista.z.cross(frente)
	# Compensa la escala de aparición del cuerpo para que la X no se aplaste.
	var base_local: Basis = _cuerpo.global_basis
	return base_local.inverse() * Basis(vista.z, arriba, -frente).scaled(Vector3.ONE * base_local.z.length())


## Las posiciones ya recorridas se guardan en mundo, también al rebotar.
func _muestrear_estela(delta: float) -> void:
	_reloj_estela += delta
	if _reloj_estela < 0.020 and not _estela_mundo.is_empty():
		return
	_reloj_estela = 0.0
	if not _estela_mundo.is_empty() and _estela_mundo[0].distance_to(global_position) < 0.035:
		if _estela_mundo.size() > 1:
			_estela_mundo.pop_back()
		return
	_estela_mundo.push_front(global_position)
	if _estela_mundo.size() > 10:
		_estela_mundo.pop_back()


func _estela_cinta(r: float, g: float, vuelo: float, env: float) -> void:
	var camino := PackedVector3Array([Vector3(0, 0, r * 0.20)])
	var largo: float = 0.0
	for p in _estela_mundo:
		var local: Vector3 = _cuerpo.to_local(p)
		var tramo: float = camino[-1].distance_to(local)
		if tramo < r * 0.48:
			continue
		largo += tramo
		camino.append(local)
		if largo >= r * 7.0:
			break
	if camino.size() < 2:
		return
	for i in range(1, camino.size()):
		var u: float = float(i) / float(camino.size() - 1)
		var quiebre: float = (1.0 if i % 2 == 1 else -1.0) * _rng.randf_range(0.48, 0.95)
		if RayoTrazos.prueba_descarga:
			quiebre *= 0.34 if i % 3 == 1 else 1.75
		camino[i] += Vector3(0.36 * quiebre, sin(u * PI) * 0.65 + quiebre, 0) * r * smoothstep(0.0, 0.5, u)
	var alfa: float = maxf(env, 0.48) * vuelo
	_guardar_cinta(camino, g * (1.13 if RayoTrazos.prueba_descarga else 1.55), 0.009, alfa, alfa * 0.28)
	if camino.size() >= 4:
		if RayoTrazos.prueba_descarga:
			# Guías que se abren en un cono hacia atrás. Cada una deja su propia estela.
			for i in 7:
				var angulo: float = float(i) * TAU / 7.0 + 0.5
				var salida := Vector3(cos(angulo), sin(angulo), 1.7 + 0.23 * float(i % 3)) * r
				var nudo: Vector3 = _rama_descarga(camino[i / 2], salida, g * (0.27 + 0.13 * float(i % 3)), alfa, i)
				if i % 2 == 0:
					var bifurcacion := Vector3(-sin(angulo), cos(angulo), 0.8) * r
					_rama_descarga(nudo, bifurcacion, g * 0.22, alfa * 0.83, i + 7)
			return
		var medio: int = camino.size() / 2
		var rama := PackedVector3Array([camino[1], camino[medio] + Vector3(0.45, -0.65, 0) * r, camino[-1] + Vector3(0.8, -0.65, 0) * r])
		_guardar_cinta(rama, g * 0.6, 0.008, alfa * 0.8, alfa * 0.13)


func _guardar_cinta(pts: PackedVector3Array, grosor: float, punta: float, alfa: float, alfa_punta: float) -> void:
	_cintas.append({"puntos": pts, "ancho": grosor, "punta": punta, "alfa": alfa, "alfa_punta": alfa_punta})


## La curva marca la silueta y los quiebros se leen a escala de juego. Solo se agita el interior.
func _relampago(origen: Vector3, punta: Vector3, arco: Vector3, quiebro: Vector3) -> PackedVector3Array:
	return PackedVector3Array([
		origen,
		origen.lerp(punta, 0.19) + arco * 0.7,
		origen.lerp(punta, 0.39) + arco + quiebro * _rng.randf_range(0.65, 1.0),
		origen.lerp(punta, 0.47) + arco * 0.86 - quiebro * _rng.randf_range(0.8, 1.1),
		origen.lerp(punta, 0.74) + arco * 0.6 + quiebro * _rng.randf_range(0.35, 0.65),
		punta,
	])


## El tronco conserva el origen y el contacto. Las ramas nacen en sus quiebros.
func _gen_haz_toon(lista: Array, bril: Array, env: float, cr: float) -> void:
	var origen := Vector3(0, _haz_alt, 0)
	var punta := origen + Vector3.FORWARD * _haz_largo
	var arco := Vector3(-0.42, 1.0, 0.0) * minf(_haz_largo * 0.22, 1.2)
	var quiebro := Vector3(-0.38, 1.0, 0.0) * minf(_haz_largo * 0.16, 0.92)
	var tronco := _relampago(origen, punta, arco, quiebro)
	_pos_luz = tronco[2].lerp(tronco[3], 0.5)
	var grueso: float = _grosor(_haz_r / 0.45 * 0.6) * 1.23
	var alfa: float = env * 0.65 + 0.25 * pow(1.0 - clampf(corte, 0.0, 1.0), 1.5)
	var progreso: float = cr * float(tronco.size() - 1)
	var tramo: int = mini(int(progreso), tronco.size() - 2)
	var frente: Vector3 = tronco[tramo].lerp(tronco[tramo + 1], progreso - float(tramo))
	if RayoTrazos.prueba_cinta:
		if cr > 0.0:
			var visible := tronco.slice(0, int(ceil(progreso)))
			visible.append(frente)
			var detalle := PackedVector3Array([origen])
			for i in range(1, visible.size()):
				var a: Vector3 = visible[i - 1]
				var b: Vector3 = visible[i]
				var desvio: Vector3 = Vector3(0.4, 1.0, 0.0) * minf(a.distance_to(b) * 0.13, 0.12)
				detalle.append(a.lerp(b, 0.47) + desvio * _rng.randf_range(-1.0, 1.0))
				detalle.append(b)
			_guardar_cinta(detalle, grueso * 0.71, grueso * 0.37, alfa, alfa * 0.88)
	else:
		RayoTrazos.trazar(lista, tronco, grueso, alfa, cr, 0.82, 0.18, 0.0, 0.75)
	if cr >= 0.4:
		var alta := PackedVector3Array([tronco[2], tronco[2].lerp(tronco[4], 0.53) + arco * 0.52, tronco[4] + arco * 0.6 - quiebro * 0.6])
		if RayoTrazos.prueba_cinta:
			_guardar_cinta(alta, grueso * 0.44, 0.01, alfa, alfa * 0.45)
		else:
			_afilado(lista, alta, grueso * 0.5, grueso * 0.12, alfa, alfa * 0.45, 0.66, 0.24, 4.0)
	if cr >= 0.6:
		var baja := PackedVector3Array([tronco[3], tronco[3].lerp(tronco[4], 0.58) - arco * 0.46, tronco[4] - arco * 0.42 + quiebro * 0.53])
		if RayoTrazos.prueba_cinta:
			_guardar_cinta(baja, grueso * 0.42, 0.01, alfa, alfa * 0.52)
		else:
			_afilado(lista, baja, grueso * 0.48, grueso * 0.12, alfa, alfa * 0.52, 0.66, 0.24, 6.0)
	bril.append({"pos": origen, "tam": 0.34, "alfa": env * 0.7, "estrella": 0.45})
	bril.append({"pos": frente, "tam": 0.42, "alfa": env * cr, "estrella": 0.55})


## Tronco irregular y bifurcaciones abiertas. Los extremos vienen del haz real.
func _gen_haz_descarga(bril: Array, env: float, cr: float) -> void:
	var origen := Vector3(0, _haz_alt, 0)
	var punta := origen + Vector3.FORWARD * _haz_largo
	var grueso: float = _grosor(_haz_r / 0.45 * 0.6) * 1.03
	var alfa: float = env * 0.68 + 0.28 * (1.0 - clampf(corte, 0.0, 1.0))
	var frente: Vector3 = _dibujar_descarga(origen, punta, Basis.IDENTITY, grueso, alfa, cr)
	if _fase_espejo(_t):
		# Refleja también los nudos y el ruido respecto al eje que une los contactos.
		var espejo := Transform3D(Basis.from_scale(Vector3(1, -1, 1)), Vector3(0, 2.0 * _haz_alt, 0))
		for cinta: Dictionary in _cintas:
			var puntos: PackedVector3Array = cinta["puntos"]
			cinta["puntos"] = espejo * puntos
		frente = espejo * frente
		_pos_luz = espejo * _pos_luz
	bril.append({"pos": origen, "tam": 0.38, "alfa": env, "estrella": 0.65})
	bril.append({"pos": frente, "tam": 0.48, "alfa": env * cr, "estrella": 0.65})


func _dibujar_descarga(origen: Vector3, punta: Vector3, orientacion: Basis, grueso: float, alfa: float, cr: float) -> Vector3:
	var escala: float = minf(origen.distance_to(punta), 7.0)
	var tronco := PackedVector3Array([origen])
	var u: Array[float] = [0.12, 0.25, 0.32, 0.45, 0.49, 0.61, 0.73, 0.77, 0.90]
	var alto: Array[float] = [0.055, 0.105, 0.050, 0.148, 0.118, 0.050, 0.085, 0.017, 0.039]
	for i in u.size():
		var punto: Vector3 = origen.lerp(punta, u[i]) + orientacion.y * alto[i] * escala
		tronco.append(_muestra_descarga(punto, _t, minf(escala * 0.055, 0.33), orientacion))
	tronco.append(punta)
	_pos_luz = tronco[4]
	var avance: float = cr * float(tronco.size() - 1)
	var tramo: int = mini(int(avance), tronco.size() - 2)
	var frente: Vector3 = tronco[tramo].lerp(tronco[tramo + 1], avance - float(tramo))
	if cr > 0.0:
		var visible := tronco.slice(0, int(ceil(avance)))
		visible.append(frente)
		_guardar_cinta(visible, grueso, grueso * 0.50, alfa, alfa * 0.89)
	var direcciones := PackedVector3Array([
		Vector3(0.10, -0.11, -0.13), Vector3(-0.045, 0.24, -0.23),
		Vector3(-0.14, 0.05, -0.17), Vector3(0.075, -0.20, -0.23),
		Vector3(-0.13, 0.15, -0.18), Vector3(0.14, -0.10, -0.12),
		Vector3(-0.07, 0.13, -0.11), Vector3(0.035, -0.085, -0.08),
		Vector3(-0.05, 0.07, -0.045),
	])
	for i in direcciones.size():
		if avance < float(i + 1):
			break
		var salida: Vector3 = orientacion * direcciones[i] * escala
		var nudo: Vector3 = _rama_descarga(tronco[i + 1], salida, grueso * (0.35 + 0.10 * float(i % 3)), alfa, i, orientacion)
		var giro: float = 1.0 if i % 2 == 0 else -1.0
		var desvio: Vector3 = orientacion * Vector3(0.08 * giro, 0.08 * giro, -0.07) * escala
		_rama_descarga(nudo, salida * 0.27 + desvio, grueso * 0.26, alfa * 0.84, i + direcciones.size(), orientacion)
		if i % 3 == 1:
			_rama_descarga(nudo, salida * 0.42 - desvio, grueso * 0.29, alfa * 0.91, i + 2 * direcciones.size(), orientacion)
	return frente


func _fase_espejo(tiempo: float) -> bool:
	return int(floor((tiempo + 0.00001) / T_REDIBUJO)) % 2 != 0


func _rama_descarga(origen: Vector3, salida: Vector3, ancho_rama: float, alfa: float, indice: int, orientacion: Basis = Basis.IDENTITY) -> Vector3:
	var vida_rama: float = 0.105 + float(indice % 4) * 0.028
	var fase: float = fposmod(_t * velocidad + float(indice) * 0.074, vida_rama) / vida_rama
	var extension: float = lerpf(0.30, 1.14, smoothstep(0.0, 0.62, fase))
	var intensidad: float = alfa * lerpf(1.0, 0.22, smoothstep(0.55, 1.0, fase))
	var rama := PackedVector3Array([origen])
	for i in range(1, 7):
		var u: float = float(i) / 6.0
		var guia: Vector3 = origen + salida * u * extension
		var tiempo_muestra: float = _t - (1.0 - u) * vida_rama * fase
		var amplitud: float = minf(salida.length() * 0.29, 0.36) * smoothstep(0.0, 0.55, u)
		rama.append(_muestra_descarga(guia, tiempo_muestra, amplitud, orientacion))
	_guardar_cinta(rama, ancho_rama, 0.006, intensidad, intensidad * 0.45)
	return rama[3]


## Como en el tutorial, se perturba cada muestra de la guía antes de unir la estela.
func _muestra_descarga(punto: Vector3, tiempo: float, amplitud: float, orientacion: Basis = Basis.IDENTITY) -> Vector3:
	if _ruido_descarga == null:
		_ruido_descarga = FastNoiseLite.new()
		_ruido_descarga.seed = _semilla
		_ruido_descarga.noise_type = FastNoiseLite.TYPE_VALUE
		_ruido_descarga.frequency = 10.0
		_ruido_descarga.fractal_octaves = 3
	var mundo: Vector3 = _cuerpo.to_global(punto)
	var coords: Vector3 = mundo + Vector3(0.71, 1.9, -1.03) * tiempo * velocidad
	var lateral: float = _ruido_descarga.get_noise_3dv(coords)
	var vertical: float = _ruido_descarga.get_noise_3dv(coords + Vector3(13.5, 9.2, -8.7))
	return punto + (orientacion.x * lateral + orientacion.y * vertical) * amplitud * chisporroteo
