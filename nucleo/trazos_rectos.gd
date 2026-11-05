class_name TrazosRectos
extends RefCounted

## Reconocedor por TRAZOS RECTOS (5/11, Pablo): cada glifo y cada elemento se dibuja como una secuencia CORTA de tramos rectos en
## ocho direcciones, y lo que se lee es esa secuencia, no el parecido de la forma. Es la alternativa al $P (GestureRecognizer), que
## con muchas runas de líneas cortas las confundía y obligaba a grabar plantillas. Aquí no se graba nada: la «plantilla» es un
## texto de la tabla de abajo.
##
## CÓMO SE LEE UN TRAZO
##   1. Se remuestrea a pasos iguales (un treintavo del recorrido, con un mínimo en píxeles: cuanto más fino, menos pesa el paso que cruza una esquina).
##   2. Cada paso se cuantiza a una de ocho direcciones: R, UR, U, UL, L, DL, D, DR. OJO: en pantalla la y crece hacia ABAJO, así
##      que «U» es y NEGATIVA; todo lo de este archivo habla en direcciones de pantalla.
##   3. Los pasos iguales seguidos se funden en un tramo.
##   4. Se descartan los tramos más cortos que MIN_TRAMO (15 % del recorrido del trazo) (todos a la vez), y se vuelve a fundir.
##      Si lo descartado es más del MAX_DESCARTADO (35 %) del recorrido, el trazo es un garabato y queda ILEGIBLE (no coincide con nada).
##      Eso es lo que hace que una esquina redondeada (que mete un tramo diagonal pequeño) siga leyéndose como esquina.
##   Un gesto de varios trazos es la lista de las secuencias de cada trazo; en texto se separan con «|».
##
## CÓMO SE COMPARA
##   - Por FORMA, no por sentido de trazado: una plantilla vale también recorrida al revés (orden de tramos invertido y cada
##     dirección opuesta), y en un gesto de varios trazos el orden de los trazos no importa (ni el sentido de cada uno).
##   - TOLERANCIA: cada tramo puede desviarse hasta ±TOLERANCIA pasos (1 paso = 45°) de la plantilla. Se elige la plantilla con
##     menor desviación total. Si dos plantillas DISTINTAS empatan, o ninguna cae dentro de la tolerancia, se RECHAZA, y se
##     devuelve «se parece a» (la más cercana) para el aviso.
##   - Elementos y sellos son vocabularios SEPARADOS: un elemento solo compite con elementos y un sello con sellos, así que pueden
##     repetir formas entre sí (el X es el sello `pulso` y habría podido ser un elemento).
##
## NO SE GIRA POR SECTOR. Con el $P (Grimorio.ROTAR_POR_SECTOR) se probaba el trazo girado como si el sector fuera el de la
## derecha. Aquí NO: las direcciones se leen respecto a la PÁGINA, no respecto al sector donde cae el trazo. Un «<» es «DL,DR» en
## el sector de arriba, en el de la derecha y en el de abajo; si girase con el sector, dos glifos distintos serían el mismo trazo
## según dónde se dibujen. Sin giro, la runa se dibuja siempre como se ve en la chuleta.

## --- LA TABLA ---
## Es DATO: cambiar un trazo es cambiar un texto. Formato: tramos separados por «,» y trazos separados por «|».
## Direcciones: R derecha · UR arriba-derecha · U arriba · UL arriba-izquierda · L izquierda · DL abajo-izquierda · D abajo · DR abajo-derecha.
## REGLA (5/11, primer playtest de Pablo): EL TRAZO ES LA RUNA QUE SE VE (art/ui/glyphs/*.png). La primera tabla inventaba formas aparte
## (fuego era un Λ) y Pablo, con razón, dibujaba la runa del libro (ᚲ, «<»): el log lo leía «DL,DR» una y otra vez y lo rechazaba. Todas
## las runas de la lámina son ya tramos rectos, así que cada entrada es la runa tal cual: un palo es un trazo aparte («D», da igual el
## sentido) y las ramas, otro. Un gesto de varios trazos admite cualquier orden; hay GESTURE_PAUSE (0,75 s) entre trazo y trazo.
## Una figura CERRADA (el rombo de la barrera) vale empezada en cualquier esquina (ver `_cerrada`).

