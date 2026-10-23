extends SceneTree
## PULSO3D SOLO (23/10, FASE 1 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §3), sin escena ni ventana y con una rejilla falsa de conductores:
##   · la BÚSQUEDA compartida con la fuente eléctrica (`EmisorRayo3D.ola`): pasos, alcance, 4 vecinas sin diagonales, y que `agua_conectada` sigue dando lo de siempre;
##   · ALCANCE: nada pasa del paso `alcance`;
##   · RETRASO por casilla: el paso p se dispara cuando el reloj del pulso llega a p × SEG_POR_CASILLA, ni antes ni mucho después;
##   · CORTE sin conductor: en el aire solo toca la casilla de al lado (1 casilla);
##   · COLOR: sin elemento el pulso es `COLOR_BASE` (azulado claro, #9ED9FF); con elemento, el color de su runa (se comprueba contra `nucleo/*_rune.tres`);
##   · SIN REENTRADAS: una casilla se alcanza una vez aunque haya un anillo de conductores, un receptor entre dos casillas del frente recibe UN aviso, el emisor no se avisa a sí mismo;
##   · AVISO a lo que toca (receptor junto a la veta) en el paso que le corresponde, y el nodo se libera al terminar.
##   godot --headless --path . --script res://herramientas/prueba_pulso.gd

## Un receptor de mentira: tiene `celda` y `on_pulso`, y cuenta los avisos.
class Receptor extends Node:
	var celda: Vector2i = Vector2i.ZERO
	var avisos: int = 0
	var edad_aviso: float = -1.0
	var elemento_visto: String = ""
	func on_pulso(p: Pulso3D) -> void:
		avisos += 1
		edad_aviso = p.edad()
		elemento_visto = p.elemento

var _fallos: int = 0
var _conduce: Dictionary = {}                  ## la rejilla falsa: casilla -> true


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _f(c: Vector2i) -> bool:
	return _conduce.has(c)


## Hace avanzar un pulso `segundos` en pasos de 10 ms (como fotogramas), para que su reloj marque la hora real de cada aviso.
func _avanzar_a_mano(p: Pulso3D, segundos: float) -> void:
	var t: float = 0.0
	while t < segundos and is_instance_valid(p):
		p.avanzar(0.01)
		t += 0.01


func _linea(desde: Vector2i, hasta: Vector2i) -> void:
	for y in range(mini(desde.y, hasta.y), maxi(desde.y, hasta.y) + 1):
		for x in range(mini(desde.x, hasta.x), maxi(desde.x, hasta.x) + 1):
			_conduce[Vector2i(x, y)] = true


func _initialize() -> void:
	await process_frame
	_busqueda()
	await _pulso_alcance_y_retraso()
	await _pulso_corte_en_el_aire()
	_colores()
	await _pulso_sin_reentradas()
	await _pulso_avisa_y_acaba()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------------------------------------------------------------

