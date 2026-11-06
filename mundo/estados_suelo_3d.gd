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
## 6/11 (bloque B3): ESCOMBRO es lo que deja la tierra al pararse (ralentiza a quien lo pisa y es sólido para los proyectiles) y VAPOR la nube que deja el calor al secar (la ceguera de los
## enemigos que la usen es de otro agente: aquí solo es el DATO). Ninguno tiene canal en la imagen: no se pintan en el suelo.
const ESCOMBRO: String = "escombro"
const VAPOR: String = "vapor"
const TODOS: PackedStringArray = ["helada", "electrificada", "quemada", "mojada", "segada", "escombro", "vapor"]

## Cómo se llama cada estado en `Mundo3D.casilla_cambio(c, que)`, que habla de lo que pasó, no de cómo queda la casilla.
const QUE: Dictionary = {"helada": "hielo", "electrificada": "rayo", "quemada": "fuego", "mojada": "mojado", "segada": "siega", "escombro": "tierra", "vapor": "nube"}

## B3: lo que dura el escombro y el vapor (s). Una sola constante cada uno; `DURA` las lee.
const ESCOMBRO_S: float = 6.0
const VAPOR_S: float = 4.0
## B3: a qué velocidad anda quien pisa el estado (×; 1 = normal). El jugador y los enemigos lo leen con `factor_velocidad(celda)` cuando se enganchen.
const FACTOR_VELOCIDAD: Dictionary = {"escombro": 0.7}
## B3: estados que un proyectil NO atraviesa (`bloquea_proyectil`). HechizoVivo lo consultará cuando se enganche.
const BLOQUEA_PROYECTIL: PackedStringArray = ["escombro"]

## Se emite SOLO cuando el estado cambia de verdad (poner lo que ya hay no avisa a nadie).
signal cambio(c: Vector2i, estado: String, si: bool)
## C2 (3/11): un estado ha CADUCADO (se le acabó el reloj), a diferencia de `cambio(…, false)`, que también salta si lo quita un hechizo (el fuego funde el hielo). Salta DESPUÉS de `AL_CADUCAR`
## (la casilla ya está en su estado nuevo). Lo oye `Lanzador3D` para soltar el vapor de la helada que acaba su tiempo.
signal caducado(c: Vector2i, estado: String)

## Canal de la textura de cada estado.
const CANAL: Dictionary = {"quemada": 0, "mojada": 1, "helada": 2, "segada": 3}

