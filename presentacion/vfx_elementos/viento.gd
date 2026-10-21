class_name VfxViento
extends ElementoVfx

## VIENTO del kit luminoso (19/10) + CINTAS Y COSAS ARRASTRADAS (21/10, docs/PLAN_EOW_VISUAL.md §4).
## El viento no es un objeto: son CINTAS curvas, finas, semitransparentes y blanco-verdosas que giran en espiral alrededor de una dirección, y hojas y briznas
## que arrastran. No hace falta malla de Meshy (`arte/meshy/PROMPTS_ELEMENTOS.md` §3): las cintas se hacen aquí con una malla de tira y las hojas son
## TARJETAS 2D (billboards) de un atlas.
##   · ATLAS: `presentacion/vfx/viento_atlas.png` (512 × 512, 4 × 4 casillas: filas 0–1 hojas verdes y otoñales, fila 2 briznas y semillas, fila 3 trazos de
##     remolino). Si todavía no existe se genera uno sencillo por código (placeholder: elipses y arcos de las mismas filas) y la ruta queda preparada: al
##     copiar el PNG, el juego lo usa sin tocar nada (`atlas()`).
## QUÉ DIBUJA CADA MOMENTO (visual: no cambia lógica ni colisiones; nunca opaco, nunca más del `CINTA_ALFA` de alfa):
##   · VUELO    `proyectil`: `CINTAS_VUELO` cintas que giran en espiral detrás de la cabeza (más abiertas hacia atrás), `HOJAS_VUELO` hojas/briznas que
##              arrastran y unas motas blancas.
##   · IMPACTO  `remolino`: un remolino de cintas que sube, se ABRE (crece) y se desvanece en `T_REMOLINO` s, con hojas lanzadas hacia fuera.
##   · QUIETAS  `torbellino` (tornado, corro de viento): cintas en espiral que SUBEN y giran durante la vida del hechizo, con fundido de entrada y de salida.
## Todos los números están en las constantes, a la vista.

const RUTA_ATLAS: String = "res://presentacion/vfx/viento_atlas.png"
const ATLAS_LADO: int = 512
const CASILLAS: int = 4

## Color de las cintas (blanco verdoso) y su alfa máximo.
const COLOR_CINTA: Color = Color(0.85, 1.0, 0.92)
const CINTA_ALFA: float = 0.42
const CINTA_SEGMENTOS: int = 28
const CINTA_INCLINA: float = 0.5           ## rad: la tira no es vertical del todo, se abre hacia fuera (se ve también desde arriba)

## VUELO
const CINTAS_VUELO: int = 3
const CINTA_LARGO_K: float = 5.0           ## largo de la estela = r_u · esto (mínimo CINTA_LARGO_MIN)
const CINTA_LARGO_MIN: float = 0.9
const CINTA_RADIO_INI_K: float = 0.45      ## radio de la espiral junto a la cabeza = r_u · esto
const CINTA_RADIO_FIN_K: float = 1.4       ## y en la cola
const CINTA_ANCHO_K: float = 0.7           ## ancho de la tira = r_u · esto
const CINTA_VUELTAS: float = 1.3
const CINTA_GIRO: float = 7.0              ## rad/s
const HOJAS_VUELO: int = 4
const MOTAS_VUELO: int = 10

## IMPACTO
const CINTAS_REMOLINO: int = 3
const T_REMOLINO: float = 0.9
const REMOLINO_ALTO: float = 1.8           ## u de alto del remolino (·esc, limitado)
const REMOLINO_ABRE: float = 2.0           ## cuánto se abre (escala X/Z final)
const HOJAS_REMOLINO: int = 5

## QUIETAS
const CINTAS_TORBELLINO: int = 4
const HOJAS_TORBELLINO: int = 6
const T_FUNDIDO_ENTRADA: float = 0.3
const T_FUNDIDO_SALIDA: float = 0.6
const TORBELLINO_GIRO: float = 4.0

const HOJA_TAM_MIN: float = 0.09           ## lado de una tarjeta de hoja (u)
const HOJA_TAM_MAX: float = 0.26

static var usar_atlas: bool = true         ## false = el atlas sencillo generado por código (el de antes de Meshy) y sin tarjetas de remolino: para comparar y para las pruebas
static var _atlas: Texture2D = null
static var _atlas_ph: Texture2D = null
static var _mat_hojas: Dictionary = {}     ## (casilla, atlas real o no) -> material de tarjeta

