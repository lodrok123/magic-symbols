extends "res://nivel_base.gd"

## LABORATORIO DE VFX: EL MUNDO, ELEMENTO A ELEMENTO.
##
## Complemento de VfxLab.tscn (que juzga la FORMA de los glifos en abstracto). Aquí cada
## elemento tiene su BAHÍA aislada con las cosas del mundo con las que reacciona, y un
## lanzador invisible que, en bucle, le tira su elemento a cada una. Así se ve todo lo
## nuevo sin mezclar: el camino de hielo (nevado -> escarcha -> claro), la barrera de fuego
## que se apaga, la hierba que crece o arde, el viento que recoge una llama y cruza el agua,
## el rayo que corre por la charca, los pasaderos de tierra, la placa de peso, las plantas
## que sueltan ingredientes, las barras de vida y debilidades de los goblins...
##
## TECLAS
##   F2 / F3   bahía anterior / siguiente (lleva al jugador allí)
##   F4        bucle automático on/off           F5   lanzar ahora en la bahía actual
##   R         (con el jugador vivo) recargar la escena para ver todo desde cero
##   F9        ir al laboratorio clásico (VfxLab.tscn); desde allí F9 vuelve aquí
## El jugador también puede lanzar lo que quiera (están todos los sellos y glifos).

const ANCHO_BAHIA: int = 7
## Cada bahía: elemento, runa, letras que son blanco, plano de 6 x 12 (de norte a sur).
## Las letras son las del nivel (ver test_jugabilidad.gd y nivel_base.gd).
const BAHIAS: Array = [
	{"nombre": "FUEGO", "runa": "res://fire_rune.tres", "blancos": "zlvGTshD", "plano": [
		"..D...", "......", ".z.l..", "......", ".vvGG.", "......",
		"..T...", "......", "s....h", "......", "......", "......"]},
	{"nombre": "AGUA", "runa": "res://water_rune.tres", "blancos": "BvOfD", "plano": [
		"..D...", "......", ".BB...", "......", ".vv...", "......",
		"..O...", "......", "f.....", "......", "......", "......"]},
	{"nombre": "VIENTO", "runa": "res://wind_rune.tres", "blancos": "FfsD", "plano": [
		"..T...", "..~...", "..~...", "..~...", "..F...", "......",
		"f....s", "......", "......", "D.....", "......", "......"]},
	{"nombre": "RAYO", "runa": "res://lightning_rune.tres", "blancos": "~iqD", "plano": [
		"..D...", "......", ".~~~..", ".~~~..", "......", ".i....",
		"......", "q.....", "......", "......", "......", "......"]},
	{"nombre": "HIELO", "runa": "res://ice_rune.tres", "blancos": "~sfD", "plano": [
		"..D...", "......", "~~~~~~", "~~~~~~", "......", "s....f",
		"......", "......", "......", "......", "......", "......"]},
	{"nombre": "TIERRA", "runa": "res://earth_rune.tres", "blancos": "~KqD", "quietos": "~K", "plano": [
		"..D...", "......", ".~~...", "......", ".K....", "q.....",
		"......", "......", "......", "......", "......", "......"]},
]

var _mapa_lab: PackedStringArray = PackedStringArray()
var _bahia: int = 0
var _bucle: bool = true
var _t_lanzar: float = 1.5
var _indice: Array = []          ## por bahía: qué blanco toca ahora


func _mapa() -> PackedStringArray:
	if _mapa_lab.is_empty():
		_mapa_lab = _construir_plano()
	return _mapa_lab


## El plano se arma con las bahías en fila, separadas por árboles.
func _construir_plano() -> PackedStringArray:
	var ancho: int = BAHIAS.size() * ANCHO_BAHIA + 1
	var filas: Array = []
	filas.append("#".repeat(ancho))
	for y in range(12):
		var f: String = "#"
		for i in range(BAHIAS.size()):
			var linea: String = String(BAHIAS[i]["plano"][y])
			if i == 0 and y == 11:
				linea = "..S..."
			f += linea + "#"
		filas.append(f)
	filas.append("#".repeat(ancho))
	return PackedStringArray(filas)


