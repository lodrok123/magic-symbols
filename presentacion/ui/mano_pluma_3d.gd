class_name ManoPluma3D
extends ManoPluma2D
## La mano de escribir con MODELO 3D (`mano_agarre` + `manga_agarre` + `pluma`), para sustituir a `ManoPluma2D` en el libro nuevo (Pipeline, 16/10).
##
## POR QUÉ HEREDA DE `ManoPluma2D`. El Juego (y `TintaPluma2D`) hablan con la mano por `apuntar()`, `punta()`, `mostrar()`, `ocultar()` y `pose`. Heredando,
## esas funciones, el retardo de 60 ms, la inclinación por velocidad y las poses REPOSO / ESCRIBIENDO / LEVANTADA son LITERALMENTE las mismas: no hay una
## segunda copia que se desajuste con el tiempo. Solo cambia cómo se PINTA (`_ready` y `_aplicar`). Una variable tipada `ManoPluma2D` admite una
## `ManoPluma3D` sin tocar nada.
##
## CÓMO SE USA (idéntico a la 2D; el Juego ya no necesita más que elegir qué clase instancia):
##     var mano: ManoPluma2D = ManoPluma3D.new() if ManoPluma3D.disponible() else ManoPluma2D.new()
##     capa_dibujo.add_child(mano)             # hijo del libro; `capa_z` (100) la pone por encima de los trazos
##     mano.apuntar(punto, is_drawing)         # cada fotograma, como siempre
##     mano.punta()                            # la punta DE VERDAD (con el retardo): de aquí sale la tinta
##     mano.ocultar() / mano.mostrar()
## Si faltan los GLB (`disponible()` = false) no pinta nada, pero `punta()` sigue funcionando, así que la tinta no se rompe.
##
## UN 3D ENCIMA DE UNA UI 2D: un `SubViewport` transparente (mundo 3D propio, MSAA 4×) con una cámara ORTOGONAL, y un `Sprite2D` que muestra su textura. El
## sprite es un nodo 2D normal: lleva `z_index`, hereda la escala y la rotación del libro y se oculta con `visible`. Una cámara ortogonal (sin perspectiva)
## no deforma con la distancia: un metro mide `PX_POR_M` píxeles en cualquier punto, y la mano pesa lo mismo en la esquina que en el centro.
##
## DÓNDE ESTÁ LA PUNTA, POR CONSTRUCCIÓN. La punta del plumín es el origen 3D (`_ancla`) y la cámara se coloca para que ese punto caiga en `PUNTA_VP`
## (píxel del viewport); el sprite se desplaza `−PUNTA_VP` y el nodo se coloca en `punta()`. Así la punta cae en `punta()` SIN depender de la lámina ni de su
## escala: ya no hay un `PUNTA_PX` que recalcular cuando cambia el libro. Lo que tiene que ser exacto es el punto que da el libro (`apuntar`), y eso es
## cosa de `spellbook.gd`. La prueba lo mide en la imagen renderizada (`prueba_mano_pluma_3d.gd`).
##
## ESCRIBIR / NO ESCRIBIR. Escribiendo (`Pose.ESCRIBIENDO`) el plumín está en la página (altura 0); en cualquier otra pose la mano se levanta (`LEVANTE_ALTO` m: 12 cm;
## en REPOSO, un 35 % de eso). La sombra (un óvalo difuso) se aleja y se aclara al levantarse, como la de la mano 2D. 16/10 (Pablo): la pluma se queda SIEMPRE VISIBLE
## (`pluma_siempre` = true); con `pluma_siempre = false` solo se ve escribiendo, como en el primer encargo del Juego.

