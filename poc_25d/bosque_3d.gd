class_name Bosque3D
extends Node

## REGLAS DEL NIVEL «BOSQUE 1» EN 3D (Fase 9, Juego). Hermano de Jugabilidad3D: la maqueta (PruebaTest2 con `reglas = "bosque"`)
## lo monta con las mismas llamadas —`registrar_*` mientras coloca letras, `colocar(mundo)` antes de agrupar los lotes e
## `iniciar(mundo)` al final de _ready, con el Jugador3D ya montado— y él pone las reglas. No hereda de Jugabilidad3D a
## propósito: aquel archivo es una lista de cuatro tareas con su mapa pegado dentro; este nivel tiene otra lógica (tres runas)
## y su mapa vive en un .tscn/.txt del Pipeline.
##
## EL NIVEL, en una pantalla (docs/PLAN_ARREGLOS.md, Fase 9):
##   · Tres TÓTEMS (fuego, agua, rayo). Cada uno activado ilumina SU runa en la puerta final `X`; con las tres, se abre.
##   · El tótem de FUEGO no se enciende con un hechizo: lo activan las 4 ANTORCHAS DE ARRIBA encendidas (las de abajo, junto
##     a la librera, son de práctica). Por eso aquí se le quita la colisión de hechizos: un fuego que pase cerca no se lo
##     salta. Lo mismo con el de rayo, que solo lo activa la conducción del EmisorRayo3D (el jugador no tiene rayo).
##   · La SALIDA `E` está sellada hasta que muere el elemental de bosque (`G`).
##   · La zona `a` (detrás de la telaraña) da el SELLO de agua (Repertoire.unlock_element).
##   · El guardabosques vende el GLIFO barrera por 20 de oro (tienda mínima: E para hablar, E otra vez para comprar). El goblin
##     guerrero de la zona de inicio suelta 20 de oro fijos: así se puede probar la tienda en cuanto se llega a él.
##   · Fuente eléctrica `e` y surtidor `u`: se montan solos leyendo esas letras del mapa (EmisorRayo3D y Surtidor3D).
##
## Qué NO hace: dibujar las piezas nuevas (puerta con tres runas, fuente, surtidor, cauce: 9.7, Pipeline), ni leer el mapa
## (9.5, Pipeline). Mientras tanto la puerta es un tablón con tres lámparas, como la de Jugabilidad3D.
##
## Vocabulario (docs/CONTEXTO.md): SELLO = elemento; GLIFO = forma. El agua es un sello; la barrera, un glifo.

const PRECIO_BARRERA: int = 20
const ORO_GOBLIN_INICIO: int = 20
const FILA_MAX_ARRIBA: int = 28             ## filas 1–28 del mapa = la mitad de arriba (las antorchas de arriba activan el tótem)
const ALCANCE_HABLAR: float = 2.7           ## unidades (la casilla mide 2,3)
const T_OFERTA: float = 6.0                 ## s que dura el «¿la compras?» tras oír al guardabosques
const ELEMENTOS_RUNA: Array = ["fuego", "agua", "rayo"]   ## orden de las lámparas de la puerta, de izquierda a derecha
const NOMBRE_ELEMENTO: Dictionary = {"fuego": "Fuego", "agua": "Agua", "rayo": "Rayo"}
const COLOR_APAGADO: Color = Color(0.42, 0.42, 0.48)
const COLOR_LOSA_AGUA: Color = Color(0.45, 0.72, 1.0)