## Elementos (se dibujan sobre el NÚCLEO). Las claves son las de GestureLibrary.ELEMENTS.
const ELEMENTOS: Dictionary = {
	"fuego": "DL,DR",        # ᚲ  «<»
	"agua": "U,DR",          # ᛚ  palo y brazo que baja a la derecha (de abajo arriba y bajando)
	"tierra": "U,DR,UR,D",   # ᛗ  una M
	"rayo": "DR,UR,DR",      # ᛊ  el zigzag
	"hielo": "D|DR",         # ᚾ  palo y la diagonal que lo cruza
	"viento": "U,DR,D",      # ᚢ  la ∩ con el techo inclinado
}

## Sellos (se dibujan sobre un SECTOR). Las claves son las de GestureLibrary.SIGILS. `linea` no está: sigue siendo la raya sola
## (Grimorio._is_straight), que se resuelve antes de llegar aquí.
const SELLOS: Dictionary = {
	"flecha": "UL,D,UL",          # ᛇ  gancho arriba, palo, gancho abajo (de una vez)
	"retorno": "DL,DR",           # ᛃ  no tiene PNG todavía: «<» hasta que lo tenga
	"altura": "D|UR,DR",          # ᛏ  palo y el tejado Λ
	"rebote": "U,DR",             # la Λ de pata izquierda recta
	"barrera": "DL,DR,UR,UL",     # ◇  el rombo (cerrado: cualquier esquina vale)
	"repeticion": "D|UR|UR",      # ᚠ  palo y dos ramas que suben
	"pulso": "DR|DL",             # ᚷ  la X
	"raido": "U,DR,DL,DR",        # ᚱ  palo, el ojo y la pata (como una R)
	"permanencia": "D|DR,UR",     # ᛉ  palo y la V de arriba
	"perforar": "D|DR,DL",        # ᚦ  palo y el pico «>»
	"buscar": "D|DR|DR",          # ᚨ  palo y dos ramas que bajan
}

## OTRAS FORMAS que también valen para una entrada, además de la de la tabla (que es la que se enseña en la guía). Mismo formato.
## Solo para runas que se dibujan, con naturalidad, de dos maneras; cada una pasa el mismo control de choques que la tabla.
##   rayo (5/11, segundo playtest de Pablo): el log lo leía «DL,DR,DL» tres veces de tres: el zigzag VERTICAL de un relámpago (ϟ),
##   mientras que ᛊ en el libro está tumbada («DR,UR,DR»). Valen las dos.
const OTRAS_FORMAS_ELEMENTOS: Dictionary = {
	"rayo": ["DL,DR,DL"],
}
const OTRAS_FORMAS_SELLOS: Dictionary = {}


## Todas las formas de una entrada del vocabulario (la de la tabla primero), como textos.
static func formas(vocabulario: Dictionary, nombre: String) -> PackedStringArray:
	var res := PackedStringArray([String(vocabulario[nombre])])
	var otras: Dictionary = OTRAS_FORMAS_ELEMENTOS if vocabulario == ELEMENTOS else (OTRAS_FORMAS_SELLOS if vocabulario == SELLOS else {})
	for t in otras.get(nombre, []):
		res.append(String(t))
	return res

