class_name MagmaToy
extends EfectoToy

## MAGMA «TOY» (6/11/2026; concepto de Pablo en vídeo, fotogramas en docs/capturas/referencias/magma_concepto/). Clase HERMANA de FuegoToy, AguaToy, HieloToy y RayoToy: misma API, mismas
## cinco figuras (BOLA, MURO, PILAR, BARRERA, HAZ), mismos ejes (semieje_x / y / z en m), misma escala (`describir` / `desde_hechizo` son los de FuegoToy) y los mismos mandos (los diez de EfectoToy;
## valen `brillo` (las grietas), `chispas` (la estela de brasas), `luz` y `ancho`; el resto se pasa al FuegoToy de las figuras de volumen). La máquina de carga e impacto está copiada de RayoToy.
## NO ES UNA LLAMA: es ROCA OSCURA SÓLIDA (base tierra) con GRIETAS y CONTORNO que brillan con `calor` 0 → 1 (0 gris apagado, 0,5 rojo, 1 amarillo en las grietas y el borde; aquí el amarillo
## SÍ vale: es calor de grieta, no llama; el fuego del juego lo tiene prohibido). Paleta: Vfx3D.COLOR["magma"] (0,95, 0,40, 0,12) es la luz.
##   BOLA (la principal; `viaja` = proyectil): una esfera facetada de pocos polígonos con relieve (ImpactoMagmaToy.malla_bola; las `piedra_est_magma_*` de Meshy se probaron primero y
##     se leían como una gema piramidal) con magma_roca.gdshader (albedo oscuro de rocas_magma_albedo.png + grietas emisivas de rocas_magma_emisivo.png, el mismo atlas que la costra del suelo). RUEDA de verdad al avanzar (gira sobre el eje ⟂ a su velocidad, ángulo = distancia / radio). Estela de BRASAS pequeñas que se
##     quedan atrás y caen (MultiMesh de SpriteToy con el tramo bajo de la rampa: rojo-naranja, más oscuro que las chispas del fuego) y UNA luz naranja tenue.
##   MURO, PILAR, BARRERA, HAZ (versión sencilla): un FuegoToy hijo del mismo tamaño con la rampa desplazada al rojo oscuro (`escala_rampa` 0,55, `contraste` 1,25) y unas piedras de magma
##     al rojo en la base (sin estela ni luz propia: la del FuegoToy).
## Ciclo de vida de un proyectil (sobre UN SOLO nodo, igual que las hermanas):
##   empezar_carga(duracion, tam_final)  la roca nace PEQUEÑA Y GRIS en la mano y se CALIENTA (calor 0 → 1) mientras crece. Si se sostiene más, respira. NO hace falta `lanzar()`.
##   progreso_carga() -> float           0 → 1 (se queda en 1 al sostener, y tras soltar)
##   soltar(dir)                         ESA MISMA roca (mismo nodo) pasa a proyectil apuntando a `dir`, a calor 1.
##   cancelar_carga()                    se encoge y se apaga en T_CANCELAR s y se libera
##   impactar_en(pos, normal, escala)    ImpactoMagmaToy GOLPE (destello, 6-10 esquirlas con el mismo material cuyo calor baja a 0 en ~1 s, cráter con pétalos de roca y grietas
##                                       que se enfrían a gris en ~2 s); la bola desaparece en seguida
##   rebotar(pos, normal) -> Vector3     unas esquirlas sin cráter; la bola SIGUE; devuelve la dirección reflejada
##   terminar_sin_choque()               el hechizo se agota en el aire: la roca se ENFRÍA A GRIS y CAE al suelo (y unas brasas, ImpactoMagmaToy FIN)
##   finalizar(motivo, pos, normal)      atajo para HechizoVivo._terminar(causa)
## `impactar()` (contrato de EfectoVfx3D) también funciona. `definir`, `describir`, `desde_hechizo` y `preparar` son los de FuegoToy.

enum Figura { BOLA, MURO, PILAR, BARRERA, HAZ }
enum EstadoCarga { NINGUNA, CARGANDO, SOLTANDO, APAGANDO, CANCELANDO }

