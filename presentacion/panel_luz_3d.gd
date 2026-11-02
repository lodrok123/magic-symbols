class_name PanelLuz3D
extends CanvasLayer

## PANEL DE LUZ DEL MAPA (2/11, «Juego 2/11»). Se abre con F3 en los mapas exteriores (lo monta PruebaTest2 si tiene sol) y deja afinar EN CALIENTE el ciclo de día y noche (CicloDia3D)
## y las sombras del sol (LuzZona3D), para revisar con ventana cómo se ve cada hora. Es depuración: no guarda nada; P imprime los valores para copiarlos al código.
##
## Teclas (solo con el panel visible, en `_input` para que ni la maqueta ni la jugadora las vean): ↑↓ elegir fila (con vuelta), ←→ cambiar (Shift = ×10), Backspace restaurar todo
## a lo que había al montar el panel, P imprime `texto_valores()`. F3 abre y cierra, pero lo maneja la maqueta (`alternar`): aquí NO se consume.
## Cada fila lee y escribe en una clase según `CLASE_DE`: «ciclo» (CicloDia3D), «zona» (LuzZona3D), «sol» (la DirectionalLight3D de la maqueta) o «hierba» (Hierba3D.RECIBE_SOMBRA;
## al escribir llama a `poner_recibe_sombra` de la hierba de la maqueta, `_hierba`, para que se vea en caliente).
## Contraste de sombra: HIERBA_SOMBRA sí · AMBIENTE_FACTOR 0,5 · SOL_FACTOR 1,3 · SOMBRA_BLUR 0,5

## [nombre, paso, mínimo, máximo]. Las filas bool van de 0 a 1 (≥ 0,5 = sí).
const FILAS: Array = [
	["HORA", 0.25, 0.0, 24.0],
	["DURACION_DIA_S", 30.0, 0.0, 3600.0],
	["CICLO_ACTIVO", 1.0, 0.0, 1.0],
	["SOMBRAS", 1.0, 0.0, 1.0],
	["SOMBRA_OPACIDAD", 0.05, 0.0, 1.0],
	["SOMBRA_BLUR", 0.1, 0.0, 5.0],
	["SOMBRA_DISTANCIA", 5.0, 10.0, 200.0],
	["SOL_INCLINACION_EXTRA", 2.0, -40.0, 40.0],
	["SOL_FACTOR", 0.05, 0.2, 3.0],
	["AMBIENTE_FACTOR", 0.05, 0.0, 2.0],
	["HIERBA_SOMBRA", 1.0, 0.0, 1.0],
	["ELEVACION_MIN", 0.05, 0.0, 1.0],
	["GIRO_POR_HORA", 1.0, 0.0, 30.0],
	["NOCHE_SOL_ENERGIA", 0.02, 0.0, 1.0],
	["NOCHE_AMBIENTE_ENERGIA", 0.02, 0.0, 1.0],
	["AMANECER_SOL_ENERGIA", 0.05, 0.0, 1.5],
	["AMANECER_AMBIENTE_ENERGIA", 0.05, 0.0, 1.5],
	["ATARDECER_SOL_ENERGIA", 0.05, 0.0, 1.5],
	["ATARDECER_AMBIENTE_ENERGIA", 0.05, 0.0, 1.5],
	["NIEBLA_NOCHE_MAS", 0.1, 0.0, 3.0],
	["LUNA_ENERGIA", 0.02, 0.0, 1.0],
	["LUNA_ACTIVA", 1.0, 0.0, 1.0],
]
const CLASE_DE: Dictionary = {
	"HORA": "ciclo", "DURACION_DIA_S": "ciclo", "CICLO_ACTIVO": "ciclo", "SOMBRAS": "sol",
	"SOMBRA_OPACIDAD": "zona", "SOMBRA_BLUR": "zona", "SOMBRA_DISTANCIA": "zona", "SOL_INCLINACION_EXTRA": "zona",
	"SOL_FACTOR": "zona", "AMBIENTE_FACTOR": "zona", "HIERBA_SOMBRA": "hierba",
	"ELEVACION_MIN": "ciclo", "GIRO_POR_HORA": "ciclo",
	"NOCHE_SOL_ENERGIA": "ciclo", "NOCHE_AMBIENTE_ENERGIA": "ciclo", "AMANECER_SOL_ENERGIA": "ciclo", "AMANECER_AMBIENTE_ENERGIA": "ciclo",
	"ATARDECER_SOL_ENERGIA": "ciclo", "ATARDECER_AMBIENTE_ENERGIA": "ciclo", "NIEBLA_NOCHE_MAS": "ciclo", "LUNA_ENERGIA": "ciclo", "LUNA_ACTIVA": "ciclo",
}
const ESC_CICLO: GDScript = preload("res://presentacion/ciclo_dia_3d.gd")
const ESC_ZONA: GDScript = preload("res://presentacion/luz_zona_3d.gd")
const BOOLEANAS: PackedStringArray = ["CICLO_ACTIVO", "SOMBRAS", "LUNA_ACTIVA", "HIERBA_SOMBRA"]

