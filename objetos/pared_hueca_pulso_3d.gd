class_name ParedHuecaPulso3D
extends Node3D

## PARED HUECA (23/10, FASE 2 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §4, §5 y §10 punto 5): una roca que tapa un paso y SUENA hueca cuando le llega un pulso. Es el REACTIVO del
## pulso. Dos respuestas, a propósito distintas:
##   · cualquier pulso (el del escenario, un cristal, la fuente) le arranca un ECO: un anillo, un destello azul y dos notas graves que se repiten. Es la pista: «aquí detrás hay hueco».
##   · un pulso del JUGADOR (el glifo ᚱ, `Pulso3D.del_jugador`) la ABRE: la roca se agrieta, suelta polvo y se hunde, y la casilla queda libre. Es el primer uso obligatorio del glifo
##     (la salida de la Cueva): no hay pulsador de reserva (decisión de Pablo, §10 punto 5).
## Pone la flag `flag=` al abrirse, y con ella ya puesta al montar nace abierta y sin efecto (partida cargada). Está en el grupo `Pulso3D.GRUPO_PULSABLE`, tiene `celda` y `on_pulso(pulso)`.
## Bloquea su casilla mientras está cerrada. Señales `eco(pulso)` y `abierto`.
##
## RECONOCIBLE SIN REGALAR EL SECRETO (23/10, pedido de Pablo: «se camufla como pared normal»). La cámara del juego mira desde el sur y la pared tapa un paso de un muro norte-sur:
## su cara hacia la sala queda de canto y la del sur la tapa la pared vecina, así que un dibujo sobre la roca no se vería. Por eso el indicio va en el SUELO a su pie: unas GRIETAS
## finas (la máscara de la veta, un trozo distinto del de la losa contigua) que salen de debajo de la pared y se apagan sala adentro, con un brillo azul tenue que LATE LENTO
## (`T_LATIDO_GRIETAS`), y una luz azul baja delante de ella que las acompaña. Y un aviso al acercarse a `ALCANCE_AVISO` casillas: las grietas se encienden `T_AVISO` s y suena una
## nota grave («aquí suena hueco»), una vez por acercamiento. No dice qué hacer: solo que esa roca no es como las demás.
##
## Se coloca con `; pieza <id> pared_hueca <x> <y> [flag=<nombre>] [mira=n|e|s|o]` (escenas/puzle.gd). `mira` (24/10): la sala hacia la que mira cuando hay sala a los dos lados.

signal eco(pulso: Pulso3D)
signal abierto

const T_ECO: float = 0.55                 ## s que dura el destello del eco
const T_REPETICION: float = 0.22          ## s entre la nota del eco y su repetición
const TONO_ECO: float = 0.5               ## tono de la nota (grave: suena a hueco)
const TONO_REPETICION: float = 0.42
const T_ABRIR: float = 1.1                ## s que tarda en hundirse
const HUNDIR_Y: float = 1.9               ## u que baja al abrirse (más que su altura: queda bajo el suelo)
const TEMBLOR_ABRIR: float = 0.045        ## u de temblor mientras se agrieta
const ESCALA_MODELO: float = 3.1          ## el modelo `roca_hueca` mide 0,7 de alto: se escala para cubrir el hueco del paso
const ENERGIA_ECO: float = 1.6
const ALCANCE_LUZ: float = 4.5
const ALTO_LUZ: float = 0.7
const ADELANTE_LUZ: float = 0.9           ## casillas hacia la sala a las que cuelga la luz azul (delante de la pared, no dentro de la roca)
## Grietas del suelo (el indicio) y su aviso de cercanía.
const RUTA_MASCARA: String = "res://arte/suelo_meshy/veta_mineral_mascara.png"
const TAM_TEX_GRIETAS: float = 4.6        ## u que mide la textura de la veta (la misma de VetaPulso3D)
const DESFASE_GRIETAS: Vector2 = Vector2(0.37, 0.61)   ## trozo de la máscara que se usa (distinto al de la losa de veta contigua)
const LARGO_GRIETAS: float = 1.6          ## casillas que se adentran en la sala desde el pie de la pared
const ANCHO_GRIETAS: float = 1.9          ## casillas de ancho (la pared mide una; las grietas corren un poco por el pie de las vecinas)
const ALTO_GRIETAS: float = 0.05          ## u sobre el suelo
const GANANCIA_GRIETAS: float = 1.6       ## multiplicador del color de las grietas (aditivo)
const T_LATIDO_GRIETAS: float = 4.0       ## s por latido de las grietas en reposo (lento)
const GRIETAS_MIN: float = 0.30           ## brillo (0..1) en lo más bajo del latido
const GRIETAS_MAX: float = 0.70           ## brillo en lo más alto
const LUZ_GRIETAS: float = 0.9            ## energía de la luz azul de la pared en lo más alto del latido (la mitad en lo más bajo)
const ALCANCE_AVISO: float = 2.0          ## casillas a las que avisa al jugador (a 2 casillas justas, de centro a centro, ya avisa)
const MARGEN_AVISO: float = 0.5           ## casillas de margen: el jugador no está nunca justo en el centro de su casilla
const T_AVISO: float = 1.6                ## s que dura el encendido de aviso
const ENFRIAR_AVISO: float = 4.0          ## s mínimos entre dos avisos
const EXTRA_AVISO: float = 0.9            ## brillo que suma el aviso a las grietas
const LUZ_AVISO: float = 0.9              ## energía que suma el aviso a la luz
const TONO_AVISO: float = 0.3             ## nota grave del aviso
const CADA_VIGILAR: float = 0.12          ## s entre dos miradas a dónde está el jugador

