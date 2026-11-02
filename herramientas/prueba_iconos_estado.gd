extends "res://herramientas/prueba_sensacion_2.gd"
## GAMEFEEL TERCERA TANDA, LOTE 2 · B2 ICONOS DE ESTADO DEL ENEMIGO (2/11; enemigos/combate_3d.gd `_construir_iconos_estado` / `_actualizar_iconos_estado` / `estados_activos`).
## Sobre la escena real del Bosque, con un guerrero quieto y --fixed-fps 30 (los estados se ponen con los hechizos de verdad: `on_spell_hit` con la runa del elemento):
##   1 prender → icono «quemado» con su barra de tiempo, que baja; sin tocar el estado (solo lee);  2 mojar y helar → dos iconos (congelado y mojado), ordenados;  3 el rayo → «electrificado» (aturdido) mientras dura;
##   4 al expirar desaparecen;  5 `ICONOS_ESTADO_SIEMPRE = false` con la barra oculta → no se ven, con la barra visible sí;  6 `Sensacion3D.ACTIVA = false` → se siguen viendo (es información);
##   7 como mucho 4 a la vez;  8 el elemental no los muestra y el muerto tampoco;  9 letras Q C V M E por defecto y símbolos con `ICONOS_CON_SIMBOLOS`.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_iconos_estado.gd

const RUNAS: Dictionary = {"fuego": "fire", "agua": "water", "rayo": "lightning", "hielo": "ice", "tierra": "earth", "viento": "wind"}


func _runa(el: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % RUNAS[el]) as RuneData


func _golpear(g: Combate3D, el: String) -> void:
	g.on_spell_hit(_runa(el), Vector3(-1, 0, 0))


func _guerrero(vida: float = 100000.0) -> Combate3D:
	return _goblin(Vector2i(9, 33), true, vida)


func _letra(g: Combate3D, i: int) -> Label3D:
	return g._iconos_estado[i]["letra"] as Label3D


func _escenario() -> void:
	var siempre0: bool = Combate3D.ICONOS_ESTADO_SIEMPRE
	var simbolos0: bool = Combate3D.ICONOS_CON_SIMBOLOS
	var sens0: bool = Sensacion3D.ACTIVA
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	_vaciar_nivel()
	await avanzar(20)
	_jugadora(Vector2i(11, 33))
	Sensacion3D.ACTIVA = true
	Combate3D.ICONOS_ESTADO_SIEMPRE = true
	Combate3D.ICONOS_CON_SIMBOLOS = false

	await _caso_quemado()
	await _caso_dos()
	await _caso_rayo()
	await _caso_expira()
	await _caso_solo_con_barra()
	await _caso_sin_sensacion()
	await _caso_maximo()
	await _caso_elemental_y_muerto()
	await _caso_simbolos()

	Combate3D.ICONOS_ESTADO_SIEMPRE = siempre0
	Combate3D.ICONOS_CON_SIMBOLOS = simbolos0
	Sensacion3D.ACTIVA = sens0
	print("COMPROBACIONES: %d" % _comprobaciones)


# --- 1 · prender ------------------------------------------------------------------------------------------------------
func _caso_quemado() -> void:
	var g: Combate3D = _guerrero()
	await avanzar(3)
	_ok("1 el guerrero nace con %d huecos de icono, todos ocultos" % Combate3D.MAX_ICONOS_ESTADO, g._iconos_estado.size() == Combate3D.MAX_ICONOS_ESTADO and g.iconos_estado_visibles().is_empty())
	_ok("1 sin estados, estados_activos() está vacío", g.estados_activos().is_empty())
	_golpear(g, "fuego")
	await avanzar(3)
	_ok("1 prendido: quemando > 0", g.quemando > 0.0, str(g.quemando))
	_ok("1 se ve UN icono: «quemado»", g.iconos_estado_visibles() == ["quemado"], str(g.iconos_estado_visibles()))
	_ok("1 con la letra Q y el color del fuego", _letra(g, 0).text == "Q" and _letra(g, 0).modulate.r > 0.9 and _letra(g, 0).modulate.b < 0.4)
	var a: Dictionary = g.estados_activos()[0]
	var fr0: float = float(a["fraccion"])
	var barra: MeshInstance3D = g._iconos_estado[0]["barra"] as MeshInstance3D
	_ok("1 la barra de tiempo debajo se ve y está casi llena", barra.visible and fr0 > 0.9 and (barra.mesh as QuadMesh).size.x > Combate3D.ICONO_BARRA_ANCHO * 0.9, "fracción %.2f ancho %.3f" % [fr0, (barra.mesh as QuadMesh).size.x])
	_ok("1 el tiempo restante es el de `quemando`", is_equal_approx(float(a["tiempo"]), g.quemando))
	var q0: float = g.quemando
	await avanzar(30)
	var fr1: float = float(g.estados_activos()[0]["fraccion"]) if not g.estados_activos().is_empty() else 0.0
	_ok("1 un segundo después la barra ha bajado (%.2f → %.2f) y sigue el icono" % [fr0, fr1], fr1 < fr0 - 0.2 and g.iconos_estado_visibles() == ["quemado"])
	_ok("1 y quemando bajó solo (el icono no lo toca): %.2f → %.2f" % [q0, g.quemando], g.quemando < q0 and g.quemando > 0.0)
	_limpiar()
	await avanzar(3)


