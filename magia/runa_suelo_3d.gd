class_name RunaSuelo3D
extends Node3D

## LA RUNA EN EL SUELO DEL CHAMÁN (28/10; Pablo: «un ROMBO, el gesto de la barrera, dentro de su sello circular; que se vea dibujarse siguiendo la punta del bastón»).
## Un sello circular y, dentro, el rombo, como líneas de luz verde (naturaleza): emisivas, aditivas y sin sombras. NACEN DE LA PUNTA REAL del bastón: `punta_mundo(p, baja)` (cada fotograma, con
## la posición de la punta ya con la pose del fotograma) añade un punto al trazo en curso mientras la punta toca el suelo, y la línea llega exactamente hasta ella, sin desfase. El chamán gira en el sitio
## con la punta fuera (ChamanRitual + AnimacionesChaman.yaw_en), así que el sello queda centrado en sus pies y mide lo que alcanza el bastón (`radio_trazo`, ~0,55 u).
## Al CLAVAR (`activar`) el dibujo se AMPLÍA hasta el tamaño del sello de efecto (`radio`, 2 casillas de DIÁMETRO por defecto) a la vez que sale la onda verde: se ve que el sello pequeño se convierte en el
## efecto. `cancelar()`: se rompe y se apaga en rojo-gris. `progreso(u)` solo apunta qué fracción del ritual va (para `completa()`).
## Señales `activada`, `cancelada`, `onda_avanza(radio)` (cada fotograma de la onda: quien reparte escudos mira a los aliados dentro de ese radio).
## El nodo está en el centro del sello, sin giro: los puntos se guardan en coordenadas de mundo relativas a él.

signal activada
signal cancelada
signal onda_avanza(radio: float)

const VERDE: Color = Color(0.35, 1.0, 0.45)
const ROJO_GRIS: Color = Color(0.7, 0.3, 0.28)
const ONDA_CASILLAS: float = 3.0               ## radio máximo de la onda (casillas)
const T_ONDA: float = 0.8                      ## s que tarda la onda en llegar a su radio máximo
const T_EXPANDE: float = 0.55                  ## s que tarda el dibujo en crecer hasta el sello grande
const T_FLASH: float = 0.18
const T_DESVANECE: float = 0.7                 ## s que tardan en apagarse las líneas, a partir de que acaban de crecer
const T_ROMPE: float = 0.7                     ## s de la cancelación
const ALTO_SUELO: float = 0.05                 ## u sobre el suelo
const ANCHO: float = 0.07                      ## u, grosor de la línea al dibujar (se lee desde la cámara del juego)
const ANCHO_GRANDE: float = 0.16               ## u, grosor cuando ya es el sello grande
const BRILLO: float = 1.8
const PASO_MIN: float = 0.012                  ## u: distancia mínima entre dos puntos del trazo

var radio: float = 2.3                         ## radio del sello grande (u)
var radio_trazo: float = 0.55                  ## radio del sello que dibuja la punta (u)
var color: Color = VERDE
var u_dibujado: float = 0.0                    ## fracción del ritual (0..1) que lleva
var estado: String = "dibujando"               ## dibujando · activa · cancelada
var radio_onda: float = 0.0
var t_estado: float = 0.0
var escala_dibujo: float = 1.0                 ## 1 al dibujar; sube hasta radio / radio_trazo al activar
var punta: Vector3 = Vector3.ZERO              ## la punta (mundo)
var punta_baja: bool = false
var trazos: Array = []                         ## [PackedVector3Array en coordenadas relativas al centro] (los trazos dibujados por la punta)
var _abierto: bool = false                     ## ¿se está dibujando un trazo (la punta toca)?

var _malla: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _chispas: CPUParticles3D = null
var _onda: MeshInstance3D = null
var _onda_mat: StandardMaterial3D = null
var _flash: MeshInstance3D = null
var _luz: OmniLight3D = null
var _t: float = 0.0


## Crea la runa colgada de `en`, centrada en `centro` (mundo). `p_radio_trazo` = el radio del sello que dibuja la punta (u).
static func crear(en: Node, p_centro: Vector3, _p_yaw: float = 0.0, p_radio: float = -1.0, p_radio_trazo: float = 0.55, p_color: Color = VERDE) -> RunaSuelo3D:
	var r := RunaSuelo3D.new()
	r.name = "RunaSuelo"
	en.add_child(r)
	r.radio_trazo = p_radio_trazo
	r.empezar(p_centro, p_radio if p_radio > 0.0 else Terreno3D.casilla, p_color)
	return r


func empezar(p_centro: Vector3, p_radio: float, p_color: Color) -> void:
	global_position = p_centro
	radio = p_radio
	color = p_color
	estado = "dibujando"
	u_dibujado = 0.0
	t_estado = 0.0
	escala_dibujo = 1.0
	trazos.clear()
	_abierto = false
	_construir()


