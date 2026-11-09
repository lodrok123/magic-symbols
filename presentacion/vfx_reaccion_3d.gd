class_name VfxReaccion3D
extends RefCounted
## EFECTOS DE LAS REACCIONES (PL2 de PLAN_EOW, Pipeline, 21/10): lo que se VE cuando algo arde, se apaga, se hunde o se rompe. La tabla que decide cuál
## suena y se ve en cada reacción es `ReaccionesVfx3D`; aquí solo están los dibujos, uno por función estática.
##
## POR QUÉ ESTÁ SEPARADO DE LA TABLA. Un efecto se escribe una vez y se reutiliza desde varias reacciones (el vapor sirve para `apagado_agua` y para
## `secado`), y la tabla debe poder cambiarse sin tocar un solo GPUParticles3D. Es la separación de EoW (la lógica emite una señal, una tabla elige el
## efecto): el Juego nunca decide qué partículas salen.
##
## Las llamas siguen al nodo que arde y se liberan con él. Las reacciones solo dibujan el estado del juego.

const NOMBRE_LLAMAS: String = "LlamasCuerpo"
const HumoToy = preload("res://presentacion/vfx/toy/humo_toy.gd")
const COLOR_MADERA: Color = Color(0.55, 0.36, 0.2, 1.0)
const HUESO_MANO_QUEMADA: String = "LeftHand"      ## la mano del escudo (final del nombre del hueso, como en Equipo3D)
const VIDA_RESTO_MANO_QUEMADA: float = 1.4         ## s que sigue ahí (sin emitir) lo que ya había salido, antes de quitar el attachment


## Alto de referencia de lo que arde: la `altura` del enemigo si la tiene; si no, 1.
static func _alto(nodo: Node) -> float:
	var h: Variant = nodo.get("altura")
	return maxf(float(h), 0.2) if h != null else 1.0


## ---- Arder ----

## Llama sostenida que sigue al cuerpo y se apaga con el ciclo del toy.
static func llamas_cuerpo(nodo: Node3D, escala: float = 1.0, dura: float = 0.0) -> Node3D:
	if nodo == null:
		return null
	var h: float = _alto(nodo) * escala
	return _llama_adherida(nodo, Vector3.UP * h * 0.04, 0.34 * h, 1.05 * h, 0.45, dura)


static func llamas_flecha(flecha: Node3D) -> Node3D:
	return _llama_adherida(flecha, Vector3.ZERO, 0.09, 0.28, 0.0, -1.0)


static func _llama_adherida(nodo: Node3D, pos: Vector3, radio: float, alto: float, luz: float, dura: float) -> Node3D:
	if nodo == null:
		return null
	var previa: Node3D = nodo.get_node_or_null(NOMBRE_LLAMAS) as Node3D
	if previa != null:
		return previa
	var llama := llama_vertical(nodo, pos, radio, alto, luz, dura)
	llama.name = NOMBRE_LLAMAS
	return llama


## Llama vertical con origen en su base, en coordenadas del padre.
static func llama_vertical(padre: Node3D, base: Vector3, radio: float, alto: float, luz: float = 0.0, dura: float = -1.0) -> FuegoToy:
	var llama := FuegoToy.new()
	llama.position = base
	llama.definir(FuegoToy.Figura.PILAR, radio, alto, radio)
	llama.luz = luz
	llama.chispas = 0.25
	padre.add_child(llama)
	llama.lanzar(dura if dura > 0.0 else -1.0)
	return llama


## Libera el nombre al empezar el apagado, para permitir que el blanco vuelva a prender.
static func apagar_llamas(nodo: Node3D, con_vapor: bool = false) -> bool:
	if not is_instance_valid(nodo):
		return false
	var llama: FuegoToy = nodo.get_node_or_null(NOMBRE_LLAMAS) as FuegoToy
	if llama == null:
		return false
	llama.name = NOMBRE_LLAMAS + "_apagando"
	if con_vapor and nodo.is_inside_tree():
		vapor(nodo, nodo.global_position + Vector3.UP * _alto(nodo) * 0.6, _alto(nodo))
	llama.morir()
	return true


