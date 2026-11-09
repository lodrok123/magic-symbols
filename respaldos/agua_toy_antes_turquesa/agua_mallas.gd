extends RefCounted

## MALLAS Y MATERIALES DEL AGUA «TOY» (3/11/2026, fase 1). Se usa con `const AguaMallas = preload("res://presentacion/vfx/toy/agua_mallas.gd")` (sin class_name: no depende de la caché de clases).
##   · `cinta(...)`: tira helicoidal alrededor del eje Z (UV.x a lo largo, UV.y a lo ancho) para las cintas de la bola, la estela y el remolino de la carga.
##   · `material(...)`: un ShaderMaterial del agua con las texturas LeLu ya puestas (cáusticas, flujo, onda, disco).
##   · `rampa_sprites()`: rampa azul → celeste → casi blanco para recolorear los sprites LeLu (la lámina de salpicadura y el vaho) con lelu_sprite_mix.gdshader.

const AguaPaleta = preload("res://presentacion/vfx/toy/agua_paleta.gd")
const DIR: String = "res://presentacion/vfx/toy/"
const TEX: String = "res://assets/vfx/lelu_noise/"
const SH_ESFERA: String = DIR + "agua_esfera.gdshader"
const SH_ESFERA_ATRAS: String = DIR + "agua_esfera_atras.gdshader"
const SH_CINTA: String = DIR + "agua_cinta.gdshader"
const SH_ONDA: String = DIR + "agua_onda.gdshader"
const SH_HAZ: String = DIR + "agua_haz.gdshader"
const SH_HAZ_CINTA: String = DIR + "agua_haz_cinta.gdshader"
const SH_MANCHA: String = DIR + "agua_mancha.gdshader"
const SH_PILAR: String = DIR + "agua_pilar.gdshader"
const SH_LAMINA: String = DIR + "agua_lamina.gdshader"
const SH_ESPUMA: String = DIR + "agua_espuma.gdshader"
const SH_OLA: String = DIR + "agua_ola.gdshader"
const SH_OLA_LAMINA: String = DIR + "agua_ola_lamina.gdshader"
const SH_FRANJA: String = DIR + "agua_franja.gdshader"
const SH_SPRITE: String = DIR + "lelu_sprite_mix.gdshader"
const PUFF: String = "res://assets/vfx/kenney_puff/whitePuff03.png"

static var _rampa: GradientTexture1D = null


static func material(shader: String, p: Dictionary = {}, prioridad: int = 0) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader)
	m.render_priority = prioridad
	m.set_shader_parameter("causticas", load(TEX + "T_Noise_Wf4.png"))
	m.set_shader_parameter("flujo", load(TEX + "T_Noise_W5i.png"))
	m.set_shader_parameter("flujo2", load(TEX + "T_Noise_Wo14.png"))
	m.set_shader_parameter("onda", load(TEX + "T_Wave43.png"))
	m.set_shader_parameter("disco", load(TEX + "T_VFX_CircleFit1.png"))
	m.set_shader_parameter("liquido", load(TEX + "T_LiquidVertical_Wave.png"))
	m.set_shader_parameter("lengua", load(TEX + "T_wavesKI96.png"))
	m.set_shader_parameter("onda66", load(TEX + "T_Wave66.png"))
	m.set_shader_parameter("puff", load(PUFF))
	var pal: Dictionary = AguaPaleta.uniforms()                # la paleta del agua del mundo, siempre la misma (agua_paleta.gd)
	for k in pal:
		m.set_shader_parameter(k, pal[k])
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


