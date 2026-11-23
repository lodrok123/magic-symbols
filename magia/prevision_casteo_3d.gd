class_name PrevisionCasteo3D
extends Node3D

## Preparación visual, SIN física ni efectos: el Hechizo decide la silueta.
## El recorrido y las reacciones siguen siendo los de PrevisionHechizo/Apuntado3D.
## Contornos abiertos y tenues: nunca prometer protección antes del disparo real.

const ALFA: float = 0.28
const ANCHO: float = 0.018
const PASOS: int = 24
## 22/11 (HECHIZOS, ajuste 1): «no vale» en GRIS, no en rojo. El rojo es de los avisos enemigos (G4, legibilidad: lo suyo siempre por encima de lo nuestro).
const COLOR_NO_VALE: Color = Color(0.62, 0.62, 0.62)
const CIMA_PROTECCION_U: float = 1.35            ## alto de la cúpula de protección (lo lee también el rótulo «para…» de PrevisionReaccion3D)
var tipo: String = ""
var _h: Hechizo
var _lanzador: Node
var _jugadora: Node3D
var _origen := Vector3.ZERO
var _pies := Vector3.ZERO
var _mano := Vector3.ZERO
var _dir := Vector3.RIGHT
var _valido: bool = true
var _conjuro: bool = false
var _edad: float = 0.0
var _malla := ImmediateMesh.new()
var _vista := MeshInstance3D.new()
var _material := StandardMaterial3D.new()


## Mismo orden de prioridades que la ejecución. No se deduce del nombre del glifo:
## barrera+flecha es volumen móvil, retorno+copias sin flecha es órbita.
static func perfil(h: Hechizo) -> String:
	if h == null:
		return ""
	if h.suelo or h.es_plataforma_tierra():
		return "suelo"
	if h.orbita:
		return "orbita"
	if h.haz:
		return "haz"
	if h.volumen_viaja:
		return "volumen_movil"
	if h.proyectil:
		return "proyectil"
	if h.en_punto:
		return "colocado"
	if h.solidez > 0.0:
		return "proteccion"
	return "area"


## 22/11 (HECHIZOS, ajuste 2): ¿lo que sale es el ANILLO fino de tierra de COMBATE (A4, `HechizoVivo._anillo_tierra`)? Pasa con un sólido pisable (tierra) que se apunta a la casilla
## de la jugadora: el bloque no puede levantarse «estás encima» y en su lugar brota el anillo, que SOLO para proyectiles. La misma condición que en `HechizoVivo._materializar`
## (pisable, sólido, sin bloque posible), vista desde fuera: elemento pisable, con solidez y en la casilla de los pies.
static func es_anillo_tierra(h: Hechizo, origen: Vector3, pies: Vector3) -> bool:
	if h == null or h.solidez <= 0.0 or h.fuente == null or not h.fuente.pisable or h.suelo or h.viaja:
		return false
	return Terreno3D.celda_de(origen) == Terreno3D.celda_de(pies)


## 22/11 (HECHIZOS): el punto más alto de la silueta, para que el rótulo «para…» (B9b) se pegue a ella y no tape a la jugadora. Vector3.INF si no es una protección.
static func cima_silueta(h: Hechizo, origen: Vector3, pies: Vector3) -> Vector3:
	var f: String = perfil(h)
	if es_anillo_tierra(h, origen, pies):
		var c: Vector2i = Terreno3D.celda_de(pies)
		return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, pies.y + HechizoVivo.ANILLO_ALTO_U, (float(c.y) + 0.5) * Terreno3D.casilla)
	if f == "proteccion":
		var tiene_forma: bool = maxf(h.semieje_x, maxf(h.semieje_y, h.semieje_z)) > Sigils.RADIO_BASE_V2 + 0.001
		if tiene_forma:
			return origen + Vector3.UP * (0.08 + h.semiejes.y * Terreno3D.casilla * 2.0)
		return pies + Vector3.UP * (0.08 + CIMA_PROTECCION_U)
	if f == "colocado" and h.solidez > 0.0:
		return origen + Vector3.UP * (0.05 + maxf(0.18, h.semiejes.y * Terreno3D.casilla * 2.0))
	return Vector3.INF