const SpriteToy = preload("res://presentacion/vfx/toy/sprite_toy.gd")

const REF_BOLA: Vector3 = Vector3(0.4, 0.4, 0.4)
const REF_MURO: Vector3 = Vector3(3.45, 1.5, 0.3)
const REF_PILAR: Vector3 = Vector3(0.5, 4.0, 0.5)
const REF_BARRERA: Vector3 = Vector3(1.5, 1.5, 1.5)
const REF_HAZ: Vector3 = Vector3(1.5, 0.5, 0.15)
const COLOR_GRIETA_MAGMA: Color = Color(0.85, 0.28, 0.06)             ## 7/11: la grieta del suelo del haz de magma tira a naranja, no al negro de la de tierra

const T_SOLTAR: float = 0.14
const T_APAGAR: float = 0.55            ## s en que la roca se enfría a gris al agotarse en el aire (mientras cae)
const T_CANCELAR: float = 0.2
const RESPIRO_HZ: float = 1.4
const T_NACER: float = 0.2
const T_MORIR: float = 0.3
const T_MORIR_BOLA: float = 0.12
const N_BRASAS_VUELO: int = 28
const PERIODO_BRASA: float = 0.04       ## s entre brasa y brasa que deja la bola en vuelo
const LUZ_ENERGIA: float = 0.9          ## la luz de la bola a calor 1 (tenue: la roca no es una llama)
const LUZ_COLOR: Color = Color(0.95, 0.40, 0.12)     ## Vfx3D.COLOR["magma"]
const ESCALA_RAMPA_VOL: float = 0.55    ## las figuras de volumen: FuegoToy con la rampa recortada al rojo oscuro
const CONTRASTE_VOL: float = 1.25
const T_CAIDA_FIN: float = 0.5          ## s que se queda la roca fría en el suelo tras la FIN antes de liberarse

@export_group("Figura y ejes (m)")
@export var figura: Figura = Figura.BOLA: set = _set_figura
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_x: float = 0.4: set = _set_x
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_y: float = 0.4: set = _set_y
@export_range(0.05, 8.0, 0.01, "or_greater") var semieje_z: float = 0.4: set = _set_z
@export var viaja: bool = false: set = _set_viaja
## Calor de la roca: 0 gris apagado, 0,5 rojo, 1 amarillo en las grietas. La carga lo sube de 0 a 1; la FIN lo baja a 0.
@export_range(0.0, 1.0, 0.01) var calor: float = 1.0: set = _set_calor
@export_group("Carga del hechizo")
@export_range(0.03, 0.6, 0.01) var carga_tam_inicial: float = 0.2
@export_range(0.3, 3.0, 0.05) var carga_curva: float = 0.8
@export_range(0, 36, 1) var carga_chispas: int = 28                 ## sin uso en el magma (la carga es la roca calentándose); existe para que los mandos del lab valgan para todos
@export_range(0.0, 3.0, 0.05) var carga_destello: float = 1.0       ## ídem
@export_range(0.0, 0.2, 0.005) var carga_respiro: float = 0.04
@export_range(0.0, 3.0, 0.05) var carga_brillo: float = 1.0         ## ídem
@export_range(0.5, 2.0, 0.05) var carga_radio: float = 1.0          ## ídem
@export var carga_bola_visible: bool = true: set = _set_carga_bola_visible
@export_group("Impacto")
## true: al impactar, en vez del golpe de un proyectil, un cráter grande con más esquirlas (ImpactoMagmaToy.Variante.AREA). `desde_hechizo` lo pone en las zonas.
@export var area_al_impactar: bool = false
@export_group("Mundo")
## Altura (m) del nodo sobre el suelo: la roca que se agota en el aire cae hasta ahí; las brasas que caen por debajo se apagan.
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
var _pop: bool = false
var _roca: MeshInstance3D = null            ## BOLA: la roca
var _mat_roca: ShaderMaterial = null
var _fuego: FuegoToy = null                 ## MURO / PILAR / BARRERA / HAZ: el FuegoToy hijo
var _puas: Node3D = null                    ## HAZ (7/11): el TierraToy hijo que pone las puas, con la roca de magma
var _mat_pua: ShaderMaterial = null         ## el material de magma de esas puas
var _mat_base: ShaderMaterial = null        ## las piedras de la base de las figuras de volumen
var _brasas_mm: MultiMeshInstance3D = null  ## BOLA en vuelo: la estela de brasas (top_level: se quedan en el mundo)
var _brasas: Array = []                     ## [{p (mundo), v, edad, vida, tam}]
var _t_brasa: float = 0.0
var _ult_pos: Vector3 = Vector3.ZERO
var _tiene_ult: bool = false
var _vel_mundo: Vector3 = Vector3.ZERO
var _giro_acum: float = 0.0                 ## radianes rodados (pruebas)
var _v_caida: float = 0.0                   ## FIN: velocidad vertical de la caída
var _en_suelo: float = -1.0                 ## FIN: s que lleva parada en el suelo (< 0: aún cae)
var _y_suelo: float = 0.0                   ## FIN: altura (mundo) a la que se para el centro de la roca
var _calor_fin: float = 1.0                 ## FIN: calor del que parte el enfriado
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_construir()
	super._ready()
	_construido = true
	_set_proyectil(viaja)


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