## 9.12 — BORRADOR de diálogos para que Pablo los apruebe (9.2). La voz es la de CONTEXTO.md: frases cortas, humor seco, y cada
## línea trabaja (una pista, un precio, un aviso); nada de explicar la mecánica. El guardabosques es el único NPC con tienda.
const DIALOGOS: Dictionary = {
	"guardabosques": [
		"La puerta del fondo quiere tres runas: fuego, agua y rayo. Una por tótem. Ni una menos.",
		"Hay un elemental detrás. Al fuego le tiene respeto. Al agua... ni una gota: se cura y se hace más grande. Lo he visto.",
		"Los goblins de abajo llevan monedas encima. Y las barreras cuestan veinte.",
	],
	"librera": [
		"Las antorchas se encienden con fuego. Y lo que arde, contagia: mira dónde pisas.",
		"La telaraña no te va a dejar pasar por las buenas. Ni por las malas, pero las malas tienen más gracia.",
		"El rayo viaja por el agua. Yo, en tu lugar, no me metería.",
	],
}
const TEXTO_OFERTA: String = "¿Una barrera? Son %d de oro. (E para comprar)"
const TEXTO_SIN_ORO: String = "Te faltan %d de oro. Los goblins de abajo suelen llevar."
const TEXTO_YA_COMPRADA: String = "Ya tienes la barrera. Úsala antes de necesitarla."

var m: Variant = null                       ## la maqueta (PruebaTest2). Sin tipo: se le llama a métodos suyos
var _losas: Dictionary = {}                 ## Vector2i -> letra (a, p, w)
var _npcs: Dictionary = {}                  ## nombre -> Pj3D
var _puerta: MeshInstance3D = null
var _puerta_c: Vector2i = Vector2i(-1, -1)
var _salida_c: Vector2i = Vector2i(-1, -1)
var _sello_salida: MeshInstance3D = null
var _lamparas: Array = []                   ## 3 MeshInstance3D, en el orden de ELEMENTOS_RUNA
var _runa_lista: Array = [false, false, false]
var _totems: Dictionary = {}                ## elemento -> Reactivo3D
var _braseros_arriba: Array = []            ## Reactivo3D (las antorchas que cuentan)
var _elementales: Array = []                ## Combate3D de los elementales del nivel
var _puerta_abierta: bool = false
var _salida_abierta: bool = false
var _terminado: bool = false
var _agua_dada: bool = false
var _barrera_comprada: bool = false
var _t: float = 0.0
var _t_aviso: float = 0.0
var _t_oferta: float = 0.0
var _jug: Jugador3D = null
var _hud: Label = null
var _aviso: Label = null
var _lineas: Dictionary = {}
var _hablando: Pj3D = null
var _t_habla: float = 0.0
var _t_hud: float = 0.0


func registrar_losa(letra: String, c: Vector2i) -> void:
	_losas[c] = letra


func registrar_npc(nombre: String, pj: Pj3D) -> void:
	if pj != null:
		_npcs[nombre] = pj


## Todo lo que se pone en el mundo, ANTES de que la maqueta agrupe los lotes.
func colocar(mundo: Variant) -> void:
	m = mundo
	var mapa: PackedStringArray = m.get("_mapa")
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			var c := Vector2i(x, y)
			match mapa[y][x]:
				"X":
					_puerta_c = c
				"E":
					_salida_c = c
				"e":
					var em := EmisorRayo3D.new()
					em.name = "emisor_%d_%d" % [x, y]
					(m.get("_props") as Node).add_child(em)
					em.preparar(m, c)
				"u":
					var su := Surtidor3D.new()
					su.name = "surtidor_%d_%d" % [x, y]
					(m.get("_props") as Node).add_child(su)
					su.preparar(m, c)
	for c in _losas:
		if _losas[c] == "a":
			m.call("_disco", "", m.call("_centro_celda", c, m.get("Y_DECAL")), float(m.get("S")) * 0.85, COLOR_LOSA_AGUA)
			var rot := Label3D.new()
			rot.text = "SELLO DE AGUA"
			rot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			rot.font_size = 48
			rot.outline_size = 10
			rot.pixel_size = 0.005
			rot.modulate = COLOR_LOSA_AGUA
			rot.position = m.call("_centro_celda", c, float(m.get("ALTO")) + 0.55)
			(m.get("_props") as Node).add_child(rot)
	if _puerta_c.x >= 0:
		_montar_puerta()
	if _salida_c.x >= 0:
		_montar_sello_salida()


