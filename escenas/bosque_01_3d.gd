extends Node

## REGLAS DEL NIVEL «BOSQUE 01» (Juego, 16/10). El siguiente nivel tras Terra Fina; sale de la hoja `Nivel_Bosque_01.xlsx`.
## Mapa: mundo/datos_nivel/mapas/Bosque_01.txt · Nivel editable: mundo/datos_nivel/Nivel_Bosque_01.tscn · Escena: escenas/PruebaBosque01.tscn.
## Se generan con tools/hoja_a_nivel.py; a partir de ahí Pablo edita el .tscn en Godot y este archivo solo lee CASILLAS.
##
## POR QUÉ ES UN NODO HIJO («Reglas») y no `reglas = "bosque"`: PruebaTest2 elige las reglas por cadena fija (Pipeline) y `bosque` es
## Bosque3D, el nivel anterior. Mismo patrón que TerraFina3D: `_ready` espera un fotograma (`call_deferred`) y ya está el mundo montado.
## Los puzles de agua (la losa que sube el estanque) NO están aquí: son líneas `; pieza` / `; puzle` del .txt que lee Puzle3D («Puzles»).
##
## EL NIVEL, de sur a norte (las casillas son las del mapa horneado, con el borde de árboles; el rótulo es el de la hoja):
##   · Zona de inicio (oeste, S): dos goblins guerreros (GG). Al caer los dos aparece el COFRE C_1 (campamento NE) con el glifo de barrera.
##   · El TRONCO-PUENTE (marcador de datos `tronco_puente`, orilla este del río, con enredaderas): al recibir fuego cae SIEMPRE hacia delante
##     (eje X local del marcador) sobre el río y queda de puente. Lo hace TroncoPuente3D.
##   · El prado, con el estanque vacío en medio (T_C → Puzle3D) y el alquimista (ALC). Tres TÓTEMS DE FUEGO, cada uno con su criterio:
##       TF_1 (zona de hierba alta, sur) → que el FUEGO SE PROPAGUE a su lado (una casilla vecina ardiendo).
##       TF_2 (norte)                    → las DOS antorchas de su lado (V14, W14) encendidas a la vez.
##       TF_3 (oeste del prado este)     → las cuatro antorchas T_1..T_4 encendidas EN ORDEN (si te equivocas, se apagan todas).
##   · La PUERTA P_1 (X) se abre con los tres tótems. Detrás, el elemental del bosque (E_B); al caer aparece el COFRE C_2 = fin de la demo.
##
##   · El estanque: el TRONCO (marcador `tronco_estanque`, T19) está al fondo del cauce vacío; al llenarse de agua (la losa T_C) SUBE hasta quedar
##     a ras y el paso se abre (TroncoEstanque3D). Con el agua, el resto de la columna del cauce deja de pisarse: el único paso es el tronco.
##   · Los LOBERNOS (marcadores `loberno`, M19 y M23) usan el modelo aprobado `loberno.glb`; combaten como los goblins (Combate3D genérico).
##
## PROVISIONAL (modelo): los dos troncos son cilindros (falta el modelo con su versión caída/hundida y las enredaderas).

const MISION: String = "bosque_01"
const OBJ_GOBLINS: int = 0
const OBJ_COFRE_1: int = 1
const OBJ_TOTEMS: int = 2
const OBJ_PUERTA: int = 3
const OBJ_ELEMENTAL: int = 4
const OBJ_COFRE_2: int = 5

## Casillas del mapa horneado (columna, fila). Cambian solo si se mueven en el editor: son lo único que este archivo conoce del dibujo.
const TOTEM_PROPAGACION: Vector2i = Vector2i(18, 25)        ## TF_1
const TOTEM_ANTORCHAS: Vector2i = Vector2i(19, 8)           ## TF_2
const TOTEM_SECUENCIA: Vector2i = Vector2i(17, 19)          ## TF_3
const ANTORCHAS_DEL_TOTEM_2: Array = [Vector2i(18, 9), Vector2i(19, 9)]      ## V14, W14
## T_1..T_4 en el orden correcto (W18, U21, U16, W22 de la hoja).
const SECUENCIA: Array = [Vector2i(19, 13), Vector2i(17, 16), Vector2i(17, 11), Vector2i(19, 17)]
const ID_LOBERNO: String = "loberno"
## Casillas del cauce que dejan de pisarse al llenarse el estanque (la columna oeste, menos la del tronco). Por qué solo estas: el brazo de
## arriba (fila 10) lleva a la losa T_C y tiene que seguir libre. Si el diseño quiere cortar otra parte, es esta lista.
const COLUMNA_ESTANQUE: Array = [Vector2i(16, 11), Vector2i(16, 12), Vector2i(16, 13), Vector2i(16, 15), Vector2i(16, 16),
		Vector2i(16, 17), Vector2i(16, 18), Vector2i(16, 19), Vector2i(16, 20)]

