class_name AvisoAtaque3D
extends Node3D

## C3 · ATAQUES AVISADOS (docs/PROPUESTA_COMBATE.md §2 y §7; 28/10). Dueño: Juego.
##
## La zona roja en el suelo que un enemigo marca ANTES de su golpe, como los avisos de un MOBA: el borde se ve entero desde el principio y el relleno crece desde el centro
## (o desde el enemigo, en el rectángulo) hasta llenarla justo en el instante del impacto. En los últimos `VENTANA_ESQUIVA` s el borde se pone blanco y late: es la ventana
## de la esquiva con premio (C4, `TiempoBruja`).
##
## Lo crea quien ataca (`Combate3D._avisar_ataque`, `Limo3D`) con la MISMA forma y el mismo centro con que luego comprueba el daño, y el mismo tiempo hasta el golpe; así
## «lo que se ve es lo que pega». Formas:
##   · `circulo(mundo, centro, radio, t_impacto, dueno)`            el guerrero (alrededor de él), la flecha (donde va a caer), el limo (donde va a aterrizar)
##   · `rectangulo(mundo, origen, dir, largo, ancho, t_impacto, dueno)`   el puñetazo del elemental (desde él hacia delante; `ancho` = la mitad a cada lado)
## `seguir(nodo)`: el centro va con ese nodo hasta `fijar(punto, t_restante)` (la flecha: apunta a la jugadora mientras tensa y se queda donde la suelta).
## El reloj es el del juego (delta con `Engine.time_scale`): en cámara lenta el aviso también va lento.
## Se borra solo al llegar el impacto (con un destello corto) o con `cancelar()` (el enemigo interrumpido, congelado, empujado…).
## Todos los vivos están en el grupo GRUPO: `esquiva_a_tiempo(p)` (C4) los recorre.

const GRUPO: String = "aviso_ataque3d"
const T_MIN: float = 0.4                     ## s mínimos entre que sale el aviso y el golpe (el contrato de C3: si el ataque es más rápido, lo alarga quien ataca)
const VENTANA_ESQUIVA: float = 0.25          ## s antes del impacto en que rodar da premio (C4; la propuesta dice «~0,2 s»: 0,25 con el redondeo de los fotogramas)
const T_DESTELLO: float = 0.12               ## s que se ve el destello del impacto antes de borrarse
const ALTO_SUELO: float = 0.06               ## u sobre los pies, para no pelearse con el suelo
const COLOR: Color = Color(1.0, 0.22, 0.16)
const COLOR_VENTANA: Color = Color(1.0, 0.95, 0.85)

