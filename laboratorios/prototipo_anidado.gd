extends Node
## PROTOTIPO LANZABLE DE LA ANIDACIÓN (H12 + H15; 23/11, Pablo: «crea un prototipo del hechizo anidado y del de la combinación»). Sesión HECHIZOS.
## SOLO en el lab del libro rojo (`laboratorios/LabLibroRojo.tscn`): no toca `Hechizo` ni `HechizoVivo`. Escucha `Lanzador3D.hechizo_vivo_creado` y, si la página que se
## acaba de lanzar tiene un HIJO escrito en el libro rojo (`pages[i]["hijo"]` = {elemento, glifos}, `condicion`), lanza el segundo círculo cuando toca:
##   · «al impactar»: donde el primero choca (golpe, muro, suelo o cruce con otro hechizo).
##   · «al acabar»: donde el primero termina, sea como sea (también al llegar a su alcance).
##   · «a la vez»: desde la mano, `RETARDO_A_LA_VEZ` s después (lo medido en el vídeo de Mystralia, H15).
## El hijo es un `Hechizo` NORMAL de su propio elemento y sus glifos (`Hechizo.construir`), y se lanza con el `lanzar_hechizo` de siempre. Se COBRA AL NACER (si el primero
## no llega a activarlo, no se paga; la política de coste, P11, sigue abierta). Al nacer: destello, rótulo con la condición y sonido, para que se lea la cadena.
## Sin los contrapesos de «a la vez» (recarga y tiempo de lanzar sumados, sin sobrecarga): eso irá en el sistema de verdad (B7).

signal hijo_lanzado(info: Dictionary)          ## {elemento, condicion, origen, coste, casillas} (pruebas)
signal hijo_sin_tinta(info: Dictionary)

const RETARDO_A_LA_VEZ: float = 0.17
const MOTIVOS_IMPACTO: PackedStringArray = ["golpe", "muro", "suelo", "cruce"]
const COLOR_ROTULO: Color = Color(1.0, 0.86, 0.55)

var activo: bool = true
var lz: Lanzador3D = null
var ultimo: Dictionary = {}                    ## lo último que lanzó (pruebas)
var _disparo_visto: Dictionary = {}            ## el `ultimo_disparo` ya atendido (el MISMO diccionario: `is_same`): las copias y la ráfaga de un disparo no lanzan varios hijos
var _lanzando_hijo: bool = false


func conectar(lanzador: Lanzador3D) -> void:
	lz = lanzador
	if lz != null and not lz.hechizo_vivo_creado.is_connected(_al_crear):
		lz.hechizo_vivo_creado.connect(_al_crear)


func _al_crear(vivo: HechizoVivo) -> void:
	if not activo or _lanzando_hijo or lz == null or vivo == null or vivo.h == null or vivo.h.profundidad != 0:
		return
	var disparo: Dictionary = lz.ultimo_disparo
	if disparo.is_empty() or is_same(disparo, _disparo_visto):
		return
	_disparo_visto = disparo
	var pag: int = int(disparo.get("pagina", 0)) - 1
	if pag < 0 or pag >= lz.pages.size():
		return
	var ficha: Dictionary = lz.pages[pag]
	var hijo: Variant = ficha.get("hijo")
	if not (hijo is Dictionary) or String((hijo as Dictionary).get("elemento", "")) == "":
		return
	var condicion: String = String(ficha.get("condicion", "al_impactar"))
	var dir: Vector3 = disparo.get("dir", Vector3.RIGHT) as Vector3
	if condicion == "a_la_vez":
		get_tree().create_timer(RETARDO_A_LA_VEZ, false).timeout.connect(func() -> void: lanzar_hijo((hijo as Dictionary).duplicate(true), condicion, _pos_mano(), dir))
	else:
		vivo.tree_exiting.connect(_al_acabar_principal.bind(vivo, (hijo as Dictionary).duplicate(true), condicion, dir), CONNECT_ONE_SHOT)


