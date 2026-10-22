class_name PozoCauce3D
extends Node3D
## POZO DE UNA CUENCA (13.9, 15/10; Pipeline). Dibuja la casilla `c` ABIERTA (`Terreno3D.es_cuenca`) como lo que es para la simulación y
## para el jugador: un pozo con fondo. Por qué existe: la simulación pone el suelo de `c` en `alto_agua − LECHO_AGUA` (el mismo lecho del
## río, ~0,94 u bajo el suelo de al lado) pero la maqueta dibujaba un bloque macizo a 0,1 u bajo el suelo: el agua quedaba TAPADA por ese
## bloque y solo asomaba cuando ya casi rebosaba. Ahora no hay tapa: hay fondo, cuatro paredes de piedra y un bordillo.
##
## Qué lleva (todo en coordenadas del mundo en Y; el nodo se coloca en el centro XZ de la casilla, con y = 0):
##   - el FONDO: un cuadrado a `y_fondo` (el lecho; el agua lo pinta AguaRender3D encima desde la simulación).
##   - cuatro PAREDES verticales de piedra de `y_fondo` a `y_borde`, algo más oscuras abajo (humedad / profundidad).
##   - un BORDILLO de piedra clara sobre el borde (`ALTO_BORDILLO` de alto, `ANCHO_BORDILLO` hacia dentro), como el de la foto de referencia.
## Cada lado se puede ocultar (`mostrar_lado`): entre dos pozos vecinos no hay pared (es una sola piscina) ni donde la casilla de al lado
## es agua de río (el lecho es el mismo). El orden de los lados es el de `LADOS`.
##
## Sin tapa: el pozo se ve desde arriba. La pared lleva un hueco de 0,004 u respecto al borde de la casilla para no pelear (z-fighting) con
## la cara lateral del bloque de tierra de al lado, que sube hasta el suelo pero solo desde y = 0.

const LADOS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]   ## +Z, +X, −Z, −X (giro 0°, 90°, 180°, 270°)
const ANCHO_BORDILLO: float = 0.16
const ALTO_BORDILLO: float = 0.05
const HUECO: float = 0.004
## Color de la pared abajo (multiplica la piedra): más oscuro y frío, para que se lea la profundidad.
const COLOR_PIE: Color = Color(0.50, 0.58, 0.64)

var lado: float = 2.3
var y_fondo: float = 0.0
var y_borde: float = 1.0
var _paredes: Array[MeshInstance3D] = []
var _humedad: Array[MeshInstance3D] = []     ## una marca oscura por pared (hijas de cada Lado: giran y se ocultan con él)
var _y_max: float = -1000.0                  ## la cota más alta que ha alcanzado el agua: la marca no baja aunque el agua baje


## `piedra`: el material triplanar de piedra (se duplica para la pared y el bordillo); `mat_fondo`: el del lecho.
## `fondo_malla` (cauce hondo, 22/10): el fondo ya hecho (con la oclusión en el color de vértice) en vez del cuadrado liso; sus vértices van en el espacio del nodo, a `y_fondo`.
func construir(p_lado: float, p_y_fondo: float, p_y_borde: float, piedra: StandardMaterial3D, mat_fondo: Material, fondo_malla: Mesh = null) -> void:
	lado = p_lado
	y_fondo = p_y_fondo
	y_borde = p_y_borde
	var r: float = lado * 0.5
	# Fondo.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat_fondo)
	_quad(st, Vector3(-r, y_fondo, -r), Vector3(r, y_fondo, -r), Vector3(r, y_fondo, r), Vector3(-r, y_fondo, r), Vector3.UP)
	var fondo := MeshInstance3D.new()
	fondo.name = "Fondo"
	fondo.mesh = fondo_malla if fondo_malla != null else st.commit()
	fondo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fondo)
	# Materiales de la pared (con color por vértice) y del bordillo.
	var m_pared: StandardMaterial3D = piedra.duplicate() as StandardMaterial3D
	m_pared.vertex_color_use_as_albedo = true
	m_pared.albedo_color = piedra.albedo_color * Color(0.9, 0.9, 0.92)
	var m_borde: StandardMaterial3D = piedra.duplicate() as StandardMaterial3D
	m_borde.albedo_color = piedra.albedo_color * Color(1.45, 1.4, 1.32)
	var malla_lado: ArrayMesh = _malla_lado(r, m_pared, m_borde)
	for i in range(LADOS.size()):
		var mi := MeshInstance3D.new()
		mi.name = "Lado%d" % i
		mi.mesh = malla_lado
		mi.rotation.y = float(i) * PI * 0.5
		add_child(mi)
		_paredes.append(mi)
		_humedad.append(_marca_humedad(mi, r))


