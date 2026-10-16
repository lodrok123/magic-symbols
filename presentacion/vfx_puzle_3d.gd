class_name VfxPuzle3D
extends RefCounted

## EFECTOS DE LAS PIEZAS DE PUZLE (16/10, Pipeline, Fase 13.5). Salpicadura al mojar, chispas, vapor al secar, fogonazo del barril, polvo del
## derrumbe, y los del llenado del pozo (burbujas, caída del chorro). Todo son funciones estáticas que cuelgan nodos de `padre` y se
## limpian solas (como VfxKit3D): ninguna guarda estado salvo las texturas.
##
## Por qué en código y no en `.tres`: un GPUParticles3D no cabe en un único `.tres` (necesita su malla de dibujo y su material
## a la vez), y los `.tscn` sueltos habría que instanciarlos y colocarlos a mano desde el Juego; con una llamada
## (`VfxPuzle3D.polvo(self, punto)`) el Juego no necesita saber nada. Los valores están arriba de cada función, a la vista.
##
## Las texturas son las de `presentacion/vfx/` (gota, humo, polvo, chispa_electrica, brasa, burbuja, destello, ondas); si falta alguna
## se usa un punto suave generado: un efecto nunca falla por un PNG que no esté.

const CARPETA: String = "res://presentacion/vfx/"
const COLOR_AGUA: Color = Color(0.55, 0.82, 1.0, 0.9)
const COLOR_RAYO: Color = Color(1.0, 0.92, 0.45)

static var _tex: Dictionary = {}


## Textura `nombre`.png de presentacion/vfx/, o un punto radial suave si no existe.
static func _textura(nombre: String) -> Texture2D:
	if _tex.has(nombre):
		return _tex[nombre]
	var t: Texture2D = null
	var ruta: String = CARPETA + nombre + ".png"
	if ResourceLoader.exists(ruta):
		t = load(ruta) as Texture2D
	if t == null:
		t = _punto()
	_tex[nombre] = t
	return t


static func _punto() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## Emisor genérico. `opc`: color (Color, con alfa), aditivo (bool), gravedad (float), direccion (Vector3), abanico (grados), continuo (bool),
## radio_emision (float), crece (bool: la partícula nace pequeña y se hincha, humo/polvo; si no, nace grande y se encoge), hdr (float, > 1 =
## brilla con el bloom), alargada (bool: estela alineada con la velocidad, chispas), amortigua (float, frenado).
static func _emisor(padre: Node3D, pos: Vector3, textura: String, n: int, vida: float, tam: float, vel: float, opc: Dictionary = {}) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.amount = n
	gp.lifetime = vida
	var continuo: bool = bool(opc.get("continuo", false))
	gp.one_shot = not continuo
	gp.explosiveness = 0.0 if continuo else 0.9
	gp.local_coords = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-5, -3, -5), Vector3(10, 8, 10))
	var pm := ParticleProcessMaterial.new()
	pm.direction = opc.get("direccion", Vector3.UP)
	pm.spread = float(opc.get("abanico", 45.0))
	pm.initial_velocity_min = vel * 0.5
	pm.initial_velocity_max = vel
	pm.gravity = Vector3(0.0, float(opc.get("gravedad", -4.0)), 0.0)
	pm.damping_min = float(opc.get("amortigua", 0.0))
	pm.damping_max = float(opc.get("amortigua", 0.0)) * 1.3
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = float(opc.get("radio_emision", 0.1))
	pm.scale_min = tam * 0.7
	pm.scale_max = tam * 1.25
	var curva := Curve.new()
	if bool(opc.get("crece", false)):
		curva.add_point(Vector2(0.0, 0.35))
		curva.add_point(Vector2(1.0, 1.25))
	else:
		curva.add_point(Vector2(0.0, 1.0))
		curva.add_point(Vector2(0.75, 0.7))
		curva.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var col: Color = opc.get("color", Color.WHITE)
	var g := Gradient.new()                          # el alfa baja a 0 al final: nada desaparece de golpe
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([col, Color(col.r, col.g, col.b, col.a * 0.7), Color(col.r, col.g, col.b, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	if bool(opc.get("alargada", false)):
		pm.particle_flag_align_y = true
	gp.process_material = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if bool(opc.get("aditivo", false)) else BaseMaterial3D.BLEND_MODE_MIX
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.billboard_keep_scale = true
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _textura(textura)
	var h: float = float(opc.get("hdr", 1.0))
	sm.albedo_color = Color(h, h, h, 1.0)
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.6) if bool(opc.get("alargada", false)) else Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Z
	q.material = sm
	gp.draw_pass_1 = q
	gp.position = pos
	padre.add_child(gp)
	gp.emitting = true
	if not continuo and padre.is_inside_tree():
		padre.get_tree().create_timer(vida + 0.4, false).timeout.connect(gp.queue_free)
	return gp


## Aro plano en el suelo que se abre y se desvanece (anillos de agua, onda del derrumbe). `y` es la altura en coordenadas de `padre`.
static func _aro(padre: Node3D, pos: Vector3, radio: float, dura: float, color: Color, textura: String = "ondas") -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	q.orientation = PlaneMesh.FACE_Y
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.albedo_texture = _textura(textura)
	sm.albedo_color = color
	q.material = sm
	m.mesh = q
	m.position = pos
	m.scale = Vector3.ONE * radio * 0.15
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(m)
	var tw: Tween = m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * radio, dura).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sm, "albedo_color:a", 0.0, dura)
	tw.tween_callback(m.queue_free)


