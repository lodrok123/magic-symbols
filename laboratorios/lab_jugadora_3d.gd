extends Node3D

## LABORATORIO DE LA JUGADORA NUEVA (24/10, Pablo: «veo la cabeza excesivamente desproporcionada frente al cuerpo… no veo las animaciones bien, veo movimientos raros»).
## Monta a `jugadora_base` EXACTAMENTE como el juego (la misma ruta que PruebaTest2._personaje: Pj3D.cargar → ropa por defecto, clips de la familia traducidos por
## ClipsFamilia, material de juguete y rim de jugadora) y deja mirar cada clip:
##  · Lista de TODOS los clips de su AnimationPlayer con los ROLES de Pj3D que los usan y su FUENTE (de qué modelo/clip sale la traducción). Clic o ↑/↓; en bucle.
##  · El MODELO FUENTE al lado (F), con el clip ORIGINAL en su propio esqueleto, para separar lo que viene del retarget de lo que ya traía el clip. La fuente de los clips
##    de Meshy (arte/meshy/jugadora_clips.glb) no tiene malla: se ve solo su esqueleto.
##  · Velocidad 1 · 0,5 · 0,25 · pausa (V), barra de fotograma, ←/→ paso a paso; cámaras 1 frente · 2 lado · 3 tres cuartos · 4 arriba · 5 «del juego»
##    (ortográfica inclinada 30°, tamaño 6,0 como PruebaTest2); esqueleto (S).
##  · ESCALA DE LA CABEZA (0,6–1,1 de 0,05 en 0,05; teclas - y +): el hueso Head, con la capucha pegada (va entera al hueso Head). Muestra las «alturas de cabeza»
##    (alto total / alto de la cabeza). Usa el mecanismo que ya existe, ProporcionChibi vía `Pj3D.set_proporcion` (los valores del juego están en `Pj3D.PROPORCIONES`; el lab arranca con el de jugadora_base): no escribe nada.
##  · Panel de medidas del clip visto: duración, fotogramas, y los 5 huesos con el mayor salto de giro entre claves consecutivas (nuevo y fuente).
## No modifica ningún archivo.
## Teclas: 1-5 cámara · Espacio pausa · V velocidad · ←/→ fotograma · ↑/↓ clip · F fuente · S esqueleto · M marcar cabeza · R ropa · P postura de la elfa · -/+ cabeza · H cabeza del juego · rueda zoom · arrastrar orbita
## Abrir: laboratorios/LabJugadora3D.tscn y F6.

const ID: String = "jugadora_base"
const ALTO_JUEGO: float = 1.0                    ## u de juego (ALTO_PJ de PruebaTest2)
const CABEZA_MIN: float = 0.6
const CABEZA_MAX: float = 1.1
const CABEZA_PASO: float = 0.05
const SEPARACION_FUENTE: float = 1.0             ## u a la derecha de la jugadora donde se pone el modelo fuente
const VELOCIDADES: Array = [["1", 1.0], ["0,5", 0.5], ["0,25", 0.25]]
const FPS_PASO: float = 30.0
const TAM_CAMARA_JUEGO: float = 6.0              ## PruebaTest2.ZOOM_INICIAL (ventana de altura 1, vertical)
const ELEVACION_JUEGO: float = 30.0              ## 90° − INCLINACION (60°) de PruebaTest2
const CENTRO_JUEGO: float = 0.85                 ## el foco del juego está a 0,85 del alto del personaje (PruebaTest2._centro)
const ANCHO_PANEL_IZQ: float = 470.0
const ANCHO_PANEL_DER: float = 350.0
const PEORES: int = 5
const PESO_CABEZA_MIN: float = 0.5               ## peso en Head para que un vértice cuente como «de la cabeza» al medirla
const COLOR_PIERNAS: Color = Color(0.35, 1.0, 0.45)
const COLOR_BRAZOS: Color = Color(0.35, 0.65, 1.0)
const COLOR_RESTO: Color = Color(0.95, 0.95, 0.95)
const COLOR_MARCA: Color = Color(1.0, 0.2, 0.9)
const COLOR_MARCA_2: Color = Color(1.0, 0.85, 0.1)
const NOMBRES_CAMARA: Array = ["frente", "lado", "tres_cuartos", "arriba", "juego"]

var _pj: Pj3D = null
var _sk: Skeleton3D = null
var _ap: AnimationPlayer = null
var _cam: Camera3D = null
var _im: ImmediateMesh = null
var _marcas: ImmediateMesh = null
var _fuentes: Array = []                       ## [{ruta, etiqueta, clips: {destino: origen}, nodo, sk, ap, malla: bool}] en el orden de ClipsFamilia.FUENTES
var _puesto_fuente: Node3D = null
var _clips: Array = []                         ## [{nombre, roles: Array[String], dur, fuente: {i, origen}}]
var _roles_sin_clip: PackedStringArray = PackedStringArray()
var _sel: int = -1
var _t: float = 0.0
var _vel: float = 1.0
var _pausa: bool = false
var _fuente_visible: bool = true
var _esqueleto: bool = false
var _marcar: bool = false
var _interfaz_visible: bool = true
var _ocupado: bool = false
var _cabeza: float = 1.0
var _cabeza_juego: float = 1.0
var _chin_sk: float = 0.0                      ## espacio del esqueleto: lo más bajo de la cabeza (vértices con peso en Head) y lo más alto, y el hueso Head
var _top_sk: float = 0.0
var _hy_sk: float = 0.0
var _esc_sk: float = 1.0                       ## espacio del esqueleto → unidades del modelo
var _alto_cabeza_raw: float = 0.0              ## alto de la cabeza (u del modelo) con escala 1
var _yaw: float = 0.7
var _pitch: float = 0.15
var _dist: float = 3.2
var _modo_juego: bool = false
var _tam_juego: float = TAM_CAMARA_JUEGO