const FASE_ARDIENDO: int = 3             ## PruebaTest2.Fase.ARDIENDO (la maqueta no tiene class_name; 4 = CENIZAS, también cuenta)
const T_SONDEO: float = 0.1              ## s entre comprobaciones (los criterios no necesitan 60 Hz)
const ALCANCE_E: float = 2.7             ## unidades: hablar con el alquimista y abrir cofres (la casilla mide 2,3)
const COLOR_FUEGO: Color = Color(1.0, 0.45, 0.15)
const COLOR_APAGADO: Color = Color(0.42, 0.42, 0.48)
const COFRE_ESCENA: String = "res://arte/piezas/cofre.tscn"

const DIALOGO_ALQUIMISTA: Array = [
	"Una muestra gratis, que luego no digas. Bébela cuando duela (Q).",
	"Cuatro antorchas del prado de este lado. El orden importa: la del medio, la de abajo, la de arriba y, por último, la de abajo a la derecha.",
	"Un fallo y se apagan todas. A mí ya me ha pasado. Dos veces.",
	"Al tótem del sur no se le enciende con un hechizo: lo despierta el fuego que se contagia. La hierba alta ayuda.",
]

var m: Variant = null                       ## la maqueta (PruebaTest2); sin tipo: se le llaman métodos suyos
var _jug: Jugador3D = null
var _aviso: Label = null
var _t_aviso: float = 0.0
var _acum: float = 0.0
var _totems: Dictionary = {}                ## Vector2i -> Reactivo3D (los tres tótems)
var _sec: Array = []                        ## Reactivo3D de las cuatro antorchas, en orden
var _sec_prev: Array = [false, false, false, false]
var _sec_sig: int = 0                       ## cuántas llevas bien
var _sec_hecha: bool = false
var _antorchas2: Array = []
var _goblins: Array = []                    ## Combate3D del cofre 1
var _lobernos: Array = []                   ## Pj3D de los lobernos (el modelo; su Combate3D cuelga de la maqueta)
var _tronco_puente: TroncoPuente3D = null
var _tronco_estanque: TroncoEstanque3D = null
var _columna_cortada: bool = false
var _elementales: Array = []
var _celda_puerta: Vector2i = Vector2i(-1, -1)
var _puerta: MeshInstance3D = null
var _lamparas: Array = []
var _puerta_abierta: bool = false
var _celdas_cofre: Array = []               ## [C_1, C_2] (de arriba abajo en el mapa)
var _entregado: Array = [false, false]      ## el botín de cada cofre se da UNA vez, abra como abra
var _cofres: Array = [null, null]           ## Node3D de cada cofre cuando ya ha aparecido
var _npc: Pj3D = null
var _lineas: int = 0
var _muestra_dada: bool = false
var _hablando: Pj3D = null
var _t_habla: float = 0.0
var _terminado: bool = false


func _ready() -> void:
	# El padre aún no ha hecho su _ready: se espera a que termine (call_deferred corre al final del fotograma).
	call_deferred("_arrancar")


func _arrancar() -> void:
	if get_parent() != null:
		iniciar(get_parent())


