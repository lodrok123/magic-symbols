class_name VfxTierra
extends ElementoVfx

## TIERRA del kit luminoso (19/10) + VFX DE MATERIA SÓLIDA (21/10, docs/PLAN_EOW_VISUAL.md §4).
## La tierra no brilla: es opaca y pesada. Rampa marrón oscuro → tierra → ocre claro, polvo que se mezcla (no aditivo) y movimiento lento.
##
## DIBUJO COMO MATERIA (lo nuevo): la tierra se lee como terrones y bloques, no como humo. Piezas facetadas (caras planas, aristas vivas, color por cara
## de la paleta: `Paleta3D` TIERRA / TIERRA_FLANCO / PIEDRA) con los MISMOS ids y medidas que pide `arte/meshy/PROMPTS_ELEMENTOS.md` §1:
##   terron_0..5          terrón que vuela (0,25–0,45 u, origen en su centro)             · lo usa el PROYECTIL (uno al azar)
##   cascote_0..3         cascote del impacto (0,1–0,2 u, origen en su centro)            · lo usa el IMPACTO (3–5 que saltan y se quedan ~1,5 s)
##   bloque_tierra_0..2   bloque que emerge (0,9 × 1,0 × 0,9 u, origen en el centro de la BASE, cara de arriba plana) · muro, columna, barrera y el bloque pisable
##   pincho_tierra_0..1   estaca que sale del suelo (0,3 × 0,9 u, origen en la base)      · la «esfera» quieta de tierra
## CÓMO ENGANCHAN LOS GLB DE MESHY (ya instalados en `arte/meshy/piezas/`, 22/10: terron_0..5, cascote_0..3, bloque_tierra_0..2, pincho_tierra_0..1): `pieza(id)` busca, por este orden,
##   1. una lámina `res://arte/meshy/piezas/elem_tierra.glb` con un nodo de malla llamado como el id (ya orientada, a escala y con el origen puesto, como la
##      lámina «puzle»), o
##   2. un GLB suelto `res://arte/meshy/piezas/<id>.glb` (se hornea una vez a la medida de `MEDIDA` y se coloca en su origen: `ModeloElemento`; el bloque
##      se estira por eje a 0,9 × 1,0 × 0,9 —la cara de arriba pisable queda a 1,0 u—, los pinchos se ajustan por el alto, el resto por el lado mayor),
##   3. y si no hay ninguno, la PRIMITIVA facetada de este archivo. El Juego llama igual en los tres casos (mismo método que `PiezaPuzle3D` / `PiezaFuego3D`).
## `VfxTierra.usar_modelos = false` fuerza las primitivas; `VfxTierra.hay_modelo(id)` dice si hay modelo; `VfxTierra._modelos[id] = <Mesh>` fuerza uno (pruebas).
##
## QUÉ DIBUJA CADA MOMENTO (todo es visual: no cambia lógica ni colisiones):
##   · VUELO    `proyectil`: un terrón facetado (de 6, al azar) que rueda sobre un eje al azar, del tamaño de la caja de golpe del proyectil (2·r_u),
##              y un poco de polvo que se queda atrás.
##   · IMPACTO  `impacto`: 3–5 cascotes que saltan, caen al suelo (un rebote), se quedan `T_REPOSO` s y se hunden; más polvo pardo (`VfxPuzle3D.polvo`).
##   · QUIETAS  `emerger`: bloques que SALEN DEL SUELO de abajo arriba (empiezan enterrados, suben con un pequeño rebote y polvo), aguantan lo que dura
##              el hechizo y se hunden. `vestir_bloque`: lo mismo para el bloque pisable del Lanzador (4 trozos que suben por delante de la caja).
## Todos los números están en las constantes de abajo, a la vista.

# ---------------------------------------------------------------------------------------------------------------------------------
# Parámetros
# ---------------------------------------------------------------------------------------------------------------------------------
const RUTA_MODELOS: String = "res://arte/meshy/piezas/"
const HOJA_MODELOS: String = "elem_tierra"