const CODIGO_GRIETAS: String = """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;
uniform sampler2D t_mascara : filter_linear_mipmap, repeat_enable;
uniform vec3 color : source_color = vec3(0.62, 0.85, 1.0);
uniform float energia = 0.0;
uniform float tam_tex = 4.6;
uniform vec2 desfase = vec2(0.0);
uniform vec2 sentido = vec2(1.0, 0.0);      // hacia la sala (xz)
uniform vec2 pie = vec2(0.0);               // punto del pie de la pared (xz)
uniform float largo = 3.0;
varying vec2 mundo_xz;
varying vec2 uv_q;

void vertex() {
	mundo_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	uv_q = UV;
}

void fragment() {
	float m = smoothstep(0.15, 0.6, texture(t_mascara, mundo_xz / tam_tex + desfase).r);
	float d = dot(mundo_xz - pie, sentido) / largo;                 // 0 en el pie, 1 al fondo
	float cae = 1.0 - smoothstep(0.0, 1.0, d);                       // se apaga sala adentro
	float lado = smoothstep(0.0, 0.18, uv_q.x) * (1.0 - smoothstep(0.82, 1.0, uv_q.x)) * smoothstep(0.0, 0.18, uv_q.y) * (1.0 - smoothstep(0.82, 1.0, uv_q.y));
	ALBEDO = color * m * cae * lado * energia;
	ALPHA = 1.0;
}
"""
static var _shader_grietas: Shader = null

const _DIRS: Array = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]   ## sur, este, norte, oeste (en (x, z))
const MIRAS: Dictionary = {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "o": Vector2i(-1, 0)}

var celda: Vector2i = Vector2i.ZERO
var flag: String = ""
var mira: String = ""                     ## hacia qué sala mira (n|e|s|o): el lado donde van las grietas y la luz. Vacío = el primer vecino que no es roca (sur, este, norte, oeste)
var abierta: bool = false
var ecos: int = 0                         ## cuántos pulsos le han arrancado un eco (las pruebas)
var destello: float = 0.0
var ultimo_pulso_propio: bool = false     ## ¿el último pulso que la tocó era del jugador? (las pruebas)
var _mundo: Node = null
var _modelo: Node3D = null
var _mat_primitiva: StandardMaterial3D = null
var _luz: OmniLight3D = null
var _grietas: MeshInstance3D = null       ## el suelo agrietado a su pie (el indicio)
var _mat_grietas: ShaderMaterial = null
var _bloqueada: bool = false
var _y0: float = 0.0
var _t_abrir: float = -1.0
var _color: Color = BrilloPulso3D.COLOR_REPOSO
var _t: float = 0.0
var _aviso: float = 0.0                   ## 1 al avisar, baja a 0 en T_AVISO
var _enfriar: float = 0.0
var _vigilar: float = 0.0
var _cerca: bool = false                  ## ¿el jugador está dentro de ALCANCE_AVISO?
var _jug: Node3D = null
var avisos: int = 0                       ## cuántas veces ha avisado (las pruebas)


