class_name BlockFx
extends RefCounted

## PARTÍCULAS PARA LOS BLOQUES.
##
## En isométrico el volumen es un engaño: son dibujos planos colocados
## en rombo. Lo que sostiene el engaño no es el dibujo, es que las cosas
## OCURRAN en el sitio correcto — que el humo suba desde la cara de
## arriba del cubo, que las chispas salten de su borde. El cerebro da
## por buena la profundidad en cuanto ve algo comportarse con ella.
##
## Todo se construye por código y no como escenas .tscn a propósito: un
## emisor de partículas es puro ajuste numérico, y quince nodos casi
## iguales en el editor se desincronizan solos en cuanto cambias uno.

const FLAME: Texture2D = preload("res://art/particles/flame.png")
const SMOKE: Texture2D = preload("res://art/particles/smoke.png")
const SPARK: Texture2D = preload("res://art/particles/spark.png")
const DIRT: Texture2D = preload("res://art/particles/dirt.png")
const MAGIC: Texture2D = preload("res://art/particles/magic.png")

## Desde dónde emiten. No es el centro del nodo: es el centro de la cara
## SUPERIOR del cubo, que es la superficie que arde. Sale de la misma
## geometría que coloca los bloques, así que si un día cambia la escala
## esto la sigue sin tocar nada.
const TOP_FACE: Vector2 = Vector2(0.0, -IsoGrid.LEVEL * 0.35)

## La cara de arriba es un rombo, así que las partículas tienen que
## nacer repartidas en un óvalo ancho y bajo. Emitir desde un punto se
## nota muchísimo: delata que debajo no hay volumen.
const SPREAD: Vector3 = Vector3(24.0, 10.0, 0.0)


## --- Fuego continuo ---
## Mientras el bloque arde. Devuelve el emisor para poder pararlo.
static func flames(parent: Node2D) -> GPUParticles2D:
	var p := _make(parent, FLAME, 26)
	p.lifetime = 0.9

	var m := p.process_material as ParticleProcessMaterial
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 18.0
	m.initial_velocity_min = 26.0
	m.initial_velocity_max = 52.0
	m.gravity = Vector3(0.0, -40.0, 0.0)   # el fuego SUBE
	m.scale_min = 0.25
	m.scale_max = 0.6
	m.color = Color(1.0, 0.72, 0.28, 1.0)

	# Se apaga al final de su vida en vez de desaparecer de golpe.
	m.color_ramp = _ramp([
		Color(1.0, 0.95, 0.6, 1.0),
		Color(1.0, 0.45, 0.1, 0.85),
		Color(0.5, 0.15, 0.05, 0.0),
	])
	return p


## --- Humo continuo ---
static func smoke(parent: Node2D) -> GPUParticles2D:
	var p := _make(parent, SMOKE, 14)
	p.lifetime = 2.2

	var m := p.process_material as ParticleProcessMaterial
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 25.0
	m.initial_velocity_min = 12.0
	m.initial_velocity_max = 26.0
	m.gravity = Vector3(6.0, -18.0, 0.0)   # deriva un poco de lado
	m.scale_min = 0.3
	m.scale_max = 0.9
	# Crece al subir: es lo que hace que una columna de humo se lea como
	# columna y no como una fila de manchas iguales.
	m.scale_curve = _curve([0.35, 1.0])
	m.color_ramp = _ramp([
		Color(0.35, 0.33, 0.32, 0.0),
		Color(0.45, 0.43, 0.42, 0.55),
		Color(0.6, 0.6, 0.6, 0.0),
	])
	return p


## --- Estallidos de un solo uso ---
## Se borran solos al terminar. Sirven para el instante en que algo
## CAMBIA: el bloque se desmorona, el hielo estalla, la runa disipa.
##
## NO cuelgan del bloque, sino de la escena. Es importante: media de
## estas explosiones ocurre porque el bloque DESAPARECE (se disipa, se
## desmorona por el tope de 20), y un hijo se va con su padre. Colgadas
## del bloque no se vería ni una sola de las que más importan.
static func burst(origen: Node2D, tipo: String) -> void:
	var ajustes: Dictionary = {
		"ceniza": {"tex": SMOKE, "n": 18, "col": Color(0.3, 0.29, 0.28, 0.8),
			"vel": 60.0, "grav": -10.0, "vida": 1.4},
		"chispas": {"tex": SPARK, "n": 22, "col": Color(1.0, 0.9, 0.4, 1.0),
			"vel": 130.0, "grav": 220.0, "vida": 0.7},
		"chispas_azules": {"tex": SPARK, "n": 22, "col": Color(0.55, 0.8, 1.0, 1.0),
			"vel": 130.0, "grav": 220.0, "vida": 0.7},
		"tierra": {"tex": DIRT, "n": 16, "col": Color(0.62, 0.42, 0.28, 1.0),
			"vel": 95.0, "grav": 280.0, "vida": 0.8},
		"magia": {"tex": MAGIC, "n": 20, "col": Color(0.78, 0.72, 0.95, 1.0),
			"vel": 70.0, "grav": -30.0, "vida": 1.1},
	}
	if not ajustes.has(tipo):
		return
	if not origen.is_inside_tree():
		return
	var cfg: Dictionary = ajustes[tipo]

	var escena: Node = origen.get_tree().current_scene
	var p := _make(escena, cfg["tex"], int(cfg["n"]))
	p.global_position = origen.global_position + TOP_FACE
	p.one_shot = true
	p.explosiveness = 1.0          # todas a la vez, no goteando
	p.lifetime = float(cfg["vida"])

	var m := p.process_material as ParticleProcessMaterial
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 180.0               # en todas direcciones
	m.initial_velocity_min = float(cfg["vel"]) * 0.4
	m.initial_velocity_max = float(cfg["vel"])
	m.gravity = Vector3(0.0, float(cfg["grav"]), 0.0)
	m.scale_min = 0.2
	m.scale_max = 0.5
	m.color = cfg["col"]

	# Se limpia solo. Sin esto, cada bloque quemado dejaría un emisor
	# muerto en la escena para siempre.
	p.finished.connect(p.queue_free)


