extends Node3D

## LABORATORIO DE LAS FASES DEL FUEGO (Pipeline, 20/10, entrada 217): carga (chispas que se aglutinan + sonido), impacto (explosión) y fin (se agota sin chocar), con TODAS las
## variables de `FasesFuego3D` como sliders EN VIVO. Es el sitio donde se ajusta; lo que dejes y guardes (G) es lo que saldrá en el mapa.
## Usa lo MISMO que el juego: `ConjuroVfx3D` (carga y disparo, escucha `conjuro_fase`) y `VfxElemento3D` (el proyectil, que pide el impacto o el fin al pararse), con un lanzador
## de mentira y un `HechizoVivo` que se mueve a mano. Nada de lo que se ve aquí está dibujado aparte.
## Teclas:  C = empezar a cargar (se queda cargando, aglutinando)   Espacio = soltar: el proyectil sale hacia el muñeco y EXPLOTA al chocar
##          A = soltar al aire: se agota sin chocar (FIN)    F = secuencia completa (carga 1,5 s → suelta → choca)    I / O = impacto / fin directos, sin lanzar
##          [ ] = tamaño del hechizo (semieje)    T = cámara lenta (¼)    G = guardar los sliders (user://fases_fuego.json)    P = imprimir lo tocado    R = restaurar todo
##          rueda: zoom · Esc: salir.  Al mover un slider se repite solo lo último que hiciste (carga, impacto o fin), para ver el efecto del cambio al momento.
const MANO: Vector3 = Vector3(-4.0, 1.3, 0.0)
const MUNECO: Vector3 = Vector3(4.0, 0.0, 0.0)
const CASILLA: float = 2.3
const VEL_U: float = 1.7 * CASILLA

## Un lanzador de mentira: las señales y los métodos que `ConjuroVfx3D` y `VfxElemento3D` esperan del `Lanzador3D`.
class Lanz:
	extends Node
	signal conjuro_fase(fase: String, elemento: String, posicion: Vector3)
	signal hechizo_v2(estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary)
	signal vfx_hechizo(nombre: String, posicion: Vector3, elemento: String)
	var fx: Vfx3D = null
	func tiempos_conjuro(_elemento: String) -> Array:
		return [0.1, 0.25, 0.1]
	func origen_conjuro(_elemento: String) -> Dictionary:
		return {"origen": "mano_libre"}

var lanz: Lanz = null
var conjuro: ConjuroVfx3D = null
var vfx: VfxElemento3D = null
var semieje: float = 0.25
var cargando: bool = false
var _ultima: Callable = Callable()
var _cam: Camera3D = null
var _zoom: float = 11.0
var _hud: Label = null
var _lento: bool = false
var _hv: HechizoVivo = null
var _destino: Vector3 = Vector3.ZERO
var _motivo: String = "golpe"
var _vol: Dictionary = {}                    ## clave -> [HSlider, Label]
var _reintento: float = -1.0                 ## cuenta atrás (s) para repetir lo último tras mover un slider (así no se repite a cada píxel)


func _ready() -> void:
	FasesFuego3D.persistir = true
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 30)
	suelo.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.30, 0.38, 0.22)
	suelo.material_override = ms
	add_child(suelo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.light_energy = 0.45
	add_child(sol)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.36, 0.42)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_figura("Mago", Vector3(-4.6, 0.0, 0.0), Color(0.7, 0.7, 0.75))
	_figura("Muneco", MUNECO, Color(0.75, 0.7, 0.68))
	_cam = Camera3D.new()
	_cam.far = 200.0
	add_child(_cam)
	_cam.current = true
	_colocar_camara()
	lanz = Lanz.new()
	lanz.name = "LanzFalso"
	add_child(lanz)
	lanz.fx = Vfx3D.new()
	add_child(lanz.fx)
	conjuro = ConjuroVfx3D.conectar(lanz, self)
	vfx = VfxElemento3D.conectar(lanz, self)
	var estado: VfxEstado3D = VfxEstado3D.conectar(lanz, self)
	estado.encendido = false
	_montar_ui()
	_refrescar()


