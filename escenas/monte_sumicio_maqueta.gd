extends Node3D

const PORTON := Vector2i(10, 16)
const GUARDIA := Vector2i(10, 17)
const AUDIENCIA := Vector2i(10, 3)
const OBRADOR := Vector2i(15, 12)
const FRAGA := Vector2i(8, 24)
const CASAS_FAMILIARES := [Vector2i(5, 6), Vector2i(7, 9), Vector2i(5, 13)]
const TIENDA_ESTE := Vector2i(15, 7)

var _porton: Node3D
var _corona: Node3D
var _paja_azotea: Node3D
var _materiales: Dictionary = {}
var _tope_anterior: int
var _montada := false


func montar(mapa: PackedStringArray) -> void:
	_tope_anterior = Jugador3D.tope_niveles_nivel
	Jugador3D.tope_niveles_nivel = 2
	_montada = true
	for z in range(mapa.size()):
		var altura := 2 if z < 15 else (1 if z < 20 else 0)
		# Dos rellanos intermedios reparten cada desnivel en pasos de 0,5175 u.
		var medio_escalon := z == 15 or z == 20
		if altura == 0 and not medio_escalon:
			continue
		for x in range(mapa[z].length()):
			if mapa[z][x] == " ":
				continue
			var c := Vector2i(x, z)
			Terreno3D.fijar_altura(c, altura)
			if medio_escalon:
				Terreno3D.realces_terreno[c] = Terreno3D.ALTO_NIVEL * 0.5
			var color := Color("#82725c") if mapa[z][x] == "g" else Color("#636d56")
			var grosor := Terreno3D.y_pies(c) - Terreno3D.alto_suelo
			var s := Terreno3D.casilla
			_caja(self, punto(c) - Vector3.UP * grosor * 0.5, Vector3(s, grosor, s), color)

	var madera := Color("#5e4635")
	_enmarcar_fraga(madera)
	for x in range(3, 18):
		_tramo(Vector2i(x, 2), madera)
		if x != PORTON.x:
			_tramo(Vector2i(x, PORTON.y), madera)
	for z in range(3, PORTON.y):
		_tramo(Vector2i(3, z), madera, true)
		_tramo(Vector2i(17, z), madera, true)

	_porton = Node3D.new()
	_porton.name = "Porton"
	add_child(_porton)
	_porton.position = punto(PORTON) + Vector3.LEFT * 1.15
	_caja(_porton, Vector3(1.15, 1.3, 0), Vector3(2.26, 2.6, 0.34), madera.lightened(0.15))
	_caja(_porton, Vector3(1.15, 1.7, 0.22), Vector3(2.25, 0.17, 0.18), madera)
	Terreno3D.bloquear_celda_completa(PORTON)

	for casa: Vector2i in CASAS_FAMILIARES:
		_palloza(casa)
	_palloza(TIENDA_ESTE)
	_construir_obrador()
	_construir_torre()
	_rotulo("Torre Verde", punto(Vector2i(10, 7)) + Vector3.UP * 1.5)
	_rotulo("Pallozas familiares", punto(Vector2i(6, 12)) + Vector3.UP * 1.25)
	_rotulo("Obrador del gremio", punto(Vector2i(13, 12)) + Vector3.UP * 1.25)
	_rotulo("Tienda y síntesis", punto(TIENDA_ESTE + Vector2i.DOWN) + Vector3.UP * 1.5)
	_rotulo("Monte Sumicio", punto(PORTON) + Vector3.UP * 3.3)


func _exit_tree() -> void:
	if _montada:
		Jugador3D.tope_niveles_nivel = _tope_anterior


func abrir_porton() -> void:
	_porton.rotation.y = PI * 0.5
	Terreno3D.liberar_celda(PORTON)


func mostrar_interiores(posicion: Vector3) -> void:
	var c := Terreno3D.celda_de(posicion)
	_corona.visible = not Rect2i(8, 3, 5, 5).has_point(c)
	_paja_azotea.visible = not Rect2i(13, 10, 4, 5).has_point(c)


static func punto(c: Vector2i) -> Vector3:
	return Terreno3D.centro_de(c, Terreno3D.y_pies(c))


func _enmarcar_fraga(madera: Color) -> void:
	var hojas := Color("#475d46")
	for c: Vector2i in [Vector2i(5, 22), Vector2i(13, 22), Vector2i(6, 24),
			Vector2i(11, 23), Vector2i(4, 25), Vector2i(12, 25)]:
		var p := punto(c)
		_cilindro(self, p + Vector3.UP * 1.1, 0.24, 0.18, 2.2, madera)
		_cilindro(self, p + Vector3.UP * 2.45, 1.0, 0.05, 2.6, hojas)
		_cilindro(self, p + Vector3.UP * 3.23, 0.74, 0.0, 2.1, hojas.lightened(0.08))
		Terreno3D.bloquear_celda_completa(c)


func _tramo(c: Vector2i, color: Color, girado := false) -> void:
	var p := punto(c)
	var eje := Vector3.BACK if girado else Vector3.RIGHT
	for i in range(-2, 3):
		var alto := 2.15 + 0.12 * posmod(c.x + c.y + i, 3)
		var centro := p + eje * (i * 0.46)
		_cilindro(self, centro + Vector3.UP * (alto * 0.5), 0.24, 0.24, alto, color)
		_cilindro(self, centro + Vector3.UP * (alto + 0.18), 0.24, 0.0, 0.36, color.lightened(0.12))
	Terreno3D.bloquear_celda_completa(c)