## --- UMBRALES ---
const NOMBRES_DIR: PackedStringArray = ["R", "UR", "U", "UL", "L", "DL", "D", "DR"]
const PASOS: int = 8
## Cuánto puede desviarse cada tramo de la plantilla, en pasos de 45°.
const TOLERANCIA: int = 1
## Tope del umbral de tramo corto: nunca más que esta fracción del tramo más largo del trazo (ver `secuencia`).
const MIN_TRAMO_DEL_MAYOR: float = 0.35
## Un tramo más corto que esta fracción del recorrido de SU trazo se descarta (esquinas redondeadas, temblor). Pablo pidió ~12 %; medido con\n## dibujos sintéticos (prueba_trazos_rectos.gd, AVISO) 0,12 deja pasar esquinas cortadas al 15 % como un tramo más y 0,15 las lee bien (0,18 ya\n## empieza a comerse tramos legítimos). A ajustar en el playtest.
const MIN_TRAMO: float = 0.15
## Si se descarta más de esta fracción del recorrido de un trazo, el trazo es un garabato (ILEGIBLE) y no se lee.
const MAX_DESCARTADO: float = 0.35
## Marca de un trazo ilegible en una secuencia (no es una dirección).
const ILEGIBLE: int = -1
## El paso del remuestreo es el recorrido entre este número, pero nunca menos de PASO_MIN_PX.
const PASOS_POR_TRAZO: float = 30.0
const PASO_MIN_PX: float = 4.0
## Un trazo con menos recorrido que esto no tiene dirección que leer.
const RECORRIDO_MIN_PX: float = 8.0
## Coste de «se parece a» cuando el número de tramos no coincide: por cada tramo de diferencia. Solo ordena el aviso.
const COSTE_TRAMO_SOBRANTE: int = 4
## Calidad que se resta por cada paso de desviación total (la calidad alimenta la potencia del glifo, como el margen del $P).
const CALIDAD_POR_PASO: float = 0.25
const CALIDAD_MIN: float = 0.25


## --- LECTURA DEL TRAZO ---

## Un trazo (Array de Vector2, y hacia abajo) -> los índices de dirección de sus tramos (0=R, 1=UR, 2=U… ver NOMBRES_DIR).
static func secuencia(trazo: Array) -> Array:
	var puntos: Array = []
	for p in trazo:
		if puntos.is_empty() or (puntos[puntos.size() - 1] as Vector2).distance_to(p) > 0.001:
			puntos.append(p)
	if puntos.size() < 2:
		return []
	var recorrido: float = 0.0
	for i in range(puntos.size() - 1):
		recorrido += (puntos[i] as Vector2).distance_to(puntos[i + 1])
	if recorrido < RECORRIDO_MIN_PX:
		return []

	var remuestreados: Array = _remuestrear(puntos, maxf(recorrido / PASOS_POR_TRAZO, PASO_MIN_PX))
	# Tramos como [dirección, longitud]; los pasos iguales seguidos se funden.
	var tramos: Array = []
	for i in range(remuestreados.size() - 1):
		var v: Vector2 = (remuestreados[i + 1] as Vector2) - (remuestreados[i] as Vector2)
		var l: float = v.length()
		if l < 0.001:
			continue
		tramos.append([direccion_de(v), l])
	tramos = _fundir(tramos)
	# Trazo cerrado empezado a mitad de un lado: el primer y el último tramo son el MISMO lado partido en dos; se juntan antes de quitar
	# los cortos (cada mitad sola podría quedarse por debajo de MIN_TRAMO y perderse).
	var cierre: float = (puntos[0] as Vector2).distance_to(puntos[puntos.size() - 1])
	if tramos.size() > 2 and int(tramos[0][0]) == int(tramos[tramos.size() - 1][0]) and cierre < MIN_TRAMO * recorrido:
		tramos[0][1] = float(tramos[0][1]) + float(tramos[tramos.size() - 1][1])
		tramos.remove_at(tramos.size() - 1)

	# Los tramos cortos se quitan de una vez (no uno a uno: quitar de uno en uno encadena, y un garabato de muchos tramos pequeños
	# acababa reducido a dos y aceptado), y los vecinos que quedan iguales se funden. Si todos son cortos se queda el más largo.
	var largo_max: int = 0
	for i in range(tramos.size()):
		if float(tramos[i][1]) > float(tramos[largo_max][1]):
			largo_max = i
	# 5/11: con runas de 4 tramos (ᛗ, ᚱ, el rombo) el 15 % del recorrido se comía el tramo más corto; el umbral tampoco pasa de una
	# fracción del tramo MÁS LARGO, que en una runa de dos tramos da lo mismo y en una de cuatro deja vivos los tramos legítimos.
	var umbral: float = minf(MIN_TRAMO * recorrido, MIN_TRAMO_DEL_MAYOR * float(tramos[largo_max][1]))
	var firmes: Array = []
	var descartado: float = 0.0
	if float(tramos[largo_max][1]) < umbral:
		firmes.append(tramos[largo_max])
	else:
		for t in tramos:
			if float(t[1]) >= umbral:
				firmes.append(t)
	for t in tramos:
		descartado += float(t[1])
	for t in firmes:
		descartado -= float(t[1])
	# Si lo descartado es una parte grande del trazo, no era un trazo con esquinas sino un garabato (espiral, sierra fina…): no se
	# reduce a lo poco que quede, se marca como ilegible y no coincide con nada.
	if descartado > MAX_DESCARTADO * recorrido:
		return [ILEGIBLE]
	tramos = _fundir(firmes)

	var res: Array = []
	for t in tramos:
		res.append(int(t[0]))
	return res


