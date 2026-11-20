extends Control
## GENERADOR DE MAPAS — la herramienta visual (17/11/2026). Se abre como una escena más:
##   tools\Godot_v4.7.2-stable_win64.exe --path . res://herramientas/generador_mapas/GeneradorMapas.tscn
## Izquierda: los parámetros (cada cambio regenera al momento). Centro: la vista previa del mapa (rueda = zoom, botón derecho = mover,
## botón izquierdo = pintar con el pincel elegido). Derecha: resumen, validación y el texto exacto del .txt que se escribiría.
## Abajo: «Otra semilla» (F5), «Exportar a Godot» (escribe mundo/datos_nivel/mapas/<Nombre>.txt y escenas/Prueba<Nombre>.tscn) y
## «Probar en el juego» (exporta y abre el nivel en otra ventana). NADA se escribe en el proyecto hasta pulsar Exportar.
## El generador es `generador_mazmorra.gd` (datos puros) y lo que escribe los archivos, `exportador_mapa.gd`.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const Catalogo = preload("res://herramientas/generador_mapas/catalogo_puzles.gd")

const C_FONDO: Color = Color(0.13, 0.12, 0.11)
const C_PANEL: Color = Color(0.17, 0.16, 0.15)
const C_MURO: Color = Color(0.23, 0.2, 0.19)
const C_SUELO: Color = Color(0.93, 0.89, 0.8)
const C_AGUA: Color = Color(0.45, 0.68, 0.82)
const C_TINTA: Color = Color(0.12, 0.1, 0.09)
const ROLES: Dictionary = {
	"inicio": ["inicio", Color(0.35, 0.75, 0.4)], "tesoro": ["tesoro", Color(0.95, 0.75, 0.2)],
	"llave": ["llave", Color(0.65, 0.45, 0.9)], "combate": ["se cierra", Color(0.9, 0.35, 0.3)], "salida": ["otra salida", Color(0.25, 0.7, 0.8)], "puzle": ["puzle del catálogo", Color(0.1, 0.6, 0.55)],
}
## tipo de objeto → [letra que se pinta, color, forma (0 círculo, 1 cuadrado), nombre]
const ICONOS: Dictionary = {
	"inicio": ["S", Color(0.2, 0.65, 0.3), 0, "inicio de la jugadora"], "salida": ["E", Color(0.25, 0.7, 0.8), 1, "salida a otro nivel"],
	"entrada": ["e", Color(0.2, 0.65, 0.3), 0, "llegada desde otro nivel"],
	"puerta": ["P", Color(0.45, 0.3, 0.2), 1, "puerta cerrada (la abre su activador)"], "puente": ["=", Color(0.2, 0.45, 0.7), 1, "puente plegado (lo tiende su activador)"],
	"contador": ["#", Color(0.95, 0.6, 0.15), 1, "contador de braseros (activador)"], "placa": ["_", Color(0.5, 0.5, 0.55), 1, "placa de peso (activador)"],
	"bloque": ["B", Color(0.4, 0.38, 0.36), 1, "bloque empujable"], "catalogo": ["?", Color(0.1, 0.5, 0.48), 1, "pieza de un puzle del catálogo"],
	"guerrero": ["W", Color(0.8, 0.25, 0.2), 0, "goblin guerrero"], "arquero": ["A", Color(0.85, 0.45, 0.15), 0, "goblin arquero"],
	"brasero": ["T", Color(0.95, 0.6, 0.15), 0, "brasero"], "jarron": ["j", Color(0.6, 0.5, 0.38), 0, "jarrón"],
	"cofre_tesoro": ["$", Color(0.9, 0.7, 0.1), 1, "cofre del tesoro"], "cofre_llave": ["K", Color(0.6, 0.4, 0.85), 1, "cofre de la llave"],
	"puerta_llave": ["L", Color(0.6, 0.4, 0.85), 1, "puerta con llave"], "cerrojo": ["X", Color(0.85, 0.3, 0.25), 1, "cerrojo de sala"],
	# Enemigos y cofres añadidos a mano (pestañas «Enemigos» y «Cofres»).
	"limo": ["l", Color(0.3, 0.7, 0.35), 0, "limo"], "golem": ["g", Color(0.5, 0.5, 0.55), 0, "gólem"], "chaman": ["c", Color(0.6, 0.3, 0.7), 0, "chamán"],
	"mouro": ["m", Color(0.35, 0.6, 0.75), 0, "mouro"], "elemental": ["G", Color(0.15, 0.45, 0.2), 0, "elemental del bosque (jefe)"],
	"cofre_comun": ["c", Color(0.6, 0.42, 0.22), 1, "cofre común"], "cofre_epico": ["é", Color(0.55, 0.3, 0.8), 1, "cofre épico"],
	"cofre_legendario": ["!", Color(0.95, 0.7, 0.1), 1, "cofre legendario"],
}
const TIPOS_ENEMIGO: Array[String] = ["guerrero", "arquero", "limo", "golem", "chaman", "mouro", "elemental"]
const TIPOS_COFRE: Array[String] = ["cofre_tesoro", "cofre_llave", "cofre_comun", "cofre_epico", "cofre_legendario"]
## Cambiar uno de estos cambia la forma del mapa: los retoques pintados a mano dejan de tener sentido y se borran.
const CLAVES_FORMA: Array[String] = ["algoritmo", "semilla", "ancho", "alto", "sala_min", "sala_max", "reparto", "densidad_salas", "puertas", "recto", "callejones",
	"ancho_pasillo", "forma", "relleno", "silueta", "metodo", "octavas", "tamano_sala", "suavizados", "region_min", "agua", "n_salas", "lado_min", "lado_max", "simetria", "pasillos", "bucles"]