## La puerta: un tablón que cierra el paso (de oeste a este) y tres lámparas encima, una por runa.
func _montar_puerta() -> void:
	var s: float = float(m.get("S"))
	var alto: float = float(m.get("ALTO"))
	var caja := BoxMesh.new()
	caja.size = Vector3(0.28, 2.3, s * 0.92)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.34, 0.22)
	mat.roughness = 0.9
	caja.material = mat
	_puerta = MeshInstance3D.new()
	_puerta.name = "puerta_final"
	_puerta.mesh = caja
	_puerta.position = m.call("_centro_celda", _puerta_c, alto + 1.15)
	(m.get("_props") as Node).add_child(_puerta)
	(m.get("_bloqueadas") as Dictionary)[_puerta_c] = true
	var base: Vector3 = m.call("_centro_celda", _puerta_c, alto + 3.9)
	for i in range(3):
		var lamp: MeshInstance3D = Formas3D.instancia("llama", COLOR_APAGADO, 0.42)
		lamp.position = base + Vector3((float(i) - 1.0) * 0.6, 0.0, 0.0)
		(m.get("_props") as Node).add_child(lamp)
		_lamparas.append(lamp)


## La salida sellada: una cortina azul translúcida sobre la casilla `E` hasta que muera el elemental.
func _montar_sello_salida() -> void:
	var s: float = float(m.get("S"))
	var caja := BoxMesh.new()
	caja.size = Vector3(0.2, 2.6, s * 0.95)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.72, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.72, 1.0)
	mat.emission_energy_multiplier = 0.6
	caja.material = mat
	_sello_salida = MeshInstance3D.new()
	_sello_salida.name = "sello_salida"
	_sello_salida.mesh = caja
	_sello_salida.position = m.call("_centro_celda", _salida_c, float(m.get("ALTO")) + 1.3)
	(m.get("_props") as Node).add_child(_sello_salida)
	(m.get("_bloqueadas") as Dictionary)[_salida_c] = true


## Al final de _ready de la maqueta: el Jugador3D ya existe, los goblins ya tienen su Combate3D y los reactivos están puestos.
func iniciar(mundo: Variant) -> void:
	m = mundo
	for n in (m as Node).get_children():
		if n is Jugador3D:
			_jug = n
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	_hud = Label.new()
	_hud.position = Vector2(12.0, 150.0)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	capa.add_child(_hud)
	_aviso = Label.new()
	_aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso.position = Vector2(-300.0, -120.0)
	_aviso.custom_minimum_size = Vector2(600.0, 0.0)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 22)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 8)
	capa.add_child(_aviso)
	for k in DIALOGOS:
		_lineas[k] = 0
	# Tótems y antorchas: los reactivos que puso la maqueta.
	for r in (m.get("_reactivos") as Array):
		if not is_instance_valid(r):
			continue
		if r.tipo == "totem":
			_totems[r.elemento] = r
			if r.elemento != "agua":
				# Fuego y rayo no se activan con hechizos (los activan las antorchas y la corriente): fuera de la capa de hechizos.
				(r as CollisionObject3D).collision_layer = 0
		elif r.tipo == "brasero" and int(r.celda.y) <= FILA_MAX_ARRIBA:
			_braseros_arriba.append(r)
	# Elementales del nivel (para sellar la salida hasta que mueran) y el oro fijo del goblin de la zona de inicio.
	_ajustar_combates()
	_salida_abierta = _salida_c.x < 0 or _elementales.is_empty()
	if _salida_abierta and _sello_salida != null:
		_abrir_salida(false)
	_refrescar_hud()


## Busca los Combate3D del nivel: marca los elementales y pone 20 de oro FIJOS al guerrero que más cerca empieza del jugador.
func _ajustar_combates() -> void:
	var inicio: Vector3 = (m.get("_jugador") as Node3D).position if m.get("_jugador") != null else Vector3.ZERO
	var elegido: Combate3D = null
	var mejor: float = INF
	for n in get_tree().get_nodes_in_group("combate3d"):
		var cb: Combate3D = n as Combate3D
		if cb == null:
			continue
		if cb.elemental:
			_elementales.append(cb)
		elif not cb.arquero:
			var d: float = Vector2(cb.position.x - inicio.x, cb.position.z - inicio.z).length()
			if d < mejor:
				mejor = d
				elegido = cb
	if elegido != null:
		elegido.oro = ORO_GOBLIN_INICIO


