class_name ContadorReactivos3D
extends Node3D

## CONTADOR DE REACTIVOS (Fase 14.6 · laboratorio de fuego, F1 «enciende las cuatro antorchas», 16/10, Juego). Cuenta cuántos objetos de
## una lista están ENCENDIDOS (`is_lit`: braseros, fogatas, setos que arden, cuerdas…) y avisa cuando están todos, o los que se pidan.
## Es el detector del fuego, igual que NivelAgua3D lo es del agua: no abre nada, solo avisa; quien lo escucha (una regla de Puzle3D) decide.
##
## Señales:
##   todos(si)               cambia «¿están los pedidos?». `si = true` al llegar a `minimo`, `false` al bajar de él. No sale al nacer.
##   cambio(encendidos, total)   cada vez que cambia la cuenta (para el rótulo y el HUD).
## Lectura (no hace falta señal para consultarlo): `encendidos`, `total`, `minimo`, `completo`.
##
## Cómo lee: cada fotograma, `is_lit` de cada nodo de la lista. Un nodo liberado (un seto consumido) cuenta como apagado. No hay
## señal que escuchar porque `is_lit` no tiene una común a todos los tipos (un seto no emite `llama`, un brasero sí), y son cuatro o
## cinco lecturas por fotograma.
## Rótulo flotante «ENCENDIDAS 2/4» sobre su casilla (solo si `preparar` recibe una casilla): es lo que ve el jugador.
## Qué NO hace: no enciende nada ni mira el agua; una lista vacía no está nunca completa.

signal todos(si: bool)
signal cambio(encendidos: int, total: int)

const ALTO_ROTULO: float = 1.8
const ALTO_ROTULO_PLACA: float = 0.85    ## el rótulo sobre la placa (mide 0,5 de alto)
const GEMAS_PLACA: int = 4                ## huecos que tiene el modelo de la placa
const COLOR_FALTAN: Color = Color(1.0, 0.85, 0.6)
const COLOR_TODOS: Color = Color(0.6, 1.0, 0.65)

var lista: Array = []                       ## los nodos que se cuentan (cada uno con `is_lit`)
var minimo: int = 0                         ## cuántos hacen falta (por defecto, todos)
var celda: Vector2i = Vector2i(-1, -1)
var encendidos: int = 0
var completo: bool = false
var _rotulo: Label3D = null
var _placa: PiezaFuego3D = null             ## la placa con huecos del Pipeline (`contador_placa`); null si no hay modelo o no hay casilla
var modelo: String = ""                     ## 24/11: "" o "totem" = el tótem (ver _poner_totem; sin el pack, la placa) · "placa" = la placa con gemas y el rótulo de antes


## `p_lista`: los nodos a contar. `p_minimo`: 0 = todos. `p_celda`: donde se cuelga el rótulo (x < 0 = sin rótulo, para las pruebas).
func preparar(p_lista: Array, p_minimo: int = 0, p_celda: Vector2i = Vector2i(-1, -1)) -> void:
	lista = p_lista.duplicate()
	minimo = p_minimo if p_minimo > 0 else lista.size()
	celda = p_celda
	if celda.x >= 0:
		position = Terreno3D.centro_de(celda, Terreno3D.alto_suelo)


func _ready() -> void:
	if celda.x >= 0 and modelo != "placa" and _poner_totem():      # 24/11 (Pablo: «sí, en todos»): el tótem por defecto; `modelo=placa`, la placa de antes
		_leer(false)
		set_process(true)
		return
	if celda.x >= 0:
		_rotulo = Label3D.new()
		_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_rotulo.font_size = 28
		_rotulo.outline_size = 8
		_rotulo.pixel_size = 0.005
		_rotulo.position = Vector3(0.0, ALTO_ROTULO, 0.0)
		add_child(_rotulo)
		# La placa con huecos y gemas del Pipeline (diario 108); sin su modelo no se pone nada y queda solo el rótulo, como antes.
		# El rótulo se queda (dice el número exacto, también con más de 4 reactivos) pero baja a ras de la placa.
		if PiezaFuego3D.usar_modelos and PiezaFuego3D.hay_modelo("contador_placa"):
			_placa = PiezaFuego3D.crear("contador_placa")
			add_child(_placa)
			_rotulo.position = Vector3(0.0, ALTO_ROTULO_PLACA, 0.0)
	_leer(false)
	set_process(true)