## Una bocanada de espuma/vaho: quad billboard con whitePuff03 (Kenney, CC0) teñido con la rampa del agua; `tramo` = parte de la rampa que usa (más alto = más blanco). Empieza invisible y sin tamaño.
static func puff(nombre: String, tramo: Vector2 = Vector2(0.4, 0.78)) -> MeshInstance3D:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH_SPRITE)
	m.render_priority = 1
	m.set_shader_parameter("tex", load(PUFF))
	m.set_shader_parameter("rampa", rampa_sprites())
	m.set_shader_parameter("usar_alfa", 1.0)
	m.set_shader_parameter("recorte", Vector2(0.0, 0.85))
	m.set_shader_parameter("luminancia", Vector2(0.0, 1.0))
	m.set_shader_parameter("tramo", tramo)
	m.set_shader_parameter("billboard", 1)
	m.set_shader_parameter("giro", randf() * TAU)
	m.set_shader_parameter("vida", 0.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * 0.001
	return mi


## Rampa para los sprites LeLu en escala de grises: azul medio abajo, celeste en medio, casi blanco arriba (la paleta de agua_paleta.gd: hondo, somero, espuma).
static func rampa_sprites() -> GradientTexture1D:
	if _rampa != null:
		return _rampa
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.34, 0.66, 1.0])
	g.colors = PackedColorArray([AguaPaleta.HONDO, AguaPaleta.HONDO.lerp(AguaPaleta.SOMERO, 0.5), AguaPaleta.SOMERO, AguaPaleta.ESPUMA])
	_rampa = GradientTexture1D.new()
	_rampa.gradient = g
	_rampa.width = 128
	return _rampa


# ------------------------------------------------------------------ fase 3: pilar, lenguas y espuma ------------------------------------------------------------------

## Tubo abierto de 1 de radio y 1 de alto (UV.x = vuelta 0..1, UV.y = 0 en el suelo y 1 arriba). La forma real la da el vertex shader (agua_pilar.gdshader).
static func tubo(seg_a: int = 28, seg_y: int = 16) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in seg_y + 1:
		var v: float = float(j) / float(seg_y)
		for i in seg_a + 1:
			var u: float = float(i) / float(seg_a)
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3(cos(u * TAU), 0.0, sin(u * TAU)))
			st.add_vertex(Vector3(cos(u * TAU), v, sin(u * TAU)))
	for j in seg_y:
		for i in seg_a:
			var a0: int = j * (seg_a + 1) + i
			var b0: int = a0 + seg_a + 1
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	return st.commit()


## Una lengua: {pos (suelo, local), w, h (m), fuera (dirección horizontal unitaria, local), sem, dly (0..1), alfa}.
static func lengua(p: Vector3, w: float, h: float, fuera: Vector3, rng: RandomNumberGenerator, dly: float, alfa: float) -> Dictionary:
	return {"pos": p, "w": w, "h": h, "fuera": fuera, "sem": rng.randf() * 7.0, "dly": dly, "alfa": alfa}


## CORONA del pilar: un anillo de lenguas altas y de distinta altura alrededor de la base, más unas bajas y sueltas, más lejos. Determinista.
static func lenguas_corona(rx: float, rz: float, alto: float) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261105
	var rm: float = (rx + rz) * 0.5
	var r: Array = []
	var n: int = clampi(int(round(FuegoToyMallas.perimetro_elipse(rx, rz) / 0.55)), 7, 13)
	var fase: float = rng.randf() * TAU
	for i in n:
		var ang: float = fase + TAU * (float(i) + rng.randf_range(-0.25, 0.25)) / float(n)
		var rr: float = rng.randf_range(0.95, 1.35)
		var h: float = clampf(alto * rng.randf_range(0.22, 0.5), 0.55, 2.8)
		if i % 3 == 0:
			h *= 0.5                                                   # alturas bien distintas: una de cada tres, baja
		var d: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		r.append(lengua(Vector3(d.x * rx * rr, 0.0, d.z * rz * rr), h * rng.randf_range(0.55, 0.7) + 0.15 * rm, h, d, rng, rng.randf_range(0.0, 0.6), 0.95))
	for i in 5:
		var ang2: float = fase + rng.randf() * TAU
		var d2: Vector3 = Vector3(cos(ang2), 0.0, sin(ang2))
		var rr2: float = rng.randf_range(1.7, 2.5)
		var h2: float = clampf(alto * rng.randf_range(0.05, 0.1), 0.22, 0.7)
		r.append(lengua(Vector3(d2.x * rx * rr2 + d2.x * 0.1, 0.0, d2.z * rz * rr2 + d2.z * 0.1), h2 * 0.9, h2, d2, rng, rng.randf_range(0.2, 0.9), 0.85))
	return r