var _caja_panel: PanelContainer = null
var _panel_der: PanelContainer = null
var _lista: ItemList = null
var _sl_tiempo: HSlider = null
var _sl_cabeza: HSlider = null
var _lbl_tiempo: Label = null
var _lbl_cabeza: Label = null
var _lbl_alturas: Label = null
var _txt: TextEdit = null
var _chk_fuente: CheckBox = null
var _chk_esq: CheckBox = null
var _chk_marca: CheckBox = null
var _chk_ropa: CheckBox = null
var _chk_postura: CheckBox = null
var _postura_elfa: bool = false
var _botones_vel: Array[Button] = []
var _capa: CanvasLayer = null


func _ready() -> void:
	_montar_escena()
	_montar_jugadora()
	_montar_fuentes()
	_montar_clips()
	_medir_cabeza()
	_montar_interfaz()
	_cabeza_juego = float((Pj3D.PROPORCIONES.get(ID, [1.0, 1.0, 1.0]) as Array)[0])
	_poner_cabeza(_cabeza_juego, true)
	_elegir_clip(_indice_de_rol("idle"))
	camara("tres_cuartos")


# ---------- escena ----------

func _montar_escena() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.light_energy = 1.1
	add_child(sol)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8.0, 8.0)
	suelo.mesh = pm
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment(){\n\tvec2 p = (UV - 0.5) * 8.0;\n\tvec2 g = abs(fract(p * 4.0 - 0.5) - 0.5) / fwidth(p * 4.0);\n\tfloat l = 1.0 - min(min(g.x, g.y), 1.0);\n\tfloat eje = step(abs(p.x), 0.004) + step(abs(p.y), 0.004);\n\tALBEDO = mix(vec3(0.16, 0.18, 0.21), vec3(0.32, 0.35, 0.4), l);\n\tALBEDO = mix(ALBEDO, vec3(0.8, 0.3, 0.3), clamp(eje, 0.0, 1.0) * 0.6);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	suelo.material_override = mat
	add_child(suelo)
	_cam = Camera3D.new()
	_cam.fov = 35.0
	add_child(_cam)
	_cam.current = true
	_im = ImmediateMesh.new()
	add_child(_malla_lineas(_im))
	_marcas = ImmediateMesh.new()
	add_child(_malla_lineas(_marcas))


func _malla_lineas(im: ImmediateMesh) -> MeshInstance3D:
	var lineas := MeshInstance3D.new()
	lineas.mesh = im
	var ml := StandardMaterial3D.new()
	ml.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ml.vertex_color_use_as_albedo = true
	ml.no_depth_test = true
	ml.render_priority = 10
	lineas.material_override = ml
	lineas.top_level = true
	return lineas


## La jugadora como el juego: PruebaTest2._personaje (Pj3D.cargar + set_alto). La ropa por defecto y el rim de jugadora los pone `cargar`.
func _montar_jugadora() -> void:
	_pj = Pj3D.new()
	add_child(_pj)
	_pj.cargar(ID)
	_pj.set_alto(ALTO_JUEGO)
	_sk = _pj.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_ap = _pj._ap
	if _pj._arbol != null:
		_pj._arbol.active = false          # el árbol manda sobre el reproductor: el laboratorio lleva el clip a mano
	if _ap != null:
		_ap.active = true


## Los modelos de los que ClipsFamilia traduce los clips (ver FUENTES): se abren una vez y se esconden hasta que toque verlos.
func _montar_fuentes() -> void:
	_puesto_fuente = Node3D.new()
	_puesto_fuente.position = Vector3(SEPARACION_FUENTE, 0.0, 0.0)
	add_child(_puesto_fuente)
	var altura_nueva: float = _altura_esqueleto(_sk, _pj)
	for f in (ClipsFamilia.FUENTES.get(ID, []) as Array):
		var d: Dictionary = f
		var ruta: String = String(d.get("ruta", ""))
		if not ResourceLoader.exists(ruta):
			continue
		var nodo: Node3D = (load(ruta) as PackedScene).instantiate() as Node3D
		var sks: Array[Node] = nodo.find_children("*", "Skeleton3D", true, false)
		var aps: Array[Node] = nodo.find_children("*", "AnimationPlayer", true, false)
		if sks.is_empty() or aps.is_empty():
			nodo.free()
			continue
		var sk_f: Skeleton3D = sks[0] as Skeleton3D
		var ap_f: AnimationPlayer = aps[0] as AnimationPlayer
		for n in ap_f.get_animation_list():
			ap_f.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		var pedidos: Dictionary = (d.get("clips", {}) as Dictionary).duplicate()
		if pedidos.is_empty():
			for n in ap_f.get_animation_list():
				pedidos[String(n)] = String(n)
		var contenedor := Node3D.new()
		contenedor.visible = false
		_puesto_fuente.add_child(contenedor)
		contenedor.add_child(nodo)
		# Misma altura de esqueleto (suela → coronilla) que la jugadora y pies en y = 0 en reposo.
		var h: float = _altura_esqueleto(sk_f, nodo)
		if h > 0.0001:
			nodo.scale = Vector3.ONE * (altura_nueva / h)
		nodo.position.y = -_suela_reposo(sk_f, nodo) * nodo.scale.y
		_fuentes.append({
			"ruta": ruta, "etiqueta": ruta.get_file(), "clips": pedidos, "nodo": nodo, "cont": contenedor, "sk": sk_f, "ap": ap_f,
			"malla": not nodo.find_children("*", "MeshInstance3D", true, false).is_empty()})


## Alto del esqueleto en reposo, suela → coronilla (HeadTop_End; si no hay, Head), en el espacio de `raiz` (con su escala) por la escala del modelo.
func _altura_esqueleto(sk: Skeleton3D, raiz: Node3D) -> float:
	var arriba: int = sk.find_bone("mixamorig_HeadTop_End")
	if arriba < 0:
		arriba = sk.find_bone("mixamorig_Head")
	if arriba < 0:
		return 0.0
	var a: Transform3D = raiz.global_transform.affine_inverse() * sk.global_transform
	var y_arriba: float = (a * sk.get_bone_global_rest(arriba).origin).y
	return (y_arriba - _suela_reposo(sk, raiz)) * raiz.global_transform.basis.get_scale().y


## Altura (espacio de `raiz`) de la suela más baja del esqueleto en reposo.
func _suela_reposo(sk: Skeleton3D, raiz: Node3D) -> float:
	var a: Transform3D = raiz.global_transform.affine_inverse() * sk.global_transform
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in ClipsFamilia.HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, (a * sk.get_bone_global_rest(i).origin).y)
	return m if m != INF else 0.0