## Medida de cada pieza (X, Y, Z) en unidades de juego (casilla = 2,3 u; la jugadora ~1). Son las de PROMPTS_ELEMENTOS.md.
const MEDIDA: Dictionary = {
	"terron_0": Vector3(0.34, 0.32, 0.38), "terron_1": Vector3(0.45, 0.28, 0.40), "terron_2": Vector3(0.30, 0.30, 0.30),
	"terron_3": Vector3(0.28, 0.36, 0.30), "terron_4": Vector3(0.40, 0.40, 0.40), "terron_5": Vector3(0.25, 0.25, 0.30),
	"cascote_0": Vector3(0.18, 0.12, 0.15), "cascote_1": Vector3(0.12, 0.10, 0.14), "cascote_2": Vector3(0.20, 0.14, 0.12), "cascote_3": Vector3(0.10, 0.10, 0.10),
	"bloque_tierra_0": Vector3(0.9, 1.0, 0.9), "bloque_tierra_1": Vector3(0.9, 0.95, 0.9), "bloque_tierra_2": Vector3(0.85, 1.0, 0.9),
	"pincho_tierra_0": Vector3(0.3, 0.9, 0.3), "pincho_tierra_1": Vector3(0.26, 0.75, 0.26),
}
const N_TERRONES: int = 6
const N_CASCOTES: int = 4
const N_BLOQUES: int = 3
const N_PINCHOS: int = 2

## VUELO
const TERRON_ESCALA: float = 1.0           ## diámetro del terrón = 2·r_u · esto (r_u = semieje en vuelo = la caja de golpe)
const TERRON_GIRO: float = 5.0             ## rad/s con que rueda
const POLVO_VUELO_N: int = 14              ## partículas de polvo que deja atrás

## IMPACTO
const CASCOTES_MIN: int = 3
const CASCOTES_MAX: int = 5
const CASCOTE_ESCALA_MIN: float = 0.8      ## los cascotes escalan con el impacto (esc), entre estos dos
const CASCOTE_ESCALA_MAX: float = 2.0
const CASCOTE_SALTO_MIN: float = 2.5       ## velocidad vertical al saltar (u/s)
const CASCOTE_SALTO_MAX: float = 4.5
const CASCOTE_LATERAL_MIN: float = 1.2     ## velocidad horizontal (u/s)
const CASCOTE_LATERAL_MAX: float = 3.2
const GRAVEDAD: float = 14.0
const CASCOTE_REBOTES: int = 1
const T_REPOSO: float = 1.5                ## s que se quedan en el suelo antes de hundirse
const T_HUNDE: float = 0.45                ## s que tardan en hundirse
const POLVO_IMPACTO: float = 0.55          ## radio del polvo del impacto = esto · esc (u)
const SUELO_FALTA: float = 0.9             ## si no se encuentra suelo, cae esta altura por debajo del punto de impacto

## FORMAS QUIETAS
const BLOQUE_ALTO: float = 1.0             ## alto de una pieza `bloque_tierra` (u): los pisos se apilan de a uno
const BLOQUE_ANCHO: float = 0.9
const PISOS_MAX: int = 3
const MAX_BLOQUES: int = 18                ## por hechizo (las formas grandes se recortan)
const T_EMERGE: float = 0.4                ## s que tarda un bloque en salir
const RETARDO_MAX: float = 0.3             ## los bloques no salen todos a la vez: hasta este retardo
const RETARDO_PISO: float = 0.12           ## y cada piso espera un poco al de abajo
const T_HUNDE_BLOQUE: float = 0.5
const EMERGE_ESCALA_INI: float = 0.75      ## el bloque nace un poco más pequeño y se asienta
const POLVO_BLOQUE_N: int = 6
const PINCHOS_ESFERA: int = 3              ## estacas alrededor del bloque central de una «esfera» quieta
const ANILLO_BARRERA: float = 1.3          ## radio del círculo de bloques = r_u · esto (barrera)
const ANILLO_PULSO: float = 3.0            ## ídem para el pulso (corro)
const ANILLO_MAX: float = 4.0

## Colores por cara (Paleta3D). La mayoría de caras son tierra, alguna es piedra incrustada.
const PROB_PIEDRA_TERRON: float = 0.12
const PROB_PIEDRA_BLOQUE: float = 0.15

static var usar_modelos: bool = true
static var vestir_bloques: bool = true     ## false = el bloque pisable del Lanzador vuelve a dibujarse como la caja de siempre
static var _modelos: Dictionary = {}       ## id -> Mesh o null (se mira el disco una vez por id; las pruebas pueden poner uno)
static var _prim: Dictionary = {}          ## id -> ArrayMesh (primitivas, una vez por id)
static var _hoja: Dictionary = {}          ## nombre del nodo -> Mesh de la lámina `elem_tierra.glb` (null = no hay lámina)
static var _hoja_leida: bool = false
static var _horneado: Dictionary = {}       ## id -> true: su malla es un GLB suelto ya horneado a la medida (no hace falta escalarla)
static var _mat_solido: StandardMaterial3D = null