func _set_viaja(v: bool) -> void:
	viaja = v
	_pedir()


func _set_calor(v: float) -> void:
	calor = clampf(v, 0.0, 1.0)
	_aplicar_calor()


func _aplicar_calor() -> void:
	if _mat_roca != null:
		_mat_roca.set_shader_parameter("calor", calor)
	if _mat_base != null:
		_mat_base.set_shader_parameter("calor", 0.35 + 0.5 * calor)


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


func reconstruir() -> void:
	_pendiente = false
	if not is_inside_tree() or not _construido:
		return
	_listo = false
	_construir()
	proyectil = viaja
	_recoger()
	_set_proyectil(viaja)


func semiejes() -> Vector3:
	return Vector3(semieje_x, semieje_y, semieje_z)


func esta_cargando() -> bool:
	return _est == EstadoCarga.CARGANDO


func progreso_carga() -> float:
	return _c_prog


func escala_carga() -> float:
	return _c_escala


## Radianes que lleva rodados la roca (pruebas).
func giro_rodado() -> float:
	return _giro_acum


## Brasas de la estela vivas ahora (pruebas): [{p (mundo), v, edad, vida, tam}].
func brasas_vuelo() -> Array:
	return _brasas


# ------------------------------------------------------------------ EfectoToy: lo que se recoge y lo que hacen los mandos ------------------------------------------------------------------

## La roca no lleva los shaders del fuego: no se recogen materiales (los mandos de EfectoToy se aplican aquí a mano). El FuegoToy hijo recoge los suyos.
func _recoger() -> void:
	_listo = false
	_cuerpo = get_node_or_null("Cuerpo") as Node3D
	_mats.clear()
	_halos.clear()
	_vuelo_part.clear()
	_luz = get_node_or_null("Luz") as OmniLight3D
	if _luz != null:
		_luz_base = LUZ_ENERGIA
	_listo = true
	_aplicar_todo()


func _aplicar_todo() -> void:
	if not _listo:
		return
	_set_brillo(brillo)
	_set_aparicion(aparicion)
	_aplicar_calor()
	if _fuego != null and is_instance_valid(_fuego):
		for k in ["altura", "chisporroteo", "blandura", "ondulacion", "velocidad", "halo", "tono", "chispas", "luz", "ancho"]:
			_fuego.set(k, get(k))


func _set_brillo(v: float) -> void:
	brillo = v
	if _mat_roca != null:
		_mat_roca.set_shader_parameter("brillo", v)
	if _mat_base != null:
		_mat_base.set_shader_parameter("brillo", v)
	if _fuego != null and is_instance_valid(_fuego):
		_fuego.brillo = v