## Llama breve de algo que empieza a arder.
static func llamarada(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	llama_vertical(padre, padre.to_local(punto), 0.20 * esc, 0.70 * esc, 0.25, 1.1)


## Agua sobre fuego: apaga las llamas y dibuja vapor y gotas en el punto de reacción.
static func apagar_vapor(padre: Node3D, punto: Vector3, nodo: Node3D = null, esc: float = 1.0) -> void:
	apagar_llamas(nodo)
	vapor(padre, punto, esc)
	mojar(padre, punto, 0.6 * esc)


## Bocanada breve en coordenadas locales del efecto, anclada al punto de reacción.
static func vapor(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	var humo := HumoToy.new()
	humo.name = "VaporReaccion"
	padre.add_child(humo)
	humo.global_position = punto
	humo.montar(4, {"mundo": false, "vida": 0.65, "tam_ini": 0.21 * esc, "tam_fin": 0.58 * esc})
	for i in range(4):
		var radial := Vector3.RIGHT.rotated(Vector3.UP, float(i) * TAU / 4.0)
		humo.emitir((radial * 0.18 + Vector3.UP * 0.12) * esc, (radial * 0.6 + Vector3.UP * 0.7) * esc)
	padre.get_tree().create_timer(0.7, false).timeout.connect(humo.queue_free)


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

## Gotas breves sin anillo, para que la reacción pueda ocurrir en el cuerpo.
static func mojar(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	var efecto := ImpactoAguaToy.crear(ImpactoAguaToy.Variante.FIN, Vector3.UP, 0.22 * esc)
	padre.add_child(efecto)
	efecto.global_position = punto
	efecto.lanzar()


## Se seca: bocanada suave de vapor.
static func secar(padre: Node3D, punto: Vector3, esc: float = 1.0) -> void:
	vapor(padre, punto, 0.7 * esc)


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

## Lo que dura el hundimiento (s) si quien lo avisa no dice otra cosa: la MISMA constante con la que `Combate3D` baja al enemigo bajo el agua cuando su
## modelo no trae clip de ahogarse. Con clip, el enemigo anuncia su duración real (`duracion_hundimiento`, la del clip) y `ReaccionesVfx3D` se la pasa aquí.
const DURA_HUNDIMIENTO: float = Combate3D.TIEMPO_HUNDIMIENTO
const TANDAS_BURBUJAS: int = 7                  ## tandas de burbujas repartidas por todo el hundimiento
const VIDA_BURBUJA_MIN: float = 0.3             ## lo menos que vive una tanda (s): la última, que sale cuando el cuerpo ya casi ha desaparecido
const ANILLOS_HUNDIMIENTO: int = 4

## Hundirse en el agua: la salpicadura del chapuzón, anillos que se abren uno tras otro y burbujas que suben mientras baja. Todo ocurre dentro de `dura` s
## (lo que tarda el cuerpo en bajar): las tandas de burbujas salen repartidas desde el chapuzón hasta el final, y la última vive solo lo que queda, así
## que la última burbuja llega a la superficie justo cuando el cuerpo ya está bajo el agua.
## Cuelga de `padre` (el mundo, NO del que se hunde: ese baja y se libera) y se libera solo.
static func hundimiento(padre: Node3D, punto: Vector3, esc: float = 1.0, dura: float = DURA_HUNDIMIENTO) -> Node3D:
	dura = maxf(dura, 0.1)
	var raiz := Node3D.new()
	raiz.name = "Hundimiento"
	raiz.position = punto
	padre.add_child(raiz)
	VfxPuzle3D.salpicadura(raiz, Vector3.ZERO, 1.5 * esc)
	var tw: Tween = raiz.create_tween()
	for k in range(ANILLOS_HUNDIMIENTO):                        # anillos escalonados: el agua tarda en calmarse
		var desfase: Vector2 = Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)) * esc
		tw.tween_callback(VfxPuzle3D.anillo_caida.bind(raiz, Vector3(desfase.x, 0.0, desfase.y), (0.7 + 0.25 * k) * esc))
		tw.tween_interval(dura / float(ANILLOS_HUNDIMIENTO + 1))
	var b: Tween = raiz.create_tween()
	for k in range(TANDAS_BURBUJAS):                            # burbujas: una tanda cada dura/N, desde el sitio donde se hunde
		var t: float = dura * float(k) / float(TANDAS_BURBUJAS)
		var vida: float = clampf(dura - t, VIDA_BURBUJA_MIN, VfxPuzle3D.VIDA_BURBUJA)
		if k > 0:
			b.tween_interval(dura / float(TANDAS_BURBUJAS))
		b.tween_callback(VfxPuzle3D.burbujas.bind(raiz, Vector3(randf_range(-0.2, 0.2), -0.1, randf_range(-0.2, 0.2)) * esc, 0.3 * esc, false, vida))
	raiz.set_meta("dura", dura)                                 # (pruebas y capturas: lo que se le pidió)
	if raiz.is_inside_tree():
		raiz.get_tree().create_timer(dura + VfxPuzle3D.VIDA_BURBUJA + 1.0, false).timeout.connect(raiz.queue_free)
	return raiz


## MANO QUEMADA (el escudo se consume ardiendo y le quema la mano al goblin): chispas y brasas que salen de la mano izquierda (la del escudo) durante `dura` s
## y un hilo de humo. Cuelga de un BoneAttachment3D de la mano, así que sigue la sacudida del clip `mano_quemada`; se libera solo. Devuelve el attachment
## (null si el modelo no tiene esqueleto o mano).
static func mano_quemada(pj: Pj3D, dura: float = 1.2, esc: float = 1.0) -> Node3D:
	if pj == null or not is_instance_valid(pj):
		return null
	var sk: Skeleton3D = pj._esqueleto()
	var h: int = Equipo3D._hueso(sk, HUESO_MANO_QUEMADA) if sk != null else -1
	if h < 0:
		return null
	var at := BoneAttachment3D.new()
	at.name = "ChispasManoQuemada"
	at.bone_name = sk.get_bone_name(h)
	sk.add_child(at)
	var pos: Vector3 = Vector3(0.0, 0.06, 0.0)                  # la palma: algo hacia los dedos (+Y del hueso de la mano)
	var chispas: GPUParticles3D = VfxPuzle3D._emisor(at, pos, "chispa_electrica", 8, 0.45, 0.09 * esc, 1.8 * esc,
		{"color": Color(1.0, 0.55, 0.15, 1.0), "aditivo": true, "hdr": 2.4, "gravedad": -5.0, "abanico": 160.0, "continuo": true, "radio_emision": 0.05 * esc})
	var brasas: GPUParticles3D = VfxPuzle3D._emisor(at, pos, "brasa", 6, 0.7, 0.09 * esc, 0.8 * esc,
		{"color": Color(1.0, 0.45, 0.12, 1.0), "aditivo": true, "hdr": 2.0, "gravedad": 1.5, "abanico": 90.0, "continuo": true, "radio_emision": 0.05 * esc})
	var humo: GPUParticles3D = VfxPuzle3D._emisor(at, pos, "humo", 4, 1.0, 0.16 * esc, 0.3 * esc,
		{"color": Color(0.25, 0.22, 0.2, 0.55), "gravedad": 0.8, "abanico": 30.0, "crece": true, "continuo": true, "radio_emision": 0.05 * esc})
	at.set_meta("dura", dura)
	at.set_meta("emisores", [chispas, brasas, humo])
	if at.is_inside_tree():
		# El tween cuelga del propio attachment: si el goblin se libera antes (muere, cambia de nivel) se va con él y no deja callbacks colgando.
		var tw: Tween = at.create_tween()
		tw.tween_interval(dura)
		tw.tween_callback(func() -> void:
			for e in [chispas, brasas, humo]:
				(e as GPUParticles3D).emitting = false)
		tw.tween_interval(VIDA_RESTO_MANO_QUEMADA)
		tw.tween_callback(at.queue_free)
	return at


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
