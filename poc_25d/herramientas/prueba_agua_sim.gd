extends SceneTree
## Pruebas de AguaSim3D (Fase 11) sin ventana. Lo escribe el Juego.
## Ejecutar desde la carpeta del proyecto:
##   godot --headless --path . --script res://poc_25d/herramientas/prueba_agua_sim.gd
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
