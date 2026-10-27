## EstadosSuelo3D · qué le pasa a cada casilla del suelo (hielo, electricidad, fuego, mojado). Datos puros, sin nodos (M2, 13/10).
##
## Por qué: hoy «¿está helada esta casilla?» lo guarda la maqueta del Pipeline (`_helada`) y el Juego se lo pregunta con
## `mundo.get("_helada")` (8 sitios). Un dato, un dueño (ARQUITECTURA_MODULAR §5.1): el dueño es esta clase, y quien dibuje
## (la maqueta, el agua) pregunta aquí o escucha `Mundo3D.casilla_cambio`; no guarda su propia copia.
##
## B1 (PLAN_EOW, 21/10): además del HECHO guarda su INTENSIDAD (0..1: cuánto está quemada una casilla mientras arde) y su
## CADUCIDAD (segundos que le quedan; 0 = no caduca, que es lo de siempre), y da la imagen del estado: `textura()`, un píxel
## por casilla (R quemada · G mojada · B helada · A segada). Así la hierba, el suelo, el agua, los VFX y las condiciones de puzle
## leen el MISMO dato. B2 (21/10): la maqueta ya NO tiene su propia imagen de estado (se retiró `_img_estado`); lo único que pinta
## por su cuenta es lo «pisado» (hierba aplastada, solo aspecto, caduca en 2 s) en una textura suya de un canal (`_tex_pisado`):
## aquí no se guarda porque avisaría a todo el juego a cada paso. El canal A de esta imagen es «segada», que sí es un hecho.
## Las reglas de paso entre estados (dos aguas hielan, el calor funde el hielo…) están en una TABLA (`TRANSICIONES`), no en `if`.
class_name EstadosSuelo3D
extends RefCounted

## Los estados que existen. Una casilla puede tener varios a la vez (mojada y electrificada, por ejemplo).
const HELADA: String = "helada"
const ELECTRIFICADA: String = "electrificada"
const QUEMADA: String = "quemada"
const MOJADA: String = "mojada"
## 16/10 (14.2 · P3): la hierba de la casilla está SEGADA (cortada o consumida por el fuego): queda rastrojo y no vuelve a crecer en la sesión.
## La pone quien la siega (hoy: el fuego al acabar la ceniza de una mata); la maqueta (`Rastrojo3D`) solo DIBUJA el rastrojo al oír `cambio`.
const SEGADA: String = "segada"
const TODOS: PackedStringArray = ["helada", "electrificada", "quemada", "mojada", "segada"]

## Cómo se llama cada estado en `Mundo3D.casilla_cambio(c, que)`, que habla de lo que pasó, no de cómo queda la casilla.
const QUE: Dictionary = {"helada": "hielo", "electrificada": "rayo", "quemada": "fuego", "mojada": "mojado", "segada": "siega"}

## Se emite SOLO cuando el estado cambia de verdad (poner lo que ya hay no avisa a nadie).
signal cambio(c: Vector2i, estado: String, si: bool)

## Canal de la textura de cada estado.
const CANAL: Dictionary = {"quemada": 0, "mojada": 1, "helada": 2, "segada": 3}

## Transiciones por acción sobre UNA casilla. Se recorren en orden y gana la PRIMERA fila que encaja (como el `match` que
## sustituyen, sacado de `_impacto_en_suelo` de la maqueta). Columnas:
##   accion  lo que llega: «agua», «frio» (hielo) o «calor» (fuego)
##   con     la casilla debe tener este estado ("" = da igual)
##   sin     la casilla NO debe tener este estado ("" = da igual)
##   quita / pone   estados que se quitan y se ponen
##   efecto  lo que la presentación debería pintar (hoy solo «vapor»); `aplicar` lo devuelve, no lo pinta
## Una regla nueva es una fila nueva; ningún estado sabe de los demás.
const TRANSICIONES: Array = [
	{"accion": "agua", "con": "helada", "sin": "", "quita": [], "pone": [], "efecto": ""},                     # ya helada: nada
	{"accion": "agua", "con": "mojada", "sin": "", "quita": ["mojada"], "pone": ["helada"], "efecto": ""},     # dos aguas hielan
	{"accion": "agua", "con": "", "sin": "", "quita": [], "pone": ["mojada"], "efecto": ""},
	{"accion": "frio", "con": "", "sin": "", "quita": ["mojada"], "pone": ["helada"], "efecto": ""},
	{"accion": "calor", "con": "helada", "sin": "", "quita": ["helada"], "pone": ["mojada"], "efecto": ""},    # el hielo pasa a charco
	{"accion": "calor", "con": "mojada", "sin": "", "quita": ["mojada"], "pone": [], "efecto": "vapor"},       # el charco se seca
]