const REMOLINO_TARJETAS: int = 2           ## tarjetas de la fila 3 del atlas (remolinos blancos) en el remolino de impacto
const TORBELLINO_TARJETAS: int = 3         ## y en el tornado / corro
const TARJETA_REMOLINO_K: float = 2.6      ## una tarjeta de remolino es tantas veces más grande que una hoja
const TARJETA_REMOLINO_MAX: float = 0.7


## Gira sobre su eje Y local (las cintas en espiral). Un nodo con _process en vez de un tween en bucle: muere con su padre.
class Rueda extends Node3D:
	var w: float = 6.0
	func _process(delta: float) -> void:
		rotate_object_local(Vector3.UP, w * delta)


func rampa() -> Array:
	return [[0.0, Color(0.62, 0.8, 0.78)], [0.4, Color(0.78, 0.92, 0.88)], [0.8, Color(0.92, 0.98, 0.95)], [1.0, Color(1.0, 1.0, 1.0)]]


func perfil() -> Dictionary:
	return {"luz": Color(0.8, 0.95, 0.9), "charco": Color(0.7, 0.9, 0.85), "aro": Color(0.9, 1.0, 0.95),
		"particula": [Color(1.0, 1.0, 1.0, 0.9), Color(0.8, 0.95, 0.9, 0.7), Color(0.7, 0.85, 0.8, 0.0)],
		"particula_aditiva": false, "particula_albedo": Color(1.0, 1.0, 1.0, 1.0), "marca": "",
		"mult": {"velocidad": 1.8, "suave": 2.0, "potencia": 0.6, "ondula": 1.5},
		"fijar": {"opacidad": 0.55}}


# ---------------------------------------------------------------------------------------------------------------------------------
# Cintas: malla de tira en hélice
# ---------------------------------------------------------------------------------------------------------------------------------

## Material de cintas: sin luz, mezcla alfa, a dos caras y sin escribir profundidad (varias cintas se cruzan sin parpadear). Alfa por vértice × `albedo.a`.
static func material_cinta(alfa: float = CINTA_ALFA) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(COLOR_CINTA.r, COLOR_CINTA.g, COLOR_CINTA.b, alfa)
	return mat