## Dirección de pantalla (0..7) de un vector. La y de pantalla crece hacia abajo, así que «arriba» es y negativa.
static func direccion_de(v: Vector2) -> int:
	return posmod(roundi(-atan2(v.y, v.x) / (TAU / float(PASOS))), PASOS)


## La dirección de un índice como vector de pantalla de longitud 1.
static func vector_de(dir: int) -> Vector2:
	var a: float = float(dir) * TAU / float(PASOS)
	return Vector2(cos(a), -sin(a))


## Un gesto (lista de trazos) -> lista de secuencias, una por trazo. Los trazos sin dirección (puntos sueltos) se ignoran.
static func secuencias(trazos: Array) -> Array:
	var res: Array = []
	for t in trazos:
		var s: Array = secuencia(t)
		if not s.is_empty():
			res.append(s)
	return res


## Como texto, con el formato de la tabla: «UR,DR|DL». Sirve para el registro (PlayLog) y para ver qué leyó el reconocedor.
static func texto_de(trazos: Array) -> String:
	return _a_texto(secuencias(trazos))


## --- COINCIDENCIA ---

## Reconoce un gesto contra un vocabulario (ELEMENTOS o SELLOS; cualquier Dictionary nombre -> texto de trazos).
## Devuelve {"name", "second_name", "accepted", "desviacion" (pasos totales del mejor), "margin" (diferencia de desviación con el
## segundo, en pasos; 0 = empate), "quality" (0..1), "secuencia" (texto de lo leído), "sin_trazo" (no se pudo leer ningún tramo)}.
## `name` es siempre el más cercano (aunque se rechace) para poder decir «se parece a …».
static func reconocer(trazos: Array, vocabulario: Dictionary) -> Dictionary:
	var leidas: Array = secuencias(trazos)
	var res: Dictionary = {"name": "", "second_name": "", "accepted": false, "desviacion": 999, "margin": 0.0,
		"quality": 0.0, "secuencia": _a_texto(leidas), "sin_trazo": leidas.is_empty()}
	if leidas.is_empty():
		return res

	# Para cada plantilla: [coste, dentro_de_tolerancia, nombre]. El coste ordena también las que no valen (para el aviso).
	var filas: Array = []
	for nombre in vocabulario:
		# Con varias formas, cuenta la mejor (dentro de tolerancia antes que fuera; luego la de menos coste).
		var d: Dictionary = {}
		for texto in formas(vocabulario, String(nombre)):
			var df: Dictionary = distancia(leidas, texto_a_gesto(texto))
			if d.is_empty() or (bool(df["dentro"]) and not bool(d["dentro"])) or (bool(df["dentro"]) == bool(d["dentro"]) and int(df["coste"]) < int(d["coste"])):
				d = df
		filas.append([int(d["coste"]), bool(d["dentro"]), String(nombre)])
	if filas.is_empty():
		return res
	# Primero las que están dentro de la tolerancia (aunque una de fuera sume menos), luego por desviación total.
	filas.sort_custom(func(a, b): return int(not a[1]) < int(not b[1]) or (a[1] == b[1] and a[0] < b[0]))

	var primera: Array = filas[0]
	res["name"] = primera[2]
	res["desviacion"] = primera[0]
	if filas.size() > 1:
		res["second_name"] = (filas[1] as Array)[2]
		res["margin"] = float(int((filas[1] as Array)[0]) - int(primera[0]))
	if not bool(primera[1]):
		return res
	# Empate con otra plantilla también válida: no se sabe cuál era.
	if filas.size() > 1 and bool((filas[1] as Array)[1]) and int((filas[1] as Array)[0]) == int(primera[0]):
		return res
	res["accepted"] = true
	res["quality"] = clampf(1.0 - CALIDAD_POR_PASO * float(primera[0]), CALIDAD_MIN, 1.0)
	return res