func _palloza(c: Vector2i) -> void:
	var p := punto(c)
	var granito := Color("#858481")
	var casillas: Array[Vector2i] = []
	for z in range(-1, 2):
		for x in range(-1, 2):
			var celda := c + Vector2i(x, z)
			if not Terreno3D.es_vacio(celda) and not Terreno3D.bloqueada(celda):
				casillas.append(celda)
	for piedra in range(16):
		var angulo := TAU * float(piedra) / 16.0
		var normal := Vector3(sin(angulo), 0.0, cos(angulo))
		var tramo := Node3D.new()
		add_child(tramo)
		tramo.position = p + normal * 1.49
		tramo.rotation.y = angulo
		var vano := piedra in [0, 1, 15]
		for fila in range(3 if vano else 0, 4):
			var tono := granito.lightened(0.028 * posmod(piedra * 7 + fila * 11 + c.x, 5) - 0.056)
			_caja(tramo, Vector3.UP * (0.2 + fila * 0.4), Vector3(0.61, 0.39, 0.29), tono)
		if not vano:
			var alcance := Terreno3D.casilla * 0.5 + 0.60
			for celda in casillas:
				var d := punto(celda) - tramo.position
				if absf(d.x) < alcance and absf(d.z) < alcance:
					Terreno3D.bloquear_contorno(celda, tramo)
	var paja := Color("#ac8a4f")
	var cubierta := Node3D.new()
	cubierta.name = "Cubierta"
	add_child(cubierta)
	cubierta.position = p
	for franja in range(5):
		var base := lerpf(1.95, 0.12, franja / 5.0)
		var cima := lerpf(1.95, 0.12, (franja + 1) / 5.0)
		var tono := paja.lightened(0.035 * (franja % 3))
		_cilindro(cubierta, Vector3.UP * (0.895 + 0.49 * (franja + 0.5)),
			base, cima, 0.49, tono, 16)
	var madera := Color("#554435")
	for lado in [-1.0, 1.0]:
		_caja(self, p + Vector3(lado * 0.65, 0.60, 1.42), Vector3(0.12, 1.2, 0.22), madera)
	_caja(self, p + Vector3(0, 1.24, 1.42), Vector3(1.42, 0.12, 0.25), madera)
	Terreno3D.bloquear_celda_completa(c)


func _construir_obrador() -> void:
	var p := punto(OBRADOR)
	var piedra := Color("#898481")
	for c: Vector2i in [Vector2i(14, 11), Vector2i(15, 11), Vector2i(16, 11),
			Vector2i(16, 12), Vector2i(14, 13), Vector2i(15, 13), Vector2i(16, 13)]:
		_muro(c, piedra)
	_paja_azotea = _cilindro(self, p + Vector3.UP * 2.8, 3.5, 0.15, 2.8, Color("#ad8b4e"))
	_caja(self, p + Vector3(0.68, 0.42, -0.62), Vector3(0.66, 0.84, 0.46), Color("#62482f"))


func _construir_torre() -> void:
	var piedra := Color("#77847a")
	for x in range(8, 13):
		_muro(Vector2i(x, 2), piedra)
		if x != 10:
			_muro(Vector2i(x, 6), piedra)
	for z in range(3, 6):
		_muro(Vector2i(8, z), piedra)
		_muro(Vector2i(12, z), piedra)
	var p := punto(Vector2i(10, 4))
	_corona = Node3D.new()
	add_child(_corona)
	_corona.position = p
	_cilindro(_corona, Vector3.UP * 5.0, 4.7, 4.5, 5.7, piedra, 20)
	_cilindro(_corona, Vector3.UP * 7.9, 4.75, 4.75, 0.48, Color("#536e58"), 20)
	_cilindro(_corona, Vector3.UP * 9.1, 4.66, 1.2, 2.2, Color("#486851"), 20)
	_caja(self, p + Vector3(0.9, 0.42, -0.75), Vector3(1.15, 0.84, 0.60), Color("#644a39"))


func _muro(c: Vector2i, color: Color) -> void:
	var s := Terreno3D.casilla
	_caja(self, punto(c) + Vector3.UP, Vector3(s, 2.0, s), color)
	Terreno3D.bloquear_celda_completa(c)


func _rotulo(texto: String, p: Vector3) -> void:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.font_size = 38
	etiqueta.pixel_size = 0.015
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(etiqueta)
	etiqueta.position = p


func _caja(padre: Node3D, p: Vector3, tam: Vector3, color: Color) -> MeshInstance3D:
	var malla := BoxMesh.new()
	malla.size = tam
	return _malla(padre, p, malla, color)


func _cilindro(padre: Node3D, p: Vector3, base: float, cima: float, alto: float,
		color: Color, lados := 10) -> MeshInstance3D:
	var malla := CylinderMesh.new()
	malla.bottom_radius = base
	malla.top_radius = cima
	malla.height = alto
	malla.radial_segments = lados
	malla.rings = 1
	return _malla(padre, p, malla, color)


func _malla(padre: Node3D, p: Vector3, malla: Mesh, color: Color) -> MeshInstance3D:
	if not _materiales.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		_materiales[color] = material
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.material_override = _materiales[color]
	padre.add_child(nodo)
	nodo.position = p
	return nodo