## Los campos del panel. t: titulo | opcion | int | float | bool | texto. `alg`: solo se ve con ese algoritmo.
const CAMPOS: Array = [
	{"t": "titulo", "r": "MAPA"},
	{"k": "algoritmo", "r": "Algoritmo", "t": "opcion", "op": [["salas", "Salas y pasillos (donjon)"], ["cueva", "Cueva o claro de bosque (orgánico)"], ["pagina", "Una página (sala a sala)"]],
		"a": "Salas y pasillos: rejilla de salas unidas por un laberinto podado.\nCueva: roca natural por autómata celular, con agua.\nUna página: crece desde la entrada pegando salas, con simetría y bucles."},
	{"k": "semilla", "r": "Semilla", "t": "int", "min": 0, "max": 9999999, "a": "La misma semilla con los mismos parámetros da siempre el mismo mapa."},
	{"k": "ancho", "r": "Ancho (casillas)", "t": "int", "min": 12, "max": 120, "a": "Una casilla son 2,3 u del juego. La Cueva mide 27 × 25; el Bosque 02, 40 × 40."},
	{"k": "alto", "r": "Alto (casillas)", "t": "int", "min": 12, "max": 120},
	{"t": "titulo", "r": "SALAS Y PASILLOS", "alg": "salas"},
	{"k": "ancho_pasillo", "r": "Ancho de pasillo", "t": "int", "min": 1, "max": 3, "alg": "salas", "a": "Casillas de ancho de cada pasillo. Las salas crecen en la misma proporción. Con 1, los pasillos son de una sola casilla (difícil para combatir)."},
	{"k": "sala_min", "r": "Sala mínima (huecos)", "t": "int", "min": 1, "max": 8, "alg": "salas", "a": "Lado mínimo de una sala, en huecos de pasillo. Con pasillo de 2, una sala de 3 huecos mide 8 casillas."},
	{"k": "sala_max", "r": "Sala máxima (huecos)", "t": "int", "min": 1, "max": 10, "alg": "salas"},
	{"k": "reparto", "r": "Reparto de salas", "t": "opcion", "op": [["dispersas", "Dispersas"], ["densas", "Densas (llenan el mapa)"]], "alg": "salas"},
	{"k": "densidad_salas", "r": "Cantidad de salas", "t": "float", "min": 0.2, "max": 3.0, "paso": 0.1, "alg": "salas", "a": "1 = lo normal para el tamaño del mapa."},
	{"k": "puertas", "r": "Puertas por sala (%)", "t": "int", "min": 0, "max": 200, "paso": 10, "alg": "salas", "a": "50 = lo normal (según el tamaño de la sala). 0 = una sola puerta por sala."},
	{"k": "recto", "r": "Pasillos rectos (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "alg": "salas", "a": "0 = laberinto retorcido; 100 = pasillos largos y rectos."},
	{"k": "callejones", "r": "Podar callejones (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "alg": "salas", "a": "100 = no queda ningún pasillo sin salida; 0 = se queda el laberinto entero."},
	{"k": "forma", "r": "Forma del mapa", "t": "opcion", "op": [["rectangulo", "Rectángulo"], ["caja", "Caja (hueco central)"], ["cruz", "Cruz"], ["redonda", "Redonda"]], "alg": "salas"},
	{"t": "titulo", "r": "CUEVA / CLARO DE BOSQUE", "alg": "cueva"},
	{"k": "metodo", "r": "Método", "t": "opcion", "op": [["fractal", "Fractal (ruido en octavas)"], ["automata", "Autómata celular"]], "alg": "cueva",
		"a": "Fractal: salas anchas unidas por gargantas, con el borde recortado a varias escalas.\nAutómata: galerías más enredadas y parejas."},
	{"k": "tamano_sala", "r": "Tamaño de las salas", "t": "float", "min": 4.0, "max": 40.0, "paso": 1.0, "alg": "cueva", "a": "Solo fractal: casillas que mide, más o menos, cada bolsa de la cueva. Pequeño = muchas salitas; grande = pocas y amplias."},
	{"k": "octavas", "r": "Detalle (octavas)", "t": "int", "min": 1, "max": 6, "alg": "cueva", "a": "Solo fractal: 1 = formas lisas y redondas; 5-6 = borde muy recortado, con recovecos."},
	{"k": "relleno", "r": "Roca inicial (%)", "t": "int", "min": 30, "max": 75, "alg": "cueva", "a": "Menos = cueva abierta; más = galerías estrechas. Entre 42 y 48 da las mejores."},
	{"k": "silueta", "r": "Silueta irregular (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "alg": "cueva", "a": "0 = la cueva llena todo el rectángulo. Más = una mancha irregular con brazos y entrantes, como las del Cave Generator."},
	{"k": "suavizados", "r": "Suavizados", "t": "int", "min": 0, "max": 12, "alg": "cueva", "a": "Pasadas del autómata: más = paredes más redondas."},
	{"k": "region_min", "r": "Bolsa mínima (casillas)", "t": "int", "min": 1, "max": 80, "alg": "cueva", "a": "Las bolsas sueltas más pequeñas que esto se tapan; las demás se unen con un túnel."},
	{"k": "agua", "r": "Agua (%)", "t": "int", "min": 0, "max": 40, "alg": "cueva", "a": "Parte del suelo que se inunda (lo más bajo). Si el agua parte la cueva, se abre un vado."},
	{"t": "titulo", "r": "UNA PÁGINA", "alg": "pagina"},
	{"k": "n_salas", "r": "Número de salas", "t": "int", "min": 2, "max": 40, "alg": "pagina", "a": "Pequeña 3-6, mediana 6-12, grande 12-25. Si no caben, avisa."},
	{"k": "lado_min", "r": "Lado mínimo (casillas)", "t": "int", "min": 2, "max": 12, "alg": "pagina"},
	{"k": "lado_max", "r": "Lado máximo (casillas)", "t": "int", "min": 2, "max": 16, "alg": "pagina"},
	{"k": "simetria", "r": "Grupos simétricos", "t": "bool", "alg": "pagina", "a": "Las salas a los lados del eje de la entrada salen por parejas."},
	{"k": "pasillos", "r": "Pasillos (%)", "t": "int", "min": 0, "max": 90, "paso": 5, "alg": "pagina", "a": "Cuántas de las «salas» nuevas son pasillos largos y estrechos."},
	{"k": "bucles", "r": "Bucles (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "alg": "pagina", "a": "Puertas de más entre salas vecinas, para que no sea un árbol puro."},
	{"t": "titulo", "r": "CONTENIDO"},
	{"k": "enemigos", "r": "Enemigos", "t": "float", "min": 0.0, "max": 4.0, "paso": 0.1, "a": "0 = ninguno; 1 = un goblin por cada ~22 casillas de sala (más en las lejanas); 5 por sala como mucho."},
	{"k": "arqueros", "r": "Arqueros (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "a": "Parte de los goblins que son arqueros (letra A) en vez de guerreros (W)."},
	{"k": "salas_cerradas", "r": "Salas que se cierran (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "a": "Salas con enemigos que cierran sus puertas al entrar y se abren al vencer (cerrojo + vigía)."},
	{"k": "puzles", "r": "Puzles del catálogo", "t": "int", "min": 0, "max": 12, "a": "Cuántos puzles del catálogo se reparten solos en salas libres. Para poner uno concreto en una sala: pincel «puzle: …» y clic en la sala.\nLas plantillas están en herramientas/generador_mapas/catalogo/ (un .txt por puzle)."},
	{"k": "barreras", "r": "Barreras con puzle", "t": "int", "min": 0, "max": 8, "a": "Pasos obligados cerrados por una puerta o un puente, que abre un activador colocado antes de la barrera.\nLa flecha amarilla de la vista une cada activador con lo que abre. Con el pincel «enlazar» se cambia a mano."},
	{"k": "b_braseros", "r": "Activador: braseros", "t": "bool", "a": "Plantillas del catálogo que acaban en un contador de braseros (braseros_puerta): al encenderlos, se abre."},
	{"k": "b_placa", "r": "Activador: placa + bloque", "t": "bool", "a": "Plantillas del catálogo que acaban en una placa (piedra_pista): un bloque de piedra en una pista cerrada por paredes, que se empuja hasta la placa.\nPara que otra plantilla valga de activador, ponle «; barrera si» en su .txt."},
	{"k": "b_puente", "r": "Barrera: puentes", "t": "bool", "a": "Marcado: la mitad de las barreras son puentes plegados bajo el agua (en las cuevas, todas). Desmarcado: solo puertas."},
	{"k": "tesoro", "r": "Sala del tesoro", "t": "bool", "a": "La sala más lejana lleva un cofre (60 de oro y una poción)."},
	{"k": "llave", "r": "Tesoro con llave", "t": "bool", "a": "La sala del tesoro se cierra con una puerta de llave; la llave está en el cofre de otra sala lejana, que aparece al limpiarla."},
	{"k": "charcas", "r": "Salas con charca (%)", "t": "int", "min": 0, "max": 100, "paso": 5, "a": "Salas de 5 × 5 o más con una charca de agua honda en medio."},
	{"k": "braseros", "r": "Braseros por sala", "t": "float", "min": 0.0, "max": 4.0, "paso": 0.5, "a": "En los rincones. Nacen apagados: se encienden con fuego."},
	{"k": "jarrones", "r": "Jarrones por sala", "t": "float", "min": 0.0, "max": 6.0, "paso": 0.5, "a": "Contra la pared del fondo. Dan oro (o poción, 1 de cada 5)."},
	{"t": "titulo", "r": "NIVEL"},
	{"k": "nombre", "r": "Nombre del nivel", "t": "texto", "a": "Letras sin acento, cifras y «_». Será mapas/<Nombre>.txt y escenas/Prueba<Nombre>.tscn."},
	{"k": "estilo", "r": "Estilo", "t": "opcion", "op": [["cueva", "Cueva (roca)"], ["bosque", "Bosque (árboles)"], ["pantano", "Pantano (barro)"]], "a": "Cómo dibuja la maqueta las paredes y el suelo."},
	{"k": "luz", "r": "Luz", "t": "opcion", "op": [], "a": "La fila de LuzZona3D.ZONAS que ilumina el nivel."},
	{"k": "rotulo", "r": "Rótulo al entrar", "t": "bool", "a": "Una zona que cubre el mapa y enseña el nombre la primera vez."},
	{"k": "terreno", "r": "Pintar terreno", "t": "bool", "a": "Los pasillos van de tierra pisada y la sala del tesoro, enlosada (en estilo cueva no se enlosa).\nSin esto todo el suelo es igual y no hay juntas entre suelos que enseñar."},
	{"k": "acabado", "r": "Acabado del terreno", "t": "bool", "a": "Orillas del agua como en Bosque 01 (orilla integrada, ribera curva con cantos) y juntas y bordes como en Monte Sumicio\n(más relieve, hierba entremezclada con la tierra y la piedra). En estilo cueva solo las orillas.\nEs el acabado de serie de todos los niveles del juego; sin la casilla, este nivel se exporta sin él."},
	{"k": "camara_sala", "r": "Cámara por sala", "t": "bool", "a": "La cámara se frena en el borde de cada sala (no enseña lo que hay detrás de las paredes) y en las salas\npequeñas se acerca poco a poco; al salir a una sala grande vuelve al zoom de antes. En los pasillos solo la frena el borde del mapa.\nCon el algoritmo cueva no hay salas cerradas: se frena solo en el borde del mapa. Las salas que obligan a acercar mucho salen en los avisos."},
	{"k": "salida_a", "r": "Salidas (Nivel:entrada, …)", "t": "texto", "a": "Vacío = sin salida. Cada salida es Nivel:entrada, con el nombre del nivel tal como está en Niveles.ESCENAS (MonteSumicio, Bosque_02, Cueva…).\nVarias, separadas por comas: Bosque_02:boca_cueva, MonteSumicio:inicio\nLa primera va en la sala de inicio; cada una de las demás, en una sala lejana, con su propia llegada (entrada_2, entrada_3…).\nPara dar NOMBRE a la llegada (por donde se entra aquí viniendo de aquel nivel): Nivel:entrada=llegada.\nEjemplo para un Bosque 02 nuevo: MonteSumicio:desde_fraga=desde_sumicio, Cueva:desde_bosque=boca_cueva"},
]


# =====================================================================================================================
#  La vista previa
# =====================================================================================================================

class Vista extends Control:
	signal pintada(c: Vector2i)
	signal sobre(c: Vector2i)
	## Pincel «mover»: se agarra un elemento, se arrastra y se suelta. Solo al soltar se regenera el mapa.
	signal agarrada(c: Vector2i)
	signal soltada(c: Vector2i)
	## Herramientas de las pestañas «Enemigos» y «Cofres» (pincel «poner:…» o «llevar»): un clic, sin arrastre.
	signal clicada(c: Vector2i)
	var resaltada: Vector2i = Vector2i(-1, -1)        ## el enemigo elegido para llevarlo a otro sitio
	var arrastre_de: Vector2i = Vector2i(-1, -1)      ## casilla del elemento agarrado ((-1, -1) = ninguno)
	var arrastre_a: Vector2i = Vector2i(-1, -1)       ## casilla bajo el cursor mientras se arrastra

	var mapa: Dictionary = {}
	var escala: float = 16.0
	var origen: Vector2 = Vector2.ZERO
	var pincel: String = ""
	var _moviendo: bool = false
	var _pintando: bool = false
	var _tam: Vector2i = Vector2i.ZERO

	var ver_contenido: bool = true
	var seleccion: String = ""                     ## id del activador elegido con el pincel «enlazar»
	var _papel: ColorRect = ColorRect.new()          ## el plano lo pinta un shader (papel_mapa.gdshader) detrás de lo que dibuja `_draw`
	var _material: ShaderMaterial = ShaderMaterial.new()
	var _titulo: SystemFont = SystemFont.new()

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_CLICK
		_titulo.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Georgia", "serif"])
		_material.shader = load("res://herramientas/generador_mapas/papel_mapa.gdshader")
		_papel.material = _material
		_papel.show_behind_parent = true
		_papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_papel.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_papel)

	## Dónde y cómo pinta el shader: lo que cambia al mover la vista o hacer zoom.
	func _colocar_papel() -> void:
		_material.set_shader_parameter("tam_vista", size)
		_material.set_shader_parameter("origen", origen)
		_material.set_shader_parameter("escala", escala)

	func poner(m: Dictionary) -> void:
		mapa = m
		# El plano, a una textura de un píxel por casilla: R = se pisa, G = agua.
		var filas: PackedStringArray = m["filas"]
		var img: Image = Image.create(int(m["ancho"]), int(m["alto"]), false, Image.FORMAT_RGB8)
		for y in range(int(m["alto"])):
			for x in range(int(m["ancho"])):
				var ch: String = filas[y][x]
				img.set_pixel(x, y, Color(0.0 if ch == "#" else 1.0, 1.0 if ch == "~" else 0.0, 0.0))
		var par: Dictionary = m["parametros"]
		_material.set_shader_parameter("mapa", ImageTexture.create_from_image(img))
		_material.set_shader_parameter("tam", Vector2(int(m["ancho"]), int(m["alto"])))
		_material.set_shader_parameter("modo", 0 if String(par["estilo"]) == "cueva" else 1)
		_material.set_shader_parameter("temblor", 0.22 if String(par["algoritmo"]) == "cueva" else 0.07)
		var t: Vector2i = Vector2i(int(m["ancho"]), int(m["alto"]))
		if t != _tam:
			_tam = t
			ajustar()
		queue_redraw()

	## Encaja el mapa entero en la vista.
	func ajustar() -> void:
		if _tam.x <= 0 or size.x < 20.0 or size.y < 20.0:
			return
		escala = clampf(floorf(minf((size.x - 24.0) / _tam.x, (size.y - 96.0) / _tam.y)), 3.0, 48.0)
		origen = ((size - Vector2(_tam) * escala) * 0.5).floor() + Vector2(0, 30)
		queue_redraw()

	func _notification(que: int) -> void:
		if que == NOTIFICATION_RESIZED:
			ajustar()

	func celda_en(pos: Vector2) -> Vector2i:
		return Vector2i(((pos - origen) / escala).floor())

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var b: InputEventMouseButton = ev
			if b.pressed and (b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN):
				var antes: Vector2 = (b.position - origen) / escala
				escala = clampf(escala * (1.15 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 3.0, 64.0)
				origen = b.position - antes * escala
				queue_redraw()
			elif b.button_index == MOUSE_BUTTON_RIGHT or b.button_index == MOUSE_BUTTON_MIDDLE:
				_moviendo = b.pressed
			elif b.button_index == MOUSE_BUTTON_LEFT and (pincel.begins_with("poner") or pincel == "llevar"):
				if b.pressed:
					clicada.emit(celda_en(b.position))
			elif b.button_index == MOUSE_BUTTON_LEFT and pincel == "mover":
				if b.pressed:
					arrastre_a = celda_en(b.position)
					agarrada.emit(arrastre_a)             # quien escucha pone `arrastre_de` si ahí hay algo que se pueda mover
				elif arrastre_de.x >= 0:
					soltada.emit(celda_en(b.position))
					arrastre_de = Vector2i(-1, -1)
				queue_redraw()
			elif b.button_index == MOUSE_BUTTON_LEFT:
				_pintando = b.pressed and pincel != ""
				if _pintando:
					pintada.emit(celda_en(b.position))
		elif ev is InputEventMouseMotion:
			var mm: InputEventMouseMotion = ev
			if _moviendo:
				origen += mm.relative
				queue_redraw()
			elif arrastre_de.x >= 0:
				arrastre_a = celda_en(mm.position)
				queue_redraw()
			elif _pintando:
				pintada.emit(celda_en(mm.position))
			sobre.emit(celda_en(mm.position))

	func _draw() -> void:
		_colocar_papel()
		if mapa.is_empty():
			return
		var filas: PackedStringArray = mapa["filas"]
		var e: float = escala
		var claro: bool = String((mapa["parametros"] as Dictionary)["estilo"]) != "cueva"
		# El nombre del nivel, como el título de un mapa.
		draw_string(_titulo, Vector2(28, 62), String((mapa["parametros"] as Dictionary)["nombre"]).replace("_", " "), HORIZONTAL_ALIGNMENT_LEFT, -1, 44,
			Color(0.8, 0.9, 0.75) if claro else C_TINTA)
		# El terreno pintado: tierra pisada (g) en ocre y losas (R) en gris azulado, por debajo de todo lo demás.
		for y in range(filas.size()):
			for x in range(filas[y].length()):
				var ct: String = filas[y][x]
				if ct == "g" or ct == "R":
					draw_rect(Rect2(origen + Vector2(x, y) * e, Vector2(e, e)), Color(0.55, 0.38, 0.2, 0.22) if ct == "g" else Color(0.42, 0.46, 0.6, 0.28))
		if not ver_contenido:
			return
		# Salas: el papel que hacen (inicio, tesoro, llave, se cierra) y su número.
		var fuente: Font = get_theme_default_font()
		for s in mapa["salas"]:
			var r: Rect2i = s["rect"]
			var rol: String = String(s["rol"])
			if ROLES.has(rol):
				var col: Color = ROLES[rol][1]
				if String((mapa["parametros"] as Dictionary)["algoritmo"]) != "cueva":
					draw_rect(Rect2(origen + Vector2(r.position) * e, Vector2(r.size) * e).grow(-e * 0.2), Color(col, 0.22))
					draw_rect(Rect2(origen + Vector2(r.position) * e, Vector2(r.size) * e).grow(-e * 0.2), Color(col, 0.9), false, 2.0)
				else:
					draw_arc(origen + (Vector2(r.position) + Vector2(r.size) * 0.5) * e, r.size.x * 0.5 * e, 0.0, TAU, 48, Color(col, 0.9), 2.0)
		# Puertas sin pieza: una traviesa marrón.
		for pu in mapa["puertas"]:
			if String(pu["tipo"]) != "paso":
				continue
			var c: Vector2i = pu["c"]
			var horizontal: bool = filas[c.y][c.x - 1] == "#" and filas[c.y][c.x + 1] == "#"
			var centro: Vector2 = origen + (Vector2(c) + Vector2(0.5, 0.5)) * e
			var medio: Vector2 = Vector2(e * 0.5, e * 0.14) if horizontal else Vector2(e * 0.14, e * 0.5)
			draw_rect(Rect2(centro - medio, medio * 2.0), Color(0.5, 0.33, 0.18))
		# Objetos.
		var tam_letra: int = int(clampf(e * 0.62, 7.0, 26.0))
		for o in mapa["objetos"]:
			var ic: Array = ICONOS.get(String(o["tipo"]), ["?", Color.MAGENTA, 0, ""])
			if String(o.get("txt", "")) == "R":
				ic = ["R", Color(0.85, 0.36, 0.1), 1, "lava"]          # el basalto bajo la lava de un puzle: en naranja, que se lea como río
			var oc: Vector2i = o["c"]
			var cen: Vector2 = origen + (Vector2(oc) + Vector2(0.5, 0.5)) * e
			if int(ic[2]) == 1:
				draw_rect(Rect2(cen - Vector2(e, e) * 0.4, Vector2(e, e) * 0.8), C_TINTA)
				draw_rect(Rect2(cen - Vector2(e, e) * 0.34, Vector2(e, e) * 0.68), ic[1])
			else:
				draw_circle(cen, e * 0.4, C_TINTA)
				draw_circle(cen, e * 0.34, ic[1])
			if e >= 9.0:
				draw_string(fuente, cen + Vector2(-e * 0.5, tam_letra * 0.36), String(o.get("txt", ic[0])), HORIZONTAL_ALIGNMENT_CENTER, e, tam_letra, Color.WHITE)
		if e >= 12.0:
			for s in mapa["salas"]:
				var r2: Rect2i = s["rect"]
				# El número de la sala, en una chapa oscura que se lea sobre cualquier fondo: es el que piden los desplegables de la pestaña «Puzles».
				var num: String = str(int(s["id"]))
				var tam_num: int = maxi(11, int(tam_letra * 0.85))
				var esquina: Vector2 = origen + Vector2(r2.position) * e + Vector2(2, 2)
				var ancho_num: float = fuente.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_num).x + 8.0
				draw_rect(Rect2(esquina, Vector2(ancho_num, tam_num + 5.0)), Color(0.08, 0.08, 0.1, 0.78))
				draw_string(fuente, esquina + Vector2(4, tam_num), num, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_num, Color.WHITE)
				if s.has("titulo"):
					draw_string(fuente, esquina + Vector2(ancho_num + 5.0, tam_num), String(s["titulo"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam_letra * 0.75), Color(0, 0, 0, 0.7))
		# Elementos movidos a mano: una raya fina desde donde los puso el generador hasta donde están.
		for de_m in (mapa.get("movidos", {}) as Dictionary):
			var a_m: Vector2i = mapa["movidos"][de_m]
			var p0: Vector2 = origen + (Vector2(de_m) + Vector2(0.5, 0.5)) * e
			var p1: Vector2 = origen + (Vector2(a_m) + Vector2(0.5, 0.5)) * e
			draw_dashed_line(p0, p1, Color(0.1, 0.75, 0.85, 0.8), 1.5, 4.0)
			draw_arc(p0, e * 0.22, 0.0, TAU, 16, Color(0.1, 0.75, 0.85, 0.8), 1.5)
		if resaltada.x >= 0:
			draw_arc(origen + (Vector2(resaltada) + Vector2(0.5, 0.5)) * e, e * 0.66, 0.0, TAU, 24, Color(0.1, 0.85, 0.95), 3.0)
		# El elemento agarrado con el pincel «mover» y la casilla donde se soltaría.
		if arrastre_de.x >= 0:
			var q0: Vector2 = origen + (Vector2(arrastre_de) + Vector2(0.5, 0.5)) * e
			var q1: Vector2 = origen + (Vector2(arrastre_a) + Vector2(0.5, 0.5)) * e
			draw_arc(q0, e * 0.62, 0.0, TAU, 24, Color(0.1, 0.85, 0.95), 2.5)
			draw_line(q0, q1, Color(0.1, 0.85, 0.95), 2.0)
			draw_rect(Rect2(origen + Vector2(arrastre_a) * e, Vector2(e, e)), Color(0.1, 0.85, 0.95, 0.35))
			draw_rect(Rect2(origen + Vector2(arrastre_a) * e, Vector2(e, e)), Color(0.1, 0.85, 0.95), false, 2.0)
		# Vínculos: una flecha del activador a lo que abre (amarilla; morada la de la llave, que es fija). Lo que no tiene, en rojo.
		for en in mapa.get("enlaces", []):
			var pa: Vector2 = origen + (Vector2(en["a"]) + Vector2(0.5, 0.5)) * e
			if (en["de"] as Vector2i).x < 0:
				draw_arc(pa, e * 0.8, 0.0, TAU, 32, Color(1.0, 0.2, 0.15), 3.0)
				draw_string(fuente, pa + Vector2(e * 0.7, -e * 0.6), "sin enlazar", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(tam_letra, 13), Color(1.0, 0.25, 0.2))
				continue
			var pd: Vector2 = origen + (Vector2(en["de"]) + Vector2(0.5, 0.5)) * e
			var cv: Color = Color(0.75, 0.55, 0.95) if bool(en["fijo"]) else Color(1.0, 0.82, 0.2)
			if bool(en.get("aparece", false)):
				cv = Color(0.35, 0.9, 0.45)                # enemigo → cofre que aparece al caer
			var comba: Vector2 = (pd + pa) * 0.5 + (pa - pd).orthogonal() * 0.14
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(17):
				var t: float = i / 16.0
				pts.append(pd.lerp(comba, t).lerp(comba.lerp(pa, t), t))
			var hacia: Vector2 = (pa - pts[14]).normalized()
			var punta: Vector2 = pa - hacia * e * 0.45
			pts[16] = punta - hacia * e * 0.4
			draw_polyline(pts, C_TINTA, 5.5, true)
			draw_polyline(pts, cv, 2.5, true)
			draw_colored_polygon(PackedVector2Array([punta, punta - hacia * e * 0.55 + hacia.orthogonal() * e * 0.3, punta - hacia * e * 0.55 - hacia.orthogonal() * e * 0.3]), cv)
			draw_circle(pd, e * 0.17, cv)
		if seleccion != "":
			for o in mapa["objetos"]:
				if String(o["id"]) == seleccion:
					draw_arc(origen + (Vector2(o["c"]) + Vector2(0.5, 0.5)) * e, e * 0.62, 0.0, TAU, 32, Color(0.2, 0.9, 1.0), 3.0)


# =====================================================================================================================
#  La herramienta
# =====================================================================================================================

var _par: Dictionary = Generador.parametros_defecto()
var _retoques: Dictionary = {}
var _puzles: Dictionary = {}              ## puzles del catalogo puestos a mano: sala -> id del puzle
var _apariciones: Array = []              ## cofres que aparecen al caer enemigos: [{cofre, enemigos: []}] (extremos `a<n>` o `x,y`)
var _enl_enemigo: String = ""             ## pincel «enlazar»: el enemigo elegido, a la espera del clic en un cofre
var _anadidos: Array = []                 ## enemigos y cofres añadidos a mano: [{que, tipo, premio, c}]
var _lista_enemigos: VBoxContainer = null
var _lista_cofres: VBoxContainer = null
var _lista_salidas: VBoxContainer = null
var _sa_nivel: String = ""                ## pestaña «Salidas»: a qué nivel lleva ("" = ninguna herramienta puesta)…
var _sa_entrada: String = ""              ## …por cuál de sus llegadas se entra allí…
var _sa_modo: String = "pisar"            ## …cómo se activa (pisar | usar)…
var _sa_ancho: int = 1                    ## …cuántas casillas ocupa…
var _sa_acceso: String = ""               ## …cómo se llega a ella ("" tal cual | sendero | boca)…
var _sa_marca: bool = true               ## …si lleva marca en el suelo…
var _sa_llegada: String = ""              ## …y cómo se llama la llegada de este lado ("" = automático)
## Llegadas que un nivel crea por código y no están en su .txt (para que salgan en el desplegable).
const LLEGADAS_POR_CODIGO: Dictionary = {"MonteSumicio": ["desde_fraga"]}
var _en_tipo: String = ""                 ## pestaña «Enemigos»: el tipo elegido para añadir ("" = ninguno)
var _llevar_c: Vector2i = Vector2i(-1, -1)   ## …y el enemigo del mapa elegido para llevarlo a otro sitio
var _co_calidad: String = ""              ## pestaña «Cofres»: la calidad elegida ("" = ninguna)
var _co_premio: String = ""               ## …y la recompensa (épico y legendario)
var _movidos: Dictionary = {}             ## elementos movidos a mano: casilla donde lo puso el generador -> casilla donde está
var _enlaces: Dictionary = {}             ## enlaces cambiados a mano: id de barrera -> id de activador ("" = suelta)
var _mapa: Dictionary = {}
var _sucio: bool = true
var _controles: Dictionary = {}          ## clave → control
var _filas: Array = []                   ## [nodo de la fila, algoritmo o ""]
var _vista: Vista = null
var _resumen: RichTextLabel = null
var _texto: TextEdit = null
var _estado: Label = null
var _bajo_cursor: Label = null
var _pincel: OptionButton = null
var _abrir: MenuButton = null
var _confirmar: ConfirmationDialog = null
var _tras_confirmar: Callable = Callable()
var _lista_puzles: VBoxContainer = null  ## el contenido de la pestaña «Puzles» (se rehace cada vez que cambia el mapa)
var _pz_que: String = ""                ## lo elegido en «Añadir»: qué puzle…
var _pz_sala: int = -1                  ## …y en qué sala
var _pid_horno: int = 0                ## el proceso que está horneando (0 = ninguno)
var _nombre_horno: String = ""
var _mono: SystemFont = SystemFont.new()
var _cargando: bool = false


func _ready() -> void:
	var v: Window = get_window()
	v.title = "Generador de mapas — Magic Symbols"
	v.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED       # interfaz a píxeles reales (el juego estira la suya)
	v.min_size = Vector2i(1100, 650)
	if DisplayServer.get_name() != "headless":
		v.mode = Window.MODE_MAXIMIZED
	_mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
	theme = Theme.new()
	theme.default_font_size = 17 if DisplayServer.screen_get_size().x >= 2200 else 14      # en un monitor de 2560 la letra de serie queda pequeña
	_par["semilla"] = int(Time.get_unix_time_from_system()) % 1000000
	_montar()
	_regenerar()


func _process(_delta: float) -> void:
	if _sucio:
		_regenerar()
	if _pid_horno > 0 and not OS.is_process_running(_pid_horno):
		_fin_hornear()


func _unhandled_key_input(ev: InputEvent) -> void:
	var k: InputEventKey = ev as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F5:
		_otra_semilla()
		accept_event()


func _montar() -> void:
	var fondo: ColorRect = ColorRect.new()
	fondo.color = C_PANEL
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var margen: MarginContainer = MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 8)
	add_child(margen)
	var todo: VBoxContainer = VBoxContainer.new()
	todo.add_theme_constant_override("separation", 8)
	margen.add_child(todo)
	var cuerpo: HBoxContainer = HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 8)
	todo.add_child(cuerpo)
	# --- izquierda: parámetros ---
	# Dos pestañas: «Mapa» (los parámetros de siempre) y «Puzles» (añadir, mover y quitar puzles del catálogo sin usar el pincel).
	var pestanas: TabContainer = TabContainer.new()
	pestanas.custom_minimum_size = Vector2(440, 0)                # caben las cinco pestañas sin flechas de desplazar
	cuerpo.add_child(pestanas)
	var barra: ScrollContainer = ScrollContainer.new()
	barra.name = "Mapa"
	barra.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pestanas.add_child(barra)
	var barra_pz: ScrollContainer = ScrollContainer.new()
	barra_pz.name = "Puzles"
	barra_pz.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pestanas.add_child(barra_pz)
	_lista_puzles = VBoxContainer.new()
	_lista_puzles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_puzles.add_theme_constant_override("separation", 6)
	barra_pz.add_child(_lista_puzles)
	# «Enemigos» y «Cofres»: se elige en la pestaña y se pone con un clic en el mapa.
	_lista_enemigos = _pestana(pestanas, "Enemigos")
	_lista_cofres = _pestana(pestanas, "Cofres")
	_lista_salidas = _pestana(pestanas, "Salidas")
	pestanas.tab_changed.connect(func(_i: int) -> void: _herramienta(""))       # al cambiar de pestaña no se queda una herramienta puesta
	var lista: VBoxContainer = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 3)
	barra.add_child(lista)
	for campo in CAMPOS:
		_fila(lista, campo)
	# --- centro: vista ---
	_vista = Vista.new()
	_vista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vista.pintada.connect(_al_pintar)
	_vista.clicada.connect(_al_clicar)
	_vista.agarrada.connect(_al_agarrar)
	_vista.soltada.connect(_al_soltar)
	_vista.sobre.connect(_al_pasar)
	cuerpo.add_child(_vista)
	# --- derecha: resumen y texto ---
	var der: VBoxContainer = VBoxContainer.new()
	der.custom_minimum_size = Vector2(430, 0)
	der.add_theme_constant_override("separation", 6)
	cuerpo.add_child(der)
	_resumen = RichTextLabel.new()
	_resumen.bbcode_enabled = true
	_resumen.fit_content = true
	_resumen.custom_minimum_size = Vector2(0, 120)
	der.add_child(_resumen)
	var leyenda: RichTextLabel = RichTextLabel.new()
	leyenda.bbcode_enabled = true
	leyenda.fit_content = true
	var partes: PackedStringArray = PackedStringArray()
	for tipo in ICONOS:
		partes.append("[bgcolor=#%s][color=white] %s [/color][/bgcolor] %s" % [(ICONOS[tipo][1] as Color).to_html(false), String(ICONOS[tipo][0]), String(ICONOS[tipo][3])])
	for rol in ROLES:
		partes.append("[color=#%s]▣[/color] sala: %s" % [(ROLES[rol][1] as Color).to_html(false), String(ROLES[rol][0])])
	leyenda.text = "[b]Leyenda[/b]\n" + "   ".join(partes)
	der.add_child(leyenda)
	var rot: Label = Label.new()
	rot.text = "Lo que se escribiría en mapas/<Nombre>.txt:"
	der.add_child(rot)
	_texto = TextEdit.new()
	_texto.editable = false
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_texto.add_theme_font_override("font", _mono)
	_texto.add_theme_font_size_override("font_size", 13)
	der.add_child(_texto)
	# --- abajo: acciones ---
	var pie: HBoxContainer = HBoxContainer.new()
	pie.add_theme_constant_override("separation", 8)
	todo.add_child(pie)
	_boton(pie, "Otra semilla (F5)", _otra_semilla, "Genera otro mapa con los mismos parámetros.")
	_boton(pie, "Encajar vista", func() -> void: _vista.ajustar(), "Vuelve a ver el mapa entero.")
	var lp: Label = Label.new()
	lp.text = "   Pincel:"
	pie.add_child(lp)
	_pincel = OptionButton.new()
	for it in [["", "ninguno"], ["#", "# pared"], [".", ". suelo"], ["~", "~ agua"], ["borrar", "goma (quita el retoque)"], ["enlazar", "enlazar (activador → puerta/puente · enemigo → cofre)"],
			["mover", "mover un elemento (arrastrar)"]]:
		_pincel.add_item(String(it[1]))
		_pincel.set_item_metadata(_pincel.item_count - 1, String(it[0]))
	for cid in Catalogo.todos():
		_pincel.add_item("puzle: " + String(Catalogo.todos()[cid]["titulo"]))
		_pincel.set_item_metadata(_pincel.item_count - 1, "cat:" + String(cid))
	_pincel.add_item("quitar puzle de la sala")
	_pincel.set_item_metadata(_pincel.item_count - 1, "cat:")
	_pincel.tooltip_text = "Con un pincel elegido, el botón izquierdo pinta sobre la vista. El contenido (enemigos, cofres…) se recoloca solo."
	_pincel.item_selected.connect(_al_elegir_pincel)
	pie.add_child(_pincel)
	_boton(pie, "Borrar retoques", _borrar_retoques, "Quita todo lo pintado a mano y los enlaces cambiados a mano.")
	var ver: CheckBox = CheckBox.new()
	ver.text = "Contenido"
	ver.button_pressed = true
	ver.tooltip_text = "Desmarcado se ve solo el mapa, sin enemigos, cofres ni salas marcadas."
	ver.toggled.connect(_al_ver_contenido)
	pie.add_child(ver)
	_abrir = MenuButton.new()
	_abrir.text = "Abrir mapa generado ▾"
	_abrir.flat = false
	_abrir.tooltip_text = "Recupera los parámetros (y los retoques) de un mapa que exportó esta herramienta."
	_abrir.about_to_popup.connect(_llenar_abrir)
	_abrir.get_popup().id_pressed.connect(_al_abrir)
	pie.add_child(_abrir)
	var hueco: Control = Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(hueco)
	_boton(pie, "Copiar texto", _copiar_texto, "Copia el .txt al portapapeles sin escribir nada.")
	_boton(pie, "Exportar a Godot", func() -> void: _exportar(false), "Escribe mapas/<Nombre>.txt y escenas/Prueba<Nombre>.tscn.")
	_boton(pie, "Probar en el juego", func() -> void: _exportar(true), "Exporta y abre el nivel en otra ventana.")
	_boton(pie, "Hornear", _hornear, "Exporta y convierte el nivel en mundo/datos_nivel/Nivel_<Nombre>.tscn, EDITABLE en Godot (mover, girar, borrar y añadir piezas a mano).\nEs lo mismo que pulsar F9 dentro del juego. Es el último paso: con el nivel horneado, la herramienta ya no vuelve a exportar ese nombre.")
	var pie2: HBoxContainer = HBoxContainer.new()
	todo.add_child(pie2)
	_estado = Label.new()
	_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_estado.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pie2.add_child(_estado)
	_bajo_cursor = Label.new()
	_bajo_cursor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bajo_cursor.custom_minimum_size = Vector2(520, 0)
	pie2.add_child(_bajo_cursor)
	_confirmar = ConfirmationDialog.new()
	_confirmar.title = "Exportar"
	_confirmar.ok_button_text = "Sobrescribir"
	_confirmar.cancel_button_text = "Cancelar"
	_confirmar.confirmed.connect(_al_confirmar)
	add_child(_confirmar)
	_decir("Nada se escribe en el proyecto hasta pulsar «Exportar a Godot». Rueda = zoom · botón derecho = mover la vista.")


func _al_ver_contenido(si: bool) -> void:
	_vista.ver_contenido = si
	_vista.queue_redraw()


func _borrar_retoques() -> void:
	_retoques.clear()
	_enlaces.clear()
	_puzles.clear()
	_movidos.clear()
	_anadidos.clear()
	_apariciones.clear()
	_sucio = true


func _copiar_texto() -> void:
	DisplayServer.clipboard_set(_texto.text)
	_decir("Texto del mapa copiado al portapapeles.")


func _al_confirmar() -> void:
	if _tras_confirmar.is_valid():
		_tras_confirmar.call()


func _boton(padre: Node, texto: String, al_pulsar: Callable, ayuda: String) -> Button:
	var b: Button = Button.new()
	b.text = texto
	b.tooltip_text = ayuda
	b.pressed.connect(al_pulsar)
	padre.add_child(b)
	return b


func _fila(lista: VBoxContainer, campo: Dictionary) -> void:
	var alg: String = String(campo.get("alg", ""))
	if String(campo["t"]) == "titulo":
		var t: Label = Label.new()
		t.text = String(campo["r"])
		t.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
		t.add_theme_font_size_override("font_size", 13)
		var caja: MarginContainer = MarginContainer.new()
		caja.add_theme_constant_override("margin_top", 10)
		caja.add_child(t)
		lista.add_child(caja)
		_filas.append([caja, alg])
		return
	var k: String = String(campo["k"])
	var fila: HBoxContainer = HBoxContainer.new()
	fila.tooltip_text = String(campo.get("a", ""))
	var r: Label = Label.new()
	r.text = String(campo["r"])
	r.custom_minimum_size = Vector2(175, 0)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	fila.add_child(r)
	var c: Control = null
	match String(campo["t"]):
		"opcion":
			var ob: OptionButton = OptionButton.new()
			var ops: Array = campo["op"]
			if k == "luz":
				ops = []
				for l in Exportador.LUCES:
					ops.append([l, l])
			for o in ops:
				ob.add_item(String(o[1]))
				ob.set_item_metadata(ob.item_count - 1, String(o[0]))
				if String(o[0]) == String(_par[k]):
					ob.select(ob.item_count - 1)
			ob.item_selected.connect(func(i: int) -> void: _cambio(k, String(ob.get_item_metadata(i))))
			c = ob
		"int", "float":
			var sb: SpinBox = SpinBox.new()
			sb.min_value = float(campo["min"])
			sb.max_value = float(campo["max"])
			sb.step = float(campo.get("paso", 1.0)) if String(campo["t"]) == "float" else 1.0
			sb.custom_arrow_step = float(campo.get("paso", 1.0))
			sb.value = float(_par[k])
			var entero: bool = String(campo["t"]) == "int"
			sb.value_changed.connect(func(val: float) -> void: _cambio(k, int(val) if entero else val))
			c = sb
		"bool":
			var cb: CheckBox = CheckBox.new()
			cb.button_pressed = bool(_par[k])
			cb.toggled.connect(func(si: bool) -> void: _cambio(k, si))
			c = cb
		"texto":
			var le: LineEdit = LineEdit.new()
			le.text = String(_par[k])
			le.text_changed.connect(func(txt: String) -> void: _cambio(k, txt))
			c = le
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.tooltip_text = fila.tooltip_text
	fila.add_child(c)
	lista.add_child(fila)
	_controles[k] = c
	_filas.append([fila, alg])


func _cambio(k: String, valor: Variant) -> void:
	if _cargando:
		return
	_par[k] = valor
	if CLAVES_FORMA.has(k):
		_enlaces.clear()
		_puzles.clear()
		_movidos.clear()
		_anadidos.clear()
		_apariciones.clear()
	if CLAVES_FORMA.has(k) and not _retoques.is_empty():
		_retoques.clear()
		_decir("Ha cambiado la forma del mapa: los retoques pintados a mano se han borrado.")
	if k == "estilo" and Exportador.LUCES.has(String(valor)):
		_poner_control("luz", String(valor))          # la luz sigue al estilo (se puede cambiar después)
		_par["luz"] = String(valor)
	_sucio = true


## Pone un valor en su control sin que el control vuelva a avisar del cambio.
func _poner_control(k: String, valor: Variant) -> void:
	var c: Control = _controles.get(k)
	if c == null:
		return
	_cargando = true
	if c is OptionButton:
		for i in range((c as OptionButton).item_count):
			if String((c as OptionButton).get_item_metadata(i)) == String(valor):
				(c as OptionButton).select(i)
	elif c is SpinBox:
		(c as SpinBox).value = float(valor)
	elif c is CheckBox:
		(c as CheckBox).button_pressed = bool(valor)
	elif c is LineEdit:
		(c as LineEdit).text = String(valor)
	_cargando = false


func _otra_semilla() -> void:
	_retoques.clear()
	_enlaces.clear()
	_puzles.clear()
	_movidos.clear()
	_anadidos.clear()
	_apariciones.clear()
	_par["semilla"] = randi() % 1000000
	_poner_control("semilla", _par["semilla"])
	_sucio = true


func _regenerar() -> void:
	_sucio = false
	for f in _filas:
		(f[0] as Control).visible = String(f[1]) == "" or String(f[1]) == String(_par["algoritmo"])
	var t0: int = Time.get_ticks_usec()
	_mapa = Generador.new().generar(_par, _retoques, _enlaces, _puzles, _movidos, _anadidos, _apariciones)
	_apariciones = []                                             # los enlaces enemigo → cofre que siguen valiendo, con los nombres ya al día
	for ap in _mapa["apariciones"]:
		_apariciones.append({"cofre": String(ap["cofre"]), "enemigos": (ap["enemigos"] as Array).duplicate()})
	_movidos = (_mapa["movidos"] as Dictionary).duplicate()       # lo que de verdad se movió (el sitio pedido puede haberse ajustado)
	_anadidos = (_mapa["anadidos"] as Array).duplicate(true)      # y lo que de verdad se añadió, en su casilla final
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_vista.poner(_mapa)
	_refrescar_puzles()
	_refrescar_enemigos()
	_refrescar_cofres()
	_refrescar_salidas()
	_texto.text = Exportador.texto_mapa(_mapa)
	var st: Dictionary = _mapa["stats"]
	var l: PackedStringArray = PackedStringArray()
	l.append("[b]%s[/b] · %d × %d casillas (%.0f × %.0f u) · semilla %d · %.0f ms" % [String(_par["nombre"]), int(_mapa["ancho"]), int(_mapa["alto"]),
		int(_mapa["ancho"]) * 2.3, int(_mapa["alto"]) * 2.3, int(_par["semilla"]), ms])
	l.append("%d salas · %d puertas · %d enemigos · %d cofres · %d jarrones · %d casillas pisables (%d %% del mapa, %d de agua)" % [int(st["salas"]), int(st["puertas"]),
		int(st["enemigos"]), int(st["cofres"]), int(st["jarrones"]), int(st["suelo"]), int(round(float(st["ocupacion"]) * 100.0)), int(st["agua"])])
	if not _retoques.is_empty():
		l.append("%d casillas retocadas a mano." % _retoques.size())
	if not _movidos.is_empty():
		l.append("%d elementos movidos a mano (raya azul: de dónde vienen)." % _movidos.size())
	var errores: PackedStringArray = Exportador.validar(_mapa)
	var mal: String = Exportador.nombre_valido(String(_par["nombre"]))
	if errores.is_empty():
		l.append("[color=#7fd88a]✔ Mapa válido: todo se alcanza desde el inicio y ninguna pieza corta el paso.[/color]")
	for e in errores:
		l.append("[color=#ff7a6b]✖ %s[/color]" % e)
	if mal != "":
		l.append("[color=#ff7a6b]✖ %s[/color]" % mal)
	else:
		var est: Dictionary = Exportador.estado_destino(String(_par["nombre"]))
		if String(est["mapa"]) != "" and not bool(est["mapa_nuestro"]):
			l.append("[color=#e8c56a]● %s es un nivel HECHO A MANO. Al exportar se te pedirá confirmar que lo sustituyes (se guarda copia de todo lo viejo).[/color]" % String(est["mapa"]).get_file())
		elif String(est["horneado"]) != "":
			l.append("[color=#ff7a6b]✖ Existe %s (horneado): este nombre ya no se exporta, para no pisar tus ediciones. Edítalo en Godot o cambia el nombre.[/color]" % String(est["horneado"]).get_file())
		elif String(est["mapa"]) != "":
			l.append("[color=#e8c56a]● %s ya existe (lo generó esta herramienta): exportar lo sobrescribe.[/color]" % String(est["mapa"]).get_file())
	for a in _mapa["avisos"]:
		l.append("[color=#e8c56a]● %s[/color]" % a)
	# Las salidas: bien escritas y a un nivel que el juego conozca.
	var conocidos: Dictionary = load("res://nucleo/niveles.gd").ESCENAS
	for d in String(_par["salida_a"]).replace(";", ",").replace(" ", ",").split(",", false):
		var trozos: PackedStringArray = d.split("=", true, 1)[0].split(":")       # lo de detrás del «=» es el nombre de la llegada de aquí
		if trozos.size() != 2 or trozos[0] == "" or trozos[1] == "":
			l.append("[color=#ff7a6b]✖ Salida «%s» mal escrita: es Nivel:entrada (por ejemplo MonteSumicio:inicio). El juego la ignoraría.[/color]" % d)
		elif not conocidos.has(trozos[0]):
			var parecido: String = ""
			for k in conocidos:
				if String(k).to_lower().replace("_", "") == trozos[0].to_lower().replace("_", ""):
					parecido = " ¿Querías decir «%s»?" % String(k)
			l.append("[color=#e8c56a]● Salida «%s»: el nivel «%s» no está en Niveles.ESCENAS; al pisarla avisará «no lleva a ningún sitio».%s[/color]" % [d, trozos[0], parecido])
	_resumen.text = "\n".join(l)


func _al_pintar(c: Vector2i) -> void:
	if _mapa.is_empty() or c.x < 1 or c.y < 1 or c.x > int(_mapa["ancho"]) - 2 or c.y > int(_mapa["alto"]) - 2:
		return
	var letra: String = _vista.pincel
	if letra.begins_with("cat:"):
		_puzle_en(c, letra.substr(4))
	elif letra == "enlazar":
		_enlazar_en(c)
	elif letra == "borrar":
		if _retoques.has(c):
			_retoques.erase(c)
			_sucio = true
	elif String(_retoques.get(c, "")) != letra:
		_retoques[c] = letra
		_sucio = true


## Pincel «puzle: …»: un clic en una sala le pone ese puzle del catálogo (o se lo quita). Si no cabe, el generador ajusta el suelo;
## si ni así, lo dice en el panel de la derecha.
func _puzle_en(c: Vector2i, cid: String) -> void:
	for s in _mapa["salas"]:
		if not (s["rect"] as Rect2i).has_point(c):
			continue
		var sid: int = int(s["id"])
		if cid == "":
			if _puzles.has(sid):
				_puzles.erase(sid)
				_decir("Puzle quitado de la sala %d." % sid)
				_sucio = true
		elif String(_puzles.get(sid, "")) != cid:
			_puzles[sid] = cid
			_decir("Puzle «%s» pedido para la sala %d. Si no aparece, mira el aviso amarillo del panel de la derecha." % [cid, sid])
			_sucio = true
		return


## Pincel «enlazar»: un clic en un activador (contador, sus braseros, placa o su bloque) lo elige; un clic en una puerta o un puente
## lo enlaza con el elegido. Un clic en una puerta o un puente sin nada elegido lo deja suelto (y el mapa da error hasta enlazarlo).
func _enlazar_en(c: Vector2i) -> void:
	# Enemigo → cofre (18/11): un clic en un enemigo lo elige; un clic en un cofre hace que ese cofre aparezca al caer el enemigo.
	for o in _mapa["objetos"]:
		if (o["c"] as Vector2i) != c:
			continue
		var tipo_o: String = String(o["tipo"])
		if TIPOS_ENEMIGO.has(tipo_o):
			if _vista.resaltada != c:
				_enl_enemigo = _extremo_de(o)
				_vista.seleccion = ""
				_vista.resaltada = c
				_vista.queue_redraw()
				_decir("Enemigo elegido (%s): ahora haz clic en el cofre que debe aparecer cuando caiga." % String(ICONOS[tipo_o][3]))
			return
		if TIPOS_COFRE.has(tipo_o) and _enl_enemigo != "":
			if tipo_o == "cofre_llave":
				_decir("El cofre de la llave no se enlaza: ya aparece al limpiar su sala.")
				return
			var cofre: String = _extremo_de(o)
			var hecho: bool = false
			for ap in _apariciones:
				if String(ap["cofre"]) == cofre:
					if not (ap["enemigos"] as Array).has(_enl_enemigo):
						(ap["enemigos"] as Array).append(_enl_enemigo)
					hecho = true
			if not hecho:
				_apariciones.append({"cofre": cofre, "enemigos": [_enl_enemigo]})
			_decir("Enlazado: ese cofre aparecerá cuando caigan todos sus enemigos enlazados. Para quitarlo: pestaña «Cofres», «Que aparezca siempre».")
			_enl_enemigo = ""
			_vista.resaltada = Vector2i(-1, -1)
			_sucio = true
			return
	for o in _mapa["objetos"]:
		if (o["c"] as Vector2i) != c or String(o["id"]) == "":
			continue
		var id: String = String(o["id"])
		var tipo: String = String(o["tipo"])
		if not (_mapa["activadores"] as Array).has(id) and id.begins_with("cat"):
			# Una pieza cualquiera del puzle (un brasero, el bloque) vale para elegir el activador de su plantilla.
			var prefijo: String = id.split("_")[0] + "_"
			for a in _mapa["activadores"]:
				if String(a).begins_with(prefijo):
					id = String(a)
		if (_mapa["activadores"] as Array).has(id):
			if _vista.seleccion != id:
				_vista.seleccion = id
				_vista.queue_redraw()
				_decir("Activador «%s» elegido: ahora haz clic en la puerta o el puente que debe abrir." % id)
		elif tipo == "puerta" or tipo == "puente":
			if String(_enlaces.get(id, "?")) != _vista.seleccion:
				_enlaces[id] = _vista.seleccion
				_decir(("«%s» enlazada con «%s»." % [id, _vista.seleccion]) if _vista.seleccion != "" else ("«%s» se queda sin enlace: elige antes un activador y vuelve a hacer clic en ella." % id))
				_vista.seleccion = ""
				_sucio = true
		return


func _al_pasar(c: Vector2i) -> void:
	if _mapa.is_empty() or c.x < 0 or c.y < 0 or c.x >= int(_mapa["ancho"]) or c.y >= int(_mapa["alto"]):
		_bajo_cursor.text = ""
		return
	var partes: PackedStringArray = PackedStringArray(["(%d, %d)" % [c.x, c.y]])
	var ch: String = (_mapa["filas"] as PackedStringArray)[c.y][c.x]
	partes.append({"#": "pared", "~": "agua honda", "g": "tierra pisada", "R": "losas"}.get(ch, "suelo"))
	for s in _mapa["salas"]:
		if (s["rect"] as Rect2i).has_point(c):
			var rol: String = String(s["rol"])
			partes.append("sala %d%s" % [int(s["id"]), " (%s)" % String(ROLES[rol][0]) if ROLES.has(rol) else ""])
			break
	for o in _mapa["objetos"]:
		if (o["c"] as Vector2i) == c:
			partes.append(String(ICONOS.get(String(o["tipo"]), ["", null, 0, String(o["tipo"])])[3]) + (" «%s»" % String(o["id"]) if String(o["id"]) != "" else ""))
	for pu in _mapa["puertas"]:
		if (pu["c"] as Vector2i) == c and String(pu["tipo"]) == "paso":
			partes.append("puerta abierta")
	if _retoques.has(c):
		partes.append("retocada")
	_bajo_cursor.text = " · ".join(partes)


func _decir(texto: String) -> void:
	_estado.text = texto


# --- exportar ---

func _exportar(probar: bool) -> void:
	if _sucio:
		_regenerar()
	var nombre: String = String(_par["nombre"])
	var mal: String = Exportador.nombre_valido(nombre)
	if mal != "":
		_decir("No se exporta: " + mal)
		return
	var est: Dictionary = Exportador.estado_destino(nombre)
	if probar and String(est["horneado"]) != "" and String(est["escena"]) != "" and not _es_ajeno(est):
		# Ya horneado: no se exporta (pisaría el .txt del que depende el horneado); se abre tal como está, con las ediciones a mano.
		var pid_h: int = OS.create_process(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), String(est["escena"])])
		_decir(("Abriendo el nivel HORNEADO %s (no se exporta: manda el .tscn con tus ediciones)." % String(est["horneado"]).get_file()) if pid_h > 0 else "No se pudo abrir el juego.")
		return
	_confirmar.title = "Exportar"
	_confirmar.ok_button_text = "Sobrescribir"
	if _es_ajeno(est):
		# Un nivel HECHO A MANO con ese nombre (18/11, Pablo: «Sustituir los viejos»): se puede ocupar su sitio, guardando copia de todo.
		var viejo: PackedStringArray = PackedStringArray()
		if String(est["mapa"]) != "" and not bool(est["mapa_nuestro"]):
			viejo.append("· %s  →  se guarda una copia al lado (…_copia_<fecha>_a_mano.txt)" % String(est["mapa"]))
		if String(est["escena"]) != "" and not bool(est["escena_nuestra"]):
			viejo.append("· %s  →  se guarda una copia al lado; la escena nueva NO lleva sus reglas (el nodo «Reglas»: misiones, diálogos, lo que mira por nombre)" % String(est["escena"]))
		if String(est["horneado"]) != "":
			viejo.append("· %s  →  se renombra a …_copia_<fecha>.tscn (el nivel editado a mano en Godot deja de cargarse)" % String(est["horneado"]))
		_confirmar.title = "Sustituir un nivel hecho a mano"
		_confirmar.ok_button_text = "Sustituir"
		_confirmar.dialog_text = "«%s» es un nivel HECHO A MANO. Si sigues, el mapa que estás viendo ocupa su sitio:\n\n%s\n\nNo se borra nada, pero el nivel viejo deja de ser el que carga el juego, y las pruebas escritas para él fallarán.\nLos niveles que viajan a «%s» seguirán llegando si el mapa nuevo tiene llegadas con los mismos nombres\n(en «Salidas»: Nivel:entrada=nombre_de_la_llegada)." % [nombre, "\n".join(viejo), nombre]
		_tras_confirmar = _hacer_exportar.bind(probar, true)
		_confirmar.popup_centered()
		return
	if String(est["mapa"]) != "" and bool(est["mapa_nuestro"]):
		_confirmar.dialog_text = "%s ya existe (lo generó esta herramienta).\n¿Sobrescribirlo con el mapa que estás viendo?\nSi lo habías retocado a mano se guarda antes una copia." % String(est["mapa"]).get_file()
		_tras_confirmar = _hacer_exportar.bind(probar, false)
		_confirmar.popup_centered()
		return
	_hacer_exportar(probar, false)


## ¿Hay con ese nombre un mapa o una escena que NO generó esta herramienta?
func _es_ajeno(est: Dictionary) -> bool:
	return (String(est["mapa"]) != "" and not bool(est["mapa_nuestro"])) or (String(est["escena"]) != "" and not bool(est["escena_nuestra"]))


func _hacer_exportar(probar: bool, sustituir: bool = false) -> void:
	var res: Dictionary = Exportador.exportar(_mapa, sustituir)
	if not bool(res["ok"]):
		_decir("NO exportado: " + String(res["error"]))
		return
	var nombre: String = String(_par["nombre"])
	var txt: String = "Exportado: " + " y ".join(PackedStringArray(res["escritos"]))
	if String(res["copia"]) != "":
		txt += " (copia del anterior: %s)" % String(res["copia"]).get_file()
	if not (res["apartados"] as Array).is_empty():
		var nombres_ap: PackedStringArray = PackedStringArray()
		for ap in res["apartados"]:
			nombres_ap.append(String(ap).get_file())
		txt = "SUSTITUIDO «%s». Lo viejo queda en: %s" % [nombre, ", ".join(nombres_ap)]
	if load("res://nucleo/niveles.gd").ESCENAS.has(nombre):
		_decir(txt + ".")
	else:
		_decir(txt + ". Para viajar a él desde otro nivel, añade «%s» a Niveles.ESCENAS." % nombre)
	_sucio = true                  # el resumen pasa a decir que el archivo ya existe
	if probar:
		var pid: int = OS.create_process(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), Exportador.ruta_escena(nombre)])
		if pid <= 0:
			_decir("Exportado, pero no se pudo abrir el juego. Ábrelo a mano: " + Exportador.ruta_escena(nombre))


