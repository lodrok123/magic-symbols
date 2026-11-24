extends RefCounted
## GENERADOR DE MAZMORRAS Y CUEVAS (17/11/2026). Datos puros, sin nodos: de unos parámetros y una semilla saca un plano de letras como los de
## `mundo/datos_nivel/mapas/*.txt` y las líneas `; pieza` / `; puzle` que lee `Puzle3D`. Lo usa la herramienta visual
## `herramientas/generador_mapas/GeneradorMapas.tscn` y lo comprueba `herramientas/prueba_generador_mapas.gd`.
## Sin `class_name` a propósito: se carga con `preload` y no obliga a reimportar el proyecto.
##
## TRES ALGORITMOS (`algoritmo`), escritos desde cero a partir de cómo trabajan tres generadores conocidos (no se copia código de ninguno):
##   «salas»   Salas y pasillos al estilo de donjon (donjon.bin.sh). Rejilla lógica donde las posiciones impares son huecos y las pares muros: se
##             reparten salas, se les abren puertas, se rellena lo demás con un laberinto (con querencia a seguir recto) y se podan los callejones.
##             Aquí, además, cada hueco lógico se pinta con `ancho_pasillo` casillas, para que los pasillos no sean de una sola casilla.
##   «cueva»   Cueva orgánica por autómata celular (la familia del Cave Generator de watabou): ruido, suavizado, se unen las regiones sueltas y se
##             inunda lo más bajo de un mapa de ruido (`agua`).
##   «pagina»  Mazmorra de «una página» (la idea del One Page Dungeon de watabou): crece desde una sala raíz pegando salas y pasillos a las que ya
##             hay, con grupos simétricos respecto al eje de la entrada, y luego se añaden bucles para que no sea un árbol puro.
##   «bosque»  (24/11) ESPACIO ABIERTO, no mazmorra: claros unidos por CAMINOS SINUOSOS de tierra (`g`) entre masas de árboles, con hierba
##             corta y alta alrededor, un RÍO que cruza el mapa con vados de piedra donde lo pisa un camino, SALIDAS EN EL BORDE que se pidan
##             (`lados_salida`) y, si se quiere, un PASO DE TIERRA: muros agrietados en el camino de una salida, que se rompen con tierra.
##             Sin puertas ni cerrojos; la cámara se frena solo en el borde del mapa. Ver `_gen_bosque`.
##
## DESPUÉS, IGUAL PARA LOS TRES (`_poblar`): inicio (S) en la sala más al sur, sala del tesoro en la más lejana (tras una puerta con llave si se
## puede), cofre de la llave en otra sala lejana, goblins (W / A) según el tamaño y la distancia, salas que se cierran hasta limpiarlas (cerrojo +
## vigía), charcas, braseros (T) y jarrones. Nada de lo que bloquea una casilla puede cortar el paso: se comprueba con un relleno cada vez.
##
## Uso:   var gen = preload("res://herramientas/generador_mapas/generador_mazmorra.gd").new()
##        var mapa: Dictionary = gen.generar({"algoritmo": "salas", "semilla": 7})
## `retoques` (casilla → "#", "." o "~") son los cambios pintados a mano en la herramienta: se aplican al plano antes de poblarlo.

const Catalogo = preload("res://herramientas/generador_mapas/catalogo_puzles.gd")

const MURO: int = 0
const SUELO: int = 1
const AGUA: int = 2
const LETRA: Array[String] = ["#", ".", "~"]
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]      ## N, E, S, O
const ALGORITMOS: Array[String] = ["salas", "cueva", "pagina", "bosque"]
const ANCHO_MAX: int = 120
const ALTO_MAX: int = 120
const CASILLAS_POR_ENEMIGO: float = 22.0     ## con `enemigos` = 1: un goblin por cada tantas casillas libres de la sala (más en las lejanas), 5 como mucho

# Banderas de la rejilla lógica de «salas».
const _B: int = 1       ## bloqueada por la forma del mapa
const _R: int = 2       ## sala
const _C: int = 4       ## pasillo
const _P: int = 8       ## perímetro de una sala (donde puede ir una puerta)
const _D: int = 16      ## puerta

var p: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var w: int = 0
var h: int = 0
var g: PackedByteArray = PackedByteArray()
var salas: Array = []                 ## {id, rect: Rect2i, rol, eje, gemela, viva, enemigos, dist}
var puertas: Array = []               ## {c: Vector2i, salas: Array[int], tipo: "paso" | "llave" | "cerrojo"}
var letras: Dictionary = {}           ## casilla → letra del plano (S, W, A, T)
var objetos: Array = []               ## {c, tipo, id}: lo que la vista dibuja encima
var lineas: PackedStringArray = PackedStringArray()
var avisos: PackedStringArray = PackedStringArray()
var inicio: Vector2i = Vector2i(-1, -1)

var _ocupada: Dictionary = {}
var _bloqueos: Dictionary = {}
var _cont: Dictionary = {}
var _L: PackedInt32Array = PackedInt32Array()
var _Lid: PackedInt32Array = PackedInt32Array()
var _lw: int = 0
var _lh: int = 0
var _lsalas: Array = []
var _eje: int = 0
var _retoques: Dictionary = {}


static func parametros_defecto() -> Dictionary:
	return {
		"algoritmo": "salas", "semilla": 1, "ancho": 40, "alto": 34,
		# «salas» (tamaños en huecos lógicos: una sala de 3 con pasillo de 2 mide 8 casillas)
		"sala_min": 2, "sala_max": 4, "reparto": "dispersas", "densidad_salas": 1.0, "puertas": 50,
		"recto": 60, "callejones": 100, "ancho_pasillo": 2, "forma": "rectangulo",
		# «cueva»
		"relleno": 56, "suavizados": 2, "region_min": 12, "agua": 8, "silueta": 60, "metodo": "fractal", "octavas": 4, "tamano_sala": 10.0,
		# «pagina» (tamaños en casillas)
		"n_salas": 9, "lado_min": 4, "lado_max": 8, "simetria": true, "pasillos": 30, "bucles": 30,
		# «bosque» (24/11, Pablo: «primera pasada de los bosques con el generador, como espacio abierto»).
		"claros": 6, "tamano_claro": 5, "ancho_camino": 2, "sinuosidad": 50, "bucles_claros": 30, "apertura": 55, "rio": "ns", "ancho_rio": 2,
		"hierba_alta": 15, "lados_salida": "", "paso_tierra": 0, "ancho_precipicio": 2,
		# contenido
		"enemigos": 1.0, "arqueros": 30, "jarrones": 1.0, "braseros": 1.0, "charcas": 20,
		"tesoro": true, "llave": true, "salas_cerradas": 40,
		# 22/11 (Pablo: «sala campamento»): cuántas salas grandes se vuelven CAMPAMENTO GOBLIN (ver `_poner_campamentos`). 0 = ninguno (como antes).
		"campamentos": 0,
		"puzles": 0, "barreras": 2, "b_braseros": true, "b_placa": true, "b_puente": true,
		# nivel
		"nombre": "MazmorraGen", "estilo": "cueva", "luz": "cueva", "salida_a": "", "rotulo": true,
		# terreno: `terreno` pinta tierra en los pasillos y losas en la sala del tesoro (para que haya juntas entre suelos distintos);
		# `acabado` = el acabado de serie de la maqueta (orillas y juntas); con false la escena se exporta con él apagado.
		"terreno": true, "acabado": true,
		# `camara_sala`: la cámara se frena en el borde de cada sala y se acerca poco a poco en las pequeñas (CamaraSalas).
		"camara_sala": true,
	}


## Barreras (17/11, ver _poblar 4c): pasos obligados cerrados por una PUERTA o un PUENTE plegado, que abre un ACTIVADOR (braseros + contador,
## o placa de peso + bloque empujable) colocado donde se llega sin cruzar la barrera. `enlaces_mano` (id de barrera → id de activador, o "")
## cambia a mano qué abre qué; una barrera sin enlace, o un enlace que deja el mapa sin solución, va a `errores` y el mapa no se exporta.
var errores: PackedStringArray = PackedStringArray()
var enlaces: Array = []                ## {de: Vector2i, a: Vector2i, de_id, a_id, fijo}: lo que la vista dibuja como vínculo
var _puentes: Dictionary = {}          ## casillas de agua con puente: cuentan como tierra (se cruzan cuando el puente está tendido)
var _barreras: Array = []              ## {id, tipo: "puerta" | "puente", celdas, pos, act}
var _activadores: Dictionary = {}      ## id → {id, tipo, celdas (a las que hay que llegar), pos, senal}
var _enlaces_mano: Dictionary = {}
var _llave_barrera: Dictionary = {}    ## la puerta con llave como barrera: {celdas, act_celdas}


var puzles_puestos: Dictionary = {}     ## sala -> puzle del catalogo que lleva
var _puzles_mano: Dictionary = {}       ## sala -> puzle del catalogo pedido a mano
var _n_cat: int = 0
## Elementos movidos a mano (18/11): casilla donde el generador lo puso → casilla donde se quiere. Ver `_aplicar_movidos`.
var _movidos_pedidos: Dictionary = {}
var movidos_hechos: Dictionary = {}     ## lo que de verdad se movió: casilla de origen → casilla donde ha quedado (puede no ser la pedida)
## Lo que se puede mover a mano. Las puertas, los puentes y los cerrojos no (son la forma del mapa); las piezas de un puzle del catálogo
## tampoco: el puzle entero se mueve de sala en la pestaña «Puzles».
const MOVIBLES: Array[String] = ["guerrero", "arquero", "brasero", "jarron", "cofre_tesoro", "cofre_llave", "salida", "entrada", "inicio",
	"limo", "golem", "chaman", "mouro", "elemental", "cofre_comun", "cofre_epico", "cofre_legendario"]

## ENEMIGOS que se pueden añadir a mano (18/11, pestaña «Enemigos»). Son los que el juego sabe montar desde un mapa de letras sin guion
## de nivel: los goblins y el elemental van por LETRA; limo, gólem, chamán y mouro, por línea `; pieza` (escenas/puzle.gd).
## No están el loberno, el canouro ni el goblin asesino: esos los crea el guion de cada nivel hecho a mano leyendo `; marcador`, y un
## mapa generado no lleva guion. Tampoco la Santa Compaña (pide un camino de casillas). `icono` = el tipo con que se dibuja.
const ORDEN_ENEMIGOS: Array[String] = ["guerrero", "arquero", "limo", "limo_fuego", "limo_agua", "limo_tierra", "limo_grande", "golem", "chaman", "mouro", "elemental"]
const ENEMIGOS: Dictionary = {
	"guerrero": {"titulo": "Goblin guerrero", "letra": "W", "icono": "guerrero"},
	"arquero": {"titulo": "Goblin arquero", "letra": "A", "icono": "arquero"},
	"limo": {"titulo": "Limo", "pieza": "limo", "icono": "limo"},
	"limo_fuego": {"titulo": "Limo de fuego", "pieza": "limo", "extra": " elemento=fuego", "icono": "limo"},
	"limo_agua": {"titulo": "Limo de agua", "pieza": "limo", "extra": " elemento=agua", "icono": "limo"},
	"limo_tierra": {"titulo": "Limo de tierra", "pieza": "limo", "extra": " elemento=tierra", "icono": "limo"},
	"limo_grande": {"titulo": "Limo grande", "pieza": "limo", "extra": " grande=si", "icono": "limo"},
	"golem": {"titulo": "Gólem de piedra", "pieza": "golem", "icono": "golem"},
	"chaman": {"titulo": "Chamán goblin", "pieza": "chaman", "icono": "chaman"},
	"mouro": {"titulo": "Mouro (espectro)", "pieza": "mouro", "icono": "mouro"},
	"elemental": {"titulo": "Elemental del bosque (jefe)", "letra": "G", "icono": "elemental"},
}

## COFRES que se pueden añadir a mano (pestaña «Cofres»), por CALIDAD (Pablo, 18/11: «pedir calidad; recompensa aleatoria para los
## comunes y recompensas específicas para épico y legendario»).
##   · común: la recompensa se SORTEA entre `premios` (con la semilla del mapa y el número del cofre: sale siempre la misma para el mismo mapa).
##   · épico (`modelo=epico`): una recompensa concreta, a elegir de `premios` (texto de `da=` → cómo se dice).
##   · legendario (`modelo=legendario`): un GLIFO del libro (`glifo=`, con su secuencia de cofre legendario) y un botín fijo; o sin glifo.
const ORDEN_COFRES: Array[String] = ["comun", "epico", "legendario"]
const COFRES: Dictionary = {
	"comun": {"titulo": "Común", "modelo": "", "premios": ["oro:20", "oro:30", "oro:45", "oro:25+pocion:1", "pocion:2", "oro:15+tonico_tinta:1",
		"oro:20+antidoto:1", "oro:20+esquirla_cristal:2", "tabla:cofre_pequeno"]},
	"epico": {"titulo": "Épico", "modelo": "epico", "premios": {
		"tunica_salamandra:1": "Túnica de salamandra", "capa_escarcha:1": "Capa de escarcha", "capucha_musgo:1": "Capucha de musgo",
		"nucleo_eco:1": "Núcleo de eco", "fragmento_savia:1+oro:60": "Fragmento de savia y 60 de oro", "frasco_vacio:1+oro:40": "Frasco de reserva y 40 de oro",
		"engarce_glifo:1": "Engarce de glifo", "hoja_grimorio:1+oro:50": "Hoja de grimorio y 50 de oro"}},
	"legendario": {"titulo": "Legendario", "modelo": "legendario", "da": "oro:150+pocion_grande:2", "premios": {
		"glifo:barrera": "Glifo «barrera»", "glifo:linea": "Glifo «línea»", "glifo:raido": "Glifo «raido» (pulso)",
		"glifo:permanencia": "Glifo «permanencia»", "fragmento_savia:1": "Sin glifo: un fragmento de savia más"}},
}
## Lo añadido a mano que se pide: [{que: "enemigo" | "cofre", tipo, premio (cofres), c: Vector2i}]. Ver `_aplicar_anadidos`.
var _anadidos_pedidos: Array = []
var anadidos_hechos: Array = []         ## lo que de verdad se puso, con su casilla final (la pedida o la válida más cercana)
var _indice_hecho: Array = []           ## por cada añadido pedido, su sitio en `anadidos_hechos` (-1 si no se pudo poner)
## COFRES QUE APARECEN AL CAER ENEMIGOS (18/11, Pablo: «enlazar que un enemigo muerto haga aparecer un cofre»): [{cofre, enemigos: []}].
## Cada extremo se nombra de forma que sobreviva a mover cosas: `a<n>` = el añadido a mano número n; `x,y` = la casilla donde el
## generador puso el elemento (aunque después se haya movido). Ver `_aplicar_apariciones`.
var _apariciones_pedidas: Array = []
var apariciones_hechas: Array = []
const TIPOS_ENEMIGO: Array[String] = ["guerrero", "arquero", "limo", "golem", "chaman", "mouro", "elemental"]
const COFRES_ENLAZABLES: Array[String] = ["cofre_tesoro", "cofre_comun", "cofre_epico", "cofre_legendario"]
var _ultimo_act: String = ""            ## el activador que dejó la última plantilla `salida` estampada
var _nv: String = ""                    ## el nombre del nivel en minúsculas (para las flags)
var _letras_extra: String = ""
# «bosque» (24/11): lo que deja `_gen_bosque` para `_poblar` y `_pintar_terreno`.
var _b_salas: Array = []                ## por cada destino de `salida_a`, el id de su claro (-1 = que lo elija `_poblar` como siempre); [0] es el del inicio
var _b_lados: Array = []                ## por cada destino, el lado del borde donde va su salida: "n" | "s" | "e" | "o" | ""
var _suelo_bosque: Dictionary = {}      ## casilla → letra de suelo del bosque (g camino, . claro, , hierba, v hierba alta, R vado)
var precipicio: Array = []              ## las casillas de VACÍO del paso de tierra (letra « »: sin suelo; se cruzan con el puente de tierra tendido desde el borde). Para el resto del generador son suelo ocupado


func generar(parametros: Dictionary = {}, retoques: Dictionary = {}, enlaces_mano: Dictionary = {}, puzles_mano: Dictionary = {}, movidos: Dictionary = {},
		anadidos: Array = [], apariciones: Array = []) -> Dictionary:
	_apariciones_pedidas = apariciones.duplicate(true)
	apariciones_hechas = []
	_indice_hecho = []
	_movidos_pedidos = movidos.duplicate()
	movidos_hechos = {}
	_anadidos_pedidos = anadidos.duplicate(true)
	anadidos_hechos = []
	puzles_puestos = {}
	_puzles_mano = puzles_mano.duplicate()
	_n_cat = 0
	_letras_extra = ""
	errores = PackedStringArray()
	enlaces = []
	_puentes = {}
	_barreras = []
	_activadores = {}
	_enlaces_mano = enlaces_mano.duplicate()
	_llave_barrera = {}
	p = parametros_defecto()
	p.merge(parametros, true)
	rng = RandomNumberGenerator.new()
	rng.seed = int(p["semilla"])
	salas = []
	puertas = []
	letras = {}
	objetos = []
	lineas = PackedStringArray()
	avisos = PackedStringArray()
	inicio = Vector2i(-1, -1)
	_ocupada = {}
	_bloqueos = {}
	_cont = {}
	_b_salas = []
	_b_lados = []
	_suelo_bosque = {}
	precipicio = []
	_tierra_puntos = []
	match String(p["algoritmo"]):
		"cueva":
			_gen_cueva()
		"pagina":
			_gen_pagina()
		"bosque":
			_gen_bosque()
		_:
			p["algoritmo"] = "salas"
			_gen_salas()
	_retoques = retoques.duplicate()
	_aplicar_retoques(retoques)
	_cerrar_borde()
	_quitar_inalcanzable()
	_asegurar_tierra_conectada()
	# Red de seguridad: si un retoque o el tapado de zonas sueltas pisó alguna casilla del precipicio, se quita el paso entero y se avisa.
	var hueco_perdido: bool = false
	for c in precipicio:
		hueco_perdido = hueco_perdido or _tipo(c) != SUELO
	if hueco_perdido:
		for c in precipicio:
			_ocupada.erase(c)
		precipicio = []
		avisos.append("El paso de tierra se ha quitado: alguna casilla del precipicio quedó tapada (por un retoque o una zona suelta). Ponlo a mano.")
	if not _tierra_cierra():
		avisos.append("El paso de tierra se puede rodear: otro camino (o un vado del río) llega a esa salida sin cruzar el precipicio. Retócalo a mano pintando árboles alrededor.")
	_revisar_salas_y_puertas()
	_poblar()
	return _resultado()


# =====================================================================================================================
#  Utilidades
# =====================================================================================================================