## ¿Podría lo dibujado hasta ahora ser el principio de un gesto del vocabulario con MÁS trazos? Sirve para que el libro cierre el
## gesto al soltar en cuanto nada puede añadirse, en vez de esperar la pausa. Cada trazo ya dibujado debe caber (con tolerancia, en
## cualquiera de los dos sentidos) en un trazo distinto de alguna plantilla con más trazos.
static func puede_completarse(trazos: Array, vocabulario: Dictionary) -> bool:
	var leidas: Array = secuencias(trazos)
	if leidas.is_empty():
		return false
	for nombre in vocabulario:
		for texto in formas(vocabulario, String(nombre)):
			var plantilla: Array = texto_a_gesto(texto)
			if plantilla.size() > leidas.size() and _cabe_en(leidas, 0, plantilla, []):
				return true
	return false


static func _cabe_en(leidas: Array, k: int, plantilla: Array, usados: Array) -> bool:
	if k >= leidas.size():
		return true
	for j in range(plantilla.size()):
		if usados.has(j):
			continue
		var sec: Array = plantilla[j]
		if not (bool(_coste_trazo(leidas[k], sec)["dentro"]) or bool(_coste_trazo(leidas[k], invertir(sec))["dentro"])):
			continue
		if _cabe_en(leidas, k + 1, plantilla, usados + [j]):
			return true
	return false


## Distancia entre un gesto leído y una plantilla (ambos como lista de secuencias): {"coste", "dentro"}.
## Prueba el orden de los trazos y el sentido de cada uno, y se queda con lo mejor. `dentro` = misma estructura y ningún tramo
## fuera de TOLERANCIA.
static func distancia(leidas: Array, plantilla: Array) -> Dictionary:
	var mejor: int = 1 << 20
	var dentro: bool = false
	var n: int = plantilla.size()
	if leidas.size() != n:
		return {"coste": 1000 + 100 * absi(leidas.size() - n), "dentro": false}
	for orden in _permutaciones(n):
		for mascara in range(1 << n):
			var coste: int = 0
			var todo_dentro: bool = true
			for k in range(n):
				var tramo_p: Array = plantilla[orden[k]]
				if (mascara >> k) & 1 == 1:
					tramo_p = invertir(tramo_p)
				var par: Dictionary = _coste_trazo(leidas[k], tramo_p)
				coste += int(par["coste"])
				todo_dentro = todo_dentro and bool(par["dentro"])
			# Con varios candidatos a «dentro», gana el que lo está; entre iguales, el de menos coste.
			if (todo_dentro and not dentro) or (todo_dentro == dentro and coste < mejor):
				mejor = coste
				dentro = todo_dentro
	return {"coste": mejor, "dentro": dentro}


## Un trazo recorrido al revés: tramos en orden inverso y cada dirección opuesta.
static func invertir(sec: Array) -> Array:
	var res: Array = []
	for i in range(sec.size() - 1, -1, -1):
		res.append((int(sec[i]) + PASOS / 2) % PASOS)
	return res


## «UR,DR|DL» -> [[1, 7], [5]].
static func texto_a_gesto(texto: String) -> Array:
	var res: Array = []
	for parte in texto.split("|", false):
		var sec: Array = []
		for nombre in parte.split(",", false):
			var i: int = NOMBRES_DIR.find(nombre.strip_edges())
			if i >= 0:
				sec.append(i)
		if not sec.is_empty():
			res.append(sec)
	return res


