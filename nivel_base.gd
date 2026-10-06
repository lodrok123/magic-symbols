extends Node2D

## NIVEL BASE: EL MOTOR COMÚN DE TODOS LOS NIVELES DE PRUEBAS.
##
## Aquí vive TODO lo que no es de un nivel concreto: cómo se construye un plano de letras
## (suelos, agua con su hielo, árboles, puente, tótems, fogatas, bloques empujables...), el
## jugador y la cámara, la interfaz, los NPC y el diálogo, los puestos con su tendero, la
## mochila y el botín, el decorado recogible, los goblins con IA, los puntos de guardado, la
## pantalla de muerte y las tareas de la puerta final.
##
## Un NIVEL es un script pequeño que hereda de este y solo pone sus DATOS:
##
##   nivel_base.gd               <- ESTE ARCHIVO (el motor)
##     ├─ test_jugabilidad.gd    el mapa de siempre (23x23)
##     ├─ mundo.gd               el mapa grande (40x34)
##     ├─ test_2.gd              el laboratorio de elementos (40x40)
##     └─ vfx_lab_mundo.gd       cada elemento aislado en su bahía
##
## Antes era al revés (el motor estaba dentro de test_jugabilidad.gd y los demás niveles
## dependían de unos "ganchos" que había que no borrar). Al invertirlo, editar un nivel ya no
## puede romper a los otros: lo común está aquí y cada nivel solo sobrescribe lo suyo.
##
## LO QUE UN NIVEL PUEDE DAR (todas tienen un valor por defecto vacío):
##   _mapa()               el plano (obligatorio)          _lista_props()       decorado
##   _lista_setos()        setos secos sueltos             _suelo_objetos()     oro y pociones
##   _celdas_guardado()    baldosas de guardado            _lista_empujables()  bloques empujables
##   _puestos()            puestos de venta extra          _definir_encargos()  encargos (letra M)
##   _letra_extra()        letras propias del plano        _extras_nivel()      lo que quiera al final
##   _repertorio_inicial() sellos y glifos con que se empieza
##   _progreso() / _refrescar_hud() / _actualizar_tareas()   si sus tareas no son las 4 de siempre
##
## EL PLANO ES UN DATO: cambiar el nivel es cambiar letras.
##   #  árbol (muro físico)            .  suelo de hierba
##   S  inicio                         ~  agua (se congela con hielo y se queda helada)
##   g  plataforma de tierra           v  hierba transitable   G  hierba tupida (cierra el paso)
##   p  baldosa de contacto            K  placa de PESO (solo la pisa un bloque, no el jugador)
##   i  tótem de rayo (tiende el puente b)    j  tótem de fuego    k  tótem de agua
##   a  desbloqueo: agua + barrera     w  desbloqueo: viento + 2.º hueco de glifos
##   n  puesto de la LIBRERA           Q  puesto del ALQUIMISTA (mejoras)
##      (el puesto ocupa x y x+1; el tendero se coloca AL NORTE, en x,y-1)
##   m  NPC guardabosques (habla)      M  guardabosques con ENCARGOS
##   B  barrera de fuego (solo el agua la apaga)
##   F  fuente de fuego (no se apaga; el viento recoge su llama)
##   T  antorcha apagada               O  fogata del encargo de apagar fuego
##   A  arquero    W  goblin guerrero  D  dummy de pruebas
##   s seta   f flor   q raíz          plantas que dan ingredientes al reaccionar con un elemento
##   z seto seco   l tronco   h setas   r telaraña   (arden; telaraña y seto son muro hasta quemarlos)
##   X  puerta final (se abre al completar las tareas)    E  salida
##
## LAS CUATRO TAREAS POR DEFECTO (la puerta final tiene 4 llamas, una por tarea):
##   1. Pisar la baldosa de contacto    3. Hablar con un NPC
##   2. Matar a los goblins             4. Encender las antorchas
##
## EL ARTE SALE DE export_godot/ (lo aprobado en el pipeline): bloques, árboles y props de
## terrain/bosque_01 y los personajes de characters/. Ver CONTRATO_GODOT.md.


## --- Progresión de runas ---
## Se empieza con fuego + flecha (para quemar la hierba) y rayo (para el interruptor).
## Lo demás se gana pisando las losas de desbloqueo.
const SELLOS_INICIO: PackedStringArray = ["fuego", "rayo"]
const GLIFOS_INICIO: PackedStringArray = ["flecha"]
const HUECOS_INICIO: int = 1
const HUECOS_TRAS_VIENTO: int = 2

const APUNTAR_CON_RATON: bool = true
const PALETA_RUNAS: bool = true

## --- Geometría ---
## Los bloques del pack miden 128 x 102 (cara de arriba 128 x 64) y la rejilla del juego
## es la de IsoGrid (rombo de 116 x 55). Se escalan para encajar: un 9 % en horizontal y
## un 14 % en vertical, que a simple vista no se nota.
const SX: float = 116.0 / 128.0
const SY: float = 55.0 / 64.0
const CARA_Y: float = 33.0          ## fila del sprite donde está el centro de la cara de arriba

const ORIGEN: Vector2 = Vector2(1400.0, 80.0)
const ZOOM: float = 1.45
const MARGEN: float = 150.0
const SEGUIMIENTO: float = 6.0

const RAIZ_BOSQUE: String = "res://export_godot/terrain/bosque_01/sprites/"
const PANEL_UI: String = "res://Assets/kenney_fantasy-ui-borders/PNG/Default/Panel/panel-000.png"

const ARBOLES: Array = ["oak", "pine", "green_d", "green_l", "pine_g", "oak", "pine", "birch", "lime"]
const ESCALA_ARBOL: float = 1.15

## Un árbol que está DELANTE de un personaje (más cerca de la cámara) y lo tapa se
## vuelve casi transparente, para que nunca se pierda nada detrás del bosque.
const ALPHA_TAPANDO: float = 0.22
const VEL_FUNDIDO: float = 9.0

## Escala y colisión de cada prop. Un `true` en la segunda columna = tiene cuerpo.
const PROP_DATOS: Dictionary = {
	"barrel": [1.25, true], "crate": [1.25, true], "boulder": [1.3, true],
	"stump": [1.2, true], "log": [1.2, true], "signpost": [1.2, true],
	"cairn_deco": [1.2, false],
	"bush": [1.4, false], "bush_berry": [1.4, false], "fern": [1.4, false],
	"flowers": [1.4, false], "mushrooms": [1.5, false], "lavender": [1.4, false],
	"grass_clump": [1.5, false], "groundcover": [1.6, false], "rocks": [1.4, false],
}

const NEUTRAL_SCENE: PackedScene = preload("res://NeutralBlock.tscn")
const GRASS_SCENE: PackedScene = preload("res://GrassBlock.tscn")
const WATER_SCENE: PackedScene = preload("res://WaterBlock.tscn")
const FOGATA: Script = preload("res://fogata.gd")
const ARCHER_SCENE: PackedScene = preload("res://Archer.tscn")
const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const GOAL_SCENE: PackedScene = preload("res://Goal.tscn")

const NOMBRE_TAREA: Dictionary = {
	"baldosa": "Baldosa de contacto",
	"goblins": "Matar a los goblins",
	"npc": "Hablar con un NPC",
	"antorchas": "Encender las antorchas",
}

const DIALOGOS: Dictionary = {
	"bookseller_woman": {
		"nombre": "Librera",
		"lineas": [
			"¡Una aprendiz de runas! Hacía tiempo que nadie cruzaba el sendero.",
			"Recuerda: el sello es el elemento y el glifo es la forma. Elige uno de cada y dibújalos en el libro.",
			"Si el fuego te estorba, el agua lo apaga. Y si el agua te estorba, ya sabrás qué hacer.",
		],
	},
	"ranger_human": {
		"nombre": "Guardabosques",
		"lineas": [
			"Cuidado al sur: hay un goblin con hacha y dos arqueros que vigilan el camino.",
			"El rayo los aturde, y el agua conduce la corriente. Úsala para llegar a donde no alcanzas.",
			"Las antorchas de la plataforma no se encienden solas: el fuego tendrá que viajar hasta ellas.",
			"MONDONGO",
		],
	},
}


## --- El puntero (igual que el del Blockout) ---
class Puntero extends Node2D:
	var apunta: Vector2 = Vector2.RIGHT

	func _process(_delta: float) -> void:
		var a: Vector2 = get_global_mouse_position() - global_position
		if a != Vector2.ZERO:
			apunta = a.normalized()
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 11.0, Color(0.05, 0.05, 0.08, 0.7))
		draw_circle(Vector2.ZERO, 9.0, Color(0.85, 0.80, 0.95, 0.98))
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(1, 1, 1, 0.7), 1.5, true)
		draw_line(apunta * 16.0, apunta * 34.0, Color(0.05, 0.05, 0.08, 0.7), 5.0, true)
		draw_line(apunta * 16.0, apunta * 34.0, Color(1, 1, 1, 0.95), 2.5, true)


## Cuerpo sólido que solo existe mientras arde lo que tiene al lado (la barrera de
## fuego). Cuando el agua apaga la hoguera, deja de estorbar.
class Bloqueo extends StaticBody2D:
	var fuente: Node = null
	var _forma: CollisionShape2D = null
	var _activo: bool = true

	func _ready() -> void:
		_forma = CollisionShape2D.new()
		_forma.shape = IsoGrid.footprint(0.95)
		add_child(_forma)

	func _physics_process(_delta: float) -> void:
		var arde: bool = is_instance_valid(fuente) and bool(fuente.get("is_lit"))
		if arde != _activo:
			_activo = arde
			_forma.set_deferred("disabled", not arde)


## Una casilla que reacciona al PISARLA el jugador: la baldosa de contacto y las losas de
## desbloqueo. Dibuja un anillo en el suelo (más vivo mientras está sin usar).
class Disparador extends Area2D:
	signal pisado

	var color: Color = Color(1, 1, 1)
	var rotulo: String = ""
	var una_vez: bool = true
	var usado: bool = false

	func _ready() -> void:
		var forma := CollisionShape2D.new()
		forma.shape = IsoGrid.footprint(0.7)
		add_child(forma)
		body_entered.connect(_on_body_entered)
		z_index = -1

	func _on_body_entered(body: Node) -> void:
		if not body.is_in_group("player"):
			return
		_activar()

	func _activar() -> void:
		if usado and una_vez:
			return
		usado = true
		pisado.emit()
		queue_redraw()

	func _process(_delta: float) -> void:
		queue_redraw()
		# Un bloque empujado encima (grupo "empujable") pesa lo mismo que el jugador.
		if not usado:
			for b in get_overlapping_bodies():
				if b.is_in_group("empujable"):
					_activar()
					break

	func _draw() -> void:
		var t: float = Time.get_ticks_msec() / 1000.0
		var a: float = 0.35 if usado else 0.65 + 0.3 * sin(t * 3.0)
		var c := Color(color.r, color.g, color.b, a)
		var puntos := PackedVector2Array()
		for i in range(25):
			var ang: float = TAU * float(i) / 24.0
			puntos.append(Vector2(cos(ang) * 38.0, sin(ang) * 18.0))
		draw_polyline(puntos, c, 3.0, true)
		var interior := PackedVector2Array()
		for i in range(25):
			var ang2: float = TAU * float(i) / 24.0
			interior.append(Vector2(cos(ang2) * 24.0, sin(ang2) * 11.0))
		draw_polyline(interior, Color(c.r, c.g, c.b, a * 0.6), 2.0, true)
		if rotulo != "":
			var fuente: Font = ThemeDB.fallback_font
			var ancho: float = fuente.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(fuente, Vector2(-ancho * 0.5, 4.0), rotulo,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.9 if not usado else 0.45))