func _dentro(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func _tipo(c: Vector2i) -> int:
	return g[c.y * w + c.x] if _dentro(c) else MURO


func _poner(c: Vector2i, t: int) -> void:
	if c.x >= 1 and c.y >= 1 and c.x < w - 1 and c.y < h - 1:
		g[c.y * w + c.x] = t


func _azar(a: int, b: int) -> int:
	return rng.randi_range(a, b) if b > a else a


func _pct(x: float) -> bool:
	return rng.randf() * 100.0 < x


## Baraja con el generador de la semilla (Array.shuffle usa el global y no sería reproducible).
func _barajar(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


func _id(base: String) -> String:
	var n: int = int(_cont.get(base, 0)) + 1
	_cont[base] = n
	return "%s_%d" % [base, n]


func _vale(i: int, solo_tierra: bool, bloqueadas: Dictionary) -> bool:
	var t: int = g[i]
	if t == MURO or (solo_tierra and t == AGUA and not _puentes.has(Vector2i(i % w, i / w))):
		return false
	return bloqueadas.is_empty() or not bloqueadas.has(Vector2i(i % w, i / w))


## Componentes conexas (a cuatro vecinas) de lo que se pisa. Devuelve [componente por casilla (-1 = no cuenta), tamaños].
func _componentes(solo_tierra: bool = false, bloqueadas: Dictionary = {}) -> Array:
	var comp: PackedInt32Array = PackedInt32Array()
	comp.resize(w * h)
	comp.fill(-1)
	var tams: Array = []
	for i0 in range(w * h):
		if comp[i0] >= 0 or not _vale(i0, solo_tierra, bloqueadas):
			continue
		var id: int = tams.size()
		var n: int = 0
		var pila: PackedInt32Array = PackedInt32Array([i0])
		comp[i0] = id
		while not pila.is_empty():
			var i: int = pila[pila.size() - 1]
			pila.remove_at(pila.size() - 1)
			n += 1
			var x: int = i % w
			var y: int = i / w
			for d in DIRS:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var j: int = ny * w + nx
				if comp[j] < 0 and _vale(j, solo_tierra, bloqueadas):
					comp[j] = id
					pila.append(j)
		tams.append(n)
	return [comp, tams]


## Distancia en pasos desde `desde` por lo que se pisa (-1 = no se llega). `bloqueadas`: casillas que no se cruzan.
func _distancias(desde: Vector2i, bloqueadas: Dictionary = {}) -> PackedInt32Array:
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	if not _dentro(desde) or _tipo(desde) == MURO:
		return dist
	var cola: PackedInt32Array = PackedInt32Array([desde.y * w + desde.x])
	dist[cola[0]] = 0
	var k: int = 0
	while k < cola.size():
		var i: int = cola[k]
		k += 1
		var x: int = i % w
		var y: int = i / w
		for d in DIRS:
			var c: Vector2i = Vector2i(x + d.x, y + d.y)
			if not _dentro(c):
				continue
			var j: int = c.y * w + c.x
			# El agua honda es pared para quien anda (el nado está desactivado en el juego): solo se cruza por un puente tendido.
			if dist[j] >= 0 or g[j] == MURO or bloqueadas.has(c) or (g[j] == AGUA and not _puentes.has(c)):
				continue
			dist[j] = dist[i] + 1
			cola.append(j)
	return dist


# =====================================================================================================================
#  «salas»: salas y pasillos sobre una rejilla lógica (impares = huecos, pares = muros)
# =====================================================================================================================

func _gen_salas() -> void:
	var a: int = clampi(int(p["ancho_pasillo"]), 1, 3)
	var nj: int = maxi(4, (clampi(int(p["ancho"]), 12, ANCHO_MAX) - 1) / (a + 1))
	var ni: int = maxi(4, (clampi(int(p["alto"]), 12, ALTO_MAX) - 1) / (a + 1))
	_lw = 2 * nj + 1
	_lh = 2 * ni + 1
	_L = PackedInt32Array()
	_L.resize(_lw * _lh)
	_L.fill(0)
	_Lid = PackedInt32Array()
	_Lid.resize(_lw * _lh)
	_Lid.fill(-1)
	_lsalas = []
	# 1 · La forma del mapa bloquea parte de la rejilla.
	var forma: String = String(p["forma"])
	for r in range(_lh):
		for c in range(_lw):
			var fr: float = (r + 0.5) / float(_lh)
			var fc: float = (c + 0.5) / float(_lw)
			var bloq: bool = false
			match forma:
				"caja":
					bloq = fr > 0.36 and fr < 0.64 and fc > 0.36 and fc < 0.64
				"cruz":
					bloq = (fr < 0.3 or fr > 0.7) and (fc < 0.3 or fc > 0.7)
				"redonda":
					bloq = Vector2(fc - 0.5, fr - 0.5).length() > 0.5
			if bloq:
				_L[r * _lw + c] |= _B
	# 2 · Salas.
	var smin: int = clampi(int(p["sala_min"]), 1, 8)
	var smax: int = clampi(int(p["sala_max"]), smin, 10)
	var dens: float = clampf(float(p["densidad_salas"]), 0.1, 3.0)
	if String(p["reparto"]) == "densas":
		for i in range(ni):
			for j in range(nj):
				if _L[(2 * i + 1) * _lw + 2 * j + 1] & (_B | _R):
					continue
				if not _pct(45.0 * dens):
					continue
				var hu: int = _azar(smin, smax)
				var wu: int = _azar(smin, smax)
				while not _l_sala(i, j, hu, wu) and (hu > smin or wu > smin):
					hu = maxi(smin, hu - 1)
					wu = maxi(smin, wu - 1)
	else:
		var quiero: int = maxi(2, int(ceil(ni * nj / float(smax * smax) * 1.6 * dens)))
		var intentos: int = quiero * 4
		while _lsalas.size() < quiero and intentos > 0:
			intentos -= 1
			var hu2: int = _azar(smin, smax)
			var wu2: int = _azar(smin, smax)
			_l_sala(_azar(0, ni - hu2), _azar(0, nj - wu2), hu2, wu2)
	var red: int = 300
	while _lsalas.size() < 2 and red > 0:          # con formas raras o salas enormes puede no caber casi nada: al menos dos, pequeñas
		red -= 1
		_l_sala(_azar(0, ni - 1), _azar(0, nj - 1), mini(smin, 2), mini(smin, 2))
	# 3 · Puertas: en cada sala, f + azar(f) huecos del perímetro (f = raíz del área), sin repetir pareja de salas.
	var pares: Dictionary = {}
	for id in range(_lsalas.size()):
		var s: Array = _lsalas[id]
		var r1: int = 2 * int(s[0]) + 1
		var c1: int = 2 * int(s[1]) + 1
		var r2: int = 2 * (int(s[0]) + int(s[2]) - 1) + 1
		var c2: int = 2 * (int(s[1]) + int(s[3]) - 1) + 1
		var cand: Array = []                       # [fila puerta, columna puerta, fila de fuera, columna de fuera]
		for c in range(c1, c2 + 1, 2):
			cand.append([r1 - 1, c, r1 - 2, c])
			cand.append([r2 + 1, c, r2 + 2, c])
		for r in range(r1, r2 + 1, 2):
			cand.append([r, c1 - 1, r, c1 - 2])
			cand.append([r, c2 + 1, r, c2 + 2])
		_barajar(cand)
		var f: int = int(sqrt(float(int(s[2]) * int(s[3]))))
		var n: int = f + _azar(0, maxi(f - 1, 0))
		n = maxi(1, int(round(n * clampf(float(p["puertas"]), 0.0, 200.0) / 50.0)))
		var puestas: int = 0
		for k in cand:
			if puestas >= n:
				break
			var rf: int = int(k[2])
			var cf: int = int(k[3])
			if rf < 1 or cf < 1 or rf > _lh - 2 or cf > _lw - 2:
				continue
			var ip: int = int(k[0]) * _lw + int(k[1])
			var ifu: int = rf * _lw + cf
			if (_L[ifu] & _B) or (_L[ip] & (_B | _D)):
				continue
			var otro: int = _Lid[ifu]
			if otro >= 0:
				var clave: Vector2i = Vector2i(mini(id, otro), maxi(id, otro))
				if pares.has(clave):
					continue
				pares[clave] = true
			_L[ip] |= _D
			puestas += 1
	# 4 · Laberinto en todo hueco libre: recorrido en profundidad con querencia a seguir recto (`recto` %).
	var recto: float = clampf(float(p["recto"]), 0.0, 100.0)
	for i in range(ni):
		for j in range(nj):
			var r0: int = 2 * i + 1
			var c0: int = 2 * j + 1
			if _L[r0 * _lw + c0] & (_B | _R | _C):
				continue
			_L[r0 * _lw + c0] |= _C
			var pila: Array = [[r0, c0, -1]]
			while not pila.is_empty():
				var t: Array = pila[pila.size() - 1]
				var orden: Array = [0, 1, 2, 3]
				_barajar(orden)
				if int(t[2]) >= 0 and _pct(recto):
					orden.erase(int(t[2]))
					orden.push_front(int(t[2]))
				var hecho: bool = false
				for d in orden:
					var dv: Vector2i = DIRS[int(d)]
					var nr: int = int(t[0]) + 2 * dv.y
					var nc: int = int(t[1]) + 2 * dv.x
					if nr < 1 or nc < 1 or nr > _lh - 2 or nc > _lw - 2:
						continue
					var im: int = (int(t[0]) + dv.y) * _lw + int(t[1]) + dv.x
					var inx: int = nr * _lw + nc
					if (_L[im] & (_B | _P | _C | _R | _D)) or (_L[inx] & (_B | _P | _C | _R)):
						continue
					_L[im] |= _C
					_L[inx] |= _C
					pila.append([nr, nc, int(d)])
					hecho = true
					break
				if not hecho:
					pila.pop_back()
	# 5 · Podar callejones (`callejones` % de los que hay) y quitar las puertas que ya no dan a nada.
	var poda: float = clampf(float(p["callejones"]), 0.0, 100.0)
	for i in range(ni):
		for j in range(nj):
			var r: int = 2 * i + 1
			var c: int = 2 * j + 1
			if (_L[r * _lw + c] & _C) and not (_L[r * _lw + c] & _R) and _l_abiertos(r, c).size() <= 1 and _pct(poda):
				_l_colapsar(r, c)
	_l_revisar_puertas()
	# 6 · Que todo quede unido: lo suelto se une por el camino más corto de huecos (abriendo puerta si cruza la pared de una sala).
	_l_conectar()
	_l_revisar_puertas()
	# 7 · A casillas: cada hueco lógico son `a` casillas y cada muro, una.
	w = nj * (a + 1) + 1
	h = ni * (a + 1) + 1
	g = PackedByteArray()
	g.resize(w * h)
	g.fill(MURO)
	for r in range(_lh):
		for c in range(_lw):
			var v: int = _L[r * _lw + c]
			if v & _D:
				g[_l_celda_puerta(r, c, a).y * w + _l_celda_puerta(r, c, a).x] = SUELO
			elif v & (_R | _C):
				for y in range(_l_ini(r, a), _l_ini(r, a) + _l_tam(r, a)):
					for x in range(_l_ini(c, a), _l_ini(c, a) + _l_tam(c, a)):
						g[y * w + x] = SUELO
	var nuevo_id: Dictionary = {}
	for id in range(_lsalas.size()):
		var s2: Array = _lsalas[id]
		var rr1: int = 2 * int(s2[0]) + 1
		var cc1: int = 2 * int(s2[1]) + 1
		if not (_L[rr1 * _lw + cc1] & _R):
			continue                               # sala retirada al no poder unirla
		var rr2: int = 2 * (int(s2[0]) + int(s2[2]) - 1) + 1
		var cc2: int = 2 * (int(s2[1]) + int(s2[3]) - 1) + 1
		var rect: Rect2i = Rect2i(_l_ini(cc1, a), _l_ini(rr1, a), _l_ini(cc2, a) + a - _l_ini(cc1, a), _l_ini(rr2, a) + a - _l_ini(rr1, a))
		nuevo_id[id] = salas.size()
		_nueva_sala(rect)
	for r in range(_lh):
		for c in range(_lw):
			if not (_L[r * _lw + c] & _D):
				continue
			var lados: Array = [[r - 1, c], [r + 1, c]] if r % 2 == 0 else [[r, c - 1], [r, c + 1]]
			var de: Array = []
			for l in lados:
				var sid: int = _Lid[int(l[0]) * _lw + int(l[1])]
				if sid >= 0 and nuevo_id.has(sid) and not de.has(int(nuevo_id[sid])):
					de.append(int(nuevo_id[sid]))
			puertas.append({"c": _l_celda_puerta(r, c, a), "salas": de, "tipo": "paso"})


func _l_ini(k: int, a: int) -> int:
	return (k / 2) * (a + 1) + (1 if k % 2 == 1 else 0)


func _l_tam(k: int, a: int) -> int:
	return a if k % 2 == 1 else 1


## La casilla que se abre de una puerta lógica: la del centro del tramo (la puerta siempre es de una casilla, aunque el pasillo sea ancho).
func _l_celda_puerta(r: int, c: int, a: int) -> Vector2i:
	if r % 2 == 0:
		return Vector2i(_l_ini(c, a) + a / 2, _l_ini(r, a))
	return Vector2i(_l_ini(c, a), _l_ini(r, a) + a / 2)


func _l_sala(i: int, j: int, hu: int, wu: int) -> bool:
	var r1: int = 2 * i + 1
	var c1: int = 2 * j + 1
	var r2: int = 2 * (i + hu - 1) + 1
	var c2: int = 2 * (j + wu - 1) + 1
	if i < 0 or j < 0 or r2 > _lh - 2 or c2 > _lw - 2:
		return false
	for r in range(r1, r2 + 1):
		for c in range(c1, c2 + 1):
			if _L[r * _lw + c] & (_B | _R):
				return false
	var id: int = _lsalas.size()
	for r in range(r1, r2 + 1):
		for c in range(c1, c2 + 1):
			_L[r * _lw + c] |= _R
			_Lid[r * _lw + c] = id
	for r in range(r1 - 1, r2 + 2):
		for c in range(c1 - 1, c2 + 2):
			if not (_L[r * _lw + c] & _R):
				_L[r * _lw + c] |= _P
	_lsalas.append([i, j, hu, wu])
	return true


## Direcciones (índice de DIRS) por las que un hueco de pasillo sigue abierto: pasillo o puerta.
func _l_abiertos(r: int, c: int) -> Array:
	var res: Array = []
	for d in range(4):
		if _L[(r + DIRS[d].y) * _lw + c + DIRS[d].x] & (_C | _D):
			res.append(d)
	return res


## Cierra un callejón desde su punta hasta el primer cruce (o hasta la puerta a la que no llevaba nadie, que se quita).
func _l_colapsar(r: int, c: int) -> void:
	while true:
		var i: int = r * _lw + c
		if not (_L[i] & _C) or (_L[i] & _R):
			return
		var v: Array = _l_abiertos(r, c)
		if v.size() > 1:
			return
		_L[i] &= ~_C
		if v.is_empty():
			return
		var d: Vector2i = DIRS[int(v[0])]
		var m: int = (r + d.y) * _lw + c + d.x
		if _L[m] & _D:
			_L[m] &= ~_D
			return
		_L[m] &= ~_C
		r += 2 * d.y
		c += 2 * d.x


## Una puerta vale si a sus dos lados hay sala o pasillo.
func _l_revisar_puertas() -> void:
	for r in range(1, _lh - 1):
		for c in range(1, _lw - 1):
			if not (_L[r * _lw + c] & _D):
				continue
			var a1: int = _L[(r - 1) * _lw + c] if r % 2 == 0 else _L[r * _lw + c - 1]
			var a2: int = _L[(r + 1) * _lw + c] if r % 2 == 0 else _L[r * _lw + c + 1]
			if not (a1 & (_R | _C)) or not (a2 & (_R | _C)):
				_L[r * _lw + c] &= ~_D


func _l_conectar() -> void:
	var abierto: int = _R | _C | _D
	for _vuelta in range(80):
		var comp: PackedInt32Array = PackedInt32Array()
		comp.resize(_lw * _lh)
		comp.fill(-1)
		var tams: Array = []
		for i0 in range(_lw * _lh):
			if comp[i0] >= 0 or not (_L[i0] & abierto):
				continue
			var n: int = 0
			var pila: PackedInt32Array = PackedInt32Array([i0])
			comp[i0] = tams.size()
			while not pila.is_empty():
				var i: int = pila[pila.size() - 1]
				pila.remove_at(pila.size() - 1)
				n += 1
				for d in DIRS:
					var j: int = i + d.y * _lw + d.x          # el borde lógico nunca está abierto: no se sale de la rejilla
					if comp[j] < 0 and (_L[j] & abierto):
						comp[j] = tams.size()
						pila.append(j)
			tams.append(n)
		if tams.size() <= 1:
			return
		var k: int = 0
		for t in range(tams.size()):
			if int(tams[t]) < int(tams[k]):
				k = t
		# Búsqueda en anchura por huecos (impar, impar) desde la componente pequeña hasta tocar otra.
		var prev: Dictionary = {}
		var cola: PackedInt32Array = PackedInt32Array()
		for r in range(1, _lh - 1, 2):
			for c in range(1, _lw - 1, 2):
				if comp[r * _lw + c] == k:
					cola.append(r * _lw + c)
					prev[r * _lw + c] = -1
		var meta: int = -1
		var q: int = 0
		while q < cola.size() and meta < 0:
			var u: int = cola[q]
			q += 1
			var ur: int = u / _lw
			var uc: int = u % _lw
			for d in DIRS:
				var nr: int = ur + 2 * d.y
				var nc: int = uc + 2 * d.x
				if nr < 1 or nc < 1 or nr > _lh - 2 or nc > _lw - 2:
					continue
				var v: int = nr * _lw + nc
				var m: int = (ur + d.y) * _lw + uc + d.x
				if prev.has(v) or (_L[v] & _B) or (_L[m] & _B):
					continue
				prev[v] = u
				if (_L[v] & (_R | _C)) and comp[v] != k:
					meta = v
					break
				cola.append(v)
		if meta < 0:
			# Aislada por la forma del mapa: se retira.
			for i in range(_lw * _lh):
				if comp[i] == k:
					_L[i] &= ~abierto
			continue
		var cur: int = meta
		while int(prev[cur]) >= 0:
			var u2: int = int(prev[cur])
			var m2: int = (cur + u2) / 2
			if not (_L[m2] & abierto):
				_L[m2] |= _D if (_L[m2] & _P) else _C
			if not (_L[cur] & (_R | _C)):
				_L[cur] |= _C
			cur = u2


# =====================================================================================================================
#  «cueva»: autómata celular
# =====================================================================================================================

func _gen_cueva() -> void:
	w = clampi(int(p["ancho"]), 12, ANCHO_MAX)
	h = clampi(int(p["alto"]), 12, ALTO_MAX)
	g = PackedByteArray()
	g.resize(w * h)
	g.fill(MURO)
	var relleno: float = clampf(float(p["relleno"]), 30.0, 75.0)
	# Silueta: con 0 la cueva llena el rectángulo; cuanto más, más roca hacia los bordes (con ruido), y sale una mancha irregular
	# con entrantes y brazos, como las del Cave Generator, en vez de un rectángulo de roca.
	var silueta: float = clampf(float(p["silueta"]), 0.0, 100.0)
	var contorno: FastNoiseLite = FastNoiseLite.new()
	contorno.seed = int(p["semilla"]) + 7919
	contorno.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	contorno.frequency = 0.07
	# «fractal»: el suelo es lo más alto de un ruido fractal (varias octavas sumadas: la misma forma se repite en grande y en pequeño,
	# y de ahí salen las salas anchas unidas por gargantas y los bordes recortados). «automata»: ruido casilla a casilla, que luego se suaviza.
	var fractal: bool = String(p["metodo"]) != "automata"
	var campo: FastNoiseLite = FastNoiseLite.new()
	campo.seed = int(p["semilla"])
	campo.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	campo.fractal_type = FastNoiseLite.FRACTAL_FBM
	campo.fractal_octaves = clampi(int(p["octavas"]), 1, 6)
	campo.fractal_lacunarity = 2.0
	campo.fractal_gain = 0.55
	campo.frequency = 1.0 / clampf(float(p["tamano_sala"]), 4.0, 40.0)
	var alturas: PackedFloat32Array = PackedFloat32Array()
	alturas.resize(w * h)
	var orden: Array = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var dx: float = (x - (w - 1) * 0.5) / ((w - 2) * 0.5)
			var dy: float = (y - (h - 1) * 0.5) / ((h - 2) * 0.5)
			var lejos: float = sqrt(dx * dx + dy * dy) + 0.4 * contorno.get_noise_2d(float(x), float(y))
			var borde: float = silueta * smoothstep(0.5, 1.0, lejos)
			if fractal:
				alturas[y * w + x] = campo.get_noise_2d(float(x), float(y)) - borde * 0.007
				orden.append(alturas[y * w + x])
			elif not _pct(relleno + borde):
				g[y * w + x] = SUELO
	if fractal and not orden.is_empty():
		# El corte se pone donde deja de suelo justo la parte pedida (100 − roca).
		orden.sort()
		var corte: float = float(orden[clampi(int(orden.size() * relleno / 100.0), 0, orden.size() - 1)])
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				if alturas[y * w + x] > corte:
					g[y * w + x] = SUELO
	# Suavizado: una casilla es roca si lo son 5 o más de las 9 de su entorno.
	for _k in range(clampi(int(p["suavizados"]), 0, 12)):
		var n: PackedByteArray = g.duplicate()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var m: int = 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if g[(y + dy) * w + x + dx] == MURO:
							m += 1
				n[y * w + x] = MURO if m >= 5 else SUELO
		g = n
	# Regiones sueltas: las pequeñas se tapan y las demás se unen con un túnel de dos casillas por el camino más corto.
	var region_min: int = maxi(1, int(p["region_min"]))
	for _v in range(60):
		var res: Array = _componentes()
		var comp: PackedInt32Array = res[0]
		var tams: Array = res[1]
		if tams.size() <= 1:
			break
		var k: int = 0
		for t in range(tams.size()):
			if int(tams[t]) < int(tams[k]):
				k = t
		if int(tams[k]) < region_min:
			for i in range(w * h):
				if comp[i] == k:
					g[i] = MURO
			continue
		var prev: PackedInt32Array = PackedInt32Array()
		prev.resize(w * h)
		prev.fill(-2)
		var cola: PackedInt32Array = PackedInt32Array()
		for i in range(w * h):
			if comp[i] == k:
				cola.append(i)
				prev[i] = -1
		var meta: int = -1
		var q: int = 0
		while q < cola.size() and meta < 0:
			var i2: int = cola[q]
			q += 1
			for d in DIRS:
				var x2: int = i2 % w + d.x
				var y2: int = i2 / w + d.y
				if x2 < 1 or y2 < 1 or x2 > w - 2 or y2 > h - 2:
					continue
				var j: int = y2 * w + x2
				if prev[j] != -2:
					continue
				prev[j] = i2
				if g[j] != MURO:
					meta = j
					break
				cola.append(j)
		if meta < 0:
			for i in range(w * h):
				if comp[i] == k:
					g[i] = MURO
			continue
		var cur: int = prev[meta]
		while cur >= 0 and comp[cur] != k:
			var cc: Vector2i = Vector2i(cur % w, cur / w)
			_poner(cc, SUELO)
			if _tipo(cc + Vector2i(1, 0)) == MURO:
				_poner(cc + Vector2i(1, 0), SUELO)
			if _tipo(cc + Vector2i(0, 1)) == MURO:
				_poner(cc + Vector2i(0, 1), SUELO)
			cur = prev[cur]
	var suelo: int = g.count(SUELO)
	if suelo < 30:
		avisos.append("La cueva salió casi toda roca (relleno muy alto): se abre una sala central.")
		for y in range(h / 2 - 3, h / 2 + 4):
			for x in range(w / 2 - 4, w / 2 + 5):
				_poner(Vector2i(x, y), SUELO)
	# Agua: se inunda lo más bajo de un mapa de ruido (`agua` % del suelo).
	var pct: float = clampf(float(p["agua"]), 0.0, 40.0)
	if pct > 0.0:
		var ruido: FastNoiseLite = FastNoiseLite.new()
		ruido.seed = int(p["semilla"])
		ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		ruido.frequency = 0.09
		var vals: Array = []
		for i in range(w * h):
			if g[i] == SUELO:
				vals.append(ruido.get_noise_2d(float(i % w), float(i / w)))
		if not vals.is_empty():
			vals.sort()
			var umbral: float = float(vals[clampi(int(vals.size() * pct / 100.0), 0, vals.size() - 1)])
			for i in range(w * h):
				if g[i] == SUELO and ruido.get_noise_2d(float(i % w), float(i / w)) < umbral:
					g[i] = AGUA
	_cueva_claros()


## La cueva no tiene salas: se eligen «claros» (los puntos más anchos, lo más separados posible) para repartir el contenido como si lo fueran.
func _cueva_claros() -> void:
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	var cola: PackedInt32Array = PackedInt32Array()
	for i in range(w * h):
		if g[i] == MURO:
			dist[i] = 0
			cola.append(i)
	var q: int = 0
	while q < cola.size():
		var i: int = cola[q]
		q += 1
		for d in DIRS:
			var x: int = i % w + d.x
			var y: int = i / w + d.y
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			if dist[y * w + x] < 0:
				dist[y * w + x] = dist[i] + 1
				cola.append(y * w + x)
	var cand: Array = []
	for corte in [3, 2, 1]:
		cand = []
		for i in range(w * h):
			if g[i] == SUELO and dist[i] >= int(corte):
				cand.append(i)
		if cand.size() >= 12:
			break
	if cand.is_empty():
		return
	var quiero: int = clampi(g.count(SUELO) / 70, 3, 12)
	var elegidos: Array = []
	var primero: int = int(cand[0])
	for i in cand:
		if int(i) / w > primero / w:
			primero = int(i)                       # el más al sur: ahí irá la entrada
	elegidos.append(primero)
	while elegidos.size() < quiero:
		var mejor: int = -1
		var mejor_d: int = -1
		for i in cand:
			var dmin: int = 1 << 30
			for e in elegidos:
				var dx: int = int(i) % w - int(e) % w
				var dy: int = int(i) / w - int(e) / w
				dmin = mini(dmin, dx * dx + dy * dy)
			if dmin > mejor_d:
				mejor_d = dmin
				mejor = int(i)
		if mejor < 0 or mejor_d < 36:
			break
		elegidos.append(mejor)
	for e in elegidos:
		var c: Vector2i = Vector2i(int(e) % w, int(e) / w)
		var radio: int = clampi(dist[int(e)], 1, 3)
		_nueva_sala(Rect2i(c - Vector2i(radio, radio), Vector2i(2 * radio + 1, 2 * radio + 1)))


# =====================================================================================================================
#  «bosque»: claros unidos por caminos sinuosos, hierba, río, salidas en el borde y paso de tierra (24/11)
# =====================================================================================================================

var _camino_b: Dictionary = {}          ## casillas de camino del bosque (para los vados del río)
var _tierra_puntos: Array = []            ## [suelo del claro de dentro, suelo del claro de la salida] del paso de tierra

## Los destinos de `salida_a` (sin el nombre de la llegada), en el mismo orden en que los lee `_poblar`.
func _destinos() -> PackedStringArray:
	var res: PackedStringArray = PackedStringArray()
	for d in String(p["salida_a"]).replace(";", ",").replace(" ", ",").split(",", false):
		res.append(d.split("=", true, 1)[0])
	return res


## Los lados pedidos en `lados_salida` (uno por destino, separados por comas; vacío o «-» = dentro del bosque). `w` vale como `o`.
func _lados_pedidos(n: int) -> Array:
	var trozos: PackedStringArray = String(p["lados_salida"]).to_lower().replace(";", ",").split(",")
	var res: Array = []
	for k in range(n):
		var l: String = trozos[k].strip_edges() if k < trozos.size() else ""
		if l == "w":
			l = "o"
		res.append(l if ["n", "s", "e", "o"].has(l) else "")
	return res


func _gen_bosque() -> void:
	w = clampi(int(p["ancho"]), 16, ANCHO_MAX)
	h = clampi(int(p["alto"]), 16, ALTO_MAX)
	g = PackedByteArray()
	g.resize(w * h)
	g.fill(MURO)
	_camino_b = {}
	var r: int = clampi(int(p["tamano_claro"]), 2, 8)
	var semilla: int = int(p["semilla"])
	var ruido: FastNoiseLite = FastNoiseLite.new()
	ruido.seed = semilla + 104729
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.11
	# 1 · Los claros. Primero el del inicio y los de las salidas (cada uno pegado a su lado del borde si lo pide), después los de dentro,
	#     cada uno en el sitio más alejado de los que ya hay.
	var destinos: PackedStringArray = _destinos()
	var n_dest: int = maxi(destinos.size(), 1)           # sin salidas también hay claro de inicio
	_b_lados = _lados_pedidos(n_dest)
	var centros: Array = []
	var es_salida: Array = []
	for k in range(n_dest):
		centros.append(_sitio_claro(centros, r, String(_b_lados[k]), k == 0))
		es_salida.append(k > 0)
	var separacion: float = 2.2 * r + 2.0
	for _i in range(clampi(int(p["claros"]), 0, 30)):
		var c: Vector2i = _sitio_claro(centros, r, "", false)
		if _lejania(c, centros) < separacion:
			avisos.append("Solo caben %d claros de los %d pedidos: agranda el mapa o achica los claros." % [_i, int(p["claros"])])
			break
		centros.append(c)
		es_salida.append(false)
	# 2 · Se abren los claros: un círculo de radio `tamano_claro` con el borde movido por un ruido, para que no salgan redondos.
	var sala_de: Array = []
	for c0 in centros:
		var c: Vector2i = c0
		var caja: Rect2i = Rect2i(c, Vector2i.ZERO)
		for dy in range(-r - 3, r + 4):
			for dx in range(-r - 3, r + 4):
				var q: Vector2i = c + Vector2i(dx, dy)
				if q.x < 1 or q.y < 1 or q.x > w - 2 or q.y > h - 2:
					continue
				var rr: float = float(r) * (1.0 + 0.3 * ruido.get_noise_2d(q.x * 1.7, q.y * 1.7))
				if dx == 0 and dy == 0 or Vector2(dx, dy).length() <= rr:
					_poner(q, SUELO)
					_suelo_bosque[q] = "."
					caja = caja.expand(q)
		caja.size += Vector2i.ONE
		sala_de.append(_nueva_sala(caja))
	_b_salas = sala_de.slice(0, n_dest)
	# Los claros pegados a un lado llegan SIEMPRE hasta el borde (el ruido podría dejarlos a una casilla): un tramo de camino del
	# centro al borde, que es por donde se sale.
	for k in range(n_dest):
		var lado_k: String = String(_b_lados[k])
		if LADO_VEC.has(lado_k):
			var cen: Vector2i = centros[k]
			var hacia: Vector2i = LADO_VEC[lado_k]
			var borde: Vector2i = Vector2i(1 if hacia.x < 0 else (w - 2 if hacia.x > 0 else cen.x), 1 if hacia.y < 0 else (h - 2 if hacia.y > 0 else cen.y))
			_camino_entre(cen, borde, clampi(int(p["ancho_camino"]), 1, 4), 0.0, ruido)
	# 3 · Qué claro se une con cuál: un árbol de mínima distancia entre los de dentro (el del inicio incluido), unos BUCLES de más entre
	#     vecinos cercanos, y cada claro de salida colgado del claro de dentro más cercano (es una hoja: solo se llega por su camino).
	var nucleo: Array = []
	for i in range(centros.size()):
		if not bool(es_salida[i]):
			nucleo.append(i)
	var aristas: Array = []
	var en_arbol: Dictionary = {int(nucleo[0]): true}
	while en_arbol.size() < nucleo.size():
		var mejor: Array = []
		var md: float = INF
		for a in en_arbol:
			for b in nucleo:
				if en_arbol.has(b):
					continue
				var d: float = Vector2(centros[a]).distance_to(Vector2(centros[b]))
				if d < md:
					md = d
					mejor = [int(a), int(b)]
		aristas.append(mejor)
		en_arbol[mejor[1]] = true
	var media: float = 0.0
	for e in aristas:
		media += Vector2(centros[e[0]]).distance_to(Vector2(centros[e[1]]))
	media = media / aristas.size() if not aristas.is_empty() else 4.0 * r
	for ia in range(nucleo.size()):
		for ib in range(ia + 1, nucleo.size()):
			var a2: int = int(nucleo[ia])
			var b2: int = int(nucleo[ib])
			if aristas.has([a2, b2]) or aristas.has([b2, a2]):
				continue
			if Vector2(centros[a2]).distance_to(Vector2(centros[b2])) < 1.6 * media and _pct(float(p["bucles_claros"])):
				aristas.append([a2, b2])
	for i in range(centros.size()):
		if not bool(es_salida[i]):
			continue
		var cerca: int = int(nucleo[0])
		for n in nucleo:
			if Vector2(centros[n]).distance_to(Vector2(centros[i])) < Vector2(centros[cerca]).distance_to(Vector2(centros[i])):
				cerca = int(n)
		aristas.append([cerca, i])
	# 4 · Los caminos: una curva entre los dos centros, combada hacia un lado al azar y con un serpenteo fino (`sinuosidad`).
	var ancho: int = clampi(int(p["ancho_camino"]), 1, 4)
	var serp: float = clampf(float(p["sinuosidad"]), 0.0, 100.0) / 100.0
	var rutas: Dictionary = {}                          # claro de salida → casillas de su camino, del claro de dentro hacia la salida
	for e in aristas:
		var celdas: Array = _camino_entre(centros[e[0]], centros[e[1]], ancho, serp, ruido)
		if bool(es_salida[e[1]]):
			rutas[int(e[1])] = celdas
	# El paso de tierra: en el camino de qué salida (1 = la del inicio, que no vale: tiene que ser una de las otras).
	var k_tierra: int = int(p["paso_tierra"]) - 1
	if int(p["paso_tierra"]) != 0 and (k_tierra < 1 or k_tierra >= destinos.size()):
		avisos.append("El paso de tierra pide la salida número %d y las salidas que lo pueden llevar son de la 2 a la %d: no se pone." % [int(p["paso_tierra"]), destinos.size()])
		k_tierra = -1
	# Alrededor del camino de esa salida y de su claro no se abre hierba: si no, los muros se podrían rodear.
	var protegidas: Dictionary = {}
	var holgura: int = clampi(1 + int(float(p["apertura"]) / 25.0), 1, 5)
	if k_tierra >= 1 and rutas.has(k_tierra):
		var base: Array = []
		var arranque: Vector2i = rutas[k_tierra][0]          # el centro del claro de dentro del que sale ese camino: ahí sí puede haber hierba
		for c in rutas[k_tierra]:
			if Vector2(c).distance_to(Vector2(arranque)) > r + 1:
				base.append(c)
		for dy in range(-r - 1, r + 2):
			for dx in range(-r - 1, r + 2):
				base.append(centros[k_tierra] + Vector2i(dx, dy))
		for c in base:
			for dy in range(-holgura - 1, holgura + 2):
				for dx in range(-holgura - 1, holgura + 2):
					protegidas[(c as Vector2i) + Vector2i(dx, dy)] = true
	# 5 · La hierba: se abren casillas de árbol pegadas a lo abierto (hasta `holgura` casillas), a manchas, según `apertura`.
	var apert: float = clampf(float(p["apertura"]), 0.0, 100.0) / 100.0
	if apert > 0.0:
		var manchas: FastNoiseLite = FastNoiseLite.new()
		manchas.seed = semilla + 7
		manchas.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		manchas.frequency = 0.09
		var dist: PackedInt32Array = PackedInt32Array()
		dist.resize(w * h)
		dist.fill(-1)
		var cola: PackedInt32Array = PackedInt32Array()
		for i in range(w * h):
			if g[i] == SUELO:
				dist[i] = 0
				cola.append(i)
		var q0: int = 0
		while q0 < cola.size():
			var i: int = cola[q0]
			q0 += 1
			if dist[i] >= holgura:
				continue
			for d in DIRS:
				var x: int = i % w + d.x
				var y: int = i / w + d.y
				if x < 1 or y < 1 or x > w - 2 or y > h - 2 or dist[y * w + x] >= 0:
					continue
				dist[y * w + x] = dist[i] + 1
				cola.append(y * w + x)
		for i in range(w * h):
			var c: Vector2i = Vector2i(i % w, i / w)
			if dist[i] < 1 or protegidas.has(c):
				continue
			var v: float = (manchas.get_noise_2d(float(c.x), float(c.y)) + 1.0) * 0.5
			if v + apert * 0.6 - (dist[i] - 1) * 0.12 > 0.85:
				g[i] = SUELO
				_suelo_bosque[c] = ","
		# Los árboles sueltos que quedan con tres lados abiertos se quitan (dientes de sierra).
		var quitar: Array = []
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var c: Vector2i = Vector2i(x, y)
				if g[y * w + x] != MURO or protegidas.has(c):
					continue
				var abiertos: int = 0
				for d in DIRS:
					abiertos += 1 if _tipo(c + d) == SUELO else 0
				if abiertos >= 3:
					quitar.append(c)
		for c in quitar:
			_poner(c, SUELO)
			_suelo_bosque[c] = ","
	# 6 · El río: de borde a borde («ns» de norte a sur, «eo» de este a oeste), serpenteando. Donde lo pisa un camino queda un VADO de piedras.
	var rio: String = String(p["rio"]).to_lower()
	if ["ns", "sn", "eo", "oe", "ew", "we"].has(rio):
		var vertical: bool = rio == "ns" or rio == "sn"
		var largo_eje: int = h if vertical else w
		var ancho_eje: int = w if vertical else h
		var base_r: float = rng.randf_range(0.3, 0.7) * ancho_eje
		var anch: int = clampi(int(p["ancho_rio"]), 1, 4)
		var fase: float = rng.randf() * 100.0
		var rio_celdas: Array = []
		var prev_lo: int = -1
		var prev_hi: int = -1
		for t in range(1, largo_eje - 1):
			var lo: int = roundi(base_r + ruido.get_noise_1d(fase + t * 0.6) * ancho_eje * 0.18 - (anch - 1) * 0.5)
			var hi: int = lo + anch - 1
			if prev_lo >= 0:                             # que cada fila toque la anterior por un lado (sin saltos en diagonal)
				lo = mini(lo, prev_hi)
				hi = maxi(hi, prev_lo)
			prev_lo = lo
			prev_hi = hi
			for a in range(lo, hi + 1):
				var c: Vector2i = Vector2i(a, t) if vertical else Vector2i(t, a)
				if c.x < 1 or c.y < 1 or c.x > w - 2 or c.y > h - 2:
					continue
				if _camino_b.has(c):
					_suelo_bosque[c] = "R"
				else:
					g[c.y * w + c.x] = AGUA
					_suelo_bosque.erase(c)
					rio_celdas.append(c)
		# Las ORILLAS: una casilla de hierba a cada lado del agua, de punta a punta (si no, los tramos que pasan entre árboles quedarían
		# sueltos y se taparían). Cerca del paso de tierra no: serían un camino para rodear los muros.
		for c in rio_celdas:
			for d in DIRS:
				var q: Vector2i = (c as Vector2i) + d
				if q.x >= 1 and q.y >= 1 and q.x <= w - 2 and q.y <= h - 2 and _tipo(q) == MURO and not protegidas.has(q):
					_poner(q, SUELO)
					_suelo_bosque[q] = ","
	# 7 · La hierba alta (`v`, arde): las manchas más altas de otro ruido, `hierba_alta` % de la hierba y los claros (no el camino).
	var pct_alta: float = clampf(float(p["hierba_alta"]), 0.0, 100.0)
	if pct_alta > 0.0:
		var alta: FastNoiseLite = FastNoiseLite.new()
		alta.seed = semilla + 31
		alta.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		alta.frequency = 0.15
		var vals: Array = []
		for c in _suelo_bosque:
			if String(_suelo_bosque[c]) == "," or String(_suelo_bosque[c]) == ".":
				vals.append(alta.get_noise_2d(float(c.x), float(c.y)))
		if not vals.is_empty():
			vals.sort()
			var umbral: float = float(vals[clampi(int(vals.size() * (1.0 - pct_alta / 100.0)), 0, vals.size() - 1)])
			for c in _suelo_bosque.keys():
				var l: String = String(_suelo_bosque[c])
				if (l == "," or l == ".") and alta.get_noise_2d(float(c.x), float(c.y)) >= umbral:
					_suelo_bosque[c] = "v"
	# 8 · El paso de tierra, al final (que nada lo vuelva a abrir).
	if k_tierra >= 1 and rutas.has(k_tierra):
		_poner_precipicio(rutas[k_tierra], centros[k_tierra], r)


## La menor distancia de `c` a los centros que ya hay (INF si no hay ninguno).
func _lejania(c: Vector2i, centros: Array) -> float:
	var dm: float = INF
	for o in centros:
		dm = minf(dm, Vector2(c).distance_to(Vector2(o)))
	return dm


## Dónde poner un claro: de 40 sitios al azar, el más alejado de los que ya hay. Con `lado`, pegado a ese borde (el claro toca la
## fila o columna 1); sin lado, el del inicio va al sur (la cámara mira al norte: se entra desde abajo) y los demás, en cualquier sitio.
func _sitio_claro(centros: Array, r: int, lado: String, es_inicio: bool) -> Vector2i:
	var mejor: Vector2i = Vector2i(w / 2, h / 2)
	var mejor_d: float = -1.0
	for _i in range(40):
		var c: Vector2i
		match lado:
			"o":
				c = Vector2i(r, _azar(r + 2, h - r - 3))
			"e":
				c = Vector2i(w - 1 - r, _azar(r + 2, h - r - 3))
			"n":
				c = Vector2i(_azar(r + 2, w - r - 3), r)
			"s":
				c = Vector2i(_azar(r + 2, w - r - 3), h - 1 - r)
			_:
				if es_inicio:
					c = Vector2i(_azar(r + 2, w - r - 3), _azar(int(h * 0.68), h - r - 2))
				else:
					c = Vector2i(_azar(r + 2, w - r - 3), _azar(r + 2, h - r - 3))
		c = Vector2i(clampi(c.x, 1, w - 2), clampi(c.y, 1, h - 2))
		var d: float = _lejania(c, centros)
		if d > mejor_d:
			mejor_d = d
			mejor = c
	return mejor


## Abre un camino de `ancho` casillas entre dos puntos y devuelve sus casillas en orden (de `a` a `b`). Una curva cuadrática con el punto de
## control apartado del medio hacia un lado al azar (`serp` × la distancia) y un serpenteo fino encima; los pasos son de una casilla en
## cruz (nunca en diagonal: la jugadora y los enemigos andan a cuatro vecinas).
func _camino_entre(a: Vector2i, b: Vector2i, ancho: int, serp: float, ruido: FastNoiseLite) -> Array:
	var va: Vector2 = Vector2(a)
	var vb: Vector2 = Vector2(b)
	var largo: float = va.distance_to(vb)
	var perp: Vector2 = (vb - va).orthogonal().normalized() if largo > 0.0 else Vector2.ZERO
	var ctrl: Vector2 = (va + vb) * 0.5 + perp * largo * serp * rng.randf_range(-0.55, 0.55)
	var fase: float = rng.randf() * 100.0
	var pasos: int = maxi(2, int(largo * 3.0))
	var res: Array = []
	var prev: Vector2i = Vector2i(-1, -1)
	for i in range(pasos + 1):
		var t: float = float(i) / pasos
		var pt: Vector2 = va.lerp(ctrl, t).lerp(ctrl.lerp(vb, t), t)
		pt += perp * ruido.get_noise_1d(fase + t * largo * 0.35) * 2.5 * serp * sin(PI * t)
		var c: Vector2i = Vector2i(clampi(roundi(pt.x), 1, w - 2), clampi(roundi(pt.y), 1, h - 2))
		if prev.x < 0:
			_brocha(c, ancho)
			res.append(c)
		else:
			var q: Vector2i = prev
			while q != c:
				if q.x != c.x:
					q.x += signi(c.x - q.x)
				else:
					q.y += signi(c.y - q.y)
				_brocha(q, ancho)
				res.append(q)
		prev = c
	return res


func _brocha(c: Vector2i, ancho: int) -> void:
	for dy in range(ancho):
		for dx in range(ancho):
			var q: Vector2i = c + Vector2i(dx - (ancho - 1) / 2, dy - (ancho - 1) / 2)
			if q.x < 1 or q.y < 1 or q.x > w - 2 or q.y > h - 2:
				continue
			_poner(q, SUELO)
			_suelo_bosque[q] = "g"
			_camino_b[q] = true


## La casilla de suelo más cercana a `c` (en un radio de 6), o (-1, -1).
func _suelo_cerca(c: Vector2i) -> Vector2i:
	var mejor: Vector2i = Vector2i(-1, -1)
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var q: Vector2i = c + Vector2i(dx, dy)
			if _tipo(q) == SUELO and (mejor.x < 0 or (q - c).length_squared() < (mejor - c).length_squared()):
				mejor = q
	return mejor


## EL PASO DE TIERRA (24/11, Pablo: «el agua es un muro natural; que sea un PRECIPICIO lo que te permita hacer un puente, y el puente se crea
## DESDE la tierra que existe, no de la nada»): en el último tramo del camino de esa salida que ya está fuera de los dos claros, una franja de
## VACÍO (letra « », sin suelo) de `ancho_precipicio` casillas de hondo que corta el camino de lado a lado. Se cruza con el puente de tierra
## (barrera + líneas) lanzado desde la casilla del borde: nace sobre ese suelo y se tiende sobre el vacío (eso último es trabajo de HECHIZOS).
## Si aún se puede rodear, la grieta se alarga a los lados (solo por suelo: los árboles la frenan) hasta que, sin cruzarla, desde el claro de
## dentro no se llega al de la salida. Para el resto del generador las casillas del precipicio son suelo ocupado (nada se pone encima) y al
## escribir el plano salen como « ».
func _poner_precipicio(ruta: Array, centro_fin: Vector2i, r: int) -> void:
	var origen: Vector2i = ruta[0]
	# Los sitios donde probar, del más cercano a la salida hacia dentro: los que ya están fuera de los dos claros y, si no hay, la mitad del camino.
	var candidatos: Array = []
	for i in range(ruta.size() - 1, 1, -1):
		var c: Vector2i = ruta[i]
		if Vector2(c).distance_to(Vector2(centro_fin)) > r + 1 and Vector2(c).distance_to(Vector2(origen)) > r + 1:
			candidatos.append(i)
	if candidatos.is_empty() and ruta.size() >= 6:
		candidatos.append(ruta.size() / 2)              # claros muy juntos: a mitad de camino
	if candidatos.is_empty():
		avisos.append("El camino de la salida del paso de tierra es demasiado corto para el precipicio: aleja su claro o agranda el mapa.")
		return
	var ancho: int = clampi(int(p["ancho_camino"]), 1, 4)
	var s_min: int = -(ancho - 1) / 2                  # lo que ocupa el camino de lado a lado (como `_brocha`)
	var s_max: int = ancho / 2
	var hondo: int = clampi(int(p.get("ancho_precipicio", 2)), 1, 5)
	_tierra_puntos = [_suelo_cerca(origen), _suelo_cerca(centro_fin)]
	var bien: bool = false
	var c0: Vector2i = ruta[int(candidatos[0])]
	for k in range(0, mini(candidatos.size(), 24), 2):            # cada 2 casillas, como mucho 12 sitios
		bien = _cortar_con_precipicio(ruta, int(candidatos[k]), s_min, s_max, hondo)
		if bien:
			break
	if not bien:
		avisos.append("No se ha podido cortar con un precipicio el camino de la salida del paso de tierra cerca de (%d, %d): ponlo a mano (letra espacio)." % [c0.x, c0.y])


## Prueba a cortar el camino en `ruta[i0]` con una franja de vacío de `hondo` casillas (a lo largo del camino) en el eje por el que avanza y,
## si no sale, en el otro. Deja todo como estaba si no lo consigue.
func _cortar_con_precipicio(ruta: Array, i0: int, _s_min: int, s_max: int, hondo: int) -> bool:
	var d: Vector2i = (ruta[mini(i0 + 3, ruta.size() - 1)] as Vector2i) - (ruta[maxi(i0 - 3, 0)] as Vector2i)
	var ejes: Array = [Vector2i(1, 0), Vector2i(0, 1)] if absi(d.x) >= absi(d.y) else [Vector2i(0, 1), Vector2i(1, 0)]
	var c0: Vector2i = ruta[i0]
	var bien: bool = false
	for e in ejes:
		var eje: Vector2i = e
		var trav: Vector2i = Vector2i(eje.y, eje.x)
		var foto: Array = [_suelo_bosque.duplicate(), _ocupada.duplicate()]
		precipicio = []
		var hay: Dictionary = {}
		for lado in range(s_max + 1, 14):
			for s in range(-lado, lado + 1):
				for j in range(hondo):
					var c: Vector2i = c0 + trav * s + eje * j
					if c.x < 1 or c.y < 1 or c.x > w - 2 or c.y > h - 2 or _tipo(c) != SUELO or hay.has(c):
						continue
					hay[c] = true
					precipicio.append(c)
					_ocupar(c)
					_suelo_bosque.erase(c)
			if _tierra_cierra():
				break
		# Bien cortado: no se rodea y hay al menos un sitio donde el hueco mide justo `hondo` en línea recta con suelo firme a los dos lados
		# (desde donde nace el puente y donde llega). En un camino que baja en escalera no todo su ancho cruza recto: basta con uno.
		var cruce: bool = false
		for s in range(-14, 15):
			var base: Vector2i = c0 + trav * s
			var antes: Vector2i = base - eje
			var despues: Vector2i = base + eje * hondo
			var ok: bool = _tipo(antes) == SUELO and not hay.has(antes) and _tipo(despues) == SUELO and not hay.has(despues)
			for j in range(hondo):
				ok = ok and hay.has(base + eje * j)
			cruce = cruce or ok
		bien = not precipicio.is_empty() and _tierra_cierra() and cruce
		if bien:
			break
		_suelo_bosque = foto[0]
		_ocupada = foto[1]
		precipicio = []
	return bien


## ¿El precipicio corta de verdad? Sin cruzarlo, desde el claro de dentro no se llega al de la salida.
func _tierra_cierra() -> bool:
	if precipicio.is_empty() or _tierra_puntos.size() < 2:
		return true
	var desde: Vector2i = _tierra_puntos[0]
	var hasta: Vector2i = _tierra_puntos[1]
	if desde.x < 0 or hasta.x < 0:
		return true
	var bloq: Dictionary = {}
	for c in precipicio:
		bloq[c] = true
	return _distancias(desde, bloq)[hasta.y * w + hasta.x] < 0


# =====================================================================================================================
#  «pagina»: crece desde una sala raíz, con grupos simétricos y bucles
# =====================================================================================================================

func _gen_pagina() -> void:
	w = clampi(int(p["ancho"]), 15, ANCHO_MAX)
	h = clampi(int(p["alto"]), 15, ALTO_MAX)
	g = PackedByteArray()
	g.resize(w * h)
	g.fill(MURO)
	var lmin: int = clampi(int(p["lado_min"]), 2, 12)
	var lmax: int = clampi(int(p["lado_max"]), lmin, 16)
	var quiero: int = clampi(int(p["n_salas"]), 2, 40)
	var sim: bool = bool(p["simetria"])
	var pasillos: float = clampf(float(p["pasillos"]), 0.0, 90.0)
	var rw: int = _azar(maxi(lmin, 3), maxi(lmax, 3))
	if rw % 2 == 0:
		rw += 1
	var rh: int = _azar(maxi(lmin, 3), maxi(lmax, 3))
	rw = mini(rw, w - 4 - (w % 2))
	rh = mini(rh, h - 4)
	var raiz: Rect2i = Rect2i((w - rw) / 2, h - 1 - rh, rw, rh)
	_eje = raiz.position.x + rw / 2
	_nueva_sala(raiz)
	salas[0]["eje"] = true
	var intentos: int = quiero * 80
	while salas.size() < quiero and intentos > 0:
		intentos -= 1
		var ip: int = clampi(salas.size() - 1 - int(absf(rng.randfn(0.0, salas.size() * 0.45))), 0, salas.size() - 1)
		var padre: Dictionary = salas[ip]
		var pr: Rect2i = padre["rect"]
		var lado: int = int([0, 0, 0, 0, 1, 1, 1, 3, 3, 3, 2][_azar(0, 10)])
		var ww: int = _azar(lmin, lmax)
		var hh: int = _azar(lmin, lmax)
		if _pct(pasillos):
			var largo: int = _azar(4, 8)
			var grueso: int = _azar(1, 2)
			ww = grueso if lado % 2 == 0 else largo
			hh = largo if lado % 2 == 0 else grueso
		var centrada: bool = sim and bool(padre["eje"]) and lado % 2 == 0
		if centrada and ww % 2 == 0:
			ww += 1
		var x: int = 0
		var y: int = 0
		match lado:
			0:
				y = pr.position.y - 1 - hh
				x = _eje - ww / 2 if centrada else _alinear(pr.position.x, pr.size.x, ww)
			2:
				y = pr.end.y + 1
				x = _eje - ww / 2 if centrada else _alinear(pr.position.x, pr.size.x, ww)
			1:
				x = pr.end.x + 1
				y = _alinear(pr.position.y, pr.size.y, hh)
			_:
				x = pr.position.x - 1 - ww
				y = _alinear(pr.position.y, pr.size.y, hh)
		var rect: Rect2i = Rect2i(x, y, ww, hh)
		if not _pagina_cabe(rect):
			continue
		var pc: Vector2i = _puerta_entre(pr, rect)
		if pc.x < 0:
			continue
		var nueva: int = _nueva_sala(rect)
		salas[nueva]["eje"] = centrada
		puertas.append({"c": pc, "salas": [ip, nueva], "tipo": "paso"})
		if sim and not centrada:
			var pm: int = ip if bool(padre["eje"]) else int(padre["gemela"])
			if pm >= 0:
				var rm: Rect2i = Rect2i(2 * _eje - (x + ww - 1), y, ww, hh)
				if rm != rect and _pagina_cabe(rm):
					var gm: int = _nueva_sala(rm)
					salas[nueva]["gemela"] = gm
					salas[gm]["gemela"] = nueva
					puertas.append({"c": Vector2i(2 * _eje - pc.x, pc.y), "salas": [pm, gm], "tipo": "paso"})
	# Bucles: entre salas que comparten pared y no tienen puerta.
	var unidas: Dictionary = {}
	for pu in puertas:
		var de: Array = pu["salas"]
		unidas[Vector2i(mini(int(de[0]), int(de[1])), maxi(int(de[0]), int(de[1])))] = true
	var bucles: float = clampf(float(p["bucles"]), 0.0, 100.0)
	for i in range(salas.size()):
		for j in range(i + 1, salas.size()):
			if unidas.has(Vector2i(i, j)):
				continue
			var pc2: Vector2i = _puerta_entre(salas[i]["rect"], salas[j]["rect"])
			if pc2.x >= 0 and _pct(bucles):
				puertas.append({"c": pc2, "salas": [i, j], "tipo": "paso"})
	for s in salas:
		var r: Rect2i = s["rect"]
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				g[yy * w + xx] = SUELO
	for pu in puertas:
		g[int(pu["c"].y) * w + int(pu["c"].x)] = SUELO
	if salas.size() < quiero:
		avisos.append("Solo caben %d salas de las %d pedidas en %d × %d: agranda el mapa o achica las salas." % [salas.size(), quiero, w, h])


## Dónde empieza un tramo de largo `l` pegado a otro que va de `p0` con largo `pl`: centrado la mitad de las veces; si no, donde caiga con solape.
func _alinear(p0: int, pl: int, l: int) -> int:
	if _pct(50.0):
		return p0 + (pl - l) / 2
	return _azar(p0 - l + 1, p0 + pl - 1)


func _pagina_cabe(rect: Rect2i) -> bool:
	if not Rect2i(1, 1, w - 2, h - 2).encloses(rect):
		return false
	var gorda: Rect2i = rect.grow(1)
	for s in salas:
		if gorda.intersects(s["rect"]):
			return false
	return true


## La casilla de pared entre dos salas separadas por una sola pared y con solape; (-1, -1) si no son vecinas.
func _puerta_entre(a: Rect2i, b: Rect2i) -> Vector2i:
	var x0: int = maxi(a.position.x, b.position.x)
	var x1: int = mini(a.end.x, b.end.x) - 1
	var y0: int = maxi(a.position.y, b.position.y)
	var y1: int = mini(a.end.y, b.end.y) - 1
	if x1 >= x0:
		if b.end.y + 1 == a.position.y:
			return Vector2i((x0 + x1) / 2, a.position.y - 1)
		if a.end.y + 1 == b.position.y:
			return Vector2i((x0 + x1) / 2, a.end.y)
	if y1 >= y0:
		if a.end.x + 1 == b.position.x:
			return Vector2i(a.end.x, (y0 + y1) / 2)
		if b.end.x + 1 == a.position.x:
			return Vector2i(a.position.x - 1, (y0 + y1) / 2)
	return Vector2i(-1, -1)


# =====================================================================================================================
#  Común: retoques, borde, conexión
# =====================================================================================================================

func _nueva_sala(rect: Rect2i) -> int:
	salas.append({"id": salas.size(), "rect": rect, "rol": "", "eje": false, "gemela": -1, "viva": true, "enemigos": 0, "dist": 0})
	return salas.size() - 1


func _aplicar_retoques(retoques: Dictionary) -> void:
	for c in retoques:
		var t: int = LETRA.find(String(retoques[c]))
		if t >= 0 and c is Vector2i:
			_poner(c, t)


func _cerrar_borde() -> void:
	for x in range(w):
		g[x] = MURO
		g[(h - 1) * w + x] = MURO
	for y in range(h):
		g[y * w] = MURO
		g[y * w + w - 1] = MURO


## Se queda con la mayor zona conexa; lo demás se tapa (puede pasar al pintar muros a mano o con formas de mapa raras).
func _quitar_inalcanzable() -> void:
	var res: Array = _componentes()
	var comp: PackedInt32Array = res[0]
	var tams: Array = res[1]
	if tams.size() <= 1:
		return
	var k: int = 0
	for t in range(tams.size()):
		if int(tams[t]) > int(tams[k]):
			k = t
	var quitadas: int = 0
	for i in range(w * h):
		if comp[i] >= 0 and comp[i] != k:
			g[i] = MURO
			quitadas += 1
	avisos.append("%d casillas quedaban aisladas del resto y se han tapado." % quitadas)


## El agua honda se nada, pero los enemigos no: si parte la tierra en trozos, se abre un vado (agua → suelo) por el camino más corto.
func _asegurar_tierra_conectada() -> void:
	for _v in range(80):
		var res: Array = _componentes(true)
		var comp: PackedInt32Array = res[0]
		var tams: Array = res[1]
		if tams.size() <= 1:
			return
		var k: int = 0
		for t in range(tams.size()):
			if int(tams[t]) < int(tams[k]):
				k = t
		var prev: PackedInt32Array = PackedInt32Array()
		prev.resize(w * h)
		prev.fill(-2)
		var cola: PackedInt32Array = PackedInt32Array()
		for i in range(w * h):
			if comp[i] == k:
				cola.append(i)
				prev[i] = -1
		var meta: int = -1
		var q: int = 0
		while q < cola.size() and meta < 0:
			var i2: int = cola[q]
			q += 1
			for d in DIRS:
				var x: int = i2 % w + d.x
				var y: int = i2 / w + d.y
				if x < 0 or y < 0 or x >= w or y >= h:
					continue
				var j: int = y * w + x
				if prev[j] != -2 or g[j] == MURO:
					continue
				prev[j] = i2
				if g[j] == SUELO:
					meta = j
					break
				cola.append(j)
		if meta < 0:
			return
		var cur: int = prev[meta]
		while cur >= 0 and comp[cur] != k:
			g[cur] = SUELO
			cur = prev[cur]


func _revisar_salas_y_puertas() -> void:
	for s in salas:
		var r: Rect2i = s["rect"]
		var n: int = 0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if _tipo(Vector2i(x, y)) == SUELO:
					n += 1
		if n * 2 < r.get_area() or n == 0:
			s["viva"] = false
	var buenas: Array = []
	for pu in puertas:
		var c: Vector2i = pu["c"]
		if _tipo(c) == MURO:
			continue
		var de: Array = []
		for sid in pu["salas"]:
			if bool(salas[int(sid)]["viva"]):
				de.append(int(sid))
		pu["salas"] = de
		buenas.append(pu)
	puertas = buenas


# =====================================================================================================================
#  Contenido
# =====================================================================================================================

func _vivas() -> Array:
	var res: Array = []
	for s in salas:
		if bool(s["viva"]):
			res.append(s)
	return res


## Casillas de suelo de una sala (sin agua).
func _celdas_sala(s: Dictionary) -> Array:
	var res: Array = []
	var r: Rect2i = s["rect"]
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _tipo(Vector2i(x, y)) == SUELO:
				res.append(Vector2i(x, y))
	return res


func _puertas_de(id: int) -> Array:
	var res: Array = []
	for pu in puertas:
		if (pu["salas"] as Array).has(id):
			res.append(pu)
	return res


func _cerca_de_puerta(c: Vector2i, radio: int = 1) -> bool:
	for pu in puertas:
		var d: Vector2i = (pu["c"] as Vector2i) - c
		if absi(d.x) <= radio and absi(d.y) <= radio:
			return true
	return false


func _libre(c: Vector2i) -> bool:
	return _tipo(c) == SUELO and not _ocupada.has(c)


## La casilla de suelo libre más cercana al centro de la sala.
func _centro_libre(s: Dictionary) -> Vector2i:
	var r: Rect2i = s["rect"]
	var centro: Vector2 = Vector2(r.position) + Vector2(r.size - Vector2i.ONE) * 0.5
	var mejor: Vector2i = Vector2i(-1, -1)
	var md: float = INF
	for c in _celdas_sala(s):
		if _ocupada.has(c):
			continue
		var d: float = Vector2(c).distance_squared_to(centro)
		if d < md:
			md = d
			mejor = c
	return mejor


## ¿Se puede bloquear esta casilla (un cofre, un jarrón, un brasero) sin partir el mapa? La tierra que queda tiene que seguir siendo una sola pieza.
func _puede_bloquear(c: Vector2i) -> bool:
	if not _libre(c) or _cerca_de_puerta(c):
		return false
	var prueba: Dictionary = _bloqueos.duplicate()
	prueba[c] = true
	# Lo que ya bloquea y hay que TOCAR (cofres, braseros, bloques) tiene que conservar al menos una casilla libre al lado.
	for d in DIRS:
		var v: Vector2i = c + d
		if not _bloqueos.has(v):
			continue
		var libres: int = 0
		for d2 in DIRS:
			var u: Vector2i = v + d2
			if (_tipo(u) == SUELO or _puentes.has(u)) and not prueba.has(u):
				libres += 1
		if libres == 0:
			return false
	return (_componentes(true, prueba)[1] as Array).size() <= 1


func _ocupar(c: Vector2i, bloquea: bool = false) -> void:
	_ocupada[c] = true
	if bloquea:
		_bloqueos[c] = true


func _objeto(c: Vector2i, tipo: String, id: String = "") -> void:
	objetos.append({"c": c, "tipo": tipo, "id": id})


## Una salida en la sala `s`, lejos de `ref` (donde aparece la jugadora): la casilla libre más al sur y, a igualdad, la más alineada con `ref`.
func _poner_salida(s: Dictionary, destino: String, n: int, ref: Vector2i) -> bool:
	var mejor: Vector2i = Vector2i(-1, -1)
	for c in _celdas_sala(s):
		if _ocupada.has(c) or _cerca_de_puerta(c) or absi(c.x - ref.x) + absi(c.y - ref.y) < 2:
			continue
		if mejor.x < 0 or c.y > mejor.y or (c.y == mejor.y and absi(c.x - ref.x) < absi(mejor.x - ref.x)):
			mejor = c
	if mejor.x < 0:
		return false
	_ocupar(mejor)
	_objeto(mejor, "salida", "a_salida_%d" % n)
	lineas.append("; pieza a_salida_%d salida %d %d a=%s" % [n, mejor.x, mejor.y, destino])
	return true


## Como `_poner_salida`, pero pegada al LADO del borde pedido ("n", "s", "e", "o"): la casilla libre de la sala que más se acerca a ese
## borde y, a igualdad, la más alineada con `ref`. Sin lado, la de siempre.
func _poner_salida_lado(s: Dictionary, destino: String, n: int, ref: Vector2i, lado: String) -> bool:
	if not LADO_VEC.has(lado):
		return _poner_salida(s, destino, n, ref)
	var hacia: Vector2i = LADO_VEC[lado]
	var mejor: Vector2i = Vector2i(-1, -1)
	for c in _celdas_sala(s):
		if _ocupada.has(c) or _cerca_de_puerta(c) or absi(c.x - ref.x) + absi(c.y - ref.y) < 2:
			continue
		var a: int = c.x * hacia.x + c.y * hacia.y
		var am: int = mejor.x * hacia.x + mejor.y * hacia.y
		var lat: int = absi((c - ref).x * hacia.y) + absi((c - ref).y * hacia.x)
		var latm: int = absi((mejor - ref).x * hacia.y) + absi((mejor - ref).y * hacia.x)
		if mejor.x < 0 or a > am or (a == am and lat < latm):
			mejor = c
	if mejor.x < 0:
		return false
	_ocupar(mejor)
	_objeto(mejor, "salida", "a_salida_%d" % n)
	lineas.append("; pieza a_salida_%d salida %d %d a=%s" % [n, mejor.x, mejor.y, destino])
	return true


const LADO_VEC: Dictionary = {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "o": Vector2i(-1, 0)}

## El lado pedido para la salida `k` en el bosque ("" en los demás algoritmos o sin lado).
func _lado_b(k: int) -> String:
	if String(p["algoritmo"]) != "bosque" or k >= _b_lados.size():
		return ""
	return String(_b_lados[k])


## El claro que el bosque reservó para la salida `k`, si sigue vivo y libre ({} si no).
func _sala_b(k: int) -> Dictionary:
	if k <= 0 or k >= _b_salas.size():
		return {}
	var s: Dictionary = salas[int(_b_salas[k])]
	if bool(s["viva"]) and (String(s["rol"]) == "" or String(s["rol"]) == "salida"):
		return s
	return {}


func _rect_txt(r: Rect2i) -> String:
	return "%d,%d..%d,%d" % [r.position.x, r.position.y, r.end.x - 1, r.end.y - 1]


# =====================================================================================================================
#  Campamentos goblin (22/11, Pablo: «sala campamento»)
# =====================================================================================================================

## LA SALA CAMPAMENTO. Una sala grande (al menos CAMP_LADO_MIN), sin papel y no pegada al inicio, se vuelve un campamento goblin con las mismas
## piezas que el de Bosque 02 (letras del plano que monta `presentacion/prueba_test2.gd`):
##   · EMPALIZADA `x` en el anillo de dentro de la sala, con una PUERTA GOBLIN `y` (arde: se quema para entrar) delante de cada entrada;
##   · dentro: la FOGATA `T` en el centro, una TORRE `o` (arde) en un rincón del fondo, TIENDAS `t` contra el fondo y un ESTANDARTE `V` junto a la entrada;
##   · su gente: guardias `W` / `A` según el tamaño y el parámetro `enemigos`, y un CHAMÁN si es grande;
##   · un VIGÍA que cuenta a todos y un COFRE ÉPICO que aparece al limpiarlo, y una ZONA con la luz de fuego y el botín de campamento.
## No se cierra con cerrojo (Pablo, 5/11: en zona abierta no hay cerrojo que encierre): la barrera es la puerta que arde. Si la empalizada deja el mapa
## partido o sin solución, se deshace y se prueba la siguiente sala. Las puertas goblin no cuentan como bloqueo: el fuego siempre está en el kit.
const CAMP_LADO_MIN: Vector2i = Vector2i(7, 6)    ## casillas de la sala (con la empalizada dentro quedan 5 × 4 de patio)
const CAMP_CASILLAS_POR_GUARDIA: float = 12.0     ## con `enemigos` = 1: un guardia por cada tantas casillas de patio (2 como poco, 5 como mucho)
const CAMP_PATIO_CHAMAN: int = 30                 ## casillas de patio a partir de las que hay chamán
const CAMP_DIST_MIN: float = 0.3                  ## fracción de la distancia máxima al inicio por debajo de la que no se pone (no a la entrada)

func _poner_campamentos(vivas: Array, dmax: int, nv: String) -> void:
	var quiero: int = clampi(int(p.get("campamentos", 0)), 0, 4)
	if quiero <= 0:
		return
	var orden: Array = vivas.filter(func(s: Dictionary) -> bool:
		var r: Rect2i = s["rect"]
		return String(s["rol"]) == "" and r.size.x >= CAMP_LADO_MIN.x and r.size.y >= CAMP_LADO_MIN.y and float(s["dist"]) >= CAMP_DIST_MIN * dmax)
	orden.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var aa: int = (a["rect"] as Rect2i).get_area()
		var ab: int = (b["rect"] as Rect2i).get_area()
		return aa > ab or (aa == ab and int(a["id"]) < int(b["id"])))
	var hechos: int = 0
	for s in orden:
		if hechos >= quiero:
			break
		if _campamento_en(s, hechos + 1, nv):
			hechos += 1
	if hechos < quiero:
		avisos.append("Solo caben %d campamentos de los %d pedidos (hacen falta salas de %d × %d o más, lejos del inicio y sin otro papel)." % [hechos, quiero, CAMP_LADO_MIN.x, CAMP_LADO_MIN.y])


## Monta el campamento `n` en la sala `s`. Devuelve false (y lo deja todo como estaba) si no cabe sin partir el mapa.
func _campamento_en(s: Dictionary, n: int, nv: String) -> bool:
	var r: Rect2i = s["rect"]
	var guardado: Array = [letras.duplicate(), _ocupada.duplicate(), _bloqueos.duplicate(), objetos.duplicate(true), lineas.duplicate(), g.duplicate()]
	var anillo: Dictionary = {}
	for c in _celdas_sala(s):
		if c.x == r.position.x or c.x == r.end.x - 1 or c.y == r.position.y or c.y == r.end.y - 1:
			anillo[c] = true
	# Las puertas goblin: delante de cada entrada (la casilla del anillo pegada a la puerta, o la puerta misma si cae en el anillo).
	var puertas_g: Dictionary = {}
	for pu in _puertas_de(int(s["id"])):
		var dc: Vector2i = pu["c"]
		var cg: Vector2i = Vector2i(-1, -1)
		if anillo.has(dc):
			cg = dc
		else:
			for d in DIRS:
				if anillo.has(dc + d):
					cg = dc + d
					break
		if cg.x >= 0 and not _ocupada.has(cg):
			puertas_g[cg] = true
	if puertas_g.is_empty():
		return false
	# Empalizada: el resto del anillo que esté libre (lo ya puesto, como un activador o una pieza de puzle, se queda: hueco en la cerca).
	# Para el generador es PARED (MURO con la letra `x` encima): así ni parte el mapa sin que se note ni impide poner tiendas o la torre pegadas a ella
	# (lo que bloquea como un cofre necesita una casilla libre al lado; una pared, no).
	for c in anillo:
		if puertas_g.has(c) or _ocupada.has(c) or _tipo(c) != SUELO:
			continue
		letras[c] = "x"
		_poner(c, MURO)
	for c in puertas_g:
		letras[c] = "y"
		_ocupar(c)
		_objeto(c, "puerta_goblin", "camp%d_puerta" % n)
	if (_componentes(true, _bloqueos)[1] as Array).size() > 1 or not _resoluble():
		_deshacer_campamento(guardado)
		return false
	var patio: Rect2i = r.grow(-1)
	var centro: Vector2 = Vector2(patio.position) + Vector2(patio.size - Vector2i.ONE) * 0.5
	# Fogata en el centro (la casilla bloqueable más cercana).
	var por_centro: Array = _celdas_sala(s).filter(func(c: Vector2i) -> bool: return patio.has_point(c))
	por_centro.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(centro) < Vector2(b).distance_squared_to(centro))
	for c in por_centro:
		if _puede_bloquear(c):
			letras[c] = "T"
			_ocupar(c, true)
			_objeto(c, "brasero", "camp%d_fogata" % n)
			break
	# Torre en un rincón del fondo (los de arriba primero: la cámara mira al norte y se ve entera).
	for c in [patio.position, Vector2i(patio.end.x - 1, patio.position.y), Vector2i(patio.position.x, patio.end.y - 1), patio.end - Vector2i.ONE]:
		if _puede_bloquear(c):
			letras[c] = "o"
			_ocupar(c, true)
			_objeto(c, "torre_goblin", "camp%d_torre" % n)
			break
	# Tiendas contra el fondo del patio, una sí y otra no.
	var quiero_t: int = clampi(patio.size.x / 3, 1, 3)
	for x in range(patio.position.x + 1, patio.end.x - 1, 2):
		if quiero_t <= 0:
			break
		var c: Vector2i = Vector2i(x, patio.position.y)
		if _puede_bloquear(c):
			letras[c] = "t"
			_ocupar(c, true)
			_objeto(c, "tienda_goblin", "camp%d_tienda" % n)
			quiero_t -= 1
	# Estandarte junto a la primera entrada, por dentro y a un lado (sin tapar el paso).
	var cg0: Vector2i = puertas_g.keys()[0]
	var dentro: Vector2i = cg0
	for d in DIRS:
		if patio.has_point(cg0 + d):
			dentro = cg0 + d
			break
	if dentro != cg0:
		var lado: Vector2i = Vector2i(dentro.y - cg0.y, dentro.x - cg0.x)       # perpendicular a la entrada
		for c in [dentro + lado, dentro - lado]:
			if patio.has_point(c) and _puede_bloquear(c):
				letras[c] = "V"
				_ocupar(c, true)
				_objeto(c, "estandarte_goblin", "camp%d_estandarte" % n)
				break
	# Su gente: guardias (y chamán si es grande), lejos de las puertas goblin para que no se peguen a la cerca.
	var fuerza: float = clampf(float(p["enemigos"]), 0.0, 4.0)
	var libres: Array = _celdas_sala(s).filter(func(c: Vector2i) -> bool:
		if not patio.has_point(c) or _ocupada.has(c):
			return false
		for cg in puertas_g:
			if absi((cg as Vector2i).x - c.x) + absi((cg as Vector2i).y - c.y) <= 1:
				return false
		return true)
	_barajar(libres)
	var n_g: int = 0
	if fuerza > 0.0:
		n_g = clampi(int(round(libres.size() / CAMP_CASILLAS_POR_GUARDIA * fuerza)), 2, 5)
	var k: int = 0
	while k < mini(n_g, libres.size()):
		var c: Vector2i = libres[k]
		var arquero: bool = _pct(float(p["arqueros"]))
		letras[c] = "A" if arquero else "W"
		if arquero:
			p["_arqueros"] = true
		_ocupar(c)
		_objeto(c, "arquero" if arquero else "guerrero")
		k += 1
	s["enemigos"] = n_g
	if fuerza > 0.0 and patio.get_area() >= CAMP_PATIO_CHAMAN and k < libres.size():
		var cc: Vector2i = libres[k]
		_ocupar(cc)
		_objeto(cc, "chaman", "camp%d_chaman" % n)
		lineas.append("; pieza camp%d_chaman chaman %d %d" % [n, cc.x, cc.y])
		s["enemigos"] = int(s["enemigos"]) + 1
	# Vigía y cofre épico que aparece al limpiarlo; zona con la luz de fuego y el botín de campamento.
	var flag: String = "%s.campamento_%d.limpio" % [nv, n]
	var cv: Vector2i = patio.position
	lineas.append("; pieza camp%d_vigia vigia %d %d de=%s flag=%s" % [n, cv.x, cv.y, _rect_txt(r), flag])
	s["vigia"] = true
	var premios: Array = (COFRES["epico"]["premios"] as Dictionary).keys()
	var premio: String = String(premios[_azar(0, premios.size() - 1)])
	var cc2: Vector2i = _sitio_bloqueo(s, true)
	if cc2.x >= 0:
		_ocupar(cc2, true)
		_objeto(cc2, "cofre_epico", "camp%d_cofre" % n)
		lineas.append("; pieza camp%d_cofre cofre %d %d modelo=epico aparece_si=flag.%s abierto=%s.campamento_%d.cofre da=%s" % [n, cc2.x, cc2.y, flag, nv, n, premio])
	else:
		avisos.append("El campamento %d no tiene sitio para su cofre." % n)
	lineas.append("; zona %s fuego mezcla=1 id=campamento_%d titulo=El_campamento_goblin botin=campamento" % [_rect_txt(r), n])
	for l in ["x", "y", "o", "t", "V"]:
		if not _letras_extra.contains(l):
			_letras_extra += l
	s["rol"] = "campamento"
	return true