## Transiciones por acción sobre UNA casilla. Se recorren en orden y gana la PRIMERA fila que encaja (como el `match` que
## sustituyen, sacado de `_impacto_en_suelo` de la maqueta). Columnas:
##   accion  lo que llega: «agua», «frio» (hielo) o «calor» (fuego)
##   con     la casilla debe tener este estado ("" = da igual)
##   sin     la casilla NO debe tener este estado ("" = da igual)
##   quita / pone   estados que se quitan y se ponen
##   efecto  lo que la presentación debería pintar (hoy solo «vapor»); `aplicar` lo devuelve, no lo pinta
## Columnas opcionales (B3, 6/11), para no tocar las filas de siempre:
##   con_algun  la casilla debe tener AL MENOS UNO de estos estados (lista). Sin ella, una fila «limpia» encajaría en casillas que no tienen nada que limpiar y taparía a la siguiente.
##   mantiene   true = el estado que pone se pone con `mantener` (no acorta uno que ya no caduca; el rayo sobre la electrificada permanente de un puzle)
##   rotulo     nombre de la reacción para la previsión cuando la fila cambia algo (si falta, `ReaccionesSuelo3D.prever` lo deduce de lo que quita y pone)
## Acciones nuevas (B3): «sopla» (viento), «escombro» (tierra), «descarga» (rayo). Una acción sin fila (la «tierra» a secas) no hace nada, como siempre.
## Una regla nueva es una fila nueva; ningún estado sabe de los demás.
const TRANSICIONES: Array = [
	{"accion": "agua", "con": "helada", "sin": "", "quita": [], "pone": [], "efecto": ""},                     # ya helada: nada
	{"accion": "agua", "con": "mojada", "sin": "", "quita": ["mojada"], "pone": ["helada"], "efecto": ""},     # dos aguas hielan
	{"accion": "agua", "con": "quemada", "sin": "", "quita": [], "pone": ["mojada", "vapor"], "efecto": "vapor", "rotulo": "vapor"},   # B3: el agua sobre lo quemado humea (la quemada se queda: eso lo decide su reloj)
	{"accion": "agua", "con": "", "sin": "", "quita": [], "pone": ["mojada"], "efecto": ""},
	{"accion": "frio", "con": "", "sin": "", "quita": ["mojada"], "pone": ["helada"], "efecto": ""},
	{"accion": "calor", "con": "helada", "sin": "", "quita": ["helada"], "pone": ["mojada", "vapor"], "efecto": ""},    # el hielo pasa a charco (y suelta una nube; el vapor VISUAL de este caso lo pinta el Lanzador al caducar)
	{"accion": "calor", "con": "mojada", "sin": "", "quita": ["mojada"], "pone": ["vapor"], "efecto": "vapor"},       # el charco se seca y deja la nube
	# B3 · VIENTO: limpia. El hielo pesa (el viento no lo mueve): fila PRIMERA y vacía para que la de abajo no encaje en una casilla helada.
	{"accion": "sopla", "con": "helada", "sin": "", "quita": [], "pone": [], "efecto": ""},
	{"accion": "sopla", "con": "", "con_algun": ["mojada", "electrificada", "quemada"], "sin": "", "quita": ["mojada", "electrificada", "quemada"], "pone": [], "efecto": ""},
	# B3 · TIERRA: escombro (6 s). Otra pedrada sobre el escombro lo renueva.
	{"accion": "escombro", "con": "", "sin": "", "quita": [], "pone": ["escombro"], "efecto": ""},
	# B3 · RAYO: sobre casilla MOJADA electrifica (6 s); sobre seca, nada (no hay fila). Es lo mismo que hace `Lanzador3D.electrificar_celda` (que además cubre el agua).
	{"accion": "descarga", "con": "mojada", "sin": "", "quita": [], "pone": ["electrificada"], "efecto": "", "mantiene": true},
]

## B3: de qué ELEMENTO viene cada acción (para consultar `REACCION_MATERIAL`, que habla de elementos). Una acción que no está aquí no mira el material.
const ELEMENTO_DE_ACCION: Dictionary = {"agua": "agua", "frio": "hielo", "calor": "fuego", "sopla": "viento", "escombro": "tierra", "descarga": "rayo"}

## B4 (6/11) · MATERIAL por casilla. Los valores posibles:
const MATERIALES: PackedStringArray = ["hierba", "roca", "tierra", "madera", "agua", "arena"]
## Qué material sale de la LETRA del mapa (`Terreno3D.letra_de`) si nadie lo dice: `v` hierba, `~` agua, `#` roca (muro), `b` madera (el puente de tablas/tronco); el resto, tierra.
const MATERIAL_DE_LETRA: Dictionary = {"v": "hierba", "~": "agua", "#": "roca", "b": "madera"}
const MATERIAL_DEFECTO: String = "tierra"

