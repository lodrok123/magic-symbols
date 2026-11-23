extends SceneTree
## Clasificación de recetas reales, ausencia de física/mutación y ciclo de vida.
const PREVISION = preload("res://magia/prevision_casteo_3d.gd")
class LanzadorFalso:
	extends Node
	signal conjuro_fase(fase: String, elemento: String, posicion: Vector3)
	signal modo_cambiado(activo: bool)
	var conjurando: bool = false
	var punto_prevision := Vector3.ZERO
	func posicion_prevision_casteo() -> Vector3:
		return punto_prevision
class JugadoraFalsa:
	extends Node3D
	var muerto: bool = false
var fallos: int = 0
var comprobaciones: int = 0

func ok(c: bool, texto: String) -> void:
	comprobaciones += 1
	if not c:
		fallos += 1
		print("FALLO: ", texto)

func receta(glifos: Dictionary, elemento: String = "fire", orden: Array = []) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % elemento), glifos, 1.0, false, orden)

func _initialize() -> void:
	await process_frame
	var casos: Array = [
		[{"barrera": 1}, "proteccion"],
		[{"flecha": 1}, "proyectil"],
		[{"barrera": 1, "flecha": 1}, "volumen_movil"],
		[{"linea_x": 1}, "haz"],
		[{"suelo": 1, "flecha": 1}, "suelo"],
		[{"retorno": 1, "repeticion": 1}, "orbita"],
		[{"posicion": 1, "barrera": 1}, "colocado"],
		[{"permanencia": 1}, "area"],
	]
	for c in casos:
		ok(PREVISION.perfil(receta(c[0])) == c[1], "perfil de %s = %s" % [c[0], c[1]])
	ok(PREVISION.perfil(null) == "", "receta nula no anuncia función")
	var recorrido: Dictionary = {"caminos": [PackedVector3Array([Vector3.ZERO, Vector3.RIGHT])], "volumenes": [{"volumen": {"celdas": [Vector2i.ZERO, Vector2i.RIGHT]}}]}
	var original: Dictionary = recorrido.duplicate(true)
	var solo_dibujo: Dictionary = PREVISION.recorrido_visual(receta({"barrera": 1}), recorrido, Vector3.ZERO)
	ok((solo_dibujo["volumenes"] as Array).is_empty() and solo_dibujo["caminos"] == recorrido["caminos"], "la cúpula de preparación sustituye al fantasma relleno sin quitar el camino")
	var movil: Dictionary = PREVISION.recorrido_visual(receta({"barrera": 1, "flecha": 1}), recorrido, Vector3.ZERO)
	ok(movil["volumenes"][0]["volumen"]["celdas"] == [Vector2i.RIGHT], "el volumen móvil no deja una falsa cúpula sobre Mid")
	ok(recorrido == original, "filtrar el dibujo no muta la simulación original")
	# Cada glifo actual y cada pareja se construyen desde la tabla vigente.
	var cantidad: int = 0
	for el in ["fire", "water", "earth", "ice", "lightning", "wind"]:
		for a in Sigils.GLIFOS:
			for b in Sigils.GLIFOS:
				var cont: Dictionary = {a: 1}
				cont[b] = int(cont.get(b, 0)) + 1
				var h: Hechizo = receta(cont, el, [a, b])
				var antes: Dictionary = h.a_diccionario()
				var p: String = PREVISION.perfil(h)
				ok(p != "" and antes == h.a_diccionario(), "clasificación pura %s/%s/%s" % [el, a, b])
				cantidad += 1
	print("Recetas comprobadas: ", cantidad)
	var padre := Node3D.new()
	padre.position = Vector3(7, 0, 3)
	root.add_child(padre)
	var l := LanzadorFalso.new()
	padre.add_child(l)
	var j := JugadoraFalsa.new()
	padre.add_child(j)
	var v = PREVISION.new()
	l.add_child(v)
	var h: Hechizo = receta({"barrera": 1})
	var antes: Dictionary = h.a_diccionario()
	for i in range(3):
		v.mostrar(h, j.global_position, Vector3.RIGHT, j.global_position, j.global_position + Vector3.UP, true, l, j)
	ok(v.visible and v.tipo == "proteccion", "protección visible durante preparación")
	ok(v.get_child_count() == 1 and v.get_child(0) is MeshInstance3D, "solo hay una malla, ninguna colisión ni efecto")
	ok(v._malla.get_surface_count() == 1, "malla reutilizada sin acumular superficies")
	ok(l.get_signal_connection_list("conjuro_fase").size() == 1, "no duplica conexiones al refrescar")
	ok(antes == h.a_diccionario(), "mostrar no modifica la receta ni sus costes")
	l.modo_cambiado.emit(false)
	ok(not v.visible, "cancelar oculta inmediatamente")
	l.conjurando = true
	v.mostrar(h, Vector3.ZERO, Vector3.RIGHT, j.global_position, Vector3.UP, false, l, j, true)
	l.conjuro_fase.emit("forma", "fuego", Vector3(1, 2, 3))
	ok(v._mano == Vector3(1, 2, 3), "sigue el cast point en la fase forma")
	l.punto_prevision = Vector3(2, 3, 4)
	await process_frame
	await process_frame
	ok(v._mano == l.punto_prevision, "durante el clip sigue el cast point en cada fotograma")
	l.conjuro_fase.emit("disparo", "fuego", Vector3.UP)
	ok(not v.visible, "desaparece antes de la manifestación activa")
	v.mostrar(h, Vector3.ZERO, Vector3.RIGHT, j.global_position, Vector3.UP, true, l, j)
	j.muerto = true
	await process_frame
	await process_frame
	ok(not v.visible, "morir retira la previsión")
	j.muerto = false
	l.conjurando = false
	v.mostrar(h, Vector3.ZERO, Vector3.RIGHT, j.global_position, Vector3.UP, true, l, j, true)
	await process_frame
	await process_frame
	ok(not v.visible, "conjuro interrumpido retira la previsión")
	v.queue_free()
	await process_frame
	await process_frame
	ok(l.get_signal_connection_list("conjuro_fase").is_empty(), "liberar desconecta los eventos")
	padre.queue_free()
	await process_frame
	# 22/11 (sesión HECHIZOS) · ajuste 1: «no vale» en gris (el rojo es de los avisos enemigos, G4).
	var nv: Color = PREVISION.COLOR_NO_VALE
	ok(absf(nv.r - nv.g) < 0.05 and absf(nv.g - nv.b) < 0.05, "«no vale» es gris, no rojo")
	# Ajuste 2: la barrera de tierra apuntada a tu casilla es el ANILLO fino de COMBATE (A4); apuntada a otra, un bloque; la de fuego, la cúpula.
	var cas: float = Terreno3D.casilla
	var pies := Vector3(5.5 * cas, 0.0, 5.5 * cas)
	var tierra: Hechizo = receta({"barrera": 1}, "earth")
	var fuego: Hechizo = receta({"barrera": 1})
	ok(PREVISION.es_anillo_tierra(tierra, pies, pies), "tierra + ᛜ en tu casilla = anillo de tierra")
	ok(not PREVISION.es_anillo_tierra(tierra, pies + Vector3.RIGHT * cas, pies), "tierra + ᛜ en otra casilla no es anillo (es un bloque)")
	ok(not PREVISION.es_anillo_tierra(fuego, pies, pies), "fuego + ᛜ no es anillo (es la cúpula)")
	ok(not PREVISION.es_anillo_tierra(receta({"barrera": 1, "flecha": 1}, "earth"), pies, pies), "tierra + ᛜ + ᛇ (viaja) no es anillo")
	var cima_anillo: Vector3 = PREVISION.cima_silueta(tierra, pies, pies)
	ok(is_equal_approx(cima_anillo.y, pies.y + HechizoVivo.ANILLO_ALTO_U), "la cima del anillo está a su alto (%.2f u)" % HechizoVivo.ANILLO_ALTO_U)
	var cima_cupula: Vector3 = PREVISION.cima_silueta(fuego, pies, pies)
	ok(cima_cupula != Vector3.INF and cima_cupula.y > cima_anillo.y, "la cúpula de fuego es más alta que el anillo de tierra")
	ok(PREVISION.cima_silueta(receta({"flecha": 1}), pies, pies) == Vector3.INF, "un proyectil no tiene cima de protección (sin rótulo encima)")
	print("Comprobaciones: %d · TOTAL DE FALLOS: %d" % [comprobaciones, fallos])
	quit(1 if fallos > 0 else 0)