# --- pincel «mover» ---

## Lo que se puede mover y está en esa casilla ("" si nada): su nombre para decirlo.
func _movible_en(c: Vector2i) -> String:
	for o in _mapa["objetos"]:
		if (o["c"] as Vector2i) == c and Generador.MOVIBLES.has(String(o["tipo"])) and not String(o["id"]).begins_with("cat") and not o.has("de_salida"):
			return String(ICONOS.get(String(o["tipo"]), ["", null, 0, String(o["tipo"])])[3])
	return ""


func _al_agarrar(c: Vector2i) -> void:
	var que: String = _movible_en(c)
	if que == "":
		_vista.arrastre_de = Vector2i(-1, -1)
		_decir("Ahí no hay nada que se pueda mover. Se mueven enemigos, braseros, jarrones, cofres, el inicio, las salidas y sus llegadas; un puzle entero, en la pestaña «Puzles».")
		return
	_vista.arrastre_de = c
	_decir("Agarrado: %s de (%d, %d). Suéltalo donde lo quieras; si ese sitio no vale, se pone en el válido más cercano." % [que, c.x, c.y])


func _al_soltar(c: Vector2i) -> void:
	_mover_elemento(_vista.arrastre_de, c)


## Lleva lo que hay en `de` a `c` (lo usa el pincel «mover» y «Mover un enemigo del mapa» de la pestaña «Enemigos»).
func _mover_elemento(de: Vector2i, c: Vector2i) -> void:
	if de.x < 0 or c == de:
		return
	# Algo añadido a mano no es un «movido»: se le cambia la casilla en su propia lista.
	for o in _mapa["objetos"]:
		if (o["c"] as Vector2i) == de and o.has("anadido") and int(o["anadido"]) < _anadidos.size():
			_anadidos[int(o["anadido"])]["c"] = c
			_decir("Movido a (%d, %d). Si ha quedado en otra casilla, lo explica el aviso amarillo de la derecha." % [c.x, c.y])
			_sucio = true
			return
	# Si lo agarrado ya se había movido antes, su movimiento es el mismo: solo cambia el destino.
	var origen_real: Vector2i = de
	for k in _movidos:
		if (_movidos[k] as Vector2i) == de:
			origen_real = k
	if c == origen_real:
		_movidos.erase(origen_real)                    # devuelto a donde lo puso el generador
		_decir("Devuelto a su sitio original (%d, %d)." % [c.x, c.y])
	else:
		_movidos[origen_real] = c
		_decir("Movido a (%d, %d). Si ha quedado en otra casilla o no se ha movido, lo explica el aviso amarillo de la derecha." % [c.x, c.y])
	_sucio = true