# --- 2 · mojar y helar: dos iconos -------------------------------------------------------------------------------------
func _caso_dos() -> void:
	var g: Combate3D = _guerrero()
	await avanzar(3)
	_golpear(g, "agua")
	await avanzar(3)
	_golpear(g, "hielo")
	await avanzar(3)
	_ok("2 mojado y helado: congelado > 0 y mojado > 0", g.congelado > 0.0 and g.mojado > 0.0, "%.2f %.2f" % [g.congelado, g.mojado])
	_ok("2 se ven DOS iconos: congelado y mojado (en el orden fijo de la tabla)", g.iconos_estado_visibles() == ["congelado", "mojado"], str(g.iconos_estado_visibles()))
	_ok("2 con las letras C y M", _letra(g, 0).text == "C" and _letra(g, 1).text == "M")
	_ok("2 centrados bajo la barra: uno a cada lado del eje", _letra(g, 0).position.x < 0.0 and _letra(g, 1).position.x > 0.0 and is_equal_approx(_letra(g, 0).position.x, -_letra(g, 1).position.x))
	_ok("2 el tercer y el cuarto hueco siguen ocultos", not _letra(g, 2).visible and not _letra(g, 3).visible)
	_limpiar()
	await avanzar(3)


# --- 3 · el rayo ---------------------------------------------------------------------------------------------------------
func _caso_rayo() -> void:
	var g: Combate3D = _guerrero()
	await avanzar(3)
	_golpear(g, "rayo")
	await avanzar(3)
	_ok("3 el rayo aturde (stun_timer > 0)", g.stun_timer > 0.0, str(g.stun_timer))
	_ok("3 se ve «electrificado» con la letra E", g.iconos_estado_visibles() == ["electrificado"] and _letra(g, 0).text == "E", str(g.iconos_estado_visibles()))
	# El guerrero de prueba está `quieto` y su IA no corre: no descuenta el aturdimiento solo. Se acaba a mano, como lo haría `_ia`, y el icono tiene que irse.
	g.stun_timer = 0.0
	await avanzar(3)
	_ok("3 acabado el aturdimiento el icono se va", g.iconos_estado_visibles().is_empty(), str(g.iconos_estado_visibles()))
	_limpiar()
	await avanzar(3)


# --- 4 · al expirar desaparecen -------------------------------------------------------------------------------------------
func _caso_expira() -> void:
	var g: Combate3D = _guerrero()
	await avanzar(3)
	_golpear(g, "hielo")
	await avanzar(3)
	_ok("4 helado: icono «congelado»", g.iconos_estado_visibles() == ["congelado"])
	var t: float = 0.0
	while g.congelado > 0.0 and t < 6.0:
		await avanzar(3)
		t += 0.1
	await avanzar(3)
	_ok("4 al expirar el hielo (%.1f s) el icono desaparece y su barra también" % t, g.congelado <= 0.0 and g.iconos_estado_visibles().is_empty() and not (g._iconos_estado[0]["barra"] as MeshInstance3D).visible)
	_golpear(g, "fuego")
	await avanzar(3)
	t = 0.0
	while g.quemando > 0.0 and t < 8.0:
		await avanzar(3)
		t += 0.1
	await avanzar(3)
	_ok("4 y lo mismo con la quemadura (%.1f s)" % t, g.quemando <= 0.0 and g.iconos_estado_visibles().is_empty())
	_ok("4 estados_activos() olvida el máximo visto (un estado nuevo vuelve a empezar lleno)", g.estados_activos().is_empty() and g._estado_visto_max.is_empty())
	_limpiar()
	await avanzar(3)