## Gira sobre un eje cualquiera (el terrón que rueda). Un nodo con _process en vez de un tween en bucle: muere con su padre.
class Rueda extends Node3D:
	var eje: Vector3 = Vector3.UP
	var w: float = 5.0
	func _process(delta: float) -> void:
		rotate(eje, w * delta)


## Un cascote suelto: vuela con gravedad, rebota, se queda en el suelo `t_reposo` s y se hunde. Se libera solo (nada queda vivo).
class Cascote extends Node3D:
	var vel: Vector3 = Vector3.ZERO
	var giro: Vector3 = Vector3.ZERO
	var suelo: float = 0.0
	var apoyo: float = 0.04               ## cuánto sube su centro sobre el suelo en reposo
	var t_reposo: float = 1.5
	var esc_base: Vector3 = Vector3.ONE
	var fase: int = 0                     ## 0 vuela · 1 reposa · 2 se hunde
	var _t: float = 0.0
	var _rebotes: int = 0
	func _process(delta: float) -> void:
		match fase:
			0:
				vel.y -= VfxTierra.GRAVEDAD * delta
				position += vel * delta
				rotation += giro * delta
				if vel.y < 0.0 and position.y <= suelo + apoyo:
					position.y = suelo + apoyo
					if _rebotes < VfxTierra.CASCOTE_REBOTES and absf(vel.y) > 1.0:
						_rebotes += 1
						vel = Vector3(vel.x * 0.5, -vel.y * 0.3, vel.z * 0.5)
						giro *= 0.5
					else:
						fase = 1
						_t = 0.0
						vel = Vector3.ZERO
						giro = Vector3.ZERO
			1:
				_t += delta
				if _t >= t_reposo:
					fase = 2
					_t = 0.0
			_:
				_t += delta
				var k: float = clampf(_t / VfxTierra.T_HUNDE, 0.0, 1.0)
				position.y = suelo + apoyo - k * (apoyo + 0.12)
				scale = esc_base * (1.0 - 0.5 * k)
				if k >= 1.0:
					queue_free()


# ---------------------------------------------------------------------------------------------------------------------------------
# El elemento del kit (rampa y perfil; sin cambios)
# ---------------------------------------------------------------------------------------------------------------------------------

func rampa() -> Array:
	return [[0.0, Color(0.30, 0.20, 0.13)], [0.35, Color(0.51, 0.35, 0.2)], [0.7, Color(0.74, 0.55, 0.35)], [1.0, Color(0.86, 0.72, 0.5)]]


func perfil() -> Dictionary:
	return {"luz": Color(0.85, 0.65, 0.4), "charco": Color(0.6, 0.42, 0.25), "aro": Color(0.75, 0.6, 0.4),
		"particula": [Color(0.8, 0.65, 0.45, 1.0), Color(0.55, 0.4, 0.26, 1.0), Color(0.35, 0.25, 0.16, 0.0)],
		"particula_aditiva": false, "particula_albedo": Color(1.0, 1.0, 1.0, 1.0), "marca": "",
		"mult": {"velocidad": 0.3, "suave": 0.5, "potencia": 0.8}}


# ---------------------------------------------------------------------------------------------------------------------------------
# Piezas: modelo de Meshy o primitiva facetada
# ---------------------------------------------------------------------------------------------------------------------------------

static func ids() -> PackedStringArray:
	return PackedStringArray(MEDIDA.keys())


## ¿Hay modelo de Meshy para esta pieza (en la lámina o suelto)? Las pruebas lo usan para saber qué se va a ver.
static func hay_modelo(id: String) -> bool:
	return usar_modelos and _modelo(id) != null


## Origen en la base (bloques y pinchos) o en el centro (terrones y cascotes).
static func _origen_base(id: String) -> bool:
	return id.begins_with("bloque_") or id.begins_with("pincho_")


