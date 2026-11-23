class_name Contacto
extends RefCounted

## B2 de docs/PLAN_COMBATE_2026-11-22.md · C19: REACCIÓN AL CONTACTO barrera × proyectil (tabla aprobada por Pablo como punto de partida el 21/11; burbuja decidida el 22/11).
## Dueño: Juego. Solo datos y la resolución de una flecha enemiga; nadie escribe «la barrera de agua para la flecha»: el proyectil tiene un tipo, la barrera un elemento y esta
## tabla dice qué pasa. Hay casos INEFICACES a propósito (el fuego no para el fuego) y tienen que LEERSE (C20): el proyectil la cruza con un golpe sordo y, la primera vez, un rótulo.
##
## Acciones (catálogo cerrado):
##   para     se clava y se para (tierra)                       quema    se quema en ceniza y chispas (fuego)
##   frena    se frena y cae mojada (agua)                      apaga    se apaga y cae (agua contra lo que arde); la barrera se gasta
##   vapor    se anulan en vapor: se pierden los dos            pasa     NO protege: el proyectil sigue (ineficaz)
##   repele   vuelve hacia quien lo tiró (viento, O12)          rebota   rebota de lado, gira y cae; la protección sigue (la burbuja, C10)
##   diluye   pasa pero hace menos daño (veneno en agua)        refleja  la LUZ sale hacia donde mira quien lleva la protección (sin nadie, hacia atrás). Lo resuelve
##                                                                      `RayoLuz.trazar` (sesión de puzles, base de la luz 3b; también la mirada del Basilisco, X3)
## Proyectiles: flecha · flecha_ardiendo · fuego (bola, chorro, lanzallamas) · agua · piedra · veneno · luz (22/11, PLAN_PUZLES §5.1; tabla de partida, pregunta 16 de Pablo).

const TABLA: Dictionary = {
	# barrera →        flecha     flecha_ardiendo   fuego      agua      piedra    veneno
	"fuego":  {"flecha": "quema", "flecha_ardiendo": "pasa", "fuego": "pasa", "agua": "vapor", "piedra": "pasa", "veneno": "quema", "luz": "pasa"},
	"agua":   {"flecha": "frena", "flecha_ardiendo": "apaga", "fuego": "apaga", "agua": "pasa", "piedra": "pasa", "veneno": "diluye", "luz": "refleja"},
	"tierra": {"flecha": "para", "flecha_ardiendo": "para", "fuego": "para", "agua": "para", "piedra": "para", "veneno": "para", "luz": "para"},
	"viento": {"flecha": "repele", "flecha_ardiendo": "repele", "fuego": "pasa", "agua": "repele", "piedra": "pasa", "veneno": "repele", "luz": "pasa"},
	"hielo":  {"luz": "refleja"},                                                           # después de la demo (PLAN_PUZLES §5.1)
}
## C10 (Pablo, 22/11): «rebotan contra viento/agua/tierra, se queman con fuego». La burbuja NO revienta con flechas. El resto, como las barreras.
const TABLA_BURBUJA: Dictionary = {
	"fuego": {"flecha": "quema", "flecha_ardiendo": "pasa"},
	"agua": {"flecha": "rebota", "flecha_ardiendo": "rebota"},
	"tierra": {"flecha": "rebota", "flecha_ardiendo": "rebota"},
	"viento": {"flecha": "rebota", "flecha_ardiendo": "rebota"},
}
## Lo que NO protege a quien está detrás.
const NO_PROTEGE: Array = ["pasa", "diluye"]
## Los rótulos de lo ineficaz (C20 #1): la primera vez de cada caso en la partida.
const ROTULOS_INEFICAZ: Dictionary = {
	"fuego|fuego": "El fuego no para el fuego", "fuego|flecha_ardiendo": "La flecha ya arde: cruza el fuego",
	"fuego|piedra": "El fuego no para la piedra", "agua|piedra": "El agua no para la piedra", "agua|agua": "El agua no para el agua",
	"viento|fuego": "El viento esparce el fuego", "viento|piedra": "El viento no mueve la piedra",
}
const COLOR_INEFICAZ: Color = Color(0.7, 0.7, 0.7)
const T_CAIDA: float = 0.45                  ## s que tarda en caer la flecha frenada o rebotada
const T_CENIZA: float = 0.18                 ## s que tarda en deshacerse la flecha quemada

