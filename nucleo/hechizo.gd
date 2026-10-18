class_name Hechizo
extends RefCounted

## UN SOLO SITIO DONDE SE CONSTRUYE UN HECHIZO (HC1, 18/10; docs HECHIZO_CLASE.md).
##
## Datos puros, sin nodos: todos los parámetros de un hechizo con su valor por defecto (0, falso o vacío si no hay nada que decir). Se construyen
## con `Hechizo.construir(elemento, glifos, calidad)` en un orden fijo:
##   1. valores por defecto (los de los `var` de abajo)
##   2. modificadores del elemento (los campos de RuneData de hoy traducidos + `RuneData.modificadores`: duraciones de estado, fuerza del golpe…)
##   3. modificadores de los glifos (`Sigils.GLIFOS`): primero fija y sumas, después multiplicaciones
##   4. topes, y después los mínimos («suelos», como el de la barrera)
##   5. derivados: forma, niveles, coste, recarga, cast point (no se tocan a mano)
## Un modificador es `{campo, op, valor, tope, desde}` (ver Sigils.GLIFOS). Un glifo o un elemento nuevo es solo datos.
##
## HC1 es REFACTORIZACIÓN: aún no lo lee nadie. Convive con `Sigils.aplicar_v2` + `RuneData` + `Receta3D`, y `prueba_hechizo` comprueba que da los mismos números.

const EPS: float = 0.0001

## Los campos, por grupos, en el orden en que los enseñará el laboratorio (HC5). [nombre, grupo].
const CAMPOS: Array = [
	["semiejes", "forma"], ["copias", "forma"], ["crece", "forma"], ["solidez", "forma"],
	["velocidad", "movimiento"], ["aceleracion", "movimiento"], ["gravedad", "movimiento"], ["distancia_max", "movimiento"],
	["persiste", "movimiento"], ["altura_salida", "movimiento"], ["rebotes", "movimiento"], ["retorna", "movimiento"], ["busca", "movimiento"], ["en_punto", "movimiento"],
	["dano", "combate"], ["empuje", "combate"], ["fuerza_golpe", "combate"], ["perfora", "combate"], ["radio_explosion", "combate"], ["golpea_lanzador", "combate"],
	["quema", "estados"], ["moja", "estados"], ["congela", "estados"], ["congela_mojado", "estados"], ["aturde", "estados"],
	["ralentiza", "estados"], ["ralentiza_fuerza", "estados"], ["interrumpe", "estados"], ["veneno", "estados"], ["veneno_dps", "estados"], ["deja", "estados"],
	["estado_materia", "materia"], ["pisable", "materia"],
	["choca_con", "choque"], ["color", "aspecto"], ["estela", "aspecto"], ["efecto_impacto", "aspecto"],
	["eventos", "eventos"],
]

## Los eventos que dispara un hechizo vivo (HC4, §2.3) y el catálogo CERRADO de acciones que puede llevar cada uno. Todo lo demás es datos: añadir un efecto
## nuevo a un glifo es una línea en su lista de modificadores (`op: "anade"` sobre `eventos.<nombre>`), nunca código por combinación.
const EVENTOS: PackedStringArray = ["al_nacer", "al_golpear", "al_matar", "al_expirar", "al_rebotar", "al_viajar"]
const ACCIONES: PackedStringArray = ["danar_area", "crear_hijo", "estado_suelo", "sonido", "vfx"]
## `choca_con` es una máscara de bits; 0 = «la de siempre» = mundo + enemigos.
const CHOCA_MUNDO: int = 1
const CHOCA_ENEMIGOS: int = 2
## Límites de HC4 (§2.3): profundidad de hijos y hechizos vivos por lanzamiento.
const MAX_PROFUNDIDAD: int = 2
const MAX_VIVOS: int = 32

## Qué propiedad de la receta (`Sigils.aplicar_v2(...)["props"]`) es cada campo. Cuenta como «propiedad usada» (encarece el hechizo) cuando algún glifo lo toca.
const PROPIEDAD_DE: Dictionary = {"distancia_max": "viaja", "solidez": "solidez", "copias": "copias", "rebotes": "rebotes", "crece": "crece"}