## La pieza `id` como MeshInstance3D con su origen puesto y a su medida (`MEDIDA`). Marca `modelo` (meta) si salió de un GLB.
static func pieza(id: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = id
	var med: Vector3 = MEDIDA.get(id, Vector3.ONE)
	var m: Mesh = _modelo(id) if usar_modelos else null
	if m != null:
		mi.mesh = m
		mi.set_meta("modelo", true)
		if not _hoja.has(id) and not _horneado.has(id):
			# Malla suelta sin hornear (solo pruebas que fuerzan una): se escala a la medida y se pone el origen donde toca (la lámina y el GLB horneado ya vienen así).
			var caja: AABB = m.get_aabb()
			var k: float = maxf(med.x, maxf(med.y, med.z)) / maxf(maxf(caja.size.x, maxf(caja.size.y, caja.size.z)), 0.0001)
			mi.scale = Vector3.ONE * k
			var c: Vector3 = caja.position + caja.size * 0.5
			mi.position = Vector3(-c.x * k, (-caja.position.y * k) if _origen_base(id) else (-c.y * k), -c.z * k)
		return mi
	mi.mesh = _primitiva(id)
	mi.material_override = _material()
	mi.set_meta("modelo", false)
	return mi


## El Mesh del modelo (o null). Lámina primero, GLB suelto después; se cachea.
static func _modelo(id: String) -> Mesh:
	if _modelos.has(id):
		return _modelos[id]
	_leer_hoja()
	var m: Mesh = _hoja.get(id, null)
	if m == null:
		var suelto: Mesh = ModeloElemento.malla_glb(id)
		if suelto != null:
			# GLB suelto de Meshy: se hornea una vez a la medida del juego y con el origen que toca (ver ModeloElemento). `pieza` lo usa tal cual.
			var ajuste: String = "caja" if id.begins_with("bloque_") else ("alto" if id.begins_with("pincho_") else "mayor")
			m = ModeloElemento.hornear(suelto, MEDIDA.get(id, Vector3.ONE), ajuste, _origen_base(id))
			_horneado[id] = true
	_modelos[id] = m
	return m


static func _leer_hoja() -> void:
	if _hoja_leida:
		return
	_hoja_leida = true
	var ruta: String = "%s%s.glb" % [RUTA_MODELOS, HOJA_MODELOS]
	if not ResourceLoader.exists(ruta):
		return
	var ps: PackedScene = load(ruta) as PackedScene
	if ps == null:
		return
	var raiz: Node = ps.instantiate()
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		_hoja[String(n.name)] = (n as MeshInstance3D).mesh
	raiz.queue_free()


static func _material() -> StandardMaterial3D:
	if _mat_solido == null:
		_mat_solido = StandardMaterial3D.new()
		_mat_solido.vertex_color_use_as_albedo = true
		_mat_solido.vertex_color_is_srgb = true       # los colores de la Paleta3D son sRGB: sin esto se ven lavados (más claros)
		_mat_solido.albedo_color = Color.WHITE
		_mat_solido.roughness = 1.0
		_mat_solido.metallic = 0.0
	return _mat_solido


# ---------------------------------------------------------------------------------------------------------------------------------
# Primitivas facetadas (sombreado plano: una normal por cara; color por cara)
# ---------------------------------------------------------------------------------------------------------------------------------

static func _primitiva(id: String) -> ArrayMesh:
	if _prim.has(id):
		return _prim[id]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)                      # la misma forma siempre para el mismo id
	var med: Vector3 = MEDIDA.get(id, Vector3.ONE)
	var m: ArrayMesh = null
	if id.begins_with("terron_"):
		m = _roca(rng, med, 1, 0.16, false, PROB_PIEDRA_TERRON)
	elif id.begins_with("cascote_"):
		m = _roca(rng, med, 0, 0.28, true, 0.6)
	elif id.begins_with("bloque_"):
		m = _bloque(rng, med)
	else:
		m = _pincho(rng, med)
	_prim[id] = m
	return m