# --- TÓTEM (24/11, Pablo en el playtest de PtFuego: «¿hay una manera mejor de enseñar el progreso? Un tótem que vaya encendiendo los símbolos») ----------
## POR DEFECTO (24/11, Pablo: «sí, en todos»; `modelo=placa` vuelve a lo de antes): en vez de la placa con gemas y el rótulo «ENCENDIDAS 2/3», el TÓTEM de piedra del pack Lost Cave (`lost_totem_a`) con un SÍMBOLO tallado
## por cada reactivo que hace falta (hasta TOTEM_MAX; las pinturas rupestres del pack: espiral, ojo, figura). Se encienden de abajo arriba, en naranja de fuego,
## según arden; con todos, el tótem entero brilla. Va al fondo de su casilla (no la tapa: no bloquea). Sin el pack, la placa de siempre.
const TOTEM: String = "res://arte/lostcave/piezas/lost_totem_a.tscn"
const SIMBOLOS: Array[String] = ["res://arte/lostcave/texturas/T_Symbol_c_BC.png", "res://arte/lostcave/texturas/T_Symbol_b_BC.png", "res://arte/lostcave/texturas/T_Symbol_a_BC.png"]
const TOTEM_ESCALA: float = 0.6
const TOTEM_FONDO: float = 0.3               ## fracción de casilla que se corre hacia el fondo (norte)
const TOTEM_MAX: int = 5
const COLOR_APAGADO: Color = Color(0.05, 0.04, 0.035, 1.0)        ## un trazo tallado en la piedra (opaco: de día, en el bosque, a 0,85 casi no se veía)
const COLOR_ENCENDIDO: Color = Color(1.0, 0.38, 0.1, 1.0)         ## naranja de brasa (Pablo: rojos y naranjas, nunca amarillo)
const BRILLO_ENCENDIDO: float = 2.4
const SHADER_SIMBOLO: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D mascara : source_color, filter_linear_mipmap;
uniform vec4 color : source_color = vec4(1.0);
uniform float brillo = 1.0;
void fragment() {
	float a = smoothstep(0.02, 0.3, texture(mascara, UV).a);   // engrosa el trazo: de lejos, con el mipmap, los trazos finos se perdían

	ALBEDO = color.rgb * brillo;
	ALPHA = a * color.a;
}
"""
static var _shader: Shader = null
var _totem: Node3D = null
var _simbolos: Array = []                    ## ShaderMaterial de cada símbolo, de abajo arriba
var _luz_totem: OmniLight3D = null
var _encendidos_vistos: int = -1


func _poner_totem() -> bool:
	if not ResourceLoader.exists(TOTEM):
		return false
	var n: Node3D = (load(TOTEM) as PackedScene).instantiate() as Node3D
	for col in n.find_children("*", "CollisionObject3D", true, false):
		col.free()                                  # no bloquea: es un marcador
	var malla: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D if not n.find_children("*", "MeshInstance3D", true, false).is_empty() else null
	if malla == null:
		n.free()
		return false
	n.scale = Vector3.ONE * TOTEM_ESCALA
	n.position = Vector3(0.0, 0.0, -TOTEM_FONDO * Terreno3D.casilla)
	add_child(n)
	_totem = n
	Ocluso3D.convertir_nodo(n)
	# La cara de delante (+Z, hacia la cámara) y su alto, en las unidades de la pieza.
	var caja: AABB = malla.transform * malla.mesh.get_aabb()
	var cuantos: int = clampi(minimo, 1, TOTEM_MAX)
	var alto_util: float = caja.size.y * 0.62
	var lado: float = minf(caja.size.x * 0.42, alto_util / float(cuantos) * 0.85)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_SIMBOLO
	_simbolos.clear()
	for i in cuantos:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(lado, lado)
		q.mesh = qm
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter("mascara", load(SIMBOLOS[i % SIMBOLOS.size()]))
		mat.set_shader_parameter("color", COLOR_APAGADO)
		mat.set_shader_parameter("brillo", 1.0)
		q.material_override = mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var y: float = caja.position.y + caja.size.y * 0.2 + (alto_util / float(cuantos)) * (float(i) + 0.5)
		q.position = Vector3(caja.get_center().x, y, caja.end.z + 0.03)
		n.add_child(q)
		_simbolos.append(mat)
	_luz_totem = OmniLight3D.new()
	_luz_totem.light_color = COLOR_ENCENDIDO
	_luz_totem.omni_range = 3.0
	_luz_totem.light_energy = 0.0
	_luz_totem.position = Vector3(0.0, caja.get_center().y * TOTEM_ESCALA, -TOTEM_FONDO * Terreno3D.casilla + caja.end.z * TOTEM_ESCALA + 0.5)
	add_child(_luz_totem)
	return true


## Enciende tantos símbolos (de abajo arriba) como reactivos arden; con todos, más brillo y más luz.
func _pintar_totem() -> void:
	var de: int = maxi(minimo, 1)
	var cuantos: int = _simbolos.size()
	var luces: int = int(floor(float(mini(encendidos, de)) * cuantos / float(de)))
	for i in cuantos:
		var mat: ShaderMaterial = _simbolos[i]
		var on: bool = i < luces
		var objetivo_color: Color = COLOR_ENCENDIDO if on else COLOR_APAGADO
		var objetivo_brillo: float = (BRILLO_ENCENDIDO * (1.5 if completo else 1.0)) if on else 1.0
		if is_inside_tree() and _encendidos_vistos >= 0:
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_property(mat, "shader_parameter/color", objetivo_color, 0.35)
			tw.tween_property(mat, "shader_parameter/brillo", objetivo_brillo, 0.35)
		else:
			mat.set_shader_parameter("color", objetivo_color)
			mat.set_shader_parameter("brillo", objetivo_brillo)
	if _luz_totem != null:
		var e: float = (2.2 if completo else 0.5 * float(luces))
		if is_inside_tree() and _encendidos_vistos >= 0:
			create_tween().tween_property(_luz_totem, "light_energy", e, 0.35)
		else:
			_luz_totem.light_energy = e
	if completo and _encendidos_vistos >= 0 and _encendidos_vistos < de and is_inside_tree():
		Sfx.play(self, "sello_ok")
	_encendidos_vistos = encendidos


func total() -> int:
	return lista.size()


## Cuántos de la lista arden ahora mismo.
func contar() -> int:
	var n: int = 0
	for o in lista:
		if is_instance_valid(o) and bool(o.get("is_lit")):
			n += 1
	return n


func _process(_delta: float) -> void:
	_leer(true)


func _leer(avisar: bool) -> void:
	var n: int = contar()
	var ahora: bool = lista.size() > 0 and n >= minimo
	if n != encendidos:
		encendidos = n
		if avisar:
			cambio.emit(encendidos, lista.size())
		_pintar()
	if ahora != completo:
		completo = ahora
		_pintar()
		if avisar:
			todos.emit(completo)


func _pintar() -> void:
	if _totem != null:
		_pintar_totem()
		return
	if _placa != null:
		# Una gema por reactivo hasta 4; con más reactivos que huecos, la parte proporcional.
		var de: int = mini(maxi(minimo, 1), GEMAS_PLACA)
		_placa.poner_cuenta(int(floor(float(mini(encendidos, maxi(minimo, 1))) * de / float(maxi(minimo, 1)))), de)
	if _rotulo == null:
		return
	_rotulo.text = "ENCENDIDAS %d/%d" % [encendidos, minimo]
	_rotulo.modulate = COLOR_TODOS if completo else COLOR_FALTAN