func _deshacer_campamento(guardado: Array) -> void:
	letras = guardado[0]
	_ocupada = guardado[1]
	_bloqueos = guardado[2]
	objetos = guardado[3]
	lineas = guardado[4]
	g = guardado[5]


func _poblar() -> void:
	var vivas: Array = _vivas()
	if vivas.is_empty():
		# Sin salas (un mapa retocado hasta dejarlo sin ninguna): todo lo que se pisa hace de sala única.
		var caja: Rect2i = Rect2i()
		var hay: bool = false
		for i in range(w * h):
			if g[i] == SUELO:
				var c: Vector2i = Vector2i(i % w, i / w)
				caja = caja.expand(c) if hay else Rect2i(c, Vector2i.ONE)
				hay = true
		if not hay:
			avisos.append("El mapa no tiene suelo.")
			return
		caja.size += Vector2i.ONE
		_nueva_sala(caja)
		vivas = _vivas()
	var nv: String = String(p["nombre"]).to_lower()
	_nv = nv
	var cueva: bool = String(p["estilo"]) == "cueva"
	# 1 · Inicio: la sala más al sur (la cámara mira al norte: se entra desde abajo). En «pagina», la raíz.
	var s_ini: Dictionary = vivas[0]
	var bosque: bool = String(p["algoritmo"]) == "bosque"
	if bosque and not _b_salas.is_empty() and bool(salas[int(_b_salas[0])]["viva"]):
		s_ini = salas[int(_b_salas[0])]                 # el bosque ya eligió el claro del inicio (pegado a su lado, si lo pidió)
	elif String(p["algoritmo"]) != "pagina" or not bool(salas[0]["viva"]):
		for s in vivas:
			if (s["rect"] as Rect2i).end.y > (s_ini["rect"] as Rect2i).end.y:
				s_ini = s
	else:
		s_ini = salas[0]
	s_ini["rol"] = "inicio"
	inicio = _centro_libre(s_ini)
	letras[inicio] = "S"
	_ocupar(inicio)
	_objeto(inicio, "inicio")
	lineas.append("; pieza inicio entrada %d %d" % [inicio.x, inicio.y])
	# Salidas: varias, separadas por comas. La primera va en la sala de inicio; las demás, cada una en una sala lejana (más abajo).
	# 18/11: `Nivel:entrada=llegada` da NOMBRE a la llegada que acompaña a esa salida (por donde se entra a este nivel viniendo de aquel).
	# Hace falta para sustituir un nivel al que ya viajan otros: las cuevas salen a `Bosque_02:boca_cueva`, así que el Bosque 02 nuevo
	# necesita una llegada que se llame `boca_cueva`. Sin `=`, las de siempre: `inicio` la primera y `entrada_2`, `entrada_3`… las demás.
	var destinos: PackedStringArray = PackedStringArray()
	var llegadas: PackedStringArray = PackedStringArray()
	for d in String(p["salida_a"]).replace(";", ",").replace(" ", ",").split(",", false):
		var trozos_d: PackedStringArray = d.split("=", true, 1)
		destinos.append(trozos_d[0])
		llegadas.append(trozos_d[1] if trozos_d.size() > 1 else "")
	if llegadas.size() > 0 and llegadas[0] != "" and llegadas[0] != "inicio":
		lineas.append("; pieza %s entrada %d %d" % [llegadas[0], inicio.x, inicio.y])       # la sala de inicio, también con ese nombre
	if destinos.size() > 0 and not _poner_salida_lado(s_ini, destinos[0], 1, inicio, _lado_b(0)):
		avisos.append("No cabe la salida en la sala de inicio (demasiado pequeña).")
	# El bosque reserva ya los claros de sus salidas (si no, el tesoro o la llave podrían quedarse con uno).
	if bosque:
		for k in range(1, destinos.size()):
			var sb: Dictionary = _sala_b(k)
			if not sb.is_empty() and String(sb["rol"]) == "":
				sb["rol"] = "salida"
	# 1b · Puzles del catalogo: antes de repartir papeles, porque cambian el suelo de su sala.
	_colocar_catalogo(vivas, nv)
	# 2 · Distancia de cada sala al inicio.
	var dist: PackedInt32Array = _distancias(inicio)
	var dmax: int = 1
	for s in vivas:
		var c: Vector2i = _centro_libre(s)
		s["dist"] = dist[c.y * w + c.x] if c.x >= 0 else 0
		dmax = maxi(dmax, int(s["dist"]))
	# 3 · Sala del tesoro: la más lejana; mejor una con una sola puerta, que se cierra con llave.
	var s_tes: Dictionary = {}
	var puerta_llave: Dictionary = {}
	if bool(p["tesoro"]) and vivas.size() >= 2:
		var orden: Array = vivas.filter(func(s: Dictionary) -> bool: return String(s["rol"]) == "")
		orden.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["dist"]) > int(b["dist"]) or (int(a["dist"]) == int(b["dist"]) and int(a["id"]) < int(b["id"])))
		for s in orden:
			if _puertas_de(int(s["id"])).size() == 1:
				s_tes = s
				break
		if s_tes.is_empty() and bool(p["llave"]):
			# Ninguna sala de una sola puerta: se intenta tapiar las puertas de más de la más lejana (si el resto sigue unido).
			for s in orden.slice(0, 4):
				var ps: Array = _puertas_de(int(s["id"]))
				if ps.size() < 2:
					continue
				ps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return dist[int(a["c"].y) * w + int(a["c"].x)] < dist[int(b["c"].y) * w + int(b["c"].x)])
				var copia: PackedByteArray = g.duplicate()
				for k in range(1, ps.size()):
					g[int(ps[k]["c"].y) * w + int(ps[k]["c"].x)] = MURO
				if (_componentes()[1] as Array).size() <= 1:
					for k in range(1, ps.size()):
						puertas.erase(ps[k])
					s_tes = s
					break
				g = copia
		if s_tes.is_empty() and not orden.is_empty():
			s_tes = orden[0]
		if not s_tes.is_empty():
			s_tes["rol"] = "tesoro"
			var pt: Array = _puertas_de(int(s_tes["id"]))
			if bool(p["llave"]) and pt.size() == 1 and vivas.size() >= 3:
				puerta_llave = pt[0]
	# 4 · La llave: en la sala más lejana a la que se llega SIN cruzar la puerta del tesoro.
	var s_llave: Dictionary = {}
	var sitio_llave: Vector2i = Vector2i(-1, -1)
	if not puerta_llave.is_empty():
		var sin: PackedInt32Array = _distancias(inicio, {puerta_llave["c"]: true})
		var md: int = -1
		for s in vivas:
			if String(s["rol"]) != "":
				continue
			var c: Vector2i = _centro_libre(s)
			if c.x >= 0 and sin[c.y * w + c.x] > md:
				md = sin[c.y * w + c.x]
				s_llave = s
		# El cofre de la llave se reserva YA: si no cabe, no hay puerta con llave (una puerta sin llave dejaría el tesoro sin salida).
		if not s_llave.is_empty():
			sitio_llave = _sitio_bloqueo(s_llave, true)
			if sitio_llave.x < 0:
				s_llave = {}
		if s_llave.is_empty():
			puerta_llave = {}
		else:
			_ocupar(sitio_llave, true)
			s_llave["rol"] = "llave"
			puerta_llave["tipo"] = "llave"
			_llave_barrera = {"celdas": [puerta_llave["c"]], "act_celdas": [sitio_llave]}
			var pc: Vector2i = puerta_llave["c"]
			_ocupar(pc)
			_objeto(pc, "puerta_llave", "puerta_tesoro")
			lineas.append("; pieza puerta_tesoro puerta %d %d modelo=llave llave=%s.tesoro.llave gasta=no abierto=%s.tesoro.puerta" % [pc.x, pc.y, nv, nv])
	# 4b · Las demás salidas: cada una en la sala sin papel más alejada de las salidas ya puestas, con su propia entrada (`entrada_<n>`)
	# para que el otro nivel pueda traer a la jugadora justo ahí.
	var con_salida: Array = [s_ini]
	for k in range(1, destinos.size()):
		var sala_k: Dictionary = _sala_b(k) if bosque else {}
		var lejania: float = INF if not sala_k.is_empty() else -1.0          # con claro reservado no se busca otro
		for s in vivas:
			if String(s["rol"]) != "" or lejania == INF:
				continue
			var dm: float = INF
			for u in con_salida:
				dm = minf(dm, Vector2((s["rect"] as Rect2i).get_center()).distance_to(Vector2((u["rect"] as Rect2i).get_center())))
			if dm > lejania:
				lejania = dm
				sala_k = s
		var puesta: bool = false
		if not sala_k.is_empty():
			var llegada: Vector2i = _centro_libre(sala_k)
			if llegada.x >= 0:
				_ocupar(llegada)
				if _poner_salida_lado(sala_k, destinos[k], k + 1, llegada, _lado_b(k)):
					sala_k["rol"] = "salida"
					con_salida.append(sala_k)
					var id_llegada: String = llegadas[k] if llegadas[k] != "" else "entrada_%d" % (k + 1)
					_objeto(llegada, "entrada", id_llegada)
					lineas.append("; pieza %s entrada %d %d" % [id_llegada, llegada.x, llegada.y])
					puesta = true
				else:
					_ocupada.erase(llegada)
		if not puesta:
			avisos.append("No queda sala libre para la salida a %s: añade salas o quita salidas." % destinos[k])
	# 4c · Barreras: pasos obligados que se cierran con una puerta o un puente y se abren con un activador puesto ANTES de la barrera.
	var quiero_barreras: int = clampi(int(p["barreras"]), 0, 8)
	if quiero_barreras > 0:
		if not bool(p["b_braseros"]) and not bool(p["b_placa"]):
			avisos.append("Hay barreras pedidas pero ningún activador permitido (braseros o placa): no se pone ninguna.")
		else:
			for paso in _pasos_candidatos():
				if _barreras.size() >= quiero_barreras:
					break
				_intentar_barrera(paso, _barreras.size() + 1, vivas, cueva)
			if _barreras.size() < quiero_barreras:
				avisos.append("Solo caben %d barreras de las %d pedidas (hacen falta pasos obligados y salas libres para sus activadores)." % [_barreras.size(), quiero_barreras])
	# 4d · Campamentos goblin (22/11): antes de las charcas y los enemigos, porque ponen su empalizada, su gente y su cofre.
	_poner_campamentos(vivas, dmax, nv)
	# 5 · Charcas dentro de las salas grandes (dejando libre el anillo de las paredes: no cortan el paso).
	for s in vivas:
		var r: Rect2i = s["rect"]
		if String(s["rol"]) == "inicio" or String(s["rol"]) == "puzle" or String(s["rol"]) == "campamento" or r.size.x < 5 or r.size.y < 5 or String(p["algoritmo"]) == "cueva" or bosque:
			continue
		if not _pct(float(p["charcas"])):
			continue
		var cw: int = _azar(2, maxi(2, r.size.x - 3))
		var ch: int = _azar(2, maxi(2, r.size.y - 3))
		var cx: int = _azar(r.position.x + 1, r.end.x - 1 - cw)
		var cy: int = _azar(r.position.y + 1, r.end.y - 1 - ch)
		var sin_charca: PackedByteArray = g.duplicate()
		for y in range(cy, cy + ch):
			for x in range(cx, cx + cw):
				var esquina: bool = (x == cx or x == cx + cw - 1) and (y == cy or y == cy + ch - 1)
				if esquina and cw >= 3 and ch >= 3:
					continue
				# Ni encima ni pegada a nada ya colocado (un cofre, un activador, la línea del bloque): el agua es pared y lo dejaría aislado.
				var pegada: bool = false
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						pegada = pegada or _ocupada.has(Vector2i(x + ox, y + oy))
				if pegada:
					continue
				g[y * w + x] = AGUA
		# Los huecos que deja la regla anterior pueden quedar como una isla dentro de la charca: si la tierra se parte o el mapa
		# deja de poder completarse, esta sala se queda sin charca.
		if (_componentes(true, _bloqueos)[1] as Array).size() > 1 or not _resoluble():
			g = sin_charca
	# 6 · Cofres (bloquean su casilla).
	if not s_tes.is_empty():
		var ct: Vector2i = _sitio_bloqueo(s_tes, true)
		if ct.x >= 0:
			_ocupar(ct, true)
			_objeto(ct, "cofre_tesoro", "tesoro")
			lineas.append("; pieza tesoro cofre %d %d abierto=%s.tesoro.cofre da=oro:60+pocion:1" % [ct.x, ct.y, nv])
		else:
			avisos.append("No cabe el cofre en la sala del tesoro.")
	# 7 · Enemigos: más cuanto mayor es la sala y más lejos está. La sala del tesoro con llave es premio: sin guardia.
	var fuerza: float = clampf(float(p["enemigos"]), 0.0, 4.0)
	var hay_arquero: bool = false
	for s in vivas:
		var rol: String = String(s["rol"])
		if rol == "inicio" or rol == "salida" or rol == "puzle" or rol == "campamento" or (rol == "tesoro" and not puerta_llave.is_empty()):
			continue                               # donde se llega de otro nivel no espera nadie (el campamento ya trae su gente)
		var celdas: Array = _celdas_sala(s).filter(func(c: Vector2i) -> bool: return not _ocupada.has(c) and not _cerca_de_puerta(c) and absi(c.x - inicio.x) + absi(c.y - inicio.y) >= 5)
		var n: int = clampi(int(round(celdas.size() / CASILLAS_POR_ENEMIGO * fuerza * (0.6 + 0.8 * int(s["dist"]) / float(dmax)))), 0, 5)
		if rol == "llave" and fuerza > 0.0:
			n = maxi(n, 1)
		_barajar(celdas)
		for k in range(mini(n, celdas.size())):
			var c: Vector2i = celdas[k]
			var arquero: bool = _pct(float(p["arqueros"]))
			letras[c] = "A" if arquero else "W"
			hay_arquero = hay_arquero or arquero
			_ocupar(c)
			_objeto(c, "arquero" if arquero else "guerrero")
			s["enemigos"] = int(s["enemigos"]) + 1
	# 8 · Vigías y cerrojos: la sala de la llave siempre lleva vigía (el cofre aparece al limpiarla); otras se cierran hasta vencer.
	for s in vivas:
		if int(s["enemigos"]) == 0 or String(s["rol"]) == "campamento":
			continue                               # el campamento pone su propio vigía y no se cierra (Pablo, 5/11: en zona abierta no hay cerrojo)
		var rol: String = String(s["rol"])
		var r: Rect2i = s["rect"]
		var celdas_puerta: Array = []
		var compartida: bool = false               # una puerta que ya es el cerrojo de la sala vecina: dos cerrojos no caben en la misma casilla
		for pu in _puertas_de(int(s["id"])):
			if String(pu["tipo"]) == "paso":
				celdas_puerta.append(pu)
			elif String(pu["tipo"]) == "cerrojo":
				compartida = true
		var cierra: bool = rol != "tesoro" and not compartida and not celdas_puerta.is_empty() and r.get_area() >= 12 and _pct(float(p["salas_cerradas"]))
		if not cierra and rol != "llave":
			continue
		var n: int = int(s["id"])
		var flag: String = "%s.sala_%d.limpia" % [nv, n]
		var cv: Vector2i = r.position                # la esquina de la sala, o su primera casilla de suelo si la esquina es pared
		if _tipo(cv) == MURO:                        # (una plantilla del catálogo pone paredes dentro o agranda la sala)
			for c in _celdas_sala(s):
				if _tipo(c) == SUELO:
					cv = c
					break
		lineas.append("; pieza vigia_%d vigia %d %d de=%s flag=%s" % [n, cv.x, cv.y, _rect_txt(r), flag])
		s["vigia"] = true
		if cierra:
			var txt: PackedStringArray = PackedStringArray()
			for pu in celdas_puerta:
				pu["tipo"] = "cerrojo"
				txt.append("%d,%d" % [int(pu["c"].x), int(pu["c"].y)])
				_ocupar(pu["c"])
				_objeto(pu["c"], "cerrojo", "cerrojo_%d" % n)
			var c0: Vector2i = celdas_puerta[0]["c"]
			lineas.append("; pieza cerrojo_%d cerrojo %d %d celdas=%s sala=%s hasta=%s" % [n, c0.x, c0.y, "+".join(txt), _rect_txt(r), flag])
			lineas.append("; puzle abre_%d cuando=vigia_%d.todos_derrotados hace=cerrojo_%d.abrir" % [n, n, n])
			if rol == "":
				s["rol"] = "combate"
	if not s_llave.is_empty():
		_objeto(sitio_llave, "cofre_llave", "cofre_llave")
		var extra: String = " aparece_si=flag.%s.sala_%d.limpia" % [nv, int(s_llave["id"])] if s_llave.has("vigia") else ""
		lineas.append("; pieza cofre_llave cofre %d %d%s abierto=%s.tesoro.llave" % [sitio_llave.x, sitio_llave.y, extra, nv])
	# 9 · Braseros (letra T) en los rincones y jarrones contra la pared del fondo.
	var n_bras: float = clampf(float(p["braseros"]), 0.0, 4.0)
	var n_jar: float = clampf(float(p["jarrones"]), 0.0, 6.0)
	for s in vivas:
		var r: Rect2i = s["rect"]
		if r.size.x < 3 or r.size.y < 3 or String(s["rol"]) == "puzle" or String(s["rol"]) == "campamento":
			continue
		var quiero_b: int = int(n_bras) + (1 if _pct(fmod(n_bras, 1.0) * 100.0) else 0)
		var rincones: Array = [r.position, Vector2i(r.end.x - 1, r.position.y), Vector2i(r.position.x, r.end.y - 1), r.end - Vector2i.ONE]
		_barajar(rincones)
		for c in rincones:
			if quiero_b <= 0:
				break
			if _puede_bloquear(c):
				letras[c] = "T"
				_ocupar(c, true)
				_objeto(c, "brasero")
				if cueva:
					lineas.append("; pieza %s brasero %d %d luz=2.4 modelo=cueva" % [_id("brasero"), c.x, c.y])
				quiero_b -= 1
		var quiero_j: int = int(n_jar) + (1 if _pct(fmod(n_jar, 1.0) * 100.0) else 0)
		var fondo: Array = _celdas_sala(s).filter(func(c: Vector2i) -> bool: return _tipo(c + Vector2i(0, -1)) == MURO)
		_barajar(fondo)
		for c in fondo:
			if quiero_j <= 0:
				break
			if _puede_bloquear(c):
				_ocupar(c, true)
				var jid: String = _id("jarron")
				_objeto(c, "jarron", jid)
				lineas.append("; pieza %s jarron %d %d botin=%s" % [jid, c.x, c.y, "pocion" if _pct(20.0) else "oro"])
				quiero_j -= 1
	p["_arqueros"] = hay_arquero
	_aplicar_movidos()
	_aplicar_anadidos(nv)
	_aplicar_apariciones(nv)
	_emitir_barreras(nv)
	_pintar_terreno()