## MultiMesh de lenguas (agua_lamina.gdshader): la base de cada instancia es (ancho, 0, 0) · (0, alto, 0) · (fuera). Devuelve el nodo; los parámetros de animación (subida, curva, caida) los pone quien lo usa.
static func lenguas_mm(nombre: String, lista: Array, p: Dictionary = {}) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = FuegoToyMallas.quad_vbb(4, 14)
	mm.instance_count = lista.size()
	for i in lista.size():
		var l: Dictionary = lista[i]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3(float(l["w"]), 0, 0), Vector3(0, float(l["h"]), 0), l["fuera"]), l["pos"]))
		mm.set_instance_custom_data(i, Color(float(l["sem"]), float(l["dly"]), 0.0, float(l["alfa"])))
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = material(SH_LAMINA, p, 2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -30.0, Vector3.ONE * 60.0)
	return mi


## MultiMesh de bocanadas de espuma (agua_espuma.gdshader), todas ocultas al principio.
static func espuma_mm(nombre: String, cantidad: int) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = cantidad
	for i in cantidad:
		espuma_poner(mm, i, Vector3.ZERO, 0.0, 0.0, 0.5, 0.0)
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = material(SH_ESPUMA, {"suave_prof": 0.1}, 3)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -30.0, Vector3.ONE * 60.0)
	return mi


## MultiMesh de FRANJAS de espuma (agua_franja.gdshader): quads tumbados en el suelo, largos y estrechos (fase 4: base del géiser, en vez de bocanadas redondas).
static func franjas_mm(nombre: String, cantidad: int) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	mm.mesh = q
	mm.instance_count = cantidad
	for i in cantidad:
		franja_poner(mm, i, Vector3.ZERO, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0)
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	mi.material_override = material(SH_FRANJA, {"suave_prof": 0.0}, 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -30.0, Vector3.ONE * 60.0)
	return mi


## Franja `i`: centro `pos`, `largo` (a lo largo del giro `giro` alrededor de Y) y `ancho` en m, opacidad `alfa`, claridad 0..1.
static func franja_poner(mm: MultiMesh, i: int, pos: Vector3, largo: float, ancho: float, alfa: float, claridad: float, giro: float, semilla: float) -> void:
	var vivo: bool = alfa > 0.002 and largo > 0.0
	var b: Basis = Basis(Vector3.UP, giro) * Basis.from_scale(Vector3(largo if vivo else 0.0, 1.0, ancho if vivo else 0.0))
	mm.set_instance_transform(i, Transform3D(b, pos))
	mm.set_instance_custom_data(i, Color(clampf(alfa, 0.0, 1.0), clampf(claridad, 0.0, 1.0), semilla, 0.0))


static func espuma_poner(mm: MultiMesh, i: int, pos: Vector3, tam: float, alfa: float, claridad: float, giro: float) -> void:
	var vivo: bool = alfa > 0.002 and tam > 0.0
	mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * (tam if vivo else 0.0)), pos))
	mm.set_instance_custom_data(i, Color(clampf(alfa, 0.0, 1.0), clampf(claridad, 0.0, 1.0), giro, 0.0))


# ------------------------------------------------------------------ fase 4: ola ------------------------------------------------------------------

## Rejilla plana de la cortina de la ola: vértices (u - 0,5, s, 0) con UV = (u, s); la forma real (el perfil con el rizo) la da el vertex shader agua_ola.gdshader.
static func plano_ola(nx: int = 56, ns: int = 36) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in ns + 1:
		var v: float = float(j) / float(ns)
		for i in nx + 1:
			var u: float = float(i) / float(nx)
			st.set_uv(Vector2(u, v))
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(Vector3(u - 0.5, v, 0.0))
	for j in ns:
		for i in nx:
			var a0: int = j * (nx + 1) + i
			var b0: int = a0 + nx + 1
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	return st.commit()