## Cuánto dura cada estado si quien lo pone no dice otra cosa (s; 0 = no caduca). El reloj es `Mundo3D._process` → `avanzar`.
## 27/10 (lote 3, cambio 1): el MOJADO se seca solo a los 20 s, lo mismo que el suelo que moja la simulación (`AguaSim3D.SECA_EN`).
## La helada de suelo sigue con su reloj de `Lanzador3D` (se deshiela y deja la casilla mojada), la electricidad la quita el emisor
## y lo quemado y lo segado se quedan.
const DURA: Dictionary = {"helada": 0.0, "electrificada": 0.0, "quemada": 0.0, "mojada": 20.0, "segada": 0.0}

## HUMEDAD QUE SE VE (27/10, idea de DK Bananza: «el suelo que toca el agua se oscurece poco a poco»). Solo aspecto: el hecho «mojada»
## es sí/no y dura lo de `DURA`; lo que pinta la imagen sube en SUBE s al mojarse (el agua empapa) y baja en los últimos SECADO s
## (se seca). Un estado sin fila aquí se pinta con su intensidad tal cual, como siempre.
const SUBE: Dictionary = {"mojada": 0.8}
const SECADO: Dictionary = {"mojada": 8.0}

var _celdas: Dictionary = {}          ## estado -> Dictionary(Vector2i -> true)
var _intensidad: Dictionary = {}      ## estado -> Dictionary(Vector2i -> float 0..1); sin entrada = 1
var _queda: Dictionary = {}           ## estado -> Dictionary(Vector2i -> float s); solo las que caducan
var _edad: Dictionary = {}            ## estado -> Dictionary(Vector2i -> float s desde que se puso); solo los estados con SUBE
## ESCARCHA (21/10): «helada» quiere decir dos cosas. Sobre AGUA es hielo que se pisa y resbala (`Terreno3D.hielo_fisico`: pisable, y_pies,
## sobre_hielo, es_agua…). Sobre SUELO (dos aguas, un hielo) es solo el estado «helada» de la casilla, para las reglas de puzle y la imagen,
## y NO cambia cómo se anda ni a qué altura se pisa. Esta lista dice qué casillas con «helada» son del segundo tipo; la llena `aplicar`
## (que solo se usa en suelo) y la vacía quien deshiela o convierte la casilla en hielo de verdad (`Terreno3D.poner_helada`).
var _escarcha: Dictionary = {}        ## Vector2i -> true
## B2 (21/10): AVANCE VISUAL. No es un hecho (no avisa, no cuenta para los puzles): es cuánto se VE ya un estado en una casilla mientras llega
## a serlo. Lo usa la maqueta para el círculo quemado que crece mientras la hierba arde (la casilla solo es `quemada` de verdad pasada la
## mitad, `ReaccionesSuelo3D.sincronizar_hierba`) y para la hierba segada, que deja el suelo oscurecido. En la imagen manda sobre la
## intensidad del hecho: la casilla se pinta con el avance mientras haya uno (> 0).
var _avance: Dictionary = {}          ## estado -> Dictionary(Vector2i -> float 0..1)

## Lado de la textura (casillas). 40 = el `_lado` de la maqueta; `dimensionar` lo cambia (Mundo3D le pasa el del mapa).
var lado: int = 40
var _img: Image = null
var _tex: ImageTexture = null
var _sucia: bool = true


func tiene(c: Vector2i, estado: String) -> bool:
	return (_celdas.get(estado, {}) as Dictionary).has(c)