func _repertorio_inicial() -> void:
	Repertoire.aim_with_mouse = APUNTAR_CON_RATON
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = 3


func _lista_empujables() -> Array:
	# Uno de hielo en la bahía del fuego (se derrite) y uno de tierra en la de tierra.
	return [["hielo", 5, 6], ["tierra", 5 * ANCHO_BAHIA + 5, 9]]


func _extras_nivel() -> void:
	# Cámara más abierta que en los niveles: la bahía entera tiene que caber en pantalla.
	for c in player.get_children():
		if c is Camera2D:
			(c as Camera2D).zoom = Vector2(0.9, 0.9)
	for i in range(BAHIAS.size()):
		_indice.append(0)
		var l := Label.new()
		l.text = String(BAHIAS[i]["nombre"])
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 7)
		l.position = _at(_lanzador(i)) + Vector2(-50.0, 20.0)
		l.z_index = 30
		add_child(l)
	_ir_a(0)


func _lanzador(i: int) -> Vector2i:
	return Vector2i(1 + i * ANCHO_BAHIA + 2, 11)


func _blancos(i: int) -> Array:
	var b: Dictionary = BAHIAS[i]
	var letras: String = String(b["blancos"])
	var l: Array = []
	for y in range(12):
		var fila: String = String(b["plano"][y])
		for x in range(6):
			if letras.contains(fila[x]):
				l.append([Vector2i(1 + i * ANCHO_BAHIA + x, y + 1), fila[x]])
	return l


func _ir_a(i: int) -> void:
	_bahia = posmod(i, BAHIAS.size())
	if is_instance_valid(player):
		player.global_position = _at(Vector2i(1 + _bahia * ANCHO_BAHIA + 4, 7))
	_avisar("Bahía: %s" % String(BAHIAS[_bahia]["nombre"]))


func _lanzar_bahia(i: int) -> void:
	var bl: Array = _blancos(i)
	if bl.is_empty():
		return
	var k: int = int(_indice[i]) % bl.size()
	_indice[i] = k + 1
	var celda: Vector2i = bl[k][0]
	var letra: String = bl[k][1]
	var runa: RuneData = load(String(BAHIAS[i]["runa"]))
	var desde: Vector2 = _at(_lanzador(i))
	if String(BAHIAS[i].get("quietos", "")).contains(letra):
		SpellFactory.cast(self, _at(celda), Vector2.ZERO, runa, 0.8)
	else:
		SpellFactory.cast(self, desde, (_at(celda) - desde).normalized(), runa)


func _process(delta: float) -> void:
	super(delta)
	if not _bucle:
		return
	_t_lanzar -= delta
	if _t_lanzar <= 0.0:
		_t_lanzar = 2.2
		_lanzar_bahia(_bahia)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		match k.keycode:
			KEY_F2:
				_ir_a(_bahia - 1)
				return
			KEY_F3:
				_ir_a(_bahia + 1)
				return
			KEY_F4:
				_bucle = not _bucle
				_avisar("Bucle automático: %s" % ("sí" if _bucle else "no"))
				return
			KEY_F5:
				_lanzar_bahia(_bahia)
				return
			KEY_F9:
				get_tree().call_deferred("change_scene_to_file", "res://VfxLab.tscn")
				return
			KEY_R:
				if is_instance_valid(player) and not bool(player.get("is_dead")):
					get_tree().call_deferred("reload_current_scene")
					return
	super(event)


func _refrescar_hud() -> void:
	if _hud == null:
		return
	_hud.text = "LABORATORIO DE VFX: EL MUNDO\nBahía actual: %s\n\nF2 / F3  bahía anterior / siguiente\nF4  bucle automático (%s)\nF5  lanzar ahora\nR  recargar todo\nF9  laboratorio clásico" % [
		String(BAHIAS[_bahia]["nombre"]) if not BAHIAS.is_empty() else "", "sí" if _bucle else "no"]


func _actualizar_tareas() -> void:
	_refrescar_hud()


func _actualizar_llamas() -> void:
	pass