## Baldosa de guardado (checkpoint): una losa de piedra con una runa en cruz. Al pisarla se
## enciende (la runa brilla y late) y pasa a ser el punto donde reapareces. Solo hay una
## activa a la vez: al pisar otra, la anterior se apaga.
class Punto_guardado extends Area2D:
	signal activado

	var tex_base: Texture2D = null
	var tex_runa: Texture2D = null
	var ancla: Vector2 = Vector2.ZERO
	var color: Color = Color(0.45, 1.0, 0.7)
	var activo: bool = false
	var _base: Sprite2D
	var _runa: Sprite2D
	var _luz: PointLight2D
	var _t: float = 0.0

	func _ready() -> void:
		z_index = -1
		var forma := CollisionShape2D.new()
		forma.shape = IsoGrid.footprint(0.7)
		add_child(forma)
		_base = _sprite(tex_base)
		add_child(_base)
		_runa = _sprite(tex_runa)
		_runa.modulate = Color(color.r, color.g, color.b, 0.0)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_runa.material = mat
		add_child(_runa)
		_luz = Glow.attach(self, color, 70.0, 0.0)
		_luz.position = Vector2(0.0, -2.0)
		_base.modulate = Color(0.82, 0.82, 0.86)
		body_entered.connect(_on_body_entered)

	func _sprite(tex: Texture2D) -> Sprite2D:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2(0.5, 0.5)
		s.offset = -ancla
		return s

	func _on_body_entered(body: Node) -> void:
		if activo or not body.is_in_group("player"):
			return
		encender()
		activado.emit()

	func encender() -> void:
		activo = true
		_base.modulate = Color.WHITE
		BlockFx.burst(self, "magia")
		Glow.flash(self, color, 110.0, 0.9)
		Sfx.play(self, "prender")

	func apagar() -> void:
		activo = false
		_base.modulate = Color(0.82, 0.82, 0.86)
		_runa.modulate.a = 0.0
		_luz.energy = 0.0

	func _process(delta: float) -> void:
		if not activo:
			return
		_t += delta
		var pulso: float = 0.75 + 0.25 * sin(_t * 2.6)
		_runa.modulate.a = pulso
		_luz.energy = 0.25 + 0.2 * pulso


## La ventana de la tienda. Pausa el juego mientras esta abierta (como el dialogo) y se
## maneja con raton (botones), con las teclas 1-9 o cerrando con E / Esc. No decide nada:
## avisa con `comprar(id)` y el nivel es quien cobra y entrega.
class Tienda extends CanvasLayer:
	signal comprar(id: String)
	signal cerrado

	var abierto: bool = false
	var panel_textura: Texture2D = null
	var _oro: Label = null
	var _nota: Label = null
	var _lista: VBoxContainer = null
	var _ids: Array = []
	var titulo_texto: String = "Puesto de pociones y libros"

	func _ready() -> void:
		layer = 31
		process_mode = Node.PROCESS_MODE_ALWAYS
		visible = false

		var panel := PanelContainer.new()
		if panel_textura != null:
			var estilo := StyleBoxTexture.new()
			estilo.texture = panel_textura
			estilo.texture_margin_left = 18.0
			estilo.texture_margin_right = 18.0
			estilo.texture_margin_top = 18.0
			estilo.texture_margin_bottom = 18.0
			estilo.content_margin_left = 30.0
			estilo.content_margin_right = 30.0
			estilo.content_margin_top = 22.0
			estilo.content_margin_bottom = 20.0
			estilo.modulate_color = Color(0.10, 0.13, 0.26, 0.96)
			panel.add_theme_stylebox_override("panel", estilo)
		add_child(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		panel.offset_left = -270.0
		panel.offset_right = 270.0
		panel.offset_top = -250.0
		panel.offset_bottom = 250.0

		var caja := VBoxContainer.new()
		caja.add_theme_constant_override("separation", 10)
		panel.add_child(caja)

		var titulo := Label.new()
		titulo.text = titulo_texto
		titulo.add_theme_font_size_override("font_size", 20)
		titulo.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
		caja.add_child(titulo)

		_oro = Label.new()
		_oro.add_theme_font_size_override("font_size", 16)
		caja.add_child(_oro)

		_lista = VBoxContainer.new()
		_lista.add_theme_constant_override("separation", 6)
		caja.add_child(_lista)

		_nota = Label.new()
		_nota.add_theme_font_size_override("font_size", 15)
		_nota.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
		caja.add_child(_nota)

		var pista := Label.new()
		pista.text = "[1-9] o clic para comprar    [E / Esc] cerrar"
		pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pista.add_theme_font_size_override("font_size", 14)
		pista.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0, 0.8))
		caja.add_child(pista)

	func abrir(articulos: Array, oro: int) -> void:
		abierto = true
		visible = true
		_nota.text = ""
		refrescar(articulos, oro)
		get_tree().paused = true

	## Redibuja la lista: oro actual, y cada articulo con su precio o "agotado".
	func refrescar(articulos: Array, oro: int) -> void:
		_oro.text = "Oro: %d" % oro
		for h in _lista.get_children():
			h.queue_free()
		_ids.clear()
		var n: int = 1
		for a in articulos:
			var d: Dictionary = a
			var b := Button.new()
			var agotado: bool = bool(d.get("agotado", false))
			var txt: String = "[%d]  %s  -  %s" % [n, String(d["nombre"]), String(d["desc"])]
			txt += "      AGOTADO" if agotado else "      %d oro" % int(d["precio"])
			b.text = txt
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = agotado
			b.pressed.connect(_pedir.bind(String(d["id"])))
			_lista.add_child(b)
			_ids.append(String(d["id"]) if not agotado else "")
			n += 1

	func decir(texto: String) -> void:
		_nota.text = texto

	func _pedir(id: String) -> void:
		comprar.emit(id)

	func cerrar() -> void:
		abierto = false
		visible = false
		get_tree().paused = false
		cerrado.emit()

	func _input(event: InputEvent) -> void:
		if not abierto:
			return
		var k := event as InputEventKey
		if k == null or not k.pressed or k.echo:
			return
		if k.keycode == KEY_E or k.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			cerrar()
			return
		var i: int = k.keycode - KEY_1
		if i >= 0 and i < _ids.size() and String(_ids[i]) != "":
			get_viewport().set_input_as_handled()
			comprar.emit(String(_ids[i]))


## La zona por donde un bloque empujable recibe hechizos (los hechizos solo golpean AREAS,
## no cuerpos). Reenvia el golpe al bloque; el de tierra los deja pasar, el de hielo se
## detiene solo si es calor (y se derrite).
class ZonaGolpe extends Area2D:
	var dueno: Node = null

	func on_spell_hit(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
		if dueno != null:
			dueno.call("golpeado", rune_data)

	func spell_passes_through() -> bool:
		return dueno == null or not bool(dueno.call("detiene_hechizo"))


## Un bloque que se EMPUJA: de tierra (se mueve de casilla en casilla) o de hielo (resbala
## hasta chocar con algo). Se empuja andando contra el, en cualquiera de las cuatro
## direcciones de la cuadricula. Pesa: pulsa las losas igual que el jugador (ver
## Disparador). El nivel decide si una casilla esta libre (`libre`) y donde cae en pantalla
## (`a_pantalla`), asi que el bloque no sabe nada del mapa.
class Empujable extends AnimatableBody2D:
	var tipo: String = "tierra"
	var textura: Texture2D = null
	var ancla: Vector2 = Vector2.ZERO
	var celda: Vector2i = Vector2i.ZERO
	var libre: Callable
	var a_pantalla: Callable
	var _sensor: Area2D
	var _carga: float = 0.0
	var _mueve: bool = false
	var _forma: CollisionShape2D
	var _dibujo: Sprite2D
	var _derritiendo: bool = false
	var _t_fuego: float = 0.0

	const STEAM_RUNE: RuneData = preload("res://steam_rune.tres")
	const RADIO_FUEGO: float = 75.0     ## una llama (fogata, brasero, objeto ardiendo) tan cerca lo derrite
	const AGARRE: float = 0.18          ## segundos empujando antes de que ceda
	const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	func _ready() -> void:
		add_to_group("empujable")
		_forma = CollisionShape2D.new()
		_forma.shape = IsoGrid.footprint(0.85)
		add_child(_forma)

		_dibujo = Sprite2D.new()
		_dibujo.texture = textura
		_dibujo.centered = false
		_dibujo.scale = Vector2(0.5, 0.5)
		_dibujo.offset = -ancla
		add_child(_dibujo)

		# Para recibir hechizos (calor derrite el hielo).
		var golpe := ZonaGolpe.new()
		golpe.dueno = self
		var zg := CollisionShape2D.new()
		zg.shape = IsoGrid.footprint(0.85)
		golpe.add_child(zg)
		add_child(golpe)

		# Un anillo algo mayor que el bloque: avisa de que el jugador esta pegado a el.
		_sensor = Area2D.new()
		var zona := CollisionShape2D.new()
		zona.shape = IsoGrid.footprint(1.35)
		_sensor.add_child(zona)
		add_child(_sensor)

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in range(25):
			var a: float = TAU * float(i) / 24.0
			pts.append(Vector2(cos(a) * 44.0, sin(a) * 19.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.22))

	## Direccion de pantalla de un paso en la cuadricula (x+1 = abajo-derecha, y+1 = abajo-izquierda).
	func _eje(d: Vector2i) -> Vector2:
		return Vector2(float(d.x - d.y) * IsoGrid.STEP.x, float(d.x + d.y) * IsoGrid.STEP.y).normalized()

	func detiene_hechizo() -> bool:
		return tipo == "hielo" and not _derritiendo

	## Un hechizo de CALOR derrite el hielo; la tierra no reacciona a nada.
	func golpeado(rune_data: RuneData) -> void:
		if tipo == "hielo" and rune_data != null and rune_data.tags.has("calor"):
			derretir()

	## El hielo se deshace en vapor y desaparece, dejando la casilla libre.
	func derretir() -> void:
		if _derritiendo:
			return
		_derritiendo = true
		_mueve = true
		_forma.set_deferred("disabled", true)
		SpellFactory.cast(self, global_position, Vector2.ZERO, STEAM_RUNE, 2.0)
		PlayLog.event("hielo_derretido")
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_dibujo, "modulate", Color(0.8, 0.95, 1.0, 0.0), 1.0)
		tw.tween_property(_dibujo, "scale:y", 0.25, 1.0)
		tw.chain().tween_callback(queue_free)

	## Llama cerca (fogata encendida, objeto ardiendo): lo mira cada medio segundo.
	func _hay_fuego_cerca() -> bool:
		for g in ["flammable", "ground"]:
			for n in get_tree().get_nodes_in_group(g):
				var nd := n as Node2D
				if nd == null or nd == self:
					continue
				if nd.get("is_lit") == true and nd.global_position.distance_to(global_position) < RADIO_FUEGO:
					return true
		return false

	func _physics_process(delta: float) -> void:
		if _derritiendo:
			return
		if tipo == "hielo":
			_t_fuego += delta
			if _t_fuego >= 0.5:
				_t_fuego = 0.0
				if _hay_fuego_cerca():
					derretir()
					return
		if _mueve:
			return
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p == null or bool(p.get("is_dead")) or not _sensor.overlaps_body(p):
			_carga = 0.0
			return
		# Las mismas teclas que mueven al jugador.
		var tecla := Vector2.ZERO
		if Input.is_key_pressed(KEY_A):
			tecla.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			tecla.x += 1.0
		if Input.is_key_pressed(KEY_W):
			tecla.y -= 1.0
		if Input.is_key_pressed(KEY_S):
			tecla.y += 1.0
		if tecla == Vector2.ZERO:
			_carga = 0.0
			return
		tecla = tecla.normalized()
		var hacia: Vector2 = (global_position - p.global_position).normalized()
		# Solo empuja quien camina HACIA el bloque.
		if tecla.dot(hacia) < 0.5:
			_carga = 0.0
			return
		_carga += delta
		if _carga < AGARRE:
			return
		var mejor: Vector2i = Vector2i.ZERO
		var puntos: float = -99.0
		for d in DIRS:
			var eje: Vector2 = _eje(d)
			var s: float = eje.dot(tecla) + eje.dot(hacia)
			if eje.dot(hacia) > 0.2 and s > puntos:
				puntos = s
				mejor = d
		_carga = 0.0
		if mejor != Vector2i.ZERO:
			_empujar(mejor)

	func _empujar(d: Vector2i) -> void:
		if not bool(libre.call(celda + d, self)):
			return
		_mueve = true
		if tipo == "tierra":
			BlockFx.burst(self, "ceniza")
		else:
			Sfx.play(self, "congelar")
		while bool(libre.call(celda + d, self)):
			celda += d
			var meta: Vector2 = a_pantalla.call(celda)
			var tw := create_tween()
			tw.tween_property(self, "position", meta, 0.30 if tipo == "tierra" else 0.15)
			await tw.finished
			if tipo == "tierra":
				break
		_mueve = false


