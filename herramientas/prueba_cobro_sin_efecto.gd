extends "res://herramientas/escenario_base.gd"
## A4 de docs/PLAN_COMBATE_2026-11-22.md (C20 #2, 22/11): tierra + barrera sola.
## El caso del registro del 21/11: en el carril del dragón (SalaDragon) salía con 0 manifestaciones y cobraba 12 de tinta (88 → 76), y parecía un cobro sin efecto.
## No lo era: la barrera de tierra sola ocupa UNA casilla (la tuya); el bloque no se levanta ahí («estás encima»), pero su SolidezV2 sí nacía y protegía. No se veía nada.
## Decisión de Pablo (22/11): «círculo de tierra alrededor, capa fina; así hay una debilidad en los ataques del suelo o explosiones». Comprueba:
##   · sale un ANILLO de tierra (`AnilloTierra`, hijo de la SolidezV2) y cuenta como 1 manifestación (entra en `barreras_vivas`, el tope C4);
##   · la protección para proyectiles en su casilla (`solidez_para`) y el anillo se va con ella;
##   · cobra su tinta (es una elección con efecto) y un hechizo normal sigue igual.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_cobro_sin_efecto.gd

const RUTA_SALA: String = "res://escenas/PruebaSalaDragon.tscn"

var _ultimo_n: int = -1


func _al_lanzar(_el: String, _forma: String, n: int) -> void:
	_ultimo_n = n


func _anillos() -> Array:
	var r: Array = []
	for s in lanzador._solideces_v2:
		if is_instance_valid(s) and not (s as Node).is_queued_for_deletion():
			var a: Node = (s as Node).get_node_or_null("AnilloTierra")
			if a != null:
				r.append(a)
	return r


func _probar(desde: Vector2i, elemento: String, glifos: Array, dir: Vector3) -> Dictionary:
	colocar_jugador(desde)
	await avanzar(2)
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
		lanzador.tinta.actual = 88.0
	_ultimo_n = -1
	var antes: float = lanzador.tinta.actual if lanzador.tinta != null else 0.0
	var salio: bool = lanzar(elemento, glifos, dir)
	var espera: float = 0.0
	while _ultimo_n < 0 and espera < 3.0:
		espera += await avanzar_s(0.1)
	await avanzar_s(0.3)                                    # que el anillo haya brotado
	var despues: float = lanzador.tinta.actual if lanzador.tinta != null else 0.0
	var anillos: Array = _anillos()
	var alto: float = (anillos[0] as Node3D).scale.y if not anillos.is_empty() else 0.0
	var r: Dictionary = {"salio": salio, "n": _ultimo_n, "cobro": snappedf(antes - despues, 0.1), "anillos": anillos.size(), "alto": snappedf(alto, 0.01),
		"protege_aqui": lanzador.solidez_para(jugador.position + Vector3(0, 0.8, 0), 0.0), "barreras": lanzador.barreras_vivas.size()}
	print("   %s %s desde %s hacia %s → %s" % [elemento, str(glifos), str(desde), str(dir), str(r)])
	return r


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_SALA, true)
	if lanzador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	lanzador.lanzado.connect(_al_lanzar)
	(jugador as Jugador3D).vida = 100000.0
	var casos: Array = [[Vector2i(2, 4), Vector3(0, 0, -1)], [Vector2i(3, 4), Vector3(1, 0, 0)], [Vector2i(14, 4), Vector3(0, 0, -1)]]
	var bien: int = 0
	for c in casos:
		var r: Dictionary = await _probar(c[0] as Vector2i, "tierra", ["barrera"], c[1] as Vector3)
		if int(r["n"]) == 1 and int(r["anillos"]) >= 1 and float(r["alto"]) > 0.9 and bool(r["protege_aqui"]) and float(r["cobro"]) > 0.0:
			bien += 1
		await avanzar_s(1.0)
	_ok("A4 tierra + barrera sola: anillo de tierra visible, 1 manifestación, protege su casilla y cobra", bien == casos.size(), "%d de %d casos" % [bien, casos.size()])
	var t_fin: float = 0.0
	while not _anillos().is_empty() and t_fin < 20.0:
		t_fin += await avanzar_s(0.25)
	_ok("A4 al acabar la protección, el anillo se va con ella", _anillos().is_empty(), "el último se fue %.1f s después" % t_fin)
	# Cuenta en el tope de barreras (C4): tres seguidas caben, la cuarta disuelve la más vieja
	for i in range(4):
		await _probar(Vector2i(2 + i * 3, 4), "tierra", ["barrera"], Vector3(0, 0, -1))
	_ok("A4 cuenta para el tope de barreras (%d como mucho)" % Lanzador3D.MAX_BARRERAS_VIVAS, lanzador.barreras_vivas.size() <= Lanzador3D.MAX_BARRERAS_VIVAS and _anillos().size() <= Lanzador3D.MAX_BARRERAS_VIVAS,
		"%d barreras · %d anillos" % [lanzador.barreras_vivas.size(), _anillos().size()])
	var antes_normal: int = _anillos().size()
	var normal: Dictionary = await _probar(Vector2i(4, 4), "fuego", ["flecha"], Vector3(1, 0, 0))
	_ok("A4 un hechizo normal sigue igual (no saca anillo, cobra)", int(normal["n"]) > 0 and float(normal["cobro"]) > 0.0 and int(normal["anillos"]) <= antes_normal, str(normal))