func preparar(p_celda: Vector2i, p_flag: String = "", mundo: Node = null, p_mira: String = "") -> void:
	celda = p_celda
	flag = p_flag
	_mundo = mundo
	mira = p_mira
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda)) if Terreno3D.hay_mundo() else Terreno3D.centro_de(celda)
	_y0 = position.y


func _ready() -> void:
	add_to_group(Pulso3D.GRUPO_PULSABLE)
	_dibujar()
	if flag != "" and Flags.i().tiene(flag):
		_abrir_ya()                       # partida cargada: ya estaba abierta
	else:
		_bloquear(true)
	set_process(true)


func _exit_tree() -> void:
	_bloquear(false)


func _dibujar() -> void:
	# Es un trozo de la propia pared de la cueva (el kit `cueva_pared`, girado hacia la sala como lo haría la maqueta con un tabique): del lado de C6 solo se distingue por
	# las vetas que llevan hasta él, la luz azul tenue y el eco. (La primera versión usaba `roca_hueca`, 0,7 de alto: se leía como una bola de musgo en la puerta.)
	var n: Node3D = BrilloPulso3D.modelo("cueva_pared", _mundo)
	if n != null:
		n.name = "modelo"
		n.rotation_degrees.y = _giro_hacia_la_sala()
		add_child(n)
		_modelo = n
	else:
		var caja := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(Terreno3D.casilla * 0.95, Terreno3D.casilla * 0.9, Terreno3D.casilla * 0.5)
		caja.mesh = bm
		_mat_primitiva = StandardMaterial3D.new()
		_mat_primitiva.albedo_color = Color(0.36, 0.34, 0.33)
		_mat_primitiva.emission_enabled = true
		_mat_primitiva.emission = BrilloPulso3D.COLOR_REPOSO
		_mat_primitiva.emission_energy_multiplier = 0.0
		caja.material_override = _mat_primitiva
		caja.position = Vector3(0.0, Terreno3D.casilla * 0.45, 0.0)
		add_child(caja)
		_modelo = caja
	var sala: Vector2i = _dir_sala()
	_luz = OmniLight3D.new()
	_luz.light_color = BrilloPulso3D.COLOR_REPOSO
	_luz.omni_range = ALCANCE_LUZ
	_luz.light_energy = 0.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(float(sala.x), 0.0, float(sala.y)) * (Terreno3D.casilla * ADELANTE_LUZ) + Vector3(0.0, ALTO_LUZ, 0.0)
	add_child(_luz)                                  # no gasta cupo de `reservar_luz`: es UNA luz y es la que delata la pared
	_dibujar_grietas(sala)
	_pintar()


## Las grietas del suelo a su pie: un trozo de la máscara de la veta (aditivo azul) que sale de debajo de la pared y se apaga sala adentro.
func _dibujar_grietas(sala: Vector2i) -> void:
	if not Terreno3D.hay_mundo() or not ResourceLoader.exists(RUTA_MASCARA):
		return
	if _shader_grietas == null:
		_shader_grietas = Shader.new()
		_shader_grietas.code = CODIGO_GRIETAS
	var largo: float = Terreno3D.casilla * LARGO_GRIETAS
	var ancho: float = Terreno3D.casilla * ANCHO_GRIETAS
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(largo, ancho) if sala.x != 0 else Vector2(ancho, largo)
	var pie_local := Vector3(float(sala.x), 0.0, float(sala.y)) * (Terreno3D.casilla * 0.5)
	_mat_grietas = ShaderMaterial.new()
	_mat_grietas.shader = _shader_grietas
	_mat_grietas.set_shader_parameter("t_mascara", load(RUTA_MASCARA) as Texture2D)
	_mat_grietas.set_shader_parameter("color", BrilloPulso3D.COLOR_REPOSO)
	_mat_grietas.set_shader_parameter("tam_tex", TAM_TEX_GRIETAS)
	_mat_grietas.set_shader_parameter("desfase", DESFASE_GRIETAS)
	_mat_grietas.set_shader_parameter("sentido", Vector2(float(sala.x), float(sala.y)))
	_mat_grietas.set_shader_parameter("largo", largo)
	_mat_grietas.set_shader_parameter("energia", 0.0)
	_grietas = MeshInstance3D.new()
	_grietas.name = "grietas"
	_grietas.mesh = q
	_grietas.material_override = _mat_grietas
	_grietas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grietas.position = pie_local + Vector3(float(sala.x), 0.0, float(sala.y)) * (largo * 0.5) + Vector3(0.0, ALTO_GRIETAS, 0.0)
	add_child(_grietas)
	_mat_grietas.set_shader_parameter("pie", Vector2(global_position.x + pie_local.x, global_position.z + pie_local.z))