static var _vistos: Dictionary = {}          ## rótulos ya enseñados («barrera|proyectil» → true)
static var ultimas: Array = []               ## [barrera, proyectil, accion] de las últimas resoluciones (para las pruebas; se vacía sola a las 32)


## Qué pasa cuando `proyectil` toca una barrera de `elemento` (`burbuja` = la burbuja). Sin fila: «para» (lo sólido de siempre).
static func accion(elemento: String, proyectil: String, burbuja: bool = false) -> String:
	if burbuja:
		var fb: Dictionary = TABLA_BURBUJA.get(elemento, {})
		if fb.has(proyectil):
			return String(fb[proyectil])
	var f: Dictionary = TABLA.get(elemento, {})
	return String(f.get(proyectil, "para"))


static func protege(acc: String) -> bool:
	return not NO_PROTEGE.has(acc)


## ¿Gasta la barrera? Si pasa, no; si la anula en vapor o apaga, sí (C20 #7). El resto, el golpe de siempre (`dano`).
static func gasto(acc: String, dano: float) -> float:
	match acc:
		"pasa", "diluye", "rebota", "repele", "refleja":
			return 0.0
		"vapor", "apaga":
			return dano * 3.0
	return dano


static func _anotar(elemento: String, proyectil: String, acc: String) -> void:
	ultimas.append([elemento, proyectil, acc])
	if ultimas.size() > 32:
		ultimas.pop_front()


## El feedback común de lo ineficaz (C20 #1): golpe sordo y, la primera vez de este caso, un rótulo corto sobre el punto.
static func avisar_ineficaz(elemento: String, proyectil: String, punto: Vector3, mundo: Node) -> void:
	var clave: String = "%s|%s" % [elemento, proyectil]
	if mundo != null and not _vistos.has(clave) and ROTULOS_INEFICAZ.has(clave):
		_vistos[clave] = true
		Combate3D.flotante(mundo, punto + Vector3(0.0, 0.9, 0.0), String(ROTULOS_INEFICAZ[clave]), COLOR_INEFICAZ, 1.0)
	if mundo != null and mundo.is_inside_tree():
		Sfx.play_en(mundo, "golpe_sordo", punto)


## =====================================================================================================
##  Flecha enemiga (la de `Combate3D` y la de `FlechaTrampa3D`): un paso de su vuelo
## =====================================================================================================

## La flecha `flecha` (Node3D que vuela; meta «ardiendo» si arde) está en `p` viniendo de `anterior`. Mira la burbuja y las barreras de `lanz` y resuelve el contacto.
## Devuelve la acción («» = no tocó nada, o la cruzó: sigue volando). Con una acción que la detiene, la flecha queda con meta «parada» y se encarga de su final.
## `tirador` (opcional) para `repele`. `dano` es lo que encaja la barrera si la para.
static func flecha_en(lanz: Lanzador3D, flecha: Node3D, p: Vector3, anterior: Vector3, dano: float, mundo: Node) -> String:
	if lanz == null or flecha == null or flecha.has_meta("parada"):
		return ""
	var proyectil: String = "flecha_ardiendo" if flecha.has_meta("ardiendo") else "flecha"
	# 1) La burbuja: sigue a la jugadora (se mira cada paso).
	if lanz.burbuja_contiene(p) and not flecha.has_meta("cruza_burbuja"):
		var b: Lanzador3D.Burbuja = lanz._barrera_activa
		var acc_b: String = accion(b.elemento, proyectil, true)
		_anotar(b.elemento, proyectil, acc_b)
		if not protege(acc_b):
			flecha.set_meta("cruza_burbuja", true)
			avisar_ineficaz(b.elemento, proyectil, p, mundo)
			return acc_b
		_detener(flecha, acc_b, p, anterior, mundo)
		return acc_b
	# 2) Una barrera (SolidezV2). La de viento con su cara de desvío ya la resuelve quien llama (`_desviar_flecha`).
	var s: Lanzador3D.SolidezV2 = lanz.solidez_en(p)
	if s == null:
		return ""
	if flecha.has_meta("cruzo_" + str(s.get_instance_id())):
		return ""
	var acc: String = accion(s.elemento, proyectil)
	_anotar(s.elemento, proyectil, acc)
	if not protege(acc):
		flecha.set_meta("cruzo_" + str(s.get_instance_id()), true)        # la cruza una vez, sin gastarla, y se lee
		avisar_ineficaz(s.elemento, proyectil, p, mundo)
		return acc
	s.golpe(gasto(acc, dano))
	_detener(flecha, acc, p, anterior, mundo)
	return acc