## Sustituye SOLO la cúpula rellena del origen por el contorno de preparación.
## Nunca cambia el recorrido simulado: las celdas y las reacciones siguen intactas.
static func recorrido_visual(h: Hechizo, recorrido: Dictionary, pies: Vector3) -> Dictionary:
	var funcion: String = perfil(h)
	# 22/11 (HECHIZOS, ajuste 2): el anillo de tierra en la casilla de la jugadora tampoco se pinta como volumen relleno (era una cúpula amarilla): lo dibuja el contorno del anillo.
	var anillo: bool = funcion == "colocado" and es_anillo_tierra(h, pies, pies)
	if funcion != "proteccion" and funcion != "volumen_movil" and not anillo:
		return recorrido
	var salida: Dictionary = recorrido.duplicate()
	var volumenes: Array = []
	if funcion == "volumen_movil" or anillo:
		var celda: Vector2i = Terreno3D.celda_de(pies)
		for vol in recorrido.get("volumenes", []):
			var v: Dictionary = (vol as Dictionary).duplicate()
			var g: Dictionary = (v.get("volumen", {}) as Dictionary).duplicate()
			var celdas: Array = (g.get("celdas", []) as Array).duplicate()
			celdas.erase(celda)
			if celdas.is_empty():
				continue
			g["celdas"] = celdas
			v["volumen"] = g
			volumenes.append(v)
	salida["volumenes"] = volumenes
	return salida


func _ready() -> void:
	name = "PrevisionCasteo"
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false
	_vista.mesh = _malla
	_vista.material_override = _material
	_vista.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_vista)
	hide()


func mostrar(h: Hechizo, origen: Vector3, direccion: Vector3, pies: Vector3,
		mano: Vector3, valido: bool, lanzador: Node, jugadora: Node3D,
		conjuro: bool = false) -> void:
	if h == null:
		ocultar()
		return
	var nuevo_tipo: String = perfil(h)
	if not visible or nuevo_tipo != tipo:
		_edad = 0.0
	_h = h
	tipo = nuevo_tipo
	_origen = origen
	_pies = pies
	_mano = mano
	_dir = Vector3(direccion.x, 0.0, direccion.z).normalized()
	if _dir.length_squared() < 0.001:
		_dir = Vector3.RIGHT
	_valido = valido
	_conjuro = conjuro
	_jugadora = jugadora
	if _lanzador != lanzador:
		_desconectar()
		_lanzador = lanzador
		if is_instance_valid(_lanzador):
			_lanzador.connect("conjuro_fase", _al_conjuro)
			_lanzador.connect("modo_cambiado", _al_modo)
	show()
	_dibujar()


func ocultar() -> void:
	hide()
	_h = null
	_conjuro = false
	_malla.clear_surfaces()


func _desconectar() -> void:
	if not is_instance_valid(_lanzador):
		return
	if _lanzador.is_connected("conjuro_fase", _al_conjuro):
		_lanzador.disconnect("conjuro_fase", _al_conjuro)
	if _lanzador.is_connected("modo_cambiado", _al_modo):
		_lanzador.disconnect("modo_cambiado", _al_modo)


func _exit_tree() -> void:
	_desconectar()


func _al_modo(activo: bool) -> void:
	if not activo and not _conjuro:
		ocultar()


func _al_conjuro(fase: String, _elemento: String, punto: Vector3) -> void:
	if fase == "disparo":
		ocultar()                         # el efecto activo toma el relevo, sin solaparse
	elif _conjuro and fase == "forma":
		_mano = punto


func _process(delta: float) -> void:
	if not visible or _h == null:
		return
	if is_instance_valid(_jugadora):
		if bool(_jugadora.get("muerto")):
			ocultar()
			return
		var desplazamiento: Vector3 = _jugadora.global_position - _pies
		_pies = _jugadora.global_position
		_mano += desplazamiento
	if _conjuro and is_instance_valid(_lanzador) and not bool(_lanzador.get("conjurando")):
		ocultar()
		return
	if _conjuro and is_instance_valid(_lanzador) and _lanzador.has_method("posicion_prevision_casteo"):
		_mano = _lanzador.call("posicion_prevision_casteo") as Vector3
	_edad += delta
	_dibujar()