## HC5: lo que el laboratorio deja tocar en vivo. Numéricos: {paso, min, max}; «bool» se alterna; «lista» recorre sus valores. Lo que no está aquí se enseña pero no se toca
## (color, deja, estela, efecto_impacto, eventos: son nombres o listas, no números).
const EDITABLES: Dictionary = {
	"semiejes.x": {"paso": 0.05, "min": 0.05, "max": 6.0}, "semiejes.y": {"paso": 0.05, "min": 0.05, "max": 6.0}, "semiejes.z": {"paso": 0.05, "min": 0.05, "max": 6.0},
	"copias": {"paso": 1.0, "min": 1.0, "max": 9.0}, "crece": {"paso": 0.1, "min": 0.0, "max": 3.0}, "solidez": {"paso": 0.5, "min": 0.0, "max": 5.0},
	"velocidad": {"paso": 1.0, "min": 0.0, "max": 40.0}, "aceleracion": {"paso": 1.0, "min": -20.0, "max": 40.0}, "gravedad": {"paso": 0.1, "min": 0.0, "max": 3.0},
	"distancia_max": {"paso": 0.5, "min": 0.0, "max": 20.0}, "altura_salida": {"paso": 0.1, "min": 0.0, "max": 4.0}, "persiste": {"paso": 0.5, "min": 0.0, "max": 30.0}, "rebotes": {"paso": 1.0, "min": 0.0, "max": 6.0},
	"retorna": {"tipo": "bool"}, "en_punto": {"tipo": "bool"}, "busca": {"paso": 0.25, "min": 0.0, "max": 4.0},
	"dano": {"paso": 5.0, "min": 0.0, "max": 300.0}, "empuje": {"paso": 0.1, "min": 0.0, "max": 1.0}, "fuerza_golpe": {"paso": 100.0, "min": 0.0, "max": 3000.0},
	"perfora": {"paso": 1.0, "min": 0.0, "max": 5.0}, "radio_explosion": {"paso": 0.25, "min": 0.0, "max": 5.0}, "golpea_lanzador": {"tipo": "bool"},
	"quema": {"paso": 0.5, "min": 0.0, "max": 20.0}, "moja": {"paso": 0.5, "min": 0.0, "max": 20.0}, "congela": {"paso": 0.5, "min": 0.0, "max": 20.0},
	"congela_mojado": {"paso": 0.5, "min": 0.0, "max": 20.0}, "aturde": {"paso": 0.1, "min": 0.0, "max": 10.0}, "ralentiza": {"paso": 0.5, "min": 0.0, "max": 20.0},
	"ralentiza_fuerza": {"paso": 0.05, "min": 0.0, "max": 1.0}, "interrumpe": {"paso": 0.1, "min": 0.0, "max": 5.0}, "veneno": {"paso": 0.5, "min": 0.0, "max": 20.0},
	"veneno_dps": {"paso": 0.5, "min": 0.0, "max": 30.0},
	"estado_materia": {"tipo": "lista", "valores": ["solido", "liquido", "plasma", "energia", "gas", "campo"]}, "pisable": {"tipo": "bool"},
	"choca_con": {"paso": 1.0, "min": 0.0, "max": 3.0},
}
## Los derivados que enseña la tabla (no se tocan: salen de lo demás).
const DERIVADOS: PackedStringArray = ["forma", "cast_point", "niveles", "viaja", "coste", "coste_tinta", "recarga"]

# --- Forma y volumen ---
## Casillas de semieje (X ancho, Y alto, Z fondo). Se guardan como tres `float` (64 bits) y no como un Vector3 (32 bits): así los números son EXACTAMENTE los de
## `Sigils.aplicar_v2` y el rasterizado de casillas no cambia ni en los casos límite. `semiejes` es la vista en Vector3 (solo lectura; se escribe con «semiejes.x»).
var semieje_x: float = Sigils.RADIO_BASE_V2
var semieje_y: float = Sigils.RADIO_BASE_V2
var semieje_z: float = Sigils.RADIO_BASE_V2
var semiejes: Vector3:
	get:
		return Vector3(semieje_x, semieje_y, semieje_z)
var copias: int = 1                    ## n volúmenes repartidos en X
var crece: float = 0.0                 ## escala por segundo al nacer
var solidez: float = 0.0               ## 0 = no bloquea; con barrera, 1·1,5^n (diverge del doc, que dice 1: hoy «sin barrera» es la ausencia de la propiedad)