## B4: elemento × material = qué puede pasar. Sin entrada = lo de siempre (todo permitido, sin factor). Claves:
##   prende   el fuego puede ENCENDER la casilla (hierba y madera sí; roca, tierra, arena, agua no). Es solo el encendido: el calor sigue fundiendo hielo y secando charcos en cualquier suelo (`TRANSICIONES`).
##   propaga  lo que arde contagia a las vecinas (la hierba sí; la madera arde sola). La propagación la hace el autómata de la maqueta (`_hf`); esto es lo que debe preguntarle.
##   actua    false = el elemento NO deja su estado ahí (la tierra no hace escombro en el agua).
##   seca_x   cuántas veces más deprisa se SECA lo mojado (la arena bebe: el doble, DURA/2).
##   hiela    el hielo sobre agua hiela (lo hace la simulación del agua, `ReaccionesAgua3D`; aquí es dato de la tabla).
const REACCION_MATERIAL: Dictionary = {
	"fuego": {
		"hierba": {"prende": true, "propaga": true},
		"madera": {"prende": true, "propaga": false},
		"roca": {"prende": false}, "tierra": {"prende": false}, "arena": {"prende": false}, "agua": {"prende": false},
	},
	"agua": {"arena": {"seca_x": 2.0}},
	"tierra": {"agua": {"actua": false}},
	"hielo": {"agua": {"hiela": true}},
}

## Cuánto dura cada estado si quien lo pone no dice otra cosa (s; 0 = no caduca). El reloj es `Mundo3D._process` → `avanzar`.
## 27/10 (lote 3, cambio 1): el MOJADO se seca solo a los 20 s, lo mismo que el suelo que moja la simulación (`AguaSim3D.SECA_EN`).
## C2 (3/11, decisión de Pablo: «sin aplicación el rayo se irá a los 2 segundos; hielo se va a los 20 segundos»): la ELECTRIFICADA caduca a los 2 s si nadie la
## mantiene (el `EmisorRayo3D` activo la renueva mientras dura la descarga) y la HELADA a los 20 s (se deshiela y deja la casilla mojada, `AL_CADUCAR`). Esta constante es
## el ÚNICO sitio donde está la duración del hielo: `AguaSim3D.DURA_HIELO`, `Hierba3D.ESCARCHA_S` y `Lanzador3D` la leen de aquí. Lo quemado y lo segado se quedan (sin decidir).
## 6/11 (bloque A5, decisión de Pablo): la ELECTRIFICADA pasa de 2 s a 6 s (con 2 s no daba tiempo a preparar nada encima) y la QUEMADA deja de ser permanente: caduca a los 8 s.
## OJO: el 3/11 Pablo había fijado electrificada 2 s; el 6 s NO es un error, es esta decisión posterior. La helada se queda en 20 s.
## 6/11 (bloque B3): escombro 6 s y vapor 4 s (`ESCOMBRO_S`, `VAPOR_S`).
const DURA: Dictionary = {"helada": 20.0, "electrificada": 6.0, "quemada": 8.0, "mojada": 20.0, "segada": 0.0, "escombro": ESCOMBRO_S, "vapor": VAPOR_S}

## C1 (2/11, lote 3 cambio 1), la columna «al_caducar»: qué estado queda en la casilla cuando OTRO caduca (se quita el que caduca y se pone este; "" o sin fila = nada). Hoy solo hay una fila: lo que
## se hiela (una `helada` que caduca) se deshiela y deja la casilla MOJADA. C2 (3/11): ya se usa de verdad (`DURA["helada"]` = 20) y el `Lanzador3D` dejó su contador: oye `caducado` para soltar
## el vapor y lo demás. El mojado se seca sin más (sin fila), como siempre.
const AL_CADUCAR: Dictionary = {"helada": "mojada"}

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