## Entrada pública: `mundo` es la maqueta ya montada.
func iniciar(mundo: Variant) -> void:
	m = mundo
	for n in (m as Node).get_children():
		if n is Jugador3D:
			_jug = n
	var mapa: PackedStringArray = m.get("_mapa")
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			match mapa[y][x]:
				"X":
					_celda_puerta = Vector2i(x, y)
				"Z":
					_celdas_cofre.append(Vector2i(x, y))     # se recorre de arriba abajo: C_1 (campamento) antes que C_2 (este)
	# Tótems y antorchas: los reactivos que puso la maqueta. Los tótems salen de la capa de hechizos: no se encienden «a pelo».
	var por_celda: Dictionary = {}
	for r in (m.get("_reactivos") as Array):
		if is_instance_valid(r):
			por_celda[r.celda] = r
	for c in [TOTEM_PROPAGACION, TOTEM_ANTORCHAS, TOTEM_SECUENCIA]:
		var t: Variant = por_celda.get(c)
		if t != null and t.tipo == "totem":
			_totems[c] = t
			(t as CollisionObject3D).collision_layer = 0
	for c in ANTORCHAS_DEL_TOTEM_2:
		if por_celda.has(c):
			_antorchas2.append(por_celda[c])
	for c in SECUENCIA:
		if por_celda.has(c):
			_sec.append(por_celda[c])
	_clasificar_combates()
	_montar_troncos_y_lobernos()
	_buscar_alquimista()
	if _celda_puerta.x >= 0:
		_montar_puerta()
	_montar_aviso()
	var objetivos: Array = [
		"Derrotar a los goblins del camino (0/%d)" % _goblins.size(), "Abrir el cofre del campamento",
		"Activar los tres tótems de fuego (0/3)", "Abrir la puerta de los tótems", "Derrotar al elemental del bosque", "Abrir el cofre final"]
	Misiones.i().definir({"id": MISION, "titulo": "El Bosque (1.ª parte)", "tipo": "principal",
		"texto": "Tres tótems de fuego, cada uno con su manera de despertar, abren la puerta del fondo. Detrás espera el elemental del bosque.",
		"origen": "Bosque 01", "objetivos": objetivos})
	Misiones.i().activar(MISION)
	if _goblins.is_empty():
		Misiones.i().objetivo_hecho(MISION, OBJ_GOBLINS)
	set_process(true)


## Los goblins guerreros del nivel dan el cofre 1; el elemental, el cofre 2. Los lobernos se crean después, así que no cuentan aquí.
func _clasificar_combates() -> void:
	for n in get_tree().get_nodes_in_group("combate3d"):
		var cb: Combate3D = n as Combate3D
		if cb == null:
			continue
		if cb.elemental:
			_elementales.append(cb)
		elif not cb.arquero:
			_goblins.append(cb)


## Lee los marcadores de datos del nivel (`tronco_puente`, `tronco_estanque`, `loberno`) y crea lo que piden. Sin marcador no hace nada:
## así un Nivel_Bosque_01.tscn editado a mano sin ellos sigue arrancando.
func _montar_troncos_y_lobernos() -> void:
	for mc in (m._marcas as Array):
		var d: Dictionary = mc
		var c: Vector2i = d["c"]
		match String(d["grupo"]):
			"tronco_puente":
				# El giro del marcador (grados, sentido de las agujas hacia +Z como en el resto de marcadores) fija hacia dónde cae: su +X local.
				var a: float = deg_to_rad(float(d["giro"]))
				var dir := Vector3(cos(a), 0.0, -sin(a))
				var celda_rio: Vector2i = c + Vector2i(roundi(dir.x), roundi(dir.z))
				var base: Vector3 = m.call("_centro_celda", c, m.ALTO)
				_tronco_puente = TroncoPuente3D.new()
				_tronco_puente.name = "TroncoPuente"
				m.add_child(_tronco_puente)
				_tronco_puente.preparar(m, base, dir, celda_rio)
			"tronco_estanque":
				_tronco_estanque = TroncoEstanque3D.new()
				_tronco_estanque.name = "TroncoEstanque"
				m.add_child(_tronco_estanque)
				_tronco_estanque.preparar(m, c)
			"loberno":
				_crear_loberno(c)