## El interruptor eléctrico: se activa con corriente (un rayo directo o la que
## le llega por el agua) y se queda activado. Forma parte del circuito igual que las
## placas conductoras y las puertas.
class Interruptor extends Area2D:
	signal activado

	## Que lo enciende: "rayo" (corriente), "fuego" (calor) o "agua".
	var elemento: String = "rayo"
	var activo: bool = false
	var visual: Sprite2D = null
	var tex_activo: Texture2D = null
	## Donde esta la runa, respecto al pie del totem, y de que color son sus particulas.
	var pos_runa: Vector2 = Vector2(0.0, -40.0)
	var color_runa: Color = Color(0.6, 0.9, 1.0)
	var luz: Color = Color(0.98, 0.92, 0.55)

	func _ready() -> void:
		if elemento == "rayo":
			add_to_group(Circuit.GROUP)
		var forma := CollisionShape2D.new()
		forma.shape = IsoGrid.footprint(0.8)
		add_child(forma)

	func _le_toca(rune_data: RuneData) -> bool:
		match elemento:
			"fuego":
				return rune_data.tags.has("calor")
			"agua":
				return rune_data.tags.has("agua")
			_:
				return Circuit.is_current(rune_data)

	func on_spell_hit(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
		if activo or rune_data == null or not _le_toca(rune_data):
			return
		activo = true
		if visual != null:
			if tex_activo != null:
				visual.texture = tex_activo
			else:
				visual.modulate = Color(1.5, 1.45, 0.7)
		BlockFx.burst(self, "chispas_azules" if elemento == "rayo" else ("chispas" if elemento == "fuego" else "magia"))
		Sfx.play(self, "chispa")
		Glow.flash(self, luz, 150.0, 1.6, 0.8)
		_particulas_runa()
		if elemento == "rayo":
			# Encendido para siempre: chispas electricas continuas por el suelo.
			ElectricSparks.en(self).activar(1000000.0)
		print("¡El totem de %s se activa!" % elemento)
		activado.emit()

	## Particulas sutiles que se quedan saliendo de la runa mientras el totem esta activo.
	func _particulas_runa() -> void:
		var p := CPUParticles2D.new()
		p.position = pos_runa
		p.z_index = 3
		p.texture = _punto()
		p.amount = 7
		p.lifetime = 1.5
		p.local_coords = false
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 9.0
		p.direction = Vector2(0.0, -1.0)
		p.spread = 50.0
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 11.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.1
		match elemento:
			"fuego":
				p.gravity = Vector2(0.0, -14.0)      # ascuas que suben
			"agua":
				p.gravity = Vector2(0.0, 12.0)       # gotitas que caen despacio
				p.direction = Vector2(0.0, 1.0)
			_:
				p.gravity = Vector2.ZERO             # chispas que vibran
				p.spread = 180.0
				p.lifetime = 0.7
				p.amount = 9
		var rampa := Gradient.new()
		rampa.set_color(0, Color(color_runa, 0.9))
		rampa.set_color(1, Color(color_runa, 0.0))
		p.color_ramp = rampa
		add_child(p)

	static func _punto() -> GradientTexture2D:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 8
		t.height = 8
		return t


## Una puerta que no abre ningún hechizo: pregunta a `condicion` cada fotograma y,
## cuando es cierta, se abre para siempre. Cerrada es un muro de piedra de dos bloques;
## abierta, el suelo.
class PuertaFinal extends Door:
	var condicion: Callable = Callable()
	var tex_cerrada: Texture2D = null
	var tex_abierta: Texture2D = null
	var escala: Vector2 = Vector2.ONE
	var desplaza: Vector2 = Vector2.ZERO
	var altura_bloque: float = 33.0
	var _segundo: Sprite2D = null

	func _ready() -> void:
		super()
		visual.modulate = Color(1.15, 1.0, 0.7)

	func on_spell_hit(_rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
		pass

	func _process(_delta: float) -> void:
		if is_open or not condicion.is_valid():
			return
		if condicion.call():
			is_open = true
			_apply()
			BlockFx.burst(self, "chispas")
			Sfx.play(self, "puerta_abre")
			print("La puerta final se abre.")

	func _apply() -> void:
		if visual == null:
			return
		visual.texture = tex_abierta if is_open else tex_cerrada
		visual.scale = escala
		visual.offset = desplaza
		if _segundo == null:
			_segundo = Sprite2D.new()
			_segundo.scale = escala
			_segundo.offset = desplaza
			_segundo.position = Vector2(0.0, -altura_bloque)
			_segundo.modulate = Color(1.15, 1.0, 0.7)
			add_child(_segundo)
		_segundo.texture = tex_cerrada
		_segundo.visible = not is_open

		if solido:
			solido.queue_free()
			solido = null
		if is_open:
			return
		solido = StaticBody2D.new()
		var forma := CollisionShape2D.new()
		forma.shape = IsoGrid.footprint(0.95)
		solido.add_child(forma)
		add_child(solido)


## Las 4 llamas de la puerta final, una por tarea. Una llama apagada es solo un
## contorno; encendida (tarea hecha), parpadea.
class Llamas extends Node2D:
	var encendidas: Array = []   # 4 booleanos, una por tarea

	func _ready() -> void:
		z_index = 20
		for i in range(4):
			encendidas.append(false)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t: float = Time.get_ticks_msec() / 1000.0
		for i in range(4):
			var c := Vector2((float(i) - 1.5) * 44.0, 0.0)
			_flama(c, bool(encendidas[i]), t, float(i) * 1.7)

	func _flama(c: Vector2, viva: bool, t: float, fase: float) -> void:
		var s: float = 1.0 + 0.14 * sin(t * 9.0 + fase) if viva else 1.0
		var cuerpo := PackedVector2Array([
			c + Vector2(0, -15.0 * s), c + Vector2(7, -3), c + Vector2(6, 5),
			c + Vector2(0, 9), c + Vector2(-6, 5), c + Vector2(-7, -3)])
		if viva:
			draw_circle(c, 17.0, Color(1.0, 0.6, 0.2, 0.14))
			draw_colored_polygon(cuerpo, Color(1.0, 0.45, 0.10, 0.95))
			var dentro := PackedVector2Array()
			for p in cuerpo:
				dentro.append(c + (p - c) * 0.55 + Vector2(0, 2))
			draw_colored_polygon(dentro, Color(1.0, 0.88, 0.35, 0.95))
		else:
			var cerrado: PackedVector2Array = cuerpo.duplicate()
			cerrado.append(cuerpo[0])
			draw_colored_polygon(cuerpo, Color(0.08, 0.08, 0.12, 0.55))
			draw_polyline(cerrado, Color(0.62, 0.62, 0.70, 0.9), 1.6, true)


## Un NPC: el sprite del pipeline, un cuerpo pequeño para no poder atravesarlo y el
## texto de lo que dice.
class Npc extends Node2D:
	var id: String = ""
	var nombre: String = ""
	var lineas: Array = []
	var actor: MsActor = null

	func hablar(si: bool) -> void:
		if actor != null:
			actor.jugar("talk_with_left_hand_raised" if si else "idle")


## El cuadro de texto básico de los NPC. Usa de placeholder un panel del pack Kenney de
## bordes de fantasía (Assets/kenney_fantasy-ui-borders), teñido de azul oscuro.
class Dialogo extends CanvasLayer:
	signal cerrado

	var abierto: bool = false
	var _panel: PanelContainer = null
	var _nombre: Label = null
	var _texto: Label = null
	var _pista: Label = null
	var _lineas: Array = []
	var _i: int = 0
	var _chars: float = 0.0
	var panel_textura: Texture2D = null

	func _ready() -> void:
		layer = 30
		process_mode = Node.PROCESS_MODE_ALWAYS
		visible = false

		_panel = PanelContainer.new()
		if panel_textura != null:
			var estilo := StyleBoxTexture.new()
			estilo.texture = panel_textura
			estilo.texture_margin_left = 18.0
			estilo.texture_margin_right = 18.0
			estilo.texture_margin_top = 18.0
			estilo.texture_margin_bottom = 18.0
			estilo.content_margin_left = 30.0
			estilo.content_margin_right = 30.0
			estilo.content_margin_top = 22.0
			estilo.content_margin_bottom = 20.0
			estilo.modulate_color = Color(0.10, 0.13, 0.26, 0.96)
			_panel.add_theme_stylebox_override("panel", estilo)
		add_child(_panel)
		_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_panel.offset_left = 140.0
		_panel.offset_right = -140.0
		_panel.offset_top = -200.0
		_panel.offset_bottom = -30.0

		var caja := VBoxContainer.new()
		caja.add_theme_constant_override("separation", 8)
		_panel.add_child(caja)

		_nombre = Label.new()
		_nombre.add_theme_font_size_override("font_size", 20)
		_nombre.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
		caja.add_child(_nombre)

		_texto = Label.new()
		_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_texto.add_theme_font_size_override("font_size", 19)
		caja.add_child(_texto)

		_pista = Label.new()
		_pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_pista.add_theme_font_size_override("font_size", 14)
		_pista.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0, 0.8))
		caja.add_child(_pista)

	func abrir(quien: String, lineas: Array) -> void:
		_lineas = lineas
		_i = 0
		_nombre.text = quien
		abierto = true
		visible = true
		get_tree().paused = true
		_mostrar()

	func _mostrar() -> void:
		_texto.text = String(_lineas[_i])
		_texto.visible_characters = 0
		_chars = 0.0
		_pista.text = "[E] continuar" if _i < _lineas.size() - 1 else "[E] cerrar"

	func _process(delta: float) -> void:
		if not abierto:
			return
		_chars += delta * 55.0
		_texto.visible_characters = int(_chars)

	func _input(event: InputEvent) -> void:
		if not abierto:
			return
		var avanza: bool = false
		var k := event as InputEventKey
		if k != null and k.pressed and not k.echo and \
				(k.keycode == KEY_E or k.keycode == KEY_ENTER or k.keycode == KEY_SPACE):
			avanza = true
		var m := event as InputEventMouseButton
		if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
			avanza = true
		if not avanza:
			return
		get_viewport().set_input_as_handled()
		if int(_chars) < _texto.text.length():
			_chars = float(_texto.text.length())
			_texto.visible_characters = -1
			return
		_i += 1
		if _i >= _lineas.size():
			abierto = false
			visible = false
			get_tree().paused = false
			cerrado.emit()
		else:
			_mostrar()


static var _texturas: Dictionary = {}

var player: CharacterBody2D = null
var _inicio: Vector2i = Vector2i(1, 1)
var _hud: Label = null
var _aviso: Label = null
var _pista_e: Label = null
var _tween: Tween = null
var _dialogo: Dialogo = null

var _npcs: Array = []
var _arboles: Array = []      ## [nodo, sprite] de cada árbol, para el fundido
var _goblins: Array = []
var _antorchas: Array = []
var _fuegos_fijos: Array = []   ## fuentes de fuego que no se apagan
var _baldosa_pisada: bool = false
var _npc_hablado: bool = false
var _puerta_final: PuertaFinal = null
var _llamas: Llamas = null
var _tareas_hechas: Dictionary = {}
var _final_avisada: bool = false

var _agua_puente: Node2D = null
var _celda_puente: Vector2i = Vector2i.ZERO
var _puente_hecho: bool = false