## El final de una flecha que algo detuvo, según la acción. Se ve distinto en cada caso (C19, feedback de O12).
static func _detener(flecha: Node3D, acc: String, p: Vector3, anterior: Vector3, mundo: Node) -> void:
	flecha.set_meta("parada", true)
	flecha.set_meta("contacto", acc)
	var fx: Variant = mundo.get("_fx") if mundo != null else null
	var vfx: Vfx3D = fx as Vfx3D if fx is Vfx3D else null
	match acc:
		"quema":
			if vfx != null:
				vfx.golpe_estrella(p, "fuego", 0.6)
			var tw: Tween = flecha.create_tween()
			tw.tween_property(flecha, "scale", Vector3.ONE * 0.05, T_CENIZA)
			tw.tween_callback(flecha.queue_free)
			if mundo != null and mundo.is_inside_tree():
				Sfx.play_en(mundo, "golpe_sordo", p)
		"rebota", "repele":
			if vfx != null:
				vfx.golpe_estrella(p, "", 0.8)                    # destello blanco en estrella en el punto (O3)
			var ida: Vector3 = p - anterior
			ida.y = 0.0
			var lado: Vector3 = Vector3(-ida.z, 0.0, ida.x).normalized() if ida.length() > 0.001 else Vector3.RIGHT
			if randf() < 0.5:
				lado = -lado
			var salida: Vector3 = (-ida.normalized() * 0.5 + lado).normalized() if acc == "rebota" else -ida.normalized()
			var fin: Vector3 = p + salida * 1.1
			var suelo: float = Terreno3D.y_pies(Terreno3D.celda_de(fin)) if Terreno3D.en_mapa(Terreno3D.celda_de(fin)) else p.y - 0.8
			fin.y = suelo + 0.05
			var tw2: Tween = flecha.create_tween()
			tw2.tween_property(flecha, "position", fin, T_CAIDA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw2.parallel().tween_property(flecha, "rotation:z", flecha.rotation.z + TAU * 1.5, T_CAIDA)
			tw2.tween_interval(0.4)
			tw2.tween_callback(flecha.queue_free)
			if mundo != null and mundo.is_inside_tree():
				Sfx.play_en(mundo, "golpe_sordo", p)
		"frena", "apaga":
			if flecha.has_meta("ardiendo"):
				flecha.remove_meta("ardiendo")
			var fin2: Vector3 = p
			fin2.y = (Terreno3D.y_pies(Terreno3D.celda_de(p)) if Terreno3D.en_mapa(Terreno3D.celda_de(p)) else p.y - 0.8) + 0.05
			var tw3: Tween = flecha.create_tween()
			tw3.tween_property(flecha, "position", fin2, T_CAIDA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw3.tween_interval(0.5)
			tw3.tween_callback(flecha.queue_free)
		_:
			flecha.queue_free()                                     # para / vapor: se queda en la barrera