## La dirección (x, z) hacia la sala a la que mira la pared: la primera casilla vecina que no es roca, en el orden sur, este, norte, oeste.
func _dir_sala() -> Vector2i:
	if MIRAS.has(mira):
		return MIRAS[mira] as Vector2i                 # fase 3 (C1): la pared de la salida del secreto tiene sala a los dos lados; `mira=` dice cuál es la que importa
	for d in _DIRS:
		var l: String = Terreno3D.letra_de(celda + (d as Vector2i))
		if l != "#" and l != " ":
			return d as Vector2i
	return _DIRS[0] as Vector2i


## El giro (grados, sobre Y) con que la maqueta pone un `cueva_pared` de tabique: de frente a una de las dos salas.
func _giro_hacia_la_sala() -> float:
	return 90.0 * float(_DIRS.find(_dir_sala()))


## El brillo de las grietas ahora (0..1+): el latido lento de reposo, el aviso de cercanía y el eco del pulso. 0 si la pared ya se abrió.
func brillo_grietas() -> float:
	if abierta:
		return 0.0
	return _latido() + EXTRA_AVISO * _aviso + destello * destello


## El latido lento de reposo (GRIETAS_MIN..GRIETAS_MAX, un ciclo cada T_LATIDO_GRIETAS s).
func _latido() -> float:
	return lerpf(GRIETAS_MIN, GRIETAS_MAX, 0.5 + 0.5 * sin(_t * TAU / T_LATIDO_GRIETAS))


func _bloquear(si: bool) -> void:
	if si and not _bloqueada:
		Terreno3D.bloquear_celda(celda)
		_bloqueada = true
	elif not si and _bloqueada:
		Terreno3D.liberar_celda(celda)
		_bloqueada = false


## El aviso del pulso: SIEMPRE eco; si es del jugador, además abre. Devuelve true si la abrió.
func on_pulso(pulso: Pulso3D) -> bool:
	if pulso == null:
		return false
	ultimo_pulso_propio = pulso.del_jugador
	_eco(pulso)
	if pulso.del_jugador and not abierta:
		abrir()
		return true
	return false


func _eco(pulso: Pulso3D) -> void:
	ecos += 1
	destello = 1.0
	_color = pulso.color
	if is_inside_tree() and Terreno3D.hay_mundo():
		Pulso3D.anillo(self, global_position, pulso.color)
		Sfx.play(self, Pulso3D.SFX_PULSO, TONO_ECO)
		get_tree().create_timer(T_REPETICION, false).timeout.connect(_repetir_eco.bind(weakref(self)))
	_pintar()
	eco.emit(pulso)


static func _repetir_eco(yo_ref: WeakRef) -> void:
	var yo: Variant = yo_ref.get_ref()
	if yo != null and is_instance_valid(yo) and (yo as Node).is_inside_tree():
		Sfx.play(yo as Node, Pulso3D.SFX_PULSO, TONO_REPETICION)


## Se abre (el pulso del jugador, o la acción `abrir` de una regla). false si ya estaba abierta.
func abrir() -> bool:
	if abierta:
		return false
	abierta = true
	_bloquear(false)                       # el paso queda libre ya: el hundimiento es un efecto
	_t_abrir = 0.0
	if is_inside_tree() and Terreno3D.hay_mundo():
		VfxKit3D.oro_motas(self, global_position + Vector3(0.0, Terreno3D.casilla * 0.4, 0.0), 30, 0.9, 0.09, 1.6, false, false, Terreno3D.casilla * 0.4, Vector3.UP, 60.0)
		Sfx.play(self, Pulso3D.SFX_PULSO, 0.38)
	if flag != "" and not Flags.i().tiene(flag):
		Flags.i().poner(flag)
	Puzle3D._logro("puerta_abierta", self)
	abierto.emit()
	return true