func _busqueda() -> void:
	_conduce.clear()
	_linea(Vector2i(1, 0), Vector2i(5, 0))
	_linea(Vector2i(3, 1), Vector2i(3, 3))               # una rama hacia abajo
	_conduce[Vector2i(6, 1)] = true                       # solo en diagonal de (5,0): NO se une (4 vecinas)
	var ola: Dictionary = EmisorRayo3D.ola([Vector2i(0, 0)], _f, 99)
	_ok("1 la búsqueda da los pasos de cada casilla (1..5 por la línea; la rama baja desde el paso 3: 4, 5 y 6)", ola.get(Vector2i(1, 0)) == 1 and ola.get(Vector2i(5, 0)) == 5 and ola.get(Vector2i(3, 1)) == 4 and ola.get(Vector2i(3, 3)) == 6, str(ola))
	_ok("1 una casilla que solo toca por la diagonal no entra (4 vecinas)", not ola.has(Vector2i(6, 1)))
	_ok("1 el origen que NO conduce no cuenta como conductor", not ola.has(Vector2i(0, 0)))
	var corta: Dictionary = EmisorRayo3D.ola([Vector2i(0, 0)], _f, 3)
	_ok("1 con alcance 3 no pasa del paso 3", corta.size() == 3 and not corta.has(Vector2i(4, 0)) and corta.has(Vector2i(3, 0)), str(corta.keys()))
	var con_origen: Dictionary = EmisorRayo3D.ola([Vector2i(0, 0)], _f, 3, true)
	_ok("1 con `origen_siempre` el origen entra en el paso 0 (el pulso nace en su emisor)", con_origen.get(Vector2i(0, 0)) == 0 and con_origen.size() == 4)
	# La fuente eléctrica sigue pidiendo lo mismo (`agua_conectada` ahora llama a `ola`): conjunto y orden por anillos.
	var agua: Array = EmisorRayo3D.agua_conectada(Vector2i(0, 0), _f)
	_ok("1 `agua_conectada` sigue dando el conjunto conectado de siempre (8 casillas, sin la diagonal)", agua.size() == 8 and not agua.has(Vector2i(6, 1)) and agua.has(Vector2i(3, 3)), str(agua))
	# Origen que ya es agua: entra él también.
	var desde_agua: Array = EmisorRayo3D.agua_conectada(Vector2i(1, 0), _f)
	_ok("1 si el origen conduce, entra él y lo conectado (sin la diagonal)", desde_agua.size() == 8 and desde_agua[0] == Vector2i(1, 0), str(desde_agua))


## Lanza un pulso con la rejilla falsa, sin dibujo. `_conduce` ya preparada.
func _lanzar(origen: Vector2i, elemento: String, alcance: int, receptores: Array = []) -> Pulso3D:
	var p := Pulso3D.new()
	p.dibujar = false
	p.preparar([origen], elemento, alcance, null, _f)
	for r in receptores:
		root.add_child(r)
		r.add_to_group(Pulso3D.GRUPO_PULSABLE)
	root.add_child(p)
	return p


func _pulso_alcance_y_retraso() -> void:
	_conduce.clear()
	_linea(Vector2i(1, 0), Vector2i(9, 0))
	var p: Pulso3D = _lanzar(Vector2i(0, 0), "", 5)
	_ok("2 alcance 5 sobre una línea de 9: alcanza el origen y 5 casillas (6)", p.alcanzadas.size() == 6 and p.alcanzadas.has(Vector2i(5, 0)) and not p.alcanzadas.has(Vector2i(6, 0)), str(p.alcanzadas.keys()))
	var edades: Dictionary = {}                    ## paso -> edad del reloj del pulso cuando se disparó
	p.alcanzo.connect(func(_c: Vector2i, paso: int) -> void: edades[paso] = p.edad())
	var t: float = 0.0
	var dt: float = 0.01
	while t < 0.75:
		p.avanzar(dt)
		t += dt
	var bien: bool = edades.size() == 6
	var peor: float = 0.0
	for paso in edades:
		var esperado: float = float(paso) * Pulso3D.SEG_POR_CASILLA
		var retraso: float = float(edades[paso]) - esperado
		peor = maxf(peor, retraso)
		if retraso < -1.0e-4 or retraso > dt + 1.0e-4:           # ni antes de su hora ni más de un fotograma tarde
			bien = false
	_ok("2 cada paso se dispara a su hora (paso × %.2f s, como mucho %.0f ms tarde)" % [Pulso3D.SEG_POR_CASILLA, peor * 1000.0], bien, str(edades))
	_ok("2 el pulso de 0,08 s por casilla tarda 0,40 s en llegar al paso 5", absf(float(edades.get(5, 0.0)) - 0.40) <= dt + 1.0e-4)
	# Un pulso nuevo: a 0,07 s solo ha salido el origen.
	var q: Pulso3D = _lanzar(Vector2i(0, 0), "", 5)
	var vistos: Array = []
	q.alcanzo.connect(func(_c: Vector2i, paso: int) -> void: vistos.append(paso))
	q.avanzar(0.07)
	_ok("2 a los 0,07 s solo ha salido el origen (paso 0)", vistos == [0], str(vistos))
	q.avanzar(0.01)
	_ok("2 a los 0,08 s sale el paso 1", vistos == [0, 1], str(vistos))
	q.avanzar(0.0)
	await process_frame
	var fin := _Fin.new()
	q.terminado.connect(func() -> void: fin.hecho = true)
	q.avanzar(2.0)
	_ok("2 al acabar emite `terminado` y se libera", fin.hecho)
	await process_frame
	await process_frame
	_ok("2 el nodo del pulso terminado ya no existe", not is_instance_valid(q))