func _set_aparicion(v: float) -> void:
	aparicion = v
	if not _listo:
		return
	if _fuego != null and is_instance_valid(_fuego):
		_fuego.aparicion = v
	_aplicar_escala_carga()


## El cuerpo escala con `aparicion` (nacer / morir) y con la carga, uniforme: una roca no se aplasta como una llama.
func _aplicar_escala_carga() -> void:
	if _cuerpo != null and figura == Figura.BOLA:
		_cuerpo.scale = Vector3.ONE * maxf(aparicion * _c_escala, 0.001)


func _set_proyectil(v: bool) -> void:
	proyectil = v
	if _brasas_mm != null and not v:
		_brasas.clear()


func _set_carga_bola_visible(v: bool) -> void:
	carga_bola_visible = v
	if _est == EstadoCarga.CARGANDO and _cuerpo != null:
		_cuerpo.visible = v


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
	aparicion = 1.0
	if _ap != null:
		_ap.stop()
	_c_dur = maxf(duracion, 0.05)
	_c_t = 0.0
	_c_prog = 0.0
	_c_escala = carga_tam_inicial
	_est = EstadoCarga.CARGANDO
	_pop = false
	calor = 0.0                                   # nace gris y se calienta
	if _cuerpo != null:
		_cuerpo.visible = carga_bola_visible
	_aplicar_escala_carga()