## --- Estado de los sistemas nuevos ---
const GOBLIN_GUERRERO: Script = preload("res://goblin_guerrero.gd")
const GOBLIN_ARQUERO: Script = preload("res://goblin_arquero.gd")
const GOBLIN_ESCARCHA: Script = preload("res://goblin_escarcha.gd")

const PLANTA_LETRA: Dictionary = {"s": "seta", "f": "flor", "q": "raiz"}
const LIMITE_HUECOS: int = 8

## Decorado del bosque que SÍ tiene sentido recoger: prop -> [objeto, cantidad].
## Una caja, un barril o un cartel NO (no tienen lógica); una planta o una piedra sí.
const RECOGIBLES_PROP: Dictionary = {
	"lavender": ["lavanda", 1],
	"bush_berry": ["baya", 2],
	"fern": ["helecho", 1],
	"flowers": ["flor_silvestre", 1],
	"rocks": ["piedra", 1],
}

## Los tenderos. [id del Npc, modelo del pipeline, nombre, tinte, líneas]
const TENDEROS: Dictionary = {
	"librera": ["bookseller_woman", "bookseller_woman", "Librera", Color.WHITE, []],
	"alquimista": ["alquimista", "ranger_human", "Alquimista", Color(0.78, 0.62, 1.15), [
		"Si me traes ingredientes y oro, mejoraré tu equipo.",
		"Haz reaccionar las plantas con los elementos: una seta con un rayo, una flor con fuego...",
		"Con eso se hacen elixires para tener más vida, más sitio en la mochila o más rapidez."]],
}

var bolsa: BolsaUI = null
var misiones: Misiones = null
var pantalla_muerte: PantallaMuerte = null
var _tienda_lib: Tienda = null
var _tienda_alq: Tienda = null
var _rangers: Dictionary = {}          ## celda -> Npc
var _fogata_encargo: Area2D = null
var _lib_visitas: int = 0
var _puestos_mapa: Array = []          ## [rol, celda] de las letras n y Q del plano
var _puestos_nodos: Dictionary = {}    ## rol -> nodo del puesto
var _tenderos: Dictionary = {}         ## rol -> Npc
var _placa_peso: Disparador = null     ## la de la letra K (si hay)


## Placa que solo cuenta el PESO de un bloque (de tierra creado con el sello, o empujable).
class PlacaPeso extends Disparador:
	func _on_body_entered(_body: Node) -> void:
		pass     # el jugador no pesa bastante

	func _process(_delta: float) -> void:
		queue_redraw()
		if usado:
			return
		for b in get_overlapping_bodies():
			if b.is_in_group("empujable"):
				_activar()
				return
		for a in get_overlapping_areas():
			if a.is_in_group("earth_blocks"):
				_activar()
				return


## --- Texturas ---
##
## Se cargan leyendo el PNG directamente, igual que la escena demo del pipeline: no
## depende de que Godot haya importado el archivo.
static func _tex_ruta(ruta: String) -> Texture2D:
	if _texturas.has(ruta):
		return _texturas[ruta]
	var t: Texture2D = null
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(ruta))
	if img != null and not img.is_empty():
		t = ImageTexture.create_from_image(img)
	else:
		push_warning("TestJugabilidad: no encuentro la imagen %s" % ruta)
	_texturas[ruta] = t
	return t


static func _img_ruta(ruta: String) -> Image:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(ruta))
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _bloque(nombre: String) -> Texture2D:
	return _tex_ruta(RAIZ_BOSQUE + "blocks/" + nombre + ".png")


## Hierba con algo ENCIMA: el bloque de hierba más uno o varios sprites apoyados en el
## centro de su cara de arriba. El lienzo crece por arriba (`relleno`) para que quepa
## lo alto. Las dos versiones (decorada y tupida) usan el MISMO tamaño de lienzo, así
## el bloque de hierba cambia de una a otra sin descuadrarse.
static func _hierba_con(extras: Array, relleno: int) -> Texture2D:
	var base: Image = _img_ruta(RAIZ_BOSQUE + "blocks/grass.png")
	if base == null:
		return null
	var lienzo := Image.create_empty(base.get_width(), base.get_height() + relleno, false, Image.FORMAT_RGBA8)
	lienzo.blend_rect(base, Rect2i(0, 0, base.get_width(), base.get_height()), Vector2i(0, relleno))
	var centro := Vector2i(int(base.get_width() * 0.5), relleno + int(CARA_Y))
	for e in extras:
		var im: Image = _img_ruta(RAIZ_BOSQUE + String(e[0]))
		if im == null:
			continue
		var dx: int = int(e[1])
		var dy: int = int(e[2])
		var destino := Vector2i(centro.x + dx - int(im.get_width() * 0.5), centro.y + dy - im.get_height())
		lienzo.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), destino)
	return ImageTexture.create_from_image(lienzo)


const RELLENO_HIERBA: int = 70


## --- Repertorio ---

func _repertorio_inicial() -> void:
	Repertoire.aim_with_mouse = APUNTAR_CON_RATON
	Repertoire.max_sigils_per_page = HUECOS_INICIO
	Repertoire.set_active(SELLOS_INICIO, GLIFOS_INICIO)


## --- Lo que da cada nivel (valores por defecto) ---

## El plano del nivel. Cada nivel devuelve el suyo.
func _mapa() -> PackedStringArray:
	return PackedStringArray()


## Decorado del bosque: [prop, columna, fila]. Los props con cuerpo (caja, barril, peñasco,
## tocón, tronco, cartel) bloquean el paso; el resto es decorado (y algunos se recogen).
func _lista_props() -> Array:
	return []


## Setos secos sueltos (además de los de la letra z del plano).
func _lista_setos() -> Array:
	return []


## El botín del suelo: [objeto, columna, fila, cantidad].
func _suelo_objetos() -> Array:
	return []


## Las baldosas de guardado.
func _celdas_guardado() -> Array:
	return []


## Bloques empujables: [tipo ("tierra" o "hielo"), columna, fila].
func _lista_empujables() -> Array:
	return []


## Los puestos: [[rol, celda], ...]. Por defecto, los de las letras n y Q del plano.
func _puestos() -> Array:
	return _puestos_mapa


## Los encargos de los guardabosques (letra M). Por defecto ninguno.
func _definir_encargos() -> void:
	pass


## Cualquier cosa extra que un nivel quiera montar al final de _ready().
func _extras_nivel() -> void:
	pass


func _ready() -> void:
	y_sort_enabled = true
	add_to_group("checkpoint_nivel")
	SpellFactory.agua_apaga_muros = false

	Estado.nuevo()
	PlayLog.nueva_partida()
	_repertorio_inicial()
	_construir_mapa()
	_colocar_props()
	_colocar_setos()
	_colocar_recogibles()
	_colocar_guardados()
	_colocar_puesto()
	_colocar_empujables()
	_crear_jugador()
	_crear_interfaz()
	_colocar_camara()
	_extras_base()
	_extras_nivel()
	_refrescar_hud()


## --- Letras del plano que no están en _construir_mapa ---
## Un nivel con letras propias sobrescribe esta función, coloca las suyas y para el resto
## llama a super(cell, letra).
## --- El plano: letras nuevas ---

func _letra_extra(cell: Vector2i, letra: String) -> bool:
	match letra:
		"Q":
			_suelo(cell, "pathgrass", true)
			_puestos_mapa.append(["alquimista", cell])
		"M":
			_suelo(cell, "pathgrass", true)
			_rangers[cell] = _npc_mundo(cell, "ranger_human", "guardabosques", "Guardabosques", "SE", [], Color.WHITE)
		"D":
			_suelo(cell, _tipo_suelo(cell.x, cell.y), true)
			_dummy(cell)
		"s", "f", "q":
			_suelo(cell, _tipo_suelo(cell.x, cell.y), true)
			var r := Reagente.new()
			r.planta = PLANTA_LETRA[letra]
			r.y_sort_enabled = true
			_colocar(r, cell)
		"O":
			_suelo(cell, "dirt", true)
			_fogata_encargo = _fogata(cell, true)
		"K":
			_suelo(cell, "stone", true)
			var p := PlacaPeso.new()
			p.color = Color(0.8, 0.62, 0.35)
			p.rotulo = "PESO"
			_colocar(p, cell)
			_placa_peso = p
		_:
			return false
	return true


## Se llama al crear cada prop del decorado: el que tiene sentido recoger se vuelve recogible.

func _prop_creado(nombre: String, _cell: Vector2i, nodo: Node2D, sprite: Sprite2D) -> void:
	if not RECOGIBLES_PROP.has(nombre):
		return
	var d: Array = RECOGIBLES_PROP[nombre]
	var r := Recolectable.new()
	r.id = String(d[0])
	r.cantidad = int(d[1])
	r.sprite = sprite
	nodo.add_child(r)

func _letra(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= _mapa().size():
		return ""
	var linea: String = _mapa()[cell.y]
	if cell.x < 0 or cell.x >= linea.length():
		return ""
	return linea[cell.x]


func _at(cell: Vector2i) -> Vector2:
	return ORIGEN + IsoGrid.to_screen(cell)


func _hash(x: int, y: int, sal: int = 0) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (sal * 83492791))


func _construir_mapa() -> void:
	var tupida: Texture2D = _hierba_con([["grass/hierba_sano_0.png", 0, 22]], RELLENO_HIERBA)
	var decorada: Texture2D = _hierba_con([
		["clumps/mata_fern_flowers_sano.png", -22, 14],
		["props/fern.png", 24, 18],
		["props/flowers.png", 0, 24],
	], RELLENO_HIERBA)

	for y in range(_mapa().size()):
		var linea: String = _mapa()[y]
		for x in range(linea.length()):
			var cell := Vector2i(x, y)
			var letra: String = linea[x]
			match letra:
				"#":
					_suelo(cell, _tipo_suelo(x, y), false)
					_arbol(cell)
				"~":
					_agua(cell)
				"b":
					_celda_puente = cell
					_agua_puente = _agua(cell)
					_poner_puente(cell)
				"v":
					_hierba(cell, decorada, tupida, 0)
				"G":
					_hierba(cell, decorada, tupida, 1)
				"g":
					_suelo(cell, "dirt", true)
				"p":
					_suelo(cell, "stone", true)
					_baldosa(cell)
				"a":
					_suelo(cell, "moss_stone", true)
					_losa(cell, "agua_barrera", Color(0.45, 0.85, 1.0), "AGUA")
				"w":
					_suelo(cell, "moss_stone", true)
					_losa(cell, "viento_hueco", Color(0.80, 0.60, 1.0), "VIENTO")
				"i":
					_suelo(cell, _tipo_suelo(x, y), true)
					_interruptor(cell)
				"j":
					_suelo(cell, _tipo_suelo(x, y), true)
					_interruptor(cell, "fuego")
				"k":
					_suelo(cell, _tipo_suelo(x, y), true)
					_interruptor(cell, "agua")
				"z", "l", "h", "r":
					_suelo(cell, _tipo_suelo(x, y), true)
					_combustible(cell, OBJETO_LETRA[letra])
				"n":
					# La librera atiende en su PUESTO (el puesto ocupa esta casilla y la de su derecha).
					_suelo(cell, "pathgrass", true)
					_puestos_mapa.append(["librera", cell])
				"m":
					_suelo(cell, "pathgrass", true)
					_npc(cell, "ranger_human", "SW")
				"B":
					_suelo(cell, _tipo_suelo(x, y), true)
					_fuente_fuego(cell, true)
				"F":
					_suelo(cell, "dirt", true)
					_fuente_fuego(cell, false)
				"T":
					_suelo(cell, "dirt", true)
					_antorcha(cell)
				"A":
					_suelo(cell, _tipo_suelo(x, y), true)
					_arquero(cell)
				"W":
					_suelo(cell, _tipo_suelo(x, y), true)
					_guerrero(cell)
				"X":
					_suelo(cell, "path", true)
					_puerta(cell)
				"E":
					_suelo(cell, "path", true)
					_salida(cell)
				"S":
					_inicio = cell
					_suelo(cell, "pathgrass", true)
				_:
					if not _letra_extra(cell, letra):
						_suelo(cell, _tipo_suelo(x, y), true)


