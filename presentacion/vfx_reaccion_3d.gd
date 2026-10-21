class_name VfxReaccion3D
extends RefCounted
## EFECTOS DE LAS REACCIONES (PL2 de PLAN_EOW, Pipeline, 21/10): lo que se VE cuando algo arde, se apaga, se hunde o se rompe. La tabla que decide cuál
## suena y se ve en cada reacción es `ReaccionesVfx3D`; aquí solo están los dibujos, uno por función estática.
##
## POR QUÉ ESTÁ SEPARADO DE LA TABLA. Un efecto se escribe una vez y se reutiliza desde varias reacciones (el vapor sirve para `apagado_agua` y para
## `secado`), y la tabla debe poder cambiarse sin tocar un solo GPUParticles3D. Es la separación de EoW (la lógica emite una señal, una tabla elige el
## efecto): el Juego nunca decide qué partículas salen.
##
## LO QUE ARDE SE QUEDA ARDIENDO. `llamas_cuerpo` y `llamas_flecha` CUELGAN del nodo que arde (un hijo `LlamasCuerpo`): se mueven con él, y si el
## nodo se libera, las llamas se van con él (no quedan fuegos huérfanos). Las brasas nacen en coordenadas de mundo (`local_coords = false`), así que dejan
## estela cuando el goblin corre. Apagarlas es `apagar_llamas(nodo)`: las llamas dejan de emitir, la luz baja y el hijo se libera al acabar la última partícula.
## Todas las funciones son SOLO PRESENTACIÓN: no leen ni cambian la lógica de quien arde.
##
## Las funciones se apoyan en `VfxPuzle3D._emisor` (misma carpeta y mismo dueño) para no duplicar el emisor genérico. Si falta una textura se usa un
## punto suave: un efecto nunca falla por un PNG que no esté.

const NOMBRE_LLAMAS: String = "LlamasCuerpo"
const COLOR_LLAMA: Color = Color(1.0, 0.62, 0.22, 0.95)
const COLOR_MADERA: Color = Color(0.55, 0.36, 0.2, 1.0)


## Alto de referencia de lo que arde: la `altura` del enemigo si la tiene; si no, 1.
static func _alto(nodo: Node) -> float:
	var h: Variant = nodo.get("altura")
	return maxf(float(h), 0.2) if h != null else 1.0


## ---- Arder ----

## Llamas que cuelgan de `nodo` y lo siguen: lengüetas, brasas que dejan estela, un hilo de humo y una luz que parpadea. `escala` agranda o encoge todo
## (0,5 para un escudo). `dura` > 0: se apagan solas pasados esos segundos; 0: arden hasta `apagar_llamas`. Una sola vez por nodo: si ya arde, devuelve las que hay.
static func llamas_cuerpo(nodo: Node3D, escala: float = 1.0, dura: float = 0.0) -> Node3D:
	if nodo == null:
		return null
	var previo: Node3D = nodo.get_node_or_null(NOMBRE_LLAMAS) as Node3D
	if previo != null:
		return previo
	var h: float = _alto(nodo) * escala
	var raiz := Node3D.new()
	raiz.name = NOMBRE_LLAMAS
	nodo.add_child(raiz)
	# Lengüetas: la textura de llama aditiva y por encima de 1 (el bloom la hace brillar); suben porque la «gravedad» es positiva.
	VfxPuzle3D._emisor(raiz, Vector3(0.0, h * 0.45, 0.0), "llama", 14, 0.75, 0.62 * h, 0.35 * h,
		{"color": COLOR_LLAMA, "aditivo": true, "hdr": 1.8, "gravedad": 1.6, "abanico": 25.0, "continuo": true, "radio_emision": 0.3 * h})
	# Brasas: puntitos que se sueltan y suben; en coordenadas de mundo dejan estela cuando el goblin se mueve.
	VfxPuzle3D._emisor(raiz, Vector3(0.0, h * 0.5, 0.0), "brasa", 10, 1.1, 0.1 * h, 0.8 * h,
		{"color": Color(1.0, 0.55, 0.15, 1.0), "aditivo": true, "hdr": 2.2, "gravedad": 1.2, "abanico": 60.0, "continuo": true, "radio_emision": 0.32 * h})
	# Humo oscuro: sube por encima de la cabeza, se ensancha y se deshace.
	VfxPuzle3D._emisor(raiz, Vector3(0.0, h * 0.95, 0.0), "humo", 6, 1.6, 0.55 * h, 0.4,
		{"color": Color(0.2, 0.18, 0.17, 0.5), "gravedad": 0.8, "abanico": 20.0, "crece": true, "continuo": true, "radio_emision": 0.2 * h})
	var luz := OmniLight3D.new()
	luz.name = "Luz"
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.light_energy = 1.1
	luz.omni_range = 2.6 * h
	luz.shadow_enabled = false                       # una luz con sombra por goblin ardiendo costaría más de lo que aporta
	luz.position = Vector3(0.0, h * 0.5, 0.0)
	raiz.add_child(luz)
	VfxKit3D.parpadeo(luz)
	if dura > 0.0 and nodo.is_inside_tree():
		nodo.get_tree().create_timer(dura, false).timeout.connect(func() -> void: apagar_llamas(nodo))
	return raiz