## F4 (29/10): Callable(celda: Vector2i) -> Array con los estados del mundo de la zona de esa casilla (`EstadoZona3D.estados_de`; la conecta `Mundo3D`). Con él el suelo CADUCA según la zona
## (`secado_x`: el mojado se seca en 6 s con calor; `hielo_dura_x`: lo helado con caducidad dura 1/3 con calor y casi no caduca con frío) y el mojado se hiela solo en el frío
## (`hiela_sola_s`). Sin él (vacío) todo es como siempre.
var estado_zona_en: Callable = Callable()
var _frio_t: Dictionary = {}          ## Vector2i -> s que lleva mojada en una zona que hiela sola
## B4 · MATERIAL. Vive aquí (y no en `Terreno3D`) porque es el mismo tipo de dato que los estados —una propiedad por casilla que decide qué reacciona— y quien pregunta
## «¿esto arde? ¿esto se seca?» ya le pregunta a esta clase; `Terreno3D` solo conoce las letras, y de ahí se deduce lo que nadie ha dicho (`material_de`).
var _material: Dictionary = {}        ## Vector2i -> String: solo las casillas que alguien fijó (pieza `; material` o `poner_material`); el resto se deduce de la letra
## Quien conozca la hierba de verdad (hoy la maqueta: `_es_hierba`, que no es solo la letra `v` sino también el tipo de suelo y las zonas) la conecta aquí: Callable(c) -> bool. Sin él, la letra.
var hierba_en: Callable = Callable()

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


## C2 (3/11): pone o RENUEVA el estado con la caducidad del reloj oficial (`DURA`), salvo que la casilla ya lo tenga SIN caducidad (lo mantiene otro: el canal electrificado del Bosque 1,
## el hielo permanente): ese no se acorta. Lo usan la descarga de un hechizo de rayo y el rayo sobre una casilla mojada. Devuelve true si el estado cambió (como `poner`).
func mantener(c: Vector2i, estado: String) -> bool:
	if tiene(c, estado) and queda(c, estado) <= 0.0:
		return false
	return poner(c, estado, true)


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
	if estado_zona_en.is_valid():
		_hielo_solo(dt)
	for estado in _queda.keys():
		var q: Dictionary = _queda[estado]
		var secado: float = float(SECADO.get(estado, 0.0))
		var caducan: Array = []
		for c in q.keys():
			q[c] = float(q[c]) - dt * _ritmo_caducidad(c as Vector2i, String(estado))
			if float(q[c]) <= 0.0:
				caducan.append(c)
			elif float(q[c]) < secado:
				_sucia = true                # se está secando: la imagen cambia
		for c in caducan:
			poner(c, String(estado), false)
			var despues: String = String(AL_CADUCAR.get(estado, ""))
			if despues != "":
				poner(c, despues, true)              # al_caducar: lo helado queda mojado (con la caducidad del mojado, `DURA`)
			caducado.emit(c as Vector2i, String(estado))


## F4: a qué velocidad corre el reloj de `estado` en `c` según la zona (1 = normal): el mojado se seca 1/`secado_x` veces más deprisa; lo helado con caducidad, 1/`hielo_dura_x`.
func _ritmo_caducidad(c: Vector2i, estado: String) -> float:
	if not estado_zona_en.is_valid() or (estado != MOJADA and estado != HELADA):
		return 1.0
	var zona: Array = estado_zona_en.call(c)
	if zona.is_empty():
		return 1.0
	var x: float = EstadoZona3D.producto(zona, "secado_x" if estado == MOJADA else "hielo_dura_x")
	return 1.0 / maxf(x, 0.01)


## F4: en una zona con `hiela_sola_s` (frío) una casilla de SUELO mojada se hiela sola a los 5 s (la misma transición que un hechizo de hielo: mojada → helada). Solo SUELO (`ReaccionesSuelo3D.clase_de`).
func _hielo_solo(dt: float) -> void:
	var mojadas: Dictionary = _celdas.get(MOJADA, {})
	for c in _frio_t.keys():
		if not mojadas.has(c):
			_frio_t.erase(c)
	for c in mojadas.keys():
		var tiempo: float = EstadoZona3D.numero(estado_zona_en.call(c), "hiela_sola_s")
		if tiempo <= 0.0:
			_frio_t.erase(c)
			continue
		_frio_t[c] = float(_frio_t.get(c, 0.0)) + dt
		if float(_frio_t[c]) >= tiempo:
			_frio_t.erase(c)
			if ReaccionesSuelo3D.clase_de(c as Vector2i) == "suelo":
				aplicar(c as Vector2i, "frio")