# --- Movimiento ---
var velocidad: float = 0.0             ## u/s (0 = la de siempre del lanzador) · HC4
var aceleracion: float = 0.0           ## u/s², negativa = frena · HC4
var gravedad: float = 0.0              ## caída: 1 = como un objeto · HC4
var distancia_max: float = 0.0         ## casillas que recorre (0 = quieto; hoy `viaja`)
var persiste: float = 0.0              ## segundos que vive lo creado, YA multiplicado por el factor de calidad del trazo
var altura_salida: float = 0.9         ## u sobre el suelo desde donde sale un PROYECTIL (0,9 = la mano). Los hechizos sin velocidad no la usan: nacen en su casilla · HC4
var rebotes: int = 0                   ## cambios de dirección al chocar
var retorna: bool = false              ## vuelve al lanzador al acabar · HC4
var en_punto: bool = false            ## nace donde apunta el cursor (dentro del anillo de alcance) y no en el lanzador · 18/10 diseño de Pablo («cast on point»)
var busca: float = 0.0                 ## fuerza de giro hacia un objetivo (0 = recto) · HC4

# --- Daño y combate ---
var dano: float = 0.0                  ## daño base (hoy RuneData.damage × potencia 1; el daño no depende de la calidad)
var empuje: float = 0.0                ## 0..1: cuánto empuja un campo de gas (la zona) y qué fracción de la fuerza máxima es
var fuerza_golpe: float = 400.0        ## fuerza con que empuja a un enemigo al golpearlo, ANTES de MULT_EMPUJE y del suelo de Combate3D (0 = no empuja: el viento lo empuja el Lanzador). 400 = la de siempre para lo que no tiene valor propio
var perfora: int = 0                   ## enemigos que atraviesa antes de pararse · HC4
var radio_explosion: float = 0.0       ## casillas de daño en área al golpear · HC4 (con un evento)
var golpea_lanzador: bool = false      ## puede herir a quien lo lanzó · HC4

# --- Estados que deja al golpear (segundos; 0 = no lo aplica) ---
var quema: float = 0.0
var moja: float = 0.0
var congela: float = 0.0
var congela_mojado: float = 0.0        ## lo que congela si el enemigo ya estaba mojado
var aturde: float = 0.0
var ralentiza: float = 0.0             ## segundos
var ralentiza_fuerza: float = 0.0      ## 0..1: cuánto frena (hoy Combate3D multiplica por 0,6 = 0,4 de fuerza)
var interrumpe: float = 0.0
var veneno: float = 0.0                ## segundos que dura el veneno que deja al golpear (0 = no envenena) · HC4
var veneno_dps: float = 3.0            ## daño por segundo mientras dura (solo cuenta si `veneno` > 0)
var deja: String = ""                  ## estado de suelo que deja ("quemado", "mojado", "helado")

# --- Materia ---
var estado_materia: String = "solido"  ## "solido" | "liquido" | "plasma" | "energia" | "gas" | "campo"
var pisable: bool = false

# --- Choque y aspecto ---
var choca_con: int = 0                 ## máscara de lo que lo para (0 = la de siempre: mundo + enemigos) · HC4
var color: Color = Color.WHITE
var estela: String = ""                ## nombre de VFX, lo resuelve el Pipeline · HC4
var efecto_impacto: String = ""        ## nombre de VFX que suena al golpear (lo resuelve el Pipeline: llega por la señal `vfx_hechizo` del lanzador)
## Eventos: nombre (EVENTOS) -> lista de acciones [{accion: <ACCIONES>, …parámetros}]. Vacío = no hace nada. Se rellena con modificadores «anade».
var eventos: Dictionary = {}

# --- Identidad y entrada (no son modificables) ---
var elemento: String = ""              ## "fuego", "agua", "hielo", "rayo", "tierra", "viento", "" (el tiempo no tiene nombre en Objetos)
var etiquetas: Array[String] = []
var calidad: float = 1.0
var fuente: RuneData = null            ## el RuneData del elemento con que se construyó (HC2: aún lo piden Combate3D y los reactivos; HC3 lo sustituye por los campos)
var glifos: Dictionary = {}            ## los contadores con que se construyó (nombre V2 -> n)
var ignorados: PackedStringArray = PackedStringArray()   ## glifos que la tabla no conoce
var profundidad: int = 0               ## 0 = el hechizo lanzado; un hijo creado por `crear_hijo` vale la del padre + 1 (tope MAX_PROFUNDIDAD)