func soltar(dir: Vector3 = Vector3.ZERO) -> void:
	if dir.length() > 0.001 and is_inside_tree():
		var d: Vector3 = dir.normalized()
		look_at(global_position + d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
	_silencio = true
	viaja = true
	_silencio = false
	proyectil = true
	calor = 1.0
	if _cuerpo != null and not _cuerpo.visible:
		_cuerpo.visible = true
		_pop = true
		_c_desde = 0.5
		_c_escala = 0.5
		_aplicar_escala_carga()
	else:
		_pop = false
		_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.SOLTANDO
	_tiene_ult = false


func cancelar_carga() -> void:
	if _est == EstadoCarga.CANCELANDO:
		return
	_c_desde = _c_escala
	_c_t = 0.0
	_est = EstadoCarga.CANCELANDO


func _escala_de_carga(p: float) -> float:
	var g: float = smoothstep(0.0, 1.0, pow(clampf(p, 0.0, 1.0), carga_curva))
	return lerpf(carga_tam_inicial, 1.0, g)


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
			calor = pow(p, 1.6)                                       # se calienta con la carga: gris casi todo el rato, rojo, y amarillo solo al final
			_aplicar_escala_carga()
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
			calor = _calor_fin * (1.0 - u2)
			_aplicar_escala_carga()
			if u2 >= 1.0:
				_est = EstadoCarga.NINGUNA
				queue_free()
		EstadoCarga.APAGANDO:
			_c_t += delta
			var u3: float = clampf(_c_t / T_APAGAR, 0.0, 1.0)
			calor = _calor_fin * (1.0 - u3)                           # se enfría a gris...
			if _en_suelo < 0.0 and is_inside_tree():
				_v_caida += 9.8 * delta                               # ... mientras cae
				global_position.y -= _v_caida * delta
				_girar_rodando(Vector3(0, -_v_caida * delta, 0) * 0.3)
				if global_position.y <= _y_suelo:
					global_position.y = _y_suelo
					_en_suelo = 0.0
			elif _en_suelo >= 0.0:
				_en_suelo += delta
				if _en_suelo >= T_CAIDA_FIN:
					_est = EstadoCarga.NINGUNA
					queue_free()


func _radio_impacto(escala: float) -> float:
	return escala if escala > 0.0 else maxf(semieje_x, semieje_z)


func _crear_impacto(variante: ImpactoMagmaToy.Variante, normal: Vector3, escala: float, pos: Vector3) -> Node3D:
	var padre: Node = get_parent()
	if padre == null:
		return null
	var imp: ImpactoMagmaToy = ImpactoMagmaToy.crear(variante, normal, _radio_impacto(escala))
	imp.altura_suelo = altura_suelo
	padre.add_child(imp)
	imp.global_position = pos
	return imp


## Explosión de ÁREA de magma (cráter grande con más esquirlas, ImpactoMagmaToy.Variante.AREA) en `pos` (sobre el suelo) con `radio` m de radio. No toca a la bola.
func explotar_area(pos: Vector3, radio: float = -1.0) -> Node3D:
	var r: float = radio if radio > 0.0 else maxf(maxf(semieje_x, semieje_z), 0.3)
	return _crear_impacto(ImpactoMagmaToy.Variante.AREA, Vector3.UP, r, pos)


func impactar_en(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Node3D:
	var imp: Node3D
	if area_al_impactar:
		imp = explotar_area(pos, escala)
	else:
		imp = _crear_impacto(ImpactoMagmaToy.Variante.GOLPE, normal, escala, pos)
	_est = EstadoCarga.NINGUNA
	if _luz != null:
		_luz.visible = false                          # la luz del impacto toma el relevo: nunca hay dos
	morir()                                           # la bola se va en T_MORIR_BOLA s (0,12) mientras saltan las esquirlas; la estela se va con ella
	return imp


func rebotar(pos: Vector3, normal: Vector3 = Vector3.UP, escala: float = -1.0) -> Vector3:
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var d: Vector3 = -global_transform.basis.z if is_inside_tree() else Vector3.FORWARD
	var nd: Vector3 = (d - 2.0 * d.dot(n) * n).normalized()
	_crear_impacto(ImpactoMagmaToy.Variante.REBOTE, n, escala, pos)
	if is_inside_tree():
		global_position = pos
		look_at(pos + nd, Vector3.UP if absf(nd.y) < 0.99 else Vector3.FORWARD)
		_ult_pos = pos
	return nd


func terminar_sin_choque() -> void:
	if _est == EstadoCarga.APAGANDO or _est == EstadoCarga.CANCELANDO:
		return
	_crear_impacto(ImpactoMagmaToy.Variante.FIN, Vector3.UP, -1.0, global_position)
	_calor_fin = calor
	_c_desde = _c_escala
	_c_t = 0.0
	_v_caida = 0.0
	_en_suelo = -1.0
	_y_suelo = (global_position.y if is_inside_tree() else 0.0) - altura_suelo + maxf(semieje_x, semieje_z) * _c_escala * 0.5
	_est = EstadoCarga.APAGANDO


func finalizar(motivo: String, pos: Vector3 = Vector3.INF, normal: Vector3 = Vector3.UP) -> void:
	var p: Vector3 = global_position if pos == Vector3.INF else pos
	match motivo:
		"golpe", "muro", "suelo":
			impactar_en(p, normal)
		"retorno":
			cancelar_carga()
		_:
			terminar_sin_choque()


func impactar() -> void:
	var n: Vector3 = global_transform.basis.z.normalized() if proyectil else Vector3.UP
	if global_position.y < 0.3:
		n = Vector3.UP
	impactar_en(global_position, n)


func preparar(volumen: Dictionary, dir: Vector3, _elemento: String = "magma") -> void:
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
	area_al_impactar = int(d["figura"]) == Figura.BOLA and not bool(d["viaja"])


static func describir(h: Hechizo, casilla_m: float = 2.3) -> Dictionary:
	return FuegoToy.describir(h, casilla_m)


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
	cuerpo.scale = Vector3.ONE
	tam_referencia = Vector3(semieje_x, semieje_y, semieje_z) * 2.0
	_avance_cabeza = 0.0
	_roca = null
	_mat_roca = null
	_fuego = null
	_mat_base = null
	var luz_nodo: OmniLight3D = get_node_or_null("Luz") as OmniLight3D
	if figura == Figura.BOLA:
		_bola(cuerpo)
		if luz_nodo == null:
			luz_nodo = OmniLight3D.new()
			luz_nodo.name = "Luz"
			luz_nodo.light_color = LUZ_COLOR
			luz_nodo.omni_attenuation = 1.4
			luz_nodo.shadow_enabled = false
			add_child(luz_nodo)
		luz_nodo.visible = true
		luz_nodo.light_energy = LUZ_ENERGIA
		luz_nodo.omni_range = clampf(2.4 + 2.0 * extension(), 2.0, 6.0)
	else:
		if luz_nodo != null:
			luz_nodo.queue_free()                    # la luz la pone el FuegoToy hijo
		_volumen(cuerpo)
	_montar_brasas()
	_anim_si_hace_falta()


## BOLA: la roca (la esfera facetada de ImpactoMagmaToy.malla_bola, centrada y escalada al diámetro 2·r) con magma_roca.gdshader.
func _bola(c: Node3D) -> void:
	var r: float = maxf(semieje_x, semieje_z)
	var m: Mesh = ImpactoMagmaToy.malla_bola()
	var aabb: AABB = m.get_aabb()
	var lado: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var k: float = 2.0 * r / maxf(lado, 0.001)
	_roca = MeshInstance3D.new()
	_roca.name = "Roca"
	_roca.mesh = m
	_mat_roca = ImpactoMagmaToy.material_roca(false)
	_mat_roca.set_shader_parameter("calor", calor)
	_mat_roca.set_shader_parameter("brillo", brillo)
	_roca.material_override = _mat_roca
	_roca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pivote: Node3D = Node3D.new()                  # el pivote gira (rueda); la malla, con la base en el origen, va centrada dentro
	pivote.name = "Giro"
	c.add_child(pivote)
	pivote.add_child(_roca)
	var sc: Vector3 = Vector3(k, k * semieje_y / r, k)
	_roca.position = -aabb.get_center() * sc
	_roca.scale = sc


## MURO / PILAR / BARRERA / HAZ: FuegoToy del mismo tamaño con la rampa al rojo oscuro y piedras de magma al rojo en la base.
func _volumen(c: Node3D) -> void:
	_fuego = FuegoToy.new()
	_fuego.name = "Fuego"
	_fuego.definir(int(figura) as FuegoToy.Figura, semieje_x, semieje_y, semieje_z, false)
	_fuego.aparicion = aparicion
	c.add_child(_fuego)
	_fuego._param_mats("escala_rampa", ESCALA_RAMPA_VOL)
	_fuego._param_mats("contraste", CONTRASTE_VOL)
	_mat_base = ImpactoMagmaToy.material_roca(false)
	_mat_base.set_shader_parameter("calor", 0.35 + 0.5 * calor)
	var sitios: Array = []                          # [[pos, tam]]
	var tam: float = clampf(minf(semieje_x, semieje_z) * 0.55, 0.12, 0.5)
	match figura:
		Figura.MURO:
			var n: int = clampi(int(round(semieje_x * 1.6)), 3, 10)
			for i in n:
				var x: float = lerpf(-semieje_x * 0.9, semieje_x * 0.9, (float(i) + 0.5) / float(n))
				sitios.append([Vector3(x, 0.0, _rng.randf_range(-semieje_z, semieje_z) * 0.6), clampf(semieje_z * 0.9, 0.12, 0.45) * _rng.randf_range(0.8, 1.2)])
		Figura.PILAR, Figura.BARRERA:
			var n2: int = 5 if figura == Figura.PILAR else 7
			for i in n2:
				var a: float = TAU * float(i) / float(n2) + _rng.randf_range(-0.3, 0.3)
				var kx: float = semieje_x * (1.05 if figura == Figura.PILAR else 0.95)
				var kz: float = semieje_z * (1.05 if figura == Figura.PILAR else 0.95)
				sitios.append([Vector3(cos(a) * kx, 0.0, sin(a) * kz), tam * _rng.randf_range(0.8, 1.2)])
		Figura.HAZ:
			_puas_igneas(c)                          # 7/11 (Pablo: «magma puede ser algo parecido a tierra pero con sus púas más ígneas y transmitiendo calor»)
	for j in sitios.size():
		var s: Array = sitios[j]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Piedra%d" % j
		mi.mesh = ImpactoMagmaToy.malla_piedra(_rng.randi_range(0, 4))
		mi.material_override = _mat_base
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lado: float = maxf(ImpactoMagmaToy.lado_malla(mi.mesh), 0.001)
		var k: float = float(s[1]) / lado
		mi.scale = Vector3(k, k, k)
		mi.position = (s[0] as Vector3) + Vector3(0, -0.01, 0)
		mi.rotation.y = _rng.randf() * TAU
		c.add_child(mi)


## 7/11/2026 (Pablo: «magma puede ser algo parecido a tierra pero con sus púas más ígneas y transmitiendo calor. Tómalo como referencia»): el HAZ de magma son las MISMAS PÚAS que las de
## tierra —la misma malla, la misma secuencia de brote, el mismo hundirse al revés— pero de ROCA DE MAGMA: casi negra, con las grietas al rojo del `magma_roca.gdshader`. No se duplica la
## máquina: se cuelga un `TierraToy` con la figura HAZ y se le cambia el material de sus MultiMesh de púas y lajas por el de magma. El fuego rojo del `FuegoToy` sigue por encima, que es el
## calor que transmite. Las púas de magma no se manchan de tierra en la base (ahí es donde más calientan) y su grieta del suelo tira a naranja en vez de a negro.
func _puas_igneas(c: Node3D) -> void:
	var t := TierraToy.new()
	t.name = "PuasIgneas"
	t.linea_ignea = true
	t.definir(TierraToy.Figura.HAZ, semieje_x, semieje_y, semieje_z, false)
	t.aparicion = aparicion
	c.add_child(t)
	_puas = t
	_mat_pua = ImpactoMagmaToy.material_roca(false)
	_mat_pua.set_shader_parameter("calor", clampf(0.55 + 0.45 * calor, 0.0, 1.0))
	for n in t.find_children("Bloques*", "MultiMeshInstance3D", true, false):
		(n as MultiMeshInstance3D).material_override = _mat_pua
	var gr: Node = t.find_child("Grietas", true, false)
	if gr != null and (gr as MeshInstance3D).material_override is ShaderMaterial:
		((gr as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("color_grieta", COLOR_GRIETA_MAGMA)


## La estela de brasas (MultiMesh de SpriteToy; el nodo es top_level: las brasas viven en el mundo y la bola se aleja).
func _montar_brasas() -> void:
	if _brasas_mm != null and is_instance_valid(_brasas_mm):
		_brasas_mm.queue_free()
	_brasas_mm = null
	_brasas.clear()
	if figura != Figura.BOLA:
		return
	_brasas_mm = SpriteToy.chispas_mm("Brasas", N_BRASAS_VUELO, 1.3)
	(_brasas_mm.material_override as ShaderMaterial).set_shader_parameter("tramo", Vector2(0.15, 0.55))
	_brasas_mm.top_level = true
	add_child(_brasas_mm)


func _anim_si_hace_falta() -> void:
	var ap: AnimationPlayer = get_node_or_null("Anim") as AnimationPlayer
	if ap != null and _figura_anim == int(figura):
		return
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "Anim"
		add_child(ap)
	_figura_anim = int(figura)
	var morir_s: float = T_MORIR if figura != Figura.BOLA else T_MORIR_BOLA
	var lib: AnimationLibrary = AnimationLibrary.new()
	for nom in ["nacer", "vivir", "morir"]:
		var an: Animation = Animation.new()
		var pista: int = an.add_track(Animation.TYPE_VALUE)
		an.track_set_path(pista, NodePath(".:aparicion"))
		match nom:
			"nacer":
				an.length = T_NACER
				an.track_insert_key(pista, 0.0, 0.0)
				an.track_insert_key(pista, T_NACER, 1.0)
			"vivir":
				an.length = 1.0
				an.loop_mode = Animation.LOOP_LINEAR
				an.track_insert_key(pista, 0.0, 1.0)
			"morir":
				an.length = morir_s
				an.track_insert_key(pista, 0.0, 1.0)
				an.track_insert_key(pista, morir_s, 0.0)
		an.track_set_interpolation_type(pista, Animation.INTERPOLATION_LINEAR)
		lib.add_animation(nom, an)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	dura_morir = morir_s


# ------------------------------------------------------------------ vuelo: rodar y brasas ------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_avanzar_carga(delta)
	if delta > 0.0 and is_inside_tree():
		if _tiene_ult:
			var d: Vector3 = global_position - _ult_pos
			if d.length() < 1.5:                                       # un salto grande es un rebote o una recolocación: no rueda
				_vel_mundo = d / delta
				if proyectil and _est != EstadoCarga.APAGANDO:
					_girar_rodando(d)
		_ult_pos = global_position
		_tiene_ult = true
	_avanzar_brasas(delta)
	if _luz != null and _listo and figura == Figura.BOLA:
		_luz.light_energy *= clampf(calor, 0.0, 1.0)                   # la luz sigue al calor (EfectoToy ya ha puesto energía × luz × titileo)


## Rueda: gira el pivote de la roca sobre el eje ⟂ al desplazamiento `d` (mundo), ángulo = distancia / radio.
func _girar_rodando(d: Vector3) -> void:
	var piv: Node3D = get_node_or_null("Cuerpo/Giro") as Node3D
	if piv == null or d.length() < 0.00001:
		return
	var r: float = maxf(maxf(semieje_x, semieje_z) * _c_escala, 0.02)
	var eje: Vector3 = Vector3.UP.cross(d.normalized())
	if eje.length() < 0.001:
		eje = Vector3.RIGHT
	var ang: float = d.length() / r
	_giro_acum += ang
	piv.global_rotate(eje.normalized(), ang)


## BOLA en vuelo: brasas que salen de la parte de atrás, SE QUEDAN ATRÁS (en coordenadas del mundo) y caen con la gravedad hasta apagarse.
func _avanzar_brasas(delta: float) -> void:
	if _brasas_mm == null or not is_instance_valid(_brasas_mm) or not is_inside_tree():
		return
	var mm: MultiMesh = _brasas_mm.multimesh
	var vuela: bool = proyectil and _est != EstadoCarga.APAGANDO and _est != EstadoCarga.CANCELANDO and aparicion > 0.5
	var r: float = maxf(semieje_x, semieje_z)
	if vuela:
		_t_brasa += delta
		if _t_brasa >= PERIODO_BRASA and _brasas.size() < N_BRASAS_VUELO and chispas > 0.01:
			_t_brasa = 0.0
			var d: Vector3 = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
			var atras: Vector3 = global_transform.basis.z
			_brasas.append({"p": global_position + d * r * 0.6 + atras * r * 0.5, "v": d * _rng.randf_range(0.3, 0.9) + atras * 0.5 + Vector3(0, 0.2, 0),
				"edad": 0.0, "vida": _rng.randf_range(0.35, 0.7), "tam": _rng.randf_range(0.06, 0.12) * clampf(r / 0.4, 0.6, 2.0)})
	var piso: float = global_position.y - altura_suelo
	var vivas: Array = []
	for c in _brasas:
		var s: Dictionary = c
		s["edad"] = float(s["edad"]) + delta
		var v: Vector3 = s["v"]
		v.y -= 6.0 * delta
		s["v"] = v
		s["p"] = (s["p"] as Vector3) + v * delta
		if float(s["edad"]) < float(s["vida"]) and (s["p"] as Vector3).y > piso:
			vivas.append(s)
	_brasas = vivas
	for i in N_BRASAS_VUELO:
		if i < _brasas.size():
			var q: Dictionary = _brasas[i]
			var u: float = float(q["edad"]) / float(q["vida"])
			SpriteToy.poner_chispa(mm, i, q["p"], (q["v"] as Vector3).normalized(), 0.0, float(q["tam"]) * (1.0 - 0.5 * u), 0.85 - 0.8 * u, (1.0 - smoothstep(0.5, 1.0, u)) * clampf(chispas, 0.0, 1.0), true)
		else:
			SpriteToy.poner_chispa(mm, i, Vector3.ZERO, Vector3.UP, 0.0, 0.0, 0.0, 0.0, true)