func _process(delta: float) -> void:
	if m == null or m.get("_jugador") == null:
		return
	_t += delta
	var pj: Pj3D = m.get("_jugador")
	var c: Vector2i = m.call("_celda_de", pj.position)
	_t_aviso = maxf(_t_aviso - delta, 0.0)
	_t_oferta = maxf(_t_oferta - delta, 0.0)
	# Antorchas de arriba → tótem de fuego.
	if _totems.has("fuego") and not bool(_totems["fuego"].activo) and not _braseros_arriba.is_empty() and _antorchas_encendidas() == _braseros_arriba.size():
		_totems["fuego"].on_spell_hit(_runa(["fuego", "calor"]), Vector3.ZERO)
	# Runas de la puerta: cada tótem activado ilumina la suya.
	for i in range(3):
		var el: String = ELEMENTOS_RUNA[i]
		if not _runa_lista[i] and _totems.has(el) and bool(_totems[el].activo):
			_runa_lista[i] = true
			_encender_runa(i)
	if not _puerta_abierta and _puerta_c.x >= 0 and not _runa_lista.has(false):
		_abrir_puerta()
	# Sello de agua (zona `a`).
	if not _agua_dada and _losas.get(c, "") == "a":
		_agua_dada = true
		if Repertoire.unlock_element("agua"):
			_decir("Sello de agua conseguido: ya puedes dibujarlo.", 5.0)
		_refrescar_hud()
	# Salida: se abre al morir los elementales; se completa pisándola.
	if not _salida_abierta and _elementales_muertos():
		_abrir_salida(true)
	if _salida_abierta and not _terminado and c == _salida_c:
		_terminado = true
		_decir("¡Bosque completado en %d s!" % int(_t), 8.0)
	if _hablando != null:
		_t_habla -= delta
		if _t_habla <= 0.0:
			_hablando.animacion_actual = ""
			_hablando.jugar("idle")
			_hablando = null
	if _t_aviso <= 0.0 and _aviso != null:
		_aviso.text = ""
	_t_hud += delta
	if _t_hud > 0.25:
		_t_hud = 0.0
		_refrescar_hud()


func _antorchas_encendidas() -> int:
	var n: int = 0
	for r in _braseros_arriba:
		if is_instance_valid(r) and bool(r.is_lit):
			n += 1
	return n


func _elementales_muertos() -> bool:
	for e in _elementales:
		if is_instance_valid(e) and not bool(e.muerto):
			return false
	return true


static func _runa(etiquetas: Array) -> RuneData:
	var r := RuneData.new()
	var t: Array[String] = []
	for e in etiquetas:
		t.append(String(e))
	r.tags = t
	return r


func _encender_runa(i: int) -> void:
	var el: String = ELEMENTOS_RUNA[i]
	var col: Color = Reactivo3D.COLOR_ELEMENTO.get(el, Color.WHITE)
	if i < _lamparas.size():
		var lamp: MeshInstance3D = _lamparas[i]
		lamp.set_surface_override_material(0, Formas3D.material_tinte(col, false, "llama"))
		if m.get("_fx") != null:
			(m.get("_fx") as Vfx3D).chispazo(lamp.position, el)
	_decir("Runa de %s iluminada (%d/3)" % [String(NOMBRE_ELEMENTO[el]).to_lower(), _runa_lista.count(true)], 3.5)


func _abrir_puerta() -> void:
	_puerta_abierta = true
	m.call("_liberar", _puerta_c)
	_decir("¡La puerta se abre!", 4.0)
	if _puerta != null:
		var tw := create_tween()
		tw.tween_property(_puerta, "position:y", _puerta.position.y - 2.4, 1.4).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_puerta.hide)