var seleccion: int = 0
var _m: Node3D = null
var _sol: DirectionalLight3D = null
var _originales: Dictionary = {}
var _panel: PanelContainer = null
var _texto: Label = null
var _aviso_reloj: bool = false


## Monta el panel (oculto) en la maqueta. `maqueta._sol` es el DirectionalLight3D. Idempotente.
static func montar(maqueta: Node3D) -> PanelLuz3D:
	if maqueta == null:
		return null
	var previo: Node = maqueta.get_node_or_null("PanelLuz3D")
	if previo is PanelLuz3D:
		return previo as PanelLuz3D
	var p := PanelLuz3D.new()
	p.name = "PanelLuz3D"
	p._m = maqueta
	p._sol = maqueta.get("_sol") as DirectionalLight3D
	maqueta.add_child(p)
	return p


func _init() -> void:
	layer = 90
	visible = false


func _ready() -> void:
	for f in FILAS:
		_originales[String(f[0])] = valor(String(f[0]))
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -12.0
	_panel.offset_right = -12.0
	_panel.offset_top = 12.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.05, 0.08, 0.82)
	estilo.set_content_margin_all(10.0)
	estilo.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", estilo)
	_texto = Label.new()
	_texto.add_theme_font_override("font", _fuente_mono())
	_texto.add_theme_font_size_override("font_size", 13)
	_texto.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_texto)
	add_child(_panel)
	set_process(true)
	_refrescar()


func _fuente_mono() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	return f


## F3 (lo llama la maqueta): muestra u oculta.
func alternar() -> void:
	visible = not visible
	if visible:
		_refrescar()


func _ciclo() -> CicloDia3D:
	return _m.get_node_or_null("CicloDia3D") as CicloDia3D if _m != null else null


func es_booleana(nombre: String) -> bool:
	return BOOLEANAS.has(nombre)


func _fila_de(nombre: String) -> Array:
	for f in FILAS:
		if String(f[0]) == nombre:
			return f
	return []


## El valor de una fila como número (bool: 0 o 1). 0 si no se puede leer.
func valor(nombre: String) -> float:
	match String(CLASE_DE.get(nombre, "")):
		"ciclo":
			var v: Variant = ESC_CICLO.get(nombre)
			return (1.0 if bool(v) else 0.0) if es_booleana(nombre) else float(v)
		"zona":
			return float(ESC_ZONA.get(nombre))
		"hierba":
			return 1.0 if Hierba3D.RECIBE_SOMBRA else 0.0
		"sol":
			if _sol != null and is_instance_valid(_sol):
				return 1.0 if _sol.shadow_enabled else 0.0
	return 0.0


## Escribe una fila (acotada a su mínimo y máximo; bool: v ≥ 0,5) y aplica lo que haga falta.
func poner(nombre: String, v: float) -> void:
	var f: Array = _fila_de(nombre)
	if f.is_empty():
		return
	var x: float = clampf(v, float(f[2]), float(f[3]))
	match String(CLASE_DE.get(nombre, "")):
		"ciclo":
			ESC_CICLO.set(nombre, (x >= 0.5) if es_booleana(nombre) else x)
		"zona":
			ESC_ZONA.set(nombre, x)
		"hierba":
			_poner_hierba(x >= 0.5)
		"sol":
			if _sol != null and is_instance_valid(_sol):
				_sol.shadow_enabled = x >= 0.5
	_aviso_reloj = nombre == "HORA" and CicloDia3D.DURACION_DIA_S > 0.0
	_aplicar_sin_ciclo()
	_refrescar()