func _al_acabar_principal(vivo: HechizoVivo, hijo: Dictionary, condicion: String, dir: Vector3) -> void:
	if not is_instance_valid(vivo):
		return
	var motivo: String = vivo.motivo_fin
	if condicion == "al_impactar" and not MOTIVOS_IMPACTO.has(motivo):
		ultimo = {"no_nacio": true, "motivo": motivo, "condicion": condicion}
		return
	var p: Vector3 = vivo.p
	var c: Vector2i = Terreno3D.celda_de(p)
	var origen := Vector3(p.x, Terreno3D.y_pies(c) if Terreno3D.en_mapa(c) else p.y, p.z)
	lanzar_hijo.call_deferred(hijo, condicion, origen, dir)       # fuera del `tree_exiting`: el hijo entra en el árbol en paz


func _pos_mano() -> Vector3:
	if lz != null and lz.jugador != null and is_instance_valid(lz.jugador):
		return (lz.jugador as Node3D).global_position
	return Vector3.ZERO


## Lanza el segundo círculo. Público para las pruebas. Devuelve las casillas que ocupó (0 = no salió).
func lanzar_hijo(hijo: Dictionary, condicion: String, origen: Vector3, dir: Vector3) -> int:
	if lz == null or not is_instance_valid(lz) or not lz.is_inside_tree():
		return 0
	var elemento: String = String(hijo.get("elemento", ""))
	var tipo: Variant = Grimorio.GESTURE_TO_RUNE.get(elemento)
	var rune: RuneData = lz.rune_database.get(tipo) as RuneData if tipo != null else null
	if rune == null:
		return 0
	var cuentas: Dictionary = {}
	var orden: Array = []
	for g in (hijo.get("glifos", []) as Array):
		if String(g) != "":
			cuentas[String(g)] = int(cuentas.get(String(g), 0)) + 1
			orden.append(String(g))
	var h: Hechizo = Hechizo.construir(rune, cuentas, 1.0, false, orden)
	if h == null:
		return 0
	var coste: float = Dano.tinta_de(h)
	var tinta_antes: float = lz.tinta.actual if lz.tinta != null else 0.0
	if lz.tinta != null and not lz.tinta.gastar("", coste, elemento):
		ultimo = {"sin_tinta": true, "elemento": elemento, "coste": coste}
		Combate3D.flotante(lz.mundo, origen + Vector3(0.0, 1.2, 0.0), "Sin tinta para el 2.º círculo", Color(1.0, 0.4, 0.3), 1.0)
		hijo_sin_tinta.emit(ultimo)
		return 0
	var tinta_despues: float = lz.tinta.actual if lz.tinta != null else 0.0
	_lanzando_hijo = true
	var n: int = lz.lanzar_hechizo(h, origen, dir if dir.length() > 0.01 else Vector3.RIGHT)
	_lanzando_hijo = false
	# Que se vea NACER: el efecto común del hijo (aro que se cierra + runa de su sello, GlifoComunVfx, 24/11), rótulo con la condición y sonido.
	var gc: GlifoComunVfx = lz.mundo.get_node_or_null("GlifoComunVfx") as GlifoComunVfx if lz.mundo != null else null
	if gc == null and lz.mundo != null:
		gc = GlifoComunVfx.conectar(lz, lz.mundo)
	if gc != null:
		gc.hijo_nace(lz.mundo, origen, elemento)
	var texto: String = {"al_impactar": "al impactar", "al_acabar": "al acabar", "a_la_vez": "a la vez"}.get(condicion, condicion)
	Combate3D.flotante(lz.mundo, origen + Vector3(0.0, 1.2, 0.0), "→ %s: %s" % [texto, elemento], COLOR_ROTULO, 0.9)
	Sfx.play(lz, "sello_ok")
	ultimo = {"elemento": elemento, "condicion": condicion, "origen": origen, "coste": coste, "casillas": n, "hechizo": h, "tinta_antes": tinta_antes, "tinta_despues": tinta_despues}
	hijo_lanzado.emit(ultimo)
	PlayLog.event("prototipo_anidado", {"elemento": elemento, "condicion": condicion, "coste": snappedf(coste, 0.1), "casillas": n})
	return n