class _Fin extends RefCounted:
	var hecho: bool = false


func _pulso_corte_en_el_aire() -> void:
	_conduce.clear()
	var cerca := Receptor.new()
	cerca.celda = Vector2i(5, 4)
	var lejos := Receptor.new()
	lejos.celda = Vector2i(5, 3)
	var al_lado_2 := Receptor.new()
	al_lado_2.celda = Vector2i(7, 5)
	var p: Pulso3D = _lanzar(Vector2i(5, 5), "", 12, [cerca, lejos, al_lado_2])
	_ok("3 sin conductor solo cuenta el origen (paso 0)", p.alcanzadas.size() == 1 and p.alcanzadas.get(Vector2i(5, 5)) == 0, str(p.alcanzadas))
	_ok("3 por el aire toca las 4 vecinas, en el paso 1 (1 casilla)", p.tocadas.size() == 4 and p.tocadas.get(Vector2i(5, 4)) == 1 and p.tocadas.get(Vector2i(6, 5)) == 1, str(p.tocadas))
	_ok("3 el pulso solo tiene 1 paso", p.pasos() == 1)
	_avanzar_a_mano(p, 0.5)
	_ok("3 una casilla pegada al emisor recibe el aviso en su paso 1 (0,08 s)", cerca.avisos == 1 and cerca.edad_aviso >= 0.08 - 1.0e-4 and cerca.edad_aviso <= 0.09 + 1.0e-4, "avisos %d, a los %.3f s" % [cerca.avisos, cerca.edad_aviso])
	_ok("3 a 2 casillas por el aire NO llega (ni por la columna ni en línea)", lejos.avisos == 0 and al_lado_2.avisos == 0)
	for r in [cerca, lejos, al_lado_2]:
		r.queue_free()


func _colores() -> void:
	_ok("4 COLOR_BASE es azulado claro (#9ED9FF)", Pulso3D.COLOR_BASE.to_html(false).to_upper() == "9ED9FF", Pulso3D.COLOR_BASE.to_html(false))
	_conduce.clear()
	var sin := Pulso3D.new()
	sin.dibujar = false
	sin.preparar([Vector2i(0, 0)], "", 3, null, _f)
	_ok("4 el pulso sin elemento lleva COLOR_BASE", sin.color == Pulso3D.COLOR_BASE and sin.elemento == "")
	var raro := Pulso3D.new()
	raro.preparar([Vector2i(0, 0)], "elemento_inventado", 3, null, _f)
	_ok("4 un elemento desconocido se pinta como el base", raro.color == Pulso3D.COLOR_BASE)
	var runas: Dictionary = {"fuego": "fire", "agua": "water", "hielo": "ice", "rayo": "lightning", "tierra": "earth", "viento": "wind", "tiempo": "time"}
	for e in runas:
		var rd: RuneData = load("res://nucleo/%s_rune.tres" % runas[e]) as RuneData
		var p := Pulso3D.new()
		p.preparar([Vector2i(0, 0)], e, 3, null, _f)
		_ok("4 el pulso de %s toma el color de su runa" % e, rd != null and p.color == rd.color and p.color != Pulso3D.COLOR_BASE, "pulso %s · runa %s" % [p.color.to_html(false), rd.color.to_html(false) if rd != null else "?"])
		p.free()
	sin.free()
	raro.free()