# --- Derivados (se calculan al final de `construir`) ---
var _glifos_x: float = 0.0             ## lo que dieron los glifos antes de los mínimos (el coste cuenta ESTO: la barrera no encarece)
var _glifos_y: float = 0.0
var _glifos_z: float = 0.0
var semiejes_glifos: Vector3:
	get:
		return Vector3(_glifos_x, _glifos_y, _glifos_z)
var forma: String = "x_mano"           ## nombre derivado: x_mano | alto | abajo
var cast_point: String = ""            ## id de la variación de CastPoints para esa forma
var niveles: int = 1
var viaja: bool = false
var coste: float = 1.0                 ## relativo: la esfera base sin propiedades vale 1
var coste_tinta: float = 0.0
var recarga: float = 0.0

## De dónde viene el valor de cada campo (HC5): "defecto" · "elemento" · "glifo:<nombre>" · "calidad". Los componentes de semiejes llevan «semiejes.x».
var origen: Dictionary = {}
var _tocados: Dictionary = {}          ## campos que algún glifo ha tocado (para `desde` y para contar propiedades)


## Construye el hechizo de un elemento con unos glifos. `glifos` = nombre V2 -> cuántas veces (los nombres con alias, como «levitacion», se resuelven).
static func construir(elemento_rune: RuneData, contadores: Dictionary, calidad_trazo: float = 1.0) -> Hechizo:
	var h := Hechizo.new()
	h.calidad = calidad_trazo
	h.fuente = elemento_rune
	# 2. el elemento
	if elemento_rune != null:
		h.elemento = Objetos.elemento_de(elemento_rune)
		h.color = elemento_rune.color
		h.etiquetas = elemento_rune.tags.duplicate()
		h._aplicar(_modificadores_de_elemento(elemento_rune), "elemento", false)
	# 3. y 4. los glifos
	var lista: Array = []
	for nombre in contadores:
		var n: int = maxi(int(contadores[nombre]), 0)
		var v2: String = Sigils.glifo_v2(String(nombre))
		if n == 0:
			continue
		if not Sigils.GLIFOS.has(v2):
			h.ignorados.append(String(nombre))
			continue
		h.glifos[v2] = int(h.glifos.get(v2, 0)) + n
	for nombre in Sigils.GLIFOS:             # en el orden de la tabla, no en el de dibujo: la receta es un multiconjunto
		if not h.glifos.has(nombre):
			continue
		for m in (Sigils.GLIFOS[nombre]["modificadores"] as Array):
			var mod: Dictionary = (m as Dictionary).duplicate()
			mod["n"] = int(h.glifos[nombre])
			mod["de"] = "glifo:%s" % nombre
			lista.append(mod)
	h._aplicar(lista, "glifo", true)
	# la calidad del trazo solo alarga lo que dura
	if h.persiste > 0.0:
		h.persiste *= Sigils.quality_factor(h.calidad)
		h.origen["persiste"] = "calidad"
	h._derivar()
	return h


## Los campos de RuneData de hoy, traducidos a modificadores «fija», más los `modificadores` propios del .tres (HC3: ahí viven las duraciones de estado, la fuerza del golpe y el daño extra de la tierra).
static func _modificadores_de_elemento(r: RuneData) -> Array:
	var lista: Array = []
	for par in [["dano", r.damage], ["persiste", r.persiste], ["empuje", r.empuje], ["pisable", r.pisable], ["deja", r.deja], ["estado_materia", r.estado]]:
		lista.append({"campo": par[0], "op": "fija", "valor": par[1], "n": 1})
	for campo in r.modificadores:
		var m: Dictionary = (r.modificadores[campo] as Dictionary).duplicate()
		m["campo"] = String(campo)
		m["n"] = 1
		lista.append(m)
	return lista


