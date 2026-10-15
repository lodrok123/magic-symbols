extends Node
class_name AguaMetaballs3D
## CHORROS, CAÍDAS Y SALPICADURAS COMO UN LÍQUIDO CONTINUO (Fase 11.9, 12/10). Lo escribe el Pipeline.
##
## Técnica: metaballs (la de AstroStucky/EasyFluidSim, hecha en 3D). Las gotas son partículas sueltas que se dibujan como manchas
## BORROSAS y aditivas en una capa de render aparte; una SubViewport con la MISMA cámara pinta solo esa capa; y la imagen resultante
## se corta por umbral (densidad > umbral → color del agua, con un borde claro). Donde varias manchas se solapan la suma pasa el
## umbral y se funden en una sola masa; donde se separan, la masa se estira y se rompe en gotas. Un chorro de partículas se lee
## como un chorro de agua, no como puntos.
##
## Por qué así y no mallas ni partículas lisas: es barato (un pase con la mitad de resolución), no hace falta cómputo y mantiene el
## aspecto estilizado del resto del agua (dos tonos y borde claro, sin degradados).
##
## Límite conocido: el resultado se pinta ENCIMA del 3D (no sabe de la profundidad de lo que hay delante), pero DEBAJO de la interfaz (15/10). Vale para chorros
## que se ven enteros desde la cámara del juego; si algo (un árbol, un muro) debería taparlos, quedan delante. El Juego decide dónde usarlo.
##
## Uso:
##   var gotas := AguaMetaballs3D.new(); add_child(gotas); gotas.camara = camara_del_juego
##   var surtidor := gotas.chorro(pos, Vector3(0.3, 1.0, 0.0), 7.0, 70.0)      # sale mientras no se pare
##   gotas.detener(surtidor)
##   gotas.salpicadura(pos_impacto, 28, 4.0)                                    # una vez: la caída al canal, el impacto
## El Juego llama a esto desde el surtidor, el canal y el hechizo de agua; se avisa en el diario.

## Cámara del juego: la capa de gotas se deja de dibujar en ella y la SubViewport la copia cada fotograma.
@export var camara: Camera3D = null
## Resolución de la capa respecto a la pantalla (0,5 = la mitad: barato y el umbral la suaviza).
@export var escala: float = 0.5
## Densidad a partir de la cual hay agua (0-1). Más alto = gotas más pequeñas y chorros más finos.
@export var umbral: float = 0.45
@export var color_agua: Color = Color(0.36, 0.70, 0.90)
@export var color_borde: Color = Color(0.92, 0.98, 1.0)
## Número de la capa de render que usan las gotas (1-20). La cámara del juego no la dibuja.
@export_range(1, 20) var capa_gotas: int = 20
## 15/10 (Pablo: «el agua solo será visible cuando no hay nada en medio»): las gotas pasan a tener OCLUSIÓN. La SubViewport de las gotas dibuja
## también la geometría OPACA del mundo, pero con COPIAS NEGRAS (una malla gemela por cada oclusor, solo en esta capa, 1-20): no aportan
## densidad, solo profundidad, y las gotas, que ahora hacen test de profundidad, quedan tapadas por lo que tengan delante. Falso = como antes (todo encima).
@export var oclusion: bool = true
@export_range(1, 20) var capa_oclusores: int = 19
## Sesgo (u) con el que se adelanta cada gota hacia la cámara en el test de profundidad: sin él, las gotas pegadas a una superficie (el
## suelo del charco, el borde del canal) quedarían medio recortadas por ella.
@export var sesgo_profundidad: float = 0.12

## 11.18: radio por defecto del chorro (u), gotas por u³ de agua, tamaño de la gota respecto al radio y cada cuánto salpica al caer.
const R_CHORRO: float = 0.25
const GOTAS_POR_U3: float = 60.0
const RADIO_GOTA_POR_R: float = 0.6
const SEG_SALPICA: float = 0.35