func _tipo_suelo(x: int, y: int) -> String:
	var h: int = _hash(x, y) % 13
	if h <= 1:
		return "forest_grass"
	if h == 2:
		return "moss"
	return "grass"


## Añade una pieza a una casilla. `encajar` cambia sus formas de colisión al rombo de
## la casilla (las piezas venían dimensionadas para otro tamaño).
func _colocar(nodo: Node2D, cell: Vector2i, encajar: bool = false) -> Node2D:
	add_child(nodo)
	nodo.position = _at(cell)
	if encajar:
		for c in [nodo.get_node_or_null("CollisionShape2D"),
				nodo.get_node_or_null("SolidBody/CollisionShape2D")]:
			if c:
				c.shape = IsoGrid.diamond()
				c.position = Vector2.ZERO
	return nodo


## Pone el dibujo de un bloque del pack en el nodo `Visual` de una pieza.
func _dibujar_bloque(nodo: Node2D, tex: Texture2D, cara_y: float = CARA_Y) -> void:
	var v: Sprite2D = nodo.get_node("Visual")
	v.texture = tex
	v.scale = Vector2(SX, SY)
	v.offset = Vector2(0.0, tex.get_height() * 0.5 - cara_y)


## El suelo llano: un NeutralBlock (se moja, se hiela, deja andar). `con_cuerpo` false =
## solo dibujo (el suelo bajo un árbol, que no hace falta que reaccione a nada).
func _suelo(cell: Vector2i, tipo: String, con_cuerpo: bool = true) -> void:
	var tex: Texture2D = _bloque(tipo)
	if not con_cuerpo:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(SX, SY)
		s.offset = Vector2(0.0, tex.get_height() * 0.5 - CARA_Y)
		s.z_index = -1
		add_child(s)
		s.position = _at(cell)
		return
	var bloque: Node2D = NEUTRAL_SCENE.instantiate()
	_dibujar_bloque(bloque, tex)
	bloque.z_index = -1
	_colocar(bloque, cell, true)


func _agua(cell: Vector2i) -> Node2D:
	var agua: Node2D = WATER_SCENE.instantiate()
	# Los tres hielos (nevado -> escarcha -> claro): al congelarse se ve el primero y se va
	# "descongelando" hasta el ultimo, que se queda. El hielo es firme (no vuelve a ser agua).
	agua.set("hielo_permanente", true)
	agua.set("hielo", [
		_bloque("water_frozen_1_nevado"),
		_bloque("water_frozen_2_escarcha"),
		_bloque("water_frozen_3_claro")])
	_dibujar_bloque(agua, _bloque("water"))
	agua.z_index = -1
	_colocar(agua, cell, true)
	return agua


## `tupida` 1 = hierba que cierra el paso (se quema); 0 = hierba transitable (enredadera).
func _hierba(cell: Vector2i, decorada: Texture2D, tupida: Texture2D, estado: int) -> void:
	var g: Node2D = GRASS_SCENE.instantiate()
	g.set("tex_thin", decorada)
	g.set("tex_grown", tupida)
	g.set("initial_state", estado)
	var tex: Texture2D = decorada if decorada != null else _bloque("grass")
	_dibujar_bloque(g, tex, CARA_Y + float(RELLENO_HIERBA))
	# Al mismo nivel que el suelo: si no, sus costados se pintan POR ENCIMA de las
	# casillas de delante y parece un escalón.
	g.z_index = -1
	_colocar(g, cell, true)


func _arbol(cell: Vector2i) -> void:
	var tipo: String = ARBOLES[_hash(cell.x, cell.y, 3) % ARBOLES.size()]
	var angulo: int = _hash(cell.x, cell.y, 5) % 5
	var tex: Texture2D = _tex_ruta("%strees/tree_%s_%d.png" % [RAIZ_BOSQUE, tipo, angulo])

	var nodo := Node2D.new()
	nodo.y_sort_enabled = true
	add_child(nodo)
	nodo.position = _at(cell)

	var s := Sprite2D.new()
	s.texture = tex
	var k: float = ESCALA_ARBOL * SX
	s.scale = Vector2(k, k)
	_arboles.append([nodo, s])
	# La base del tronco en el centro de la casilla, un poco por debajo.
	var alto: float = tex.get_height() if tex != null else 100.0
	s.offset = Vector2(0.0, -alto * 0.5 + 8.0)
	nodo.add_child(s)

	var cuerpo := StaticBody2D.new()
	var forma := CollisionShape2D.new()
	forma.shape = IsoGrid.footprint(0.93)
	cuerpo.add_child(forma)
	nodo.add_child(cuerpo)
## El oro vive en el Estado (compartido con la mochila y el resto de sistemas).
var _oro: int:
	get:
		return Estado.i().oro
	set(v):
		Estado.i().oro = v
		Estado.i().cambiado.emit()


## --- Puntos de guardado ---
const GUARDADO_ART: String = "res://art/baldosa.png"
const GUARDADO_RUNA: String = "res://art/baldosa_runa.png"
const ANCLA_GUARDADO: Vector2 = Vector2(113.0, 74.5)
var _puntos: Array = []
var _guardado_activo: Node2D = null


func _colocar_guardados() -> void:
	for c in _celdas_guardado():
		var g := Punto_guardado.new()
		g.tex_base = _tex_ruta(GUARDADO_ART)
		g.tex_runa = _tex_ruta(GUARDADO_RUNA)
		g.ancla = ANCLA_GUARDADO
		g.activado.connect(_on_guardado.bind(g))
		_colocar(g, c as Vector2i)
		_puntos.append(g)


func _on_guardado(g: Punto_guardado) -> void:
	for o in _puntos:
		if o != g:
			(o as Punto_guardado).apagar()
	_guardado_activo = g
	_avisar("Punto de guardado")
	PlayLog.event("guardado")


## Lo llama player.gd al morir. Con un punto activo, el jugador reaparece alli con la vida
## completa y un instante de invulnerabilidad en vez de acabar la partida.
func reaparecer(jugador: Node2D) -> bool:
	if _guardado_activo == null or not is_instance_valid(_guardado_activo):
		return false
	var tope: float = float(jugador.get("max_health"))
	jugador.set("health", tope)
	jugador.set("velocity", Vector2.ZERO)
	jugador.set("_invuln", 1.5)
	jugador.global_position = _guardado_activo.global_position
	jugador.emit_signal("health_changed", tope, tope)
	BlockFx.burst(jugador, "magia")
	_avisar("Vuelves al punto de guardado")
	PlayLog.event("reaparece")
	return true


## --- Los puestos de venta ---
## Mostrador de madera (art/puesto.png, a 2x -> escala 0.5) de 2x1 casillas: ocupa su celda y la
## de su derecha (x+1); el dibujo se ancla en el centro de su base. Es el PLACEHOLDER de toda
## tienda: el tendero se pone AL NORTE del puesto (ver _poner_puesto). Se abre con E, hablando
## con el tendero o estando junto al mostrador.
const PUESTO_ART: String = "res://art/puesto.png"
const ANCLA_PUESTO: Vector2 = Vector2(175.0, 175.0)
const DISTANCIA_PUESTO: float = 150.0


## --- Bloques empujables ---
## Tierra: avanza una casilla por empujon. Hielo: resbala hasta que algo lo frena. Pesan, asi
## que pulsan las losas. Solo andan por suelo normal: los arboles y muros, el agua (tambien
## helada), el puente y cualquier cosa solida les hacen tope. El hielo ademas se derrite
## con calor (un hechizo, o una llama cerca).
const EMPUJABLE_ART: String = "res://art/empujable_%s.png"
const ANCLA_EMPUJABLE: Dictionary = {"tierra": Vector2(100.0, 156.0), "hielo": Vector2(100.0, 157.0)}
const LETRAS_LIBRES_BLOQUE: String = ".Svgpaw"


func _colocar_empujables() -> void:
	for e in _lista_empujables():
		var b := Empujable.new()
		b.tipo = e[0]
		b.textura = _tex_ruta(EMPUJABLE_ART % String(e[0]))
		b.ancla = ANCLA_EMPUJABLE[e[0]]
		b.celda = Vector2i(int(e[1]), int(e[2]))
		b.libre = Callable(self, "_celda_libre_bloque")
		b.a_pantalla = Callable(self, "_at")
		b.y_sort_enabled = true
		_colocar(b, b.celda)