## La lista de clips de la jugadora (los de su AnimationPlayer, tal como los tiene el juego), con sus roles de Pj3D y su fuente.
func _montar_clips() -> void:
	_clips.clear()
	var por_clip: Dictionary = {}
	_roles_sin_clip = PackedStringArray()
	for rol in Pj3D.SINONIMOS.keys():
		var c: String = _pj.clip_de(String(rol))
		if c == "":
			_roles_sin_clip.append(String(rol))
			continue
		if not por_clip.has(c):
			por_clip[c] = []
		(por_clip[c] as Array).append(String(rol))
	var nombres: Array = Array(_ap.get_animation_list())
	nombres.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)
	for n in nombres:
		var nombre: String = String(n)
		_clips.append({"nombre": nombre, "roles": por_clip.get(nombre, []), "dur": _ap.get_animation(nombre).length, "fuente": _fuente_de(nombre)})


## De qué fuente y de qué clip sale el clip `nombre` (la primera fuente que lo da, como ClipsFamilia._traer_de). {} si no sale de ninguna (lo construye Pj3D por código).
func _fuente_de(nombre: String) -> Dictionary:
	for i in range(_fuentes.size()):
		var pedidos: Dictionary = (_fuentes[i] as Dictionary)["clips"]
		if pedidos.has(nombre) and ((_fuentes[i] as Dictionary)["ap"] as AnimationPlayer).has_animation(String(pedidos[nombre])):
			return {"i": i, "origen": String(pedidos[nombre])}
	return {}


func _indice_de_rol(rol: String) -> int:
	var c: String = _pj.clip_de(rol)
	for i in range(_clips.size()):
		if String((_clips[i] as Dictionary)["nombre"]) == c:
			return i
	return 0


# ---------- la cabeza ----------

## Mide el cráneo en reposo: arriba = el vértice más alto de la zona «cabeza» con peso en Head; abajo, el más bajo. Todo en el espacio del esqueleto (el de las mallas skineadas).
func _medir_cabeza() -> void:
	var hc: int = _sk.find_bone("mixamorig_Head")
	_hy_sk = _sk.get_bone_global_rest(hc).origin.y if hc >= 0 else 0.0
	_esc_sk = (_pj._modelo.global_transform.affine_inverse() * _sk.global_transform).basis.get_scale().y
	var cuerpo: MeshInstance3D = Ropa3D.cuerpo(_pj)
	var minimo: float = INF
	var maximo: float = -INF
	if cuerpo != null and cuerpo.mesh != null and cuerpo.skin != null:
		for s in range(cuerpo.mesh.get_surface_count()):
			if cuerpo.mesh.surface_get_name(s) != "cabeza":
				continue
			var arr: Array = cuerpo.mesh.surface_get_arrays(s)
			var huesos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var por: int = huesos.size() / maxi(verts.size(), 1)
			for v in range(verts.size()):
				var w: float = 0.0
				for k in range(por):
					if cuerpo.skin.get_bind_name(huesos[v * por + k]) == "mixamorig_Head":
						w += pesos[v * por + k]
				if w >= PESO_CABEZA_MIN:
					minimo = minf(minimo, verts[v].y)
					maximo = maxf(maximo, verts[v].y)
	if minimo == INF:
		# Sin malla: del hueso Head a la coronilla.
		var arriba: int = _sk.find_bone("mixamorig_HeadTop_End")
		minimo = _hy_sk
		maximo = _sk.get_bone_global_rest(arriba).origin.y if arriba >= 0 else _hy_sk
	_chin_sk = minimo
	_top_sk = maximo
	_alto_cabeza_raw = (_top_sk - _chin_sk) * _esc_sk


## Escala de la cabeza (hueso Head, ProporcionChibi) y el alto del personaje se mantiene (Pj3D.set_proporcion lo reajusta).
func _poner_cabeza(v: float, actualizar_slider: bool = false) -> void:
	_cabeza = clampf(snappedf(v, CABEZA_PASO), CABEZA_MIN, CABEZA_MAX)
	if _pj.proporcion != null:
		_pj.set_proporcion(_cabeza, _pj.proporcion.piernas, _pj.proporcion.torso)
	if actualizar_slider and _sl_cabeza != null:
		_ocupado = true
		_sl_cabeza.value = _cabeza
		_ocupado = false
	_refrescar_cabeza()


