extends SceneTree
## Geometría de hechizos (P1, 13/10): el largo de la Línea es el alcance de la Flecha y cada Línea repetida suma un 20 %.
## Sin ventana. Lo escribe el Juego.
##   godot --headless --path . --script res://herramientas/prueba_geometria.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _u(g: Dictionary) -> float:
	return float(g["largo"]) * Terreno3D.casilla       # largo de la forma en unidades de mundo


func _initialize() -> void:
	var G = Lanzador3D.GeometriaHechizo
	var cas: float = Terreno3D.casilla
	var flecha: float = float(G.evaluar({"flecha": 1})["alcance"]) * cas
	_ok("1 Flecha sola alcanza 3 casillas = 6,9 u", is_equal_approx(flecha, 6.9), str(flecha))
	var l1: float = _u(G.evaluar({"linea": 1}))
	var l2: float = _u(G.evaluar({"linea": 2}))
	var l3: float = _u(G.evaluar({"linea": 3}))
	_ok("2 una Línea = alcance de Flecha (6,9 u)", is_equal_approx(l1, flecha), str(l1))
	_ok("3 dos Líneas = ×1,2 (8,28 u)", is_equal_approx(l2, 8.28), str(l2))
	_ok("4 tres Líneas = ×1,4 (9,66 u)", is_equal_approx(l3, 9.66), str(l3))
	# Tamaño suma su parte propia (+2 casillas); Flecha en el chorro +1 casilla; ninguno cambia su regla.
	var lt: float = _u(G.evaluar({"linea": 2, "tamano": 1}))
	_ok("5 dos Líneas + Tamaño = 8,28 u + 2 casillas", is_equal_approx(lt, 8.28 + 2.0 * cas), str(lt))
	var lf: float = _u(G.evaluar({"linea": 1, "flecha": 1}))
	_ok("6 Línea + Flecha sigue alargando 1 casilla", is_equal_approx(lf, 6.9 + cas), str(lf))
	var tope: float = _u(G.evaluar({"linea": 3, "tamano": 9, "flecha": 5}))
	_ok("7 el tope sigue siendo ×3 la medida base (9 casillas)", is_equal_approx(tope, 9.0 * cas), str(tope))
	_ok("8 Flecha y Tamaño sobre la esfera no cambian", is_equal_approx(float(G.evaluar({"flecha": 3})["alcance"]), 5.0) and is_equal_approx(float(G.evaluar({"tamano": 1})["radio"]), 1.0))
	# El rayo del chorro ya no sobrepasa el largo dibujado: antes llegaba a HAZ_DESDE + largo (8,05 u en vez de 6,9).
	var g: Dictionary = G.evaluar({"linea": 1})
	var origen := Vector2(0.5, 0.5) * cas
	var cs: Array = G.celdas(g, origen, Vector2.RIGHT, cas)
	var lejos: float = 0.0
	for c in cs:
		var borde_cercano: float = float((c as Vector2i).x) * cas - origen.x       # donde empieza esa casilla, a lo largo de +X
		lejos = maxf(lejos, borde_cercano)
	_ok("9 el haz solo toca casillas que empiezan antes de 6,9 u", lejos < 6.9 and cs.size() == 3, "casillas=%d, empieza la última a %.2f u" % [cs.size(), lejos])
	print("FALLOS: %d" % _fallos)
	quit(_fallos)