## Aplica una lista de modificadores: fija y sumas, luego multiplicaciones, luego los topes de cada campo y al final los mínimos.
func _aplicar(lista: Array, etiqueta: String, marca_tocados: bool) -> void:
	var topes: Dictionary = {}
	for rango in ["fija", "suma", "multiplica"]:
		for m in lista:
			if String(m["op"]) != rango:
				continue
			var campo: String = String(m["campo"])
			var v: float = 0.0
			var n: int = int(m.get("n", 1))
			# `salta`: los k primeros glifos no cuentan (la barrera: el 1.º da «en_punto», cada glifo SUCESIVO suma +1 s de persistencia)
			n = maxi(n - int(m.get("salta", 0)), 0)
			if n == 0 and rango != "fija":
				continue                                # sin glifos que cuenten no se toca el campo (ni «desde», ni «tocado», ni el origen)
			if rango == "fija":
				_escribir(campo, _valor_de(m["valor"]))
			else:
				if m.has("desde") and not _tocados.has(campo):
					_escribir(campo, float(m["desde"]))
				v = float(_leer(campo))
				v = v + float(m["valor"]) * float(n) if rango == "suma" else v * pow(float(m["valor"]), float(n))
				_escribir(campo, v)
			if marca_tocados:
				_tocados[campo] = true
			origen[campo] = String(m.get("de", etiqueta))
			if m.has("tope"):
				topes[campo] = minf(float(topes.get(campo, INF)), float(m["tope"]))
	for m in lista:                                  # los eventos se añaden al final, en el orden de la lista (no tienen orden entre sumas y multiplicaciones)
		if String(m["op"]) == "anade":
			var nombre_ev: String = String(m["campo"]).trim_prefix("eventos.")
			var acciones: Array = eventos.get(nombre_ev, []) as Array
			for _k in range(int(m.get("n", 1))):
				acciones.append((m["valor"] as Dictionary).duplicate(true))
			eventos[nombre_ev] = acciones
			origen["eventos"] = String(m.get("de", etiqueta))
			if marca_tocados:
				_tocados["eventos"] = true
	for campo in topes:
		if _leer(String(campo)) > float(topes[campo]):
			_escribir(String(campo), float(topes[campo]))
	_glifos_x = semieje_x
	_glifos_y = semieje_y
	_glifos_z = semieje_z
	for m in lista:
		if String(m["op"]) == "minimo":
			var campo: String = String(m["campo"])
			_escribir(campo, maxf(float(_leer(campo)), float(_valor_de(m["valor"]))))
			origen[campo] = String(m.get("de", etiqueta))


## Un valor simbólico («@radio_barrera») se resuelve aquí; cualquier otro se devuelve tal cual.
static func _valor_de(v: Variant) -> Variant:
	if v is String and String(v) == "@radio_barrera":
		return Sigils.radio_barrera_casillas()
	return v


## Lee un campo; «semiejes.x» lee un componente.
func _leer(campo: String) -> Variant:
	if campo.begins_with("semiejes."):
		return get("semieje_" + campo.substr(9))
	return get(campo)


## Escribe un campo respetando su tipo (int, float, bool, String); «semiejes.x» escribe un componente.
func _escribir(campo: String, valor: Variant) -> void:
	if campo.begins_with("semiejes."):
		set("semieje_" + campo.substr(9), float(valor))
		return
	var actual: Variant = get(campo)
	if actual is int:
		set(campo, int(roundf(float(valor))))
	elif actual is float:
		set(campo, float(valor))
	elif actual is bool:
		set(campo, bool(valor))
	else:
		set(campo, valor)


## 5. Lo que sale de lo anterior.
func _derivar() -> void:
	viaja = distancia_max > 0.0
	forma = nombre_derivado(semieje_x, semieje_y, semieje_z, viaja)
	niveles = maxi(1, roundi(2.0 * semieje_y))
	cast_point = CastPoints.variacion_de(forma)
	var base: float = 4.0 / 3.0 * PI * pow(Sigils.RADIO_BASE_V2, 3.0)
	var vol: float = 4.0 / 3.0 * PI * _glifos_x * _glifos_y * _glifos_z
	coste = vol / base * (1.0 + Sigils.COSTE_PROP_V2 * float(propiedades_usadas().size()))
	coste_tinta = Tinta.coste_receta(coste)
	recarga = Sigils.cooldown_v2(glifos)
	for campo in ["forma", "cast_point", "niveles", "viaja", "coste", "coste_tinta", "recarga"]:
		origen[campo] = "derivado"


## Eje en el que más se estira: "x" | "y" | "z", o "esfera" si no se ha estirado ninguno. (Empate: gana Z, luego Y, luego X.)
static func eje_dominante(sx: float, sy: float, sz: float) -> String:
	var v: Dictionary = {"x": sx, "y": sy, "z": sz}
	var mayor: String = "z"
	for e in ["y", "x"]:
		if float(v[e]) > float(v[mayor]) + EPS:
			mayor = e
	return mayor if float(v[mayor]) > Sigils.RADIO_BASE_V2 + EPS else "esfera"


