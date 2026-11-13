extends "res://herramientas/escenario_base.gd"
## Tarea 19 (13/11, Juego): RENDIMIENTO DEL A* DE CASILLAS (Caminos3D) sobre mapas REALES con un lote fijo y reproducible de consultas.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_rendimiento_rutas.gd
## Por cada mapa (Bosque 01 v01 y Cueva Resonante) se cargan las escenas de verdad y se pide, con una semilla fija:
##   · «natural»: pares de casillas transitables del mapa tal cual (con ruta y, si el mapa tiene bolsas aisladas, sin ruta);
##   · «barrera»: lo mismo con una pared de DOS niveles de borde a borde en mitad del mapa (`fijar_altura`), que es el caso difícil: el A* nativo sí halla ruta
##     (solo mira solidez), la regla de altura la invalida y el A* propio recorre todo lo alcanzable antes de rendirse. Se restaura el terreno al acabar.
## Mide mediana y p99 (en us) por separado para las consultas con ruta y sin ruta, y afirma:
##   · que «hay ruta» o «no hay» coincide con las componentes conexas calculadas aquí aparte (BFS con `arista_ok`, sin tocar el código de Caminos3D);
##   · que las rutas encontradas son IDÉNTICAS casilla a casilla a las de referencia (huella del texto de todas, medida con el A* anterior a la tarea 19).
## El tiempo NO es comprobación (depende de la carga de la máquina): si el p99 sin ruta pasa de 1 ms se imprime `AVISO`.

const MAPAS: Array = [
	["Bosque 01 v01", "res://escenas/PruebaBosque01_v01.tscn"],
	["Cueva Resonante", "res://escenas/PruebaCuevaResonante.tscn"],
]
const SEMILLA: int = 20261113
const PARES_CON_RUTA: int = 300
const PARES_SIN_RUTA: int = 300
const PASADAS: int = 3                           ## cada consulta se repite en tres pasadas y las tres cuentan en la estadística (la primera es la que compara rutas)
const LIMITE_SIN_RUTA_US: float = 1000.0
## Huellas de REFERENCIA: «mapa|lote» -> [huella del texto de todas las rutas encontradas, casillas totales, consultas con ruta, consultas sin ruta].
## Medidas con el A* ANTERIOR a la tarea 19 (commit 681fc8f3). Si cambian, ya no se devuelven las mismas rutas.
const REFERENCIA: Dictionary = {
	"Bosque 01 v01|natural": [903628519, 9020, 300, 300],
	"Bosque 01 v01|barrera": [3013291275, 5817, 300, 300],
	"Cueva Resonante|natural": [3013720149, 2792, 300, 300],
	"Cueva Resonante|barrera": [66092694, 2811, 300, 300],
}

var _medir_referencia: bool = false


func _escenario() -> void:
	_medir_referencia = OS.get_cmdline_user_args().has("--referencia")
	for m in MAPAS:
		await _mapa(String(m[0]), String(m[1]))
		maqueta.queue_free()
		maqueta = null
		await avanzar(5)
		Caminos3D.reiniciar()


func _mapa(nombre: String, ruta_escena: String) -> void:
	Flags.nuevo()
	Misiones.nuevo()
	Estado.nuevo()
	Niveles.viajes.clear()
	await cargar(ruta_escena, true)
	if maqueta == null:
		return
	var red: Caminos3D = Caminos3D.compartido()
	var lado: int = Terreno3D.lado_del_mapa()
	_ok("%s: el mapa tiene rejilla de rutas" % nombre, lado > 0 and red != null, "lado %d, %d casillas con altura" % [lado, Terreno3D.alturas.size()])
	await _lote(nombre, "natural", lado)
	# Barrera de dos niveles de borde a borde: el escalón de 2 no se pasa. Se guarda lo que había para restaurarlo.
	var xb: int = lado / 2
	var antes: Dictionary = {}
	for y in range(lado):
		var c := Vector2i(xb, y)
		antes[c] = Terreno3D.altura_en(c)
		Terreno3D.fijar_altura(c, antes[c] + 2)
	await _lote(nombre, "barrera", lado)
	for c: Vector2i in antes:
		Terreno3D.fijar_altura(c, 0)
		if int(antes[c]) > 0:
			Terreno3D.fijar_altura(c, int(antes[c]))


## Componentes conexas por su cuenta (BFS de 8 vecinas con la regla pública `arista_ok` y `transitable`): la verdad contra la que se mira «hay ruta».
func _componentes(lado: int) -> PackedInt32Array:
	var comp := PackedInt32Array()
	comp.resize(lado * lado)
	comp.fill(0)
	var n: int = 0
	for y in range(lado):
		for x in range(lado):
			if comp[y * lado + x] != 0 or not Caminos3D.transitable(Vector2i(x, y)):
				continue
			n += 1
			comp[y * lado + x] = n
			var cola: Array[Vector2i] = [Vector2i(x, y)]
			var i: int = 0
			while i < cola.size():
				var u: Vector2i = cola[i]
				i += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var v := Vector2i(u.x + dx, u.y + dy)
						if v.x < 0 or v.y < 0 or v.x >= lado or v.y >= lado or comp[v.y * lado + v.x] != 0:
							continue
						if Caminos3D.transitable(v) and Caminos3D.arista_ok(u, v):
							comp[v.y * lado + v.x] = n
							cola.append(v)
	return comp