## Roca: icosaedro (20 caras; 80 si `sub` = 1) con los vértices desplazados al azar y ajustada a la caja `med`, centrada.
static func _roca(rng: RandomNumberGenerator, med: Vector3, sub: int, jitter: float, piedra: bool, prob_piedra: float) -> ArrayMesh:
	var t: float = (1.0 + sqrt(5.0)) / 2.0
	var v: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in range(v.size()):
		v[i] = (v[i] as Vector3).normalized()
	var f: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for _s in range(sub):
		var nf: Array = []
		var cache: Dictionary = {}
		for c in f:
			var m3: Array = []
			for k in range(3):
				var a: int = c[k]
				var b: int = c[(k + 1) % 3]
				var clave: int = mini(a, b) * 10000 + maxi(a, b)
				if not cache.has(clave):
					v.append(((v[a] as Vector3) + (v[b] as Vector3)).normalized())
					cache[clave] = v.size() - 1
				m3.append(cache[clave])
			nf.append([c[0], m3[0], m3[2]])
			nf.append([c[1], m3[1], m3[0]])
			nf.append([c[2], m3[2], m3[1]])
			nf.append([m3[0], m3[1], m3[2]])
		f = nf
	for i in range(v.size()):
		v[i] = (v[i] as Vector3) * (1.0 + rng.randf_range(-jitter, jitter))
	var cols: Array = _paleta(piedra)
	return _ensamblar(v, f, med, false, rng, cols[0], cols[1], prob_piedra)


## Bloque: prisma de 8 lados en 3 anillos (base áspera, medio algo más ancho, tapa PLANA = se pisa). Origen en el centro de la base.
static func _bloque(rng: RandomNumberGenerator, med: Vector3) -> ArrayMesh:
	var v: Array = []
	var alturas: Array = [0.0, 0.42, 1.0]
	var radios: Array = [0.40, 0.5, 0.45]
	var jit: Array = [0.08, 0.05, 0.015]       # la base es la más irregular (terrones de tierra), la tapa casi regular y plana
	for r in range(3):
		for i in range(8):
			var a: float = TAU * (float(i) + 0.5) / 8.0
			var rad: float = radios[r] * (1.0 + rng.randf_range(-jit[r], jit[r]))
			v.append(Vector3(cos(a) * rad, alturas[r], sin(a) * rad))
	v.append(Vector3(0.0, 1.0, 0.0))           # centro de la tapa (24)
	v.append(Vector3(0.0, 0.0, 0.0))           # centro de la base (25)
	var f: Array = []
	for r in range(2):
		for i in range(8):
			var a0: int = r * 8 + i
			var a1: int = r * 8 + (i + 1) % 8
			f.append([a0, a1, a1 + 8])
			f.append([a0, a1 + 8, a0 + 8])
	for i in range(8):
		f.append([24, 16 + i, 16 + (i + 1) % 8])
		f.append([25, (i + 1) % 8, i])
	return _ensamblar(v, f, med, true, rng, Paleta3D.TIERRA, Paleta3D.TIERRA_FLANCO, PROB_PIEDRA_BLOQUE)


## Estaca: cono de 5 caras con la punta algo torcida. Origen en el centro de la base.
static func _pincho(rng: RandomNumberGenerator, med: Vector3) -> ArrayMesh:
	var v: Array = []
	for i in range(5):
		var a: float = TAU * float(i) / 5.0 + rng.randf_range(-0.2, 0.2)
		v.append(Vector3(cos(a), 0.0, sin(a)) * 0.5 * (1.0 + rng.randf_range(-0.15, 0.15)))
	v.append(Vector3(rng.randf_range(-0.08, 0.08), 1.0, rng.randf_range(-0.08, 0.08)))     # punta (5)
	v.append(Vector3.ZERO)                                                                  # centro de la base (6)
	var f: Array = []
	for i in range(5):
		f.append([i, (i + 1) % 5, 5])
		f.append([6, (i + 1) % 5, i])
	return _ensamblar(v, f, med, true, rng, Paleta3D.TIERRA, Paleta3D.TIERRA_FLANCO, 0.1)


static func _paleta(piedra: bool) -> Array:
	return [Paleta3D.PIEDRA_OSCURA, Paleta3D.PIEDRA] if piedra else [Paleta3D.TIERRA, Paleta3D.TIERRA_FLANCO]


