extends "res://herramientas/escenario_base.gd"
## G1 de docs/PLAN_COMBATE_2026-11-22.md (22/11, morir y reintentar). Regla de Pablo: lo permanente se queda; la vida y la fase de los enemigos del encuentro se restauran; los ataques
## y avisos se retiran; lo resuelto sigue resuelto. Comprueba:
##   · CUEVA, sala C4 (vigía `guardia` + cerrojo `entrada_c4`): entrar cierra la puerta; se mata a un goblin y se hiere a otro; la jugadora muere y reaparece →
##     los goblins vuelven todos, sanos y en su sitio; la puerta se abre; no queda ningún aviso; la flag de la sala sigue sin poner. Luego se limpia la sala → al morir otra vez
##     no vuelve nadie, la flag sigue puesta y la puerta, abierta.
##   · SALA DEL DRAGÓN: se presenta y se le quita vida; al reaparecer vuelve a dormir con la vida llena.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_reintentar.gd


func _vivos(v: Object) -> Array:
	var r: Array = []
	for e in v.get("vistos"):
		if is_instance_valid(e) and not bool((e as Combate3D).muerto):
			r.append(e)
	return r


func _morir_y_volver() -> void:
	var j: Jugador3D = jugador as Jugador3D
	j.vida = 0.0
	j._morir()
	await avanzar(3)
	j.reaparecer()
	await avanzar_s(0.6)                                    # que el vigía vuelva a ver a los repuestos


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar("res://escenas/PruebaCueva.tscn", true)
	if maqueta == null or lanzador == null:
		return
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var vig: Object = z.nodo("guardia") if z != null else null
	var cj: Object = z.nodo("entrada_c4") if z != null else null
	_ok("0 la sala C4 tiene su vigía y su cerrojo", vig != null and cj != null)
	if vig == null or cj == null:
		return
	await avanzar_s(0.6)
	var n0: int = _vivos(vig).size()
	_ok("0 el vigía ve a sus goblins y guarda su receta antes de la pelea", n0 >= 2 and (vig.get("recetas") as Array).size() == n0, "%d goblins, %d recetas" % [n0, (vig.get("recetas") as Array).size()])
	var casas: Array = []
	for e in _vivos(vig):
		casas.append(Terreno3D.celda_de((e as Combate3D).casa))
	# Entra (se cierra la puerta) y pelea: uno muerto, otro herido.
	(jugador as Jugador3D).vida = 100000.0
	colocar_jugador(Vector2i(20, 5))
	await avanzar_s(0.5)
	_ok("1 al entrar en la sala se cierra la puerta", bool(cj.get("cerrado")))
	var vivos: Array = _vivos(vig)
	(vivos[0] as Combate3D).receive_damage(9999.0)
	(vivos[1] as Combate3D).receive_damage(15.0)
	await avanzar_s(0.6)
	_ok("1 la pelea empezó: uno menos", _vivos(vig).size() == n0 - 1 and bool(vig.get("empezado")))
	var viejos: Array = vivos.duplicate()
	await _morir_y_volver()
	var nuevos: Array = _vivos(vig)
	_ok("2 al reaparecer, vuelven todos los goblins del encuentro", nuevos.size() == n0, "%d de %d" % [nuevos.size(), n0])
	var sanos: bool = true
	var en_casa: bool = true
	for e in nuevos:
		sanos = sanos and is_equal_approx((e as Combate3D).health, (e as Combate3D).vida_max)
		en_casa = en_casa and casas.has(Terreno3D.celda_de((e as Combate3D).casa))
	_ok("2 sanos y en su casilla de partida", sanos and en_casa)
	var nuevo_de_verdad: bool = true
	for e in nuevos:
		nuevo_de_verdad = nuevo_de_verdad and not viejos.has(e)
	_ok("2 son enemigos nuevos (los de antes se retiraron)", nuevo_de_verdad)
	_ok("2 la puerta de la sala se abre (se volverá a cerrar al entrar)", not bool(cj.get("cerrado")))
	_ok("2 no queda ningún aviso de ataque en el suelo", get_nodes_in_group(AvisoAtaque3D.GRUPO).is_empty())
	_ok("2 la sala sigue sin resolver (su flag no se puso)", not Flags.i().tiene("cueva.c4.limpia") and not bool(vig.get("completo")))
	# Ahora se limpia de verdad y se vuelve a morir: lo resuelto se queda.
	colocar_jugador(Vector2i(20, 5))
	await avanzar_s(0.5)
	_ok("3 al volver a entrar se cierra otra vez", bool(cj.get("cerrado")))
	for e in _vivos(vig):
		(e as Combate3D).receive_damage(9999.0)
	await avanzar_s(1.0)
	_ok("3 sala limpia: flag puesta y puerta abierta", Flags.i().tiene("cueva.c4.limpia") and bool(vig.get("completo")) and not bool(cj.get("cerrado")))
	var reinicios: int = int(vig.get("reinicios"))
	await _morir_y_volver()
	_ok("3 al morir con la sala resuelta no vuelve nadie y todo sigue resuelto", _vivos(vig).is_empty() and int(vig.get("reinicios")) == reinicios
		and Flags.i().tiene("cueva.c4.limpia") and not bool(cj.get("cerrado")))
	maqueta.queue_free()
	await avanzar(5)
	# --- El dragón ---
	await cargar("res://escenas/PruebaSalaDragon.tscn", true)
	var zd: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	var dr: DragonJefe3D = zd.nodo("dragon") as DragonJefe3D if zd != null else null
	_ok("0 hay dragón", dr != null)
	if dr == null:
		return
	(jugador as Jugador3D).vida = 100000.0
	colocar_jugador(Vector2i(8, 4))
	var t: float = 0.0
	while dr.fase != DragonJefe3D.Fase.REPOSO and t < 10.0:
		t += await avanzar_s(0.2)
	dr.vida = dr.vida_max - 60.0
	_ok("4 el dragón se presentó y se le quitó vida", dr.fase != DragonJefe3D.Fase.DORMIDO and dr.vida < dr.vida_max)
	await _morir_y_volver()
	_ok("4 al reaparecer vuelve a dormir con la vida llena", dr.fase == DragonJefe3D.Fase.DORMIDO and is_equal_approx(dr.vida, dr.vida_max) and dr.reinicios == 1,
		"fase %d · vida %.0f" % [dr.fase, dr.vida])