# =====================================================================================================================
#  Enemigos y cofres añadidos a mano
# =====================================================================================================================

## Pone los enemigos y cofres que se han añadido a mano (pestañas «Enemigos» y «Cofres»: se elige y se hace clic en el mapa). Va después
## de mover y con el mismo cuidado: se prueba la casilla pedida y, si no vale, las más cercanas; se queda con la primera que sea suelo
## libre y, para un cofre (que bloquea su casilla), que no parta el mapa ni lo deje sin solución. Si no hay sitio, no se pone y lo dice.
func _aplicar_anadidos(nv: String) -> void:
	var n_enem: int = 0
	var n_cofre: int = 0
	for pedido_v in _anadidos_pedidos:
		var ped: Dictionary = pedido_v
		var que: String = String(ped.get("que", ""))
		var tipo: String = String(ped.get("tipo", ""))
		var pedido: Vector2i = ped.get("c", Vector2i(-1, -1))
		var es_cofre: bool = que == "cofre"
		_indice_hecho.append(-1)
		if que == "salida":
			_anadir_salida(ped)
			continue
		if (es_cofre and not COFRES.has(tipo)) or (not es_cofre and not ENEMIGOS.has(tipo)):
			avisos.append("Lo añadido a mano en (%d, %d) no se reconoce («%s»): se descarta." % [pedido.x, pedido.y, tipo])
			continue
		var candidatos: Array = []
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				var c: Vector2i = pedido + Vector2i(dx, dy)
				if _dentro(c) and _tipo(c) == SUELO and not _ocupada.has(c) and not letras.has(c):
					candidatos.append(c)
		candidatos.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da: int = (a - pedido).length_squared()
			var db: int = (b - pedido).length_squared()
			return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
		var puesto: Vector2i = Vector2i(-1, -1)
		for c in candidatos.slice(0, 40):
			if not es_cofre:
				puesto = c                               # un enemigo no bloquea: cualquier suelo libre vale
				break
			if not _puede_bloquear(c):
				continue
			_ocupar(c, true)
			if (_componentes(true, _bloqueos)[1] as Array).size() <= 1 and _resoluble():
				puesto = c
				break
			_ocupada.erase(c)
			_bloqueos.erase(c)
		var nombre: String = ("un cofre %s" % String(COFRES[tipo]["titulo"]).to_lower()) if es_cofre else String(ENEMIGOS[tipo]["titulo"])
		if puesto.x < 0:
			avisos.append("No se ha podido poner %s cerca de (%d, %d): no hay suelo libre%s. No se añade." % [nombre, pedido.x, pedido.y,
				" donde no corte el paso" if es_cofre else ""])
			continue
		if puesto != pedido:
			avisos.append("%s que ponías en (%d, %d) ha quedado en (%d, %d): era el sitio válido más cercano." % [(nombre.substr(0, 1).to_upper() + nombre.substr(1)) if not es_cofre else "El cofre",
				pedido.x, pedido.y, puesto.x, puesto.y])
		var hecho: Dictionary = {"que": que, "tipo": tipo, "c": puesto}
		if es_cofre:
			n_cofre += 1
			var def: Dictionary = COFRES[tipo]
			var da: String = String(def.get("da", ""))
			var premio: String = String(ped.get("premio", ""))
			var extra: String = ""
			if tipo == "comun":
				# Sorteada, pero siempre la misma para este mapa y este cofre.
				var dado: RandomNumberGenerator = RandomNumberGenerator.new()
				dado.seed = hash("cofre %d de la semilla %d" % [n_cofre, int(p["semilla"])])
				var bolsa: Array = def["premios"]
				premio = String(bolsa[dado.randi() % bolsa.size()])
				da = premio
			else:
				if not (def["premios"] as Dictionary).has(premio):
					premio = String((def["premios"] as Dictionary).keys()[0])
				if premio.begins_with("glifo:"):
					extra = " glifo=" + premio.substr(6)
				else:
					da = premio if da == "" else da + "+" + premio
			hecho["premio"] = premio
			hecho["da"] = da
			var cid: String = "cofre_m%d" % n_cofre
			_objeto(puesto, "cofre_" + tipo, cid)
			lineas.append("; pieza %s cofre %d %d%s%s abierto=%s.%s.abierto da=%s" % [cid, puesto.x, puesto.y,
				(" modelo=" + String(def["modelo"])) if String(def["modelo"]) != "" else "", extra, nv, cid, da])
		else:
			n_enem += 1
			var def_e: Dictionary = ENEMIGOS[tipo]
			var eid: String = "enemigo_m%d" % n_enem
			_ocupar(puesto)
			_objeto(puesto, String(def_e["icono"]), eid)
			if def_e.has("letra"):
				letras[puesto] = String(def_e["letra"])
				if not _letras_extra.contains(String(def_e["letra"])) and not "#.~SWAT".contains(String(def_e["letra"])):
					_letras_extra += String(def_e["letra"])
				if tipo == "arquero":
					p["_arqueros"] = true
			else:
				var extra_e: String = String(def_e.get("extra", ""))
				if tipo == "mouro":
					# 21/11 (Pablo: el mouro «puede ponerse como generable»; resucita mientras su tumba no se tape): sin mámoa sería un enemigo normal, así que
					# se le pone su MÁMOA en una casilla libre a dos pasos (no pegada: que dé tiempo a verla) y se enlaza.
					var cm: Vector2i = Vector2i(-1, -1)
					for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if _libre(puesto + d) and not _cerca_de_puerta(puesto + d):
							cm = puesto + d
							break
					if cm.x >= 0:
						var mid: String = "mamoa_m%d" % n_enem
						_ocupar(cm)
						lineas.append("; pieza %s mamoa %d %d" % [mid, cm.x, cm.y])
						extra_e += " mamoa=" + mid
					else:
						avisos.append("El mouro de (%d, %d) no tiene sitio para su mámoa al lado: sale sin tumba (muere a la primera). Muévelo a un sitio con más suelo." % [puesto.x, puesto.y])
				lineas.append("; pieza %s %s %d %d%s" % [eid, String(def_e["pieza"]), puesto.x, puesto.y, extra_e])
		objetos[objetos.size() - 1]["anadido"] = anadidos_hechos.size()       # para que la herramienta sepa cuál de la lista es
		_indice_hecho[_indice_hecho.size() - 1] = anadidos_hechos.size()
		anadidos_hechos.append(hecho)