const PX_POR_M: float = 520.0                     ## píxeles de pantalla por metro del modelo (la mano mide 0,5 m → ~260 px, parecida a la 2D)
const TAM_VP: Vector2i = Vector2i(560, 560)       ## tamaño del viewport en píxeles; igual que las capas 2D (560 × 560)
const PUNTA_VP: Vector2 = Vector2(170.0, 170.0)   ## píxel del viewport donde cae la punta del plumín: deja sitio a la mano y la manga, que vienen de abajo a la derecha
const INCLINACION_CAMARA: float = 28.0            ## grados que la cámara se aparta de la vertical, para que se lea el volumen (0 = plano, como un dibujo)
const YAW_BASE: float = -135.0                    ## grados: hacia dónde miran los dedos (arriba-izquierda), como la mano 2D, que viene de abajo a la derecha
const LEVANTE_ALTO: float = 0.12                  ## m que sube la mano cuando no escribe (alzada = 1)
const SOMBRA_ALPHA: float = 0.40                  ## opacidad de la sombra con la mano en la página
const SOMBRA_ALPHA_ALTA: float = 0.28             ## y con la mano levantada

## Se aplica al nodo entero (sprite y sombra): 1 = el tamaño de diseño. Sustituye al `escala` de la 2D, que era «0,55 sobre un PNG de 560».
@export var capa_z: int = 100                      ## `z_index` del nodo: por encima de los trazos y de lo demás del libro
@export var pluma_siempre: bool = true                ## true = la pluma se ve en todas las poses (pedido de Pablo, 16/10) · false = solo escribiendo

var _vp: SubViewport
var _s_vista: Sprite2D
var _camara: Camera3D
var _ancla: Node3D                               ## en la punta del plumín; sube al levantar la mano
var _brazo: Node3D                               ## mano + manga
var _pluma: MeshInstance3D
var _mano_3d: MeshInstance3D
var _manga_3d: MeshInstance3D
static var _base_camara: Basis = _calcular_base_camara()


func _init() -> void:
	escala = 1.0


## `true` si están los GLB de la mano, la manga y la pluma. El Juego lo mira para decidir entre esta clase y `ManoPluma2D`.
static func disponible() -> bool:
	return PiezaEscritura3D.malla_modelo("mano_agarre") != null \
		and PiezaEscritura3D.malla_modelo("manga_agarre") != null \
		and PiezaEscritura3D.malla_modelo("pluma") != null


static func _calcular_base_camara() -> Basis:
	var a: float = deg_to_rad(INCLINACION_CAMARA)
	# La cámara mira hacia abajo y hacia el norte de la página (−Z): derecha de pantalla = +X, arriba de pantalla = (0, sen a, −cos a).
	return Basis.looking_at(Vector3(0.0, -cos(a), -sin(a)), Vector3.UP)


## Dónde cae, en píxeles respecto a la punta y SIN escalar, un punto 3D (con la punta en el origen). Estática y pura: la prueba la usa.
static func proyectar(p: Vector3) -> Vector2:
	var c: Vector3 = _base_camara.inverse() * p
	return Vector2(c.x, -c.y) * PX_POR_M


func _ready() -> void:
	z_index = capa_z
	visible = visible_al_inicio
	if not disponible():
		push_warning("ManoPluma3D: faltan los GLB de arte/meshy/escritura/ (mano_agarre.glb, pluma.glb); no se pinta la mano, la punta sigue funcionando")
		return
	_montar()