const CODIGO_PANTALLA: String = """
shader_type canvas_item;
uniform sampler2D densidad : filter_linear, repeat_disable;
uniform float umbral = 0.45;
uniform float ancho_borde = 0.2;
uniform vec3 color_agua : source_color = vec3(0.36, 0.70, 0.90);
uniform vec3 color_borde : source_color = vec3(0.92, 0.98, 1.0);
void fragment() {
	float d = texture(densidad, UV).r;
	if (d < umbral) {
		discard;
	}
	// Dos tonos y un borde claro: el aspecto estilizado del agua, no un degradado.
	float k = smoothstep(umbral, umbral + ancho_borde, d);
	vec3 col = mix(color_borde, color_agua, step(0.5, k));
	// El interior más denso, un poco más hondo.
	col = mix(col, color_agua * 0.82, smoothstep(umbral + 0.35, umbral + 0.6, d) * step(0.5, k));
	COLOR = vec4(col, 1.0);
}
"""

## La mancha de una gota: un cuadrado que mira a la cámara, aditivo, con test de profundidad contra los oclusores (ver `oclusion`).
## Se escribe a mano (y no con StandardMaterial3D billboard) para poder adelantarlo `sesgo` hacia la cámara y para que la niebla no lo toque.
const CODIGO_GOTA: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
uniform sampler2D mancha : source_color, filter_linear, repeat_disable;
uniform float sesgo = 0.12;
void vertex() {
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mv = mv * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	mv[3].z += sesgo;
	MODELVIEW_MATRIX = mv;
}
void fragment() {
	ALBEDO = texture(mancha, UV).rgb;
}
"""

var _vp: SubViewport = null
var _activa: bool = true                 ## la SubViewport se actualiza solo mientras hay emisores (ver `_process`)
var _cam_vp: Camera3D = null
var _capa: CanvasLayer = null
var _rect: TextureRect = null
var _mat_pantalla: ShaderMaterial = null
var _mat_gota: ShaderMaterial = null
var _malla_gota: QuadMesh = null


func _ready() -> void:
	_montar()


func _montar() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = false
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_cam_vp = Camera3D.new()
	_cam_vp.cull_mask = 1 << (capa_gotas - 1)
	if oclusion:
		_cam_vp.cull_mask |= 1 << (capa_oclusores - 1)
	# Fondo negro (densidad 0) y sin nada más: el entorno del juego no debe verse en esta capa.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_cam_vp.environment = env
	_vp.add_child(_cam_vp)
	_capa = CanvasLayer.new()
	# 15/10 (Pablo): «el agua solo será visible cuando no hay nada en medio». Antes estaba en la capa 2, POR ENCIMA de la capa 1 (HUD de
	# depuración) y de todo lo de la interfaz: el chorro se veía a través de los textos. En la capa -1 va sobre el 3D (que siempre se pinta
	# debajo de cualquier capa) y por DEBAJO de toda la interfaz (capas 0 en adelante).
	_capa.layer = -1
	add_child(_capa)
	_rect = TextureRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.texture = _vp.get_texture()
	var sh := Shader.new()
	sh.code = CODIGO_PANTALLA
	_mat_pantalla = ShaderMaterial.new()
	_mat_pantalla.shader = sh
	_rect.material = _mat_pantalla
	_capa.add_child(_rect)
	# La mancha de una gota: blanca en el centro y negra en el borde (se SUMA: el negro no aporta).
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.85, 0.85, 0.85, 1.0), Color(0.0, 0.0, 0.0, 1.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var sh_gota := Shader.new()
	sh_gota.code = CODIGO_GOTA
	_mat_gota = ShaderMaterial.new()
	_mat_gota.shader = sh_gota
	_mat_gota.set_shader_parameter("mancha", gt)
	_mat_gota.set_shader_parameter("sesgo", sesgo_profundidad if oclusion else 0.0)
	_malla_gota = QuadMesh.new()
	_malla_gota.size = Vector2(1.0, 1.0)
	_malla_gota.material = _mat_gota
	_ajustar_camara()
	if oclusion:
		_marcar_existentes(get_tree().root)
		get_tree().node_added.connect(_nodo_nuevo)


## --- Oclusores ---
## Marca con la capa de oclusores toda la geometría OPACA que cuelga de `raiz` (salvo lo que lleve el meta `no_ocluye_agua`) (y de lo que se añada después, ver `_nodo_nuevo`). Es público
## por si el Juego añade geometría con la que quiera tapar el agua y no entra sola.
func marcar_oclusores(raiz: Node) -> void:
	_marcar_existentes(raiz)


func _marcar_existentes(n: Node) -> void:
	_marcar(n)
	for h in n.get_children():
		_marcar_existentes(h)


func _nodo_nuevo(n: Node) -> void:
	# En el momento de `node_added` el nodo aún no tiene su malla ni su material puestos: se mira un fotograma después.
	if n is MeshInstance3D or n is MultiMeshInstance3D:
		_marcar.call_deferred(n)


func _marcar(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	var v := n as GeometryInstance3D
	if v == null or not (n is MeshInstance3D or n is MultiMeshInstance3D):
		return
	if v.layers & (1 << (capa_gotas - 1)) != 0 or v.layers & (1 << (capa_oclusores - 1)) != 0 or n.has_meta("gemelo_oclusor"):
		return
	# Lo que lleva la marca «no_ocluye_agua» (o cuelga de algo que la lleva) no tapa las gotas: la tinaja, de cuyo interior sale el chorro. Con ella,
	# el borde de la boca se comía el arranque del chorro y quedaba un salto entre el agua de dentro y el hilo de fuera (Pablo, 15/10).
	var p: Node = n
	while p != null:
		if p.has_meta("no_ocluye_agua"):
			return
		p = p.get_parent()
	if v.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return
	var m: Mesh = null
	if n is MeshInstance3D:
		m = (n as MeshInstance3D).mesh
	else:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		m = mm.mesh if mm != null else null
	if m == null:
		return
	if v.material_override != null:
		if not _es_opaco(v.material_override):
			return
	else:
		for i in range(m.get_surface_count()):
			var mat: Material = null
			if n is MeshInstance3D:
				mat = (n as MeshInstance3D).get_surface_override_material(i)
			if mat == null:
				mat = m.surface_get_material(i)
			if mat != null and not _es_opaco(mat):
				return
	# La gemela NEGRA: misma malla, colgada de la original (se mueve, se oculta y se borra con ella), solo en la capa de oclusores. Se hace así y no
	# marcando la original porque la SubViewport la dibujaría con su color (y lo sumaría a la densidad: se veía amarillo alrededor de la boca).
	var g: GeometryInstance3D = null
	if n is MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.skin = (n as MeshInstance3D).skin
		mi.skeleton = (n as MeshInstance3D).skeleton
		g = mi
	else:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = (n as MultiMeshInstance3D).multimesh
		g = mmi
	g.material_override = _mat_oclusor()
	g.layers = 1 << (capa_oclusores - 1)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.set_meta("gemelo_oclusor", true)
	n.set_meta("gemelo_oclusor", true)
	n.add_child(g)


var _negro: StandardMaterial3D = null


func _mat_oclusor() -> StandardMaterial3D:
	if _negro == null:
		_negro = StandardMaterial3D.new()
		_negro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_negro.albedo_color = Color(0, 0, 0)
		_negro.disable_fog = true
	return _negro


## ¿Escribe profundidad como un sólido? Un material estándar sin transparencia (el recortado NO: su gemela negra sería un cuadrado entero); un shader propio, si no mezcla (blend_*) ni
## escribe ALPHA. Dudoso = transparente: el agua dibujada, los efectos y los cristales NO deben tapar las gotas.
func _es_opaco(mat: Material) -> bool:
	if mat is BaseMaterial3D:
		var t: int = (mat as BaseMaterial3D).transparency
		return t == BaseMaterial3D.TRANSPARENCY_DISABLED
	if mat is ShaderMaterial:
		var sh: Shader = (mat as ShaderMaterial).shader
		if sh == null:
			return false
		var c: String = sh.code
		return not (c.contains("blend_") or c.contains("ALPHA =") or c.contains("ALPHA=") or c.contains("ALPHA *=") or c.contains("ALPHA*="))
	return false


## Un chorro que sale de `origen` hacia `direccion` con `velocidad` (u/s) y `caudal` (gotas por segundo) hasta `detener()` o `duracion` s.
## `abanico` = apertura en grados; `radio_gota` = tamaño de cada mancha (u). Devuelve el emisor para pararlo.
func chorro(origen: Vector3, direccion: Vector3, velocidad: float = 6.0, caudal: float = 60.0, duracion: float = -1.0,
		abanico: float = 6.0, radio_gota: float = 0.2) -> GPUParticles3D:
	var e: GPUParticles3D = _emisor(origen, direccion, velocidad, abanico, radio_gota)
	e.lifetime = 1.1
	e.amount = maxi(4, int(caudal * e.lifetime))
	e.one_shot = false
	e.explosiveness = 0.0
	e.emitting = true
	if duracion > 0.0:
		get_tree().create_timer(duracion).timeout.connect(detener.bind(e))
	return e


## 13.9 (e): se emite en cada salpicadura (en `pos`, mundo). La maqueta la conecta a `AguaOndas3D.impulso`: una gota que cae levanta una onda.
signal salpico(pos: Vector3)


## Una salpicadura de una vez: `cantidad` gotas que salen en abanico ancho desde `pos` hacia arriba. Se borra sola.
func salpicadura(pos: Vector3, cantidad: int = 24, velocidad: float = 4.0, radio_gota: float = 0.14) -> void:
	salpico.emit(pos)
	var e: GPUParticles3D = _emisor(pos, Vector3.UP, velocidad, 70.0, radio_gota)
	e.lifetime = 0.8
	e.amount = maxi(4, cantidad)
	e.one_shot = true
	e.explosiveness = 0.95
	e.emitting = true
	get_tree().create_timer(e.lifetime + 0.4).timeout.connect(e.queue_free)


## 11.18 (12/10) · CHORRO CON FÍSICA: sale HORIZONTAL de `origen` hacia `dir_horizontal`, cae con la gravedad de la simulación y toca el suelo
## `x` u más allá y `y` u más abajo. Misma cuenta que el chorro de la simulación (11.17): tiempo de caída t = √(2·y/G), velocidad de salida
## v = x/t, caudal Q = π·r²·v (u³/s). Las gotas por segundo son proporcionales al caudal (GOTAS_POR_U3) y su tamaño al radio `r`, así que
## un chorro más largo o más grueso se ve más lleno. `duracion` ≤ 0: hasta `detener()`.
## `caudal` > 0 manda sobre el calculado (la tinaja: su boca es fija y el agua que echa la fija el Surtidor, no la geometría).
## `salpica`: una salpicadura donde cae, cada SEG_SALPICA s.
## Devuelve el emisor (para `detener`); el punto de caída queda en su meta «caida» y el caudal usado en «caudal».
func chorro_fisico(origen: Vector3, dir_horizontal: Vector3, x: float, y: float, r: float = R_CHORRO, duracion: float = -1.0,
		caudal: float = -1.0, salpica: bool = true) -> GPUParticles3D:
	var c: Dictionary = calcular_chorro(x, y, r)
	var d := Vector3(dir_horizontal.x, 0.0, dir_horizontal.z)
	d = d.normalized() if d.length() > 0.001 else Vector3.FORWARD
	var q: float = caudal if caudal > 0.0 else float(c["caudal"])
	var e: GPUParticles3D = _emisor(origen, d, float(c["velocidad"]), 1.5, maxf(r * RADIO_GOTA_POR_R, 0.05))
	var pm := e.process_material as ParticleProcessMaterial
	pm.gravity = Vector3(0.0, -AguaSim3D.G, 0.0)
	e.lifetime = maxf(float(c["tiempo"]), 0.1)                      # la gota vive justo lo que tarda en caer: desaparece al tocar el suelo
	e.amount = clampi(int(q * GOTAS_POR_U3 * e.lifetime), 4, 400)
	e.one_shot = false
	e.explosiveness = 0.0
	e.emitting = true
	var caida: Vector3 = origen + d * x - Vector3(0.0, y, 0.0)
	e.set_meta("caida", caida)
	e.set_meta("caudal", q)
	if duracion > 0.0:
		get_tree().create_timer(duracion).timeout.connect(detener.bind(e))
	if salpica:
		_salpicar_mientras(e, caida, q)
	return e


## Cuenta de 11.17 en local (por si la simulación aún no la ofrece): {velocidad, tiempo, caudal} de un chorro horizontal que cae `y` u
## y llega `x` u más allá, de radio `r`.
static func calcular_chorro(x: float, y: float, r: float = R_CHORRO) -> Dictionary:
	var t: float = sqrt(2.0 * maxf(y, 0.01) / AguaSim3D.G)
	var v: float = maxf(x, 0.0) / t
	return {"velocidad": v, "tiempo": t, "caudal": PI * r * r * v}


func _salpicar_mientras(e: GPUParticles3D, caida: Vector3, caudal: float) -> void:
	if e == null or not is_instance_valid(e) or not e.emitting or not is_inside_tree():
		return
	salpicadura(caida, clampi(int(6.0 + caudal * 5.0), 6, 30), 2.5 + minf(caudal, 4.0) * 0.4)
	get_tree().create_timer(SEG_SALPICA).timeout.connect(_salpicar_mientras.bind(e, caida, caudal))


## Deja de echar gotas; las que ya salieron terminan su caída y el emisor se borra solo.
func detener(emisor: GPUParticles3D) -> void:
	if emisor == null or not is_instance_valid(emisor):
		return
	emisor.emitting = false
	get_tree().create_timer(emisor.lifetime + 0.2).timeout.connect(emisor.queue_free)


func _emisor(origen: Vector3, direccion: Vector3, velocidad: float, abanico: float, radio_gota: float) -> GPUParticles3D:
	var e := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = direccion.normalized()
	pm.spread = abanico
	pm.initial_velocity_min = velocidad * 0.85
	pm.initial_velocity_max = velocidad * 1.15
	pm.gravity = Vector3(0.0, -9.8, 0.0)
	pm.scale_min = 0.8
	pm.scale_max = 1.25
	e.process_material = pm
	e.local_coords = false
	e.layers = 1 << (capa_gotas - 1)
	e.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# El tamaño de la mancha va en la escala del emisor (la malla es de 1 × 1).
	e.draw_pass_1 = _malla_de_tamano(radio_gota * 2.0)
	add_child(e)
	e.global_position = origen
	return e


func _malla_de_tamano(lado: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(lado, lado)
	q.material = _mat_gota
	return q


func _process(_delta: float) -> void:
	_ajustar_camara()
	# Con oclusores la SubViewport dibuja la escena otra vez: solo cuando hay gotas (un emisor vivo). Sin ellas no cuesta nada.
	var hay: bool = false
	for h in get_children():
		if h is GPUParticles3D:
			hay = true
			break
	if hay != _activa:
		_activa = hay
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if hay else SubViewport.UPDATE_DISABLED
		_capa.visible = hay


## La cámara de la capa copia a la del juego (transformación, proyección, tamaño) y la del juego deja de dibujar la capa de gotas.
func _ajustar_camara() -> void:
	if _vp == null or _cam_vp == null:
		return
	_mat_pantalla.set_shader_parameter("densidad", _vp.get_texture())
	_mat_pantalla.set_shader_parameter("umbral", umbral)
	_mat_pantalla.set_shader_parameter("color_agua", Vector3(color_agua.r, color_agua.g, color_agua.b))
	_mat_pantalla.set_shader_parameter("color_borde", Vector3(color_borde.r, color_borde.g, color_borde.b))
	if camara == null or not is_instance_valid(camara):
		return
	camara.cull_mask &= ~(1 << (capa_gotas - 1))
	camara.cull_mask &= ~(1 << (capa_oclusores - 1))      # las gemelas negras solo existen para la SubViewport
	var tam: Vector2 = camara.get_viewport().get_visible_rect().size
	var t := Vector2i(maxi(2, int(tam.x * escala)), maxi(2, int(tam.y * escala)))
	if _vp.size != t:
		_vp.size = t
	_cam_vp.global_transform = camara.global_transform
	_cam_vp.projection = camara.projection
	_cam_vp.near = camara.near
	_cam_vp.far = camara.far
	_cam_vp.keep_aspect = camara.keep_aspect
	_cam_vp.h_offset = camara.h_offset
	_cam_vp.v_offset = camara.v_offset
	if camara.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_cam_vp.size = camara.size
	elif camara.projection == Camera3D.PROJECTION_PERSPECTIVE:
		_cam_vp.fov = camara.fov
	else:
		_cam_vp.size = camara.size
		_cam_vp.frustum_offset = camara.frustum_offset