## Pone o quita un estado. Devuelve true si algo cambió (el hecho; cambiar solo la intensidad o la duración no avisa).
## `intensidad` (0..1) y `dura` (s; < 0 = la de `DURA`, 0 = no caduca) solo cuentan al poner. Los que ya llamaban con tres
## argumentos siguen igual: intensidad 1 y sin caducidad.
func poner(c: Vector2i, estado: String, si: bool, intensidad: float = 1.0, dura: float = -1.0) -> bool:
	if not TODOS.has(estado):
		push_warning("EstadosSuelo3D: estado desconocido «%s»" % estado)
		return false
	var d: Dictionary = _celdas.get(estado, {})
	var inten: Dictionary = _intensidad.get(estado, {})
	var queda: Dictionary = _queda.get(estado, {})
	if si:
		var i: float = clampf(intensidad, 0.0, 1.0)
		if not is_equal_approx(float(inten.get(c, 1.0)), i):
			_sucia = true
		if is_equal_approx(i, 1.0):
			inten.erase(c)
		else:
			inten[c] = i
		var t: float = float(DURA.get(estado, 0.0)) if dura < 0.0 else dura
		if t > 0.0:
			queda[c] = t
		else:
			queda.erase(c)
	else:
		inten.erase(c)
		queda.erase(c)
		if estado == HELADA:
			_escarcha.erase(c)       # sin helada no hay escarcha que recordar
	_intensidad[estado] = inten
	_queda[estado] = queda
	if si == d.has(c):
		return false
	if si:
		d[c] = true
		if SUBE.has(estado):
			var ed: Dictionary = _edad.get(estado, {})
			ed[c] = 0.0                  # recién mojada: empieza a empapar (volver a mojar una casilla mojada no la aclara)
			_edad[estado] = ed
	else:
		d.erase(c)
		(_edad.get(estado, {}) as Dictionary).erase(c)
	_celdas[estado] = d
	_sucia = true
	cambio.emit(c, estado, si)
	return true


## Intensidad del estado en la casilla (0 si no lo tiene).
func intensidad(c: Vector2i, estado: String) -> float:
	if not tiene(c, estado):
		return 0.0
	return float((_intensidad.get(estado, {}) as Dictionary).get(c, 1.0))


## Lo que se PINTA del estado en la casilla (0..1): la intensidad por lo que ha empapado (SUBE) y por lo que le falta para secarse (SECADO).
## Solo aspecto; para las reglas vale `tiene` / `intensidad`.
func intensidad_vista(c: Vector2i, estado: String) -> float:
	var i: float = intensidad(c, estado)
	if i <= 0.0:
		return 0.0
	if SUBE.has(estado):
		var ed: Variant = (_edad.get(estado, {}) as Dictionary).get(c)
		if ed != null:
			i *= smoothstep(0.0, float(SUBE[estado]), float(ed))
	if SECADO.has(estado):
		var q: float = queda(c, estado)
		if q > 0.0:
			i *= smoothstep(0.0, float(SECADO[estado]), q)
	return i


## Avance visual de un estado en la casilla (0..1; 0 = ninguno). Ver `_avance`: solo aspecto, no es el hecho.
func avance(c: Vector2i, estado: String) -> float:
	return float((_avance.get(estado, {}) as Dictionary).get(c, 0.0))


## Pone el avance visual (0 lo quita). No avisa a nadie: no es un hecho. Solo para estados con canal en la imagen.
func poner_avance(c: Vector2i, estado: String, valor: float) -> void:
	if not CANAL.has(estado):
		push_warning("EstadosSuelo3D: avance de un estado sin canal «%s»" % estado)
		return
	var d: Dictionary = _avance.get(estado, {})
	var v: float = clampf(valor, 0.0, 1.0)
	if v <= 0.0:
		if d.erase(c):
			_sucia = true
	elif not is_equal_approx(float(d.get(c, -1.0)), v):
		d[c] = v
		_sucia = true
	_avance[estado] = d


## Segundos que le quedan (0 = no caduca o no lo tiene).
func queda(c: Vector2i, estado: String) -> float:
	return float((_queda.get(estado, {}) as Dictionary).get(c, 0.0))


## Pasa el tiempo: quita (y avisa) lo que caduca y deja la imagen por rehacer si algo se está empapando o secando. El reloj del nivel es
## `Mundo3D._process` (27/10); las pruebas sin mundo la llaman a mano.
func avanzar(dt: float) -> void:
	for estado in _edad.keys():
		var ed: Dictionary = _edad[estado]
		var tope: float = float(SUBE.get(estado, 0.0))
		var listas: Array = []
		for c in ed.keys():
			ed[c] = float(ed[c]) + dt
			_sucia = true
			if float(ed[c]) >= tope:
				listas.append(c)             # ya empapó del todo: no hace falta seguir contando
		for c in listas:
			ed.erase(c)
	for estado in _queda.keys():
		var q: Dictionary = _queda[estado]
		var secado: float = float(SECADO.get(estado, 0.0))
		var caducan: Array = []
		for c in q.keys():
			q[c] = float(q[c]) - dt
			if float(q[c]) <= 0.0:
				caducan.append(c)
			elif float(q[c]) < secado:
				_sucia = true                # se está secando: la imagen cambia
		for c in caducan:
			poner(c, String(estado), false)