## Una casilla esta libre para un bloque si es suelo del mapa (no muro ni fuera) y no hay
## ningun cuerpo solido encima: props, puesto, npcs, agua sin helar, otros bloques, el jugador.
func _celda_libre_bloque(cell: Vector2i, quien: Object) -> bool:
	# Terreno: solo suelo normal. Muros y arboles (#), agua (~), puente, puertas, fuentes de
	# fuego... hacen tope. Despues, ademas, cualquier cuerpo solido (props, arboles, npcs).
	var letra: String = _letra(cell)
	if letra == "" or not LETRAS_LIBRES_BLOQUE.contains(letra):
		return false
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = IsoGrid.footprint(0.7)
	q.transform = Transform2D(0.0, _at(cell))
	q.collide_with_areas = false
	q.collide_with_bodies = true
	if quien is CollisionObject2D:
		q.exclude = [(quien as CollisionObject2D).get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _colocar_props() -> void:
	for p in _lista_props():
		var nombre: String = p[0]
		var cell := Vector2i(int(p[1]), int(p[2]))
		# Los troncos y las setas del decorado son los objetos que arden (combustible.gd), y
		# donde va un seto no hace falta matorral decorativo.
		if OBJETO_PROP.has(nombre):
			_combustible(cell, OBJETO_PROP[nombre])
			continue
		if _lista_setos().has(cell):
			continue
		var datos: Array = PROP_DATOS.get(nombre, [1.3, false])
		var archivo: String = "cairn" if nombre == "cairn_deco" else nombre
		var carpeta: String = "props/"
		var tex: Texture2D = _tex_ruta(RAIZ_BOSQUE + carpeta + archivo + ".png")
		if tex == null:
			continue

		var nodo := Node2D.new()
		nodo.y_sort_enabled = true
		add_child(nodo)
		var jx: float = float(_hash(cell.x, cell.y, 7) % 21) - 10.0
		var jy: float = float(_hash(cell.x, cell.y, 9) % 9) - 4.0
		nodo.position = _at(cell) + Vector2(jx, jy)

		var s := Sprite2D.new()
		s.texture = tex
		var k: float = float(datos[0]) * SX
		s.scale = Vector2(k, k)
		s.offset = Vector2(0.0, -tex.get_height() * 0.5 + 4.0)
		nodo.add_child(s)
		_prop_creado(nombre, cell, nodo, s)   # el que tenga sentido se vuelve recogible

		if bool(datos[1]):
			var cuerpo := StaticBody2D.new()
			var forma := CollisionShape2D.new()
			forma.shape = IsoGrid.footprint(0.40)
			cuerpo.add_child(forma)
			nodo.add_child(cuerpo)


## --- Piezas del puzle ---

func _baldosa(cell: Vector2i) -> void:
	var d := Disparador.new()
	d.color = Color(1.0, 0.82, 0.30)
	d.rotulo = ""
	d.pisado.connect(func() -> void:
		_baldosa_pisada = true
		d.modulate = Color(1.2, 1.1, 0.7)
		_avisar("Baldosa de contacto activada")
		PlayLog.event("baldosa"))
	_colocar(d, cell)


func _losa(cell: Vector2i, clave: String, color: Color, rotulo: String) -> void:
	var d := Disparador.new()
	d.color = color
	d.rotulo = rotulo
	d.pisado.connect(func() -> void: _desbloquear(clave))
	_colocar(d, cell)


func _desbloquear(clave: String) -> void:
	match clave:
		"agua_barrera":
			var nuevos: Array = []
			if Repertoire.unlock_element("agua"):
				nuevos.append("Sello AGUA")
			if Repertoire.unlock_sigil("barrera"):
				nuevos.append("Glifo BARRERA")
			if not nuevos.is_empty():
				_avisar("¡Desbloqueado!  " + "  +  ".join(nuevos))
		"viento_hueco":
			var nuevos2: Array = []
			if Repertoire.unlock_element("viento"):
				nuevos2.append("Sello VIENTO")
			if Repertoire.max_sigils_per_page < HUECOS_TRAS_VIENTO:
				Repertoire.max_sigils_per_page = HUECOS_TRAS_VIENTO
				nuevos2.append("2.º hueco de glifos")
			if not nuevos2.is_empty():
				_avisar("¡Desbloqueado!  " + "  +  ".join(nuevos2))
	PlayLog.event("runas", {"clave": clave})
	_refrescar_hud()


func _interruptor(cell: Vector2i, elemento: String = "rayo") -> void:
	var it := Interruptor.new()
	it.elemento = elemento
	var d: Dictionary = TOTEMS[elemento]
	var s := Sprite2D.new()
	s.texture = _tex_ruta("%stotem_%s_off.png" % [BOSQUE_ART, elemento])
	s.centered = false
	s.offset = -(d["ancla"] as Vector2)
	s.scale = Vector2(0.5, 0.5)
	it.tex_activo = _tex_ruta("%stotem_%s_on.png" % [BOSQUE_ART, elemento])
	it.pos_runa = d["runa"]
	it.color_runa = d["color"]
	it.luz = d["luz"]
	it.add_child(s)
	it.visual = s
	if elemento == "rayo":
		it.activado.connect(_on_interruptor)
	else:
		it.activado.connect(_on_totem.bind(elemento))
	it.y_sort_enabled = true
	_colocar(it, cell)


## Los totems de fuego y agua no abren nada por si solos: avisan y cuentan (los puzles que
## los necesiten se enganchan a `_totems_activos` o conectan la senal `activado`).
func _on_totem(elemento: String) -> void:
	_totems_activos[elemento] = true
	_avisar("Totem de %s activado" % elemento)
	PlayLog.event("totem", {"elemento": elemento})


## --- Objetos que arden (combustible.gd) ---
##
## Se colocan con una letra en MAPA:  z seto   l tronco   h setas   r telarana.
## Mientras arden se ve su dibujo CHAMUSCADO y, al acabar el fuego, desaparecen (con su
## cuerpo): el seto, el tronco y la telarana son un muro hasta que se queman.
## Datos: [archivo, estado sano, estado quemado, ancla del dibujo, hueco solido, segundos ardiendo]
const BOSQUE_ART: String = "res://art/bosque/"
const COMBUSTIBLE: Script = preload("res://combustible.gd")
const OBJETO_LETRA: Dictionary = {"z": "seto", "l": "tronco", "h": "setas", "r": "telarana"}
const OBJETOS: Dictionary = {
	"seto": ["seto", "sano", "chamuscado", Vector2(104.3, 161.4), 0.95, 3.5],
	"tronco": ["tronco", "sano", "chamuscado", Vector2(112.0, 114.5), 0.90, 4.0],
	"setas": ["setas", "sano", "chamuscado", Vector2(92.0, 145.2), 0.50, 2.5],
	"telarana": ["telarana", "sana", "quemada", Vector2(122.0, 166.9), 0.95, 1.6],
}

## Totems de runa (art/bosque/totem_<elemento>_off|on.png). `runa` = donde esta el simbolo
## respecto al pie, para las particulas sutiles que salen de el al activarse.
const TOTEMS: Dictionary = {
	"rayo": {"ancla": Vector2(64.0, 188.1), "runa": Vector2(-5.0, -45.6),
		"color": Color(0.65, 0.9, 1.0), "luz": Color(0.98, 0.92, 0.55)},
	"fuego": {"ancla": Vector2(64.0, 189.0), "runa": Vector2(-4.5, -46.2),
		"color": Color(1.0, 0.62, 0.25), "luz": Color(1.0, 0.78, 0.42)},
	"agua": {"ancla": Vector2(64.0, 189.0), "runa": Vector2(-5.0, -45.2),
		"color": Color(0.55, 0.85, 1.0), "luz": Color(0.55, 0.82, 1.0)},
}
var _totems_activos: Dictionary = {}

## Reparto de los objetos que arden por el nivel (comprobado: ninguno corta un camino).
##   - los props "log" y "mushrooms" de PROPS pasan a ser tronco y setas que arden;
##   - los setos sueltos los da cada nivel en _lista_setos();
##   - la telaraña (r en MAPA) cierra el hueco del muro de la izquierda, donde estaba la hierba alta.
const OBJETO_PROP: Dictionary = {"log": "tronco", "mushrooms": "setas"}


func _colocar_setos() -> void:
	for c in _lista_setos():
		_combustible(c as Vector2i, "seto")


func _combustible(cell: Vector2i, tipo: String) -> Area2D:
	var d: Array = OBJETOS[tipo]
	var obj: Area2D = COMBUSTIBLE.new()
	obj.set("tex_sano", _tex_ruta("%s%s_%s.png" % [BOSQUE_ART, d[0], d[1]]))
	obj.set("tex_chamuscado", _tex_ruta("%s%s_%s.png" % [BOSQUE_ART, d[0], d[2]]))
	obj.set("ancla", d[3])
	obj.set("cuerpo_tam", d[4])
	obj.set("tiempo_arder", d[5])
	obj.y_sort_enabled = true
	_colocar(obj, cell)
	return obj


## El puente tiene dos estados. SIN formar: dos hileras de piedras en la union entre la
## hierba y el rio (art/piedras_S.png y piedras_N.png). FORMADO (al llegar el rayo al
## interruptor): el puente completo, placa con borde de piedras (art/puente_completo.png),
## que sustituye a las hileras. Los dibujos estan a 2x, asi que se pintan a escala 0.5.
const PUENTE_ESCALA: float = 0.5
const ANCLA_PIEDRAS_S: Vector2 = Vector2(64.1, 42.1)
const ANCLA_PIEDRAS_N: Vector2 = Vector2(64.8, 43.7)
const ANCLA_COMPLETO: Vector2 = Vector2(119.5, 75.2)
const ESCALA_COMPLETO: float = 0.5      # el dibujo esta a 0.32 -> 0.16 en juego; sube/baja aqui si hace falta
var _piedras_puente: Array[Node2D] = []


## Una pieza anclada en su centro de dibujo. `clave` desplaza solo el ORDEN de pintado
## (el nodo se mueve `clave` y el dibujo lo contrario), para ordenarse en Y respecto al
## jugador por el sitio donde de verdad esta.
func _pieza_puente(ruta: String, ancla: Vector2, pos: Vector2, clave: Vector2, escala: float = PUENTE_ESCALA) -> Node2D:
	var tex: Texture2D = _tex_ruta(ruta)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = -ancla - clave / escala
	s.scale = Vector2(escala, escala)
	var nodo := Node2D.new()
	nodo.y_sort_enabled = true
	nodo.add_child(s)
	add_child(nodo)
	nodo.position = pos + clave
	return nodo


func _poner_puente(cell: Vector2i) -> void:
	var m: Vector2 = _at(cell)
	var medio := Vector2(IsoGrid.STEP.x * 0.5, IsoGrid.STEP.y * 0.5)
	# Las hileras van en el borde de la casilla del agua que da a cada orilla.
	_piedras_puente.append(_pieza_puente("res://art/piedras_S.png", ANCLA_PIEDRAS_S,
		m + Vector2(-medio.x, medio.y), Vector2.ZERO))
	_piedras_puente.append(_pieza_puente("res://art/piedras_N.png", ANCLA_PIEDRAS_N,
		m + Vector2(medio.x, -medio.y), Vector2.ZERO))


func _tender_placa() -> void:
	for p in _piedras_puente:
		if is_instance_valid(p):
			p.queue_free()
	_piedras_puente.clear()
	# Por ENCIMA del agua (con z -1 la tapaban las casillas de agua de delante) pero por
	# debajo del jugador: la clave de orden sube 60 px y el dibujo baja lo mismo.
	var t: Node2D = _pieza_puente("res://art/puente_completo.png", ANCLA_COMPLETO,
		_at(_celda_puente), Vector2(0.0, -60.0), ESCALA_COMPLETO)
	t.z_index = 0


## El interruptor tiende el puente: el agua de esa casilla desaparece y en su lugar
## queda un camino de tierra.
func _on_interruptor() -> void:
	if _puente_hecho:
		return
	_puente_hecho = true
	if is_instance_valid(_agua_puente):
		_agua_puente.queue_free()
	# Bajo el puente sigue viéndose el agua, pero ya se puede pisar.
	_suelo(_celda_puente, "water", true)
	_tender_placa()
	BlockFx.burst(self, "magia")
	_avisar("Se tiende el puente")
	PlayLog.event("puente")


## Los fuegos del nivel son FOGATAS (fogata.gd): la llama es una capa aparte que solo se
## ve mientras arde, así que al apagarse no queda ningún sprite de fuego.
const ESCALA_FOGATA: float = 1.5

func _fogata(cell: Vector2i, encendida: bool) -> Area2D:
	var f: Area2D = FOGATA.new()
	f.set("start_lit", encendida)
	f.set("escala", ESCALA_FOGATA * SX)
	_colocar(f, cell)
	# El dibujo es de 47 x 42 y el aro de piedras está en su mitad baja: se sube para que
	# el aro caiga en el centro de la casilla.
	var subida := Vector2(0.0, -10.0 * ESCALA_FOGATA * SX)
	(f.get("base") as Sprite2D).position = subida
	(f.get("llama") as Sprite2D).position = subida
	return f


func _fuente_fuego(cell: Vector2i, bloquea: bool) -> void:
	var fuego: Area2D = _fogata(cell, true)
	if bloquea:
		var b := Bloqueo.new()
		b.fuente = fuego
		fuego.add_child(b)
	else:
		_fuegos_fijos.append(fuego)


func _antorcha(cell: Vector2i) -> void:
	_antorchas.append(_fogata(cell, false))


## --- Personajes ---

func _npc(cell: Vector2i, id: String, mirando: String) -> void:
	var n := Npc.new()
	n.id = id
	n.nombre = String(DIALOGOS[id]["nombre"])
	n.lineas = DIALOGOS[id]["lineas"]
	n.y_sort_enabled = true
	_colocar(n, cell)

	var actor := MsActor.new()
	n.add_child(actor)
	actor.setup(id, mirando)
	n.actor = actor

	var cuerpo := StaticBody2D.new()
	var forma := CollisionShape2D.new()
	forma.shape = IsoGrid.footprint(0.45)
	cuerpo.add_child(forma)
	n.add_child(cuerpo)
	_npcs.append(n)


## Cambia el Sprite2D del escenario (arte viejo) por un MsActor del pipeline. Se hace
## ANTES de que entre en el árbol, para que archer.gd / enemy.gd encuentren "su" $Sprite2D.
func _vestir(enemigo: Node2D, id: String, mirando: String, modo: String) -> void:
	var viejo: Node = enemigo.get_node("Sprite2D")
	enemigo.remove_child(viejo)
	viejo.free()
	var actor := MsActor.new()
	actor.name = "Sprite2D"
	enemigo.add_child(actor)
	actor.setup(id, mirando, modo)


func _puerta(cell: Vector2i) -> void:
	var p := PuertaFinal.new()
	p.y_sort_enabled = true
	p.tex_cerrada = _bloque("stone")
	p.tex_abierta = _bloque("path")
	p.escala = Vector2(SX, SY)
	p.desplaza = Vector2(0.0, p.tex_cerrada.get_height() * 0.5 - CARA_Y)
	p.altura_bloque = 38.0 * SY
	p.condicion = Callable(self, "_tareas_completas")
	_colocar(p, cell)
	_puerta_final = p

	_llamas = Llamas.new()
	_llamas.position = Vector2(0.0, -120.0)
	p.add_child(_llamas)


func _salida(cell: Vector2i) -> void:
	var g: Node2D = GOAL_SCENE.instantiate()
	var v: Sprite2D = g.get_node("Visual")
	v.texture = null
	_colocar(g, cell, false)
	var c: CollisionShape2D = g.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if c:
		c.shape = IsoGrid.footprint(0.8)

	# Un anillo de luz en el suelo: "aquí se sale".
	var aro := Disparador.new()
	aro.color = Color(1.0, 0.85, 0.35)
	aro.rotulo = "SALIDA"
	aro.una_vez = false
	g.add_child(aro)


## --- El jugador ---
func _crear_jugador() -> void:
	var p := CharacterBody2D.new()
	p.name = "Player"
	p.y_sort_enabled = true
	p.up_direction = Vector2(0.7071068, -0.7071068)
	p.set_script(load("res://player.gd"))

	var cuerpo := CollisionShape2D.new()
	cuerpo.name = "CollisionShape2D"
	cuerpo.shape = IsoGrid.footprint(0.42)
	p.add_child(cuerpo)

	var pies := Area2D.new()
	pies.name = "Feet"
	var forma_pies := CollisionShape2D.new()
	forma_pies.name = "CollisionShape2D"
	forma_pies.shape = IsoGrid.footprint(0.30)
	pies.add_child(forma_pies)
	p.add_child(pies)

	var sombra := Sprite2D.new()
	sombra.name = "Shadow"
	sombra.visible = false
	p.add_child(sombra)

	var viejo := Sprite2D.new()
	viejo.name = "Sprite2D"
	p.add_child(viejo)

	# El héroe generado por el pipeline: player.gd pide "idle_<DIR>", "walk_<DIR>" y
	# "cast_spell_<DIR>", y MsAtlas se las monta con sus atlas.
	var anim := AnimatedSprite2D.new()
	anim.name = "AnimatedSprite2D"
	anim.sprite_frames = MsAtlas.frames_heroe()
	var meta: Dictionary = MsAtlas.meta("hero")
	if not meta.is_empty():
		var off: Array = meta["offset_visual_px"]
		anim.offset = Vector2(off[0], off[1])
	anim.scale = Vector2.ONE * MsAtlas.escala("hero")
	p.add_child(anim)
	p.set("visual_scale", anim.scale)

	var caster := Node2D.new()
	caster.name = "Spellcaster"
	caster.set_script(load("res://spellcaster.gd"))
	p.add_child(caster)

	var puntero := Puntero.new()
	puntero.name = "Puntero"
	puntero.z_index = 100
	p.add_child(puntero)

	p.position = _at(_inicio)
	add_child(p)
	player = p

	# El gesto de lanzar: el Spellcaster avisa al animador y player.gd reproduce el clip.
	# Se cuelga DESPUÉS de que player.gd haya hecho su _ready(), que es cuando empieza a
	# escuchar los hijos nuevos.
	var animador := ActorAnimator.new()
	animador.clips = {"cast": null}
	p.add_child(animador)


## --- La interfaz ---

func _crear_interfaz() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var barra := ProgressBar.new()
	barra.offset_left = 20.0
	barra.offset_top = 20.0
	barra.offset_right = 240.0
	barra.offset_bottom = 48.0
	barra.value = 100.0
	barra.show_percentage = false
	barra.set_script(load("res://health_bar.gd"))
	ui.add_child(barra)

	_hud = Label.new()
	_hud.position = Vector2(20.0, 56.0)
	_hud.add_theme_font_size_override("font_size", 14)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hud.add_theme_constant_override("outline_size", 4)
	ui.add_child(_hud)

	_aviso = Label.new()
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 26)
	_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_aviso.add_theme_constant_override("outline_size", 6)
	_aviso.modulate.a = 0.0
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_aviso)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_aviso.offset_top = 90.0
	_aviso.offset_bottom = 130.0

	_pista_e = Label.new()
	_pista_e.text = "[E] Hablar"
	_pista_e.visible = false
	_pista_e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pista_e.add_theme_font_size_override("font_size", 20)
	_pista_e.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_pista_e.add_theme_constant_override("outline_size", 6)
	_pista_e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_pista_e)
	_pista_e.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_pista_e.offset_top = -260.0
	_pista_e.offset_bottom = -230.0
	_pista_e.offset_left = -120.0
	_pista_e.offset_right = 120.0

	for cartel in [_cartel("¡VICTORIA!", "victory_ui", Color.WHITE),
			_cartel("HAS MUERTO\nPulsa R para reintentar", "gameover_ui", Color(0.9, 0.2, 0.2))]:
		ui.add_child(cartel)
		cartel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var paginas := Control.new()
	paginas.set_script(load("res://page_hud.gd"))
	ui.add_child(paginas)
	paginas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if PALETA_RUNAS:
		var paleta := PanelContainer.new()
		paleta.set_script(load("res://rune_palette.gd"))
		ui.add_child(paleta)

	var libro := Control.new()
	libro.process_mode = Node.PROCESS_MODE_ALWAYS
	libro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	libro.set_script(load("res://spellbook.gd"))
	ui.add_child(libro)
	libro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dialogo = Dialogo.new()
	_dialogo.panel_textura = _tex_ruta(PANEL_UI)
	_dialogo.cerrado.connect(_on_dialogo_cerrado)
	add_child(_dialogo)

	var control := Node.new()
	control.process_mode = Node.PROCESS_MODE_ALWAYS
	control.set_script(load("res://level_controller.gd"))
	add_child(control)

	# Mochila (I) y pantalla de muerte.
	bolsa = BolsaUI.new()
	bolsa.panel_textura = _tex_ruta(PANEL_UI)
	add_child(bolsa)
	pantalla_muerte = PantallaMuerte.new()
	add_child(pantalla_muerte)


