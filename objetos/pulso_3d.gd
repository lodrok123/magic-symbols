class_name Pulso3D
extends Node3D

## EL PULSO (23/10, FASE 1 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §3). La SEÑAL: una onda que nace en un emisor, avanza casilla a casilla por lo que
## CONDUCE y avisa a lo que toca. Es una sola regla, igual para el pulso del escenario (el cristal que late, la fuente eléctrica) y, más adelante, para el del
## jugador (el glifo, fase 2). Este nodo es lógica y dibujo del FRENTE; lo que se enciende de verdad lo pintan las piezas (`VetaPulso3D`, `CristalPulso3D`,
## `ReceptorPulso3D`).
##
## QUÉ CONDUCE (`conduce_pulso`): lo que ya conduce la corriente —`Terreno3D.conduce`: agua de juego, agua bajo un puente, nexos mojados— MÁS las vetas
## (`vetas`, que solo conoce el pulso: la fuente eléctrica NO corre por una veta, o el rayo herería por ellas). La búsqueda es la MISMA que la de la fuente eléctrica
## (`EmisorRayo3D.ola`, con distancia y alcance): aquí solo se le pone tiempo. Puentes de piedra, basalto enfriado y bloques de enlace son de las fases siguientes y
## entran sin tocar esto: se declaran conductores (`Terreno3D.conductores`) o se suman a `conduce_pulso`.
##
## CÓMO AVANZA: nace con las casillas de origen en el paso 0. Cada `SEG_POR_CASILLA` s el frente llega al paso siguiente: las casillas conductoras a ese paso se
## ENCIENDEN (señal `alcanzo`; una veta se ilumina, el agua recibe una losa que se apaga) y las que las tocan por una de las 4 vecinas sin conducir (un receptor
## junto a la veta, la seta, el brasero) reciben el aviso. Por el AIRE no viaja: sin conductor el pulso solo toca la casilla de al lado del emisor (paso 1). Alcance
## en casillas: nada pasa del paso `alcance`.
##
## AVISO a lo tocado: cualquier nodo del grupo `GRUPO_PULSABLE` con `celda` y un método `on_pulso(pulso: Pulso3D)` (el contrato de los hechizos, `on_spell_hit`, pero con
## la señal entera: su elemento, su color, su paso). El emisor NO se avisa a sí mismo. SIN REENTRADAS: cada casilla se alcanza una sola vez (la búsqueda no vuelve atrás,
## un anillo de veta no da vueltas), cada nodo recibe el aviso una sola vez por pulso, y recibir un pulso no emite otro (§10 bis).
##
## SE VE Y SE OYE (§3, §9): un anillo en el suelo al nacer, cada conductor se ilumina al pasar el frente y se apaga detrás (`T_BRILLO`), y un tono que SUBE al llegar a
## algo que responde. No hay sonido propio del pulso todavía: se usa `sello_ok` de `Sfx` a distintos tonos (constantes TONO_*); el gancho es `_sonar`, y bastará cambiar
## el nombre cuando exista el sonido propio.

signal alcanzo(celda: Vector2i, paso: int)               ## el frente llega a una casilla que conduce (también el origen, paso 0)
signal toco(nodo: Node, celda: Vector2i, paso: int)      ## el frente avisa a un nodo (receptor, reactivo)
signal terminado

const SEG_POR_CASILLA: float = 0.08      ## s que tarda el frente en pasar de una casilla a la siguiente (PLAN §3)
const ALCANCE_DEFECTO: int = 12          ## casillas (el tope del glifo, PLAN §2); los pulsos del escenario piden el que necesiten
const T_BRILLO: float = 0.32             ## s que una casilla tarda en apagarse después de que el frente pase (la cola del frente)
const T_ANILLO: float = 0.6              ## s que dura el anillo del suelo al nacer
const T_COLA: float = 0.65               ## s que el nodo sigue vivo tras el último paso (que se apague lo último y acabe el anillo: > T_ANILLO)
const ALTO_ANILLO: float = 0.07          ## u sobre el suelo
const GRUPO_PULSABLE: String = "pulsable3d"