## Una SALIDA añadida a mano (18/11, pestaña «Salidas»): `tipo` = el destino `Nivel:entrada`; `modo` pisar | usar; `ancho` = casillas
## seguidas que ocupa (una puerta ancha); `marca` = se dibuja la marca en el suelo; `llegada` = cómo se llama el punto por el que se
## entra AQUÍ viniendo de allí (vacío = `llegada_m<n>`). Se pone en la casilla pedida o en la válida más cercana: hace falta sitio para
## todas sus casillas (en fila, de lado a lado o, si no, de arriba abajo) y una casilla libre pegada para la llegada. No bloquea.
func _anadir_salida(ped: Dictionary) -> void:
	var destino: String = String(ped.get("tipo", ""))
	var pedido: Vector2i = ped.get("c", Vector2i(-1, -1))
	var partes: PackedStringArray = destino.split(":")
	if partes.size() != 2 or partes[0] == "" or partes[1] == "":
		avisos.append("La salida de (%d, %d) no dice a dónde va («%s» no es Nivel:entrada): se descarta." % [pedido.x, pedido.y, destino])
		return
	var modo: String = "usar" if String(ped.get("modo", "pisar")) == "usar" else "pisar"
	var ancho: int = clampi(int(ped.get("ancho", 1)), 1, 4)
	var marca: bool = bool(ped.get("marca", true))
	var acceso: String = String(ped.get("acceso", ""))
	if not ["", "sendero", "boca"].has(acceso):
		acceso = ""
	var n_sal: int = 1
	for a in anadidos_hechos:
		n_sal += 1 if String(a["que"]) == "salida" else 0
	var sid: String = "salida_m%d" % n_sal
	# El nombre de la llegada: el pedido si es un nombre limpio que no esté ya cogido; si no, uno propio.
	var llegada: String = String(ped.get("llegada", "")).strip_edges()
	var cogidos: Dictionary = {}
	for l in lineas:
		var tl: PackedStringArray = l.substr(1).strip_edges().split(" ", false)
		if tl.size() >= 3 and tl[0] == "pieza":
			cogidos[tl[1]] = true
	var limpio: bool = llegada != ""
	for i in range(llegada.length()):
		var ch: String = llegada[i]
		limpio = limpio and ((ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_")
	if llegada != "" and (not limpio or cogidos.has(llegada)):
		avisos.append("La llegada «%s» de la salida a %s no vale (%s): se llama «llegada_m%d»." % [llegada, destino, "ese nombre ya lo usa otra pieza" if limpio else "solo letras sin acento, cifras y «_»", n_sal])
		llegada = ""
	if llegada == "":
		llegada = "llegada_m%d" % n_sal
	var candidatos: Array = []
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var c: Vector2i = pedido + Vector2i(dx, dy)
			if _dentro(c) and _libre(c) and not letras.has(c):
				candidatos.append(c)
	candidatos.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = (a - pedido).length_squared()
		var db: int = (b - pedido).length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var celdas: Array = []
	var entra: Vector2i = Vector2i(-1, -1)
	var ancla: Vector2i = Vector2i(-1, -1)          # lo que se guarda como «c» (en una boca, la casilla de la sala que tiene delante)
	if acceso == "boca":
		# BOCA EN LA PARED: se excava un hueco de dos casillas HACIA ARRIBA en la pared de una sala; la salida va al fondo y la llegada, en
		# la casilla de en medio. Solo hacia arriba: con la cámara del juego un pasillo de una casilla que va de lado a lado queda tapado
		# por la pared de delante, y uno hacia abajo queda detrás de ella. Tiene que ser roca por los dos lados y seguir siéndolo detrás.
		# Si la pared da para dos casillas, la llegada va en la de en medio; si solo da para una (lo normal en «salas», donde detrás de la
		# pared suele haber un pasillo), queda un NICHO de una casilla con la salida dentro y la llegada delante, en la sala.
		var cerca: Array = []
		for dy in range(-10, 11):
			for dx in range(-10, 11):
				var cb: Vector2i = pedido + Vector2i(dx, dy)
				if _dentro(cb) and _libre(cb) and not letras.has(cb):
					cerca.append(cb)
		cerca.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da: int = (a - pedido).length_squared()
			var db: int = (b - pedido).length_squared()
			return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
		for f in cerca:
			var n1: Vector2i = (f as Vector2i) + Vector2i(0, -1)
			var n2: Vector2i = (f as Vector2i) + Vector2i(0, -2)
			var una: bool = n1.y >= 1
			for q in [n1, n2, n1 + Vector2i(-1, 0), n1 + Vector2i(1, 0), n2 + Vector2i(-1, 0), n2 + Vector2i(1, 0)]:
				una = una and _dentro(q) and _tipo(q) == MURO and not _retoques.has(q)
			if not una:
				continue
			var dos: bool = n2.y >= 1
			for q in [n2 + Vector2i(0, -1), n2 + Vector2i(-1, -1), n2 + Vector2i(1, -1)]:
				dos = dos and _dentro(q) and _tipo(q) == MURO and not _retoques.has(q)
			g[n1.y * w + n1.x] = SUELO
			if dos:
				g[n2.y * w + n2.x] = SUELO
			celdas = [n2] if dos else [n1]
			entra = n1 if dos else (f as Vector2i)
			ancla = f
			ancho = 1
			break
		if celdas.is_empty():
			avisos.append("Cerca de (%d, %d) no hay una pared de arriba con roca detrás donde abrir la boca de la salida a %s: se pone en el suelo, con sendero." % [pedido.x, pedido.y, destino])
			acceso = "sendero"
	for c in candidatos.slice(0, 60) if celdas.is_empty() else []:
		for paso in [Vector2i(1, 0), Vector2i(0, 1)]:
			var fila: Array = []
			for k in range(ancho):
				var q: Vector2i = (c as Vector2i) + (paso as Vector2i) * k
				if _dentro(q) and _libre(q) and not letras.has(q):
					fila.append(q)
			if fila.size() != ancho:
				continue
			# La llegada: una casilla libre pegada a la salida (no encima: al llegar no hay que estar pisándola).
			var e: Vector2i = Vector2i(-1, -1)
			for q in fila:
				for d in DIRS:
					var v: Vector2i = (q as Vector2i) + d
					if e.x < 0 and not fila.has(v) and _dentro(v) and _libre(v) and not letras.has(v):
						e = v
			if e.x >= 0:
				celdas = fila
				entra = e
				break
		if not celdas.is_empty():
			break
	if celdas.is_empty():
		avisos.append("No se ha podido poner la salida a %s cerca de (%d, %d): no hay %d casillas libres seguidas con otra al lado para la llegada. No se añade." % [destino, pedido.x, pedido.y, ancho])
		return
	var c0: Vector2i = celdas[0]
	if ancla.x < 0:
		ancla = c0
	if ancla != pedido:
		avisos.append("La salida a %s que ponías en (%d, %d) ha quedado en (%d, %d): era el sitio válido más cercano." % [destino, pedido.x, pedido.y, c0.x, c0.y])
	var txt: PackedStringArray = PackedStringArray()
	for q in celdas:
		_ocupar(q)
		_objeto(q, "salida", sid)
		objetos[objetos.size() - 1]["anadido"] = anadidos_hechos.size()
		txt.append("%d,%d" % [int(q.x), int(q.y)])
	_ocupar(entra)
	_objeto(entra, "entrada", llegada)
	objetos[objetos.size() - 1]["de_salida"] = true          # se mueve con su salida, no suelta
	lineas.append("; pieza %s salida %d %d a=%s%s%s%s" % [sid, c0.x, c0.y, destino, (" celdas=" + "+".join(txt)) if ancho > 1 else "",
		" modo=usar" if modo == "usar" else "", "" if marca else " marca=no"])
	lineas.append("; pieza %s entrada %d %d" % [llegada, entra.x, entra.y])
	# EL ACCESO, para que se intuya que por ahí se sale: un SENDERO de losas (`R`: losas en el bosque, basalto en la cueva; la tierra `g`
	# no valdría, que es la de los pasillos) que llega a la salida siguiendo el camino más corto desde el inicio. Con sendero, 8 casillas;
	# una boca lleva las suyas y 3 más dentro de la sala. No pisa casillas con algo encima ni con letra propia.
	var losas: Array = []
	if acceso == "sendero" or acceso == "boca":
		var dist: PackedInt32Array = _distancias(inicio)
		var paso_s: Vector2i = entra
		var largo: int = 8 if acceso == "sendero" else 4
		var visto: Dictionary = {}
		for _k in range(largo):
			if not _dentro(paso_s) or dist[paso_s.y * w + paso_s.x] < 0:
				break
			visto[paso_s] = true
			if _tipo(paso_s) == SUELO and not letras.has(paso_s) and (paso_s == entra or not _ocupada.has(paso_s)):
				letras[paso_s] = "R"
				losas.append(paso_s)
			var mejor: Vector2i = paso_s
			for d in DIRS:
				var v: Vector2i = paso_s + d
				if _dentro(v) and not visto.has(v) and dist[v.y * w + v.x] >= 0 and dist[v.y * w + v.x] < dist[mejor.y * w + mejor.x]:
					mejor = v
			if mejor == paso_s:
				break
			paso_s = mejor
		if acceso == "sendero":
			for q in celdas:
				if not letras.has(q):
					letras[q] = "R"
		if not _letras_extra.contains("R"):
			_letras_extra += "R"
	_indice_hecho[_indice_hecho.size() - 1] = anadidos_hechos.size()
	anadidos_hechos.append({"que": "salida", "tipo": destino, "c": ancla, "modo": modo, "ancho": ancho, "marca": marca, "llegada": llegada, "acceso": acceso,
		"celdas": celdas, "entrada": entra, "losas": losas, "premio": "%s;%d;%s;%s;%s" % [modo, ancho, "si" if marca else "no", llegada, acceso]})


## Dónde está ahora lo que nombra un extremo (`a<n>` o `x,y`), y cómo se nombra tras recolocar los añadidos. [casilla, nombre]; casilla (-1, -1) si ya no existe.
func _extremo(e: String) -> Array:
	if e.begins_with("a") and e.substr(1).is_valid_int():
		var i: int = e.substr(1).to_int()
		if i < 0 or i >= _indice_hecho.size() or int(_indice_hecho[i]) < 0:
			return [Vector2i(-1, -1), e]
		return [anadidos_hechos[int(_indice_hecho[i])]["c"], "a%d" % int(_indice_hecho[i])]
	var xy: PackedStringArray = e.split(",")
	if xy.size() != 2 or not xy[0].is_valid_int() or not xy[1].is_valid_int():
		return [Vector2i(-1, -1), e]
	var origen: Vector2i = Vector2i(xy[0].to_int(), xy[1].to_int())
	return [movidos_hechos.get(origen, origen), e]


## El objeto de uno de esos tipos que hay en la casilla ({} si ninguno).
func _objeto_en(c: Vector2i, tipos: Array) -> Dictionary:
	for o in objetos:
		if (o["c"] as Vector2i) == c and tipos.has(String(o["tipo"])):
			return o
	return {}


## Cofres que aparecen cuando caen sus enemigos. Usa lo que el juego ya tiene: un VIGÍA que vigila a los enemigos que nacen en unas
## casillas y pone una flag cuando han caído todos, y `aparece_si=flag.…` en el cofre (lo mismo que el generador hace con el cofre de la
## llave). Va al final, con todo movido y añadido. Un extremo que ya no existe se descarta con aviso; el cofre de la llave no se enlaza
## (ya aparece al limpiar su sala).
func _aplicar_apariciones(nv: String) -> void:
	var n: int = 0
	for ap_v in _apariciones_pedidas:
		var ap: Dictionary = ap_v
		var ec: Array = _extremo(String(ap.get("cofre", "")))
		var cofre: Dictionary = _objeto_en(ec[0], COFRES_ENLAZABLES) if (ec[0] as Vector2i).x >= 0 else {}
		if cofre.is_empty():
			avisos.append("Un cofre que aparecía al caer enemigos ya no está en el mapa: ese enlace se descarta.")
			continue
		var celdas: Array = []
		var nombres: Array = []
		for en in ap.get("enemigos", []):
			var ee: Array = _extremo(String(en))
			if (ee[0] as Vector2i).x >= 0 and not _objeto_en(ee[0], TIPOS_ENEMIGO).is_empty() and not celdas.has(ee[0]):
				celdas.append(ee[0])
				nombres.append(ee[1])
			else:
				avisos.append("Un enemigo enlazado al cofre de (%d, %d) ya no está en el mapa: se quita de ese enlace." % [(ec[0] as Vector2i).x, (ec[0] as Vector2i).y])
		if celdas.is_empty():
			avisos.append("El cofre de (%d, %d) se ha quedado sin enemigos enlazados: vuelve a aparecer desde el principio." % [(ec[0] as Vector2i).x, (ec[0] as Vector2i).y])
			continue
		# La línea del cofre: se le añade la condición de aparecer.
		var cc: Vector2i = ec[0]
		var puesta: bool = false
		var cid: String = ""
		for i in range(lineas.size()):
			var t: PackedStringArray = lineas[i].substr(1).strip_edges().split(" ", false)
			if t.size() >= 5 and t[0] == "pieza" and t[2] == "cofre" and t[3].to_int() == cc.x and t[4].to_int() == cc.y and not lineas[i].contains(" aparece_si="):
				cid = t[1]
				lineas[i] = lineas[i] + " aparece_si=flag.%s.%s.aparece" % [nv, cid]
				puesta = true
				break
		if not puesta:
			avisos.append("El cofre de (%d, %d) ya tiene su propia condición para aparecer: no se le añade otra." % [cc.x, cc.y])
			continue
		n += 1
		var txt: PackedStringArray = PackedStringArray()
		for c in celdas:
			txt.append("%d,%d" % [int(c.x), int(c.y)])
		lineas.append("; pieza vigia_ap%d vigia %d %d de=%s flag=%s.%s.aparece" % [n, int(celdas[0].x), int(celdas[0].y), "+".join(txt), nv, cid])
		apariciones_hechas.append({"cofre": ec[1], "enemigos": nombres, "c": cc, "de": celdas})
		for c in celdas:
			enlaces.append({"de": c, "a": cc, "de_id": "", "a_id": cid, "fijo": true, "aparece": true})


# =====================================================================================================================
#  Elementos movidos a mano
# =====================================================================================================================

## Lleva cada elemento movido a mano a su sitio nuevo (18/11, Pablo: «que pueda seleccionar un elemento y moverlo de lugar; la
## autorresolución debe seguir funcionando para eliminar errores»). Va al final, con todo ya colocado: no cambia nada de lo que el
## generador decide, solo traslada. Y NO se fía del sitio pedido: prueba primero ese y luego los más cercanos, y se queda con el primero
## en el que el mapa sigue siendo jugable. Si no hay ninguno, el elemento se queda donde estaba y lo dice.
##   · La casilla tiene que ser suelo libre (ni pared, ni agua, ni otra cosa encima).
##   · Lo que bloquea (cofre, jarrón, brasero) no puede partir el mapa ni tapar algo que hay que tocar.
##   · El cofre del tesoro, el de la llave y el inicio no salen de su sala (su papel es de esa sala), y un enemigo no sale de una sala
##     con vigía (el vigía cuenta los de dentro: fuera, la sala quedaría sin nadie a quien vencer).
##   · Después de mover, el mapa entero se tiene que seguir pudiendo completar (`_resoluble`) y la tierra, seguir unida.
func _aplicar_movidos() -> void:
	var origenes: Array = _movidos_pedidos.keys()
	origenes.sort()
	for de in origenes:
		var pedido: Vector2i = _movidos_pedidos[de]
		var movidos_aqui: Array = objetos.filter(func(o: Dictionary) -> bool:
			return (o["c"] as Vector2i) == (de as Vector2i) and MOVIBLES.has(String(o["tipo"])) and not String(o["id"]).begins_with("cat"))
		if movidos_aqui.is_empty():
			avisos.append("En (%d, %d) ya no hay nada que se pueda mover (el mapa ha cambiado): ese movimiento se descarta." % [(de as Vector2i).x, (de as Vector2i).y])
			continue
		var tipo: String = String(movidos_aqui[0]["tipo"])
		var bloquea: bool = _bloqueos.has(de)
		# ¿De qué sala no puede salir?
		var sala_de: Dictionary = {}
		for s in _vivas():
			if (s["rect"] as Rect2i).has_point(de):
				sala_de = s
		var atado: bool = not sala_de.is_empty() and (tipo == "cofre_tesoro" or tipo == "cofre_llave" or tipo == "inicio"
			or ((tipo == "guerrero" or tipo == "arquero") and sala_de.has("vigia")))
		# Candidatos: el sitio pedido y, si no vale, los de alrededor, de cerca a lejos.
		# Lo que no puede salir de su sala se prueba en TODA su sala (soltarlo lejos lo lleva al borde más cercano de la sala).
		var candidatos: Array = []
		var zona: Rect2i = (sala_de["rect"] as Rect2i) if atado else Rect2i(pedido - Vector2i(6, 6), Vector2i(13, 13))
		for y in range(zona.position.y, zona.end.y):
			for x in range(zona.position.x, zona.end.x):
				var c: Vector2i = Vector2i(x, y)
				if c != (de as Vector2i) and _dentro(c) and _tipo(c) == SUELO and not _ocupada.has(c) and not letras.has(c):
					candidatos.append(c)
		candidatos.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da: int = (a - pedido).length_squared()
			var db: int = (b - pedido).length_squared()
			return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
		var puesto: Vector2i = Vector2i(-1, -1)
		for c in candidatos.slice(0, 40):
			var foto: Array = [lineas.duplicate(), objetos.duplicate(true), _ocupada.duplicate(), _bloqueos.duplicate(), letras.duplicate(), inicio, _llave_barrera.duplicate(true)]
			_ocupada.erase(de)
			_bloqueos.erase(de)
			var vale: bool = _puede_bloquear(c) if bloquea else true
			if vale:
				_trasladar(de, c, bloquea)
				vale = (_componentes(true, _bloqueos)[1] as Array).size() <= 1 and _resoluble()
			if vale:
				puesto = c
				break
			lineas = foto[0]
			objetos = foto[1]
			_ocupada = foto[2]
			_bloqueos = foto[3]
			letras = foto[4]
			inicio = foto[5]
			_llave_barrera = foto[6]
		if puesto.x < 0:
			avisos.append("No se ha podido mover lo de (%d, %d) cerca de (%d, %d): cortaría el paso, dejaría el mapa sin solución o no hay sitio%s. Se queda donde estaba." % [
				(de as Vector2i).x, (de as Vector2i).y, pedido.x, pedido.y, " dentro de su sala" if atado else ""])
			continue
		movidos_hechos[de] = puesto
		if puesto != pedido:
			avisos.append("Lo que movías a (%d, %d) ha quedado en (%d, %d): era el sitio válido más cercano%s." % [pedido.x, pedido.y, puesto.x, puesto.y,
				" (no puede salir de su sala)" if atado else ""])


## Traslada de `de` a `a` todo lo movible que hay en la casilla: el dibujo, la letra del plano, las líneas `; pieza` y lo que el generador
## recuerda de esa casilla (ocupada, bloqueo, inicio, cofre de la llave).
func _trasladar(de: Vector2i, a: Vector2i, bloquea: bool) -> void:
	for o in objetos:
		if (o["c"] as Vector2i) == de and MOVIBLES.has(String(o["tipo"])) and not String(o["id"]).begins_with("cat"):
			o["c"] = a
	if letras.has(de):
		letras[a] = letras[de]
		letras.erase(de)
	for i in range(lineas.size()):
		var t: PackedStringArray = lineas[i].substr(1).strip_edges().split(" ", false)
		if t.size() >= 5 and t[0] == "pieza" and ["jarron", "cofre", "salida", "entrada"].has(t[2]) and t[3].to_int() == de.x and t[4].to_int() == de.y and not t[1].begins_with("cat"):
			t[3] = str(a.x)
			t[4] = str(a.y)
			lineas[i] = "; " + " ".join(t)
	_ocupada.erase(de)
	_bloqueos.erase(de)
	_ocupar(a, bloquea)
	if inicio == de:
		inicio = a
	if not _llave_barrera.is_empty():
		var ac: Array = _llave_barrera["act_celdas"]
		for i in range(ac.size()):
			if (ac[i] as Vector2i) == de:
				ac[i] = a


## Con qué suelo se pinta lo que se pisa (17/11). El generador solo escribía suelo `.`, y las juntas del juego salen ENTRE suelos distintos:
## sin esto un mapa generado no tiene ninguna que enseñar. Lo que queda fuera de las salas (pasillos, umbrales) es TIERRA pisada (`g`) y la
## sala del tesoro va enlosada (`R`). En estilo «cueva» no se enlosa: allí `R` es el basalto de la lava. Va lo último y solo toca casillas de
## suelo sin letra propia (un goblin, un brasero o la S mandan sobre el suelo de su casilla).
func _pintar_terreno() -> void:
	if not bool(p["terreno"]):
		return
	if String(p["algoritmo"]) == "bosque":
		# El bosque trae su propio suelo: camino de tierra, claro, hierba corta, hierba alta y vados de piedra. Solo donde sigue habiendo
		# suelo y no hay ya otra letra (inicio, goblins, braseros…); lo que se retocó a mano a pared o agua se queda como está.
		# Tampoco en las salas con un puzle del catálogo (de sala o de barrera): sus pistas tienen que quedar de suelo liso.
		var con_puzle: Array = []
		for s in _vivas():
			if String(s["rol"]) == "puzle" or s.has("activador"):
				con_puzle.append(s["rect"])
		for c in _suelo_bosque:
			var en_puzle: bool = false
			for rp in con_puzle:
				en_puzle = en_puzle or (rp as Rect2i).has_point(c)
			if en_puzle:
				continue
			var l: String = String(_suelo_bosque[c])
			if _tipo(c) != SUELO or letras.has(c) or l == ".":
				continue
			letras[c] = l
			if not _letras_extra.contains(l):
				_letras_extra += l
		return
	var en_sala: Dictionary = {}
	for s in _vivas():
		var r: Rect2i = s["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				en_sala[Vector2i(x, y)] = String(s["rol"])
	var losas: bool = String(p["estilo"]) != "cueva"
	for y in range(h):
		for x in range(w):
			var c: Vector2i = Vector2i(x, y)
			if g[y * w + x] != SUELO or letras.has(c):
				continue
			var ch: String = ""
			if not en_sala.has(c):
				ch = "g"
			elif losas and String(en_sala[c]) == "tesoro":
				ch = "R"
			if ch != "":
				letras[c] = ch
				if not _letras_extra.contains(ch):
					_letras_extra += ch


# =====================================================================================================================
#  Barreras: puerta o puente + activador, y el vínculo entre los dos
# =====================================================================================================================

## Dónde puede ir una barrera. Con puertas (salas, pagina): cada puerta abierta. Sin ellas (cueva): cada estrechamiento de una o dos casillas
## entre dos paredes. Que de verdad corte el mapa lo comprueba `_intentar_barrera`.
func _pasos_candidatos() -> Array:
	var res: Array = []
	for pu in puertas:
		if String(pu["tipo"]) == "paso" and not _ocupada.has(pu["c"]):
			res.append({"celdas": [pu["c"]], "puerta": pu})
	if res.is_empty():
		for y in range(1, h - 1):
			var x: int = 1
			while x < w - 1:
				if g[y * w + x] != SUELO:
					x += 1
					continue
				var x0: int = x
				while g[y * w + x] == SUELO:
					x += 1
				if x - x0 <= 2 and g[y * w + x0 - 1] == MURO and g[y * w + x] == MURO:
					var tramo: Array = []
					for xx in range(x0, x):
						tramo.append(Vector2i(xx, y))
					res.append({"celdas": tramo, "puerta": null})
		for x in range(1, w - 1):
			var y: int = 1
			while y < h - 1:
				if g[y * w + x] != SUELO:
					y += 1
					continue
				var y0: int = y
				while g[y * w + x] == SUELO:
					y += 1
				if y - y0 <= 2 and g[(y0 - 1) * w + x] == MURO and g[y * w + x] == MURO:
					var tramo2: Array = []
					for yy in range(y0, y):
						tramo2.append(Vector2i(x, yy))
					res.append({"celdas": tramo2, "puerta": null})
	_barajar(res)
	res = res.slice(0, 22)
	# Salas de 2 a 4 puertas: se puede cerrar una y tapiar las demás (la sala entera queda detrás de la barrera).
	var de_sala: Array = []
	for s in _vivas():
		var ps: Array = _puertas_de(int(s["id"]))
		var todas_paso: bool = String(s["rol"]) == "" and ps.size() >= 2 and ps.size() <= 4
		for pu in ps:
			todas_paso = todas_paso and String(pu["tipo"]) == "paso" and not _ocupada.has(pu["c"])
		if todas_paso:
			var k: int = _azar(0, ps.size() - 1)
			var otras: Array = ps.duplicate()
			otras.remove_at(k)
			de_sala.append({"celdas": [ps[k]["c"]], "puerta": ps[k], "tapiar": otras})
	_barajar(de_sala)
	res.append_array(de_sala.slice(0, 12))
	return res


## Con `tapiar` (una sala de varias puertas): primero se tapian las otras puertas, si el resto del mapa sigue unido; así la que queda es paso obligado.
func _intentar_barrera(paso: Dictionary, n: int, vivas: Array, cueva: bool) -> bool:
	var g0: PackedByteArray = g.duplicate()
	var tap: Array = paso.get("tapiar", [])
	for pu in tap:
		g[int(pu["c"].y) * w + int(pu["c"].x)] = MURO
	if not tap.is_empty() and (_componentes()[1] as Array).size() > 1:
		g = g0
		return false
	if _intentar_barrera_b(paso, n, vivas, cueva):
		for pu in tap:
			puertas.erase(pu)
		return true
	g = g0
	return false


func _intentar_barrera_b(paso: Dictionary, n: int, vivas: Array, cueva: bool) -> bool:
	var celdas: Array = paso["celdas"]
	var solo_llave: Dictionary = {}
	if not _llave_barrera.is_empty():
		for c in _llave_barrera["celdas"]:
			solo_llave[c] = true
	var bloq: Dictionary = solo_llave.duplicate()
	for c in celdas:
		if _ocupada.has(c) or (c as Vector2i).distance_squared_to(inicio) < 9:
			return false
		for b in _barreras:                          # ni pegada a otra barrera: dos puentes juntos se leen como uno
			for cb0 in b["celdas"]:
				if (c as Vector2i).distance_squared_to(cb0) <= 8:
					return false
		for cp in precipicio:                        # 24/11: ni junto al precipicio del paso de tierra (su agua dejaría el puente sin orilla donde llegar)
			if (c as Vector2i).distance_squared_to(cp) <= 16:
				return false
		bloq[c] = true
	# ¿Corta de verdad? Tiene que dejar bastante mapa a cada lado.
	var base: PackedInt32Array = _distancias(inicio, solo_llave)
	var antes: PackedInt32Array = _distancias(inicio, bloq)
	var n_antes: int = 0
	var n_despues: int = 0
	for i in range(w * h):
		if antes[i] >= 0:
			n_antes += 1
		elif base[i] >= 0 and not bloq.has(Vector2i(i % w, i / w)):
			n_despues += 1
	if n_antes < 12 or n_despues < 12:
		return false
	var puente: bool = paso["puerta"] == null or (bool(p["b_puente"]) and _pct(50.0))
	if paso["puerta"] == null and not bool(p["b_puente"]):
		return false
	# El activador: en una sala a la que se llega sin cruzar esta barrera, cuanto más lejos del inicio mejor.
	var salas_antes: Array = []
	for s in vivas:
		var cs: Vector2i = _centro_libre(s)
		if cs.x >= 0 and antes[cs.y * w + cs.x] >= 0 and not s.has("activador"):
			s["_d"] = antes[cs.y * w + cs.x]
			salas_antes.append(s)
	salas_antes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["_d"]) > int(b["_d"]) or (int(a["_d"]) == int(b["_d"]) and int(a["id"]) < int(b["id"])))
	# Las plantillas del catálogo que valen de activador (`; tipo salida` + `; barrera si`), según lo que se permita en el panel:
	# «braseros» = las que acaban en un contador (señal `todos`); «placa» = las que acaban en una placa (señal `pulsado`).
	var cat: Dictionary = Catalogo.todos()
	var plantillas: Array = []
	var ids: Array = cat.keys()
	ids.sort()
	for cid in ids:
		var e: Dictionary = cat[cid]
		if String(e["tipo"]) != "salida" or not bool(e["barrera"]) or not String(e["activa"]).contains("."):
			continue
		var senal: String = String(e["activa"]).split(".")[1]
		if (senal == "todos" and not bool(p["b_braseros"])) or (senal == "pulsado" and not bool(p["b_placa"])):
			continue
		plantillas.append(cid)
	_barajar(plantillas)
	var bid: String = ("puente_%d" if puente else "puerta_%d") % n
	var c0: Vector2i = celdas[0]
	# Se estampa el activador, se pone la barrera y se comprueba que el mapa entero se sigue pudiendo completar; si no, se deshace
	# y se prueba con la siguiente sala o la siguiente plantilla.
	for cid in plantillas:                           # primero la plantilla (al azar) y luego dónde cabe: así salen repartidas
		for s in salas_antes.slice(0, 6):
			var foto: Array = [g.duplicate(), lineas.duplicate(), objetos.duplicate(), _ocupada.duplicate(), _bloqueos.duplicate(), letras.duplicate(),
				_puentes.duplicate(), _activadores.duplicate(), _barreras.duplicate(), _letras_extra, _n_cat, s["rect"]]
			if _poner_puzle(s, String(cid), _nv, true) != "":
				continue
			var aid: String = _ultimo_act
			var bien: bool = aid != ""
			for c in celdas:                             # la plantilla no puede haber tocado el paso que se va a cerrar
				bien = bien and _tipo(c) == SUELO and not _ocupada.has(c)
			if bien:
				if puente:
					var txt: PackedStringArray = PackedStringArray()
					for c in celdas:
						g[int(c.y) * w + int(c.x)] = AGUA
						_puentes[c] = true
						txt.append("%d,%d" % [int(c.x), int(c.y)])
					lineas.append("; pieza %s puente %d %d celdas=%s" % [bid, c0.x, c0.y, "+".join(txt)])
				else:
					lineas.append("; pieza %s puerta %d %d" % [bid, c0.x, c0.y])
				for c in celdas:
					_ocupar(c)
					_objeto(c, "puente" if puente else "puerta", bid)
				_barreras.append({"id": bid, "tipo": "puente" if puente else "puerta", "celdas": celdas, "pos": c0, "act": aid})
				if _resoluble():
					if paso["puerta"] != null:
						paso["puerta"]["tipo"] = "barrera"
					return true
			g = foto[0]
			lineas = foto[1]
			objetos = foto[2]
			_ocupada = foto[3]
			_bloqueos = foto[4]
			letras = foto[5]
			_puentes = foto[6]
			_activadores = foto[7]
			_barreras = foto[8]
			_letras_extra = foto[9]
			_n_cat = foto[10]
			s["rect"] = foto[11]
			s.erase("activador")
	return false


## ¿Se llega a todas estas casillas? Una que bloquea (brasero, bloque, cofre) vale si se llega a una de sus vecinas.
func _alcanza(alc: PackedInt32Array, celdas: Array) -> bool:
	for c in celdas:
		var si: bool = alc[int(c.y) * w + int(c.x)] >= 0
		for d in DIRS:
			var v: Vector2i = (c as Vector2i) + d
			si = si or (_dentro(v) and alc[v.y * w + v.x] >= 0)
		if not si:
			return false
	return true


## Juega el mapa en abstracto: con todo cerrado, abre cada barrera cuyo activador se alcanza y repite. ¿Acaban todas abiertas?
func _resoluble() -> bool:
	var abiertas: Dictionary = {}
	var total: int = _barreras.size() + (0 if _llave_barrera.is_empty() else 1)
	for _v in range(total + 1):
		var bloq: Dictionary = {}
		for b in _barreras:
			if not abiertas.has(b["id"]):
				for c in b["celdas"]:
					bloq[c] = true
		if not _llave_barrera.is_empty() and not abiertas.has("_llave"):
			for c in _llave_barrera["celdas"]:
				bloq[c] = true
		var alc: PackedInt32Array = _distancias(inicio, bloq)
		var cambio: bool = false
		for b in _barreras:
			var a: String = String(b["act"])
			if not abiertas.has(b["id"]) and _activadores.has(a) and _alcanza(alc, _activadores[a]["celdas"]):
				abiertas[b["id"]] = true
				cambio = true
		if not _llave_barrera.is_empty() and not abiertas.has("_llave") and _alcanza(alc, _llave_barrera["act_celdas"]):
			abiertas["_llave"] = true
			cambio = true
		if not cambio:
			break
	return abiertas.size() == total


## Aplica los enlaces a mano, escribe las reglas (activador → flag → barrera, para que lo abierto siga abierto al volver de otro nivel)
## y deja en `enlaces` lo que la vista dibuja. Lo que no cuadra va a `errores`.
func _emitir_barreras(nv: String) -> void:
	for b in _barreras:
		if _enlaces_mano.has(b["id"]):
			var a: String = String(_enlaces_mano[b["id"]])
			if a == "" or _activadores.has(a):
				b["act"] = a
	for b in _barreras:
		var nombre: String = "El puente" if String(b["tipo"]) == "puente" else "La puerta"
		var pos: Vector2i = b["pos"]
		if String(b["act"]) == "":
			errores.append("%s «%s» de (%d, %d) no está enlazada a nada que la abra." % [nombre, String(b["id"]), pos.x, pos.y])
			enlaces.append({"de": Vector2i(-1, -1), "a": pos, "de_id": "", "a_id": b["id"], "fijo": false})
			continue
		var act: Dictionary = _activadores[String(b["act"])]
		var flag: String = "%s.%s.abierta" % [nv, String(b["id"])]
		lineas.append("; puzle resuelve_%s cuando=%s.%s hace=flag.poner(%s)" % [String(b["id"]), String(act["id"]), String(act["senal"]), flag])
		lineas.append("; puzle abre_%s cuando=flag.%s hace=%s.%s" % [String(b["id"]), flag, String(b["id"]), "tender" if String(b["tipo"]) == "puente" else "abrir"])
		enlaces.append({"de": act["pos"], "a": pos, "de_id": act["id"], "a_id": b["id"], "fijo": false})
	if not _llave_barrera.is_empty():
		enlaces.append({"de": _llave_barrera["act_celdas"][0], "a": _llave_barrera["celdas"][0], "de_id": "cofre_llave", "a_id": "puerta_tesoro", "fijo": true})
	if errores.is_empty() and not _resoluble():
		errores.append("Con estos enlaces el mapa no se puede completar: algún activador queda detrás de la barrera que abre.")


## Un sitio para algo que bloquea su casilla: lo más cerca posible del centro de la sala; mejor si la casilla de debajo no es pared
## (la pared del sur tapa a la cámara lo que tiene justo encima).
func _sitio_bloqueo(s: Dictionary, evitar_sur: bool) -> Vector2i:
	var r: Rect2i = s["rect"]
	var centro: Vector2 = Vector2(r.position) + Vector2(r.size - Vector2i.ONE) * 0.5
	var celdas: Array = _celdas_sala(s)
	celdas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: float = Vector2(a).distance_squared_to(centro)
		var db: float = Vector2(b).distance_squared_to(centro)
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	for pasada in range(2 if evitar_sur else 1):
		for c in celdas:
			if evitar_sur and pasada == 0 and _tipo(c + Vector2i(0, 1)) == MURO:
				continue
			if _puede_bloquear(c):
				return c
	return Vector2i(-1, -1)


## 20/11 · Las salas de cámara (CamaraSalas): la caja del suelo de cada sala viva, pistas incluidas (el estampado de un puzle
## ya agranda su `rect`). Con el algoritmo «cueva» no hay: sus «claros» no son salas cerradas y la cámara se confina solo al mapa.
## Avisa de las salas que obligan a acercar mucho la cámara (en 16:9, por debajo de ZOOM_AVISO).
const ZOOM_AVISO: float = 4.0
const CamaraSalas = preload("res://presentacion/camara_salas.gd")
const LADO_CASILLA: float = 2.3      ## S de la maqueta

func _salas_camara() -> Array:
	var r: Array = []
	if ["cueva", "bosque"].has(String(p.get("algoritmo", "salas"))) or not bool(p.get("camara_sala", true)):
		return r                       # el bosque es espacio abierto: la cámara solo se frena en el borde del mapa
	for s in _vivas():
		var caja: Rect2i = Rect2i()
		var hay: bool = false
		var rs: Rect2i = (s["rect"] as Rect2i).intersection(Rect2i(0, 0, w, h))
		for i in range(rs.size.x * rs.size.y):
			var c: Vector2i = rs.position + Vector2i(i % rs.size.x, i / rs.size.x)
			if _tipo(c) == MURO:
				continue      # el agua y lo que se cruza también es de la sala
			caja = caja.expand(c) if hay else Rect2i(c, Vector2i.ZERO)
			hay = true
		if not hay:
			continue
		caja.size += Vector2i.ONE
		r.append(caja)
		var z: float = CamaraSalas.zoom_que_cabe_en(caja.size, LADO_CASILLA)
		if z < ZOOM_AVISO:
			var cuanto: String = "hasta %.1f (de serie 6)" % z if z >= CamaraSalas.ZOOM_MINIMO_SALA else "al máximo (%.1f) y aun así no cabe: se verá algo de fuera" % CamaraSalas.ZOOM_MINIMO_SALA
			avisos.append("Sala de %d×%d en %d,%d: la cámara tendrá que acercarse %s. Agrándala o júntala con otra." % [caja.size.x, caja.size.y, caja.position.x, caja.position.y, cuanto])
	return r


func _resultado() -> Dictionary:
	var filas: PackedStringArray = PackedStringArray()
	var hueco: Dictionary = {}
	for c in precipicio:
		hueco[c] = true
	if not hueco.is_empty() and not _letras_extra.contains(" "):
		_letras_extra += " "                       # el precipicio del paso de tierra: casillas sin suelo
	for y in range(h):
		var fila: String = ""
		for x in range(w):
			fila += " " if hueco.has(Vector2i(x, y)) else String(letras.get(Vector2i(x, y), LETRA[g[y * w + x]]))
		filas.append(fila)
	var n_enem: int = 0
	var n_cofres: int = 0
	var n_jarrones: int = 0
	for o in objetos:
		match String(o["tipo"]):
			"guerrero", "arquero", "limo", "golem", "chaman", "mouro", "elemental":
				n_enem += 1
			"cofre_tesoro", "cofre_llave", "cofre_comun", "cofre_epico", "cofre_legendario":
				n_cofres += 1
			"jarron":
				n_jarrones += 1
	var pisable: int = w * h - g.count(MURO)
	var cam: Array = _salas_camara()
	return {
		"salas_camara": cam,
		"parametros": p.duplicate(), "ancho": w, "alto": h, "filas": filas, "inicio": inicio,
		"salas": _vivas(), "puertas": puertas, "objetos": objetos, "lineas": lineas, "avisos": avisos,
		"arqueros": bool(p.get("_arqueros", false)), "retoques": _retoques,
		"errores": errores, "enlaces": enlaces, "enlaces_mano": _enlaces_mano, "activadores": _activadores.keys(), "barreras": _barreras.size(),
		"puzles": puzles_puestos, "puzles_mano": _puzles_mano, "cruzables": _puentes.keys(), "letras_extra": _letras_extra, "precipicio": precipicio,
		"movidos": movidos_hechos, "movidos_pedidos": _movidos_pedidos, "anadidos": anadidos_hechos, "apariciones": apariciones_hechas,
		"stats": {"salas": _vivas().size(), "puertas": puertas.size(), "enemigos": n_enem, "cofres": n_cofres, "jarrones": n_jarrones,
			"suelo": pisable, "agua": g.count(AGUA), "ocupacion": pisable / float(maxi(1, w * h))},
	}


# =====================================================================================================================
#  Catálogo de puzles: una plantilla estampada en una sala (catalogo_puzles.gd)
# =====================================================================================================================

## Los puzles pedidos a mano (sala → puzle) y después los automáticos (`puzles`), en salas que aún no tienen papel.
func _colocar_catalogo(vivas: Array, nv: String) -> void:
	var cat: Dictionary = Catalogo.todos()
	var a_mano: Array = _puzles_mano.keys()
	a_mano.sort()
	for sid in a_mano:
		var cid: String = String(_puzles_mano[sid])
		var s: Dictionary = {}
		for v in vivas:
			if int(v["id"]) == int(sid):
				s = v
		if s.is_empty():
			avisos.append("El puzle «%s» estaba puesto en la sala %d, que ya no existe." % [cid, int(sid)])
		elif String(s["rol"]) != "":
			avisos.append("El puzle «%s» no se pone en la sala %d: es la sala de %s." % [cid, int(sid), String(s["rol"])])
		else:
			var motivo: String = _poner_puzle(s, cid, nv)
			if motivo != "":
				avisos.append("El puzle «%s» no se ha podido poner en la sala %d: %s" % [cid, int(sid), motivo])
	var quiero: int = clampi(int(p["puzles"]), 0, 12)
	if quiero <= 0 or cat.is_empty():
		return
	var ids: Array = cat.keys()
	ids.sort()
	_barajar(ids)
	var libres: Array = vivas.filter(func(s: Dictionary) -> bool: return String(s["rol"]) == "")
	_barajar(libres)
	var puestos: int = 0
	var turno: int = 0
	for s in libres:
		if puestos >= quiero:
			break
		for k in range(ids.size()):
			if _poner_puzle(s, String(ids[(turno + k) % ids.size()]), nv) == "":
				puestos += 1
				turno += k + 1
				break
	if puestos < quiero:
		avisos.append("Solo caben %d puzles del catálogo de los %d pedidos." % [puestos, quiero])


## Pone el puzle `cid` en la sala `s`. Devuelve "" si se pudo; si no, por qué.
func _poner_puzle(s: Dictionary, cid: String, nv: String, de_barrera: bool = false) -> String:
	var cat: Dictionary = Catalogo.todos()
	if not cat.has(cid):
		return "no está en el catálogo."
	var e: Dictionary = cat[cid]
	var r: Rect2i = s["rect"]
	for c in precipicio:                               # bosque: una plantilla podría tapar el precipicio del paso de tierra
		if r.grow(2).has_point(c):
			return "la sala toca el paso de tierra."
	var filas: Array = (e["filas"] as Array).duplicate()
	var tw: int = int(e["ancho"])
	var th: int = int(e["alto"])
	var sitios: Array = []
	if String(e["estira"]) == "x":
		# Una franja: cada fila se repite hasta el ancho de la sala y se prueba en cada altura, la del centro primero.
		tw = r.size.x
		for i in range(filas.size()):
			filas[i] = String(filas[i]).substr(0, 1).repeat(tw)
		for y in range(r.position.y, r.end.y - th + 1):
			sitios.append(Vector2i(r.position.x, y))
	else:
		for y in range(r.position.y, r.end.y - th + 1):
			for x in range(r.position.x, r.end.x - tw + 1):
				sitios.append(Vector2i(x, y))
	var centro: Vector2 = Vector2(r.position) + Vector2(r.size - Vector2i(tw, th)) * 0.5
	sitios.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: float = Vector2(a).distance_squared_to(centro)
		var db: float = Vector2(b).distance_squared_to(centro)
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	if sitios.is_empty():
		# No cabe dentro: AUTOAJUSTE DEL SUELO. Se centra sobre la sala y se excava en la roca de alrededor lo que falte.
		# En el eje en que no cabe, la plantilla cubre la sala y puede crecer hacia un lado, hacia el otro o a los dos; se prueba todo,
		# lo mas centrado primero.
		var xs: Array = range(r.end.x - tw, r.position.x + 1) if tw > r.size.x else range(r.position.x, r.end.x - tw + 1)
		var ys: Array = range(r.end.y - th, r.position.y + 1) if th > r.size.y else range(r.position.y, r.end.y - th + 1)
		for y in ys:
			for x in xs:
				sitios.append(Vector2i(x, y))
		sitios.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da: float = Vector2(a).distance_squared_to(centro)
			var db: float = Vector2(b).distance_squared_to(centro)
			return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	for sitio in sitios.slice(0, 24):
		if _estampar(s, e, filas, tw, th, sitio, nv, de_barrera):
			return ""
	return "no cabe (la plantilla mide %d × %d y la sala %d × %d; al agrandarla tropieza con otra sala o con el borde, o corta el paso)." % [tw, th, r.size.x, r.size.y]


## `de_barrera`: la plantilla es el activador de una barrera automática. La sala conserva su papel (no pasa a ser «sala de puzle») y el
## activador que deja queda en `_ultimo_act`.
func _estampar(s: Dictionary, e: Dictionary, filas: Array, tw: int, th: int, sitio: Vector2i, nv: String, de_barrera: bool = false) -> bool:
	_ultimo_act = ""
	var r: Rect2i = s["rect"]
	var zona: Rect2i = Rect2i(sitio, Vector2i(tw, th))
	if not Rect2i(1, 1, w - 2, h - 2).encloses(zona):
		return false
	if not r.encloses(zona):
		# Lo que se sale de la sala tiene que ser roca, y quedar con una pared de roca alrededor (no se abre a otra sala ni a un pasillo).
		for y in range(zona.position.y - 1, zona.end.y + 1):
			for x in range(zona.position.x - 1, zona.end.x + 1):
				var c: Vector2i = Vector2i(x, y)
				if not r.grow(1).has_point(c) and _tipo(c) != MURO:
					return false
	for y in range(th):
		for x in range(tw):
			if String(filas[y])[x] != " " and (_ocupada.has(sitio + Vector2i(x, y)) or _retoques.has(sitio + Vector2i(x, y))):
				return false                             # ni encima de otra cosa ni de un retoque pintado a mano
	var foto: Array = [g.duplicate(), lineas.duplicate(), objetos.duplicate(), _ocupada.duplicate(), _bloqueos.duplicate(), letras.duplicate(),
		_puentes.duplicate(), _activadores.duplicate(), _letras_extra]
	_n_cat += 1
	var inst: String = "cat%d" % _n_cat
	var paso: bool = String(e["tipo"]) == "paso"
	var con_paredes: bool = "".join(filas).contains("#")
	for y in range(th):
		for x in range(tw):
			var ch: String = String(filas[y])[x]
			var c: Vector2i = sitio + Vector2i(x, y)
			match ch:
				" ":
					pass
				"#":
					g[c.y * w + c.x] = MURO
				".":
					g[c.y * w + c.x] = SUELO
					if con_paredes:
						_ocupar(c)                       # el suelo de una pista es del puzle: ni enemigos ni jarrones dentro
				"~":
					g[c.y * w + c.x] = AGUA
					_ocupar(c)
					if paso:
						_puentes[c] = true           # se cruza al resolver el puzle (helada): cuenta como paso
				_:
					g[c.y * w + c.x] = SUELO
					letras[c] = ch
					_ocupar(c, ch == "T")                # un brasero bloquea su casilla
					objetos.append({"c": c, "tipo": "brasero" if ch == "T" else "catalogo", "id": inst, "txt": ch})
					if not _letras_extra.contains(ch) and not "#.~SWAT".contains(ch):
						_letras_extra += ch
	var mal: bool = false
	var todas: Array = (e["lineas"] as Array).duplicate()
	if String(p["estilo"]) == "cueva":
		todas.append_array(e["lineas_cueva"])
	var de_contador: Dictionary = {}                 # id del contador → las casillas de sus braseros (a las que hay que llegar)
	for l in todas:
		var l2: String = _linea_de_catalogo(String(l), e, sitio, inst, nv, tw, th)
		var t: PackedStringArray = l2.substr(1).strip_edges().split(" ", false)
		if t.size() >= 5 and t[0] == "pieza":
			var cp: Vector2i = Vector2i(t[3].to_int(), t[4].to_int())
			if not _dentro(cp) or _tipo(cp) == MURO:
				mal = true
			_ocupar(cp)
			# Un brasero con línea propia ya está dibujado por su letra T. Lo demás, con el icono de su tipo si lo tiene.
			if t[2] != "brasero":
				var icono: String = String({"bloque": "bloque", "pulsador": "placa", "contador": "contador"}.get(t[2], "catalogo"))
				objetos.append({"c": cp, "tipo": icono, "id": t[1], "txt": t[2].substr(0, 1).to_upper()})
			for k in range(5, t.size()):
				if t[2] == "contador" and t[k].begins_with("de="):
					var cs: Array = []
					for par in t[k].substr(3).split("+", false):
						var xy: PackedStringArray = par.split(",")
						if xy.size() == 2:
							cs.append(Vector2i(xy[0].to_int(), xy[1].to_int()))
					de_contador[t[1]] = cs
		lineas.append(l2)
	if String(e["tipo"]) == "salida" and String(e["activa"]).contains("."):
		var act: PackedStringArray = String(e["activa"]).split(".")
		var aid: String = inst + "_" + act[0]
		for o in objetos:
			if String(o["id"]) == aid:
				_activadores[aid] = {"id": aid, "tipo": "catalogo", "celdas": de_contador.get(aid, [o["c"]]), "pos": o["c"], "senal": act[1]}
		mal = mal or not _activadores.has(aid)
	# Todo lo que se pisa sigue unido, la tierra también (contando lo cruzable) y el mapa se puede completar. Si no, se deshace.
	if mal or (_componentes()[1] as Array).size() > 1 or (_componentes(true, _bloqueos)[1] as Array).size() > 1 or not _resoluble():
		g = foto[0]
		lineas = foto[1]
		objetos = foto[2]
		_ocupada = foto[3]
		_bloqueos = foto[4]
		letras = foto[5]
		_puentes = foto[6]
		_activadores = foto[7]
		_letras_extra = foto[8]
		_n_cat -= 1
		return false
	if String(e["tipo"]) == "salida" and String(e["activa"]).contains("."):
		_ultimo_act = inst + "_" + String(e["activa"]).split(".")[0]
	s["activador"] = true
	s["rect"] = r.merge(zona)
	if not de_barrera:
		s["rol"] = "puzle"
		s["catalogo"] = String(e["id"])
		s["titulo"] = String(e["titulo"])
		puzles_puestos[int(s["id"])] = String(e["id"])
	return true


## Una línea `; pieza` / `; puzle` de la plantilla, llevada al mapa: comodines, casillas trasladadas e ids con el prefijo de la instancia.
func _linea_de_catalogo(l: String, e: Dictionary, sitio: Vector2i, inst: String, nv: String, tw: int, th: int) -> String:
	var t: String = l.substr(1).strip_edges().replace("$NIVEL", nv).replace("$ID", inst).replace("$X1", str(tw - 1)).replace("$Y1", str(th - 1))
	t = t.replace("$MODELO", "modelo=cueva" if String(p["estilo"]) == "cueva" else "")
	var partes: PackedStringArray = t.split(" ", false)
	var locales: Array = []
	for otra in (e["lineas"] as Array) + (e["lineas_cueva"] as Array):
		var po: PackedStringArray = String(otra).substr(1).strip_edges().split(" ", false)
		if po.size() >= 2:
			locales.append(po[1])
	var es_pieza: bool = partes[0] == "pieza" and partes.size() >= 5
	if es_pieza:
		partes[3] = str(partes[3].to_int() + sitio.x)
		partes[4] = str(partes[4].to_int() + sitio.y)
	var pares: RegEx = RegEx.create_from_string("(\\d+),(\\d+)")
	for i in range(5 if es_pieza else 2, partes.size()):
		var kv: PackedStringArray = partes[i].split("=", true, 1)
		if kv.size() != 2:
			continue
		var valor: String = kv[1]
		if ["celdas", "de", "sala", "en", "camino", "canal", "bloque"].has(kv[0]) or valor.contains("casilla("):
			var res: String = ""
			var desde: int = 0
			for m in pares.search_all(valor):
				res += valor.substr(desde, m.get_start() - desde) + "%d,%d" % [m.get_string(1).to_int() + sitio.x, m.get_string(2).to_int() + sitio.y]
				desde = m.get_end()
			valor = res + valor.substr(desde)
		for id in locales:
			var er: RegEx = RegEx.create_from_string("(?<![A-Za-z0-9_.])" + String(id) + "(?![A-Za-z0-9_])")
			valor = er.sub(valor, inst + "_" + String(id), true)
		partes[i] = kv[0] + "=" + valor
	partes[1] = inst + "_" + partes[1]
	return "; " + " ".join(partes)