## Aplica la acción («agua», «frio», «calor») a la casilla con la primera fila de `TRANSICIONES` que encaje.
## Devuelve {"cambio": bool, "efecto": String}. No pinta nada: el efecto es para quien dibuja.
## SOLO PARA SUELO (no agua): la «helada» que ponga es escarcha (ver `_escarcha`), no hielo que se pise.
func aplicar(c: Vector2i, accion: String) -> Dictionary:
	for f in TRANSICIONES:
		var fila: Dictionary = f
		if String(fila["accion"]) != accion:
			continue
		if String(fila["con"]) != "" and not tiene(c, String(fila["con"])):
			continue
		if String(fila["sin"]) != "" and tiene(c, String(fila["sin"])):
			continue
		var algo: bool = false
		var ya_helada: bool = tiene(c, HELADA)
		for e in fila["quita"]:
			algo = poner(c, String(e), false) or algo
		for e in fila["pone"]:
			# Se apunta ANTES de poner: `poner` avisa por señal y quien escuche (Caminos3D) ya debe ver que no es hielo de agua.
			# Si la casilla ya estaba helada (hielo de una charca que congeló la simulación) sigue siendo hielo de verdad.
			if String(e) == HELADA and not ya_helada:
				_escarcha[c] = true
			algo = poner(c, String(e), true) or algo
		return {"cambio": algo, "efecto": String(fila["efecto"])}
	return {"cambio": false, "efecto": ""}


## ¿Es la «helada» de esta casilla solo la del suelo (escarcha) y no hielo sobre agua? Falso si la casilla no está helada.
func es_escarcha(c: Vector2i) -> bool:
	return _escarcha.has(c) and tiene(c, HELADA)


## La casilla deja de contar como escarcha (pasa a ser hielo de verdad). No avisa: lo hace `Terreno3D.poner_helada`.
func quitar_escarcha(c: Vector2i) -> bool:
	return _escarcha.erase(c)


## Cambia el lado de la textura (casillas). Rehace la imagen la próxima vez que se pida.
func dimensionar(n: int) -> void:
	if n > 0 and n != lado:
		lado = n
		_img = null
		_sucia = true
## La imagen del estado: `lado`×`lado` RGBA8, un píxel por casilla (R quemada · G mojada · B helada · A segada, cada uno con lo que se ve:
## `intensidad_vista`). Es SIEMPRE el mismo objeto: se rehace solo si algo cambió desde la última vez (`update`, no se recrea en GPU).
func textura() -> ImageTexture:
	if _img == null or _img.get_width() != lado:
		_img = Image.create_empty(lado, lado, false, Image.FORMAT_RGBA8)
		_tex = null
		_sucia = true
	if _sucia:
		_img.fill(Color(0.0, 0.0, 0.0, 0.0))
		for estado in CANAL.keys():
			var k: int = int(CANAL[estado])
			for c in celdas(String(estado)):
				var p: Vector2i = c
				if p.x < 0 or p.y < 0 or p.x >= lado or p.y >= lado:
					continue
				var col: Color = _img.get_pixelv(p)
				col[k] = intensidad_vista(p, String(estado))
				_img.set_pixelv(p, col)
		for estado in _avance.keys():
			var k2: int = int(CANAL[estado])
			var av: Dictionary = _avance[estado]
			for c in av.keys():
				var p2: Vector2i = c
				if p2.x < 0 or p2.y < 0 or p2.x >= lado or p2.y >= lado:
					continue
				var col2: Color = _img.get_pixelv(p2)
				col2[k2] = float(av[c])
				_img.set_pixelv(p2, col2)
		if _tex == null:
			_tex = ImageTexture.create_from_image(_img)
		else:
			_tex.update(_img)
		_sucia = false
	return _tex


## La misma imagen que sube `textura()`, al día (para leerla en CPU: pruebas, condiciones). No modificarla desde fuera.
func imagen() -> Image:
	textura()
	return _img


## Las casillas con ese estado (copia: se puede recorrer mientras cambian).
func celdas(estado: String) -> Array:
	return (_celdas.get(estado, {}) as Dictionary).keys()


func cuantas(estado: String) -> int:
	return (_celdas.get(estado, {}) as Dictionary).size()


## Empieza de cero (cambio de nivel). No emite `cambio`: quien recarga el nivel se redibuja entero.
func limpiar() -> void:
	_celdas.clear()
	_intensidad.clear()
	_queda.clear()
	_edad.clear()
	_escarcha.clear()
	_avance.clear()
	_sucia = true