## Aplica la acción («agua», «frio», «calor») a la casilla con la primera fila de `TRANSICIONES` que encaje.
## Devuelve {"cambio": bool, "efecto": String}. No pinta nada: el efecto es para quien dibuja.
## SOLO PARA SUELO (no agua): la «helada» que ponga es escarcha (ver `_escarcha`), no hielo que se pise.
func aplicar(c: Vector2i, accion: String) -> Dictionary:
	var fila: Dictionary = fila_para(c, accion)
	if not fila.is_empty():
		var algo: bool = false
		var ya_helada: bool = tiene(c, HELADA)
		for e in fila["quita"]:
			algo = poner(c, String(e), false) or algo
		for e in fila["pone"]:
			# Se apunta ANTES de poner: `poner` avisa por señal y quien escuche (Caminos3D) ya debe ver que no es hielo de agua.
			# Si la casilla ya estaba helada (hielo de una charca que congeló la simulación) sigue siendo hielo de verdad.
			if String(e) == HELADA and ya_helada:
				continue         # C2: otro hielo sobre una casilla ya helada NO renueva sus 20 s (Pablo, 12/10; antes lo impedía el `_hielo.has` del Lanzador)
			if String(e) == HELADA and not ya_helada:
				_escarcha[c] = true
			if bool(fila.get("mantiene", false)):
				algo = mantener(c, String(e)) or algo      # B3: la descarga no acorta una electrificada que otro mantiene sin caducidad
				continue
			# B4: la arena bebe: lo mojado se seca `seca_x` veces más deprisa (DURA/2). Solo se pasa la duración si cambia; con 1 es la de siempre.
			var dura: float = -1.0
			if String(e) == MOJADA:
				var x: float = float(reaccion("agua", material_de(c), "seca_x", 1.0))
				if not is_equal_approx(x, 1.0):
					dura = float(DURA[MOJADA]) / maxf(x, 0.01)
			algo = poner(c, String(e), true, 1.0, dura) or algo
		return {"cambio": algo, "efecto": String(fila["efecto"])}
	return {"cambio": false, "efecto": ""}


## 28/10 · A2 (previsión): la fila de `TRANSICIONES` que `aplicar` usaría con esta acción en esta casilla ({} si ninguna encaja), sin tocar nada. `aplicar` la ejecuta; la previsión
## la lee (`ReaccionesSuelo3D.prever`): una sola regla.
func fila_para(c: Vector2i, accion: String) -> Dictionary:
	# B4: si el material de la casilla dice que este elemento NO actúa ahí (la tierra en el agua no hace escombro), ninguna fila encaja.
	if not bool(reaccion(String(ELEMENTO_DE_ACCION.get(accion, "")), material_de(c), "actua", true)):
		return {}
	for f in TRANSICIONES:
		var fila: Dictionary = f
		if String(fila["accion"]) != accion:
			continue
		if String(fila["con"]) != "" and not tiene(c, String(fila["con"])):
			continue
		if String(fila["sin"]) != "" and tiene(c, String(fila["sin"])):
			continue
		if fila.has("con_algun"):
			var alguno: bool = false
			for e in (fila["con_algun"] as Array):
				if tiene(c, String(e)):
					alguno = true
					break
			if not alguno:
				continue
		return fila
	return {}


## B3/B4 (previsión): ¿cambiaría algo `aplicar` con esta fila en esta casilla? (quita algo que hay o pone algo que falta). `ReaccionesSuelo3D.prever` solo avisa si es que sí.
func cambiaria(c: Vector2i, fila: Dictionary) -> bool:
	for e in (fila["quita"] as Array):
		if tiene(c, String(e)):
			return true
	for e in (fila["pone"] as Array):
		if not tiene(c, String(e)):
			return true
	return false