func _figura(nombre: String, pos: Vector3, color: Color) -> void:
	var cuerpo := MeshInstance3D.new()
	cuerpo.name = nombre
	var c := CapsuleMesh.new()
	c.radius = 0.35
	c.height = 1.8
	cuerpo.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	cuerpo.material_override = m
	cuerpo.position = pos + Vector3(0.0, 0.9, 0.0)
	add_child(cuerpo)


func _colocar_camara() -> void:
	# La del juego: ortogonal, inclinada 60°, mirando al punto medio.
	var e: float = deg_to_rad(90.0 - 60.0)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = _zoom
	var foco: Vector3 = Vector3(3.0, 0.8, 0.0)         # desplazado a la derecha: la escena queda a la izquierda del panel de sliders
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 40.0)


## --- Acciones (públicas: las usan también la prueba y la captura) ---

func carga() -> void:
	_ultima = carga
	_limpiar()
	cargando = true
	lanz.conjuro_fase.emit("runa", "fuego", MANO)
	lanz.conjuro_fase.emit("voluta", "fuego", MANO + Vector3(0.0, 0.5, -0.4))
	lanz.conjuro_fase.emit("forma", "fuego", MANO)


## Suelta: si se estaba cargando, sale el destello y el proyectil. `al_aire` = no hay nada que lo pare (se agota por alcance).
func soltar(al_aire: bool = false) -> void:
	_ultima = soltar.bind(al_aire)
	if not cargando:
		carga()
	cargando = false
	lanz.conjuro_fase.emit("disparo", "fuego", MANO)
	_lanzar_proyectil(al_aire)


func secuencia() -> void:
	_ultima = secuencia
	carga()
	await get_tree().create_timer(1.5, true, false, true).timeout
	if cargando:
		soltar(false)
		_ultima = secuencia


func impacto_directo() -> void:
	_ultima = impacto_directo
	FasesFuego3D.impacto(self, MUNECO + Vector3(0.0, 1.0, 0.0), clampf(semieje * CASILLA / 0.45, 0.6, 8.0), 0.0)


func fin_directo() -> void:
	_ultima = fin_directo
	FasesFuego3D.desvanecer(self, Vector3(0.0, 1.3, 0.0), clampf(semieje * CASILLA / 0.45, 0.6, 8.0))


func _limpiar() -> void:
	if conjuro != null:
		conjuro.limpiar()
	if _hv != null and is_instance_valid(_hv):
		_hv.queue_free()
	_hv = null


func _lanzar_proyectil(al_aire: bool) -> void:
	var hv := HechizoVivo.new()
	hv.h = Hechizo.new()
	hv.h.velocidad = 1.7
	hv.h.semieje_x = semieje
	hv.h.semieje_z = semieje
	hv.estado = "plasma"
	hv.elemento = "fuego"
	hv.activo = true
	hv.proyectil = true
	hv.v = Vector3(VEL_U, 0.0, 0.0)
	lanz.add_child(hv)
	hv.set_physics_process(false)
	hv.global_position = MANO
	_hv = hv
	_destino = Vector3(MUNECO.x - 0.4, MANO.y, 0.0) if not al_aire else Vector3(MANO.x + 7.0, MANO.y, 0.0)
	_motivo = "alcance" if al_aire else "golpe"


func _process(delta: float) -> void:
	if _hv != null and is_instance_valid(_hv) and _hv.activo:
		var falta: float = _destino.x - _hv.global_position.x
		var paso: float = VEL_U * delta
		if falta <= paso:
			_hv.global_position = _destino
			_hv.motivo_fin = _motivo
			_hv.activo = false                    # el seguidor lo ve en su siguiente `_process` y pide el impacto o el fin
			# Se queda 0,8 s colgado (la `permanencia` de una flecha) y luego se va.
			get_tree().create_timer(0.8, true, false, true).timeout.connect(_liberar.bind(weakref(_hv)))
		else:
			_hv.global_position += Vector3(paso, 0.0, 0.0)
	if _reintento >= 0.0:
		_reintento -= delta / maxf(Engine.time_scale, 0.01)
		if _reintento < 0.0 and _ultima.is_valid():
			_ultima.call()