## SALPICADURA (la pila al mojarse, un golpe de agua): gotas que saltan y un anillo que se abre. `esc` 1 = una pila.
static func salpicadura(padre: Node3D, pos: Vector3, esc: float = 1.0, color: Color = COLOR_AGUA) -> void:
	_emisor(padre, pos, "gota", 18, 0.7, 0.13 * esc, 2.8 * esc,
		{"color": color, "gravedad": -9.0, "abanico": 55.0, "radio_emision": 0.12 * esc})
	_aro(padre, pos + Vector3(0.0, 0.02, 0.0), 0.9 * esc, 0.7, Color(color.r, color.g, color.b, 0.7))


## CHISPAS eléctricas. De un disparo, o `continuo` (devuelve el emisor: `emitting = false` las apaga; los bornes de la pila).
static func chispas(padre: Node3D, pos: Vector3, continuo: bool = false, esc: float = 1.0) -> GPUParticles3D:
	return _emisor(padre, pos, "chispa_electrica", 8 if continuo else 14, 0.4, 0.22 * esc, 2.4 * esc,
		{"color": COLOR_RAYO, "aditivo": true, "hdr": 2.2, "gravedad": -3.0, "abanico": 150.0, "continuo": continuo,
		"radio_emision": 0.08 * esc})


## VAPOR (el agua al secarse, el hielo que se derrite): bocanadas blancas que suben y se abren.
static func vapor(padre: Node3D, pos: Vector3, esc: float = 1.0, continuo: bool = false) -> GPUParticles3D:
	return _emisor(padre, pos, "humo", 8 if continuo else 12, 1.7, 0.55 * esc, 0.55,
		{"color": Color(0.95, 0.97, 1.0, 0.45), "gravedad": 0.5, "abanico": 25.0, "crece": true, "continuo": continuo,
		"radio_emision": 0.25 * esc})


## POLVO del derrumbe: nube parda que sale a ras de suelo en todas direcciones. `radio` = lo que se abre (u).
static func polvo(padre: Node3D, pos: Vector3, radio: float = 1.2) -> void:
	_emisor(padre, pos, "polvo", 16, 1.1, 0.8 * radio, 1.9 * radio,
		{"color": Color(0.74, 0.64, 0.52, 0.7), "gravedad": 0.0, "abanico": 80.0, "direccion": Vector3(0, 0.25, 0),
		"crece": true, "radio_emision": 0.4 * radio, "amortigua": 1.6})
	_emisor(padre, pos, "piedrecitas", 10, 0.8, 0.14, 3.0 * radio,
		{"color": Color(0.6, 0.55, 0.5, 1.0), "gravedad": -9.0, "abanico": 60.0, "radio_emision": 0.3 * radio})
	_aro(padre, pos + Vector3(0.0, 0.03, 0.0), 1.4 * radio, 0.8, Color(0.74, 0.64, 0.52, 0.5), "anillo_polvo")