## B3 · ¿hay escombro (o lo que haga de él) que frene a quien pisa esta casilla? Producto de `FACTOR_VELOCIDAD` de los estados que tiene; 1 = normal.
## Pendiente de engancharlo: `jugador_3d.gd` y `combate_3d.gd` (ver el informe).
func factor_velocidad(c: Vector2i) -> float:
	var f: float = 1.0
	for estado in FACTOR_VELOCIDAD.keys():
		if tiene(c, String(estado)):
			f *= float(FACTOR_VELOCIDAD[estado])
	return f


## B3 · ¿un proyectil que pasa por esta casilla se para? (escombro). Pendiente de engancharlo: `HechizoVivo` (ver el informe).
func bloquea_proyectil(c: Vector2i) -> bool:
	for estado in BLOQUEA_PROYECTIL:
		if tiene(c, estado):
			return true
	return false


## B3 · ¿hay una nube de vapor en la casilla? (la deja el calor al secar; quien la use —la ceguera de los enemigos— la lee aquí)
func hay_vapor(c: Vector2i) -> bool:
	return tiene(c, VAPOR)


## B4 · lo que la tabla `REACCION_MATERIAL` dice de `elemento` sobre `material` para la `clave`; `defecto` si no dice nada.
static func reaccion(elemento: String, material: String, clave: String, defecto: Variant = null) -> Variant:
	var filas: Dictionary = (REACCION_MATERIAL.get(elemento, {}) as Dictionary)
	return (filas.get(material, {}) as Dictionary).get(clave, defecto)


## B4 · el material de la casilla: lo que alguien fijó (pieza `; material`, `poner_material`) > la hierba que reconoce quien la conoce (`hierba_en`) > la letra del mapa (`MATERIAL_DE_LETRA`)
## > `tierra`. Sin mundo (una prueba suelta) y sin nada fijado, `tierra`.
func material_de(c: Vector2i) -> String:
	if _material.has(c):
		return String(_material[c])
	if hierba_en.is_valid() and bool(hierba_en.call(c)):
		return "hierba"
	if Terreno3D.hay_mundo() and Terreno3D.en_mapa(c):
		return String(MATERIAL_DE_LETRA.get(Terreno3D.letra_de(c), MATERIAL_DEFECTO))
	return MATERIAL_DEFECTO


## B4 · fija el material de una casilla (la pieza `; material x y mat` del mapa lo hace al montar). "" lo quita (vuelve a deducirse de la letra). Devuelve false si el material no existe.
func poner_material(c: Vector2i, material: String) -> bool:
	if material == "":
		return _material.erase(c)
	if not MATERIALES.has(material):
		push_warning("EstadosSuelo3D: «%s» no es un material (%s)" % [material, ", ".join(MATERIALES)])
		return false
	_material[c] = material
	return true


## B4 · ¿puede el fuego ENCENDER esta casilla? Lo dice `REACCION_MATERIAL`: la hierba y la madera sí; roca, tierra, arena y agua no. La maqueta lo consulta en `_puede_prender`.
func puede_prender(c: Vector2i) -> bool:
	return bool(reaccion("fuego", material_de(c), "prende", false))


## B4 · ¿lo que arde en esta casilla contagia a las vecinas? (la hierba sí; la madera arde sola). El autómata de la maqueta debería preguntarlo; hoy solo hay hierba.
func propaga_fuego(c: Vector2i) -> bool:
	return bool(reaccion("fuego", material_de(c), "propaga", false))


## B4 · cambio de nivel: olvida los materiales fijados (`limpiar` NO los toca, porque `desde_dic` limpia al cargar una partida y los materiales son del mapa, no de la partida).
func olvidar_materiales() -> void:
	_material.clear()


