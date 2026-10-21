class_name VfxRayo
extends ElementoVfx

## RAYO del kit luminoso (19/10, VFX_RAYO_HIELO P5). Rampa azul → cian → blanco cálido; chispas eléctricas aditivas, bordes duros
## (`suave` bajo) y movimiento muy rápido: no es una llama, es una descarga. La bola con arcos que se re-sortean a saltos la dibuja
## `VfxEstado3D` con la forma `rayo` de Formas3D (misma pieza validada que el pilar de rayo); aquí solo el color y el carácter.

func rampa() -> Array:
	return [[0.0, Color(0.12, 0.28, 0.9)], [0.3, Color(0.2, 0.58, 1.0)], [0.6, Color(0.55, 0.9, 1.0)],
		[0.85, Color(0.9, 0.98, 1.0)], [1.0, Color(1.0, 0.98, 0.88)]]


func perfil() -> Dictionary:
	return {"luz": Color(0.45, 0.85, 1.0), "charco": Color(0.3, 0.6, 1.0), "aro": Color(0.85, 0.95, 1.0),
		"particula": [Color(1.0, 1.0, 1.0, 1.0), Color(0.5, 0.9, 1.0, 1.0), Color(0.2, 0.4, 1.0, 0.0)],
		"particula_aditiva": true, "particula_albedo": Color(1.3, 1.5, 2.0, 1.0), "marca": "quemado",
		"mult": {"velocidad": 2.0, "suave": 0.5, "potencia": 1.2}}


## El rayo cae más alto que la llama: un poco más largo.
func alto_muro(alto: float) -> float:
	return alto * 1.2


# ---------------------------------------------------------------------------------------------------------------------------------
# DESCARGA (21/10): el haz de ᛁ `linea` + rayo (elemento relámpago). Una línea quebrada de la mano a la punta que se re-sortea a saltos.
# ---------------------------------------------------------------------------------------------------------------------------------
const DESC_SEG_POR_U: float = 3.0              ## tramos por unidad de largo
const DESC_SEG_MIN: int = 5
const DESC_SEG_MAX: int = 18
const DESC_DESVIO: float = 0.2                 ## desvío lateral máximo de un vértice (u × esc), nulo en los extremos
const DESC_RADIO: float = 0.03                 ## radio del núcleo (u × esc)
const DESC_HALO_K: float = 3.0                 ## el halo mide esto × el núcleo
const DESC_VARIANTES: int = 4                  ## trazados distintos que se alternan
const DESC_T_CAMBIO: float = 0.055             ## s que se ve cada trazado
const DESC_RAMAS: int = 3                      ## ramitas por trazado
const DESC_RAMA_LARGO: float = 0.45            ## u × esc
const DESC_T_ENTRA: float = 0.05
const DESC_T_SALE: float = 0.3
const DESC_COLOR_NUCLEO: Color = Color(1.0, 1.0, 0.9)
const DESC_COLOR_HALO: Color = Color(0.25, 0.6, 1.0)
const DESC_ALFA_HALO: float = 0.4


## Hace crecer y desvanecer la descarga: elige un trazado cada `DESC_T_CAMBIO` s y escala el alfa (entra, se mantiene, sale).
class Descarga extends Node3D:
	var variantes: Array = []
	var mats: Array = []             ## [material del núcleo, del halo]
	var alfas: Array = [1.0, 0.5]
	var luz: OmniLight3D = null
	var dura: float = 1.0
	var _t: float = 0.0
	var _orden: Array = []

	func _process(delta: float) -> void:
		_t += delta
		var env: float = clampf(_t / VfxRayo.DESC_T_ENTRA, 0.0, 1.0) * clampf((dura - _t) / VfxRayo.DESC_T_SALE, 0.0, 1.0)
		for i in range(mats.size()):
			var c: Color = (mats[i] as StandardMaterial3D).albedo_color
			c.a = float(alfas[i]) * env
			(mats[i] as StandardMaterial3D).albedo_color = c
		if variantes.size() > 0:
			var k: int = int(_t / VfxRayo.DESC_T_CAMBIO)
			if _orden.is_empty():
				for j in range(variantes.size()):
					_orden.append(j)
				_orden.shuffle()
			var activa: int = int(_orden[k % _orden.size()])
			for j in range(variantes.size()):
				(variantes[j] as Node3D).visible = j == activa
		if luz != null and is_instance_valid(luz):
			luz.light_energy = minf(luz.light_energy, 4.0 * env)        # el parpadeo es el del kit (`VfxKit3D.parpadeo`); aquí solo se apaga con la descarga
		if _t >= dura:
			queue_free()