## Apaga las llamas de `nodo`: dejan de emitir, la luz se va y el hijo se libera cuando se acaba la última partícula. `con_vapor`: bocanada de vapor
## (agua) en vez de apagarse sin más. Devuelve false si no ardía.
static func apagar_llamas(nodo: Node3D, con_vapor: bool = false) -> bool:
	if nodo == null or not is_instance_valid(nodo):
		return false
	var raiz: Node3D = nodo.get_node_or_null(NOMBRE_LLAMAS) as Node3D
	if raiz == null or raiz.has_meta("apagando"):
		return false
	raiz.set_meta("apagando", true)
	raiz.name = NOMBRE_LLAMAS + "_apagando"          # libera el nombre: si vuelve a arder se crea otro sin chocar con este
	for hijo in raiz.get_children():
		if hijo is GPUParticles3D:
			(hijo as GPUParticles3D).emitting = false
	var luz: OmniLight3D = raiz.get_node_or_null("Luz") as OmniLight3D
	if luz != null:
		var tw: Tween = luz.create_tween()
		tw.tween_property(luz, "light_energy", 0.0, 0.3)
	if con_vapor and raiz.is_inside_tree():
		VfxPuzle3D.vapor(raiz, Vector3(0.0, _alto(nodo) * 0.6, 0.0), _alto(nodo))
	if raiz.is_inside_tree():
		raiz.get_tree().create_timer(2.0, false).timeout.connect(raiz.queue_free)   # la partícula más larga vive 1,6 s
	else:
		raiz.queue_free()
	return true


## Una flecha ardiendo: llama pequeña en la punta y un rastro de brasas. Cuelga de la flecha: desaparece con ella. Devuelve el nodo, o el que ya había.
static func llamas_flecha(flecha: Node3D) -> Node3D:
	if flecha == null:
		return null
	var previo: Node3D = flecha.get_node_or_null(NOMBRE_LLAMAS) as Node3D
	if previo != null:
		return previo
	var raiz := Node3D.new()
	raiz.name = NOMBRE_LLAMAS
	flecha.add_child(raiz)
	VfxPuzle3D._emisor(raiz, Vector3.ZERO, "llama", 8, 0.35, 0.28, 0.2,
		{"color": COLOR_LLAMA, "aditivo": true, "hdr": 2.0, "gravedad": 1.0, "abanico": 15.0, "continuo": true, "radio_emision": 0.05})
	VfxPuzle3D._emisor(raiz, Vector3.ZERO, "brasa", 12, 0.6, 0.07, 0.3,
		{"color": Color(1.0, 0.55, 0.15, 1.0), "aditivo": true, "hdr": 2.2, "gravedad": -1.5, "abanico": 30.0, "continuo": true, "radio_emision": 0.04})
	var luz := OmniLight3D.new()
	luz.name = "Luz"
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.light_energy = 0.6
	luz.omni_range = 1.4
	luz.shadow_enabled = false
	raiz.add_child(luz)
	VfxKit3D.parpadeo(luz)
	return raiz


