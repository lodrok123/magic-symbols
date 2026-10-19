class_name RecetasLab
extends RefCounted
## Recetas con nombre del laboratorio de hechizos (LabHechizos3D): {nombre, glifos EN ORDEN, elemento, cambios de lanzamiento}.
##
## Para qué: al diseñar un glifo hay que volver a lanzar siempre las mismas pruebas (la bola, el muro, la flecha triple…) sin reconstruirlas a mano cada vez.
## Datos puros (sin nodos) para poder probarlos sin ventana. Viven en `user://lab_recetas.json`, NO en res://: son del diseñador, no del juego.
## Los `glifos` guardan el ORDEN en que se pusieron (para que Pablo diseñe secuencias, aunque hoy el resultado dependa solo del multiconjunto).

const RUTA: String = "user://lab_recetas.json"


static func nueva(nombre: String, glifos: Array, elemento: String, cambios: Dictionary = {}) -> Dictionary:
	return {"nombre": nombre, "glifos": glifos.duplicate(), "elemento": elemento, "cambios": cambios.duplicate(true)}


## Las seis de partida (encargo del lab, 19/10). Ctrl+1…6 las lanza. Cada una usa solo glifos que ya existen en `Sigils.GLIFOS`.
static func por_defecto() -> Array:
	return [
		nueva("bola de fuego", ["flecha", "linea_x", "linea_z", "altura"], "fire"),
		nueva("flecha triple de hielo", ["flecha", "repeticion", "repeticion"], "ice"),
		nueva("muro de tierra", ["barrera", "linea_x", "linea_x", "linea_x", "altura", "altura"], "earth"),
		nueva("barrera de agua", ["barrera", "linea_x", "linea_x", "permanencia"], "water"),
		nueva("pilar de rayo", ["altura", "altura", "altura", "permanencia", "permanencia"], "lightning"),
		nueva("onda de viento", ["flecha", "pulso", "pulso", "linea_z", "linea_z"], "wind"),
	]


## Lee el archivo; si no existe (o está roto) devuelve las de partida. Nunca devuelve entradas mal formadas.
static func cargar(ruta: String = RUTA) -> Array:
	if not FileAccess.file_exists(ruta):
		return por_defecto()
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return por_defecto()
	var j: Variant = JSON.parse_string(f.get_as_text())
	if not (j is Dictionary) or not ((j as Dictionary).get("recetas") is Array):
		return por_defecto()
	var lista: Array = []
	for r in ((j as Dictionary)["recetas"] as Array):
		if r is Dictionary and (r as Dictionary).has("nombre") and (r as Dictionary).get("glifos") is Array and (r as Dictionary).has("elemento"):
			lista.append(nueva(String(r["nombre"]), r["glifos"] as Array, String(r["elemento"]), (r.get("cambios", {}) as Dictionary) if r.get("cambios", {}) is Dictionary else {}))
	return lista if not lista.is_empty() else por_defecto()


static func guardar(lista: Array, ruta: String = RUTA) -> bool:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"recetas": lista}, "\t"))
	return true


## «Receta N» con el primer N libre.
static func nombre_libre(lista: Array) -> String:
	var usados: Dictionary = {}
	for r in lista:
		usados[String((r as Dictionary)["nombre"])] = true
	var n: int = 1
	while usados.has("Receta %d" % n):
		n += 1
	return "Receta %d" % n