func _lote(nombre: String, lote: String, lado: int) -> void:
	var etiqueta: String = "%s|%s" % [nombre, lote]
	var comp: PackedInt32Array = _componentes(lado)
	var libres: Array[Vector2i] = []
	for y in range(lado):
		for x in range(lado):
			if comp[y * lado + x] != 0:
				libres.append(Vector2i(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA
	var con: Array = []                         # pares [a, b] con ruta
	var sin: Array = []
	var intentos: int = 0
	while (con.size() < PARES_CON_RUTA or sin.size() < PARES_SIN_RUTA) and intentos < 200000 and libres.size() > 1:
		intentos += 1
		var a: Vector2i = libres[rng.randi() % libres.size()]
		var b: Vector2i = libres[rng.randi() % libres.size()]
		if a == b:
			continue
		var mismo: bool = comp[a.y * lado + a.x] == comp[b.y * lado + b.x]
		if mismo and con.size() < PARES_CON_RUTA:
			con.append([a, b])
		elif not mismo and sin.size() < PARES_SIN_RUTA:
			sin.append([a, b])
	var red: Caminos3D = Caminos3D.compartido()
	var t_con: Array = []
	var t_sin: Array = []
	var texto: String = ""
	var casillas: int = 0
	var mal_con: int = 0
	var mal_sin: int = 0
	var rapidas0: int = int(red.get("sin_ruta_rapidas")) if "sin_ruta_rapidas" in red else 0
	for pasada in range(PASADAS):
		for par in con:
			var t0: int = Time.get_ticks_usec()
			var r: Array[Vector2i] = Caminos3D.camino(par[0], par[1])
			t_con.append(Time.get_ticks_usec() - t0)
			if pasada == 0:
				if r.is_empty() or r[0] != par[0] or r[r.size() - 1] != par[1]:
					mal_con += 1
				casillas += r.size()
				texto += str(r) + "\n"
		for par in sin:
			var t0: int = Time.get_ticks_usec()
			var r: Array[Vector2i] = Caminos3D.camino(par[0], par[1])
			t_sin.append(Time.get_ticks_usec() - t0)
			if pasada == 0 and not r.is_empty():
				mal_sin += 1
	var huella: int = texto.hash()
	_ok("%s %s: las %d consultas de pares conectados encuentran ruta" % [nombre, lote, con.size()], mal_con == 0, "%d sin ruta o mal formada" % mal_con)
	_ok("%s %s: las %d consultas entre componentes distintas no encuentran ruta" % [nombre, lote, sin.size()], mal_sin == 0, "%d con ruta" % mal_sin)
	if lote == "barrera":
		_ok("%s %s: hay consultas sin ruta (el caso difícil existe en el lote)" % [nombre, lote], sin.size() >= 100, "%d" % sin.size())
	else:
		_aviso("%s %s: consultas sin ruta en el mapa natural" % [nombre, lote], "%d (bolsas aisladas del mapa)" % sin.size())
	print("DATO  %s: huella %d, casillas %d, con ruta %d, sin ruta %d" % [etiqueta, huella, casillas, con.size(), sin.size()])
	if not _medir_referencia and REFERENCIA.has(etiqueta):
		var ref: Array = REFERENCIA[etiqueta]
		_ok("%s: las rutas son idénticas a las de referencia (huella)" % etiqueta, huella == int(ref[0]) and casillas == int(ref[1]), "huella %d (ref %d), casillas %d (ref %d)" % [huella, int(ref[0]), casillas, int(ref[1])])
		_ok("%s: mismo lote (con ruta %d, sin ruta %d)" % [etiqueta, con.size(), sin.size()], con.size() == int(ref[2]) and sin.size() == int(ref[3]))
	_estadistica("%s con ruta" % etiqueta, t_con)
	var p99_sin: float = _estadistica("%s SIN ruta" % etiqueta, t_sin)
	if "sin_ruta_rapidas" in red:
		print("DATO  %s: respuestas «sin ruta» instantáneas %d de %d" % [etiqueta, int(red.get("sin_ruta_rapidas")) - rapidas0, sin.size() * PASADAS])
	if p99_sin > LIMITE_SIN_RUTA_US:
		_aviso("%s: el p99 de las consultas SIN ruta pasa de 1 ms" % etiqueta, "%.1f us" % p99_sin)


## Imprime mediana y p99 y devuelve el p99 (us).
func _estadistica(nombre: String, us: Array) -> float:
	if us.is_empty():
		print("AVISO %s: sin consultas" % nombre)
		return 0.0
	var orden: Array = us.duplicate()
	orden.sort()
	var suma: float = 0.0
	for v in orden:
		suma += float(v)
	var mediana: float = float(orden[orden.size() / 2])
	var p99: float = float(orden[mini(orden.size() - 1, int(ceil(float(orden.size()) * 0.99)) - 1)])
	print("MEDIDA %s: n %d, media %.1f us, mediana %.1f us, p99 %.1f us, maximo %.1f us" % [nombre, orden.size(), suma / float(orden.size()), mediana, p99, float(orden[orden.size() - 1])])
	return p99