## B4 · lee las líneas `; material <x> <y> <material>` (una casilla) y `; material <x0>,<y0>..<x1>,<y1> <material>` (un rectángulo) de un texto de mapa. Una línea mala se avisa y se salta.
func leer_materiales(texto: String) -> int:
	var n: int = 0
	for bruta in texto.split("\n"):
		var linea: String = bruta.strip_edges()
		if not linea.begins_with(";"):
			continue
		var partes: PackedStringArray = linea.substr(1).strip_edges().split(" ", false)
		if partes.size() < 3 or partes[0] != "material":
			continue
		if partes.size() >= 4 and partes[1].is_valid_int() and partes[2].is_valid_int():
			if poner_material(Vector2i(int(partes[1]), int(partes[2])), partes[3]):
				n += 1
		else:
			var rect: Rect2i = EstadoZona3D._rect(partes[1])
			if rect.size.x <= 0:
				push_warning("EstadosSuelo3D: línea de material mal formada: «%s»" % linea)
				continue
			for y in range(rect.position.y, rect.position.y + rect.size.y):
				for x in range(rect.position.x, rect.position.x + rect.size.x):
					if poner_material(Vector2i(x, y), partes[2]):
						n += 1
	return n


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


## C1 punto 3 (partida entera): el estado del suelo como diccionario para el archivo de partida. Por estado, una lista de [x, y, intensidad, segundos que le quedan] (0 = no caduca) y, aparte,
## las casillas con escarcha. NO guarda la «helada» que no es escarcha (el hielo sobre agua lo lleva `Terreno3D.poner_helada` y la simulación del agua, que no se guardan) ni el avance visual
## (`_avance`, solo aspecto) ni la edad del empapado (al cargar, lo mojado se ve entero).
func a_dic() -> Dictionary:
	var estados: Dictionary = {}
	for estado in TODOS:
		var lista: Array = []
		for c in celdas(estado):
			var p: Vector2i = c
			if estado == HELADA and not es_escarcha(p):
				continue
			lista.append([p.x, p.y, snappedf(intensidad(p, estado), 0.001), snappedf(queda(p, estado), 0.01)])
		if not lista.is_empty():
			estados[estado] = lista
	var esc: Array = []
	for c in _escarcha.keys():
		if tiene(c as Vector2i, HELADA):
			esc.append([(c as Vector2i).x, (c as Vector2i).y])
	return {"estados": estados, "escarcha": esc}


## Lo contrario de `a_dic`: deja el suelo como estaba en el archivo. Vacía antes lo que hubiera (`limpiar`) y pone cada casilla con `poner` (así avisa por `cambio` y la hierba, el suelo y el
## agua se redibujan). Un diccionario ilegible, un estado desconocido o una casilla fuera del mapa se saltan sin romper nada.
func desde_dic(d: Dictionary) -> void:
	var antes: Array = []
	for estado in TODOS:
		for c in celdas(estado):
			antes.append([c, estado])
	limpiar()
	for par in antes:
		cambio.emit(par[0], String(par[1]), false)     # `limpiar` no avisa: quien dibuja se entera de que lo de antes ya no está
	var esc: Variant = d.get("escarcha", [])
	if esc is Array:
		for v in (esc as Array):
			if v is Array and (v as Array).size() >= 2:
				_escarcha[Vector2i(int(v[0]), int(v[1]))] = true     # antes de `poner`: quien escuche ya debe ver que no es hielo de agua
	var estados: Variant = d.get("estados", {})
	if not (estados is Dictionary):
		return
	for estado in (estados as Dictionary).keys():
		var lista: Variant = (estados as Dictionary)[estado]
		if not TODOS.has(String(estado)) or not (lista is Array):
			continue
		for v in (lista as Array):
			if not (v is Array) or (v as Array).size() < 4:
				continue
			poner(Vector2i(int(v[0]), int(v[1])), String(estado), true, float(v[2]), float(v[3]))


## Empieza de cero (cambio de nivel). No emite `cambio`: quien recarga el nivel se redibuja entero.
func limpiar() -> void:
	_celdas.clear()
	_intensidad.clear()
	_queda.clear()
	_edad.clear()
	_escarcha.clear()
	_avance.clear()
	_frio_t.clear()
	_sucia = true