## Un loberno: el modelo (Pj3D) más su Combate3D, como lo hace Jugador3D con los de `_goblins` al montar. Si falta el GLB no sale y se avisa.
func _crear_loberno(c: Vector2i) -> void:
	var pj: Pj3D = m.call("_personaje", [ID_LOBERNO], m.call("_pos_marca", c, m.ALTO))
	if pj == null or _jug == null:
		push_warning("Bosque 01: no se pudo crear el loberno de %s (¿falta arte/modelos/loberno.glb?)" % str(c))
		return
	(m.get("_goblins") as Array).append(pj)
	_lobernos.append(pj)
	Combate3D.equipar(pj, m, _jug, _jug.lanz)


## El alquimista lo crea `poner_puesto` sin guardarlo (solo avisa a unas reglas registradas): se busca el Pj3D más cercano a su puesto.
func _buscar_alquimista() -> void:
	var mapa: PackedStringArray = m.get("_mapa")
	var cq: Vector2i = Vector2i(-1, -1)
	for y in range(mapa.size()):
		for x in range(mapa[y].length()):
			if mapa[y][x] == "Q":
				cq = Vector2i(x, y)
	if cq.x < 0:
		return
	var centro: Vector3 = m.call("_centro_celda", cq, 0.0)
	var goblins: Array = m.get("_goblins")
	var mejor: float = 4.0
	for n in (m as Node).find_children("*", "Pj3D", true, false):
		if n is Jugador3D or goblins.has(n):
			continue
		var d: Vector3 = (n as Pj3D).position - centro
		d.y = 0.0
		if d.length() < mejor:
			mejor = d.length()
			_npc = n as Pj3D


## La puerta: un tablón que cierra el paso de oeste a este y tres lámparas encima, una por tótem.
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
	_puerta.name = "puerta_totems"
	_puerta.mesh = caja
	_puerta.position = m.call("_centro_celda", _celda_puerta, alto + 1.15)
	(m.get("_props") as Node).add_child(_puerta)
	m.call("_bloquear", _celda_puerta)
	var base: Vector3 = m.call("_centro_celda", _celda_puerta, alto + 3.9)
	for i in range(3):
		var lamp: MeshInstance3D = Formas3D.instancia("llama", COLOR_APAGADO, 0.42)
		lamp.position = base + Vector3(0.0, 0.0, (float(i) - 1.0) * 0.6)
		(m.get("_props") as Node).add_child(lamp)
		_lamparas.append(lamp)


func _montar_aviso() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	_aviso = Label.new()
	_aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso.position = Vector2(-300.0, -120.0)
	_aviso.custom_minimum_size = Vector2(600.0, 0.0)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 22)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 8)
	capa.add_child(_aviso)


func _process(delta: float) -> void:
	if m == null or m.get("_jugador") == null:
		return
	_t_aviso = maxf(_t_aviso - delta, 0.0)
	if _t_aviso <= 0.0 and _aviso != null:
		_aviso.text = ""
	if _hablando != null:
		_t_habla -= delta
		if _t_habla <= 0.0:
			_hablando.animacion_actual = ""
			_hablando.jugar("idle")
			_hablando = null
	_acum += delta
	if _acum < T_SONDEO:
		return
	_acum = 0.0
	_criterio_propagacion()
	_criterio_antorchas()
	_criterio_secuencia()
	_revisar_totems_y_puerta()
	_revisar_combates()
	_revisar_estanque()


## Al llenarse el estanque, el resto de la columna del cauce deja de pisarse (el agua es profunda ahí) y solo queda el tronco como paso.
## `_bloquear` y no `_bloqueadas[c] = true`: el Lanzador se entera por ahí (ver prueba_test2.gd).
func _revisar_estanque() -> void:
	if _columna_cortada or _tronco_estanque == null:
		return
	var abiertas: bool = false
	for c in COLUMNA_ESTANQUE:
		if Terreno3D.cauces_abiertos.has(c):
			abiertas = true
			break
	if not abiertas:
		return
	_columna_cortada = true
	for c in COLUMNA_ESTANQUE:
		m.call("_bloquear", c)
	_decir("El estanque se llena. El tronco empieza a subir.", 4.0)


## TF_1: se despierta cuando el fuego se ha contagiado a su lado (la casilla del tótem o alguna vecina arde o ya es ceniza).
func _criterio_propagacion() -> void:
	var t: Variant = _totems.get(TOTEM_PROPAGACION)
	if t == null or bool(t.activo):
		return
	var hf: Dictionary = m.get("_hf")
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var q: Vector2i = TOTEM_PROPAGACION + Vector2i(dx, dy)
			if hf.has(q) and int((hf[q] as Dictionary)["fase"]) >= FASE_ARDIENDO:
				_activar(t)
				return