## --- Estallidos de un hechizo, teñidos de SU propio elemento ---
##
## A diferencia de burst(), aquí el color no sale de una tabla fija: lo
## trae quien llama (RuneData.color), así que un elemento nuevo sale bien
## sin tocar esta función ni la lista de arriba. Dos variantes porque el
## lanzamiento y el impacto no se leen igual: lanzar es un chispazo
## contenido que sale del mago; impactar es un estallido más grande que
## sale disparado desde donde golpea.

## El chispazo de LANZAR. Pequeño y hacia arriba, como si el gesto del
## mago soltara la magia en vez de que algo explote.
static func spell_cast(origen: Node2D, color: Color) -> void:
	_spell_burst(origen, color, 14, 90.0, -30.0, 0.45, 0.18)


## El estallido de IMPACTAR. Más partículas, más rápidas, en todas
## direcciones: es la diferencia entre soltar algo y que choque.
static func spell_impact(origen: Node2D, color: Color) -> void:
	_spell_burst(origen, color, 24, 150.0, 40.0, 0.6, 0.32)


static func _spell_burst(origen: Node2D, color: Color, n: int, vel: float,
		grav: float, escala: float, vida: float) -> void:
	if not origen.is_inside_tree():
		return

	var escena: Node = origen.get_tree().current_scene
	var p := _make(escena, MAGIC, n)
	p.position = Vector2.ZERO   # el llamador ya nos da el sitio exacto
	p.global_position = origen.global_position
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = vida

	var m := p.process_material as ParticleProcessMaterial
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 180.0
	m.initial_velocity_min = vel * 0.4
	m.initial_velocity_max = vel
	m.gravity = Vector3(0.0, grav, 0.0)
	m.scale_min = 0.15
	m.scale_max = escala
	# Nace opaca y se desvanece: el mismo truco de burst(), pero con el
	# color que traiga el elemento en vez de uno fijo.
	m.color_ramp = _ramp([
		Color(color.r, color.g, color.b, 1.0),
		Color(color.r, color.g, color.b, 0.0),
	])

	p.finished.connect(p.queue_free)


## La ESTELA de lo que viaja. Es la firma visual del sello flecha: un
## hechizo quieto no deja rastro, uno que se mueve sí, y esa diferencia
## se lee incluso en escala de grises. Cuelga del propio hechizo (muere
## con él) pero las partículas se quedan en el mundo (local_coords=false
## en _make), así que lo que queda atrás dibuja el camino recorrido.
static func trail(padre: Node2D, color: Color) -> GPUParticles2D:
	var p := _make(padre, MAGIC, 22)
	p.position = Vector2.ZERO
	p.show_behind_parent = true   # detrás del dibujo del hechizo, sin tocar z_index
	p.lifetime = 0.35

	var m := p.process_material as ParticleProcessMaterial
	m.emission_shape_scale = Vector3(5.0, 5.0, 0.0)   # sale de un punto, no de un óvalo
	m.direction = Vector3(0.0, 0.0, 0.0)
	m.spread = 180.0
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 12.0
	m.gravity = Vector3.ZERO
	m.scale_min = 0.25
	m.scale_max = 0.5
	m.scale_curve = _curve([1.0, 0.0])   # se encoge al alejarse: forma una cola
	m.color_ramp = _ramp([
		Color(color.r, color.g, color.b, 0.9),
		Color(color.r, color.g, color.b, 0.0),
	])
	return p


## --- Fontanería ---

static func _make(parent: Node, tex: Texture2D, cantidad: int) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.texture = tex
	p.amount = cantidad
	p.position = TOP_FACE
	p.local_coords = false   # las partículas no siguen al bloque si se mueve

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 1.0
	m.emission_shape_scale = SPREAD
	m.angle_min = -180.0
	m.angle_max = 180.0
	p.process_material = m

	parent.add_child(p)
	return p


static func _ramp(colores: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in range(colores.size()):
		g.add_point(float(i) / float(colores.size() - 1), colores[i])

	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _curve(valores: Array) -> CurveTexture:
	var c := Curve.new()
	for i in range(valores.size()):
		c.add_point(Vector2(float(i) / float(valores.size() - 1), valores[i]))

	var t := CurveTexture.new()
	t.curve = c
	return t