func _abrir_salida(con_aviso: bool) -> void:
	_salida_abierta = true
	m.call("_liberar", _salida_c)
	if con_aviso:
		_decir("El elemental ha caído: la salida está libre.", 5.0)
	if _sello_salida != null:
		var tw := create_tween()
		tw.tween_property(_sello_salida, "scale:y", 0.01, 0.8)
		tw.tween_callback(_sello_salida.hide)


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null or m.get("_jugador") == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or k.keycode != KEY_E:
		return
	var yo: Vector3 = (m.get("_jugador") as Pj3D).position
	var mejor: String = ""
	var dist: float = ALCANCE_HABLAR
	for nombre in _npcs:
		var d: Vector3 = (_npcs[nombre] as Pj3D).position - yo
		d.y = 0.0
		if d.length() < dist:
			dist = d.length()
			mejor = String(nombre)
	if mejor == "":
		return
	# Segunda E con la oferta en pie = comprar.
	if mejor == "guardabosques" and _t_oferta > 0.0:
		_comprar_barrera()
		return
	var npc: Pj3D = _npcs[mejor]
	var lineas: Array = DIALOGOS.get(mejor, ["..."])
	var i: int = int(_lineas.get(mejor, 0))
	_lineas[mejor] = i + 1
	var texto: String = String(lineas[i % lineas.size()])
	# El guardabosques cierra cada vuelta de frases con la oferta de la barrera (hasta que la compres).
	if mejor == "guardabosques" and i % lineas.size() == lineas.size() - 1:
		texto += "\n" + (TEXTO_YA_COMPRADA if _barrera_comprada else TEXTO_OFERTA % PRECIO_BARRERA)
		if not _barrera_comprada:
			_t_oferta = T_OFERTA
	_decir("%s: «%s»" % [mejor.capitalize(), texto], 5.0)
	npc.mirar(yo - npc.position, 1.0)
	npc.jugar("talk")
	_hablando = npc
	_t_habla = 2.5


## La tienda mínima: oro → glifo barrera (Repertoire.unlock_sigil). Si ya la tienes o no llega el oro, lo dice.
func _comprar_barrera() -> void:
	_t_oferta = 0.0
	if _barrera_comprada or Repertoire.sigil_active("barrera"):
		_barrera_comprada = true
		_decir("Guardabosques: «%s»" % TEXTO_YA_COMPRADA, 4.0)
		return
	var e: Estado = Estado.i()
	if e.oro < PRECIO_BARRERA:
		_decir("Guardabosques: «%s»" % (TEXTO_SIN_ORO % (PRECIO_BARRERA - e.oro)), 4.0)
		return
	if e.gastar_oro(PRECIO_BARRERA):
		Repertoire.unlock_sigil("barrera")
		_barrera_comprada = true
		_decir("Glifo barrera comprado (-%d oro)" % PRECIO_BARRERA, 5.0)
		PlayLog.event("compra", {"objeto": "barrera", "precio": PRECIO_BARRERA, "oro": e.oro})


func _decir(texto: String, seg: float) -> void:
	if _aviso != null:
		_aviso.text = texto
	_t_aviso = seg


func _refrescar_hud() -> void:
	if _hud == null:
		return
	var t: String = "BOSQUE 1  ·  E hablar  ·  %d s  ·  oro %d\n" % [int(_t), Estado.i().oro]
	t += "  Runas de la puerta:"
	for i in range(3):
		t += "  [%s] %s" % ["x" if _runa_lista[i] else " ", NOMBRE_ELEMENTO[ELEMENTOS_RUNA[i]]]
	t += "\n"
	if not _braseros_arriba.is_empty():
		t += "  Antorchas de arriba: %d/%d\n" % [_antorchas_encendidas(), _braseros_arriba.size()]
	t += "  Puerta: %s" % ("ABIERTA" if _puerta_abierta else "cerrada")
	t += "  ·  Salida: %s" % ("LIBRE" if _salida_abierta else "sellada (el elemental la guarda)")
	_hud.text = t