func _construir() -> void:
	if _malla != null:
		return
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_malla = MeshInstance3D.new()
	_malla.name = "Lineas"
	_malla.material_override = _mat
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_malla)
	_chispas = CPUParticles3D.new()
	_chispas.name = "Chispas"
	_chispas.emitting = false
	_chispas.amount = 30
	_chispas.lifetime = 0.5
	_chispas.direction = Vector3.UP
	_chispas.spread = 60.0
	_chispas.initial_velocity_min = 0.12
	_chispas.initial_velocity_max = 0.35
	_chispas.gravity = Vector3(0, -0.4, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cm.albedo_color = Color(color.r, color.g, color.b, 0.9)
	q.material = cm
	_chispas.mesh = q
	_chispas.top_level = true
	_chispas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_chispas)


## Apunta qué fracción (0..1) del ritual de trazo va.
func progreso(u: float) -> void:
	if estado == "dibujando":
		u_dibujado = clampf(u, 0.0, 1.0)


## La punta del bastón está ahora en `p` (mundo) y toca el suelo (`baja`) o va alzada: si toca, la línea se alarga hasta ella (empieza un trazo nuevo si venía alzada).
func punta_mundo(p: Vector3, baja: bool = true) -> void:
	punta = p
	punta_baja = baja
	if _chispas != null:
		_chispas.global_position = Vector3(p.x, global_position.y + ALTO_SUELO, p.z)
		_chispas.emitting = baja and estado == "dibujando"
	if estado != "dibujando":
		return
	var rel: Vector3 = Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
	if not baja:
		_abierto = false
		return
	if not _abierto:
		trazos.append(PackedVector3Array([rel]))
		_abierto = true
		return
	var t: PackedVector3Array = trazos[trazos.size() - 1]
	if t[t.size() - 1].distance_to(rel) >= PASO_MIN:
		t.append(rel)
		trazos[trazos.size() - 1] = t


## ¿Está el dibujo completo (el ritual ha llegado al final del rombo)?
func completa() -> bool:
	return u_dibujado >= TrazosRitual.ROMBO_FIN - 0.0001


## Al clavar el bastón: destello, onda verde, el dibujo crece hasta el sello grande y se desvanece.
func activar() -> void:
	if estado != "dibujando":
		return
	estado = "activa"
	t_estado = 0.0
	radio_onda = 0.0
	u_dibujado = 1.0
	_abierto = false
	if _chispas != null:
		_chispas.emitting = false
	_crear_onda()
	activada.emit()


## Interrumpida: el dibujo se rompe y se apaga en rojo-gris.
func cancelar() -> void:
	if estado != "dibujando":
		return
	estado = "cancelada"
	t_estado = 0.0
	if _chispas != null:
		_chispas.emitting = false
	cancelada.emit()


func _crear_onda() -> void:
	_onda_mat = StandardMaterial3D.new()
	_onda_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_onda_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_onda_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_onda_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_onda_mat.vertex_color_use_as_albedo = true
	_onda = MeshInstance3D.new()
	_onda.name = "Onda"
	_onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_onda.material_override = _onda_mat
	add_child(_onda)
	_onda.position = Vector3(0, ALTO_SUELO * 1.5, 0)
	_flash = MeshInstance3D.new()
	var qd := CylinderMesh.new()                    # disco: el destello es un círculo, no un cuadrado
	qd.top_radius = 0.5
	qd.bottom_radius = 0.5
	qd.height = 0.01
	qd.radial_segments = 48
	qd.rings = 1
	_flash.mesh = qd
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.albedo_color = Color(0.8, 1.0, 0.8, 0.9)
	_flash.material_override = fm
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.position = Vector3(0, ALTO_SUELO * 2.0, 0)
	add_child(_flash)
	_luz = OmniLight3D.new()
	_luz.light_color = color
	_luz.light_energy = 3.0
	_luz.omni_range = radio * 1.5
	_luz.shadow_enabled = false
	_luz.position = Vector3(0, 0.5, 0)
	add_child(_luz)