## ¿Tiene este nombre un trazo en el vocabulario (de elementos o de sellos)? `linea` cuenta: su trazo es la raya.
static func tiene_trazo(nombre: String, es_elemento: bool) -> bool:
	return texto_guia(nombre, es_elemento) != ""


## El trazo que se enseña en la guía del libro para un glifo ("" = ninguno). Es el de la tabla; `linea` no está en ella (es la raya
## sola, que se resuelve antes) pero también se enseña, como una raya.
static func texto_guia(nombre: String, es_elemento: bool) -> String:
	var tabla: Dictionary = ELEMENTOS if es_elemento else SELLOS
	if tabla.has(nombre):
		return String(tabla[nombre])
	if not es_elemento and nombre == "linea":
		return "R"
	return ""


## Desviación de un trazo leído contra una secuencia de la plantilla: pasos de diferencia tramo a tramo.
## Con una plantilla CERRADA se prueba cada esquina como punto de partida y se queda la mejor.
static func _coste_trazo(leida: Array, plantilla: Array) -> Dictionary:
	if leida.has(ILEGIBLE):
		return {"coste": 1000, "dentro": false}
	if not _cerrada(plantilla):
		return _coste_lineal(leida, plantilla)
	var mejor: Dictionary = {}
	for r in range(plantilla.size()):
		var girada: Array = plantilla.slice(r) + plantilla.slice(0, r)
		var c: Dictionary = _coste_lineal(leida, girada)
		if mejor.is_empty() or (bool(c["dentro"]) and not bool(mejor["dentro"])) \
				or (bool(c["dentro"]) == bool(mejor["dentro"]) and int(c["coste"]) < int(mejor["coste"])):
			mejor = c
	return mejor


## ¿Acaba la plantilla donde empieza? (tres tramos o más cuyos vectores suman cero: el rombo).
static func _cerrada(plantilla: Array) -> bool:
	if plantilla.size() < 3:
		return false
	var suma := Vector2.ZERO
	for d in plantilla:
		suma += vector_de(int(d))
	return suma.length() < 0.25


static func _coste_lineal(leida: Array, plantilla: Array) -> Dictionary:
	var comunes: int = mini(leida.size(), plantilla.size())
	var coste: int = 0
	var dentro: bool = leida.size() == plantilla.size()
	for i in range(comunes):
		var d: int = absi(int(leida[i]) - int(plantilla[i])) % PASOS
		d = mini(d, PASOS - d)
		coste += d
		if d > TOLERANCIA:
			dentro = false
	var sobran: int = absi(leida.size() - plantilla.size())
	return {"coste": coste + COSTE_TRAMO_SOBRANTE * sobran, "dentro": dentro}


static func _permutaciones(n: int) -> Array:
	if n <= 1:
		return [[0]] if n == 1 else [[]]
	var res: Array = []
	for sub in _permutaciones(n - 1):
		for pos in range(n):
			var p: Array = (sub as Array).duplicate()
			p.insert(pos, n - 1)
			res.append(p)
	return res


static func _a_texto(gesto: Array) -> String:
	var partes: PackedStringArray = []
	for sec in gesto:
		var nombres: PackedStringArray = []
		for d in sec:
			nombres.append("?" if int(d) == ILEGIBLE else NOMBRES_DIR[int(d)])
		partes.append(",".join(nombres))
	return "|".join(partes)


## Funde los tramos iguales seguidos (suma sus longitudes).
static func _fundir(tramos: Array) -> Array:
	var res: Array = []
	for t in tramos:
		if not res.is_empty() and int((res[res.size() - 1] as Array)[0]) == int(t[0]):
			(res[res.size() - 1] as Array)[1] = float((res[res.size() - 1] as Array)[1]) + float(t[1])
		else:
			res.append([int(t[0]), float(t[1])])
	return res