## 16/10 (diario 97, Pipeline): LÍNEA DE HUMEDAD. Una lámina oscura y translúcida pegada a la cara interior de cada pared, de `y_fondo` a la
## cota más alta que alcanzó el agua; sube con el nivel y se queda oscura al bajar (la piedra mojada tarda en secarse). Encima, un filo algo
## más claro justo en la cota máxima: la «raya» que deja el agua. Se actualiza con `poner_nivel(y_agua)`.
func _marca_humedad(lado_mi: MeshInstance3D, r: float) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.1, 0.17, 0.26, 0.42)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(r * 2.0, 1.0)
	var mi := MeshInstance3D.new()
	mi.name = "Humedad"
	mi.mesh = q
	mi.material_override = m
	mi.rotation.y = PI                                      # el QuadMesh mira a +Z; la cara interior de la pared mira a −Z
	mi.position = Vector3(0.0, y_fondo, r - HUECO - 0.003)
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lado_mi.add_child(mi)
	var filo := MeshInstance3D.new()
	filo.name = "Filo"
	var qf := QuadMesh.new()
	qf.size = Vector2(r * 2.0, 0.035)
	filo.mesh = qf
	var mf := m.duplicate() as StandardMaterial3D
	mf.albedo_color = Color(0.62, 0.78, 0.9, 0.5)
	filo.material_override = mf
	filo.position = Vector3(0.0, 0.0, -0.001)               # delante de la lámina (en el espacio de la lámina, que está girada)
	mi.add_child(filo)
	return mi


## `y_agua`: la cota de la superficie ahora. Cada vez que sube de lo anterior se alarga la marca; al bajar no se toca.
func poner_nivel(y_agua: float) -> void:
	if y_agua <= _y_max + 0.005:
		return
	_y_max = minf(y_agua, y_borde)
	var h: float = _y_max - y_fondo
	if h < 0.03:
		return
	for mi in _humedad:
		mi.visible = true
		mi.scale = Vector3(1.0, h, 1.0)
		mi.position.y = y_fondo + h * 0.5
		var filo: MeshInstance3D = mi.get_node("Filo")
		filo.scale = Vector3(1.0, 1.0 / h, 1.0)               # el filo no debe estirarse con la lámina
		filo.position.y = 0.5 - 0.0175 / h


## Vacía la marca (un nivel que se reinicia).
func borrar_humedad() -> void:
	_y_max = -1000.0
	for mi in _humedad:
		mi.visible = false


func mostrar_lado(i: int, visible_: bool) -> void:
	if i >= 0 and i < _paredes.size():
		_paredes[i].visible = visible_


## La pared y el bordillo del lado +Z (en local); los otros tres son esta misma malla girada.
func _malla_lado(r: float, m_pared: Material, m_borde: Material) -> ArrayMesh:
	var malla := ArrayMesh.new()
	var z: float = r - HUECO
	var sp := SurfaceTool.new()
	sp.begin(Mesh.PRIMITIVE_TRIANGLES)
	sp.set_material(m_pared)
	var a := Vector3(r, y_fondo, z)
	var b := Vector3(-r, y_fondo, z)
	var c := Vector3(-r, y_borde, z)
	var d := Vector3(r, y_borde, z)
	var n := Vector3(0, 0, -1)       # hacia dentro del pozo
	var verts: Array = [[a, COLOR_PIE], [b, COLOR_PIE], [c, Color.WHITE], [a, COLOR_PIE], [c, Color.WHITE], [d, Color.WHITE]]
	for v in verts:
		sp.set_normal(n)
		sp.set_color(v[1] as Color)
		sp.set_uv(Vector2((v[0] as Vector3).x, (v[0] as Vector3).y))
		sp.add_vertex(v[0] as Vector3)
	sp.commit(malla)
	# Bordillo: tapa, cara interior y cara exterior (la que mira a la tierra de al lado).
	var sb := SurfaceTool.new()
	sb.begin(Mesh.PRIMITIVE_TRIANGLES)
	sb.set_material(m_borde)
	var yb: float = y_borde
	var yt: float = y_borde + ALTO_BORDILLO
	var zi: float = r - ANCHO_BORDILLO
	_quad(sb, Vector3(r, yt, zi), Vector3(-r, yt, zi), Vector3(-r, yt, r), Vector3(r, yt, r), Vector3.UP)
	_quad(sb, Vector3(r, yb, zi), Vector3(-r, yb, zi), Vector3(-r, yt, zi), Vector3(r, yt, zi), Vector3(0, 0, -1))
	_quad(sb, Vector3(-r, yb, r), Vector3(r, yb, r), Vector3(r, yt, r), Vector3(-r, yt, r), Vector3(0, 0, 1))
	sb.commit(malla)
	return malla


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.set_uv(Vector2((v as Vector3).x, (v as Vector3).z))
		st.add_vertex(v as Vector3)