func _process(delta: float) -> void:
	_t += delta
	t_estado += delta
	if estado == "dibujando":
		_dibujar(1.0, color, 1.0, ANCHO, 0.0)
	elif estado == "activa":
		var e: float = clampf(t_estado / T_EXPANDE, 0.0, 1.0)
		e = 1.0 - (1.0 - e) * (1.0 - e)                      # sale rápido y frena
		escala_dibujo = lerpf(1.0, radio / maxf(radio_trazo, 0.01), e)
		var k: float = clampf((t_estado - T_EXPANDE) / T_DESVANECE, 0.0, 1.0)
		_dibujar(1.0 - k, color.lerp(Color(0.8, 1.0, 0.8), 1.0 - k), escala_dibujo, lerpf(ANCHO, ANCHO_GRANDE, e), 0.0)
		radio_onda = lerpf(0.0, ONDA_CASILLAS * Terreno3D.casilla, clampf(t_estado / T_ONDA, 0.0, 1.0))
		_dibujar_onda()
		onda_avanza.emit(radio_onda)
		if _flash != null:
			var f: float = clampf(1.0 - t_estado / T_FLASH, 0.0, 1.0)
			_flash.scale = Vector3(radio * 1.6, 1, radio * 1.6)
			(_flash.material_override as StandardMaterial3D).albedo_color = Color(0.8, 1.0, 0.8, 0.7 * f)
			_luz.light_energy = 3.0 * f + 0.6 * (1.0 - k)
		if t_estado >= T_EXPANDE + T_DESVANECE and t_estado >= T_ONDA + 0.4:
			queue_free()
	elif estado == "cancelada":
		var k2: float = clampf(t_estado / T_ROMPE, 0.0, 1.0)
		_dibujar(1.0 - k2, ROJO_GRIS, 1.0, ANCHO, k2)
		if t_estado >= T_ROMPE:
			queue_free()


## Reconstruye la malla con los trazos guardados, ampliados `escala` veces desde el centro, con `alfa`, grosor `ancho`; `rotura` > 0 los desplaza al azar (cancelación). La línea del trazo en
## curso llega hasta la punta real.
func _dibujar(alfa: float, col: Color, escala: float, ancho: float, rotura: float) -> void:
	if _malla == null:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var pulso: float = 0.88 + 0.12 * sin(_t * 9.0)
	var c := Color(col.r, col.g, col.b, clampf(alfa * BRILLO * pulso, 0.0, 1.0))
	for k in range(trazos.size()):
		var t: PackedVector3Array = trazos[k]
		var prev := Vector3.INF
		for i in range(t.size()):
			var p: Vector3 = _a_local(t[i], escala, rotura, k, i)
			if prev != Vector3.INF:
				_cinta(im, prev, p, ancho, c)
			prev = p
		if k == trazos.size() - 1 and _abierto and estado == "dibujando" and prev != Vector3.INF:
			var tp: Vector3 = Vector3(punta.x - global_position.x, ALTO_SUELO, punta.z - global_position.z)
			_cinta(im, prev, tp, ancho, c)
	im.surface_end()
	_malla.mesh = im


func _a_local(q: Vector3, escala: float, rotura: float, k: int, i: int) -> Vector3:
	var p := Vector3(q.x * escala, ALTO_SUELO, q.z * escala)
	if rotura > 0.0:
		var h: float = sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453
		h = h - floor(h)
		var h2: float = sin(float(i) * 39.346 + float(k) * 11.135) * 24634.634
		h2 = h2 - floor(h2)
		p += Vector3(h - 0.5, 0.0, h2 - 0.5) * escala * radio_trazo * 0.35 * rotura
	return p


func _cinta(im: ImmediateMesh, a: Vector3, b: Vector3, ancho: float, c: Color) -> void:
	if a == Vector3.INF or a.distance_to(b) < 0.0001:
		return
	var d: Vector3 = (b - a).normalized()
	var n: Vector3 = Vector3.UP.cross(d).normalized() * ancho * 0.5
	im.surface_set_color(c)
	im.surface_add_vertex(a - n)
	im.surface_add_vertex(a + n)
	im.surface_add_vertex(b + n)
	im.surface_add_vertex(a - n)
	im.surface_add_vertex(b + n)
	im.surface_add_vertex(b - n)


func _dibujar_onda() -> void:
	if _onda == null:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var r1: float = radio_onda
	var r0: float = maxf(r1 - 0.45, 0.0)
	var fade: float = clampf(1.0 - radio_onda / (ONDA_CASILLAS * Terreno3D.casilla), 0.0, 1.0)
	var n: int = 72
	var c := Color(color.r, color.g, color.b, 0.75 * fade)
	var c0 := Color(color.r, color.g, color.b, 0.0)
	for i in range(n):
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var p0i := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p0o := Vector3(cos(a0) * r1, 0, sin(a0) * r1)
		var p1i := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p1o := Vector3(cos(a1) * r1, 0, sin(a1) * r1)
		im.surface_set_color(c0)
		im.surface_add_vertex(p0i)
		im.surface_set_color(c)
		im.surface_add_vertex(p0o)
		im.surface_set_color(c)
		im.surface_add_vertex(p1o)
		im.surface_set_color(c0)
		im.surface_add_vertex(p0i)
		im.surface_set_color(c)
		im.surface_add_vertex(p1o)
		im.surface_set_color(c0)
		im.surface_add_vertex(p1i)
	im.surface_end()
	_onda.mesh = im
