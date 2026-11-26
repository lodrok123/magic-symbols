class_name GotaTinta3D
extends RefCounted
## LA GOTA DE TINTA RECOGIBLE (24/11/2026, concepto de Pablo «Gota de tinta · azul arcano · tinta viscosa»). Es el ASPECTO de la gota que suelta un enemigo al morir
## (`Combate3D._soltar_recogibles`, C1 de PLAN_COMBATE): la jugabilidad (valor, imán, duración, cuentas) sigue en `Combate3D.Botin3D`; aquí solo se dibuja.
##
## Por qué 3D y no un sprite: la gota gira sobre sí misma, salta y vuela hacia la jugadora con la cámara inclinada 60°; su punta curvada es asimétrica y solo se lee
## al girar si tiene volumen, y al imantarse se ESTIRA hacia ella («la pluma la atrae»), cosa que un sprite plano no hace bien.
##
## Piezas (todas hechas en código, sin modelo externo; se cachean):
##   · CUERPO: un torno a lo largo de una espina curvada (gota gruesa abajo que se afina y se dobla hacia un lado en la punta) + una GOTITA que cuelga de la punta;
##   · CHARCO: una mancha plana irregular en el suelo («restos de tinta»), solo mientras la gota está quieta; no gira ni flota con ella;
##   · MATERIAL: tinta brillante del color del pigmento (azul arcano por defecto) con un REMOLINO más claro, borde más oscuro y un poco de emisión para leerse en la cueva.
## Uso: `GotaTinta3D.montar(botin, color)` al soltarla y `GotaTinta3D.al_paso(botin, delta, imantada, hacia)` en cada fotograma.

const R: float = 0.15                ## u: radio del cuerpo en su parte más gruesa (la esfera de antes también era 0,15)
const H: float = 0.36                ## u: alto de la espina del cuerpo
const ANILLOS: int = 22
const LADOS: int = 18
const BAJA_CUERPO: float = 0.17      ## u que el cuerpo baja respecto al nodo (el nodo flota a 0,3 del suelo: la base queda a ~0,13)
const CHARCO_R: float = 0.24         ## u: radio medio del charco
const ESTIRON_MAX: float = 0.9       ## al imantarse, la gota se alarga hasta × (1 + esto) hacia ella...
const VEL_ESTIRON: float = 14.0      ## ...cuando va a esta velocidad (u/s, la máxima del imán)
## Perfil (v de 0 a 1 por la espina): radio × R, desvío lateral × R y caída de la punta × H. La punta se dobla y cae un poco, como en el dibujo.
const PERFIL: Array = [
	[0.00, 0.80, 0.00, 0.0], [0.10, 0.97, 0.00, 0.0], [0.20, 1.00, 0.00, 0.0], [0.35, 0.95, 0.00, 0.0],
	[0.50, 0.78, 0.03, 0.0], [0.62, 0.58, 0.10, 0.0], [0.72, 0.43, 0.24, 0.02], [0.80, 0.33, 0.44, 0.06],
	[0.87, 0.26, 0.66, 0.12], [0.93, 0.20, 0.86, 0.20], [1.00, 0.13, 1.02, 0.30]]

