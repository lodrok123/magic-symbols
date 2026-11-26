extends SceneTree
## Pruebas de AguaSim3D (Fase 11) sin ventana. Lo escribe el Juego.
## Ejecutar desde la carpeta del proyecto:
##   godot --headless --path . --script res://herramientas/prueba_agua_sim.gd
## Escribe una línea por comprobación (OK / FALLO) y termina con «FALLOS: n». Son las mismas siete pruebas que pasó el
## gemelo en Python antes de escribir el GDScript (12/10): si algo sale distinto aquí, el fallo está en la traducción.

const S: float = 2.3
var _fallos: int = 0


func _init() -> void:
	_hoyo()
	_presa()
	_corriente()
	_hielo()
	_charco()
	_estable()
	_hielo_mitad()
	_hielo_derretir()
	_hielo_tiempo()
	_hielo_consultas()
	_canal_estrecho()
	_paredes_borde()
	_compuerta_sin_orientacion()
	_limite_de_caudal()
	_rendimiento()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _correr(a: AguaSim3D, segundos: float) -> void:
	for _i in range(int(segundos * 60.0)):
		a.paso(1.0 / 60.0)


func _centro(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * S, 0.0, (float(c.y) + 0.5) * S)


## 1-2: pasillo de 6 casillas a 1,0 con un hoyo (casilla 3) a 0,0. 4 u³ en la casilla 0 acaban en el hoyo, y su
## superficie queda plana. El suelo se bebe las láminas finas que deja por el camino (algo de volumen se pierde).
func _hoyo() -> void:
	var a := AguaSim3D.new()
	a.configurar(6, 1, 3, S, func(c: Vector2i) -> float: return 0.0 if c.x == 3 else 1.0, func(_c: Vector2i) -> bool: return false)
	a.anadir(_centro(Vector2i(0, 0)) + Vector3(0, 1, 0), 4.0)
	var v0: float = a.volumen_total()
	_correr(a, 30.0)
	_ok("1 casi todo el volumen sigue", (v0 - a.volumen_total()) / v0 < 0.15, "%.3f -> %.3f" % [v0, a.volumen_total()])
	_ok("1 el agua acaba en el hoyo", a.profundidad_casilla(Vector2i(3, 0)) > 0.6 and a.profundidad_casilla(Vector2i(0, 0)) < 0.05,
		"hoyo %.3f origen %.3f" % [a.profundidad_casilla(Vector2i(3, 0)), a.profundidad_casilla(Vector2i(0, 0))])
	var mn: float = INF
	var mx: float = -INF
	for dx in [-0.7, 0.0, 0.7]:
		for dz in [-0.7, 0.0, 0.7]:
			var y: float = a.superficie_en(_centro(Vector2i(3, 0)) + Vector3(dx, 0, dz))
			mn = minf(mn, y)
			mx = maxf(mx, y)
	_ok("2 superficie plana en el hoyo", mx - mn < 0.01, "%.3f..%.3f" % [mn, mx])
	_ok("2 el hoyo es agua para el juego", a.es_agua_casilla(Vector2i(3, 0)))