## FOGONAZO del barril al explotar: bola de luz que se hincha, luz que ilumina el entorno, brasas, humo oscuro y polvo. `radio` = RADIO del barril.
static func fogonazo(padre: Node3D, pos: Vector3, radio: float = 2.6) -> void:
	var bola := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.3
	esf.height = 0.6
	esf.radial_segments = 12
	esf.rings = 6
	var mf := StandardMaterial3D.new()
	mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mf.albedo_color = Color(1.0, 0.7, 0.28, 0.95)
	mf.emission_enabled = true
	mf.emission = Color(1.0, 0.5, 0.1)
	mf.emission_energy_multiplier = 2.5
	esf.material = mf
	bola.mesh = esf
	bola.position = pos
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(bola)
	var tw: Tween = bola.create_tween()
	tw.tween_property(bola, "scale", Vector3.ONE * (radio * 0.55 / 0.3), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mf, "albedo_color:a", 0.0, 0.34).set_delay(0.06)
	tw.tween_callback(bola.queue_free)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.65, 0.3)
	luz.light_energy = 7.0
	luz.omni_range = radio * 2.4
	luz.position = pos + Vector3(0.0, 0.3, 0.0)
	luz.shadow_enabled = false
	padre.add_child(luz)
	var tl: Tween = luz.create_tween()
	tl.tween_property(luz, "light_energy", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tl.tween_callback(luz.queue_free)
	_emisor(padre, pos, "brasa", 30, 0.9, 0.16, 6.0,
		{"color": Color(1.0, 0.6, 0.2, 1.0), "aditivo": true, "hdr": 2.0, "gravedad": -6.0, "abanico": 120.0, "radio_emision": 0.3})
	_emisor(padre, pos + Vector3(0.0, 0.2, 0.0), "humo", 14, 1.5, 0.9, 1.4,
		{"color": Color(0.22, 0.2, 0.19, 0.8), "gravedad": 0.7, "abanico": 70.0, "crece": true, "radio_emision": 0.5})
	polvo(padre, Vector3(pos.x, pos.y - 0.3, pos.z), radio * 0.5)


## Burbujas que suben (bajo el chorro que llena el pozo, en una pila que hierve). Siempre continuas: devuelve el emisor.
static func burbujas(padre: Node3D, pos: Vector3, radio: float = 0.4, continuo: bool = true) -> GPUParticles3D:
	return _emisor(padre, pos, "burbuja", 9 if continuo else 5, 1.1, 0.12, 0.5,
		{"color": Color(0.85, 0.95, 1.0, 0.75), "gravedad": 1.2, "abanico": 12.0, "continuo": continuo, "radio_emision": radio, "crece": true})


## Caída del chorro sobre el agua (llenado del pozo): niebla fina y gotas que rebotan, continuas. Devuelve el emisor; los anillos de
## agua los pone `anillo_caida` cada cierto tiempo (los anillos son de un disparo).
static func caida_chorro(padre: Node3D, pos: Vector3, esc: float = 1.0, continuo: bool = true) -> GPUParticles3D:
	return _emisor(padre, pos, "salpicadura", 10 if continuo else 6, 0.7, 0.45 * esc, 1.4,
		{"color": Color(0.9, 0.97, 1.0, 0.6), "gravedad": -3.0, "abanico": 40.0, "continuo": continuo, "radio_emision": 0.18 * esc, "crece": true})


## Un anillo de agua que se abre donde cae el chorro (se repite desde fuera mientras caiga).
static func anillo_caida(padre: Node3D, pos: Vector3, radio: float = 0.9) -> void:
	_aro(padre, pos + Vector3(0.0, 0.02, 0.0), radio, 0.9, Color(0.9, 0.97, 1.0, 0.6))