const CODIGO: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.22, 0.16, 1.0);
uniform vec4 color_borde : source_color = vec4(1.0, 0.22, 0.16, 1.0);
uniform float progreso = 0.0;      // 0 al salir ... 1 en el impacto
uniform float circulo = 1.0;       // 1 círculo (UV centrado) · 0 rectángulo (relleno desde v = 0, el lado del enemigo)
uniform float borde = 0.08;        // grosor del borde en UV (0..0.5)
uniform float destello = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float dentro;
	float b;
	float lleno;
	if (circulo > 0.5) {
		float r = length(q);
		dentro = step(r, 1.0);
		b = smoothstep(1.0 - borde * 2.0 - 0.02, 1.0 - borde * 2.0, r);
		lleno = step(r, progreso);
	} else {
		float m = max(abs(q.x), abs(q.y));
		dentro = 1.0;
		b = smoothstep(1.0 - borde * 2.0 - 0.02, 1.0 - borde * 2.0, m);
		lleno = step(UV.y, progreso);
	}
	float a = dentro * max(b * 0.95, 0.16 + lleno * 0.34);
	vec3 c = mix(color.rgb, color_borde.rgb, b);
	c = mix(c, vec3(1.0), destello);
	ALBEDO = c;
	ALPHA = a * color.a * (1.0 - destello * 0.3);
}
"""

static var _shader: Shader = null

var dueno: Node = null
var forma: String = "circulo"
var radio: float = 1.0                       ## círculo: radio (u)
var largo: float = 1.0                       ## rectángulo: hasta dónde llega por delante del origen (u)
var ancho: float = 0.5                       ## rectángulo: la mitad del ancho (u)
var atras: float = 0.0                       ## rectángulo: lo que cubre por detrás del origen (u)
var dir: Vector3 = Vector3(0, 0, 1)
var centro: Vector3 = Vector3.ZERO           ## círculo: su centro; rectángulo: el origen (los pies del enemigo)
var t_impacto: float = 0.0                   ## s de juego desde que salió hasta el golpe
var t: float = 0.0
var cancelado: bool = false
var esquivado: bool = false                  ## ya dio su premio de esquiva (una vez por aviso)
var _sigue: Node3D = null
var _malla: MeshInstance3D = null
var _mat: ShaderMaterial = null


static func circulo(en: Node, p_centro: Vector3, p_radio: float, p_t: float, p_dueno: Node = null) -> AvisoAtaque3D:
	var a := AvisoAtaque3D.new()
	a.forma = "circulo"
	a.centro = p_centro
	a.radio = p_radio
	a.t_impacto = maxf(p_t, 0.01)
	a.dueno = p_dueno
	a._colgar(en)
	return a


static func rectangulo(en: Node, origen: Vector3, p_dir: Vector3, p_largo: float, p_ancho: float, p_t: float, p_dueno: Node = null, p_atras: float = 0.3) -> AvisoAtaque3D:
	var a := AvisoAtaque3D.new()
	a.forma = "rect"
	a.centro = origen
	var d := Vector3(p_dir.x, 0.0, p_dir.z)
	a.dir = d.normalized() if d.length() > 0.001 else Vector3(0, 0, 1)
	a.largo = p_largo
	a.ancho = p_ancho
	a.atras = p_atras
	a.t_impacto = maxf(p_t, 0.01)
	a.dueno = p_dueno
	a._colgar(en)
	return a


## ¿Hay algún aviso vivo que cubre `p` y al que le quedan `ventana` s o menos para el golpe? Si lo hay, lo marca como esquivado (da premio una vez) y lo devuelve; si no, null.
static func esquiva_a_tiempo(arbol: SceneTree, p: Vector3, ventana: float = VENTANA_ESQUIVA) -> AvisoAtaque3D:
	if arbol == null:
		return null
	for n in arbol.get_nodes_in_group(GRUPO):
		var a: AvisoAtaque3D = n as AvisoAtaque3D
		if a == null or not is_instance_valid(a) or a.cancelado or a.esquivado or a.t >= a.t_impacto:
			continue
		if a.queda() <= ventana and a.contiene(p):
			a.esquivado = true
			return a
	return null


func _colgar(en: Node) -> void:
	add_to_group(GRUPO)
	if en != null:
		en.add_child(self)
	_construir()
	_colocar()


func _construir() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODIGO
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.render_priority = 2
	_mat.set_shader_parameter("color", COLOR)
	_mat.set_shader_parameter("color_borde", COLOR)
	_mat.set_shader_parameter("circulo", 1.0 if forma == "circulo" else 0.0)
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	_malla = MeshInstance3D.new()
	_malla.mesh = pm
	_malla.material_override = _mat
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_malla)


## Pone la malla en su sitio y con su tamaño (cada fotograma si sigue a alguien).
func _colocar() -> void:
	if _malla == null:
		return
	if forma == "circulo":
		_malla.scale = Vector3(radio * 2.0, 1.0, radio * 2.0)
		_malla.rotation = Vector3.ZERO
		_poner_en(centro)
		_mat.set_shader_parameter("borde", clampf(0.06 / maxf(radio, 0.1), 0.02, 0.2))
	else:
		var total: float = largo + atras
		var medio: Vector3 = centro + dir * (largo - atras) * 0.5
		_poner_en(medio)
		# La malla mira con su +Z (la v del UV crece hacia +Z) al revés de `dir`: v = 0 queda del lado del enemigo y el relleno crece hacia delante.
		_malla.rotation = Vector3(0.0, atan2(-dir.x, -dir.z), 0.0)
		_malla.scale = Vector3(ancho * 2.0, 1.0, total)
		_mat.set_shader_parameter("borde", clampf(0.06 / maxf(minf(ancho, total * 0.5), 0.1), 0.02, 0.2))


func _poner_en(p: Vector3) -> void:
	var y: float = p.y
	var c: Vector2i = Terreno3D.celda_de(p)
	if Terreno3D.en_mapa(c):
		y = Terreno3D.y_pies(c)
	var q := Vector3(p.x, y + ALTO_SUELO, p.z)
	if is_inside_tree():
		global_position = q
	else:
		position = q


## El centro va con `nodo` (sus pies) hasta `fijar`.
func seguir(nodo: Node3D) -> void:
	_sigue = nodo


## Deja de seguir: el golpe caerá en `p`, dentro de `t_restante` s (≥ 0: si es menor que lo que quedaba, el aviso se acorta; nunca baja de lo que ya pasó).
func fijar(p: Vector3, t_restante: float = -1.0) -> void:
	_sigue = null
	centro = p
	if t_restante >= 0.0:
		t_impacto = t + t_restante
	_colocar()


## s de juego que faltan para el golpe (0 = ya).
func queda() -> float:
	return maxf(0.0, t_impacto - t)


## ¿Cubre `p` (en el plano; la altura no cuenta)? Es la MISMA zona que daña: el atacante comprueba el golpe con su propia regla, pero debe coincidir con esto.
func contiene(p: Vector3) -> bool:
	var d := Vector3(p.x - centro.x, 0.0, p.z - centro.z)
	if forma == "circulo":
		return d.length() <= radio
	var delante: float = d.dot(dir)
	var lado: float = absf(d.dot(Vector3(-dir.z, 0.0, dir.x)))
	return delante >= -atras and delante <= largo and lado <= ancho


## Las casillas que toca (las que tienen su centro dentro): para las pruebas («cubre las casillas que daña»).
func casillas() -> Array:
	var r: Array = []
	var ext: float = radio if forma == "circulo" else largo + atras + ancho
	var c0: Vector2i = Terreno3D.celda_de(centro)
	var n: int = int(ceil(ext / Terreno3D.casilla)) + 1
	for y in range(c0.y - n, c0.y + n + 1):
		for x in range(c0.x - n, c0.x + n + 1):
			var c := Vector2i(x, y)
			if contiene(Terreno3D.centro_de(c)):
				r.append(c)
	return r


func cancelar() -> void:
	if cancelado:
		return
	cancelado = true
	remove_from_group(GRUPO)
	queue_free()


func _process(delta: float) -> void:
	if cancelado:
		return
	if dueno != null and not is_instance_valid(dueno):
		cancelar()
		return
	t += delta
	if _sigue != null and is_instance_valid(_sigue):
		centro = _sigue.global_position
		_colocar()
	var k: float = clampf(t / t_impacto, 0.0, 1.0)
	_mat.set_shader_parameter("progreso", k)
	var en_ventana: bool = queda() <= VENTANA_ESQUIVA
	var borde: Color = COLOR
	if en_ventana:
		borde = COLOR.lerp(COLOR_VENTANA, 0.6 + 0.4 * sin(t * 40.0))
	_mat.set_shader_parameter("color_borde", borde)
	if t >= t_impacto:
		remove_from_group(GRUPO)
		var f: float = clampf((t - t_impacto) / T_DESTELLO, 0.0, 1.0)
		_mat.set_shader_parameter("destello", 1.0 - f)
		if f >= 1.0:
			queue_free()