const SHADER: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;   // sin cull: el torno se hace a mano y así no depende del sentido de los triángulos
uniform vec4 color : source_color = vec4(0.30, 0.55, 1.0, 1.0);
uniform float remolino = 1.0;       // 0 = sin remolino (el charco)
uniform float emision = 0.28;
void fragment() {
	vec3 base = color.rgb * 0.62;
	vec3 claro = mix(color.rgb, vec3(1.0), 0.25);
	float espiral = sin((UV.x * 2.0 + UV.y * 1.7) * 6.2831);
	float banda = smoothstep(0.55, 0.95, espiral) * remolino;
	float borde = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(mix(base, claro, banda * 0.75), base * 0.6, borde * 0.6);
	ROUGHNESS = 0.12;
	SPECULAR = 0.8;
	METALLIC = 0.0;
	EMISSION = color.rgb * emision * (0.6 + 0.4 * banda);
}
"""

static var _malla_cuerpo: ArrayMesh = null
static var _malla_charco: ArrayMesh = null
static var _shader: Shader = null


## Monta la gota en `b` (un MeshInstance3D: el `Botin3D`): le quita la malla propia y le cuelga el cuerpo y el charco como hijos. Guarda el color en la meta «color».
static func montar(b: MeshInstance3D, color: Color) -> void:
	b.mesh = null
	b.set_meta("color", color)
	var cuerpo := MeshInstance3D.new()
	cuerpo.name = "Cuerpo"
	cuerpo.mesh = malla_cuerpo()
	cuerpo.material_override = material(color, 1.0)
	cuerpo.position = Vector3(0.0, -BAJA_CUERPO, 0.0)
	b.add_child(cuerpo)
	var charco := MeshInstance3D.new()
	charco.name = "Charco"
	charco.mesh = malla_charco()
	charco.material_override = material(color, 0.0)
	charco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	charco.visible = false
	b.add_child(charco)


## Cada fotograma (lo llama `Botin3D._process`): el charco solo con la gota quieta, pegado al suelo y sin girar; al imantarse, el cuerpo apunta hacia ella y se estira
## según la velocidad. `suelo_y` es la altura del suelo bajo la gota; `hacia` el vector hasta ella; `vel` la del imán.
static func al_paso(b: Node3D, quieta: bool, suelo_y: float, imantada: bool, hacia: Vector3, vel: float) -> void:
	var cuerpo: Node3D = b.get_node_or_null("Cuerpo") as Node3D
	var charco: Node3D = b.get_node_or_null("Charco") as Node3D
	if charco != null:
		charco.visible = quieta
		if quieta:
			charco.rotation.y = -b.rotation.y                       # no gira con la gota
			charco.position.y = suelo_y + 0.012 - b.position.y          # ni flota con ella (`suelo_y` en el mismo espacio que `b.position`)
	if cuerpo == null:
		return
	if imantada and hacia.length() > 0.01:
		var k: float = clampf(vel / VEL_ESTIRON, 0.0, 1.0)
		var eje_y: Vector3 = hacia.normalized()
		var lado: Vector3 = eje_y.cross(Vector3.FORWARD if absf(eje_y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
		var eje_z: Vector3 = lado.cross(eje_y).normalized()
		var grosor: float = 1.0 / sqrt(1.0 + ESTIRON_MAX * k)          # conserva el volumen a ojo
		cuerpo.global_basis = Basis(lado * grosor, eje_y * (1.0 + ESTIRON_MAX * k), eje_z * grosor)
		cuerpo.position = Vector3.ZERO
	else:
		cuerpo.basis = Basis.IDENTITY
		cuerpo.position = Vector3(0.0, -BAJA_CUERPO, 0.0)


static func material(color: Color, remolino: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("remolino", remolino)
	m.set_shader_parameter("emision", 0.28 if remolino > 0.0 else 0.12)
	return m


## El perfil en `v` (0..1), interpolado: [radio, desvío lateral, caída] en unidades.
static func _perfil(v: float) -> Vector3:
	for i in range(PERFIL.size() - 1):
		var a: Array = PERFIL[i]
		var b: Array = PERFIL[i + 1]
		if v <= float(b[0]):
			var t: float = (v - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			return Vector3(lerpf(a[1], b[1], t) * R, lerpf(a[2], b[2], t) * R, lerpf(a[3], b[3], t) * H)
	var u: Array = PERFIL[-1]
	return Vector3(float(u[1]) * R, float(u[2]) * R, float(u[3]) * H)


## Punto de la espina en `v`.
static func _espina(v: float) -> Vector3:
	var p: Vector3 = _perfil(v)
	return Vector3(p.y, v * H - p.z, 0.0)


static func malla_cuerpo() -> ArrayMesh:
	if _malla_cuerpo != null:
		return _malla_cuerpo
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anillos: Array = []                    # [[Vector3 punto, Vector3 normal, Vector2 uv] × LADOS+1] por anillo
	for i in range(ANILLOS + 1):
		var v: float = float(i) / float(ANILLOS)
		var c: Vector3 = _espina(v)
		var tg: Vector3 = (_espina(minf(v + 0.02, 1.0)) - _espina(maxf(v - 0.02, 0.0))).normalized()
		var bz := Vector3(0, 0, 1)
		var nx: Vector3 = bz.cross(tg).normalized()
		var r: float = _perfil(v).x
		var fila: Array = []
		for j in range(LADOS + 1):
			var a: float = TAU * float(j) / float(LADOS)
			var dir: Vector3 = nx * cos(a) + bz * sin(a)
			fila.append([c + dir * r, dir, Vector2(float(j) / float(LADOS), v)])
		anillos.append(fila)
	for i in range(ANILLOS):
		for j in range(LADOS):
			var q: Array = [anillos[i][j], anillos[i][j + 1], anillos[i + 1][j + 1], anillos[i + 1][j]]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_normal(q[idx][1])
				st.set_uv(q[idx][2])
				st.add_vertex(q[idx][0])
	# Tapa de abajo (plana) y punta (cerrada en la espina).
	var c0: Vector3 = _espina(0.0)
	var c1: Vector3 = _espina(1.0) + (_espina(1.0) - _espina(0.97)).normalized() * _perfil(1.0).x
	for j in range(LADOS):
		for tri in [[c0, anillos[0][j][0], anillos[0][j + 1][0], Vector3.DOWN], [c1, anillos[ANILLOS][j + 1][0], anillos[ANILLOS][j][0], Vector3.ZERO]]:
			var n: Vector3 = tri[3]
			if n == Vector3.ZERO:
				n = (tri[1] + tri[2] - 2.0 * c1).normalized()
			for k in [0, 2, 1]:
				st.set_normal(n)
				st.set_uv(Vector2(0.5, 0.0 if tri[3] != Vector3.ZERO else 1.0))
				st.add_vertex(tri[k])
	# La gotita que cuelga de la punta.
	_esfera(st, c1 + Vector3(0.0, -R * 0.32, 0.0), R * 0.22, Vector3(1.0, 1.35, 1.0))     # pegada a la punta: cuelga, no flota suelta
	_malla_cuerpo = st.commit()
	return _malla_cuerpo


static func _esfera(st: SurfaceTool, centro: Vector3, radio: float, escala: Vector3) -> void:
	var n_lat: int = 8
	var n_lon: int = 12
	for i in range(n_lat):
		for j in range(n_lon):
			var pts: Array = []
			for d in [[0, 0], [0, 1], [1, 1], [1, 0]]:
				var th: float = PI * float(i + d[0]) / float(n_lat)
				var ph: float = TAU * float(j + d[1]) / float(n_lon)
				var nrm := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				pts.append([centro + nrm * radio * escala, nrm, Vector2(float(j + d[1]) / float(n_lon), float(i + d[0]) / float(n_lat))])
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_normal(pts[idx][1])
				st.set_uv(pts[idx][2])
				st.add_vertex(pts[idx][0])


## El charco: un disco plano de borde irregular, algo abombado en el centro.
static func malla_charco() -> ArrayMesh:
	if _malla_charco != null:
		return _malla_charco
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 28
	for j in range(n):
		var a0: float = TAU * float(j) / float(n)
		var a1: float = TAU * float(j + 1) / float(n)
		var p0: Vector3 = _borde_charco(a0)
		var p1: Vector3 = _borde_charco(a1)
		var cen := Vector3(0.0, 0.012, 0.0)
		for pt in [cen, p1, p0]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(pt.x / (CHARCO_R * 2.0) + 0.5, pt.z / (CHARCO_R * 2.0) + 0.5))
			st.add_vertex(pt)
	_malla_charco = st.commit()
	return _malla_charco


static func _borde_charco(a: float) -> Vector3:
	var r: float = CHARCO_R * (1.0 + 0.16 * sin(3.0 * a + 0.4) + 0.09 * sin(5.0 * a + 1.3) + 0.05 * sin(8.0 * a))
	return Vector3(cos(a) * r, 0.0, sin(a) * r)