## Puntos a intervalos iguales de `paso` px por el recorrido (el último punto se conserva).
static func _remuestrear(puntos: Array, paso: float) -> Array:
	var res: Array = [puntos[0]]
	var anterior: Vector2 = puntos[0]
	var falta: float = paso
	var i: int = 1
	while i < puntos.size():
		var p: Vector2 = puntos[i]
		var d: float = anterior.distance_to(p)
		if d >= falta and d > 0.0:
			var q: Vector2 = anterior + (p - anterior) * (falta / d)
			res.append(q)
			anterior = q
			falta = paso
		else:
			falta -= d
			anterior = p
			i += 1
	if (res[res.size() - 1] as Vector2).distance_to(puntos[puntos.size() - 1]) > paso * 0.5:
		res.append(puntos[puntos.size() - 1])
	return res


## --- GUÍA VISIBLE (para el libro) ---

## Los trazos de un texto de la tabla como polilíneas en una caja de 1×1 (y hacia abajo), centradas y a escala común. Cada trazo
## se dibuja en el sentido de la tabla. Dos trazos paralelos (viento) se separan; si no, se cruzan en el centro (X, +).
static func guia_polilineas(texto: String) -> Array:
	var gesto: Array = texto_a_gesto(texto)
	var lineas: Array = []
	for sec in gesto:
		var pts := PackedVector2Array([Vector2.ZERO])
		var pos := Vector2.ZERO
		for d in sec:
			pos += vector_de(int(d))
			pts.append(pos)
		lineas.append(pts)
	# Cada trazo se centra en su propia caja.
	for i in range(lineas.size()):
		var c: Vector2 = _caja(lineas[i]).get_center()
		var pts: PackedVector2Array = lineas[i]
		for j in range(pts.size()):
			pts[j] -= c
		lineas[i] = pts
	# Si todos los trazos van en el mismo eje, se reparten a lo ancho para que no se tapen.
	if lineas.size() > 1:
		var eje: int = int(gesto[0][0]) % (PASOS / 2)
		var paralelos: bool = true
		for sec in gesto:
			for d in sec:
				if int(d) % (PASOS / 2) != eje:
					paralelos = false
		if paralelos:
			var normal: Vector2 = vector_de(eje).orthogonal()
			for i in range(lineas.size()):
				var desp: Vector2 = normal * (float(i) - float(lineas.size() - 1) * 0.5) * 0.9
				var pts: PackedVector2Array = lineas[i]
				for j in range(pts.size()):
					pts[j] += desp
				lineas[i] = pts
	var todo := Rect2()
	for i in range(lineas.size()):
		var caja: Rect2 = _caja(lineas[i])
		todo = caja if i == 0 else todo.merge(caja)
	var lado: float = maxf(maxf(todo.size.x, todo.size.y), 0.001)
	var centro: Vector2 = todo.get_center()
	var res: Array = []
	for pts in lineas:
		var out := PackedVector2Array()
		for p in (pts as PackedVector2Array):
			out.append((p - centro) / lado + Vector2(0.5, 0.5))
		res.append(out)
	return res


## Dibuja la guía de `texto` dentro de `caja` (con el margen que haga falta) sobre un CanvasItem: SOLO se puede llamar desde su
## _draw. Polilínea con un punto en el inicio y una punta de flecha al final de cada trazo.
static func dibujar_guia(lienzo: CanvasItem, texto: String, caja: Rect2, color: Color, grosor: float = 1.5) -> void:
	var lado: float = minf(caja.size.x, caja.size.y) * 0.78
	var origen: Vector2 = caja.get_center() - Vector2(lado, lado) * 0.5
	for linea in guia_polilineas(texto):
		var pts := PackedVector2Array()
		for p in (linea as PackedVector2Array):
			pts.append(origen + p * lado)
		if pts.size() < 2:
			continue
		lienzo.draw_polyline(pts, color, grosor, true)
		lienzo.draw_circle(pts[0], maxf(grosor * 1.3, 2.0), color)
		var fin: Vector2 = pts[pts.size() - 1]
		var rumbo: Vector2 = (fin - pts[pts.size() - 2]).normalized()
		var punta: float = maxf(lado * 0.2, 3.0)
		lienzo.draw_line(fin, fin - rumbo.rotated(0.55) * punta, color, grosor, true)
		lienzo.draw_line(fin, fin - rumbo.rotated(-0.55) * punta, color, grosor, true)


static func _caja(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r