## PULSO BASE (decisión de Pablo, 23/10): azulado claro. Es el color del pulso sin elemento, el del escenario antes del cofre y el que se ve por defecto.
const COLOR_BASE: Color = Color(0.62, 0.85, 1.0)         # #9ED9FF
## Con elemento, el frente toma el color de su runa. Espejo de `color` de `nucleo/*_rune.tres` (la prueba de Pulso3D lo comprueba: si una runa cambia de color, avisa).
const COLORES: Dictionary = {
	"fuego": Color(0.95, 0.33, 0.12), "agua": Color(0.16, 0.62, 0.98), "hielo": Color(0.37, 0.81, 0.96), "rayo": Color(0.95, 0.78, 0.24),
	"tierra": Color(0.78, 0.53, 0.35), "viento": Color(0.56, 0.83, 0.42), "tiempo": Color(0.72, 0.58, 0.98),
}
## Sonido provisional (ver arriba): nombre del catálogo de `Sfx` y tono. Nace más grave y llega más agudo; cada elemento lo desplaza un poco.
const SFX_PULSO: String = "sello_ok"
const TONO_NACE: float = 0.7
const TONO_LLEGA: float = 1.5
const TONO_ELEMENTO: Dictionary = {"fuego": 0.8, "agua": 0.9, "hielo": 1.1, "rayo": 1.25, "tierra": 0.7, "viento": 1.15, "tiempo": 0.95}

const CODIGO_ANILLO: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(0.62, 0.85, 1.0, 1.0);
uniform float progreso = 0.0;
uniform float semilado = 3.45;
varying vec2 loc;

void vertex() {
	loc = VERTEX.xz / semilado;
}