func _pulso_sin_reentradas() -> void:
	# Un anillo de conductores alrededor del emisor y un receptor FUERA, tocando dos casillas del anillo a la vez.
	_conduce.clear()
	for c in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 1)]:
		_conduce[c] = true
	var entre := Receptor.new()
	entre.celda = Vector2i(1, 1)                 # el hueco del anillo: toca (1,0), (2,1), (1,2) y (0,1)
	var emisor := Receptor.new()
	emisor.celda = Vector2i(0, 0)
	var p := Pulso3D.new()
	p.dibujar = false
	p.preparar([Vector2i(0, 0)], "", 12, emisor, _f)
	root.add_child(entre)
	root.add_child(emisor)
	entre.add_to_group(Pulso3D.GRUPO_PULSABLE)
	emisor.add_to_group(Pulso3D.GRUPO_PULSABLE)
	root.add_child(p)
	var veces: Dictionary = {}
	p.alcanzo.connect(func(c: Vector2i, _paso: int) -> void: veces[c] = int(veces.get(c, 0)) + 1)
	_avanzar_a_mano(p, 3.0)
	var repetida: bool = false
	for c in veces:
		if int(veces[c]) != 1:
			repetida = true
	_ok("5 en un anillo cada casilla se alcanza UNA sola vez (8 casillas con el origen)", not repetida and veces.size() == 8, str(veces))
	_ok("5 el receptor que toca cuatro casillas del frente recibe UN aviso", entre.avisos == 1, "avisos %d" % entre.avisos)
	_ok("5 el emisor no se avisa a sí mismo", emisor.avisos == 0)
	_ok("5 el aviso llega en el primer paso que lo toca (paso 2, 0,16 s: (1,0) y (0,1) son el paso 1)", entre.edad_aviso >= 0.16 - 1.0e-4 and entre.edad_aviso <= 0.17 + 1.0e-4, "a los %.3f s" % entre.edad_aviso)
	# Dos pulsos seguidos del mismo emisor son independientes: cada uno avisa una vez.
	var p2 := Pulso3D.new()
	p2.dibujar = false
	p2.preparar([Vector2i(0, 0)], "fuego", 12, emisor, _f)
	root.add_child(p2)
	_avanzar_a_mano(p2, 3.0)
	_ok("5 un segundo pulso (de fuego) vuelve a avisar, una vez más, y el receptor ve su elemento", entre.avisos == 2 and entre.elemento_visto == "fuego", "avisos %d, elemento %s" % [entre.avisos, entre.elemento_visto])
	entre.queue_free()
	emisor.queue_free()


func _pulso_avisa_y_acaba() -> void:
	# Una veta de 5 casillas y un receptor pegado al final: el aviso llega en el paso 6 (la veta es de 1 a 5; el receptor lo toca el frente un paso después).
	_conduce.clear()
	_linea(Vector2i(1, 0), Vector2i(5, 0))
	var r := Receptor.new()
	r.celda = Vector2i(6, 0)
	var p: Pulso3D = _lanzar(Vector2i(0, 0), "rayo", 12, [r])
	_ok("6 el receptor pegado al final de la veta está en `tocadas` con paso 6", p.tocadas.get(Vector2i(6, 0)) == 6, str(p.tocadas))
	p.avanzar(0.47)
	_ok("6 a los 0,47 s (antes del paso 6) aún no ha recibido nada", r.avisos == 0)
	p.avanzar(0.02)
	_ok("6 a los 0,49 s lo toca el frente y recibe un pulso de rayo", r.avisos == 1 and r.elemento_visto == "rayo", "avisos %d" % r.avisos)
	var r2 := Receptor.new()
	r2.celda = Vector2i(6, 0)
	root.add_child(r2)
	r2.add_to_group(Pulso3D.GRUPO_PULSABLE)
	var corto := Pulso3D.new()
	corto.dibujar = false
	corto.preparar([Vector2i(0, 0)], "", 4, null, _f)
	root.add_child(corto)
	_avanzar_a_mano(corto, 3.0)
	_ok("6 con alcance 4 el receptor del paso 6 no se entera (el alcance corta el pulso)", r2.avisos == 0)
	r.queue_free()
	r2.queue_free()
