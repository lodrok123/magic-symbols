class_name FichasGlifo
extends RefCounted

## FICHAS DE GLIFO (23/11, sesión HECHIZOS; PLAN_HECHIZOS §4 H5, H6 y H8). Los textos que enseña la lámina de «nueva runa» (`LaminaGlifo`): el verbo y UNA frase corta, sin combinaciones
## ni otras runas (lo que la runa hace de verdad se aprende usándola: ver `PistaGlifo`). `LibroRojo` lee de aquí el verbo, la frase y `bases` para el catálogo.
## Solo estáticos, sin nodo.
##
## OJO: los TEXTOS son PROVISIONALES; los decide Pablo. Lo que no cambia al reescribirlos es la estructura (verbo / frase / bases) y que cada id jugable tenga ficha
## (`prueba_fichas_glifo.gd`).
##   verbo   el nombre-verbo que ve la jugadora en las notas del libro y en la lámina (en el color de la runa)
##   frase   UNA frase corta: lo que hace, sin nombrar otras runas ni bases
##   bases   «vale con…»: sobre qué se apoya. Lo lee el cuaderno del libro rojo; la lámina NO la enseña
## Ids: los seis elementos (SELLOS) y los glifos que la jugadora puede tener (los de los kits de `Lanzador3D`, más ᛉ permanencia y ᚱ raido, que llegan por cofre).
## `levitacion` (ᛏ) vale SOLO como `altura` (Sigils.ALIAS_V2): NO tiene ficha propia (24/11, Pablo); `ficha`, `verbo`, `frase` y `bases` la resuelven como `altura`.
##   titulo  (opcional) el título de la lámina cuando no es el `nombre_runa` de la BIBLIA: hielo se dibuja ᚾ (`TrazosRectos`), así que se llama Naudiz (24/11, Pablo)

const FICHAS: Dictionary = {
	"fuego": {"verbo": "Fuego", "frase": "Quema y prende lo que arde.", "bases": "cualquier glifo"},
	"agua": {"verbo": "Agua", "frase": "Moja, apaga y empuja.", "bases": "cualquier glifo"},
	"tierra": {"verbo": "Tierra", "frase": "Construye muros y modifica la tierra.", "bases": "cualquier glifo"},
	"viento": {"verbo": "Viento", "frase": "Empuja y desvía lo que toca.", "bases": "cualquier glifo"},
	"rayo": {"verbo": "Rayo", "frase": "Descarga y salta por lo mojado.", "bases": "cualquier glifo"},
	"hielo": {"titulo": "Naudiz", "verbo": "Hielo", "frase": "Congela y hace suelo que resbala.", "bases": "cualquier glifo"},
	"flecha": {"verbo": "Viaja", "frase": "Lanza el hechizo hacia donde apuntas.", "bases": "bola, barrera (muro que avanza)"},
	"linea": {"verbo": "Línea", "frase": "Lo alarga en línea recta.", "bases": "bola (chorro), barrera (muro)"},
	"altura": {"verbo": "Altura", "frase": "Lo hace más alto.", "bases": "bloque, barrera"},
	"pulso": {"verbo": "Crecer", "frase": "Crece mientras vive.", "bases": "bola, barrera"},
	"permanencia": {"verbo": "Dura", "frase": "Dura más tiempo.", "bases": "barrera, bloque, zona"},
	"rebote": {"verbo": "Rebotes", "frase": "Rebota en las paredes.", "bases": "flecha"},
	"buscar": {"verbo": "Busca", "frase": "Persigue al enemigo más cercano.", "bases": "flecha"},
	"repeticion": {"verbo": "Copias", "frase": "Sale más de uno a la vez.", "bases": "flecha, bola, barrera"},
	"retorno": {"verbo": "Vuelve", "frase": "Vuelve hacia ti al acabar.", "bases": "flecha"},
	"barrera": {"verbo": "Solidez", "frase": "Lo vuelve sólido: para lo que te lanzan.", "bases": "bola, flecha, haz"},
	"raido": {"verbo": "Pulso", "frase": "Suelta una onda de su elemento.", "bases": "flecha (al chocar), barrera (sin parar)"},
	"perforar": {"verbo": "Atraviesa", "frase": "Sigue de largo tras el primer golpe.", "bases": "flecha, haz"},
	"suelo": {"verbo": "Planta", "frase": "Se planta en el suelo que apuntas.", "bases": "cualquier elemento"},
	"retardo": {"verbo": "Carga", "frase": "Espera y sale más fuerte.", "bases": "cualquier forma"},
}


static func ficha(id: String) -> Dictionary:
	return (FICHAS.get(_clave(id), {}) as Dictionary).duplicate()


static func verbo(id: String) -> String:
	return String((FICHAS.get(_clave(id), {}) as Dictionary).get("verbo", id))


static func frase(id: String) -> String:
	return String((FICHAS.get(_clave(id), {}) as Dictionary).get("frase", ""))


static func bases(id: String) -> String:
	return String((FICHAS.get(_clave(id), {}) as Dictionary).get("bases", ""))


## El título propio de la ficha («Naudiz» para hielo), o "" si se usa el `nombre_runa` de la BIBLIA.
static func titulo(id: String) -> String:
	return String((FICHAS.get(_clave(id), {}) as Dictionary).get("titulo", ""))


## `levitacion` es `altura` (Sigils.ALIAS_V2): comparte su ficha.
static func _clave(id: String) -> String:
	return "altura" if id == "levitacion" else id


static func es_sello(id: String) -> bool:
	return GestureLibrary.ELEMENTS.has(id)


## "sello" (elemento), "potencia" (el glifo cuenta para el daño: `cuenta_dano` de Sigils) o "forma" (no cuenta). Lee el dato real de `Sigils`. La lámina ya no lo enseña: da el COLOR de la runa.
## `linea` no está en `Sigils.GLIFOS` (sus filas son linea_x y linea_z, las dos de geometría): se mira linea_x; `levitacion` se resuelve por su alias (altura).
static func familia(id: String) -> String:
	if es_sello(id):
		return "sello"
	var clave: String = "linea_x" if id == "linea" else Sigils.glifo_v2(id)
	return "potencia" if Sigils.cuenta_dano(clave) else "forma"


## Todos los ids con ficha: sellos, luego forma, luego potencia (dentro de cada grupo, el orden de FICHAS).
static func ids() -> Array:
	var salida: Array = []
	for fam in ["sello", "forma", "potencia"]:
		for id in FICHAS:
			if familia(String(id)) == fam:
				salida.append(String(id))
	return salida