# --- pestañas «Enemigos» y «Cofres»: se elige en la pestaña y se pone con un clic en el mapa ---

func _pestana(pestanas: TabContainer, nombre: String) -> VBoxContainer:
	var barra: ScrollContainer = ScrollContainer.new()
	barra.name = nombre
	barra.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pestanas.add_child(barra)
	var lista: VBoxContainer = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 6)
	barra.add_child(lista)
	return lista


## Pone la herramienta de una pestaña ("poner:enemigo", "poner:cofre", "llevar") o la quita (""). Con una puesta, el pincel de abajo
## pasa a «ninguno»; al quitarla, vuelve a mandar el pincel de abajo.
func _herramienta(h: String) -> void:
	if _pincel == null:
		return
	if h == "":
		_en_tipo = ""
		_co_calidad = ""
		_sa_nivel = ""
		_llevar_c = Vector2i(-1, -1)
		_vista.resaltada = Vector2i(-1, -1)
		_vista.pincel = String(_pincel.get_item_metadata(_pincel.selected))
	else:
		_pincel.select(0)
		_vista.pincel = h
	_vista.queue_redraw()
	_refrescar_enemigos.call_deferred()
	_refrescar_cofres.call_deferred()
	_refrescar_salidas.call_deferred()


func _al_elegir_pincel(i: int) -> void:
	_enl_enemigo = ""                                             # un enemigo a medio enlazar no se queda elegido al cambiar de pincel
	_herramienta("")
	_vista.pincel = String(_pincel.get_item_metadata(i))