## HIERBA_SOMBRA: por la hierba de la maqueta si la hay (reescribe sus shaders); si no, solo la variable estática.
func _poner_hierba(v: bool) -> void:
	var h: Variant = _m.get("_hierba") if _m != null else null
	if h is Hierba3D and is_instance_valid(h):
		(h as Hierba3D).poner_recibe_sombra(v)
	else:
		Hierba3D.RECIBE_SOMBRA = v


## Mueve la fila `i` `pasos` pasos (negativo = abajo). Las bool se invierten con cualquier paso.
func cambiar(i: int, pasos: int) -> void:
	var f: Array = FILAS[posmod(i, FILAS.size())]
	var n: String = String(f[0])
	if es_booleana(n):
		poner(n, 0.0 if valor(n) >= 0.5 else 1.0)
		return
	poner(n, snappedf(valor(n) + float(f[1]) * float(pasos), float(f[1]) * 0.01))


## Devuelve TODAS las filas a lo que valían al montar el panel.
func restaurar() -> void:
	for n in _originales:
		var x: float = float(_originales[n])
		match String(CLASE_DE.get(n, "")):
			"ciclo":
				ESC_CICLO.set(n, (x >= 0.5) if es_booleana(String(n)) else x)
			"zona":
				ESC_ZONA.set(n, x)
			"hierba":
				_poner_hierba(x >= 0.5)
			"sol":
				if _sol != null and is_instance_valid(_sol):
					_sol.shadow_enabled = x >= 0.5
	_aviso_reloj = false
	_aplicar_sin_ciclo()
	_refrescar()


## Una línea por fila, `NOMBRE = valor`, para copiar al código.
func texto_valores() -> String:
	var lineas: PackedStringArray = []
	for f in FILAS:
		var n: String = String(f[0])
		lineas.append("%s = %s" % [n, ("true" if valor(n) >= 0.5 else "false") if es_booleana(n) else "%.3f" % valor(n)])
	return "\n".join(lineas)


## Sin ciclo en el mapa nadie reaplica la luz cada fotograma: se hace aquí.
func _aplicar_sin_ciclo() -> void:
	if _ciclo() != null or _m == null:
		return
	var env: Environment = _m.get("_env") as Environment
	LuzZona3D.aplicar(env, _sol, String(_m.get("zona_luz")))


func _input(ev: InputEvent) -> void:
	if not visible or not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed:
		return
	var pasos: int = 10 if k.shift_pressed else 1
	match k.keycode:
		KEY_UP:
			seleccion = posmod(seleccion - 1, FILAS.size())
		KEY_DOWN:
			seleccion = posmod(seleccion + 1, FILAS.size())
		KEY_LEFT:
			cambiar(seleccion, -pasos)
		KEY_RIGHT:
			cambiar(seleccion, pasos)
		KEY_BACKSPACE:
			if k.echo:
				return
			restaurar()
		KEY_P:
			if k.echo:
				return
			print("PanelLuz3D:\n" + texto_valores())
		_:
			return                                      # F3 y el resto: los maneja la maqueta
	get_viewport().set_input_as_handled()
	_refrescar()


func _process(_delta: float) -> void:
	if visible:
		_refrescar()


func _refrescar() -> void:
	if _texto == null:
		return
	var l: PackedStringArray = []
	l.append("LUZ (F3)  ↑↓ fila  ←→ valor  Shift ×10  Backspace restaurar  P imprimir")
	if _ciclo() == null:
		l.append("sin ciclo en este mapa")
	if _aviso_reloj and CicloDia3D.DURACION_DIA_S > 0.0:
		l.append("reloj en marcha (DURACION_DIA_S > 0)")
	var h: float = fposmod(CicloDia3D.HORA, 24.0)
	l.append("hora actual %02d:%02d" % [int(h), int(fposmod(h, 1.0) * 60.0)])
	for i in range(FILAS.size()):
		var n: String = String(FILAS[i][0])
		var v: float = valor(n)
		var s: String = ("sí" if v >= 0.5 else "no") if es_booleana(n) else "%.2f" % v
		l.append("%s %-28s %s" % [">" if i == seleccion else " ", n, s])
	_texto.text = "\n".join(l)
