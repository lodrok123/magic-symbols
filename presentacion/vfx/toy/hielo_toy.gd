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

enum Figura { BOLA, MURO, PILAR, BARRERA, HAZ }
enum EstadoCarga { NINGUNA, CARGANDO, SOLTANDO, APAGANDO, CANCELANDO }

const HieloMallas = preload("res://presentacion/vfx/toy/hielo_mallas.gd")
const HieloEsquirlas = preload("res://presentacion/vfx/toy/hielo_esquirlas.gd")
const CargaHielo = preload("res://presentacion/vfx/toy/carga_hielo_toy.gd")

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
	_montar_cristales(c, HieloMallas.capa_muro(semieje_x, semieje_z, semieje_y, 1.0 + semieje_x), 2.0)
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
	_cupula = _mi_hielo(c, "Cupula", HieloMallas.bloque(0.04, 7.0), HieloMallas.material(HieloMallas.SH_CRISTAL, {"opacidad": 0.13, "escarcha_base": 0.0, "rim_pot": 2.6}, 0))
	_cupula.position = Vector3(0, 0.4 * semieje_y, 0)
	_cupula.scale = Vector3(semieje_x, semieje_y, semieje_z)
	_escarcha_base(c, 2.0 * semieje_x * 1.3, 2.0 * semieje_z * 1.3)


# ------------------------------------------------------------------ HAZ ------------------------------------------------------------------

## HAZ DE HIELO: una lanza que NACE de un punto en el origen (la mano) hacia -Z a la altura máx(y, 0,4), con púas a lo largo y un destello en la punta. `crece` la alarga en tres escalones y `corte` la rompe de la
## mano hacia fuera (la punta es lo último).
func _haz(c: Node3D) -> void:
	_haz_largo = semieje_x * 2.0
	_haz_r = semieje_z * FuegoToy.HAZ_ABRE
	_haz_alt = maxf(semieje_y, 0.4)
	var capa: Array = HieloMallas.capa_haz(_haz_largo, _haz_r, _haz_alt, 1.0 + semieje_x)
	for d in capa:
		var dist: float = clampf(-(d["pos"] as Vector3).z / maxf(_haz_largo, 0.01), 0.0, 1.0)
		d["rompe"] = clampf(dist * 0.55, 0.0, 0.55) if float(d["h"]) < _haz_largo * 0.9 else 0.3
	_montar_cristales(c, capa, 5.0)
	_punta = HieloMallas.destello("Punta")
	_punta.position = Vector3(0, _haz_alt, -_haz_largo)
	c.add_child(_punta)


## Posición local de la punta de la lanza con `crece` actual.
func _haz_z_punta() -> float:
	return -_escalon(crece) * _haz_largo * 0.97


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
		if co > 0.0 and rompe > 0.001:                                     # antes de estallar, tiembla
			pos += Vector3(sin(tt * 53.0 + float(j) * 1.7), 0.0, cos(tt * 47.0 + float(j))) * 0.012 * minf(co * 6.0, 1.0)
		var f: float = s * rompe
		_h_act.append(float(c["h"]) * altura * f)
		HieloMallas.poner(mm, j, pos, c["rot"], float(c["wx"]) * ancho, float(c["h"]) * altura * f, float(c["wz"]) * ancho, float(c["claro"]), 0.95 if f > 0.001 else 0.0, float(c["fase"]))
	var ms: ShaderMaterial = _cris_mm.material_override as ShaderMaterial
	ms.set_shader_parameter("grieta", smoothstep(0.0, 0.35, co))
	var esc: float = _escalon(cr)
	if _suelo != null and is_instance_valid(_suelo):
		var an: Vector2 = _suelo.get_meta("ancho", Vector2.ONE)
		var k: float = lerpf(0.3, 1.0, esc)
		_suelo.scale = Vector3(an.x * k, 1.0, an.y * k)
		var mf: ShaderMaterial = _suelo.material_override as ShaderMaterial
		mf.set_shader_parameter("u", esc)
		mf.set_shader_parameter("vida", 0.9 * smoothstep(0.0, 0.12, cr) * (1.0 - smoothstep(0.45, 1.0, co)))
	if _cupula != null and is_instance_valid(_cupula):
		var kc: float = maxf(esc * (1.0 - smoothstep(0.1, 0.5, co)), 0.001)
		_cupula.scale = Vector3(semieje_x, semieje_y, semieje_z) * kc
		_cupula.position = Vector3(0, 0.4 * semieje_y * kc, 0)
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
		nacer = T_NACER_HAZ
		morir_s = T_MORIR_HAZ
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