## Láminas Y-billboard de la ola, en FILAS DE PROFUNDIDAD: {x, z, w, h, sem, dly, alfa}. `cuerpo`: columnas cada ~0,7 m en cuatro filas (delante, centro, detrás y más atrás); si no, tres filas para la cresta de espuma.
static func ola_laminas(a: float, b: float, alto: float, cuerpo: bool) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261107 + (1 if cuerpo else 0)
	var paso: float = 0.7
	var n: int = clampi(int(round(2.0 * a * 0.95 / paso)) + 1, 3, 24)
	var filas: Array = [-0.8 * b, 0.0, 0.9 * b, 0.25 * alto + 1.6 * b] if cuerpo else [-0.9 * b, 0.1 * b, 0.8 * b]
	var r: Array = []
	for fi in filas.size():
		for i in n:
			var x: float = lerpf(-a * 0.95, a * 0.95, float(i) / float(maxi(n - 1, 1))) + rng.randf_range(-0.2, 0.2) * paso + (0.5 * paso if fi % 2 == 1 else 0.0)
			x = clampf(x, -a, a)
			var f: float = float(fi) / float(maxi(filas.size() - 1, 1))
			var ancho: float = maxf(paso * 1.9, 1.0) * rng.randf_range(0.85, 1.15) * (1.0 if cuerpo else 0.8)
			var alt: float = (alto * (0.92 - 0.14 * f) * rng.randf_range(0.85, 1.0)) if cuerpo else (alto * 0.36 * rng.randf_range(0.9, 1.15))
			r.append({"x": x, "z": float(filas[fi]), "w": ancho, "h": alt, "sem": rng.randf() * 7.0, "dly": rng.randf_range(0.0, 0.5), "alfa": (0.85 - 0.12 * f) if cuerpo else (0.95 - 0.1 * f)})
	return r


## MultiMesh de esas láminas con el shader agua_ola_lamina (modo 0 cuerpo, 1 cresta). Hacia delante = -Z local.
static func ola_mm(nombre: String, lista: Array, modo: int, p: Dictionary = {}) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = FuegoToyMallas.quad_vbb(4, 12)
	mm.instance_count = lista.size()
	for i in lista.size():
		var l: Dictionary = lista[i]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3(float(l["w"]), 0, 0), Vector3(0, float(l["h"]), 0), Vector3(0, 0, -1)), Vector3(float(l["x"]), 0.0, float(l["z"]))))
		mm.set_instance_custom_data(i, Color(float(l["sem"]), float(l["dly"]), float(l["x"]), float(l["alfa"])))
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.name = nombre
	mi.multimesh = mm
	var pp: Dictionary = {"modo": modo}
	pp.merge(p, true)
	mi.material_override = material(SH_OLA_LAMINA, pp, 2 if modo == 0 else 3)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3.ONE * -30.0, Vector3.ONE * 60.0)
	return mi


## Tira que da `vueltas` vueltas alrededor del eje Z entre z0 y z1. `radio_fn(u, z)` y `ancho_fn(u)` (semiancho a lo largo de Z) dan el perfil, con u 0..1 a lo largo. `fase` en vueltas (0..1).
static func cinta(z0: float, z1: float, vueltas: float, fase: float, seg: int, radio_fn: Callable, ancho_fn: Callable) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg + 1:
		var u: float = float(i) / float(seg)
		var z: float = lerpf(z0, z1, u)
		var a: float = (fase + vueltas * u) * TAU
		var r: float = float(radio_fn.call(u, z))
		var hw: float = float(ancho_fn.call(u))
		var c: Vector3 = Vector3(cos(a) * r, sin(a) * r, z)
		var n: Vector3 = Vector3(cos(a), sin(a), 0.0)
		st.set_uv(Vector2(u, 0.0))
		st.set_normal(n)
		st.add_vertex(c + Vector3(0, 0, -hw))
		st.set_uv(Vector2(u, 1.0))
		st.set_normal(n)
		st.add_vertex(c + Vector3(0, 0, hw))
	for i in seg:
		var b: int = i * 2
		st.add_index(b)
		st.add_index(b + 1)
		st.add_index(b + 2)
		st.add_index(b + 1)
		st.add_index(b + 3)
		st.add_index(b + 2)
	return st.commit()