## Un tubo de 4 caras a lo largo de la quebrada `pts` (radio `r`). Sin normales ni UV (el material no tiene luz).
static func _tubo(pts: PackedVector3Array, r: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var n: int = pts.size()
	for i in range(n):
		var t: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var u: Vector3 = t.cross(Vector3.UP)
		if u.length() < 0.05:
			u = t.cross(Vector3.RIGHT)
		u = u.normalized()
		var v: Vector3 = t.cross(u).normalized()
		for k in range(4):
			var a: float = float(k) * TAU / 4.0 + PI * 0.25
			verts.append(pts[i] + (u * cos(a) + v * sin(a)) * r)
		if i > 0:
			var b: int = i * 4
			for k in range(4):
				var k2: int = (k + 1) % 4
				idx.append_array(PackedInt32Array([b - 4 + k, b - 4 + k2, b + k, b - 4 + k2, b + k2, b + k]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## La quebrada de un trazado: de `desde` a `hasta` con vértices desviados al azar de lado (0 en los extremos), `n` tramos.
static func _quebrada(desde: Vector3, hasta: Vector3, n: int, desvio: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var t: Vector3 = (hasta - desde).normalized()
	var u: Vector3 = t.cross(Vector3.UP)
	if u.length() < 0.05:
		u = t.cross(Vector3.RIGHT)
	u = u.normalized()
	var v: Vector3 = t.cross(u).normalized()
	for i in range(n + 1):
		var s: float = float(i) / float(n)
		var amp: float = desvio * sin(PI * s) * randf_range(0.4, 1.0)
		var a: float = randf() * TAU
		pts.append(desde.lerp(hasta, s) + (u * cos(a) + v * sin(a)) * amp)
	return pts


## DESCARGA de `desde` (la mano) a `hasta` (la punta) de `dura` s: una línea quebrada y brillante (núcleo casi blanco con un halo azul) que cambia de trazado a saltos, con ramitas,
## chispas a lo largo, una luz que parpadea y un fogonazo con chispas donde da. `esc` = tamaño. Todo es aditivo y sin luz. Cuelga de `padre` (+Z libre) y se libera sola. Devuelve la raíz.
static func descarga(padre: Node3D, desde: Vector3, hasta: Vector3, dura: float = 1.0, esc: float = 1.0) -> Descarga:
	if padre == null or not is_instance_valid(padre) or not padre.is_inside_tree():
		return null
	var k: float = clampf(esc, 0.5, 2.0)
	var largo: float = maxf(desde.distance_to(hasta), 0.5)
	var n: int = clampi(roundi(largo * DESC_SEG_POR_U), DESC_SEG_MIN, DESC_SEG_MAX)
	var raiz := Descarga.new()
	raiz.name = "DescargaRayo"
	raiz.dura = maxf(dura, 0.3)
	padre.add_child(raiz)
	var mat_n: StandardMaterial3D = _material_descarga(DESC_COLOR_NUCLEO)
	var mat_h: StandardMaterial3D = _material_descarga(DESC_COLOR_HALO)
	raiz.mats = [mat_n, mat_h]
	raiz.alfas = [1.0, DESC_ALFA_HALO]
	for i in range(DESC_VARIANTES):
		var variante := Node3D.new()
		variante.name = "Trazado%d" % i
		raiz.add_child(variante)
		var pts: PackedVector3Array = _quebrada(desde, hasta, n, DESC_DESVIO * k)
		var tramos: Array = [pts]
		for j in range(DESC_RAMAS):                    # ramitas: salen de un vértice interior hacia un lado y acaban en nada
			var o: int = randi_range(1, maxi(n - 1, 1))
			var dir: Vector3 = (hasta - desde).normalized()
			var lateral: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.4), randf_range(-1.0, 1.0)).normalized()
			var largo_r: float = DESC_RAMA_LARGO * k * randf_range(0.6, 1.2)
			var a: Vector3 = pts[o]
			var rama: PackedVector3Array = PackedVector3Array([a, a + (dir * 0.4 + lateral * 0.7).normalized() * largo_r * 0.5, a + (dir * 0.6 + lateral).normalized() * largo_r])
			tramos.append(rama)
		for tr in tramos:
			var fino: float = 1.0 if tr == pts else 0.55
			for par in [[mat_n, DESC_RADIO], [mat_h, DESC_RADIO * DESC_HALO_K]]:
				var mi := MeshInstance3D.new()
				mi.mesh = _tubo(tr as PackedVector3Array, float(par[1]) * k * fino)
				mi.material_override = par[0] as Material
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				variante.add_child(mi)
		raiz.variantes.append(variante)
	raiz.luz = VfxKit3D._luz(raiz, desde.lerp(hasta, 0.5), 0.9, 2.5 + largo * 0.3, Color(0.5, 0.8, 1.0))
	VfxKit3D.particulas(raiz, desde.lerp(hasta, 0.5), 14, 0.35, 0.05 * k, 1.2, true, true, largo * 0.35, 0.0, Vector3.UP, 180.0)
	VfxKit3D.particulas(raiz, hasta, 16, 0.5, 0.07 * k, 3.5, true, true, 0.12 * k, -4.0, Vector3.UP, 70.0)
	return raiz


static func _material_descarga(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(color.r, color.g, color.b, 0.0)
	return m