## «Alturas de cabeza» con la escala actual: alto total del modelo (incluye lo que cambia la cabeza) / alto de la cabeza escalada.
func alturas_de_cabeza() -> float:
	var cabeza_raw: float = _alto_cabeza_raw * _cabeza
	return _pj.alto_modelo() / cabeza_raw if cabeza_raw > 0.0001 else 0.0


func escala_cabeza() -> float:
	return _cabeza


## La escala de la cabeza que tiene ahora el juego (Pj3D.PROPORCIONES[jugadora_base][0]; 1,0 sin entrada).
func escala_cabeza_juego() -> float:
	return _cabeza_juego


func _refrescar_cabeza() -> void:
	if _lbl_cabeza == null:
		return
	_lbl_cabeza.text = "×%s" % _n(_cabeza, 2)
	var raw: float = _pj.alto_modelo()
	var nota: String = "  (valor del juego)" if is_equal_approx(_cabeza, _cabeza_juego) else ""
	_lbl_alturas.text = "alturas de cabeza: %s  (alto %s / cabeza %s u del modelo)%s" % [_n(alturas_de_cabeza(), 2), _n(raw, 2), _n(_alto_cabeza_raw * _cabeza, 2), nota]


# ---------- interfaz ----------

func _montar_interfaz() -> void:
	_capa = CanvasLayer.new()
	add_child(_capa)
	_caja_panel = PanelContainer.new()
	_caja_panel.anchor_bottom = 1.0
	_caja_panel.offset_left = 8.0
	_caja_panel.offset_top = 8.0
	_caja_panel.offset_right = ANCHO_PANEL_IZQ - 8.0
	_caja_panel.offset_bottom = -34.0
	_capa.add_child(_caja_panel)
	var desplazable := ScrollContainer.new()
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_caja_panel.add_child(desplazable)
	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazable.add_child(caja)

	caja.add_child(_titulo("LAB JUGADORA · %s (no modifica archivos)" % ID))
	caja.add_child(_titulo("Clips (clic o ↑/↓) · [roles de Pj3D] · duración · ← fuente"))
	_lista = ItemList.new()
	_lista.custom_minimum_size = Vector2(0.0, 300.0)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(_clips.size()):
		_lista.add_item(_texto_clip(_clips[i] as Dictionary))
	_lista.item_selected.connect(func(i: int) -> void: _elegir_clip(i))
	caja.add_child(_lista)

	var fila_v := HBoxContainer.new()
	caja.add_child(fila_v)
	var lv := Label.new()
	lv.text = "velocidad (V)"
	fila_v.add_child(lv)
	for v in VELOCIDADES:
		var b := Button.new()
		b.text = String(v[0])
		b.toggle_mode = true
		var val: float = float(v[1])
		b.pressed.connect(func() -> void: poner_velocidad(val))
		fila_v.add_child(b)
		_botones_vel.append(b)
	var b_pausa := Button.new()
	b_pausa.text = "pausa (Espacio)"
	b_pausa.pressed.connect(func() -> void: poner_pausa(not _pausa))
	fila_v.add_child(b_pausa)
	var f_t := HBoxContainer.new()
	caja.add_child(f_t)
	var lt := Label.new()
	lt.text = "fotograma"
	lt.custom_minimum_size = Vector2(80.0, 0.0)
	f_t.add_child(lt)
	_sl_tiempo = HSlider.new()
	_sl_tiempo.min_value = 0.0
	_sl_tiempo.max_value = 1.0
	_sl_tiempo.step = 0.0005
	_sl_tiempo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sl_tiempo.value_changed.connect(func(v: float) -> void:
		if _ocupado:
			return
		poner_pausa(true)
		poner_fraccion(v))
	f_t.add_child(_sl_tiempo)
	_lbl_tiempo = Label.new()
	_lbl_tiempo.custom_minimum_size = Vector2(110.0, 0.0)
	f_t.add_child(_lbl_tiempo)

	_chk_fuente = _casilla(caja, "Modelo fuente al lado, con el clip original (F)", true, func(on: bool) -> void: mostrar_fuente(on))
	_chk_esq = _casilla(caja, "Esqueleto visible (S): verde piernas · azul brazos", false, func(on: bool) -> void: _esqueleto = on)
	_chk_marca = _casilla(caja, "Marcar la cabeza: barbilla (magenta) y coronilla (amarillo) (M)", false, func(on: bool) -> void: _marcar = on)
	_chk_ropa = _casilla(caja, "Ropa por defecto puesta (R)", true, func(on: bool) -> void: poner_ropa(on))
	_chk_postura = _casilla(caja, "Probar la postura de la elfa (Pj3D.POSTURAS[chibi_elf]) (P)", false, func(on: bool) -> void: poner_postura_elfa(on))

	caja.add_child(_titulo("Escala de la cabeza (hueso Head; -/+ de 0,05 en 0,05; H = valor del juego)"))
	var f_c := HBoxContainer.new()
	caja.add_child(f_c)
	_sl_cabeza = HSlider.new()
	_sl_cabeza.min_value = CABEZA_MIN
	_sl_cabeza.max_value = CABEZA_MAX
	_sl_cabeza.step = CABEZA_PASO
	_sl_cabeza.value = 1.0
	_sl_cabeza.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sl_cabeza.value_changed.connect(func(v: float) -> void:
		if not _ocupado:
			_poner_cabeza(v))
	f_c.add_child(_sl_cabeza)
	_lbl_cabeza = Label.new()
	_lbl_cabeza.custom_minimum_size = Vector2(60.0, 0.0)
	f_c.add_child(_lbl_cabeza)
	_lbl_alturas = Label.new()
	_lbl_alturas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_alturas.custom_minimum_size = Vector2(430.0, 0.0)
	caja.add_child(_lbl_alturas)

	caja.add_child(_titulo("Cámara"))
	var f_cam := HBoxContainer.new()
	caja.add_child(f_cam)
	var etiquetas: Array = ["1 frente", "2 lado", "3 ¾", "4 arriba", "5 juego"]
	for i in range(NOMBRES_CAMARA.size()):
		var bc := Button.new()
		bc.text = String(etiquetas[i])
		var nombre: String = String(NOMBRES_CAMARA[i])
		bc.pressed.connect(func() -> void: camara(nombre))
		f_cam.add_child(bc)

	var ayuda := Label.new()
	ayuda.text = "1-5 cámara · Espacio pausa · V velocidad · ←/→ fotograma · ↑/↓ clip · F fuente · S esqueleto · M marcas · R ropa · P postura de la elfa · -/+ cabeza · H cabeza del juego · rueda zoom · arrastrar orbita"
	ayuda.anchor_top = 1.0
	ayuda.anchor_bottom = 1.0
	ayuda.offset_top = -28.0
	ayuda.offset_left = 8.0
	_capa.add_child(ayuda)

	_panel_der = PanelContainer.new()
	_panel_der.anchor_left = 1.0
	_panel_der.anchor_right = 1.0
	_panel_der.anchor_bottom = 1.0
	_panel_der.offset_left = -ANCHO_PANEL_DER
	_panel_der.offset_right = -8.0
	_panel_der.offset_top = 8.0
	_panel_der.offset_bottom = -34.0
	_capa.add_child(_panel_der)
	var caja_d := VBoxContainer.new()
	_panel_der.add_child(caja_d)
	caja_d.add_child(_titulo("Medidas del clip visto"))
	_txt = TextEdit.new()
	_txt.editable = false
	_txt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja_d.add_child(_txt)
	var b_cop := Button.new()
	b_cop.text = "Copiar al portapapeles"
	b_cop.pressed.connect(func() -> void: DisplayServer.clipboard_set(_txt.text))
	caja_d.add_child(b_cop)
	_sin_foco(_capa)


