extends Node3D
## BANCO DE PRUEBAS DE LA CASCADA (24/10, agua estilo Zelda: Echoes of Wisdom). Un escalón de agua que cae a una charca con salida, montado con el MISMO dibujo del agua que el juego
## (AguaRender3D con filtro y refracción) y el lecho de cantos (LechoRio3D), SIN tocar ningún mapa de juego. Lo usan las capturas (`captura_agua_cascada_eow.gd`) y la prueba
## (`prueba_agua_cascada_eow.gd`). Se instancia con `preload`, sin `class_name`.
##
## Plano (8 × 8 casillas): arriba (norte) la meseta (M = manantial, 2 = suelo del escalón); debajo la charca (r) con la salida a la derecha (s). La caída mira al sur, hacia la
## cámara del juego, y mide 3 casillas de ancho (x 2-4): es el borde entre las filas 2 y 3.
##   ########
##   ##MMM###
##   ##222###
##   #rrrrrrs
##   #rrrrrrs
##   #rrrrrrs
##   #rrrrrrs
##   ########

const S: float = 2.3                      ## lado de casilla
const NIVEL: float = 1.15                 ## alto de un nivel de tierra
const SUB: int = 3
const NIVEL_AGUA_CHARCA: float = -0.1     ## Y de la superficie de la charca (la salida la mantiene)
const FONDO_CHARCA: float = -NIVEL        ## Y del lecho de la charca (1 nivel por debajo de la superficie)
const CAUDAL_MANANTIAL: float = 1.4       ## u³/s por casilla de manantial
const MURO_SOBRE_AGUA: float = 0.25       ## lo que sobresale el borde de piedra sobre el agua (visual)
const INCLINACION_CAMARA: float = 60.0    ## la de la maqueta del juego (PruebaTest2.INCLINACION)
const MAPA: PackedStringArray = [
	"########",
	"##MMM###",
	"##222###",
	"#rrrrrrs",
	"#rrrrrrs",
	"#rrrrrrs",
	"#rrrrrrs",
	"########",
]
const FILA_CAIDA: int = 3                 ## primera fila de la charca: la caída está en su borde norte

var script_render: GDScript = null        ## otro script del dibujo del agua (para comparar con una copia anterior); null = AguaRender3D
var escalon_niveles: float = 2.0         ## altura de la caída en niveles de tierra (1-2)
var agua: AguaSim3D = null
var render: MeshInstance3D = null         ## el dibujo del agua (AguaRender3D, o la copia que dé `script_render`)
var camara: Camera3D = null
var _suelo: Node3D = null
var _mat_lecho: ShaderMaterial = null


## Monta el banco (escena, simulación, dibujo del agua). `niveles` = altura del escalón.
func montar(niveles: float = 2.0) -> void:
	escalon_niveles = niveles
	_escena()
	_suelo = Node3D.new()
	add_child(_suelo)
	_mat_lecho = LechoRio3D.crear_material(0.78)
	agua = AguaSim3D.new()
	agua.configurar(MAPA[0].length(), MAPA.size(), SUB, S, _y_suelo, _es_pared)
	for y in range(MAPA.size()):
		for x in range(MAPA[y].length()):
			var c := Vector2i(x, y)
			_bloque(c)
			match MAPA[y][x]:
				"r":
					agua.llenar_casilla(c, NIVEL_AGUA_CHARCA)
				"s":
					agua.fijar_nivel(c, NIVEL_AGUA_CHARCA)
				"M":
					agua.fuente_en(c, CAUDAL_MANANTIAL)
	render = script_render.new() if script_render != null else AguaRender3D.new()
	add_child(render)
	render.call("enlazar", agua)
	render.call("enlazar_lecho", _mat_lecho)


func ancho_u() -> float:
	return float(MAPA[0].length()) * S


## Centro (mundo) del pie de la caída: el borde entre la meseta y la charca, en medio del ancho de la caída, a la altura de la charca.
func pie_caida() -> Vector3:
	return Vector3(3.5 * S, NIVEL_AGUA_CHARCA, float(FILA_CAIDA) * S)


## Coloca la cámara ortogonal con la inclinación del juego mirando a `foco` con el tamaño dado.
func encuadrar(foco: Vector3, tam: float, incl: float = INCLINACION_CAMARA) -> void:
	var e: float = deg_to_rad(90.0 - incl)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	camara.size = tam
	camara.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 40.0)


func _physics_process(delta: float) -> void:
	if agua != null:
		agua.paso(delta)
		agua.cambios()          # en el juego las usa el Lanzador; aquí solo se vacían


func _escena() -> void:
	camara = Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.far = 200.0
	add_child(camara)
	encuadrar(Vector3(3.5 * S, 0.0, 4.0 * S), 12.0)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sol.shadow_enabled = true
	add_child(sol)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _y_suelo(c: Vector2i) -> float:
	match MAPA[c.y][c.x]:
		"M", "2":
			return NIVEL_AGUA_CHARCA + escalon_niveles * NIVEL
		"r", "s":
			return FONDO_CHARCA
		_:
			return 0.0


func _es_pared(c: Vector2i) -> bool:
	return MAPA[c.y][c.x] == "#"


func _bloque(c: Vector2i) -> void:
	var l: String = MAPA[c.y][c.x]
	var techo: float = _y_suelo(c)
	if l == "#":
		# el borde es bajo (a la altura de la charca o de la meseta, según el lado) para que la cámara vea el agua sin muros delante
		techo = NIVEL_AGUA_CHARCA + (escalon_niveles * NIVEL if c.y < FILA_CAIDA else 0.0) + MURO_SOBRE_AGUA
	var alto: float = techo - FONDO_CHARCA + 2.0 * NIVEL
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(S, alto, S)
	var mat := StandardMaterial3D.new()          # los costados son de piedra lisa (el material del lecho proyecta en planta y estiraría la textura)
	if l == "#":
		mat.albedo_color = Color(0.22, 0.3, 0.2) if (c.x + c.y) % 2 == 0 else Color(0.24, 0.32, 0.22)
	else:
		mat.albedo_color = Color(0.36, 0.40, 0.42)
	b.material = mat
	m.mesh = b
	m.position = Vector3((c.x + 0.5) * S, techo - alto * 0.5, (c.y + 0.5) * S)
	_suelo.add_child(m)
	if l != "#":
		# la cara de arriba, con el lecho de cantos (el que ve el agua)
		var tapa := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(S, S)
		q.material = _mat_lecho
		tapa.mesh = q
		tapa.position = Vector3((c.x + 0.5) * S, techo + 0.005, (c.y + 0.5) * S)
		_suelo.add_child(tapa)