## Nombre para la animación de lanzar, el cast point y el VFX: lo que viaja o se estira hacia delante sale con la mano al frente («x_mano»), lo que domina en altura
## se eleva («alto») y lo plano y quieto va al suelo («abajo»). Es la misma regla que `Lanzador3D.GeometriaV2.nombre_derivado`.
static func nombre_derivado(sx: float, sy: float, sz: float, viaja_: bool) -> String:
	var dom: String = eje_dominante(sx, sy, sz)
	if viaja_ or (dom == "z" and sz > sx + EPS and sz > sy + EPS):
		return "x_mano"
	if dom == "y":
		return "alto"
	if dom != "esfera" and sy <= Sigils.RADIO_BASE_V2 + EPS:
		return "abajo"
	return "x_mano"


## Las propiedades que algún glifo ha tocado, en el formato de `Sigils.aplicar_v2(...)["props"]`: {param: valor}.
func propiedades_usadas() -> Dictionary:
	var salida: Dictionary = {}
	for campo in PROPIEDAD_DE:
		if _tocados.has(campo):
			salida[PROPIEDAD_DE[campo]] = float(_leer(String(campo)))
	return salida


## La geometría en el formato de siempre (el de `Lanzador3D.GeometriaV2.evaluar`): {x, y, z, props, x_glifos, z_glifos, nombre, viaja, y_tope, valida, aviso}.
## Es lo que leen `GeometriaV2.celdas`, el VFX por estado y el laboratorio mientras no pasen a leer el Hechizo directamente.
func geo() -> Dictionary:
	return {"x": semieje_x, "y": semieje_y, "z": semieje_z, "props": propiedades_usadas(), "x_glifos": _glifos_x, "z_glifos": _glifos_z,
		"nombre": forma, "viaja": viaja, "y_tope": niveles - 1, "valida": true, "aviso": ""}


## Una copia independiente (los hijos de `crear_hijo` parten de ella y le cambian campos). No copia el RuneData (se comparte) ni toca los derivados: se copian tal cual.
func copiar() -> Hechizo:
	var c := Hechizo.new()
	for p in get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var nombre: String = String(p["name"])
		if nombre == "semiejes" or nombre == "semiejes_glifos":      # vistas de solo lectura
			continue
		var v: Variant = get(nombre)
		if v is Dictionary or v is Array:
			v = v.duplicate(true)
		c.set(nombre, v)
	return c


## Cambia campos de golpe (los `cambios` de `crear_hijo` y las sobrescrituras del laboratorio: {campo: valor}); «semiejes.x» vale, y también «eventos» (diccionario entero).
## Un campo que es una «propiedad» de la receta (distancia_max, copias, rebotes, crece, solidez) cuenta como usado, igual que si lo hubiera dado un glifo, y los derivados
## (forma, viaja, coste…) se recalculan. El coste sigue siendo el de los glifos dibujados: tocar un número en el lab no encarece el hechizo. Devuelve self.
func con(cambios: Dictionary) -> Hechizo:
	for campo in cambios:
		var v: Variant = cambios[campo]
		if String(campo) == "eventos":
			eventos = (v as Dictionary).duplicate(true)
		else:
			_escribir(String(campo), v)
		if PROPIEDAD_DE.has(String(campo)):
			_tocados[String(campo)] = true
		origen[String(campo)] = "lab"
	_derivar()
	return self


## HC5: la tabla completa del hechizo construido, una fila por campo: {campo, grupo, valor, defecto, origen, tipo_origen, difiere, editable}.
## `origen` = de dónde viene el valor («defecto», «elemento», «glifo:<nombre>», «calidad», «lab» si lo tocó el laboratorio, «derivado»); `tipo_origen` es la parte antes de los «:».
## `semiejes` sale en sus tres componentes (semiejes.x/y/z) y `eventos` en una sola fila resumida. Después van los derivados.
func tabla() -> Array:
	var filas: Array = []
	for par in CAMPOS:
		var campo: String = String(par[0])
		if campo == "semiejes":
			for eje in ["x", "y", "z"]:
				filas.append(_fila("semiejes." + eje, String(par[1])))
		else:
			filas.append(_fila(campo, String(par[1])))
	for campo in DERIVADOS:
		filas.append({"campo": campo, "grupo": "derivado", "valor": get(campo), "defecto": defecto(campo), "origen": "derivado", "tipo_origen": "derivado", "difiere": false, "editable": false})
	return filas