## 3: una fila de tierra para el agua de un manantial; al quitarla, pasa.
func _presa() -> void:
	var a := AguaSim3D.new()
	a.configurar(8, 3, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	for y in range(3):
		a.solidificar_casilla(Vector2i(4, y), true)
	a.fuente_en(Vector2i(0, 1), 1.5)
	_correr(a, 20.0)
	var izq: float = 0.0
	var der: float = 0.0
	for y in range(3):
		for x in range(4):
			izq = maxf(izq, a.profundidad_casilla(Vector2i(x, y)))
		for x in range(5, 8):
			der = maxf(der, a.profundidad_casilla(Vector2i(x, y)))
	_ok("3 la tierra para el agua", izq > 0.1 and der == 0.0, "izq %.3f der %.4f" % [izq, der])
	for y in range(3):
		a.solidificar_casilla(Vector2i(4, y), false)
	a.fuente_en(Vector2i(0, 1), 0.0)
	_correr(a, 15.0)
	der = 0.0
	for y in range(3):
		for x in range(5, 8):
			der = maxf(der, a.profundidad_casilla(Vector2i(x, y)))
	_ok("3 al quitar la tierra pasa", der > 0.05, "der %.3f" % der)


## 4: manantial a la izquierda y nivel fijo bajo a la derecha: hay corriente hacia +x y el canal es agua.
func _corriente() -> void:
	var a := AguaSim3D.new()
	a.configurar(6, 1, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	a.fuente_en(Vector2i(0, 0), 2.0)
	a.fijar_nivel(Vector2i(5, 0), 0.3)
	_correr(a, 20.0)
	var v: Vector2 = a.corriente_en(_centro(Vector2i(2, 0)))
	_ok("4 corriente hacia la salida", v.x > 0.05, "vx %.3f" % v.x)
	_ok("4 el canal tiene agua", a.profundidad_casilla(Vector2i(2, 0)) > 0.25, "%.3f" % a.profundidad_casilla(Vector2i(2, 0)))


## 5: una casilla helada no deja pasar el agua.
func _hielo() -> void:
	var a := AguaSim3D.new()
	a.configurar(5, 1, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	a.helar_casilla(Vector2i(2, 0), true)
	a.llenar_casilla(Vector2i(0, 0), 0.8)
	_correr(a, 10.0)
	_ok("5 el hielo corta el paso", a.profundidad_casilla(Vector2i(3, 0)) == 0.0 and a.profundidad_casilla(Vector2i(4, 0)) == 0.0)
	_ok("5 la casilla helada no es agua", not a.es_agua_casilla(Vector2i(2, 0)))


## 6: un charco en un llano se extiende, moja, se lo bebe el suelo y luego se seca.
func _charco() -> void:
	var a := AguaSim3D.new()
	a.configurar(5, 5, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	a.anadir(_centro(Vector2i(2, 2)), 0.2 * a.l * a.l)
	_correr(a, 5.0)
	_ok("6 moja al extenderse", a.casilla_mojada(Vector2i(2, 2)))
	_correr(a, 35.0)
	_ok("6 charco absorbido", a.volumen_total() < 1.0e-6, "vol %.6f" % a.volumen_total())
	_correr(a, 25.0)
	_ok("6 se seca", not a.casilla_mojada(Vector2i(2, 2)))


## 7: estanque cerrado con una columna alta: no explota, no pierde agua y se calma.
func _estable() -> void:
	var a := AguaSim3D.new()
	a.configurar(6, 6, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	for cy in range(6):
		for cx in range(6):
			a.llenar_casilla(Vector2i(cx, cy), 0.5)
	a.anadir(_centro(Vector2i(3, 3)), 6.0 * a.l * a.l)
	var v0: float = a.volumen_total()
	var mx: float = 0.0
	for _i in range(1200):
		a.paso(1.0 / 60.0)
		for i in range(a.prof.size()):
			mx = maxf(mx, a.prof[i])
	_ok("7 estable", mx < 7.0 and absf(a.volumen_total() - v0) < 1.0e-3 * v0, "max %.2f vol %.4f -> %.4f" % [mx, v0, a.volumen_total()])
	var mn: float = INF
	var mx2: float = -INF
	for i in range(a.prof.size()):
		mn = minf(mn, a.prof[i])
		mx2 = maxf(mx2, a.prof[i])
	_ok("7 se calma", mx2 - mn < 0.02, "%.3f..%.3f" % [mn, mx2])


## Lo que cuesta un paso con el río del Bosque (19 × 49 casillas, sub 3). Solo informa; el tope es orientativo.
func _rendimiento() -> void:
	var a := AguaSim3D.new()
	a.configurar(19, 49, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	for y in range(29, 31):
		for x in range(1, 8):
			a.llenar_casilla(Vector2i(x, y), 0.5)
	var t0: int = Time.get_ticks_usec()
	for _i in range(30):
		a.paso(1.0 / 30.0)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / 30.0
	_ok("rendimiento (informativo, < 4 ms por paso)", ms < 4.0, "%.2f ms por paso" % ms)
	t0 = Time.get_ticks_usec()
	a.textura()
	_ok("imagen para el dibujo (informativo, < 20 ms)", true, "%.2f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0))


## 8 (11.12): helar la mitad de un estanque. La mitad helada no cambia ni un trocito; la otra sigue corriendo y se nivela.
func _hielo_mitad() -> void:
	var a := AguaSim3D.new()
	a.configurar(6, 3, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	for cy in range(3):
		for cx in range(6):
			a.llenar_casilla(Vector2i(cx, cy), 0.5)
	# Un círculo enorme cuyo borde cae en x = 3 casillas: casi una recta, a la izquierda queda el hielo.
	a.helar(Vector3(3.0 * S - 60.0, 0.0, 1.5 * S), 60.0, 20.0)
	var antes := PackedFloat32Array(a.prof)
	var libre_antes: float = 0.0
	var n_helados: int = 0
	for i in range(a.prof.size()):
		if a.helado[i] == 1:
			n_helados += 1
		else:
			libre_antes += a.prof[i]
	a.anadir(Vector3(4.5 * S, 0.0, 1.5 * S), 6.0, 0.8)
	libre_antes += 6.0 / (a.l * a.l)
	_correr(a, 15.0)
	var igual: bool = true
	var libre_despues: float = 0.0
	var mn: float = INF
	var mx: float = -INF
	for i in range(a.prof.size()):
		if a.helado[i] == 1:
			igual = igual and a.prof[i] == antes[i]
		else:
			libre_despues += a.prof[i]
			mn = minf(mn, a.prof[i])
			mx = maxf(mx, a.prof[i])
	_ok("8 hay hielo en la mitad izquierda", n_helados > 20 and n_helados < a.prof.size() - 20, "%d trocitos" % n_helados)
	_ok("8 el hielo no cambia ni un trocito", igual)
	_ok("8 la otra mitad conserva su volumen", absf(libre_despues - libre_antes) < 1.0e-3 * libre_antes, "%.3f -> %.3f" % [libre_antes, libre_despues])
	_ok("8 y se nivela (sigue corriendo)", mx - mn < 0.02, "%.3f..%.3f" % [mn, mx])


## 9: derretir deja el volumen total igual y suelta todo.
func _hielo_derretir() -> void:
	var a := AguaSim3D.new()
	a.configurar(5, 5, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	for cy in range(5):
		for cx in range(5):
			a.llenar_casilla(Vector2i(cx, cy), 0.4)
	var v0: float = a.volumen_total()
	var n: int = a.helar(_centro(Vector2i(2, 2)), 2.0 * S, 20.0)
	_correr(a, 3.0)
	_ok("9 el hielo conserva el volumen", absf(a.volumen_total() - v0) < 1.0e-4, "%.4f -> %.4f" % [v0, a.volumen_total()])
	var s: int = a.derretir(_centro(Vector2i(2, 2)), 2.0 * S)
	_ok("9 derretir suelta los mismos trocitos", s == n and n > 0, "helados %d, soltados %d" % [n, s])
	_correr(a, 3.0)
	_ok("9 y el volumen total es el de antes", absf(a.volumen_total() - v0) < 1.0e-4, "%.4f" % a.volumen_total())
	_ok("9 la casilla ya no está helada", not a.casilla_helada(Vector2i(2, 2)))


## 10: a los 20 s se suelta sola, y mientras tanto es hielo (no se absorbe aunque sea una lámina fina).
func _hielo_tiempo() -> void:
	var a := AguaSim3D.new()
	a.configurar(3, 3, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	a.llenar_casilla(Vector2i(1, 1), 0.2)
	a.helar(_centro(Vector2i(1, 1)), S, 20.0)
	var cam1: Array = a.cambios_hielo()
	_ok("10 se hiela y cambios_hielo lo avisa", a.casilla_helada(Vector2i(1, 1)) and cam1.size() == 1 and bool(cam1[0]["helada"]), "%s" % [cam1])
	_correr(a, 19.0)
	_ok("10 a los 19 s sigue helada", a.casilla_helada(Vector2i(1, 1)))
	_ok("10 sin absorberse en 19 s", absf(a.profundidad_casilla(Vector2i(1, 1)) - 0.2) < 1.0e-4, "%.4f" % a.profundidad_casilla(Vector2i(1, 1)))
	_correr(a, 2.0)
	_ok("10 a los 21 s se ha soltado sola", not a.casilla_helada(Vector2i(1, 1)))
	var cam: Array = a.cambios_hielo()
	_ok("10 cambios_hielo avisa de que se soltó sola", cam.size() == 1 and not bool(cam[0]["helada"]), "%s" % [cam])
	_ok("10 y no repite el aviso", a.cambios_hielo().is_empty())


## 11: consultas y textura.
func _hielo_consultas() -> void:
	var a := AguaSim3D.new()
	a.configurar(4, 4, 3, S, func(_c: Vector2i) -> float: return 0.5, func(_c: Vector2i) -> bool: return false)
	for cy in range(4):
		for cx in range(4):
			a.llenar_casilla(Vector2i(cx, cy), 1.5)
	var p: Vector3 = _centro(Vector2i(1, 1))
	_ok("11 sin hielo: hielo_en = -INF, no hay casilla helada", a.hielo_en(p) == -INF and not a.casilla_helada(Vector2i(1, 1)) and a.espesor_hielo(Vector2i(1, 1)) == 0.0)
	a.helar(p, S, 20.0)
	_ok("11 hielo_en = cara de arriba (suelo + agua)", absf(a.hielo_en(p) - 1.5) < 1.0e-4, "%.4f" % a.hielo_en(p))
	_ok("11 espesor = profundidad media del hielo", absf(a.espesor_hielo(Vector2i(1, 1)) - 1.0) < 1.0e-4, "%.4f" % a.espesor_hielo(Vector2i(1, 1)))
	_ok("11 hielo_en_casilla coincide", absf(a.hielo_en_casilla(Vector2i(1, 1)) - 1.5) < 1.0e-4)
	_ok("11 fuera del hielo: -INF", a.hielo_en(_centro(Vector2i(3, 3))) == -INF)
	var img: Image = a.imagen_hielo()
	_ok("11 textura_hielo() devuelve una textura", a.textura_hielo() != null)
	var i_hielo: int = int(floorf(p.z / a.l)) * a.w + int(floorf(p.x / a.l))
	var px: Color = img.get_pixel(i_hielo % a.w, i_hielo / a.w)
	_ok("11 textura_hielo: R = 1 y G = 1 al helar", img.get_format() == Image.FORMAT_RG8 and img.get_width() == a.w and px.r > 0.99 and px.g > 0.99, "R %.2f G %.2f" % [px.r, px.g])
	var lejos: Color = img.get_pixel(a.w - 1, a.h - 1)
	_ok("11 textura_hielo: 0 donde no hay", lejos.r == 0.0 and lejos.g == 0.0)
	_correr(a, 10.0)
	px = a.imagen_hielo().get_pixel(i_hielo % a.w, i_hielo / a.w)
	_ok("11 textura_hielo: G baja con el tiempo (~0,5 a los 10 s)", absf(px.g - 0.5) < 0.05, "G %.2f" % px.g)
	_correr(a, 11.0)
	px = a.imagen_hielo().get_pixel(i_hielo % a.w, i_hielo / a.w)
	_ok("11 textura_hielo: vacía al soltarse", px.r == 0.0 and px.g == 0.0)



## 12: canal estrecho (12/10, canal de la tinaja). Solo el centro y los lados que se pasan quedan abiertos; la fuente y la
## profundidad cuentan solo los abiertos; la forma sobrevive a abrir/cerrar y a refrescar la casilla.
func _canal_estrecho() -> void:
	var a := AguaSim3D.new()
	a.configurar(5, 3, 3, S, func(_c: Vector2i) -> float: return 1.0, func(_c: Vector2i) -> bool: return false)
	var c := Vector2i(2, 1)
	a.abrir_solo(c, [Vector2i(-1, 0), Vector2i(1, 0)])
	var ab: Array = []
	var t: PackedInt32Array = a._trozos(c)
	for k in range(9):
		if a.cerrado[t[k]] == 0:
			ab.append(k)
	_ok("12 abrir_solo deja centro + 2 lados", ab == [3, 4, 5], str(ab))
	a.sumar_fuente(c, 0.9)
	var f: float = 0.0
	var fuera: float = 0.0
	for k in range(9):
		if ab.has(k):
			f += a.fuente[t[k]]
		else:
			fuera += a.fuente[t[k]]
	_ok("12 la fuente se reparte solo entre los abiertos (0,3 cada uno)", absf(f - 0.9) < 1.0e-5 and fuera == 0.0 and absf(a.fuente[t[4]] - 0.3) < 1.0e-5)
	a.sumar_fuente(c, -0.9)
	var libre: bool = true
	for i in t:
		libre = libre and a.fuente[i] == 0.0
	_ok("12 y se retira del mismo reparto", libre)
	# Profundidad: media de los abiertos.
	a.prof[t[3]] = 0.3
	a.prof[t[4]] = 0.3
	a.prof[t[5]] = 0.3
	_ok("12 profundidad_casilla = media de los abiertos (0,3, no 0,1)", absf(a.profundidad_casilla(c) - 0.3) < 1.0e-5, "%.3f" % a.profundidad_casilla(c))
	a.prof[t[3]] = 0.0
	a.prof[t[4]] = 0.0
	a.prof[t[5]] = 0.0
	# La forma se mantiene al cerrar/abrir y al refrescar.
	a.solidificar_casilla(c, true)
	_ok("12 cerrada del todo: profundidad 0 y todo cerrado", a.profundidad_casilla(c) == 0.0 and a._trozos_abiertos(c).is_empty())
	a.solidificar_casilla(c, false)
	_ok("12 al abrir recupera su forma estrecha (3 abiertos)", a._trozos_abiertos(c).size() == 3)
	a.refrescar_casilla(c)
	_ok("12 refrescar_casilla no la ensancha", a._trozos_abiertos(c).size() == 3)
	# El agua corre por el canal, de lado a lado, y no sale por los cerrados.
	for cx in range(5):
		if cx != 2:
			a.solidificar_casilla(Vector2i(cx, 1), false)
	var ab2: PackedInt32Array = a._trozos_abiertos(Vector2i(0, 1))
	_ok("12 las casillas normales siguen con sus 9 trocitos", ab2.size() == 9)
	a.llenar_casilla(Vector2i(0, 1), 1.6)
	_correr(a, 6.0)
	var vecina_arriba: float = 0.0
	for i in a._trozos(Vector2i(2, 0)):
		vecina_arriba += a.prof[i]
	_ok("12 el agua pasa por el canal hacia el otro lado", a.profundidad_casilla(Vector2i(4, 1)) > 0.01, "%.3f" % a.profundidad_casilla(Vector2i(4, 1)))
	_ok("12 sin agua en los cerrados del canal", a.prof[t[0]] == 0.0 and a.prof[t[1]] == 0.0 and a.prof[t[2]] == 0.0 and a.prof[t[6]] == 0.0 and a.prof[t[7]] == 0.0 and a.prof[t[8]] == 0.0)
	a.quitar_estrecho(c)
	_ok("12 quitar_estrecho la devuelve a 9 trocitos", a._trozos_abiertos(c).size() == 9)


## 13 (26/11): PAREDES ENTRE TROCITOS. Un hoyo de una casilla (suelo 0) rodeado de suelo a 1,0 y lleno a 1,5 u (0,5 por encima del borde). Sin paredes el agua rebosa y se
## reparte por el llano; con `paredes_casilla` en sus 4 lados el hoyo es un recipiente de verdad: retiene el nivel, no moja nada de fuera y conserva el volumen. Quitar la
## pared devuelve el rebose. Las paredes son siempre simétricas.
func _paredes_borde() -> void:
	var lados: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var hoyo := Vector2i(2, 1)
	var res: Dictionary = {}
	for con_pared in [false, true]:
		var a := AguaSim3D.new()
		a.configurar(5, 3, 3, S, func(c: Vector2i) -> float: return 0.0 if c == hoyo else 1.0, func(_c: Vector2i) -> bool: return false)
		if con_pared:
			a.paredes_casilla(hoyo, lados, true)
		a.llenar_casilla(hoyo, 1.5)
		var v0: float = a.volumen_total()
		_correr(a, 20.0)
		var fuera: float = 0.0
		for cy in range(3):
			for cx in range(5):
				if Vector2i(cx, cy) != hoyo:
					fuera += a.profundidad_casilla(Vector2i(cx, cy))
		res[con_pared] = {"fuera": fuera, "nivel": a.profundidad_casilla(hoyo), "dv": absf(a.volumen_total() - v0), "v0": v0, "a": a}
	_ok("13 sin paredes el hoyo rebosa hasta el borde (control)", float(res[false]["nivel"]) < 1.05, "nivel %.3f, fuera %.3f" % [res[false]["nivel"], res[false]["fuera"]])
	_ok("13 con paredes retiene su nivel (1,5 u) y no moja nada de fuera", absf(float(res[true]["nivel"]) - 1.5) < 1.0e-4 and float(res[true]["fuera"]) == 0.0, "nivel %.4f, fuera %.4f" % [res[true]["nivel"], res[true]["fuera"]])
	_ok("13 y el volumen se conserva (con y sin paredes)", float(res[true]["dv"]) < 1.0e-4 * float(res[true]["v0"]) and float(res[false]["dv"]) < 0.5 * float(res[false]["v0"]),
		"con paredes: %.6f u³ de diferencia; sin ellas: %.3f (el llano que moja se lo bebe el suelo), de %.2f u³" % [res[true]["dv"], res[false]["dv"], res[true]["v0"]])
	var b: AguaSim3D = res[true]["a"]
	var simetrica: bool = true
	var n_bloq: int = 0
	for i in range(b.w * b.h):
		for k in range(4):
			var j: int = b.vecinos[i * 4 + k]
			if b.pared_borde[i * 4 + k] == 1:
				n_bloq += 1
				simetrica = simetrica and j >= 0 and b.pared_borde[j * 4 + (k ^ 1)] == 1
	_ok("13 las paredes son simétricas (12 bordes de trocito por lado de la casilla, ×2 sentidos ×4 lados)", simetrica and n_bloq == 3 * 2 * 4, "%d entradas" % n_bloq)
	b.paredes_casilla(hoyo, lados, false)
	_correr(b, 20.0)
	var fuera2: float = 0.0
	for cy in range(3):
		for cx in range(5):
			if Vector2i(cx, cy) != hoyo:
				fuera2 += b.profundidad_casilla(Vector2i(cx, cy))
	_ok("13 quitar las paredes devuelve el rebose", b.profundidad_casilla(hoyo) < 1.05, "nivel %.3f" % b.profundidad_casilla(hoyo))
	# El reparto al cerrar un trocito no manda agua por un borde con pared.
	var c := AguaSim3D.new()
	c.configurar(3, 1, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	c.pared_entre(Vector2i(0, 0), Vector2i(1, 0), true)
	c.llenar_casilla(Vector2i(0, 0), 0.5)
	c.solidificar_casilla(Vector2i(1, 0), true)
	_ok("13 pared_entre fuera del mapa no hace nada y cerrar la vecina no pasa agua por la pared", c.profundidad_casilla(Vector2i(0, 0)) >= 0.5 - 1.0e-6)
	c.pared_entre(Vector2i(0, 0), Vector2i(-1, 0), true)


## Monta una compuerta de verdad (Compuerta3D) sobre la casilla `c` de la simulación `a` y la abre sin pasar por el árbol (`_aplicar`): lo mismo que haría `abrir()` sin el sonido.
func _compuerta(a: AguaSim3D, c: Vector2i, vertical: Variant, tarda: float = 0.0, estrecha: bool = true) -> Compuerta3D:
	Terreno3D.agua_sim = a
	var k := Compuerta3D.new()
	k.estrecha = estrecha
	k.tarda = tarda
	k.preparar(c, false, "", "", vertical)
	a.solidificar_casilla(c, true)
	return k


func _abrir_compuerta(k: Compuerta3D) -> void:
	k.abierta = true
	k._aplicar(false)


func _soltar_compuerta(k: Compuerta3D) -> void:
	Terreno3D.cauces_abiertos.erase(k.celda)
	Terreno3D.cauces_a_ras.erase(k.celda)
	Terreno3D.agua_sim = null
	k.free()


## 14 (26/11): una compuerta deja pasar el agua sea cual sea su `vertical`. Pasillo este-oeste (5×1) y pasillo norte-sur (1×5), agua en las dos primeras casillas, compuerta en la
## tercera; antes `vertical` mal puesto (no en el pasillo E-O, sí en el N-S) no dejaba pasar nada. Cerrada no pasa nada. Además `vertical` no dado orienta solo la losa.
func _compuerta_sin_orientacion() -> void:
	for eje in ["EO", "NS"]:
		for vertical in [null, true, false]:
			var a := AguaSim3D.new()
			var ew: bool = eje == "EO"
			a.configurar(5 if ew else 1, 1 if ew else 5, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
			var celda: Callable = func(i: int) -> Vector2i: return Vector2i(i, 0) if ew else Vector2i(0, i)
			a.llenar_casilla(celda.call(0), 0.8)
			a.llenar_casilla(celda.call(1), 0.8)
			var k: Compuerta3D = _compuerta(a, celda.call(2), vertical)
			_correr(a, 5.0)
			var cerrada_ok: bool = a.profundidad_casilla(celda.call(3)) == 0.0 and a.profundidad_casilla(celda.call(4)) == 0.0
			var v0: float = a.volumen_total()
			_abrir_compuerta(k)
			_correr(a, 15.0)
			var etiqueta: String = "%s vertical=%s" % [eje, "(sola)" if vertical == null else str(vertical)]
			_ok("14 compuerta %s: cerrada no pasa y abierta sí (4.ª y 5.ª casillas reciben agua)" % etiqueta,
				cerrada_ok and a.profundidad_casilla(celda.call(4)) > 0.05 and a.profundidad_casilla(celda.call(3)) > 0.05,
				"casilla 3: %.3f, casilla 4: %.3f" % [a.profundidad_casilla(celda.call(3)), a.profundidad_casilla(celda.call(4))])
			_ok("14 compuerta %s: el volumen se conserva (salvo la lámina fina que se bebe el suelo)" % etiqueta, absf(a.volumen_total() - v0) < 0.02 * v0, "%.3f -> %.3f" % [v0, a.volumen_total()])
			if vertical == null:
				_ok("14 compuerta %s: la losa se orienta sola (norte-sur en el pasillo E-O, y al revés)" % etiqueta, k.vertical == ew, "vertical=%s" % str(k.vertical))
			_soltar_compuerta(k)


## Un depósito de 2 casillas de fondo y `ancho_d` de ancho con agua a 0,4 u, vaciado por una compuerta de la columna siguiente (fila 1; la fila 0 de esa columna y la siguiente es pared)
## hacia un desagüe de nivel fijo 0,02 u. `modo`: "estrecha" (el hueco de siempre), "entera" (abierta entera, sin límite) o la `tarda` en s. Devuelve {t25, t05, q, vol}: segundos hasta que
## ninguna casilla del depósito pasa de 0,25 u y de 0,05 u (-1 si no llega en 120 s), el límite que puso la compuerta y el volumen inicial del depósito.
func _vaciado(ancho_d: int, modo: Variant) -> Dictionary:
	var a := AguaSim3D.new()
	var gx: int = ancho_d
	a.configurar(ancho_d + 2, 2, 3, S, func(_c: Vector2i) -> float: return 0.0, func(c: Vector2i) -> bool: return c.y == 0 and c.x >= gx)
	var celdas: Array = []
	var vol: float = 0.0
	for cy in range(2):
		for cx in range(ancho_d):
			celdas.append(Vector2i(cx, cy))
			a.llenar_casilla(Vector2i(cx, cy), 0.4)
	vol = a.volumen_total()
	a.fijar_nivel(Vector2i(gx + 1, 1), 0.02)
	var tarda: float = float(modo) if (modo is float or modo is int) else 0.0
	var k: Compuerta3D = _compuerta(a, Vector2i(gx, 1), null, tarda, str(modo) == "estrecha")
	_abrir_compuerta(k)
	var q: float = a.limite_de(Vector2i(gx, 1))
	var t25: float = -1.0
	var t05: float = -1.0
	for paso in range(120 * 30):
		a.paso(1.0 / 30.0)
		var mx: float = 0.0
		for c in celdas:
			mx = maxf(mx, a.profundidad_casilla(c))
		var t: float = float(paso + 1) / 30.0
		if t25 < 0.0 and mx < 0.25:
			t25 = t
		if mx < 0.05:
			t05 = t
			break
	_soltar_compuerta(k)
	return {"t25": t25, "t05": t05, "q": q, "vol": vol}


## 15 (26/11): LÍMITE DE CAUDAL. Primero lo que se puede garantizar: el tope se cumple y el volumen se conserva exactamente (un depósito a 1,0 u que se vacía por una casilla limitada
## a 0,5 u³/s hacia un recipiente cerrado; mientras el depósito da más que q, el recipiente gana q·dt por paso, ni un pelo más). Después se MIDE el vaciado de un depósito de ancho 5 y
## otro de 11 (ver `_vaciado`): con el hueco de siempre, con la compuerta entera sin límite y con `tarda` de 8, 20 y 40 s. RESULTADO HONESTO: el límite es una COTA MÍNIMA del tiempo, no
## lo hace independiente del ancho: el agua del fondo de una sala ancha tarda en llegar a la boca por sí sola (el tiempo crece con el ancho al cuadrado), y con tarda=8 el tope ni llega a
## actuar (da lo mismo que sin él). Solo con tarda grande (40 s) el ancho se nota menos. Se afirma lo que es verdad: q = V/tarda, el vaciado no baja de la cota, y el cociente 11/5 baja al subir tarda.
func _limite_de_caudal() -> void:
	var a := AguaSim3D.new()
	a.configurar(7, 1, 3, S, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	for cx in range(3):
		a.llenar_casilla(Vector2i(cx, 0), 1.0)
	for cx in range(4, 7):
		a.llenar_casilla(Vector2i(cx, 0), 0.2)
	a.limitar_paso(Vector2i(3, 0), 0.5)
	a.llenar_casilla(Vector2i(3, 0), 0.6)
	_ok("15 limite_de devuelve el tope puesto y INF si no hay", a.limite_de(Vector2i(3, 0)) == 0.5 and a.limite_de(Vector2i(2, 0)) == INF)
	var v0: float = a.volumen_total()
	var gana_max: float = 0.0
	var der_ini: float = 0.0
	var der_5s: float = 0.0
	for cx in range(4, 7):
		der_ini += a.profundidad_casilla(Vector2i(cx, 0))
	var prev: float = der_ini
	for paso in range(30 * 20):
		a.paso(1.0 / 30.0)
		var der: float = 0.0
		for cx in range(4, 7):
			der += a.profundidad_casilla(Vector2i(cx, 0))
		# volumen que entra en el lado derecho este paso = (Δ de la suma de profundidades) · área de una casilla (sub² trocitos de l²) / sub² por trocito... la media por casilla × S²
		gana_max = maxf(gana_max, (der - prev) * S * S * 30.0)
		prev = der
		if paso == 30 * 5 - 1:
			der_5s = der
	var gana_5s: float = (der_5s - der_ini) * S * S / 5.0
	_ok("15 el tope se cumple: lo que sale de la casilla limitada nunca pasa de q (0,5 u³/s)", gana_max <= 0.5 * 1.001, "máximo %.4f u³/s" % gana_max)
	_ok("15 y mientras la física da más, sale justo q (media de los 5 primeros s)", absf(gana_5s - 0.5) < 0.03, "%.4f u³/s" % gana_5s)
	_ok("15 el volumen se conserva exactamente con el límite", absf(a.volumen_total() - v0) < 1.0e-4 * v0, "%.5f -> %.5f" % [v0, a.volumen_total()])
	a.quitar_limite(Vector2i(3, 0))
	_ok("15 quitar_limite lo retira", a.limite_de(Vector2i(3, 0)) == INF)
	# Medidas de vaciado.
	var modos: Array = ["estrecha", "entera", 8.0, 20.0, 40.0]
	var res: Dictionary = {}
	for modo in modos:
		for ancho_d in [5, 11]:
			res[[modo, ancho_d]] = _vaciado(ancho_d, modo)
	for modo in modos:
		var m5: Dictionary = res[[modo, 5]]
		var m11: Dictionary = res[[modo, 11]]
		print("      [15] %-8s ancho 5: <0,25 u en %5.1f s, <0,05 u en %5.1f s%s | ancho 11: %5.1f s y %5.1f s%s | cociente 11/5: %.2f (<0,25) y %.2f (<0,05)" % [
			str(modo), m5["t25"], m5["t05"], (" (q %.2f)" % m5["q"]) if m5["q"] != INF else "", m11["t25"], m11["t05"], (" (q %.2f)" % m11["q"]) if m11["q"] != INF else "",
			float(m11["t25"]) / maxf(float(m5["t25"]), 0.01), float(m11["t05"]) / maxf(float(m5["t05"]), 0.01)])
	for t_ in [8.0, 20.0, 40.0]:
		var m5: Dictionary = res[[t_, 5]]
		var m11: Dictionary = res[[t_, 11]]
		var cota: float = 0.95 * t_ * (1.0 - 0.05 / 0.4)        # bajar de 0,05 u de 0,4 u saca el 87,5 % del volumen: no puede ser antes que eso a caudal q
		_ok("15 tarda=%d: q = volumen del depósito / tarda y el vaciado (<0,05 u) no baja de la cota (%.1f s)" % [int(t_), cota],
			absf(float(m5["q"]) - float(m5["vol"]) / t_) < 0.02 * float(m5["q"]) and absf(float(m11["q"]) - float(m11["vol"]) / t_) < 0.02 * float(m11["q"]) and float(m5["t05"]) >= cota and float(m11["t05"]) >= cota,
			"q5 %.3f, q11 %.3f; vaciado %.1f s (ancho 5) y %.1f s (ancho 11), cociente %.2f" % [m5["q"], m11["q"], m5["t05"], m11["t05"], float(m11["t05"]) / maxf(float(m5["t05"]), 0.01)])
	var r8: float = float(res[[8.0, 11]]["t05"]) / float(res[[8.0, 5]]["t05"])
	var r40: float = float(res[[40.0, 11]]["t05"]) / float(res[[40.0, 5]]["t05"])
	_ok("15 el cociente de tiempos 11/5 baja al subir tarda (8 s: %.2f; 40 s: %.2f); NO llega a 1 (ver arriba)" % [r8, r40], r40 < r8 and r40 > 1.0)