void fragment() {
	float r = length(loc);
	float radio = mix(0.12, 0.95, 1.0 - pow(1.0 - progreso, 2.0));
	float grosor = mix(0.16, 0.05, progreso);
	float a = (1.0 - smoothstep(0.0, grosor, abs(r - radio))) * (1.0 - progreso);
	ALBEDO = color.rgb;
	ALPHA = a;
}
"""

## Las vetas que hay en el mapa (casilla -> VetaPulso3D): solo el pulso las cuenta como conductor. Cada veta se apunta y se borra ella misma.
static var vetas: Dictionary = {}
static var _shader_anillo: Shader = null

var origenes: Array = []                 ## Vector2i de salida (el emisor)
var elemento: String = ""                ## "" = pulso base
var color: Color = COLOR_BASE
var alcance: int = ALCANCE_DEFECTO
var emisor: Node = null                  ## el que lo soltó: no se avisa a sí mismo
var del_jugador: bool = false            ## lo soltó un hechizo del jugador (ᚱ), no el escenario
var linaje: Array = []                   ## los emisores intermedios (prismas) por los que ha pasado: no se repiten
var _paso_actual: int = 0                ## el paso que se está disparando ahora (para el aviso `on_pulso`: un prisma calcula con él el alcance que queda)
var alcanzadas: Dictionary = {}          ## casilla conductora -> paso (el origen, 0)
var tocadas: Dictionary = {}             ## casilla vecina que NO conduce -> paso en que el frente la toca
var avisados: Array = []                 ## los nodos que ya recibieron on_pulso (uno por pulso)
var dibujar: bool = true                 ## false en las pruebas de lógica pura
var _por_paso: Array = []                ## paso -> Array [Vector2i, es_alcanzada]
var _t: float = 0.0
var _paso: int = 0                       ## el siguiente paso por disparar
var _pulsables: Dictionary = {}          ## casilla -> Array de nodos pulsables (foto al nacer)
var _celdas_vivas: Array = []            ## [MeshInstance3D, edad] de las losas de agua encendidas
var _mat_losa: StandardMaterial3D = null
var _mesh_losa: QuadMesh = null
var _acabado: bool = false


## ¿Conduce el pulso por esta casilla? La corriente de siempre (agua, nexo mojado…) o una veta.
static func conduce_pulso(c: Vector2i) -> bool:
	return Terreno3D.en_mapa(c) and (Terreno3D.conduce(c) or vetas.has(c))


## El color de un elemento («» o desconocido = el base).
static func color_de(p_elemento: String) -> Color:
	return COLORES.get(p_elemento, COLOR_BASE)


static func tono_de(p_elemento: String) -> float:
	return float(TONO_ELEMENTO.get(p_elemento, 1.0))


## Casillas que el frente TOCA sin conducir: las 4 vecinas de cada alcanzada que no son alcanzadas, con el paso de la vecina más cercana + 1 (y dentro del alcance).
static func vecinas_tocadas(p_alcanzadas: Dictionary, p_alcance: int) -> Dictionary:
	var res: Dictionary = {}
	for c in p_alcanzadas:
		var p: int = int(p_alcanzadas[c]) + 1
		if p > p_alcance:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + d
			if p_alcanzadas.has(v):
				continue
			if not res.has(v) or p < int(res[v]):
				res[v] = p
	return res


## Suelta un pulso: crea el nodo bajo `contenedor` y arranca. `conduce` (Callable(Vector2i) -> bool) vacío = `conduce_pulso`.
## `p_del_jugador` = lo soltó un hechizo del jugador (glifo ᚱ): lo distingue de los del escenario, y hay piezas (la pared hueca) que solo responden al propio. `p_linaje` = los
## emisores intermedios por los que ya pasó (un prisma): ninguno vuelve a emitir este pulso, así dos prismas enfrentados no se lo pasan para siempre.
static func emitir(contenedor: Node, p_origenes: Array, p_elemento: String = "", p_alcance: int = ALCANCE_DEFECTO, p_emisor: Node = null, conduce: Callable = Callable(),
		p_del_jugador: bool = false, p_linaje: Array = []) -> Pulso3D:
	var p := Pulso3D.new()
	p.name = "Pulso"
	p.del_jugador = p_del_jugador
	p.linaje = p_linaje.duplicate()
	p.preparar(p_origenes, p_elemento, p_alcance, p_emisor, conduce)
	contenedor.add_child(p)
	return p


## Calcula AHORA por dónde va a pasar (una veta que se corta o el agua que se hiela después no cambian un pulso ya en marcha) y lo deja listo.
func preparar(p_origenes: Array, p_elemento: String = "", p_alcance: int = ALCANCE_DEFECTO, p_emisor: Node = null, conduce: Callable = Callable()) -> void:
	origenes = p_origenes
	elemento = p_elemento
	color = color_de(p_elemento)
	alcance = maxi(p_alcance, 0)
	emisor = p_emisor
	var f: Callable = conduce if conduce.is_valid() else Pulso3D.conduce_pulso
	alcanzadas = EmisorRayo3D.ola(origenes, f, alcance, true)
	tocadas = vecinas_tocadas(alcanzadas, alcance)
	var maximo: int = 0
	for c in alcanzadas:
		maximo = maxi(maximo, int(alcanzadas[c]))
	for c in tocadas:
		maximo = maxi(maximo, int(tocadas[c]))
	_por_paso = []
	for i in range(maximo + 1):
		_por_paso.append([])
	for c in alcanzadas:
		(_por_paso[int(alcanzadas[c])] as Array).append([c, true])
	for c in tocadas:
		(_por_paso[int(tocadas[c])] as Array).append([c, false])


## Pasos que tiene el pulso (el último paso con algo: alcanzado o tocado).
func pasos() -> int:
	return _por_paso.size() - 1


func _ready() -> void:
	if get_tree() != null:
		for n in get_tree().get_nodes_in_group(GRUPO_PULSABLE):
			if is_instance_valid(n) and n != emisor and n.get("celda") is Vector2i:
				var c: Vector2i = n.get("celda")
				if not _pulsables.has(c):
					_pulsables[c] = []
				(_pulsables[c] as Array).append(n)
	dibujar = dibujar and Terreno3D.hay_mundo()
	if dibujar and not origenes.is_empty():
		global_position = _centro_origen()        # el sonido sale de donde nace
		_anillo(global_position)
		_sonar(TONO_NACE, self)
	set_process(true)


func _process(delta: float) -> void:
	avanzar(delta)


## Avanza el reloj del pulso `delta` s y dispara los pasos que toquen. Público para que las pruebas lo hagan a mano y sin ventana.
func avanzar(delta: float) -> void:
	if _acabado:
		return
	_t += delta
	var objetivo: int = int(floorf(_t / SEG_POR_CASILLA + 1.0e-6))
	while _paso < _por_paso.size() and _paso <= objetivo:
		_disparar(_paso)
		_paso += 1
	if dibujar:
		_apagar_losas(delta)
	if _paso >= _por_paso.size() and _t >= float(pasos()) * SEG_POR_CASILLA + T_COLA:
		_acabado = true
		terminado.emit()
		queue_free()


## El tiempo que lleva vivo (s).
func edad() -> float:
	return _t


## El paso del frente en este momento (dentro de un `on_pulso` es el paso en que tocó a ese nodo).
func paso_actual() -> int:
	return _paso_actual


## Alcance que le queda al pulso en el paso actual (lo que puede seguir un prisma).
func alcance_restante() -> int:
	return maxi(alcance - _paso_actual, 0)


func _disparar(p: int) -> void:
	_paso_actual = p
	var llegado: Node = null
	for e in (_por_paso[p] as Array):
		var c: Vector2i = e[0]
		if bool(e[1]):
			alcanzo.emit(c, p)
			# El origen (el cristal, la fuente) lo marca el anillo: una losa plana debajo del emisor sobra. Pero si el origen es un conductor que no es el emisor (la casilla de la que
			# sale un prisma, la veta sobre la que se lanza un pulso) se enciende como las demás.
			if dibujar and (p > 0 or (conduce_pulso(c) and (emisor == null or emisor.get("celda") != c))):
				_encender(c)
		var n: Node = _avisar(c, p)
		if n != null and llegado == null:
			llegado = n
	if llegado != null and dibujar:
		_sonar(TONO_LLEGA, llegado)              # el tono sube al llegar a algo que responde


## Avisa a los pulsables de la casilla `c`. Devuelve el primero que respondió (null si ninguno): de él sale el tono de llegada.
func _avisar(c: Vector2i, p: int) -> Node:
	var primero: Node = null
	for n in (_pulsables.get(c, []) as Array):
		if not is_instance_valid(n) or avisados.has(n) or not (n as Object).has_method("on_pulso"):
			continue
		avisados.append(n)
		if primero == null:
			primero = n as Node
		toco.emit(n, c, p)
		(n as Object).call("on_pulso", self)
	return primero


# ---------------------------------------------------------------------------------------------------------------------
#  Se ve y se oye
# ---------------------------------------------------------------------------------------------------------------------

func _centro_origen() -> Vector3:
	var s := Vector3.ZERO
	for c in origenes:
		s += Terreno3D.centro_de(c as Vector2i, Terreno3D.y_pies(c as Vector2i))
	return s / float(origenes.size())


func _sonar(tono: float, origen: Node) -> void:
	if origen != null and origen.is_inside_tree():
		Sfx.play(origen, SFX_PULSO, tono * tono_de(elemento))


## Una casilla conductora se ilumina: una veta lo hace ella misma (con su máscara); el agua y lo demás reciben una losa que se apaga.
func _encender(c: Vector2i) -> void:
	var v: Variant = vetas.get(c, null)
	if v != null and is_instance_valid(v):
		(v as Object).call("encender", c, color)
		return
	if _mesh_losa == null:
		_mesh_losa = QuadMesh.new()
		_mesh_losa.orientation = PlaneMesh.FACE_Y
		_mesh_losa.size = Vector2(Terreno3D.casilla * 0.92, Terreno3D.casilla * 0.92)
		_mat_losa = StandardMaterial3D.new()
		_mat_losa.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_losa.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_losa.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_losa.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh_losa.material = _mat_losa
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_losa
	var m: StandardMaterial3D = _mat_losa.duplicate() as StandardMaterial3D        # un material por losa: cada una se apaga a su hora
	m.albedo_color = Color(color, 0.7)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var y: float = Terreno3D.superficie_agua(c) if Terreno3D.es_agua(c) else Terreno3D.y_pies(c)
	mi.global_position = Terreno3D.centro_de(c, y + ALTO_ANILLO)
	_celdas_vivas.append([mi, 0.0])


func _apagar_losas(delta: float) -> void:
	var i: int = _celdas_vivas.size() - 1
	while i >= 0:
		var e: Array = _celdas_vivas[i]
		var edad_c: float = float(e[1]) + delta
		e[1] = edad_c
		var mi: MeshInstance3D = e[0]
		if edad_c >= T_BRILLO:
			mi.queue_free()
			_celdas_vivas.remove_at(i)
		else:
			var m: StandardMaterial3D = mi.material_override as StandardMaterial3D
			m.albedo_color = Color(color, 0.7 * (1.0 - edad_c / T_BRILLO))
		i -= 1


## El anillo del suelo: un aro que se abre y se desvanece. Lo usa también el receptor al activarse (`anillo`).
func _anillo(centro: Vector3) -> void:
	Pulso3D.anillo(self, centro, color)


static func anillo(padre: Node3D, centro: Vector3, p_color: Color, p_duracion: float = T_ANILLO) -> void:
	if _shader_anillo == null:
		_shader_anillo = Shader.new()
		_shader_anillo.code = CODIGO_ANILLO
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	var lado: float = Terreno3D.casilla * 3.0
	q.size = Vector2(lado, lado)
	var m := ShaderMaterial.new()
	m.shader = _shader_anillo
	m.set_shader_parameter("color", p_color)
	m.set_shader_parameter("semilado", lado * 0.5)
	m.set_shader_parameter("progreso", 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	mi.global_position = centro + Vector3(0.0, ALTO_ANILLO, 0.0)
	var tw: Tween = mi.create_tween()
	tw.tween_property(m, "shader_parameter/progreso", 1.0, p_duracion)
	tw.tween_callback(mi.queue_free)