# --- 5 · ICONOS_ESTADO_SIEMPRE = false: solo con la barra ------------------------------------------------------------------
func _caso_solo_con_barra() -> void:
	Combate3D.ICONOS_ESTADO_SIEMPRE = false
	var g: Combate3D = _guerrero(100000.0)
	await avanzar(3)
	g.mojado = 4.0                            # un estado sin daño: la vida sigue llena y la barra, oculta (la quemadura la haría aparecer)
	await avanzar(3)
	_ok("5 vida llena, barra oculta, estado activo", g.mojado > 0.0 and not g._barra_vida.visible)
	_ok("5 con ICONOS_ESTADO_SIEMPRE = false NO se ve ningún icono", g.iconos_estado_visibles().is_empty(), str(g.iconos_estado_visibles()))
	g.health = g.vida_max * 0.5               # aparece la barra
	await avanzar(3)
	_ok("5 al bajar la vida la barra aparece…", g._barra_vida.visible)
	_ok("5 …y con ella el icono", g.iconos_estado_visibles() == ["mojado"], str(g.iconos_estado_visibles()))
	Combate3D.ICONOS_ESTADO_SIEMPRE = true
	g.health = g.vida_max
	g._barra_destello = 0.0
	g._vida_mostrada = 1.0
	await avanzar(3)
	_ok("5 con ICONOS_ESTADO_SIEMPRE = true se ve aunque la barra esté oculta", not g._barra_vida.visible and g.iconos_estado_visibles() == ["mojado"])
	_limpiar()
	await avanzar(3)


# --- 6 · sin sensación se siguen viendo -----------------------------------------------------------------------------------
func _caso_sin_sensacion() -> void:
	Sensacion3D.ACTIVA = false
	var g: Combate3D = _guerrero()
	await avanzar(3)
	_golpear(g, "fuego")
	await avanzar(3)
	_golpear(g, "agua")
	await avanzar(3)
	_ok("6 con Sensacion3D.ACTIVA = false los iconos se ven (son información, no sensación)", g.iconos_estado_visibles().size() >= 1 and _letra(g, 0).visible, str(g.iconos_estado_visibles()))
	Sensacion3D.ACTIVA = true
	_limpiar()
	await avanzar(3)


# --- 7 · como mucho 4 --------------------------------------------------------------------------------------------------------
func _caso_maximo() -> void:
	var g: Combate3D = _guerrero()
	await avanzar(3)
	g.quemando = 5.0
	g.congelado = 5.0
	g.envenenado = 5.0
	g.mojado = 5.0
	g.stun_timer = 5.0
	await avanzar(2)
	_ok("7 con los 5 estados a la vez hay 5 en estados_activos() pero solo 4 iconos", g.estados_activos().size() == 5 and g.iconos_estado_visibles().size() == Combate3D.MAX_ICONOS_ESTADO, str(g.iconos_estado_visibles()))
	_ok("7 son los cuatro primeros de la tabla (quemado, congelado, envenenado, mojado)", g.iconos_estado_visibles() == ["quemado", "congelado", "envenenado", "mojado"], str(g.iconos_estado_visibles()))
	_ok("7 el veneno lleva la letra V", _letra(g, 2).text == "V")
	_limpiar()
	await avanzar(3)


# --- 8 · elemental y muerto -----------------------------------------------------------------------------------------------------
func _caso_elemental_y_muerto() -> void:
	var g: Combate3D = _guerrero()
	await avanzar(3)
	g.quemando = 5.0
	await avanzar(2)
	_ok("8 (control) con quemadura se ve el icono", g.iconos_estado_visibles() == ["quemado"])
	g.elemental = true
	await avanzar(2)
	_ok("8 un elemental no muestra iconos (su barra es la grande de la pantalla)", g.iconos_estado_visibles().is_empty())
	g.elemental = false
	await avanzar(2)
	_ok("8 (control) sin la marca vuelven", g.iconos_estado_visibles() == ["quemado"])
	g.receive_damage(g.health + 10.0)
	await avanzar(4)
	_ok("8 muerto, los iconos se apagan", g.muerto and g.iconos_estado_visibles().is_empty(), "muerto=%s %s" % [str(g.muerto), str(g.iconos_estado_visibles())])
	_limpiar()
	await avanzar(3)


# --- 9 · letras y símbolos ---------------------------------------------------------------------------------------------------------
func _caso_simbolos() -> void:
	var g: Combate3D = _guerrero()
	await avanzar(3)
	g.quemando = 5.0
	g.mojado = 5.0
	await avanzar(2)
	_ok("9 por defecto, letras: Q y M", _letra(g, 0).text == "Q" and _letra(g, 1).text == "M")
	Combate3D.ICONOS_CON_SIMBOLOS = true
	await avanzar(2)
	_ok("9 con ICONOS_CON_SIMBOLOS: ♨ y ≈", _letra(g, 0).text == "♨" and _letra(g, 1).text == "≈", _letra(g, 0).text + _letra(g, 1).text)
	Combate3D.ICONOS_CON_SIMBOLOS = false
	_limpiar()
	await avanzar(3)