func _cartel(texto: String, grupo: String, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.visible = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_to_group(grupo)
	return l


func _refrescar_hud() -> void:
	if _hud == null:
		return
	var p: Dictionary = _progreso()
	var lineas: Array = []
	for k in NOMBRE_TAREA:
		var hecha: bool = float(p[k]) >= 1.0
		var extra: String = ""
		if k == "goblins":
			extra = "  %d/%d" % [_goblins_muertos(), _goblins.size()]
		elif k == "antorchas":
			extra = "  %d/%d" % [_antorchas_encendidas(), _antorchas.size()]
		lineas.append("%s %s%s" % ["[x]" if hecha else "[ ]", NOMBRE_TAREA[k], extra])
	_hud.text = "Oro: %d\nSellos: %s\nGlifos: %s  (huecos: %d)\n\nTAREAS\n%s" % [
		_oro,
		", ".join(Repertoire.active_elements()),
		", ".join(Repertoire.active_sigils()),
		Repertoire.max_sigils_per_page,
		"\n".join(lineas)]
	# Los encargos de los guardabosques, si los hay.
	if _hud == null or misiones == null:
		return
	var t: String = misiones.texto_hud()
	if t != "":
		_hud.text += "\n\nENCARGOS\n" + t


## --- Tareas ---

func _goblins_muertos() -> int:
	var vivos: int = 0
	for g in _goblins:
		if is_instance_valid(g):
			vivos += 1
	return _goblins.size() - vivos


func _antorchas_encendidas() -> int:
	var n: int = 0
	for t in _antorchas:
		if is_instance_valid(t) and bool(t.get("is_lit")):
			n += 1
	return n


## Cuánto de cada tarea está hecho, de 0 a 1.
func _progreso() -> Dictionary:
	var p: Dictionary = {}
	p["baldosa"] = 1.0 if _baldosa_pisada else 0.0
	p["npc"] = 1.0 if _npc_hablado else 0.0
	p["goblins"] = float(_goblins_muertos()) / float(maxi(1, _goblins.size()))
	p["antorchas"] = float(_antorchas_encendidas()) / float(maxi(1, _antorchas.size()))
	return p


func _tareas_completas() -> bool:
	for v in _progreso().values():
		if float(v) < 1.0:
			return false
	return true


func _exit_tree() -> void:
	SpellFactory.agua_apaga_muros = true


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	_mantener_fuegos()
	_actualizar_tareas()
	_actualizar_llamas()
	_actualizar_pista()


## Fundido de los árboles que tapan a alguien. Solo mira a quien importa: el jugador,
## los goblins y los NPC.
func _process(delta: float) -> void:
	if _arboles.is_empty() or not is_instance_valid(player):
		return

	var cuerpos: Array[Rect2] = []
	var piso: Array[float] = []
	var vistos: Array = [player]
	vistos.append_array(_goblins)
	vistos.append_array(_npcs)
	for n in vistos:
		if not is_instance_valid(n):
			continue
		var pos: Vector2 = (n as Node2D).global_position
		cuerpos.append(Rect2(pos + Vector2(-34.0, -120.0), Vector2(68.0, 130.0)))
		piso.append(pos.y)

	var paso: float = clampf(delta * VEL_FUNDIDO, 0.0, 1.0)
	for par in _arboles:
		var nodo: Node2D = par[0]
		var s: Sprite2D = par[1]
		var r: Rect2 = s.get_rect()
		var caja := Rect2(s.global_position + r.position * s.global_scale, r.size * s.global_scale)
		var tapa: bool = false
		for i in range(cuerpos.size()):
			if nodo.global_position.y > piso[i] - 4.0 and caja.intersects(cuerpos[i]):
				tapa = true
				break
		s.modulate.a = lerpf(s.modulate.a, ALPHA_TAPANDO if tapa else 1.0, paso)


## Las fuentes de fuego no se apagan nunca, y un tocón encendido se queda encendido
## (el vapor del río lo apagaría y haría imposible el puzle). La barrera de fuego (B)
## sí se apaga: ese es su puzle.
func _mantener_fuegos() -> void:
	for f in _fuegos_fijos:
		if is_instance_valid(f) and not bool(f.get("is_lit")):
			f.call("_light", false)
	for t in _antorchas:
		if not is_instance_valid(t):
			continue
		if bool(t.get("is_lit")):
			t.set_meta("encendida", true)
		elif t.has_meta("encendida"):
			t.call("_light", false)


func _actualizar_tareas() -> void:
	var p: Dictionary = _progreso()
	for k in p:
		var hecha: bool = float(p[k]) >= 1.0
		if hecha and not _tareas_hechas.get(k, false):
			_tareas_hechas[k] = true
			PlayLog.event("tarea", {"nombre": k})
			if k != "baldosa":
				_avisar("Tarea hecha: %s" % NOMBRE_TAREA[k])
		elif not hecha and _tareas_hechas.get(k, false):
			# Una antorcha que se apaga vuelve a dejar la tarea sin hacer.
			_tareas_hechas[k] = false
	if is_instance_valid(_puerta_final) and _puerta_final.is_open and not _final_avisada:
		_final_avisada = true
		_avisar("¡Se abre la puerta final!")
	_refrescar_hud()


## 1 llama por tarea: se enciende cuando esa tarea está completa.
func _actualizar_llamas() -> void:
	if not is_instance_valid(_llamas):
		return
	var p: Dictionary = _progreso()
	var orden: Array = ["baldosa", "goblins", "npc", "antorchas"]
	for g in range(4):
		var v: float = float(p[orden[g]])
		_llamas.encendidas[g] = v >= 1.0


## --- NPC ---

func _npc_cercano() -> Npc:
	var mejor: Npc = null
	var dmin: float = 105.0
	for n in _npcs:
		if not is_instance_valid(n):
			continue
		var d: float = player.global_position.distance_to((n as Node2D).global_position)
		if d < dmin:
			dmin = d
			mejor = n
	return mejor


var _npc_activo: Npc = null


func _on_dialogo_cerrado() -> void:
	var n: Npc = _npc_activo
	if is_instance_valid(_npc_activo):
		_npc_activo.hablar(false)
	_npc_activo = null
	if not _npc_hablado:
		_npc_hablado = true
		PlayLog.event("npc")
	# Al despedirse, el tendero abre su tienda y el guardabosques da o cobra su encargo.
	if n == null:
		return
	match n.id:
		"guardabosques":
			misiones.al_cerrar(n)
		"bookseller_woman":
			call_deferred("_abrir_librera")
		"alquimista":
			call_deferred("_abrir_alquimista")


func _avisar(texto: String) -> void:
	_refrescar_hud()
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(2.4)
	_tween.tween_property(_aviso, "modulate:a", 0.0, 0.8)


## --- La cámara ---

func _colocar_camara() -> void:
	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = SEGUIMIENTO

	var caja: Rect2 = _limites()
	cam.limit_left = int(caja.position.x)
	cam.limit_top = int(caja.position.y)
	cam.limit_right = int(caja.end.x)
	cam.limit_bottom = int(caja.end.y)

	player.add_child(cam)
	cam.make_current()
	cam.reset_smoothing()


func _limites() -> Rect2:
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for y in range(_mapa().size()):
		var linea: String = _mapa()[y]
		for x in range(linea.length()):
			if linea[x] == "#":
				continue
			var p: Vector2 = _at(Vector2i(x, y))
			minimo = minimo.min(p)
			maximo = maximo.max(p)
	var borde := Vector2(IsoGrid.STEP.x + MARGEN, IsoGrid.STEP.y + MARGEN)
	return Rect2(minimo - borde, (maximo - minimo) + borde * 2.0)


## ======================= SISTEMAS NUEVOS =======================


func _npc_mundo(cell: Vector2i, modelo: String, rol: String, nombre: String, mirando: String,
		lineas: Array, tinte: Color) -> Npc:
	var n := Npc.new()
	n.id = rol
	n.nombre = nombre
	n.lineas = lineas
	n.y_sort_enabled = true
	_colocar(n, cell)
	var actor := MsActor.new()
	n.add_child(actor)
	actor.setup(modelo, mirando)
	actor.modulate = tinte
	n.actor = actor
	var cuerpo := StaticBody2D.new()
	var forma := CollisionShape2D.new()
	forma.shape = IsoGrid.footprint(0.45)
	cuerpo.add_child(forma)
	n.add_child(cuerpo)
	_npcs.append(n)
	return n


## --- Los puestos de venta: el puesto es el PLACEHOLDER y el tendero va AL NORTE ---

func _colocar_puesto() -> void:
	for p in _puestos():
		_poner_puesto(String(p[0]), p[1] as Vector2i)


func _poner_puesto(rol: String, cell: Vector2i) -> void:
	var n := Node2D.new()
	n.y_sort_enabled = true
	_colocar(n, cell)
	n.position += Vector2(IsoGrid.STEP.x * 0.5, IsoGrid.STEP.y * 0.5)   # entre sus dos casillas

	var s := Sprite2D.new()
	s.texture = _tex_ruta(PUESTO_ART)
	s.centered = false
	s.scale = Vector2(0.5, 0.5)
	s.offset = -ANCLA_PUESTO
	n.add_child(s)

	var cuerpo := StaticBody2D.new()
	var forma := CollisionShape2D.new()
	var poli := ConvexPolygonShape2D.new()
	var ex := Vector2(IsoGrid.STEP.x, IsoGrid.STEP.y)
	var ey := Vector2(-IsoGrid.STEP.x, IsoGrid.STEP.y)
	poli.points = PackedVector2Array([
		-ex * 0.95 - ey * 0.45, ex * 0.95 - ey * 0.45,
		ex * 0.95 + ey * 0.45, -ex * 0.95 + ey * 0.45])
	forma.shape = poli
	cuerpo.add_child(forma)
	n.add_child(cuerpo)
	_puestos_nodos[rol] = n

	# El tendero, al NORTE del puesto (detrás del mostrador, mirando al jugador).
	var d: Array = TENDEROS[rol]
	var lineas: Array = d[4]
	if rol == "librera":
		lineas = DIALOGOS["bookseller_woman"]["lineas"]
	_tenderos[rol] = _npc_mundo(cell + Vector2i(0, -1), String(d[1]), String(d[0]), String(d[2]), "S", lineas, d[3])


## Rol del puesto más cercano al jugador (o "" si no hay ninguno a mano).
func _puesto_cercano() -> String:
	if not is_instance_valid(player):
		return ""
	var mejor: String = ""
	var dmin: float = DISTANCIA_PUESTO
	for rol in _puestos_nodos:
		var d: float = player.global_position.distance_to((_puestos_nodos[rol] as Node2D).global_position)
		if d < dmin:
			dmin = d
			mejor = rol
	return mejor


## --- Botín del suelo ---

func _colocar_recogibles() -> void:
	for r in _suelo_objetos():
		var b := Botin.new()
		b.id = String(r[0])
		b.cantidad = int(r[3])
		b.y_sort_enabled = true
		_colocar(b, Vector2i(int(r[1]), int(r[2])))


## --- Enemigos con IA (sustituyen a los del nivel original) ---

func _arquero(cell: Vector2i) -> void:
	var a: Node2D = ARCHER_SCENE.instantiate()
	_vestir(a, "goblin_archer", "W", "ia")
	a.set_script(GOBLIN_ARQUERO)
	a.set("detection_radius", 480.0)
	a.y_sort_enabled = true
	_colocar(a, cell, true)
	_goblins.append(a)


func _guerrero(cell: Vector2i) -> void:
	var e: Node2D = ENEMY_SCENE.instantiate()
	_vestir(e, "goblin_warrior", "E", "ia")
	e.set_script(GOBLIN_GUERRERO)
	e.set("patrol_speed", 55.0)
	e.set("patrol_distance", 120.0)
	e.y_sort_enabled = true
	_colocar(e, cell)
	e.set("start_position", e.position)
	_goblins.append(e)


## El dummy: arquero azul con nombre que no se mueve. No cuenta para las tareas.
func _dummy(cell: Vector2i) -> void:
	var a: Node2D = ARCHER_SCENE.instantiate()
	_vestir(a, "goblin_archer", "SW", "ia")
	a.set_script(GOBLIN_ESCARCHA)
	a.set("detection_radius", 330.0)
	a.y_sort_enabled = true
	_colocar(a, cell, true)


func _extras_base() -> void:
	_tienda_lib = Tienda.new()
	_tienda_lib.panel_textura = _tex_ruta(PANEL_UI)
	_tienda_lib.titulo_texto = "Librería"
	add_child(_tienda_lib)
	_tienda_lib.comprar.connect(_on_comprar_librera)

	_tienda_alq = Tienda.new()
	_tienda_alq.panel_textura = _tex_ruta(PANEL_UI)
	_tienda_alq.titulo_texto = "Alquimista: mejoras"
	add_child(_tienda_alq)
	_tienda_alq.comprar.connect(_on_comprar_alquimista)

	misiones = Misiones.new()
	misiones.avisar = Callable(self, "_avisar")
	add_child(misiones)
	_definir_encargos()
	misiones.iniciar()
	Estado.i().cambiado.connect(_refrescar_hud)


func _hay_ventana() -> bool:
	return (_dialogo != null and _dialogo.abierto) or (_tienda_lib != null and _tienda_lib.abierto) \
		or (_tienda_alq != null and _tienda_alq.abierto) or (bolsa != null and bolsa.abierta)


func _actualizar_pista() -> void:
	if _pista_e == null or _dialogo == null or _tienda_lib == null:
		return
	var hay_npc: bool = _npc_cercano() != null
	var texto: String = "[E] Hablar"
	var hay: bool = hay_npc
	if not hay_npc:
		if Botin.cercano(get_tree(), player.global_position) != null \
				or Recolectable.cercano(get_tree(), player.global_position) != null:
			texto = "[E] Recoger"
			hay = true
		elif _puesto_cercano() != "":
			texto = "[E] Comprar"
			hay = true
	_pista_e.text = texto
	_pista_e.visible = hay and not _hay_ventana()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_E:
		return
	if _dialogo == null or not is_instance_valid(player) or bool(player.get("is_dead")) or _hay_ventana():
		return
	var n: Npc = _npc_cercano()
	if n == null:
		var b: Botin = Botin.cercano(get_tree(), player.global_position)
		if b != null:
			get_viewport().set_input_as_handled()
			b.intentar_coger(player)
			return
		var r: Recolectable = Recolectable.cercano(get_tree(), player.global_position)
		if r != null:
			get_viewport().set_input_as_handled()
			r.intentar_coger(player)
			return
		var rol: String = _puesto_cercano()
		if rol != "":
			get_viewport().set_input_as_handled()
			_abrir_tienda_de(rol)
		return
	get_viewport().set_input_as_handled()
	_npc_activo = n
	n.actor.mirar_a(player.global_position - n.global_position)
	n.hablar(true)
	_dialogo.abrir(n.nombre, _lineas_de(n))


func _lineas_de(n: Npc) -> Array:
	match n.id:
		"guardabosques":
			return misiones.lineas_para(n)
		"bookseller_woman":
			_lib_visitas += 1
			return n.lineas if _lib_visitas == 1 else ["¿Qué te interesa hoy?"]
	return n.lineas


func _abrir_tienda_de(rol: String) -> void:
	if rol == "librera":
		_abrir_librera()
	else:
		_abrir_alquimista()


## --- La librera ---

func _articulos_librera() -> Array:
	var e: Estado = Estado.i()
	var l: Array = []
	l.append({"id": "pocion", "nombre": "Poción de vida",
		"desc": "cura %d (se bebe con Q)" % int(e.cura_pocion), "precio": 10})
	l.append({"id": "hueco", "nombre": "Hueco de glifo",
		"desc": "un glifo más por página (ahora %d)" % Repertoire.max_sigils_per_page, "precio": 20,
		"agotado": Repertoire.max_sigils_per_page >= LIMITE_HUECOS})
	var precio: int = mini(20 + 10 * int(e.mejoras.get("elementos", 0)), 50)
	for el in ["agua", "viento", "tierra", "hielo", "fuego", "rayo"]:
		if Repertoire.element_active(el):
			continue
		l.append({"id": "el:" + el, "nombre": "Tomo de " + el, "desc": "enseña el sello %s" % el.to_upper(),
			"precio": precio})
	return l


func _abrir_librera() -> void:
	_tienda_lib.abrir(_articulos_librera(), Estado.i().oro)


func _on_comprar_librera(id: String) -> void:
	var e: Estado = Estado.i()
	var art: Dictionary = {}
	for a in _articulos_librera():
		if String(a["id"]) == id:
			art = a
	if art.is_empty():
		return
	var precio: int = int(art["precio"])
	if e.oro < precio:
		_tienda_lib.decir("No te alcanza el oro.")
		return
	if id == "pocion":
		if e.agregar("pocion", 1) <= 0:
			_tienda_lib.decir("Tu mochila está llena.")
			return
	elif id == "hueco":
		Repertoire.max_sigils_per_page += 1
	elif id.begins_with("el:"):
		if not Repertoire.unlock_element(id.substr(3)):
			_tienda_lib.decir("Ya conoces ese sello.")
			return
		e.mejoras["elementos"] = int(e.mejoras.get("elementos", 0)) + 1
		_avisar("¡Desbloqueado!  Sello %s" % id.substr(3).to_upper())
	e.gastar_oro(precio)
	Sonidos.play(self, "comprar", -6.0)
	PlayLog.event("compra", {"id": id})
	_tienda_lib.decir("Comprado: %s" % String(art["nombre"]))
	_tienda_lib.refrescar(_articulos_librera(), e.oro)
	_refrescar_hud()


## --- El alquimista: las MEJORAS (vida, huecos de mochila, cura, velocidad) ---

func _abrir_alquimista() -> void:
	_tienda_alq.abrir(Alquimia.articulos(Estado.i()), Estado.i().oro)


func _on_comprar_alquimista(id: String) -> void:
	var e: Estado = Estado.i()
	var fallo: String = Alquimia.comprar(e, id)
	if fallo != "":
		_tienda_alq.decir(fallo)
		return
	Sonidos.play(self, "comprar", -6.0)
	_tienda_alq.decir("¡Hecho!")
	_tienda_alq.refrescar(Alquimia.articulos(e), e.oro)
	_refrescar_hud()