## TF_2: las dos antorchas de su lado arden a la vez.
func _criterio_antorchas() -> void:
	var t: Variant = _totems.get(TOTEM_ANTORCHAS)
	if t == null or bool(t.activo) or _antorchas2.is_empty():
		return
	for r in _antorchas2:
		if not is_instance_valid(r) or not bool(r.is_lit):
			return
	_activar(t)


## TF_3: T_1..T_4 en orden. Cada antorcha que se enciende se compara con la que tocaba; si no es esa, se apagan todas y se empieza de cero.
func _criterio_secuencia() -> void:
	var t: Variant = _totems.get(TOTEM_SECUENCIA)
	if t == null or _sec_hecha or _sec.size() != SECUENCIA.size():
		return
	var fallo: bool = false
	for i in range(_sec.size()):
		var r: Variant = _sec[i]
		var arde: bool = is_instance_valid(r) and bool(r.is_lit)
		if arde and not bool(_sec_prev[i]):
			if i == _sec_sig:
				_sec_sig += 1
			else:
				fallo = true
		_sec_prev[i] = arde
	if fallo:
		_sec_sig = 0
		for i in range(_sec.size()):
			if is_instance_valid(_sec[i]) and bool(_sec[i].is_lit):
				_sec[i].apagar_llama()
			_sec_prev[i] = false
		_decir("Orden equivocado: las antorchas se apagan.", 3.5)
	elif _sec_sig >= _sec.size():
		_sec_hecha = true
		_activar(t)


func _activar(t: Variant) -> void:
	# Mismo gesto que Bosque3D: el tótem de fuego solo reconoce un hechizo de fuego, así que se le da uno «de verdad».
	var r := RuneData.new()
	var tags: Array[String] = ["fuego", "calor"]
	r.tags = tags
	t.on_spell_hit(r, Vector3.ZERO)


func _revisar_totems_y_puerta() -> void:
	var n: int = 0
	for c in _totems:
		if bool(_totems[c].activo):
			n += 1
	Misiones.i().objetivo_texto(MISION, OBJ_TOTEMS, "Activar los tres tótems de fuego (%d/3)" % n)
	for i in range(mini(n, _lamparas.size())):
		_encender_lampara(i)
	if n >= _totems.size() and not _totems.is_empty():
		Misiones.i().objetivo_hecho(MISION, OBJ_TOTEMS)
		if not _puerta_abierta and _celda_puerta.x >= 0:
			_abrir_puerta()


func _encender_lampara(i: int) -> void:
	var lamp: MeshInstance3D = _lamparas[i]
	if lamp.has_meta("encendida"):
		return
	lamp.set_meta("encendida", true)
	lamp.set_surface_override_material(0, Formas3D.material_tinte(COLOR_FUEGO, false, "llama"))
	if m.get("_fx") != null:
		(m.get("_fx") as Vfx3D).chispazo(lamp.position, "fuego")
	_decir("Tótem activado (%d/3)" % _contar_lamparas(), 3.0)


func _contar_lamparas() -> int:
	var n: int = 0
	for l in _lamparas:
		if (l as Node).has_meta("encendida"):
			n += 1
	return n


func _abrir_puerta() -> void:
	_puerta_abierta = true
	Misiones.i().objetivo_hecho(MISION, OBJ_PUERTA)
	m.call("_liberar", _celda_puerta)
	_decir("¡La puerta se abre!", 4.0)
	if _puerta != null:
		var tw := create_tween()
		tw.tween_property(_puerta, "position:y", _puerta.position.y - 2.4, 1.4).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_puerta.hide)