func _vaciar(lista: VBoxContainer) -> void:
	for h in lista.get_children():
		lista.remove_child(h)
		h.queue_free()


## La primera letra en mayúscula (`capitalize` de Godot pone en mayúscula TODAS las palabras).
func _mayus(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


## En qué sala cae una casilla, para decirlo ("" si en ninguna: un pasillo).
func _sala_de(c: Vector2i) -> String:
	for s in _mapa["salas"]:
		if (s["rect"] as Rect2i).has_point(c):
			return "sala %d" % int(s["id"])
	return "pasillo"


func _refrescar_enemigos() -> void:
	if _lista_enemigos == null or _mapa.is_empty():
		return
	_vaciar(_lista_enemigos)
	_lista_enemigos.add_child(_rotulo_pz("AÑADIR UN ENEMIGO"))
	var que: OptionButton = OptionButton.new()
	que.add_item("(ninguno)")
	que.set_item_metadata(0, "")
	for id in Generador.ORDEN_ENEMIGOS:
		que.add_item(String(Generador.ENEMIGOS[id]["titulo"]))
		que.set_item_metadata(que.item_count - 1, String(id))
		if String(id) == _en_tipo:
			que.select(que.item_count - 1)
	que.item_selected.connect(func(i: int) -> void:
		var elegido: String = String(que.get_item_metadata(i))
		_herramienta("")
		_en_tipo = elegido
		if elegido != "":
			_herramienta("poner:enemigo"))
	_lista_enemigos.add_child(que)
	_lista_enemigos.add_child(_rotulo_pz(("▶ Haz clic en el mapa donde quieras un «%s». Sigue puesto: cada clic añade otro. Para dejarlo, elige «(ninguno)»." % String(Generador.ENEMIGOS[_en_tipo]["titulo"]))
		if _en_tipo != "" else "Elige un enemigo y haz clic en el mapa donde lo quieras. Si la casilla no vale, queda en la válida más cercana.",
		Color(0.4, 0.9, 1.0) if _en_tipo != "" else Color(0.75, 0.75, 0.75), 12))
	# Mover uno de los que ya están (los que repartió el generador y los añadidos).
	var enemigos: Array = (_mapa["objetos"] as Array).filter(func(o: Dictionary) -> bool: return TIPOS_ENEMIGO.has(String(o["tipo"])))
	_lista_enemigos.add_child(_rotulo_pz("\nMOVER UN ENEMIGO DEL MAPA (%d)" % enemigos.size()))
	var cual: OptionButton = OptionButton.new()
	cual.add_item("(elige cuál)")
	cual.set_item_metadata(0, Vector2i(-1, -1))
	for o in enemigos:
		var c: Vector2i = o["c"]
		cual.add_item("%s · %s · (%d, %d)%s" % [_mayus(String(ICONOS[String(o["tipo"])][3])), _sala_de(c), c.x, c.y, " · añadido" if o.has("anadido") else ""])
		cual.set_item_metadata(cual.item_count - 1, c)
		if c == _llevar_c:
			cual.select(cual.item_count - 1)
	cual.item_selected.connect(func(i: int) -> void:
		var elegida: Vector2i = cual.get_item_metadata(i)
		_herramienta("")
		_llevar_c = elegida
		if elegida.x >= 0:
			_vista.resaltada = elegida
			_herramienta("llevar"))
	_lista_enemigos.add_child(cual)
	_lista_enemigos.add_child(_rotulo_pz("▶ Está rodeado en azul en el mapa. Haz clic donde lo quieras." if _llevar_c.x >= 0
		else "Elige uno (se rodea en azul en el mapa) y haz clic donde lo quieras. También vale el pincel «mover».",
		Color(0.4, 0.9, 1.0) if _llevar_c.x >= 0 else Color(0.75, 0.75, 0.75), 12))
	# Los añadidos a mano, con «Quitar».
	var n: int = 0
	for a in _anadidos:
		n += 1 if String(a["que"]) == "enemigo" else 0
	_lista_enemigos.add_child(_rotulo_pz("\nAÑADIDOS A MANO (%d)" % n))
	for i in range(_anadidos.size()):
		var a: Dictionary = _anadidos[i]
		if String(a["que"]) != "enemigo":
			continue
		var fila: HBoxContainer = HBoxContainer.new()
		var t: Label = _rotulo_pz("%s · %s · (%d, %d)" % [String(Generador.ENEMIGOS[String(a["tipo"])]["titulo"]), _sala_de(a["c"]), int(a["c"].x), int(a["c"].y)], Color(0.92, 0.92, 0.92), 14)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(t)
		_boton(fila, "Quitar", _quitar_anadido.bind(i), "Quita este enemigo.")
		_lista_enemigos.add_child(fila)
	if n == 0:
		_lista_enemigos.add_child(_rotulo_pz("Ninguno todavía. Los que reparte el generador se piden en «Enemigos», en la pestaña Mapa.", Color(0.75, 0.75, 0.75), 12))


func _refrescar_cofres() -> void:
	if _lista_cofres == null or _mapa.is_empty():
		return
	_vaciar(_lista_cofres)
	_lista_cofres.add_child(_rotulo_pz("AÑADIR UN COFRE"))
	var cal: OptionButton = OptionButton.new()
	cal.add_item("(elige la calidad)")
	cal.set_item_metadata(0, "")
	for id in Generador.ORDEN_COFRES:
		cal.add_item(String(Generador.COFRES[id]["titulo"]))
		cal.set_item_metadata(cal.item_count - 1, String(id))
		if String(id) == _co_calidad:
			cal.select(cal.item_count - 1)
	cal.item_selected.connect(func(i: int) -> void:
		var elegida: String = String(cal.get_item_metadata(i))
		_herramienta("")
		_co_calidad = elegida
		_co_premio = ""
		if elegida != "":
			if Generador.COFRES[elegida]["premios"] is Dictionary:
				_co_premio = String((Generador.COFRES[elegida]["premios"] as Dictionary).keys()[0])
			_herramienta("poner:cofre"))
	_lista_cofres.add_child(cal)
	if _co_calidad == "comun":
		_lista_cofres.add_child(_rotulo_pz("Recompensa: SE SORTEA (oro, pociones, algún objeto). Para el mismo mapa sale siempre la misma; se ve abajo al ponerlo.", Color(0.92, 0.92, 0.92), 13))
	elif _co_calidad != "":
		_lista_cofres.add_child(_rotulo_pz("Recompensa:", Color(0.92, 0.92, 0.92), 13))
		var pr: OptionButton = OptionButton.new()
		var premios: Dictionary = Generador.COFRES[_co_calidad]["premios"]
		for clave in premios:
			pr.add_item(String(premios[clave]))
			pr.set_item_metadata(pr.item_count - 1, String(clave))
			if String(clave) == _co_premio:
				pr.select(pr.item_count - 1)
		pr.item_selected.connect(func(i: int) -> void: _co_premio = String(pr.get_item_metadata(i)))
		_lista_cofres.add_child(pr)
		if _co_calidad == "legendario":
			_lista_cofres.add_child(_rotulo_pz("Además de lo elegido da siempre 150 de oro y 2 pociones grandes.", Color(0.75, 0.75, 0.75), 12))
	_lista_cofres.add_child(_rotulo_pz(("▶ Haz clic en el mapa donde quieras el cofre %s. Sigue puesto: cada clic añade otro." % String(Generador.COFRES[_co_calidad]["titulo"]).to_lower())
		if _co_calidad != "" else "Elige la calidad y haz clic en el mapa. Un cofre ocupa su casilla: si ahí cortaría el paso, queda en la válida más cercana.",
		Color(0.4, 0.9, 1.0) if _co_calidad != "" else Color(0.75, 0.75, 0.75), 12))
	# Todos los cofres del mapa.
	var cofres: Array = (_mapa["objetos"] as Array).filter(func(o: Dictionary) -> bool: return TIPOS_COFRE.has(String(o["tipo"])))
	_lista_cofres.add_child(_rotulo_pz("\nCOFRES DEL MAPA (%d)" % cofres.size()))
	for o in cofres:
		var c: Vector2i = o["c"]
		var fila: HBoxContainer = HBoxContainer.new()
		var texto: String = "%s · %s · (%d, %d)" % [_mayus(String(ICONOS[String(o["tipo"])][3])), _sala_de(c), c.x, c.y]
		if o.has("anadido") and int(o["anadido"]) < _anadidos.size():
			texto += "\n   da: " + _premio_dicho(_anadidos[int(o["anadido"])])
		elif String(o["tipo"]) == "cofre_tesoro":
			texto += "\n   da: 60 de oro y una poción (lo pone el generador)"
		else:
			texto += "\n   da: la llave del tesoro (lo pone el generador)"
		var atado: Array = _enemigos_de_cofre(o)
		if not atado.is_empty():
			texto += "\n   aparece al caer %s (flecha verde)" % ("su enemigo" if atado.size() == 1 else "sus %d enemigos" % atado.size())
		var t: Label = _rotulo_pz(texto, Color(0.92, 0.92, 0.92), 14)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(t)
		var botones: VBoxContainer = VBoxContainer.new()
		if o.has("anadido"):
			_boton(botones, "Quitar", _quitar_anadido.bind(int(o["anadido"])), "Quita este cofre.")
		if not atado.is_empty():
			_boton(botones, "Que aparezca siempre", _soltar_cofre.bind(_extremo_de(o)), "Quita el enlace con sus enemigos: el cofre está a la vista desde el principio.")
		fila.add_child(botones)
		_lista_cofres.add_child(fila)
	_lista_cofres.add_child(_rotulo_pz("Para cambiar un cofre de sitio: pincel «mover» (abajo) y arrástralo.\nPara que un cofre APAREZCA AL CAER UN ENEMIGO: pincel «enlazar» (abajo), clic en el enemigo y clic en el cofre. Con varios enemigos enlazados, aparece cuando caen todos.", Color(0.75, 0.75, 0.75), 12))


## Las llegadas que tiene un nivel del juego: las `; pieza <nombre> entrada` de su mapa y las que crea por código.
func _llegadas_de(nivel: String) -> Array:
	var res: Array = []
	var ruta: String = HorneadorNivel.ruta_mapa(nivel)
	if ruta != "":
		for linea in FileAccess.get_file_as_string(ruta).split("\n"):
			var t: PackedStringArray = String(linea).strip_edges().substr(1).strip_edges().split(" ", false)
			if String(linea).begins_with(";") and t.size() >= 3 and t[0] == "pieza" and t[2] == "entrada" and not res.has(t[1]):
				res.append(t[1])
	for extra in LLEGADAS_POR_CODIGO.get(nivel, []):
		if not res.has(extra):
			res.append(extra)
	return res


func _fila_campo(lista: VBoxContainer, rotulo: String, control: Control) -> void:
	var fila: HBoxContainer = HBoxContainer.new()
	var r: Label = _rotulo_pz(rotulo, Color(0.92, 0.92, 0.92), 13)
	r.custom_minimum_size = Vector2(130, 0)
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	fila.add_child(r)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(control)
	lista.add_child(fila)


func _refrescar_salidas() -> void:
	if _lista_salidas == null or _mapa.is_empty():
		return
	_vaciar(_lista_salidas)
	_lista_salidas.add_child(_rotulo_pz("AÑADIR UNA SALIDA"))
	var niveles: Array = load("res://nucleo/niveles.gd").ESCENAS.keys()
	niveles.sort()
	var niv: OptionButton = OptionButton.new()
	niv.add_item("(elige el nivel)")
	niv.set_item_metadata(0, "")
	for n in niveles:
		niv.add_item(String(n))
		niv.set_item_metadata(niv.item_count - 1, String(n))
		if String(n) == _sa_nivel:
			niv.select(niv.item_count - 1)
	niv.item_selected.connect(func(i: int) -> void:
		var elegido: String = String(niv.get_item_metadata(i))
		_herramienta("")
		_sa_nivel = elegido
		if elegido != "":
			var hay: Array = _llegadas_de(elegido)
			_sa_entrada = String(hay[0]) if not hay.is_empty() else "inicio"
			_herramienta("poner:salida"))
	_fila_campo(_lista_salidas, "Lleva a", niv)
	if _sa_nivel != "":
		var llegadas: Array = _llegadas_de(_sa_nivel)
		var escrito: LineEdit = LineEdit.new()
		escrito.text = _sa_entrada
		escrito.tooltip_text = "El nombre de la llegada del nivel de destino. Si no existe allí, el juego te deja en su punto de aparición."
		escrito.text_changed.connect(func(t: String) -> void: _sa_entrada = t)
		if not llegadas.is_empty():
			var ent: OptionButton = OptionButton.new()
			for l in llegadas:
				ent.add_item(String(l))
				if String(l) == _sa_entrada:
					ent.select(ent.item_count - 1)
			ent.item_selected.connect(func(i: int) -> void:
				_sa_entrada = ent.get_item_text(i)
				escrito.text = _sa_entrada)
			_fila_campo(_lista_salidas, "Entra allí por", ent)
			_fila_campo(_lista_salidas, "(o escríbela)", escrito)
		else:
			_fila_campo(_lista_salidas, "Entra allí por", escrito)
			_lista_salidas.add_child(_rotulo_pz("No he encontrado llegadas con nombre en el mapa de %s. Si el nombre no existe allí, el juego te deja en su punto de aparición." % _sa_nivel, Color(0.9, 0.78, 0.4), 12))
		var modo: OptionButton = OptionButton.new()
		modo.add_item("al pisarla")
		modo.set_item_metadata(0, "pisar")
		modo.add_item("pulsando E encima")
		modo.set_item_metadata(1, "usar")
		modo.select(1 if _sa_modo == "usar" else 0)
		modo.item_selected.connect(func(i: int) -> void: _sa_modo = String(modo.get_item_metadata(i)))
		_fila_campo(_lista_salidas, "Se activa", modo)
		var ancho: SpinBox = SpinBox.new()
		ancho.min_value = 1
		ancho.max_value = 4
		ancho.value = _sa_ancho
		ancho.tooltip_text = "Casillas seguidas que ocupa: 2 o 3 para una puerta ancha. Van de lado a lado; si no caben, de arriba abajo."
		ancho.value_changed.connect(func(v: float) -> void: _sa_ancho = int(v))
		_fila_campo(_lista_salidas, "Ancho (casillas)", ancho)
		var acc: OptionButton = OptionButton.new()
		for it in [["", "tal cual (solo la marca)"], ["sendero", "con sendero de losas"], ["boca", "boca en la pared de arriba"]]:
			acc.add_item(String(it[1]))
			acc.set_item_metadata(acc.item_count - 1, String(it[0]))
			if String(it[0]) == _sa_acceso:
				acc.select(acc.item_count - 1)
		acc.tooltip_text = "Para que se intuya que por ahí se sale.\n· Sendero: unas casillas de losas (basalto en la cueva) que llegan hasta la salida por el camino que viene del inicio.\n· Boca: excava un hueco de dos casillas hacia arriba en la pared de la sala más cercana al clic; la salida queda al fondo. Ocupa una casilla de ancho.\n  Si cerca no hay pared de arriba con roca detrás, se pone en el suelo con sendero y lo avisa."
		acc.item_selected.connect(func(i: int) -> void: _sa_acceso = String(acc.get_item_metadata(i)))
		_fila_campo(_lista_salidas, "Acceso", acc)
		var marca: CheckBox = CheckBox.new()
		marca.button_pressed = _sa_marca
		marca.text = "se ve en el suelo"
		marca.toggled.connect(func(si: bool) -> void: _sa_marca = si)
		_fila_campo(_lista_salidas, "Marca", marca)
		var lleg: LineEdit = LineEdit.new()
		lleg.text = _sa_llegada
		lleg.placeholder_text = "automático"
		lleg.tooltip_text = "Cómo se llama el punto por el que se entra AQUÍ viniendo de ese nivel. Es lo que otro nivel pone en su salida: <este nivel>:<este nombre>.\nLetras sin acento, cifras y «_». Vacío: llegada_m1, llegada_m2…"
		lleg.text_changed.connect(func(t: String) -> void: _sa_llegada = t)
		_fila_campo(_lista_salidas, "Llegada de aquí", lleg)
		_lista_salidas.add_child(_rotulo_pz("▶ Haz clic en el mapa donde quieras la salida a %s. Sigue puesta: cada clic añade otra." % _sa_nivel, Color(0.4, 0.9, 1.0), 12))
	else:
		_lista_salidas.add_child(_rotulo_pz("Elige a qué nivel lleva y haz clic en el mapa. Al pisarla (o al pulsar E, según elijas) el juego carga ese nivel con un fundido a negro. Junto a cada salida se pone su llegada: por donde se entra aquí viniendo de allí.", Color(0.75, 0.75, 0.75), 12))
	# Todas las salidas del mapa.
	var puestas: Array = []
	for o in _mapa["objetos"]:
		if String(o["tipo"]) == "salida" and not puestas.has(String(o["id"])):
			puestas.append(String(o["id"]))
	_lista_salidas.add_child(_rotulo_pz("\nSALIDAS DEL MAPA (%d)" % puestas.size()))
	for i in range(_anadidos.size()):
		var a: Dictionary = _anadidos[i]
		if String(a["que"]) != "salida":
			continue
		var fila: HBoxContainer = HBoxContainer.new()
		var t: Label = _rotulo_pz("→ %s · %s · (%d, %d)\n   %s%s · %s\n   llegada de aquí: «%s»" % [String(a["tipo"]), _sala_de(a["c"]), int(a["c"].x), int(a["c"].y),
			"al pisarla" if String(a.get("modo", "pisar")) == "pisar" else "pulsando E", "" if int(a.get("ancho", 1)) == 1 else " · %d casillas" % int(a["ancho"]),
			("con marca" if bool(a.get("marca", true)) else "sin marca") + String({"sendero": " · sendero de losas", "boca": " · boca en la pared"}.get(String(a.get("acceso", "")), "")),
			String(a.get("llegada", ""))], Color(0.92, 0.92, 0.92), 14)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(t)
		_boton(fila, "Quitar", _quitar_anadido.bind(i), "Quita esta salida y su llegada.")
		_lista_salidas.add_child(fila)
	for l in _mapa["lineas"]:
		var tl: PackedStringArray = String(l).substr(1).strip_edges().split(" ", false)
		if tl.size() >= 6 and tl[0] == "pieza" and tl[2] == "salida" and tl[1].begins_with("a_salida_"):
			_lista_salidas.add_child(_rotulo_pz("→ %s · %s · (%s, %s)\n   del campo «Salidas» de la pestaña Mapa (se cambia allí)" % [tl[5].trim_prefix("a="), _sala_de(Vector2i(tl[3].to_int(), tl[4].to_int())), tl[3], tl[4]],
				Color(0.8, 0.8, 0.8), 14))
	if puestas.is_empty():
		_lista_salidas.add_child(_rotulo_pz("Ninguna todavía.", Color(0.75, 0.75, 0.75), 12))
	_lista_salidas.add_child(_rotulo_pz("Para cambiar una salida de sitio: pincel «mover» (abajo) y arrástrala. Para que OTRO nivel pueda venir a este, este nivel tiene que estar en la lista de niveles del juego (nucleo/niveles.gd).", Color(0.75, 0.75, 0.75), 12))


## La recompensa de un cofre añadido, dicha para leerla.
func _premio_dicho(a: Dictionary) -> String:
	var calidad: String = String(a["tipo"])
	var premios = Generador.COFRES[calidad]["premios"]
	if premios is Dictionary and (premios as Dictionary).has(String(a.get("premio", ""))):
		return String(premios[String(a["premio"])]) + (" + 150 de oro y 2 pociones grandes" if calidad == "legendario" else "")
	return String(a.get("da", a.get("premio", "?"))).replace("+", " + ").replace(":", " × ").replace("tabla × cofre_pequeno", "una tirada de la tabla «cofre pequeño»") + " (sorteado)"


func _al_clicar(c: Vector2i) -> void:
	if _mapa.is_empty() or c.x < 1 or c.y < 1 or c.x > int(_mapa["ancho"]) - 2 or c.y > int(_mapa["alto"]) - 2:
		return
	match _vista.pincel:
		"poner:enemigo":
			if _en_tipo != "":
				_anadidos.append({"que": "enemigo", "tipo": _en_tipo, "c": c})
				_decir("%s añadido en (%d, %d). Si ha quedado en otra casilla, lo explica el aviso amarillo de la derecha." % [String(Generador.ENEMIGOS[_en_tipo]["titulo"]), c.x, c.y])
				_sucio = true
		"poner:cofre":
			if _co_calidad != "":
				_anadidos.append({"que": "cofre", "tipo": _co_calidad, "premio": _co_premio, "c": c})
				_decir("Cofre %s añadido en (%d, %d). Si ha quedado en otra casilla, lo explica el aviso amarillo de la derecha." % [String(Generador.COFRES[_co_calidad]["titulo"]).to_lower(), c.x, c.y])
				_sucio = true
		"poner:salida":
			if _sa_nivel != "" and _sa_entrada.strip_edges() != "":
				var destino: String = "%s:%s" % [_sa_nivel, _sa_entrada.strip_edges()]
				_anadidos.append({"que": "salida", "tipo": destino, "modo": _sa_modo, "ancho": _sa_ancho, "marca": _sa_marca, "llegada": _sa_llegada.strip_edges(), "acceso": _sa_acceso, "c": c})
				_decir("Salida a %s añadida en (%d, %d). Si ha quedado en otra casilla, lo explica el aviso amarillo de la derecha." % [destino, c.x, c.y])
				_sa_llegada = ""                             # el nombre de la llegada es de ESTA salida: la siguiente pide el suyo
				_sucio = true
			else:
				_decir("Falta el nombre de la llegada del nivel de destino.")
		"llevar":
			if _llevar_c.x >= 0:
				_mover_elemento(_llevar_c, c)
				_herramienta("")


## Cómo se nombra un elemento en un enlace enemigo → cofre: `a<n>` si es un añadido a mano; si no, la casilla donde lo puso el
## generador (la de antes de moverlo), para que el enlace no se pierda al mover.
func _extremo_de(o: Dictionary) -> String:
	if o.has("anadido"):
		return "a%d" % int(o["anadido"])
	var c: Vector2i = o["c"]
	for k in _movidos:
		if (_movidos[k] as Vector2i) == c:
			c = k
	return "%d,%d" % [c.x, c.y]


## Los enemigos de los que depende el cofre `o` (vacío si aparece siempre).
func _enemigos_de_cofre(o: Dictionary) -> Array:
	var cofre: String = _extremo_de(o)
	for ap in _apariciones:
		if String(ap["cofre"]) == cofre:
			return ap["enemigos"]
	return []


func _soltar_cofre(cofre: String) -> void:
	for i in range(_apariciones.size() - 1, -1, -1):
		if String(_apariciones[i]["cofre"]) == cofre:
			_apariciones.remove_at(i)
	_decir("Ese cofre vuelve a estar a la vista desde el principio.")
	_sucio = true


func _quitar_anadido(i: int) -> void:
	if i >= 0 and i < _anadidos.size():
		# Los enlaces enemigo → cofre nombran los añadidos por su número: los que apuntan a este se quitan y los posteriores bajan uno.
		var renombrar: Callable = func(e: String) -> String:
			if e.begins_with("a") and e.substr(1).is_valid_int():
				var n: int = e.substr(1).to_int()
				return "" if n == i else ("a%d" % (n - 1) if n > i else e)
			return e
		for k in range(_apariciones.size() - 1, -1, -1):
			var ap: Dictionary = _apariciones[k]
			ap["cofre"] = renombrar.call(String(ap["cofre"]))
			var quedan: Array = []
			for en in ap["enemigos"]:
				var nuevo: String = renombrar.call(String(en))
				if nuevo != "":
					quedan.append(nuevo)
			ap["enemigos"] = quedan
			if String(ap["cofre"]) == "" or quedan.is_empty():
				_apariciones.remove_at(k)
		_anadidos.remove_at(i)
		_decir("Quitado.")
		_sucio = true


# --- pestaña «Puzles» ---

## Una sala, dicha como se ve en el mapa: su número (el que lleva pintado) y su tamaño.
func _nombre_sala(s: Dictionary) -> String:
	var r: Rect2i = s["rect"]
	return "Sala %d · %d × %d" % [int(s["id"]), r.size.x, r.size.y]


## Un desplegable de salas libres (sin papel: ni inicio, ni tesoro, ni llave, ni otro puzle). `primera` es el texto de la opción vacía.
func _desplegable_salas(primera: String, elegida: int = -1) -> OptionButton:
	var ob: OptionButton = OptionButton.new()
	ob.add_item(primera)
	ob.set_item_metadata(0, -1)
	for s in _mapa["salas"]:
		if String(s["rol"]) == "":
			ob.add_item(_nombre_sala(s))
			ob.set_item_metadata(ob.item_count - 1, int(s["id"]))
			if int(s["id"]) == elegida:
				ob.select(ob.item_count - 1)
	return ob


func _rotulo_pz(texto: String, color: Color = Color(0.95, 0.75, 0.35), tam: int = 13) -> Label:
	var t: Label = Label.new()
	t.text = texto
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_color_override("font_color", color)
	t.add_theme_font_size_override("font_size", tam)
	return t


## Rehace la pestaña con lo que hay en el mapa: el formulario de añadir, los puzles puestos a mano (con «Mover a…» y «Quitar») y los
## que ha repartido el generador solo (con «Mover a…», que lo fija a mano en la sala elegida y descuenta uno de los automáticos).
func _refrescar_puzles() -> void:
	if _lista_puzles == null:
		return
	for h in _lista_puzles.get_children():
		_lista_puzles.remove_child(h)
		h.queue_free()
	var cat: Dictionary = Catalogo.todos()
	var puestos: Dictionary = _mapa["puzles"]
	_lista_puzles.add_child(_rotulo_pz("AÑADIR UN PUZLE"))
	var que: OptionButton = OptionButton.new()
	que.add_item("(elige un puzle)")
	que.set_item_metadata(0, "")
	var ids: Array = cat.keys()
	ids.sort()
	for cid in ids:
		que.add_item(String(cat[cid]["titulo"]))
		que.set_item_metadata(que.item_count - 1, String(cid))
		que.set_item_tooltip(que.item_count - 1, "%s · tipo «%s»%s · %d × %d casillas" % [String(cid), String(cat[cid]["tipo"]),
			(" · pide " + String(cat[cid]["pide"])) if String(cat[cid]["pide"]) != "" else "", int(cat[cid]["ancho"]), int(cat[cid]["alto"])])
		if String(cid) == _pz_que:
			que.select(que.item_count - 1)
	que.item_selected.connect(func(i: int) -> void: _pz_que = String(que.get_item_metadata(i)))
	_lista_puzles.add_child(que)
	var fila_a: HBoxContainer = HBoxContainer.new()
	var donde: OptionButton = _desplegable_salas("(elige una sala)", _pz_sala)
	donde.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	donde.item_selected.connect(func(i: int) -> void: _pz_sala = int(donde.get_item_metadata(i)))
	fila_a.add_child(donde)
	_boton(fila_a, "Añadir", _pz_anadir, "Pone el puzle elegido en la sala elegida. Si no cabe, se excava la roca de alrededor; si ni así, lo dice abajo.")
	_lista_puzles.add_child(fila_a)
	_lista_puzles.add_child(_rotulo_pz("El número de cada sala es el que lleva pintado en el mapa. Solo salen las salas libres: una sala lleva un puzle como mucho.", Color(0.75, 0.75, 0.75), 12))
	# Puestos a mano.
	_lista_puzles.add_child(_rotulo_pz("\nPUESTOS A MANO (%d)" % _puzles.size()))
	var a_mano: Array = _puzles.keys()
	a_mano.sort()
	for sid in a_mano:
		var cid: String = String(_puzles[sid])
		var bien: bool = String(puestos.get(int(sid), "")) == cid
		_lista_puzles.add_child(_fila_puzle(int(sid), cid, true, bien))
	if _puzles.is_empty():
		_lista_puzles.add_child(_rotulo_pz("Ninguno todavía.", Color(0.75, 0.75, 0.75), 12))
	# Repartidos por el generador.
	var solos: Array = []
	for sid in puestos:
		if not _puzles.has(sid):
			solos.append(sid)
	solos.sort()
	_lista_puzles.add_child(_rotulo_pz("\nREPARTIDOS SOLOS (%d)" % solos.size()))
	for sid in solos:
		_lista_puzles.add_child(_fila_puzle(int(sid), String(puestos[sid]), false, true))
	if solos.is_empty():
		_lista_puzles.add_child(_rotulo_pz("Ninguno. Su número se pide en «Puzles del catálogo», en la pestaña Mapa.", Color(0.75, 0.75, 0.75), 12))


## La fila de un puzle: dónde está, «Mover a…» y «Quitar».
func _fila_puzle(sid: int, cid: String, a_mano: bool, bien: bool) -> Control:
	var cat: Dictionary = Catalogo.todos()
	var caja: VBoxContainer = VBoxContainer.new()
	var titulo: String = String(cat[cid]["titulo"]) if cat.has(cid) else cid
	var sala_txt: String = "Sala %d" % sid
	for s in _mapa["salas"]:
		if int(s["id"]) == sid:
			sala_txt = _nombre_sala(s)
	caja.add_child(_rotulo_pz(("%s — %s" % [sala_txt, titulo]) if bien else ("✖ %s — %s: NO se ha podido poner (mira el aviso amarillo de la derecha)" % [sala_txt, titulo]),
		Color(0.92, 0.92, 0.92) if bien else Color(1.0, 0.48, 0.42), 14))
	var fila: HBoxContainer = HBoxContainer.new()
	var mover: OptionButton = _desplegable_salas("Mover a…")
	mover.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mover.tooltip_text = "Lleva este puzle a otra sala libre." if a_mano else "Lo lleva a la sala elegida y lo deja puesto a mano (se descuenta uno de «Puzles del catálogo»)."
	mover.item_selected.connect(func(i: int) -> void: _pz_mover(sid, cid, int(mover.get_item_metadata(i)), a_mano))
	fila.add_child(mover)
	if a_mano:
		_boton(fila, "Quitar", func() -> void: _pz_quitar(sid), "Quita este puzle de su sala.")
	caja.add_child(fila)
	return caja


func _pz_anadir() -> void:
	if _pz_que == "" or _pz_sala < 0:
		_decir("Elige primero un puzle y una sala.")
		return
	_puzles[_pz_sala] = _pz_que
	_decir("Puzle «%s» pedido para la sala %d." % [_pz_que, _pz_sala])
	_pz_sala = -1
	_sucio = true


func _pz_mover(de: int, cid: String, a: int, a_mano: bool) -> void:
	if a < 0 or a == de:
		return
	if a_mano:
		_puzles.erase(de)
	else:
		# Era de los repartidos solos: pasa a estar puesto a mano y se pide uno menos de los automáticos, para que no salga otro en su lugar.
		_par["puzles"] = maxi(0, int(_par["puzles"]) - 1)
		_poner_control("puzles", _par["puzles"])
	_puzles[a] = cid
	_decir("Puzle «%s» movido de la sala %d a la sala %d." % [cid, de, a])
	_sucio = true


func _pz_quitar(sid: int) -> void:
	if _puzles.has(sid):
		_puzles.erase(sid)
		_decir("Puzle quitado de la sala %d." % sid)
		_sucio = true


# --- hornear ---

## Botón «Hornear»: exporta el mapa que se ve y lo convierte en `Nivel_<Nombre>.tscn`, el nivel editable en Godot. Lo hace otro proceso
## sin ventana (hornear_generado.gd), que abre el nivel y llama al `hornear()` de la maqueta: lo mismo que F9 dentro del juego.
func _hornear() -> void:
	if _pid_horno > 0:
		_decir("Ya se está horneando «%s»: espera a que acabe." % _nombre_horno)
		return
	if _sucio:
		_regenerar()
	var nombre: String = String(_par["nombre"])
	var mal: String = Exportador.nombre_valido(nombre)
	if mal != "":
		_decir("No se hornea: " + mal)
		return
	var errores: PackedStringArray = Exportador.validar(_mapa)
	if not errores.is_empty():
		_decir("No se hornea: el mapa no pasa la validación (%s)" % errores[0])
		return
	var est: Dictionary = Exportador.estado_destino(nombre)
	if String(est["horneado"]) != "":
		_decir("«%s» ya está horneado: edítalo en Godot (%s). Para hornear otro mapa, cambia el «Nombre del nivel»." % [nombre, String(est["horneado"])])
		return
	var txt: String = "Se exporta «%s» y se convierte en mundo/datos_nivel/Nivel_%s.tscn, editable en Godot.\n\n" % [nombre, nombre]
	txt += "· Es el último paso: con el nivel horneado, esta herramienta ya no vuelve a exportar ese nombre (no pisa tus ediciones).\n"
	txt += "· En el .tscn se editan las paredes y el decorado. El suelo, los enemigos y los puzles siguen saliendo de mapas/%s.txt.\n" % nombre
	_confirmar.title = "Hornear"
	_confirmar.ok_button_text = "Hornear"
	_confirmar.dialog_text = txt
	_tras_confirmar = _hacer_hornear
	_confirmar.popup_centered()


func _hacer_hornear() -> void:
	var res: Dictionary = Exportador.exportar(_mapa)
	if not bool(res["ok"]):
		_decir("NO horneado: " + String(res["error"]))
		return
	_nombre_horno = String(_par["nombre"])
	_pid_horno = OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://herramientas/generador_mapas/hornear_generado.gd", "--", _nombre_horno])
	if _pid_horno <= 0:
		_pid_horno = 0
		_decir("Exportado, pero no se pudo lanzar el horneado. A mano: abre el nivel con «Probar en el juego» y pulsa F9.")
		return
	_decir("HORNEANDO «%s»… tarda unos segundos (otro proceso abre el nivel sin ventana y lo guarda)." % _nombre_horno)


func _fin_hornear() -> void:
	_pid_horno = 0
	var est: Dictionary = Exportador.estado_destino(_nombre_horno)
	if String(est["horneado"]) != "":
		_decir("Horneado: %s. Ábrelo en el editor de Godot para retocarlo; «Probar en el juego» lo abre ya horneado." % String(est["horneado"]))
	else:
		_decir("El horneado de «%s» no ha dejado el archivo. A mano: «Probar en el juego» y F9 dentro del nivel (el aviso sale en su pantalla)." % _nombre_horno)
	_sucio = true                  # el resumen pasa a decir que ya está horneado


# --- abrir un mapa generado ---

func _llenar_abrir() -> void:
	var menu: PopupMenu = _abrir.get_popup()
	menu.clear()
	var d: DirAccess = DirAccess.open(Exportador.DIR_MAPAS)
	if d != null:
		var archivos: PackedStringArray = d.get_files()
		archivos.sort()
		for f in archivos:
			if f.ends_with(".txt") and FileAccess.get_file_as_string(Exportador.DIR_MAPAS + f).contains(Exportador.MARCA):
				menu.add_item(f.get_basename())
	if menu.item_count == 0:
		menu.add_item("(todavía no hay ninguno)")
		menu.set_item_disabled(0, true)


func _al_abrir(id: int) -> void:
	var menu: PopupMenu = _abrir.get_popup()
	var nombre: String = menu.get_item_text(menu.get_item_index(id))
	var texto: String = FileAccess.get_file_as_string(Exportador.ruta_mapa(nombre))
	var par: Dictionary = Exportador._tipar(Exportador.parametros_de(texto))
	if par.is_empty():
		_decir("%s no guarda sus parámetros: no se puede abrir." % nombre)
		return
	_par = Generador.parametros_defecto()
	_par.merge(par, true)
	_retoques = Exportador.retoques_de(texto)
	_enlaces = Exportador.enlaces_de(texto)
	_puzles = Exportador.puzles_de(texto)
	_movidos = Exportador.movidos_de(texto)
	_anadidos = Exportador.anadidos_de(texto)
	_apariciones = Exportador.apariciones_de(texto)
	for k in _controles:
		_poner_control(String(k), _par[k])
	_decir("Abierto %s: mismos parámetros, semilla y retoques con los que se exportó." % nombre)
	_sucio = true