## Ajusta los vértices a la caja `med` (centrada en X/Z; en Y centrada o apoyada en y = 0 si `base`) y monta las caras con normal plana y color por cara.
## El orden de los vértices se corrige solo (Godot: cara delantera = sentido horario visto de fuera) mirando hacia dónde cae el centro de la cara.
static func _ensamblar(v: Array, f: Array, med: Vector3, base: bool, rng: RandomNumberGenerator, c_a: Color, c_b: Color, prob_piedra: float) -> ArrayMesh:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in v:
		lo = lo.min(p)
		hi = hi.max(p)
	var tam: Vector3 = hi - lo
	var k := Vector3(med.x / maxf(tam.x, 0.0001), med.y / maxf(tam.y, 0.0001), med.z / maxf(tam.z, 0.0001))
	var cx: float = (lo.x + hi.x) * 0.5
	var cz: float = (lo.z + hi.z) * 0.5
	var oy: float = lo.y if base else (lo.y + hi.y) * 0.5
	var w: Array = []
	for p in v:
		var q: Vector3 = p
		w.append(Vector3((q.x - cx) * k.x, (q.y - oy) * k.y, (q.z - cz) * k.z))
	var centro := Vector3(0.0, med.y * 0.5 if base else 0.0, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in f:
		var a: Vector3 = w[c[0]]
		var b: Vector3 = w[c[1]]
		var d: Vector3 = w[c[2]]
		var n: Vector3 = (b - a).cross(d - a)
		if n.dot((a + b + d) / 3.0 - centro) > 0.0:
			var tmp: Vector3 = b
			b = d
			d = tmp
			n = (b - a).cross(d - a)
		var col: Color = c_a.lerp(c_b, rng.randf() * 0.5)
		if rng.randf() < prob_piedra:
			col = Paleta3D.PIEDRA.lerp(Paleta3D.PIEDRA_OSCURA, rng.randf())
		var nn: Vector3 = (-n).normalized()
		for p in [a, b, d]:
			st.set_color(col)
			st.set_normal(nn)
			st.add_vertex(p)
	return st.commit()


# ---------------------------------------------------------------------------------------------------------------------------------
# VUELO
# ---------------------------------------------------------------------------------------------------------------------------------

## Dibuja el proyectil de tierra: un terrón (de 6, al azar) que rueda, del tamaño de la caja de golpe (2·r_u), y polvo detrás. Lo llama VfxElemento3D con
## `VfxKit3D.elemento` ya puesto a «tierra». Devuelve el terrón.
static func proyectil(seg: Node3D, _d: Vector3, r_u: float) -> MeshInstance3D:
	var rueda := Rueda.new()
	rueda.name = "TerronRueda"
	rueda.eje = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	if rueda.eje.length() < 0.1:
		rueda.eje = Vector3.UP
	rueda.w = TERRON_GIRO
	seg.add_child(rueda)
	var id: String = "terron_%d" % (randi() % N_TERRONES)
	var mi: MeshInstance3D = pieza(id)
	var med: Vector3 = MEDIDA[id]
	var k: float = (2.0 * r_u * TERRON_ESCALA) / maxf(med.x, maxf(med.y, med.z))
	mi.scale *= k
	mi.position *= k
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rueda.add_child(mi)
	# polvo que se queda atrás y cae (gravedad negativa), en coordenadas de mundo (`local_coords` = false en el kit)
	VfxKit3D.particulas(seg, Vector3.ZERO, POLVO_VUELO_N, 0.9, 0.16, 0.6, false, true, r_u * 0.8, -1.2, Vector3.UP, 120.0)
	return mi


# ---------------------------------------------------------------------------------------------------------------------------------
# IMPACTO
# ---------------------------------------------------------------------------------------------------------------------------------

## El terrón se rompe en el punto `pos`: `n` cascotes (por defecto 3–5) saltan, caen en `suelo` (y del suelo; NAN = sin dato) y se quedan `T_REPOSO` s,
## y sale una nube de polvo pardo. `esc` = el tamaño del impacto (Proyectil.esc). Devuelve los cascotes.
static func impacto(mundo: Node, pos: Vector3, esc: float, suelo: float = NAN, n: int = -1) -> Array:
	var res: Array = []
	if mundo == null or not is_instance_valid(mundo) or not (mundo is Node3D):
		return res
	var y_suelo: float = suelo if not is_nan(suelo) else pos.y - SUELO_FALTA
	var cuantos: int = n if n > 0 else randi_range(CASCOTES_MIN, CASCOTES_MAX)
	var k: float = clampf(esc, CASCOTE_ESCALA_MIN, CASCOTE_ESCALA_MAX)
	for i in range(cuantos):
		var c := Cascote.new()
		c.name = "CascoteVfx%d" % i
		var id: String = "cascote_%d" % (randi() % N_CASCOTES)
		var mi: MeshInstance3D = pieza(id)
		mi.scale *= k
		mi.position *= k
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.add_child(mi)
		var med: Vector3 = MEDIDA[id]
		c.esc_base = Vector3.ONE
		c.apoyo = med.y * k * 0.35
		c.suelo = y_suelo
		c.t_reposo = T_REPOSO * randf_range(0.9, 1.15)
		var a: float = TAU * (float(i) + randf()) / float(cuantos)
		c.vel = Vector3(cos(a), 0.0, sin(a)) * randf_range(CASCOTE_LATERAL_MIN, CASCOTE_LATERAL_MAX) + Vector3(0.0, randf_range(CASCOTE_SALTO_MIN, CASCOTE_SALTO_MAX), 0.0)
		c.giro = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		c.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		c.position = pos
		(mundo as Node3D).add_child(c)
		res.append(c)
	if mundo.is_inside_tree():
		VfxPuzle3D.polvo(mundo as Node3D, Vector3(pos.x, y_suelo + 0.05, pos.z), POLVO_IMPACTO * clampf(esc, 0.6, 3.0))
	return res


# ---------------------------------------------------------------------------------------------------------------------------------
# FORMAS QUIETAS: bloques que emergen del suelo
# ---------------------------------------------------------------------------------------------------------------------------------

## Monta en `raiz` (top_level, en coordenadas de mundo) los bloques de un volumen de tierra con los pies en `pie`:
##   «esfera» → un bloque central (con pisos según el alto) y `PINCHOS_ESFERA` estacas alrededor;  «barrera» → un círculo de bloques (r_u · ANILLO_BARRERA);
##   «pulso» → un círculo grande (r_u · ANILLO_PULSO).  Cada bloque empieza ENTERRADO (con la tapa a ras de suelo), sube con un pequeño rebote y polvo,
##   aguanta hasta casi `vida` y se hunde. Devuelve los bloques (MeshInstance3D).
static func emerger(raiz: Node3D, pie: Vector3, r_u: float, alto_u: float, vida: float, forma: String, esc: float) -> Array:
	var res: Array = []
	var pisos: int = clampi(roundi(alto_u / BLOQUE_ALTO), 1, PISOS_MAX) if forma != "pulso" else 1
	var puestos: Array = []                     # [posición xz relativa, piso0]
	if forma == "esfera":
		puestos.append(Vector2.ZERO)
	else:
		var radio: float = minf(r_u * (ANILLO_PULSO if forma == "pulso" else ANILLO_BARRERA), ANILLO_MAX)
		var n: int = clampi(ceili(TAU * radio / (BLOQUE_ANCHO * 1.05)), 5, 14)
		var a0: float = randf() * TAU
		for i in range(n):
			var a: float = a0 + TAU * float(i) / float(n)
			puestos.append(Vector2(cos(a), sin(a)) * radio)
	var total: int = 0
	var idx: int = 0
	for xz in puestos:
		for piso in range(pisos):
			if total >= MAX_BLOQUES:
				break
			total += 1
			res.append(_bloque_que_sale(raiz, pie, xz as Vector2, piso, vida, esc, idx))
		idx += 1
	if forma == "esfera":
		var rp: float = maxf(r_u, 0.5) * 1.1
		for i in range(PINCHOS_ESFERA):
			var a: float = TAU * (float(i) + randf_range(-0.2, 0.2)) / float(PINCHOS_ESFERA)
			res.append(_pincho_que_sale(raiz, pie, Vector2(cos(a), sin(a)) * rp, vida, esc, i))
	return res


static func _bloque_que_sale(raiz: Node3D, pie: Vector3, xz: Vector2, piso: int, vida: float, esc: float, orden: int) -> MeshInstance3D:
	var m: MeshInstance3D = pieza("bloque_tierra_%d" % (randi() % N_BLOQUES))
	m.name = "bloque_tierra_%d_%d" % [orden, piso]       # nombre único (Godot renombra los repetidos a «@MeshInstance3D@n»)
	m.set_meta("piso", piso)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var y_fin: float = pie.y + float(piso) * BLOQUE_ALTO * 0.94
	var y_ini: float = y_fin - float(piso + 1) * BLOQUE_ALTO         # enterrado del todo: la tapa de ese piso a ras del suelo de abajo
	m.position = Vector3(pie.x + xz.x, y_ini, pie.z + xz.y)
	m.rotation = Vector3(randf_range(-0.06, 0.06), randf() * TAU, randf_range(-0.06, 0.06))
	m.scale = Vector3.ONE * EMERGE_ESCALA_INI
	raiz.add_child(m)
	var retardo: float = randf() * RETARDO_MAX + float(piso) * RETARDO_PISO
	var espera: float = maxf(vida - retardo - T_EMERGE - T_HUNDE_BLOQUE, 0.1)
	var tw: Tween = m.create_tween()
	tw.tween_interval(retardo)
	tw.tween_callback(_polvillo.bind(raiz, Vector3(m.position.x, pie.y + 0.05, m.position.z), esc))
	tw.tween_property(m, "position:y", y_fin, T_EMERGE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "scale", Vector3.ONE, T_EMERGE)
	tw.tween_interval(espera)
	tw.tween_property(m, "position:y", y_ini, T_HUNDE_BLOQUE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(m.queue_free)
	return m


static func _pincho_que_sale(raiz: Node3D, pie: Vector3, xz: Vector2, vida: float, esc: float, orden: int) -> MeshInstance3D:
	var m: MeshInstance3D = pieza("pincho_tierra_%d" % (orden % N_PINCHOS))
	m.name = "pincho_tierra_%d" % orden
	var y_ini: float = pie.y - 1.0
	m.position = Vector3(pie.x + xz.x, y_ini, pie.z + xz.y)
	m.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
	raiz.add_child(m)
	var retardo: float = randf() * RETARDO_MAX
	var espera: float = maxf(vida - retardo - T_EMERGE - T_HUNDE_BLOQUE, 0.1)
	var tw: Tween = m.create_tween()
	tw.tween_interval(retardo)
	tw.tween_callback(_polvillo.bind(raiz, Vector3(m.position.x, pie.y + 0.05, m.position.z), esc))
	tw.tween_property(m, "position:y", pie.y - 0.05, T_EMERGE * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(espera)
	tw.tween_property(m, "position:y", y_ini, T_HUNDE_BLOQUE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(m.queue_free)
	return m


## Un poco de polvo al pie de un bloque que empieza a salir. Pone `VfxKit3D.elemento` a «tierra» solo durante la llamada (se llama diferida, de un tween).
static func _polvillo(padre: Node3D, pos: Vector3, esc: float) -> void:
	if padre == null or not is_instance_valid(padre) or not padre.is_inside_tree():
		return
	var antes: String = VfxKit3D.elemento
	VfxKit3D.elemento = "tierra"
	VfxKit3D.particulas(padre, pos, POLVO_BLOQUE_N, 0.7, 0.14 * esc, 0.9, false, false, 0.05, -1.0, Vector3.UP, 60.0)
	VfxKit3D.elemento = antes


## GANCHO del bloque pisable del Lanzador (`Lanzador3D.construir_tierra`): viste el Area3D `bloque` (origen en el centro de la caja `tam`) con 4 trozos
## `bloque_tierra` que llenan la casilla y suben, desfasados, desde dentro del suelo. La caja y la colisión no se tocan: el Lanzador solo oculta su
## BoxMesh. `pos_suelo` = punto del suelo bajo el bloque (para el polvo). Devuelve los trozos.
static func vestir_bloque(bloque: Node3D, tam: Vector3, pos_suelo: Vector3) -> Array:
	var res: Array = []
	var sx: float = tam.x * 0.5 / BLOQUE_ANCHO
	var sz: float = tam.z * 0.5 / BLOQUE_ANCHO
	var sy: float = tam.y / BLOQUE_ALTO
	for iz in range(2):
		for ix in range(2):
			var m: MeshInstance3D = pieza("bloque_tierra_%d" % (randi() % N_BLOQUES))
			m.name = "bloque_tierra_%d_%d" % [ix, iz]
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			var y_fin: float = -tam.y * 0.5
			var y_ini: float = y_fin - tam.y * 0.5
			m.scale = Vector3(sx, sy, sz)
			m.position = Vector3((float(ix) - 0.5) * tam.x * 0.5, y_ini, (float(iz) - 0.5) * tam.z * 0.5)
			m.rotation.y = float(randi() % 4) * PI * 0.5 + randf_range(-0.08, 0.08)
			bloque.add_child(m)
			var tw: Tween = m.create_tween()
			tw.tween_interval(randf() * 0.12)
			tw.tween_property(m, "position:y", y_fin, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			res.append(m)
	if bloque.is_inside_tree():
		VfxPuzle3D.polvo(bloque.get_parent() as Node3D, pos_suelo + Vector3(0.0, 0.05, 0.0), 0.7)
	return res