func _dibujar() -> void:
	_malla.clear_surfaces()
	if _h == null:
		return
	var col: Color = _h.color if _valido else COLOR_NO_VALE
	col.a = ALFA * (0.88 + 0.12 * sin(_edad * 3.0))
	_material.albedo_color = col
	# Todos los vértices se expresan en mundo y se convierten al nodo: no asume
	# que el lanzador o su padre tengan transformación identidad.
	_malla.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var cas: float = Terreno3D.casilla
	var x: Vector3 = Vector3.UP.cross(_dir).normalized()
	var e: Vector3 = _h.semiejes * cas
	if es_anillo_tierra(_h, _origen, _pies):
		# Ajuste 2: el anillo fino de tierra (A4), con sus medidas: dos aros (pie y borde) y unos postes. Se lee «capa baja alrededor», no «cúpula que cubre».
		var c: Vector2i = Terreno3D.celda_de(_pies)
		var base: Vector3 = Vector3((float(c.x) + 0.5) * cas, _pies.y + 0.04, (float(c.y) + 0.5) * cas)
		var r: float = cas * HechizoVivo.ANILLO_RADIO_K
		var alto: float = HechizoVivo.ANILLO_ALTO_U
		_aro(base, x * r, _dir * r)
		_aro(base + Vector3.UP * alto, x * r, _dir * r)
		for i in range(8):
			var a: float = TAU * float(i) / 8.0
			var p: Vector3 = base + (x * cos(a) + _dir * sin(a)) * r
			_segmento(p, p + Vector3.UP * alto)
	elif tipo == "proteccion":
		var tiene_forma: bool = maxf(_h.semieje_x, maxf(_h.semieje_y, _h.semieje_z)) > Sigils.RADIO_BASE_V2 + 0.001
		if tiene_forma:
			# Un muro/pilar conserva sus ejes; no se redondea hasta hacerlo otra burbuja.
			_casco(_origen + Vector3.UP * 0.08, Vector3(e.x, e.y * 2.0, e.z), x)
		else:
			var r: float = cas * 0.46
			# Cúpula ABIERTA: insinúa el gesto de cubrirse, no una barrera activa.
			_casco(_pies + Vector3.UP * 0.08, Vector3(r, CIMA_PROTECCION_U, r), x)
	elif tipo == "colocado" or tipo == "suelo" or tipo == "area":
		var alto: float = 0.08 if tipo == "suelo" else maxf(0.18, e.y * 2.0)
		_casco(_origen + Vector3.UP * 0.05, Vector3(maxf(e.x, 0.18), alto, maxf(e.z, 0.18)), x)
	elif tipo == "orbita":
		var r: float = (HechizoVivo.ORBITA_RADIO_BASE_CAS + HechizoVivo.ORBITA_RADIO_POR_SEMIEJE * maxf(_h.semieje_x, _h.semieje_z)) * cas
		var centro: Vector3 = _pies + Vector3.UP * Hechizo.ALTURA_MANO_U
		_aro(centro, x * r, _dir * r)
		for i in range(mini(_h.copias, 4)):
			var a: float = TAU * float(i) / float(_h.copias) + _edad * 0.35
			var p: Vector3 = centro + (x * cos(a) + _dir * sin(a)) * r
			_aro(p, x * 0.12, Vector3.UP * 0.12)
	else:
		# Forma de preparación en la mano, sin sustituir el recorrido físico.
		var escala: float = 0.35 / maxf(maxf(e.x, e.y), maxf(e.z, 0.01))
		var tam: Vector3 = e * escala
		if tipo == "haz":
			_segmento(_mano - x * 0.05, _mano + _dir * 0.8 - x * 0.05)
			_segmento(_mano + x * 0.05, _mano + _dir * 0.8 + x * 0.05)
		else:
			_casco(_mano - Vector3.UP * tam.y, tam * Vector3(1, 2, 1), x)
		_flecha(_mano + _dir * 0.35, x)
		if _h.copias > 1:
			for i in range(mini(_h.copias, 4)):
				var p: Vector3 = _mano + _dir * (0.18 * float(i + 1)) if _h.rafaga else _mano + x * (float(i) - float(mini(_h.copias, 4) - 1) * 0.5) * 0.22
				_segmento(p, p + _dir * 0.10)
	_malla.surface_end()


func _flecha(p: Vector3, x: Vector3) -> void:
	_segmento(p, p + _dir * 0.35)
	_segmento(p + _dir * 0.35, p + _dir * 0.18 + x * 0.12)
	_segmento(p + _dir * 0.35, p + _dir * 0.18 - x * 0.12)


func _casco(base: Vector3, e: Vector3, x: Vector3) -> void:
	for nivel in [0.15, 0.55, 0.85]:
		var k: float = sqrt(1.0 - float(nivel) * float(nivel))
		_aro(base + Vector3.UP * e.y * float(nivel), x * e.x * k, _dir * e.z * k)
	for lado in [-1.0, 1.0]:
		var anterior: Vector3 = base + x * e.x * float(lado)
		for i in range(1, 13):
			var a: float = PI * 0.5 * float(i) / 12.0
			var p: Vector3 = base + x * e.x * cos(a) * float(lado) + Vector3.UP * e.y * sin(a)
			if i % 4 != 0:
				_segmento(anterior, p)
			anterior = p


func _aro(centro: Vector3, x: Vector3, z: Vector3) -> void:
	for i in range(PASOS):
		if i % 6 == 5:
			continue                         # huecos permanentes: preparación, no escudo activo
		var a: float = TAU * float(i) / float(PASOS)
		var b: float = TAU * float(i + 1) / float(PASOS)
		_segmento(centro + x * cos(a) + z * sin(a), centro + x * cos(b) + z * sin(b))


func _segmento(a: Vector3, b: Vector3) -> void:
	var lado: Vector3 = (b - a).cross(Vector3.UP).normalized()
	if lado.length_squared() < 0.001:
		lado = Vector3.RIGHT
	lado *= ANCHO
	for p in [a - lado, a + lado, b + lado, a - lado, b + lado, b - lado]:
		_malla.surface_add_vertex(to_local(p as Vector3))