func _abrir_ya() -> void:
	abierta = true
	_bloquear(false)
	_t_abrir = T_ABRIR
	position.y = _y0 - HUNDIR_Y
	if _modelo != null:
		visible = false


func _process(delta: float) -> void:
	_t += delta
	if destello > 0.0:
		destello = maxf(destello - delta / T_ECO, 0.0)
	if _aviso > 0.0:
		_aviso = maxf(_aviso - delta / T_AVISO, 0.0)
	_enfriar = maxf(_enfriar - delta, 0.0)
	_vigilar -= delta
	if _vigilar <= 0.0:
		_vigilar = CADA_VIGILAR
		_mirar_jugador()
	_pintar()
	if _t_abrir >= 0.0 and _t_abrir < T_ABRIR:
		_t_abrir = minf(_t_abrir + delta, T_ABRIR)
		var u: float = _t_abrir / T_ABRIR
		var temblor: float = TEMBLOR_ABRIR * (1.0 - u) * sin(_t_abrir * 60.0)
		position.y = _y0 - HUNDIR_Y * smoothstep(0.25, 1.0, u)
		if _modelo != null:
			_modelo.position.x = temblor                                   # se agrieta: tiembla de lado mientras se hunde
		if u >= 1.0:
			visible = false


## ¿Se acerca el jugador? Al entrar en ALCANCE_AVISO casillas (y pasado el enfriamiento) la pared AVISA: grietas encendidas y una nota grave. Una vez por acercamiento.
func _mirar_jugador() -> void:
	if abierta or not is_inside_tree():
		_cerca = false
		return
	if _jug == null or not is_instance_valid(_jug):
		var nodo: Node = get_tree().get_first_node_in_group("spellcaster")       # el Lanzador3D, que guarda al jugador (el mismo camino que usa la secuencia del cofre)
		_jug = (nodo.get("jugador") as Node3D) if nodo != null and nodo.get("jugador") != null else null
	if _jug == null:
		return
	var d: Vector3 = _jug.global_position - global_position
	var cerca: bool = Vector2(d.x, d.z).length() <= Terreno3D.casilla * (ALCANCE_AVISO + MARGEN_AVISO)
	if cerca and not _cerca and _enfriar <= 0.0:
		avisar()
	_cerca = cerca


## El aviso de cercanía (también para las pruebas): enciende las grietas T_AVISO s y suena una nota grave.
func avisar() -> void:
	if abierta:
		return
	avisos += 1
	_aviso = 1.0
	_enfriar = ENFRIAR_AVISO
	if is_inside_tree() and Terreno3D.hay_mundo():
		Sfx.play(self, Pulso3D.SFX_PULSO, TONO_AVISO)


## El aspecto: las grietas del suelo (latido lento + aviso + eco) y la luz azul delante de la pared. El modelo es la roca del kit y no tiene nada que encender; si es de primitivas
## (sin arte importado) el eco también la hace resplandecer.
func _pintar() -> void:
	var e: float = destello * destello
	var b: float = brillo_grietas()
	if _mat_primitiva != null:
		_mat_primitiva.emission = _color
		_mat_primitiva.emission_energy_multiplier = ENERGIA_ECO * e
	if _mat_grietas != null:
		_mat_grietas.set_shader_parameter("energia", b * GANANCIA_GRIETAS)
		_mat_grietas.set_shader_parameter("color", BrilloPulso3D.COLOR_REPOSO.lerp(_color, e))
		_grietas.visible = b > 0.0
	if _luz != null:
		_luz.light_color = BrilloPulso3D.COLOR_REPOSO.lerp(_color, e)
		_luz.light_energy = 0.0 if abierta else LUZ_GRIETAS * _latido() / GRIETAS_MAX + LUZ_AVISO * _aviso + ENERGIA_ECO * e