## Goblins muertos → cofre 1; elemental muerto → cofre 2.
func _revisar_combates() -> void:
	var caidos: int = 0
	for g in _goblins:
		if not is_instance_valid(g) or bool(g.muerto):
			caidos += 1
	if not _goblins.is_empty():
		Misiones.i().objetivo_texto(MISION, OBJ_GOBLINS, "Derrotar a los goblins del camino (%d/%d)" % [caidos, _goblins.size()])
	if caidos >= _goblins.size() and _cofres[0] == null:
		Misiones.i().objetivo_hecho(MISION, OBJ_GOBLINS)
		_aparecer_cofre(0)
		_decir("Los goblins han caído. En el campamento, algo brilla.", 5.0)
	if _elementales.is_empty() or _cofres[1] != null:
		return
	for e in _elementales:
		if is_instance_valid(e) and not bool(e.muerto):
			return
	Misiones.i().objetivo_hecho(MISION, OBJ_ELEMENTAL)
	_aparecer_cofre(1)
	_decir("El elemental ha caído. Hay un cofre al fondo.", 5.0)


## El cofre aparece donde la hoja lo marca (letra `Z`), creciendo desde nada; bloquea su casilla.
func _aparecer_cofre(i: int) -> void:
	if i >= _celdas_cofre.size() or ResourceLoader.exists(COFRE_ESCENA) == false:
		return
	var c: Vector2i = _celdas_cofre[i]
	var nodo: Node3D = (load(COFRE_ESCENA) as PackedScene).instantiate() as Node3D
	nodo.name = "cofre_%d" % (i + 1)
	nodo.position = m.call("_centro_celda", c, float(m.get("ALTO")))
	(m.get("_props") as Node).add_child(nodo)
	nodo.scale = Vector3.ONE * 0.01
	create_tween().tween_property(nodo, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	m.call("_bloquear", c)
	_cofres[i] = nodo


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or m == null or m.get("_jugador") == null:
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or k.keycode != KEY_E:
		return
	var yo: Vector3 = (m.get("_jugador") as Pj3D).position
	# Cofres primero (si estás al lado de uno, abrirlo es lo que quieres), luego el alquimista.
	for i in range(_cofres.size()):
		var cf: Variant = _cofres[i]
		if cf != null and _lejos(cf.position, yo) <= ALCANCE_E:
			var ctrl: Cofre3D = Cofre3D.en(cf)
			if ctrl == null:
				_al_abrir_cofre(i)                     # el modelo no trae tapa que animar (arte sin importar): el botín se entrega igual
			elif not ctrl.esta_abierto() and ctrl.abrir():
				ctrl.abierto.connect(_al_abrir_cofre.bind(i), CONNECT_ONE_SHOT)
			return
	if _npc != null and _lejos(_npc.position, yo) <= ALCANCE_E:
		_hablar_alquimista(yo)


static func _lejos(a: Vector3, b: Vector3) -> float:
	var d: Vector3 = a - b
	d.y = 0.0
	return d.length()


func _al_abrir_cofre(i: int) -> void:
	if bool(_entregado[i]):
		return
	_entregado[i] = true
	if i == 0:
		Misiones.i().objetivo_hecho(MISION, OBJ_COFRE_1)
		if Repertoire.unlock_sigil("barrera"):
			_decir("Glifo de barrera conseguido: ya puedes dibujarlo.", 6.0)
		else:
			_decir("El cofre está vacío: la barrera ya era tuya.", 4.0)
	else:
		Misiones.i().objetivo_hecho(MISION, OBJ_COFRE_2)
		_terminado = true
		_decir("Fin de la demo. Gracias por jugar el Bosque.", 10.0)


func _hablar_alquimista(yo: Vector3) -> void:
	var texto: String = String(DIALOGO_ALQUIMISTA[_lineas % DIALOGO_ALQUIMISTA.size()])
	_lineas += 1
	if not _muestra_dada:
		if Estado.i().agregar("pocion", 1) > 0:
			_muestra_dada = true
		else:
			_lineas -= 1
			texto = "Tu bolsa no tiene hueco para la muestra. Vuelve con un sitio libre."
	_decir("Alquimista: «%s»" % texto, 6.0)
	_npc.mirar(yo - _npc.position, 1.0)
	_npc.jugar("talk")
	Sfx3D.play(_npc, "conversacion_voz")
	_hablando = _npc
	_t_habla = 2.5


func _decir(texto: String, seg: float) -> void:
	if _aviso != null:
		_aviso.text = texto
	_t_aviso = seg