func _fila(campo: String, grupo: String) -> Dictionary:
	var valor: Variant = _leer(campo)
	var def: Variant = defecto(campo)
	var o: String = String(origen.get(campo, "defecto"))
	var distinto: bool
	if valor is float and def is float:
		distinto = not is_equal_approx(float(valor), float(def))
	else:
		distinto = valor != def
	if campo == "eventos":
		valor = "%d acciones" % _acciones_totales() if distinto else "ninguno"
		def = "ninguno"
	return {"campo": campo, "grupo": grupo, "valor": valor, "defecto": def, "origen": o, "tipo_origen": o.get_slice(":", 0), "difiere": distinto, "editable": EDITABLES.has(campo)}


func _acciones_totales() -> int:
	var n: int = 0
	for e in eventos:
		n += (eventos[e] as Array).size()
	return n


## Las sobrescrituras del laboratorio como modificadores LISTOS PARA PEGAR: una línea por campo, en el formato de `Sigils.GLIFOS` (lista de {campo, op, valor}) y en el de
## `RuneData.modificadores` de un .tres ({campo: {op, valor}}). Siempre «fija»: es el valor que se probó, tal cual.
static func texto_modificadores(cambios: Dictionary) -> String:
	if cambios.is_empty():
		return "# (sin cambios)"
	var campos: Array = cambios.keys()
	campos.sort()
	var glifo: PackedStringArray = PackedStringArray()
	var tres: PackedStringArray = PackedStringArray()
	for campo in campos:
		var v: Variant = cambios[campo]
		var txt: String = var_to_str(v) if not (v is float) else str(snappedf(float(v), 0.0001))
		glifo.append("\t\t{\"campo\": \"%s\", \"op\": \"fija\", \"valor\": %s}," % [campo, txt])
		tres.append("\"%s\": {\"op\": \"fija\", \"valor\": %s}" % [campo, txt])
	return "# En Sigils.GLIFOS[<glifo>][\"modificadores\"]:\n[\n%s\n]\n# En un *_rune.tres (modificadores = {...}):\nmodificadores = {%s}" % ["\n".join(glifo), ", ".join(tres)]


## Todos los campos (y los derivados) en un diccionario seguro para PlayLog/JSON: Vector3 → [x, y, z], Color → html.
func a_diccionario() -> Dictionary:
	var d: Dictionary = {}
	for par in CAMPOS:
		d[par[0]] = _plano(get(String(par[0])))
	d["elemento"] = elemento
	d["calidad"] = calidad
	for campo in ["forma", "cast_point", "niveles", "viaja", "coste", "coste_tinta", "recarga"]:
		d[campo] = get(campo)
	d["semiejes_glifos"] = _plano(semiejes_glifos)
	d["glifos"] = glifos.duplicate()
	d["origen"] = origen.duplicate()
	return d


static func _plano(v: Variant) -> Variant:
	if v is Vector3:
		return [(v as Vector3).x, (v as Vector3).y, (v as Vector3).z]
	if v is Color:
		return (v as Color).to_html()
	return v


## El valor por defecto de un campo (el del `var`): se lee de un Hechizo recién creado, así no hay dos copias.
static func defecto(campo: String) -> Variant:
	return Hechizo.new()._leer(campo)


## Texto para depurar: los campos que difieren del defecto, con de dónde vienen, y los derivados.
func describir() -> String:
	var lineas: PackedStringArray = PackedStringArray()
	lineas.append("Hechizo %s %s (calidad %.2f) · glifos %s" % [elemento if elemento != "" else "sin elemento", forma, calidad, str(glifos)])
	for par in CAMPOS:
		var campo: String = String(par[0])
		var v: Variant = get(campo)
		if v != defecto(campo):
			lineas.append("  %s = %s  (%s)" % [campo, str(v), String(origen.get(campo, origen.get(campo + ".x", "defecto")))])
	lineas.append("  coste %.2f (%.1f tinta) · recarga %.2f s · niveles %d · cast point '%s'" % [coste, coste_tinta, recarga, niveles, cast_point])
	return "\n".join(lineas)