func _titulo(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	return l


func _casilla(padre: Control, texto: String, ini: bool, f: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = texto
	c.button_pressed = ini
	c.toggled.connect(func(on: bool) -> void:
		if not _ocupado:
			f.call(on))
	padre.add_child(c)
	return c


## Nada de la interfaz coge el teclado: las teclas del laboratorio las lleva _input (si no, Espacio y las flechas las gastarían los botones y la lista).
func _sin_foco(n: Node) -> void:
	if n is Control and not (n is TextEdit):
		(n as Control).focus_mode = Control.FOCUS_NONE
	for h in n.get_children():
		_sin_foco(h)


func _texto_clip(c: Dictionary) -> String:
	var roles: Array = c["roles"]
	var f: Dictionary = c["fuente"]
	var origen: String = "construido por código (Pj3D)"
	if not f.is_empty():
		origen = "%s · %s" % [String((_fuentes[int(f["i"])] as Dictionary)["etiqueta"]), String(f["origen"])]
	var r: String = "  [%s]" % ", ".join(PackedStringArray(roles)) if not roles.is_empty() else ""
	return "%s%s  %s s  ←  %s" % [c["nombre"], r, _n(float(c["dur"]), 2), origen]


# ---------- clips y tiempo ----------

func clips() -> Array:
	return _clips


func clip_actual() -> String:
	return String((_clips[_sel] as Dictionary)["nombre"]) if _sel >= 0 else ""


func jugadora() -> Pj3D:
	return _pj


func hay_fuente() -> bool:
	return _sel >= 0 and not ((_clips[_sel] as Dictionary)["fuente"] as Dictionary).is_empty()


## true si la fuente del clip visto tiene malla (si no, solo se dibuja su esqueleto).
func fuente_con_malla() -> bool:
	if not hay_fuente():
		return false
	return bool((_fuentes[int(((_clips[_sel] as Dictionary)["fuente"] as Dictionary)["i"])] as Dictionary)["malla"])


func elegir_clip_por_nombre(nombre: String) -> bool:
	for i in range(_clips.size()):
		if String((_clips[i] as Dictionary)["nombre"]) == nombre:
			_elegir_clip(i)
			return true
	return false


func _elegir_clip(i: int) -> void:
	if _clips.is_empty():
		return
	_sel = wrapi(i, 0, _clips.size())
	var nombre: String = clip_actual()
	_ap.play(nombre)
	_ap.pause()
	_t = 0.0
	if _lista != null:
		_lista.select(_sel)
		_lista.ensure_current_is_visible()
	for f in _fuentes:
		(f["cont"] as Node3D).visible = false
	if hay_fuente():
		var d: Dictionary = (_clips[_sel] as Dictionary)["fuente"]
		var fu: Dictionary = _fuentes[int(d["i"])]
		var apf: AnimationPlayer = fu["ap"]
		apf.play(String(d["origen"]))
		apf.pause()
	_aplicar_tiempo()
	_refrescar_texto()


func poner_velocidad(v: float) -> void:
	if v <= 0.0:
		poner_pausa(true)
		return
	_vel = v
	_pausa = false
	_marcar_botones()


func poner_pausa(p: bool) -> void:
	_pausa = p
	_marcar_botones()


func _marcar_botones() -> void:
	for i in range(_botones_vel.size()):
		_botones_vel[i].set_pressed_no_signal(not _pausa and is_equal_approx(float(VELOCIDADES[i][1]), _vel))


## Pone el clip en la fracción `f` (0–1) de su duración.
func poner_fraccion(f: float) -> void:
	_t = clampf(f, 0.0, 1.0) * duracion()
	_aplicar_tiempo()


func duracion() -> float:
	return _ap.get_animation(clip_actual()).length if _sel >= 0 else 0.0


func fraccion() -> float:
	return _t / duracion() if duracion() > 0.0 else 0.0


func _aplicar_tiempo() -> void:
	if _sel < 0:
		return
	var largo: float = duracion()
	_t = fposmod(_t, largo) if largo > 0.0 else 0.0
	_ap.seek(_t, true)
	if hay_fuente():
		var d: Dictionary = (_clips[_sel] as Dictionary)["fuente"]
		var apf: AnimationPlayer = (_fuentes[int(d["i"])] as Dictionary)["ap"]
		var largo_f: float = apf.get_animation(String(d["origen"])).length
		apf.seek(fposmod(_t, largo_f) if largo_f > 0.0 else 0.0, true)
	if _sl_tiempo != null:
		_ocupado = true
		_sl_tiempo.value = fraccion()
		_ocupado = false
		_lbl_tiempo.text = "%d / %d · %s s" % [int(round(_t * FPS_PASO)), int(round(largo * FPS_PASO)), _n(_t, 2)]


func mostrar_fuente(on: bool) -> void:
	_fuente_visible = on
	if _chk_fuente != null:
		_ocupado = true
		_chk_fuente.button_pressed = on
		_ocupado = false


func poner_ropa(on: bool) -> void:
	for prenda in (Pj3D.ROPA_POR_DEFECTO.get(ID, []) as Array):
		if on:
			_pj.poner_ropa(String(prenda))
		else:
			_pj.quitar_ropa(String(prenda))
	if _chk_ropa != null:
		_ocupado = true
		_chk_ropa.button_pressed = on
		_ocupado = false


## Pone (o quita) la POSTURA de la elfa de antes (Pj3D.POSTURAS["chibi_elf"]: cabeza, cuello, columna, brazos, rodillas, pies, pelvis en grados). La jugadora nueva traduce los
## clips de la elfa pero NO tiene entrada en POSTURAS: el juego corrige a la elfa (cabizbaja, hombros encogidos, rodillas dobladas) y a ella no. Solo para mirar: no cambia el juego.
func poner_postura_elfa(on: bool) -> void:
	_postura_elfa = on
	var q: Array = Pj3D.POSTURAS.get("chibi_elf", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]) if on else [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	_pj.set_postura(float(q[0]), float(q[1]), float(q[2]), float(q[3]), float(q[4]), float(q[5]), float(q[6]))
	if _chk_postura != null:
		_ocupado = true
		_chk_postura.button_pressed = on
		_ocupado = false


func ocultar_interfaz(oculta: bool) -> void:
	_interfaz_visible = not oculta
	if _capa != null:
		_capa.visible = not oculta


## Deja solo lo que se ve del laboratorio en una captura: sin interfaz, con el esqueleto y las marcas que se pidan.
func poner_esqueleto(on: bool) -> void:
	_esqueleto = on
	if _chk_esq != null:
		_ocupado = true
		_chk_esq.button_pressed = on
		_ocupado = false


# ---------- cámara ----------

func camara(nombre: String) -> void:
	_modo_juego = nombre == "juego"
	match nombre:
		"frente":
			_yaw = 0.0
			_pitch = 0.1
		"lado":
			_yaw = PI * 0.5
			_pitch = 0.1
		"tres_cuartos":
			_yaw = deg_to_rad(40.0)
			_pitch = 0.15
		"arriba":
			_yaw = 0.0
			_pitch = deg_to_rad(82.0)
		"juego":
			_yaw = 0.0
			_tam_juego = TAM_CAMARA_JUEGO
	_dist = ALTO_JUEGO * 2.6 + 0.8 + (SEPARACION_FUENTE * 0.8 if _fuente_visible_ahora() else 0.0)


## Cámara en perspectiva a mano (para las capturas): giro y elevación en grados, distancia al foco.
func vista(yaw_grados: float, pitch_grados: float, dist: float) -> void:
	_modo_juego = false
	_yaw = deg_to_rad(yaw_grados)
	_pitch = deg_to_rad(pitch_grados)
	_dist = dist


func _fuente_visible_ahora() -> bool:
	return _fuente_visible and hay_fuente()


func _foco() -> Vector3:
	var x: float = SEPARACION_FUENTE * 0.5 if _fuente_visible_ahora() else 0.0
	return Vector3(x, ALTO_JUEGO * (CENTRO_JUEGO if _modo_juego else 0.5), 0.0)


func _colocar_camara() -> void:
	var foco: Vector3 = _foco()
	var alto_px: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var ancho_efectivo: float = 0.0
	if _interfaz_visible:
		ancho_efectivo = ANCHO_PANEL_IZQ - ANCHO_PANEL_DER
	var u_px: float = 0.0
	if _modo_juego:
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = _tam_juego
		var e: float = deg_to_rad(ELEVACION_JUEGO)
		var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
		_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 40.0)
		u_px = _tam_juego / alto_px
	else:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		var d := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
		_cam.transform = Transform3D(Basis.IDENTITY, foco + d * _dist).looking_at(foco, Vector3.UP)
		u_px = 2.0 * _dist * tan(deg_to_rad(_cam.fov) * 0.5) / alto_px
	# Los paneles tapan los lados: se corre la vista para que los personajes queden en el hueco libre.
	_cam.h_offset = -ancho_efectivo * 0.5 * u_px


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: Key = (ev as InputEventKey).keycode
		var visto: bool = true
		match k:
			KEY_UP:
				_elegir_clip(_sel - 1)
			KEY_DOWN:
				_elegir_clip(_sel + 1)
			KEY_LEFT:
				poner_pausa(true)
				_t -= 1.0 / FPS_PASO
				_aplicar_tiempo()
			KEY_RIGHT:
				poner_pausa(true)
				_t += 1.0 / FPS_PASO
				_aplicar_tiempo()
			KEY_SPACE:
				poner_pausa(not _pausa)
			KEY_V:
				_siguiente_velocidad()
			KEY_F:
				mostrar_fuente(not _fuente_visible)
			KEY_S:
				poner_esqueleto(not _esqueleto)
			KEY_M:
				_marcar = not _marcar
				_chk_marca.set_pressed_no_signal(_marcar)
			KEY_R:
				poner_ropa(_pj.ropa_puesta().is_empty())
			KEY_P:
				poner_postura_elfa(not _postura_elfa)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_poner_cabeza(_cabeza - CABEZA_PASO, true)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_poner_cabeza(_cabeza + CABEZA_PASO, true)
			KEY_H:
				_poner_cabeza(_cabeza_juego, true)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				camara(String(NOMBRES_CAMARA[int(k) - int(KEY_1)]))
			_:
				visto = false
		if visto:
			get_viewport().set_input_as_handled()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_modo_juego = false
		_yaw -= (ev as InputEventMouseMotion).relative.x * 0.01
		_pitch = clampf(_pitch + (ev as InputEventMouseMotion).relative.y * 0.01, -0.2, 1.5)
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var b: MouseButton = (ev as InputEventMouseButton).button_index
		var factor: float = 1.0
		if b == MOUSE_BUTTON_WHEEL_UP:
			factor = 0.9
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			factor = 1.1
		if factor != 1.0:
			_dist = clampf(_dist * factor, 0.8, 12.0)
			_tam_juego = clampf(_tam_juego * factor, 0.8, 20.0)


func _siguiente_velocidad() -> void:
	var i: int = 0
	if not _pausa:
		for j in range(VELOCIDADES.size()):
			if is_equal_approx(float(VELOCIDADES[j][1]), _vel):
				i = j + 1
	if i >= VELOCIDADES.size():
		poner_pausa(true)
	else:
		poner_velocidad(float(VELOCIDADES[i][1]))


func _process(delta: float) -> void:
	if _sel >= 0 and not _pausa:
		_t += delta * _vel
		_aplicar_tiempo()
	if _fuentes.size() > 0:
		_actualizar_fuente()
	_colocar_camara()
	_dibujar()


## Enseña el modelo fuente del clip visto (o no) y lo pone a la derecha, a la altura del personaje.
func _actualizar_fuente() -> void:
	var ver: bool = _fuente_visible_ahora()
	for i in range(_fuentes.size()):
		var f: Dictionary = _fuentes[i]
		var es: bool = ver and int(((_clips[_sel] as Dictionary)["fuente"] as Dictionary).get("i", -1)) == i
		(f["cont"] as Node3D).visible = es
		# Sin malla, el esqueleto se dibuja siempre (no hay otra cosa que ver).


func _dibujar() -> void:
	_im.clear_surfaces()
	_marcas.clear_surfaces()
	var dibujar_f: bool = _fuente_visible_ahora() and not fuente_con_malla()
	if _esqueleto or dibujar_f:
		_im.surface_begin(Mesh.PRIMITIVE_LINES)
		if _esqueleto:
			_lineas_hueso(_sk)
		if _fuente_visible_ahora() and (_esqueleto or dibujar_f):
			var fu: Dictionary = _fuentes[int(((_clips[_sel] as Dictionary)["fuente"] as Dictionary)["i"])]
			_lineas_hueso(fu["sk"] as Skeleton3D)
		_im.surface_end()
	if _marcar:
		_marcas.surface_begin(Mesh.PRIMITIVE_LINES)
		var s: float = _cabeza
		_linea_cabeza(_hy_sk + s * (_chin_sk - _hy_sk), COLOR_MARCA)
		_linea_cabeza(_hy_sk + s * (_top_sk - _hy_sk), COLOR_MARCA_2)
		_marcas.surface_end()


func _linea_cabeza(y_sk: float, c: Color) -> void:
	var ctr: Vector3 = _sk.global_transform * Vector3(0.0, y_sk, 0.0)
	for e in [Vector3(-0.3, 0.0, 0.0), Vector3(0.3, 0.0, 0.0)]:
		_marcas.surface_set_color(c)
		_marcas.surface_add_vertex(ctr + (e as Vector3))


func _lineas_hueso(sk: Skeleton3D) -> void:
	for i in range(sk.get_bone_count()):
		var p: int = sk.get_bone_parent(i)
		if p < 0:
			continue
		var c: Color = COLOR_RESTO
		var a: int = i
		while a >= 0:
			var n: String = sk.get_bone_name(a)
			if n.ends_with("UpLeg"):
				c = COLOR_PIERNAS
				break
			if n.ends_with("Shoulder"):
				c = COLOR_BRAZOS
				break
			a = sk.get_bone_parent(a)
		_im.surface_set_color(c)
		_im.surface_add_vertex(sk.global_transform * sk.get_bone_global_pose(p).origin)
		_im.surface_set_color(c)
		_im.surface_add_vertex(sk.global_transform * sk.get_bone_global_pose(i).origin)


# ---------- medidas ----------

func _refrescar_texto() -> void:
	if _txt == null or _sel < 0:
		return
	_txt.text = texto_medidas()


## El texto del panel de medidas del clip visto (público para las capturas y la prueba).
func texto_medidas() -> String:
	var c: Dictionary = _clips[_sel]
	var an: Animation = _ap.get_animation(String(c["nombre"]))
	var roles: Array = c["roles"]
	var s: String = "CLIP %s\nroles de Pj3D: %s\n" % [c["nombre"], ", ".join(PackedStringArray(roles)) if not roles.is_empty() else "(ninguno)"]
	var f: Dictionary = c["fuente"]
	var an_f: Animation = null
	if f.is_empty():
		s += "fuente: construido por código (Pj3D)\n"
	else:
		var fu: Dictionary = _fuentes[int(f["i"])]
		an_f = (fu["ap"] as AnimationPlayer).get_animation(String(f["origen"]))
		s += "fuente: %s · %s\n  (retarget de giro global a jugadora_base, ClipsFamilia)\n" % [fu["etiqueta"], f["origen"]]
	s += "\nNUEVO (en jugadora_base):\n" + _resumen(an)
	if an_f != null:
		s += "\nFUENTE (original):\n" + _resumen(an_f)
	s += "\nPEORES SALTOS de giro entre claves (°, °/s): NUEVO\n" + _lista_saltos(medir_saltos(an))
	if an_f != null:
		s += "\nPEORES SALTOS: FUENTE\n" + _lista_saltos(medir_saltos(an_f))
	if not _roles_sin_clip.is_empty():
		s += "\nRoles de Pj3D sin clip en la jugadora: %s\n" % ", ".join(_roles_sin_clip)
	return s


## Los peores saltos del clip `i` de la lista: {"nuevo": [...], "fuente": [...] (vacío si el clip no sale de una fuente)} (ver `medir_saltos`).
func saltos_del_clip(i: int) -> Dictionary:
	var c: Dictionary = _clips[i]
	var res: Dictionary = {"nuevo": medir_saltos(_ap.get_animation(String(c["nombre"]))), "fuente": []}
	var f: Dictionary = c["fuente"]
	if not f.is_empty():
		res["fuente"] = medir_saltos(((_fuentes[int(f["i"])] as Dictionary)["ap"] as AnimationPlayer).get_animation(String(f["origen"])))
	return res


func _resumen(an: Animation) -> String:
	var n_rot: int = 0
	var claves: int = 0
	for t in range(an.get_track_count()):
		if an.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			n_rot += 1
			claves = maxi(claves, an.track_get_key_count(t))
	var fps: float = float(claves - 1) / an.length if an.length > 0.0 and claves > 1 else 0.0
	return "  %s s · %d claves/pista · %s fps · %d pistas (%d de giro)\n" % [_n(an.length, 2), claves, _n(fps, 1), an.get_track_count(), n_rot]


func _lista_saltos(l: Array) -> String:
	var s: String = ""
	var i: int = 1
	for d in l:
		var e: Dictionary = d
		var par: String = "cierre bucle" if bool(e["cierre"]) else "claves %d→%d" % [int(e["k0"]), int(e["k1"])]
		s += "  %d. %s  %s (%s s)  %s°  %s°/s\n" % [i, String(e["hueso"]).replace("mixamorig_", ""), par, _n(float(e["t0"]), 2), _n(float(e["grados"]), 1), _n(float(e["vel"]), 0)]
		i += 1
	return s if s != "" else "  (sin pistas de giro)\n"


## Los `PEORES` huesos con el mayor giro entre dos claves consecutivas de su pista de rotación (incluido el cierre del bucle: de la última a la primera).
## [{hueso, grados, k0, k1, t0, vel (°/s), cierre}] ordenado de mayor a menor, un solo salto (el peor) por hueso.
static func medir_saltos(an: Animation) -> Array:
	var peor: Dictionary = {}
	for t in range(an.get_track_count()):
		if an.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var n: int = an.track_get_key_count(t)
		if n < 2:
			continue
		var hueso: String = String(an.track_get_path(t)).get_slice(":", 1)
		for k in range(n):
			var k1: int = (k + 1) % n
			var cierre: bool = k == n - 1
			var q0: Quaternion = an.track_get_key_value(t, k)
			var q1: Quaternion = an.track_get_key_value(t, k1)
			var ang: float = rad_to_deg(2.0 * acos(clampf(absf(q0.dot(q1)), 0.0, 1.0)))
			var dt: float = an.track_get_key_time(t, k1) - an.track_get_key_time(t, k) if not cierre else 1.0 / FPS_PASO
			if ang > float((peor.get(hueso, {"grados": -1.0}) as Dictionary)["grados"]):
				peor[hueso] = {"hueso": hueso, "grados": ang, "k0": k, "k1": k1, "t0": an.track_get_key_time(t, k), "vel": ang / maxf(dt, 0.0001), "cierre": cierre}
	var res: Array = peor.values()
	res.sort_custom(func(a: Variant, b: Variant) -> bool: return float((a as Dictionary)["grados"]) > float((b as Dictionary)["grados"]))
	return res.slice(0, PEORES)


## Número con coma decimal.
func _n(x: float, dec: int) -> String:
	return (("%." + str(dec) + "f") % x).replace(".", ",") if dec > 0 else "%d" % int(round(x))