func _montar() -> void:
	# --- El viewport transparente con su mundo 3D propio (no ve ni mancha el mundo del juego).
	_vp = SubViewport.new()
	_vp.name = "vp"
	_vp.size = TAM_VP
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE      # oculto → no se renderiza nada
	add_child(_vp)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.80, 0.82)
	_camara = Camera3D.new()
	_camara.name = "camara"
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = float(TAM_VP.y) / PX_POR_M                  # alto visible en metros
	_camara.near = 0.05
	_camara.far = 20.0
	_camara.environment = env
	_vp.add_child(_camara)
	# La cámara se desplaza en su propio plano para que la punta (el origen) caiga en PUNTA_VP en vez de en el centro.
	var ox: float = (float(TAM_VP.x) * 0.5 - PUNTA_VP.x) / PX_POR_M
	var oy: float = (PUNTA_VP.y - float(TAM_VP.y) * 0.5) / PX_POR_M
	_camara.transform = Transform3D(_base_camara, _base_camara * Vector3(ox, oy, 6.0))
	var luz := DirectionalLight3D.new()
	luz.name = "luz"
	luz.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	luz.light_energy = 0.9
	_vp.add_child(luz)
	# --- El modelo: la punta del plumín es el origen; la mano, la manga y la pluma cuelgan de ahí.
	_ancla = Node3D.new()
	_ancla.name = "ancla"
	_vp.add_child(_ancla)
	_brazo = Node3D.new()
	_brazo.name = "brazo"
	_ancla.add_child(_brazo)
	_mano_3d = PiezaEscritura3D.crear("mano_agarre")
	_manga_3d = PiezaEscritura3D.crear("manga_agarre")
	_brazo.add_child(_mano_3d)
	_brazo.add_child(_manga_3d)
	_pluma = PiezaEscritura3D.crear("pluma")
	_ancla.add_child(_pluma)
	# --- La sombra (2D, debajo) y el sprite que enseña el viewport (2D, encima).
	_s_sombra = Sprite2D.new()
	_s_sombra.name = "sombra"
	_s_sombra.texture = _textura_sombra()
	add_child(_s_sombra)
	_s_vista = Sprite2D.new()
	_s_vista.name = "mano3d"
	_s_vista.centered = false
	_s_vista.offset = -PUNTA_VP                                  # la punta del plumín queda en el origen del nodo
	_s_vista.texture = _vp.get_texture()
	_s_vista.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sh := Shader.new()
	# La manga sale por la esquina de abajo a la derecha del viewport: se desvanece hacia ahí para que no se vea el corte (igual que la 2D).
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat f = (UV.x + UV.y) * 0.5;\n\tCOLOR.a *= 1.0 - smoothstep(0.52, 0.62, f);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_s_vista.material = mat
	add_child(_s_vista)
	_aplicar()


## Un óvalo difuso (negro con borde transparente) para la sombra de la mano.
static func _textura_sombra() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0)])
	g.offsets = PackedFloat32Array([0.15, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _poner_texturas() -> void:
	pass                     # la 3D no tiene texturas por pose: la pose cambia la altura y qué se ve


func _aplicar() -> void:
	position = _punta_actual
	if _ancla == null:
		return
	_s_vista.scale = Vector2.ONE * escala
	var alto: float = LEVANTE_ALTO * _alzada
	_ancla.position = Vector3(0.0, alto, 0.0)
	# La pluma gira con la velocidad (`_giro`) y la mano un poco menos (GIRO_MANO), como una muñeca que no es rígida. Girar en pantalla en el sentido de las
	# agujas del reloj es girar −θ sobre +Y (con la cámara mirando hacia abajo y +X a la derecha).
	var enganche: Transform3D = PiezaEscritura3D.pluma_en_agarre()
	var yaw_mano: Basis = Basis(Vector3.UP, deg_to_rad(YAW_BASE - _giro * GIRO_MANO))
	var yaw_pluma: Basis = Basis(Vector3.UP, deg_to_rad(YAW_BASE - _giro))
	# La mano se coloca para que el plumín, que está en `enganche.origin` en el espacio de la mano, caiga en el origen del ancla.
	_brazo.transform = Transform3D(yaw_mano, -(yaw_mano * enganche.origin))
	_pluma.transform = Transform3D(yaw_pluma * enganche.basis, Vector3.ZERO)
	_pluma.visible = pluma_siempre or pose == Pose.ESCRIBIENDO
	# La sombra: un óvalo bajo la mano (a medio camino entre el plumín y la muñeca), alargado en la dirección del brazo; más lejos y más clara al levantarla.
	var centro: Vector3 = _brazo.transform * Vector3(0.0, 0.0, -0.22)
	var dir_pant: Vector2 = proyectar(yaw_mano * Vector3(0.0, 0.0, -1.0))
	_s_sombra.position = proyectar(Vector3(centro.x, 0.0, centro.z)) * escala + SOMBRA_ESCRIBIENDO.lerp(SOMBRA_LEVANTADA, _alzada) * 0.5 * escala
	_s_sombra.rotation = dir_pant.angle()
	_s_sombra.scale = Vector2(2.2, 1.3) * escala
	_s_sombra.modulate.a = lerpf(SOMBRA_ALPHA, SOMBRA_ALPHA_ALTA, _alzada)