## Una cinta en hélice alrededor del eje Y: nace en y = 0 y llega a y = `sentido`·`largo` (−1 = hacia atrás, +1 = hacia arriba), con el radio yendo de
## `r_ini` a `r_fin`, `vueltas` vueltas, `ancho` de tira (se afila en las puntas) y fase inicial `fase`. El alfa por vértice sube y baja (sin cortes).
static func malla_cinta(largo: float, r_ini: float, r_fin: float, vueltas: float, ancho: float, fase: float, sentido: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in range(CINTA_SEGMENTOS + 1):
		var s: float = float(i) / float(CINTA_SEGMENTOS)
		var a: float = fase + s * vueltas * TAU
		var r: float = lerpf(r_ini, r_fin, s)
		var c := Vector3(cos(a) * r, sentido * s * largo, sin(a) * r)
		var radial := Vector3(cos(a), 0.0, sin(a))
		var dir: Vector3 = (Vector3.UP * cos(CINTA_INCLINA) + radial * sin(CINTA_INCLINA)).normalized()
		var mitad: float = ancho * 0.5 * pow(sin(PI * s), 0.6)
		verts.append(c - dir * mitad)
		verts.append(c + dir * mitad)
		var alfa: float = pow(sin(PI * s), 0.8)
		cols.append(Color(1, 1, 1, alfa))
		cols.append(Color(1, 1, 1, alfa))
		if i > 0:
			var b: int = i * 2
			idx.append_array(PackedInt32Array([b - 2, b - 1, b, b - 1, b + 1, b]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## `n` cintas repartidas en fase alrededor de un eje (nodo `Rueda` hijo de `padre`). Devuelve la rueda.
static func _cintas(padre: Node3D, n: int, largo: float, r_ini: float, r_fin: float, vueltas: float, ancho: float, sentido: float, w: float, mat: Material) -> Rueda:
	var rueda := Rueda.new()
	rueda.name = "VientoRueda"
	rueda.w = w
	padre.add_child(rueda)
	for i in range(n):
		var mi := MeshInstance3D.new()
		mi.name = "cinta_%d" % i
		mi.mesh = malla_cinta(largo * randf_range(0.8, 1.0), r_ini, r_fin, vueltas * randf_range(0.85, 1.15), ancho, TAU * float(i) / float(n) + randf_range(-0.3, 0.3), sentido)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rueda.add_child(mi)
	return rueda


## Eje con la Y local a lo largo de `dir` (las cintas se enroscan alrededor de ella).
static func _eje(padre: Node3D, dir: Vector3) -> Node3D:
	var eje := Node3D.new()
	eje.name = "VientoEje"
	var y: Vector3 = dir.normalized() if dir.length() > 0.001 else Vector3.UP
	var x: Vector3 = y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	eje.basis = Basis(x, y, x.cross(y).normalized())
	padre.add_child(eje)
	return eje


# ---------------------------------------------------------------------------------------------------------------------------------
# Hojas y briznas: tarjetas 2D del atlas
# ---------------------------------------------------------------------------------------------------------------------------------

## El atlas de hojas: el PNG de `presentacion/vfx/` si existe (y `usar_atlas`); si no, un placeholder generado por código (se cachea).
static func atlas() -> Texture2D:
	if usar_atlas:
		if _atlas == null and ResourceLoader.exists(RUTA_ATLAS):
			_atlas = load(RUTA_ATLAS) as Texture2D
		if _atlas != null:
			return _atlas
	if _atlas_ph == null:
		_atlas_ph = _atlas_placeholder()
	return _atlas_ph


## ¿Es el atlas de Meshy el que se está usando?
static func atlas_real() -> bool:
	return usar_atlas and atlas() == _atlas


## Placeholder sencillo con las mismas filas que el atlas real: hojas verdes, hojas otoñales, briznas y trazos de remolino. 128 px por casilla bastan.
static func _atlas_placeholder() -> Texture2D:
	var lado: int = 256
	var celda: int = lado / CASILLAS
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var verdes: Array = [Color(0.45, 0.72, 0.38), Color(0.55, 0.8, 0.42), Color(0.36, 0.62, 0.34), Color(0.62, 0.82, 0.5)]
	var otono: Array = [Color(0.9, 0.7, 0.25), Color(0.85, 0.5, 0.2), Color(0.78, 0.38, 0.18), Color(0.92, 0.8, 0.4)]
	for fila in range(CASILLAS):
		for col in range(CASILLAS):
			var cx: float = float(col * celda) + celda * 0.5
			var cy: float = float(fila * celda) + celda * 0.5
			var ang: float = float(col) * 0.7 + float(fila) * 0.3
			for py in range(celda):
				for px in range(celda):
					var x: float = float(px) - celda * 0.5
					var y: float = float(py) - celda * 0.5
					var u: float = x * cos(ang) + y * sin(ang)       # girado: cada casilla mira a un lado
					var v: float = -x * sin(ang) + y * cos(ang)
					var c := Color(0, 0, 0, 0)
					if fila < 2:                                   # hoja: elipse con punta
						var a: float = celda * 0.4
						var b: float = celda * (0.17 + 0.03 * float(col))
						if (u * u) / (a * a) + (v * v) / (b * b) < 1.0:
							c = (verdes if fila == 0 else otono)[col]
							if absf(v) < 1.5 and absf(u) < a:
								c = c.darkened(0.25)            # nervio
					elif fila == 2:                               # brizna: arco fino
						var arco: float = (u * u) / (celda * 1.6)
						if absf(v - arco + celda * 0.12) < 1.6 and absf(u) < celda * 0.42:
							c = Color(0.7, 0.8, 0.5)
					else:                                         # trazo de remolino: tramo de anillo blanco
						var r: float = sqrt(x * x + y * y)
						var an: float = atan2(y, x)
						if absf(r - celda * (0.28 + 0.04 * float(col))) < 2.2 and an > -1.0 + float(col) * 0.3 and an < 1.6 + float(col) * 0.3:
							c = Color(1, 1, 1, 0.55)
					if c.a > 0.0:
						img.set_pixel(col * celda + px, fila * celda + py, c)
	return ImageTexture.create_from_image(img)


## Material de una tarjeta de la casilla (col, fila): billboard, sin luz, con alfa. Uno por casilla, compartido. Hojas, hierbas y vilanos (filas 0–2) son
## opacos en el cuerpo y suaves en el borde: pasada previa de profundidad (se ordenan bien con las cintas, que no escriben profundidad). Los remolinos
## (fila 3) son blancos translúcidos: mezcla pura, sin profundidad.
static func _material_hoja(col: int, fila: int) -> StandardMaterial3D:
	var clave := Vector3i(col, fila, 1 if atlas_real() else 0)
	if _mat_hojas.has(clave):
		return _mat_hojas[clave]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if fila >= 3 else BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	if fila >= 3:
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = atlas()
	mat.uv1_scale = Vector3(1.0 / CASILLAS, 1.0 / CASILLAS, 1.0)
	mat.uv1_offset = Vector3(float(col) / CASILLAS, float(fila) / CASILLAS, 0.0)
	_mat_hojas[clave] = mat
	return mat


## Una tarjeta de hoja o brizna (filas 0–2 del atlas) de lado `tam`; con `remolino` = true, un remolino blanco (fila 3).
static func hoja(tam: float, n: int = 0, remolino: bool = false) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	var mi := MeshInstance3D.new()
	mi.name = ("remolino_%d" if remolino else "hoja_%d") % n
	mi.mesh = q
	mi.material_override = _material_hoja(randi() % CASILLAS, 3 if remolino else randi() % 3)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## `n` hojas colgadas de `rueda` sobre la hélice (a altura `sentido`·`largo`·s con el radio de la espiral ahí); `n_remolinos` más son tarjetas de
## remolino (fila 3 del atlas, solo con el atlas de Meshy).
static func _hojas_en(rueda: Node3D, n: int, largo: float, r_ini: float, r_fin: float, sentido: float, tam_ref: float, n_remolinos: int = 0) -> Array:
	var res: Array = []
	if not atlas_real():
		n_remolinos = 0
	for i in range(n + n_remolinos):
		var rem: bool = i >= n
		var s: float = randf_range(0.15, 0.95)
		var a: float = randf() * TAU
		var r: float = lerpf(r_ini, r_fin, s) * randf_range(0.8, 1.3)
		var tam: float = clampf(tam_ref * randf_range(0.7, 1.3), HOJA_TAM_MIN, HOJA_TAM_MAX)
		var h: MeshInstance3D = hoja(minf(tam * TARJETA_REMOLINO_K, TARJETA_REMOLINO_MAX) if rem else tam, i, rem)
		h.position = Vector3(cos(a) * r, sentido * s * largo, sin(a) * r)
		rueda.add_child(h)
		res.append(h)
	return res


# ---------------------------------------------------------------------------------------------------------------------------------
# VUELO
# ---------------------------------------------------------------------------------------------------------------------------------

## El proyectil de viento: cintas que se enroscan detrás de la cabeza, hojas arrastradas y motas. `d` = dirección del viaje. Lo llama VfxElemento3D con
## `VfxKit3D.elemento` ya puesto a «viento». Devuelve la rueda de las cintas.
static func proyectil(seg: Node3D, d: Vector3, r_u: float) -> Rueda:
	var eje: Node3D = _eje(seg, d)
	var largo: float = maxf(r_u * CINTA_LARGO_K, CINTA_LARGO_MIN)
	var r0: float = r_u * CINTA_RADIO_INI_K
	var r1: float = r_u * CINTA_RADIO_FIN_K
	var rueda: Rueda = _cintas(eje, CINTAS_VUELO, largo, r0, r1, CINTA_VUELTAS, r_u * CINTA_ANCHO_K, -1.0, CINTA_GIRO, material_cinta())
	_hojas_en(rueda, HOJAS_VUELO, largo, r0, r1, -1.0, r_u * 0.6)
	# motas blancas que se arrastran (en coordenadas de mundo: se quedan atrás)
	VfxKit3D.particulas(seg, Vector3.ZERO, MOTAS_VUELO, 0.8, 0.1, 0.5, false, true, r_u, 0.0, Vector3.UP, 180.0)
	return rueda


# ---------------------------------------------------------------------------------------------------------------------------------
# IMPACTO
# ---------------------------------------------------------------------------------------------------------------------------------

## Remolino de impacto en `pos` (suelo si se conoce): cintas que suben, se abren y se desvanecen en `T_REMOLINO` s, con hojas que salen disparadas.
## Se libera solo. `esc` = tamaño del impacto (Proyectil.esc).
static func remolino(mundo: Node, pos: Vector3, esc: float, suelo: float = NAN) -> Node3D:
	if mundo == null or not is_instance_valid(mundo) or not (mundo is Node3D):
		return null
	var raiz := Node3D.new()
	raiz.name = "RemolinoViento"
	(mundo as Node3D).add_child(raiz)
	raiz.position = Vector3(pos.x, suelo if not is_nan(suelo) else pos.y, pos.z)
	var k: float = clampf(esc, 0.6, 2.5)
	var alto: float = REMOLINO_ALTO * k
	var mat: StandardMaterial3D = material_cinta()
	# `abre` lleva la escala (la rueda gira con rotate_object_local, que con escala no uniforme deforma): el remolino nace estrecho y se abre
	var abre := Node3D.new()
	abre.name = "RemolinoAbre"
	abre.scale = Vector3(0.4, 0.5, 0.4)
	raiz.add_child(abre)
	var rueda: Rueda = _cintas(abre, CINTAS_REMOLINO, alto, 0.25 * k, 0.55 * k, 1.6, 0.5 * k, 1.0, 11.0, mat)
	var hojas: Array = _hojas_en(rueda, HOJAS_REMOLINO, alto, 0.25 * k, 0.55 * k, 1.0, 0.2 * k, REMOLINO_TARJETAS)
	var tw: Tween = raiz.create_tween().set_parallel(true)
	tw.tween_property(abre, "scale", Vector3(REMOLINO_ABRE, 1.0, REMOLINO_ABRE), T_REMOLINO).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rueda, "w", 4.0, T_REMOLINO)
	tw.tween_property(mat, "albedo_color:a", 0.0, T_REMOLINO * 0.6).set_delay(T_REMOLINO * 0.4)
	for h in hojas:
		var y0: float = (h as MeshInstance3D).position.y * 0.6
		(h as MeshInstance3D).position.y = y0
		tw.tween_property(h, "position:y", y0 + alto * 0.7, T_REMOLINO)
		tw.tween_property(h, "scale", Vector3.ZERO, T_REMOLINO * 0.4).set_delay(T_REMOLINO * 0.6)
	tw.chain().tween_callback(raiz.queue_free)
	return raiz


# ---------------------------------------------------------------------------------------------------------------------------------
# FORMAS QUIETAS
# ---------------------------------------------------------------------------------------------------------------------------------

## Tornado / corro de viento en `padre` (en el pie): cintas en espiral que suben alrededor de `eje_dir` (hacia arriba si no viaja), con fundido de entrada y
## salida; vive `vida` s y se libera solo. Más ancho arriba que abajo. Devuelve el eje (con `Rueda` y las cintas).
static func torbellino(padre: Node3D, eje_dir: Vector3, r_u: float, alto_u: float, vida: float) -> Node3D:
	var eje: Node3D = _eje(padre, eje_dir)
	var alto: float = maxf(alto_u, maxf(r_u * 2.5, 1.6))
	var mat: StandardMaterial3D = material_cinta(0.0)
	var rueda: Rueda = _cintas(eje, CINTAS_TORBELLINO, alto, r_u * 0.4, r_u * 1.25, 1.5, maxf(r_u * 0.9, 0.35), 1.0, TORBELLINO_GIRO, mat)
	var hojas: Array = _hojas_en(rueda, HOJAS_TORBELLINO, alto, r_u * 0.4, r_u * 1.25, 1.0, r_u * 0.6, TORBELLINO_TARJETAS)
	VfxKit3D.particulas(eje, Vector3.ZERO, 16, 0.8, 0.1, 0.5, false, false, r_u, 0.0, Vector3.UP, 180.0)
	var v: float = maxf(vida, T_FUNDIDO_ENTRADA + T_FUNDIDO_SALIDA + 0.1)
	var tw: Tween = eje.create_tween()
	# las hojas (material compartido, no se pueden aclarar una a una) entran y salen por tamaño; las cintas, por alfa
	# (`parallel()` une un tweener al ANTERIOR: en cada paso el primero va sin él y los demás con él)
	tw.tween_property(mat, "albedo_color:a", CINTA_ALFA, T_FUNDIDO_ENTRADA)
	for h in hojas:
		(h as MeshInstance3D).scale = Vector3.ZERO
		tw.parallel().tween_property(h, "scale", Vector3.ONE, T_FUNDIDO_ENTRADA)
	tw.tween_interval(v - T_FUNDIDO_ENTRADA - T_FUNDIDO_SALIDA)
	tw.tween_property(mat, "albedo_color:a", 0.0, T_FUNDIDO_SALIDA)
	for h in hojas:
		tw.parallel().tween_property(h, "scale", Vector3.ZERO, T_FUNDIDO_SALIDA)
	tw.tween_callback(eje.queue_free)
	return eje