## Un fogonazo breve de algo que acaba de prender (sin quedarse ardiendo: para piezas, que ya tienen su fuego): destello, brasas y luz que baja.
static func llamarada(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	VfxPuzle3D._emisor(padre, punto, "llama", 10, 0.5, 0.5 * esc, 1.0 * esc,
		{"color": COLOR_LLAMA, "aditivo": true, "hdr": 2.0, "gravedad": 1.5, "abanico": 40.0, "radio_emision": 0.15 * esc})
	VfxPuzle3D._emisor(padre, punto, "brasa", 12, 0.8, 0.09 * esc, 2.2 * esc,
		{"color": Color(1.0, 0.55, 0.15, 1.0), "aditivo": true, "hdr": 2.2, "gravedad": -2.0, "abanico": 80.0, "radio_emision": 0.12 * esc})
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.6, 0.25)
	luz.light_energy = 2.0
	luz.omni_range = 2.5 * esc
	luz.shadow_enabled = false
	luz.position = punto
	padre.add_child(luz)
	var tw: Tween = luz.create_tween()
	tw.tween_property(luz, "light_energy", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(luz.queue_free)


## ---- Apagar ----

## Agua sobre fuego: vapor y gotas. Si `nodo` ardía (llamas que cuelgan de él), las apaga con la bocanada.
static func apagar_vapor(padre: Node3D, punto: Vector3, nodo: Node3D = null, esc: float = 1.0) -> void:
	if nodo == null or not apagar_llamas(nodo, true):
		VfxPuzle3D.vapor(padre, punto, esc)
	VfxPuzle3D.salpicadura(padre, punto, 0.6 * esc)


## El viento se lleva la llama: humo gris que sale disparado y chispas que se dispersan. También apaga las llamas de `nodo`.
static func apagar_soplo(padre: Node3D, punto: Vector3, nodo: Node3D = null, esc: float = 1.0) -> void:
	if nodo != null:
		apagar_llamas(nodo, false)
	VfxPuzle3D._emisor(padre, punto, "humo", 8, 1.0, 0.5 * esc, 2.2 * esc,
		{"color": Color(0.5, 0.5, 0.52, 0.55), "gravedad": 0.2, "abanico": 70.0, "crece": true, "radio_emision": 0.15 * esc})
	VfxPuzle3D._emisor(padre, punto, "brasa", 10, 0.9, 0.07 * esc, 3.5 * esc,
		{"color": Color(1.0, 0.55, 0.15, 1.0), "aditivo": true, "hdr": 1.8, "gravedad": -0.5, "abanico": 70.0, "radio_emision": 0.1 * esc})


## Lo que queda de algo consumido por el fuego: una bocanada de ceniza y unas brasas. (El consumo mismo, el frente que sube por el modelo, es `ConsumoFuego3D`.)
static func ceniza(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	VfxPuzle3D._emisor(padre, punto, "humo", 8, 1.4, 0.7 * esc, 0.8 * esc,
		{"color": Color(0.17, 0.16, 0.16, 0.6), "gravedad": 0.6, "abanico": 40.0, "crece": true, "radio_emision": 0.3 * esc})
	VfxPuzle3D._emisor(padre, punto, "brasa", 8, 0.9, 0.07 * esc, 1.2 * esc,
		{"color": Color(1.0, 0.5, 0.12, 1.0), "aditivo": true, "hdr": 1.6, "gravedad": 0.8, "abanico": 50.0, "radio_emision": 0.25 * esc})


## ---- Agua, hielo, rayo ----

## Algo se moja: salpicadura (la de las piezas de puzle).
static func mojar(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	VfxPuzle3D.salpicadura(padre, punto, esc)


## Se seca: bocanada suave de vapor.
static func secar(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	VfxPuzle3D.vapor(padre, punto, 0.7 * esc)


## Se congela: copos y cristalitos azules que saltan y se quedan flotando un momento.
static func escarcha(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	VfxPuzle3D._emisor(padre, punto, "copo", 12, 0.9, 0.2 * esc, 1.6 * esc,
		{"color": Color(0.8, 0.93, 1.0, 0.9), "aditivo": true, "hdr": 1.5, "gravedad": -0.8, "abanico": 90.0, "radio_emision": 0.3 * esc})
	VfxPuzle3D._emisor(padre, punto, "destello", 4, 0.5, 0.5 * esc, 0.2,
		{"color": Color(0.7, 0.9, 1.0, 0.8), "aditivo": true, "hdr": 1.8, "gravedad": 0.0, "abanico": 180.0, "radio_emision": 0.2 * esc})
	if VfxHielo.activo() and padre.is_inside_tree():            # assets elementos: racimos pequeños y pinchos de escarcha de Meshy alrededor (se funden solos)
		VfxHielo.escarcha_modelos(padre, punto, esc, VfxHielo.suelo_bajo(padre, punto))


## Se derrite: gotas que caen y un poco de vapor frío.
static func derretir(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	VfxPuzle3D._emisor(padre, punto, "gota", 10, 0.8, 0.1 * esc, 0.8 * esc,
		{"color": Color(0.7, 0.9, 1.0, 0.9), "gravedad": -7.0, "abanico": 25.0, "radio_emision": 0.25 * esc})
	VfxPuzle3D.vapor(padre, punto, 0.5 * esc)


## Descarga eléctrica: chispas en todas direcciones.
static func descarga(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	VfxPuzle3D.chispas(padre, punto, false, 1.4 * esc)


## ---- Estados del cuerpo ----

## Hundirse en el agua: la salpicadura del chapuzón, anillos que se abren uno tras otro y burbujas que suben mientras baja. `dura` s de burbujas.
## Cuelga de `padre` (el mundo, NO del que se hunde: ese baja y se libera) y se libera solo.
static func hundimiento(padre: Node3D, punto: Vector3, esc: float = 1.0, dura: float = 1.6) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Hundimiento"
	raiz.position = punto
	padre.add_child(raiz)
	VfxPuzle3D.salpicadura(raiz, Vector3.ZERO, 1.5 * esc)
	var tw: Tween = raiz.create_tween()
	for k in range(4):                                          # anillos escalonados: el agua tarda en calmarse
		var desfase: Vector2 = Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)) * esc
		tw.tween_callback(VfxPuzle3D.anillo_caida.bind(raiz, Vector3(desfase.x, 0.0, desfase.y), (0.7 + 0.25 * k) * esc))
		tw.tween_interval(dura / 5.0)
	var b: Tween = raiz.create_tween()
	for k in range(7):                                          # burbujas: una tanda cada ~0,2 s, desde el sitio donde se hunde
		b.tween_interval(dura / 8.0)
		b.tween_callback(VfxPuzle3D.burbujas.bind(raiz, Vector3(randf_range(-0.2, 0.2), -0.1, randf_range(-0.2, 0.2)) * esc, 0.3 * esc, false))
	if raiz.is_inside_tree():
		raiz.get_tree().create_timer(dura + 2.2, false).timeout.connect(raiz.queue_free)
	return raiz


## Aturdido: unas estrellitas amarillas que se abren sobre la cabeza (`punto` = la cabeza; `esc` = alto del que está aturdido).
static func estrellas(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	VfxPuzle3D._emisor(padre, punto, "destello", 6, 1.0, 0.22 * esc, 0.5 * esc,
		{"color": Color(1.0, 0.9, 0.35, 1.0), "aditivo": true, "hdr": 2.0, "gravedad": 0.0, "abanico": 180.0, "radio_emision": 0.28 * esc})


## Empujado: nube de polvo a ras de suelo, hacia donde lo empujan (`dir` = hacia dónde va; Vector3.ZERO = en todas direcciones).
static func empujon(padre: Node3D, punto: Vector3, dir: Vector3 = Vector3.ZERO, esc: float = 1.0) -> void:
	var d: Vector3 = Vector3(-dir.x, 0.15, -dir.z).normalized() if dir.length() > 0.01 else Vector3(0.0, 0.25, 0.0)
	VfxPuzle3D._emisor(padre, punto, "polvo", 8, 0.8, 0.5 * esc, 1.6 * esc,
		{"color": Color(0.74, 0.64, 0.52, 0.55), "gravedad": 0.0, "abanico": 45.0 if dir.length() > 0.01 else 80.0, "direccion": d, "crece": true,
		"radio_emision": 0.2 * esc, "amortigua": 1.5})


## ---- Escudo ----

## Algo choca contra el escudo (entero): destello seco y chispas que rebotan hacia fuera (`normal` = hacia donde mira la cara golpeada).
static func escudo_golpe(padre: Node3D, punto: Vector3, normal: Vector3 = Vector3.UP, esc: float = 1.0) -> void:
	var n: Vector3 = normal.normalized() if normal.length() > 0.01 else Vector3.UP
	VfxPuzle3D._emisor(padre, punto, "destello", 1, 0.18, 0.7 * esc, 0.0,
		{"color": Color(1.0, 0.95, 0.8, 1.0), "aditivo": true, "hdr": 2.4, "gravedad": 0.0, "radio_emision": 0.01})
	VfxPuzle3D._emisor(padre, punto, "chispa_electrica", 6, 0.35, 0.12 * esc, 3.0 * esc,
		{"color": Color(1.0, 0.85, 0.5, 1.0), "aditivo": true, "hdr": 2.0, "gravedad": -6.0, "abanico": 45.0, "direccion": n, "alargada": true,
		"radio_emision": 0.03})


## El escudo se rompe: astillas de madera que saltan, polvo y, si ardía, brasas. `ardia`: llevaba llamas.
static func escudo_roto(padre: Node3D, punto: Vector3, ardia: bool = false, esc: float = 1.0) -> void:
	VfxPuzle3D._emisor(padre, punto, "piedrecitas", 14, 0.8, 0.14 * esc, 3.2 * esc,
		{"color": COLOR_MADERA, "gravedad": -9.0, "abanico": 110.0, "alargada": true, "radio_emision": 0.18 * esc})
	VfxPuzle3D.polvo(padre, punto, 0.5 * esc)
	if ardia:
		ceniza(padre, punto, 0.8 * esc)
