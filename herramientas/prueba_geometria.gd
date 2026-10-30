extends SceneTree
## Geometría de hechizos. R3 (17/10): la prueba original medía `GeometriaHechizo` (largo de la Línea = alcance de la Flecha, +20 % por Línea,
## Tamaño, tope ×3), que se RETIRÓ con la receta V2. Aquí queda lo equivalente con `GeometriaV2`, en números de semieje y casillas.
## Sin ventana. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_geometria.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	var G = Lanzador3D.GeometriaV2
	var cas: float = Terreno3D.casilla
	var origen := Vector2(0.5, 0.5) * cas
	# 1. La esfera base ocupa una casilla; la flecha sola no cambia el volumen, solo lo desplaza.
	_ok("1 esfera base: 1 casilla", G.celdas(Sigils.aplicar_v2({}), origen, Vector2.RIGHT, cas).size() == 1)
	var f: Dictionary = G.evaluar({"flecha": 1})
	_ok("2 la flecha viaja 2 casillas (1.er glifo) y no agranda el volumen", is_equal_approx(float(f["props"]["viaja"]), 2.0) and is_equal_approx(G.volumen(f), G.volumen(G.evaluar({}))))
	# 3. Cada línea vertical (Z) suma PASO_FONDO_V2 de semieje (24/10: base 0,10 y paso 0,10), es decir 2 × paso casillas más de largo; tope 6.
	for n in [1, 2, 3, 4]:
		var g: Dictionary = G.evaluar({"linea_z": n})
		var largo: float = 2.0 * float(g["z"])
		var esperado: float = minf(2.0 * Sigils.semieje_horizontal_v2(n, Sigils.PASO_FONDO_V2), 6.0)
		_ok("3 linea_z ×%d: largo %.2f casillas" % [n, esperado], is_equal_approx(largo, esperado), str(largo))
	# 4. Cada línea horizontal (X) suma PASO_ANCHO_V2 de semieje; tope 6.
	for n in [1, 2, 3, 4]:
		var g: Dictionary = G.evaluar({"linea_x": n})
		var ancho: float = minf(2.0 * Sigils.semieje_horizontal_v2(n), 6.0)
		_ok("4 linea_x ×%d: ancho %.2f casillas" % [n, ancho], is_equal_approx(2.0 * float(g["x"]), ancho))
	# 4 bis. Decisión de Pablo 24/10: ᛜ + 4 ᛁ horizontales = muro de 3 casillas de ancho (origen en el centro de una casilla, mirando a un eje; en diagonal el muro de 0,10 de fondo no alcanza centros vecinos); 3 ᛏ = 2 niveles.
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var muro: Array = G.celdas(G.evaluar({"barrera": 1, "linea_x": Sigils.GLIFOS_ANCHO_MURO_3_V2}), origen, dir, cas)
		_ok("4 bis ᛜ + %d ᛁ mirando a %s: %d casillas" % [Sigils.GLIFOS_ANCHO_MURO_3_V2, str(dir), muro.size()], muro.size() == 3)
	_ok("4 bis 3 ᛏ = 2 niveles; 2 ᛏ = 1", G.niveles(G.evaluar({"altura": Sigils.GLIFOS_ALTURA_DOS_NIVELES_V2})) == 2 and G.niveles(G.evaluar({"altura": Sigils.GLIFOS_ALTURA_DOS_NIVELES_V2 - 1})) == 1)
	# 5. El «haz» (antes chorro) es ahora Z grande: solo toca casillas por delante de la mano, en una fila.
	var haz: Array = G.celdas(G.evaluar({"linea_z": 13}), origen, Vector2.RIGHT, cas)
	var filas: Dictionary = {}
	var detras: bool = false
	for c in haz:
		filas[(c as Vector2i).y] = true
		detras = detras or (c as Vector2i).x < 0
	_ok("5 linea_z ×13: una fila hacia delante y nada detrás de la mano (%d casillas)" % haz.size(), filas.size() == 1 and not detras and haz.size() >= 3)
	# 6. El tope por eje: 99 glifos no pasan de 6 casillas de largo, 6 de ancho y 2 niveles (19/10: altura topada en 1,0 de semieje).
	var m: Dictionary = G.evaluar({"linea_x": 99, "linea_z": 99, "altura": 99})
	# 30/10: ᛁ decreciente no pasa de 2,2 casillas (asíntota 1,10) y la altura topa en 2,0 = 4 niveles; con ᚷ ×99 (que multiplica) los tres llegan al tope: 6 × 6 × 4 niveles.
	_ok("6 99 ᛁ y 99 ᛏ: ancho y fondo no pasan de 2,2 casillas (serie decreciente) y 4 niveles", 2.0 * float(m["x"]) < 2.2001 and 2.0 * float(m["z"]) < 2.2001 and G.niveles(m) == 4)
	print("FALLOS: %d" % _fallos)
	quit(_fallos)