func _liberar(ref: WeakRef) -> void:
	var n: Object = ref.get_ref()
	if n != null and is_instance_valid(n):
		(n as Node).queue_free()


## --- Interfaz ---

func _montar_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	_hud = Label.new()
	_hud.position = Vector2(14, 10)
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 6)
	_hud.add_theme_font_size_override("font_size", 14)
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.custom_minimum_size = Vector2(840, 0)
	cl.add_child(_hud)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -366.0
	panel.offset_right = -6.0
	panel.offset_top = 6.0
	panel.offset_bottom = -6.0
	cl.add_child(panel)
	var sc := ScrollContainer.new()
	panel.add_child(sc)
	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(336, 0)
	sc.add_child(caja)
	var grupo_ant: String = ""
	for d in FasesFuego3D.DEF:
		var clave: String = String(d[0])
		var grupo: String = String(d[5])
		if grupo != grupo_ant:
			grupo_ant = grupo
			var t := Label.new()
			t.text = "— %s —" % grupo.to_upper()
			t.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
			caja.add_child(t)
		var fila := VBoxContainer.new()
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 12)
		fila.add_child(l)
		var s := HSlider.new()
		s.min_value = float(d[2])
		s.max_value = float(d[3])
		s.step = float(d[4])
		s.value = FasesFuego3D.v(clave)
		s.custom_minimum_size = Vector2(318, 16)
		s.value_changed.connect(_al_mover.bind(clave))
		fila.add_child(s)
		caja.add_child(fila)
		_vol[clave] = [s, l]
		_etiqueta(clave)


func _etiqueta(clave: String) -> void:
	var par: Array = _vol[clave]
	var texto: String = ""
	for d in FasesFuego3D.DEF:
		if String(d[0]) == clave:
			texto = String(d[6])
	var marca: String = " ●" if not is_equal_approx(FasesFuego3D.v(clave), FasesFuego3D.defecto(clave)) else ""
	(par[1] as Label).text = "%s = %s%s   · %s" % [clave, str(snappedf(FasesFuego3D.v(clave), 0.001)), marca, texto]


func _al_mover(valor: float, clave: String) -> void:
	FasesFuego3D.poner(clave, valor)
	_etiqueta(clave)
	_reintento = 0.35
	_refrescar()


func _refrescar() -> void:
	var tocadas: int = FasesFuego3D.tocadas().size()
	if _hud != null:
		_hud.text = "C cargar · Espacio soltar (choca) · A soltar al aire (se agota) · F secuencia · I impacto · O fin · [ ] tamaño %.2f m · T lento: %s · G guardar · P imprimir · R restaurar\n%d variable(s) tocada(s) (●)  ·  cargando: %s  ·  al mover un slider se repite lo último" % [
			semieje, "sí" if _lento else "no", tocadas, "sí" if cargando else "no"]


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_C:
				carga()
			KEY_SPACE:
				soltar(false)
			KEY_A:
				soltar(true)
			KEY_F:
				secuencia()
			KEY_I:
				impacto_directo()
			KEY_O:
				fin_directo()
			KEY_BRACKETLEFT:
				semieje = maxf(0.1, semieje - 0.05)
			KEY_BRACKETRIGHT:
				semieje = minf(1.5, semieje + 0.05)
			KEY_T:
				_lento = not _lento
				Engine.time_scale = 0.25 if _lento else 1.0
			KEY_G:
				print("[LabFasesFuego] guardado: %s" % str(FasesFuego3D.guardar()))
			KEY_P:
				print("[LabFasesFuego] tocadas: ", FasesFuego3D.tocadas())
			KEY_R:
				FasesFuego3D.restaurar()
				for k in _vol:
					((_vol[k] as Array)[0] as HSlider).set_value_no_signal(FasesFuego3D.v(String(k)))
					_etiqueta(String(k))
			KEY_ESCAPE:
				Engine.time_scale = 1.0
				get_tree().quit()
		_refrescar()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(4.0, _zoom * 0.9)
			_colocar_camara()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(30.0, _zoom * 1.1)
			_colocar_camara()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
