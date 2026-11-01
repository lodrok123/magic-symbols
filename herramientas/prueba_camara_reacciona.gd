extends "res://herramientas/prueba_sensacion_2.gd"
## GAMEFEEL, TAREA C (1/11; presentacion/sensacion_3d.gd `retroceso_camara` / `temblor_golpe`, enemigos/combate_3d.gd `_impacto_visual`): la cámara reacciona.
## Sobre la escena real del Bosque, con --fixed-fps 30:
##   1 C1 el disparo con 1 glifo mueve la cámara ≥ 2 px y con 5 glifos ≥ 2× más, en sentido contrario al disparo; vuelve a la base en 0,15 s;
##   2 C1 por el Lanzador: la receta con más glifos retrocede más (flecha < flecha + ᚱ);
##   3 C1 + temblor: el retroceso convive con `Vfx3D.temblor` (antes, durante y con el temblor ya en marcha) y la cámara acaba EXACTAMENTE en su base;
##   4 C1 un retroceso nuevo sustituye al anterior (no se suman), y la barrera (no sale de la mano) no retrocede;
##   5 C2 el temblor de un golpe sigue a la fuerza del empujón (`_k_golpe` 0,6..1,6) con tope TEMBLOR_MAX; el débil mantiene TEMBLOR_DEBIL; el golpe F no tiembla;
##   6 C3 dos golpes en el mismo fotograma = UN temblor, con el mayor (no el último);
##   7 `ACTIVA` = false: la cámara no retrocede (quieta), y el temblor del golpe vuelve a ser el de siempre, en el acto.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_camara_reacciona.gd


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	Repertoire.activate_all()
	_vaciar_nivel()
	await avanzar(20)
	await _caso_retroceso()
	await _caso_lanzador()
	await _caso_temblor()
	await _caso_sustituye()
	await _caso_temblor_golpe()
	await _caso_mismo_fotograma()
	await _caso_apagada()
	print("COMPROBACIONES: %d" % _comprobaciones)


var _upx: float = 1.0


func _cam() -> Camera3D:
	return root.get_camera_3d()


func _off() -> Vector2:
	var c: Camera3D = _cam()
	return Vector2(c.h_offset, c.v_offset)


## Píxeles de pantalla de un desplazamiento, con la escala de la cámara EN REPOSO (el golpe de zoom del disparo la acerca un 2,5 % y agrandaría la medida).
func _px(v: Vector2) -> float:
	return v.length() / _upx


func _runa(el: String) -> RuneData:
	var runas: Dictionary = {"fuego": "fire", "agua": "water", "rayo": "lightning", "hielo": "ice", "tierra": "earth"}
	return load("res://nucleo/%s_rune.tres" % runas[el]) as RuneData


## Espera a que la cámara esté quieta y devuelve su base (offsets de reposo).
func _reposo() -> Vector2:
	await avanzar_s(0.5)
	_upx = Sensacion3D.unidades_por_pixel(_cam(), root)
	return _off()


# --- 1 · retroceso ----------------------------------------------------------------------------------------------------
func _caso_retroceso() -> void:
	var cam: Camera3D = _cam()
	_ok("1 hay cámara activa", cam != null)
	if cam == null:
		return
	var base: Vector2 = await _reposo()
	var dir: Vector3 = Vector3(1, 0, 0)
	var b: Basis = cam.global_transform.basis
	var pantalla := Vector2(dir.dot(b.x), dir.dot(b.y)).normalized()
	Sensacion3D.disparo(lanzador, "fuego", dir, jugador.position, true, 1)
	var uno: Vector2 = _off() - base
	_ok("1 un glifo: la cámara se mueve ≥ 2 px (%.2f px)" % _px(uno), _px(uno) >= 2.0 - 0.01)
	_ok("1 ... y no más de RETROCESO_CAM_MIN (%.2f px)" % _px(uno), _px(uno) <= Sensacion3D.RETROCESO_CAM_MIN + 0.01)
	_ok("1 ... en sentido contrario al disparo en pantalla", uno.normalized().dot(pantalla) < -0.99, str(uno.normalized().dot(pantalla)))
	await avanzar_s(0.15)
	_ok("1 vuelve a la base en 0,15 s", (_off() - base).length() < 1.0e-5, str((_off() - base).length()))
	Sensacion3D.disparo(lanzador, "fuego", dir, jugador.position, true, 5)
	var cinco: Vector2 = _off() - base
	_ok("1 cinco glifos: ≥ 2× más que uno (%.2f px frente a %.2f)" % [_px(cinco), _px(uno)], _px(cinco) >= 2.0 * _px(uno) - 0.01)
	_ok("1 ... y no más de RETROCESO_CAM_MAX (%.2f px)" % _px(cinco), _px(cinco) <= Sensacion3D.RETROCESO_CAM_MAX + 0.01)
	await avanzar_s(0.15)
	_ok("1 y otra vez a la base en 0,15 s", (_off() - base).length() < 1.0e-5, str((_off() - base).length()))
	var otro: Vector3 = Vector3(0, 0, 1)
	Sensacion3D.disparo(lanzador, "fuego", otro, jugador.position, true, 3)
	var tres: Vector2 = _off() - base
	var pant2 := Vector2(otro.dot(b.x), otro.dot(b.y)).normalized()
	_ok("1 otra dirección: sigue siendo la contraria (tres glifos, %.2f px)" % _px(tres), tres.normalized().dot(pant2) < -0.99 and _px(tres) > _px(uno) and _px(tres) < _px(cinco))
	await avanzar_s(0.3)


# --- 2 · por el Lanzador ----------------------------------------------------------------------------------------------
func _caso_lanzador() -> void:
	_jugadora(Vector2i(11, 33))
	var base: Vector2 = await _reposo()
	var d0: int = int(Sensacion3D.cuenta["disparo"])
	var salio1: bool = lanzar("fuego", ["flecha"], Vector3.RIGHT)
	var p1: float = _px(_off() - base)
	var disparo1: bool = int(Sensacion3D.cuenta["disparo"]) == d0 + 1
	await avanzar_s(0.5)
	var salio2: bool = lanzar("fuego", ["flecha", "raido"], Vector3.RIGHT)
	var p2: float = _px(_off() - base)
	await avanzar_s(0.5)
	_ok("2 las dos recetas salen y disparan", salio1 and salio2 and disparo1)
	_ok("2 con un glifo: RETROCESO_CAM_MIN (%.2f px)" % p1, absf(p1 - Sensacion3D.RETROCESO_CAM_MIN) < 0.05, str(p1))
	_ok("2 con dos glifos: más que con uno (%.2f px)" % p2, p2 > p1 + 0.5, str(p2))
	var n0: int = int(Sensacion3D.cuenta["retroceso_cam"])
	lanzar("tierra", ["barrera"], Vector3.RIGHT)
	await avanzar_s(0.5)
	_ok("2 la barrera (nace donde se apunta, no sale de la mano) no retrocede", int(Sensacion3D.cuenta["retroceso_cam"]) == n0)
	_vaciar_hechizos()


func _vaciar_hechizos() -> void:
	for h in _hechizos(maqueta):
		(h as Node).queue_free()


# --- 3 · convive con el temblor ---------------------------------------------------------------------------------------
func _caso_temblor() -> void:
	var fx: Vfx3D = maqueta.get("_fx") as Vfx3D
	_ok("3 la maqueta tiene Vfx3D", fx != null)
	if fx == null:
		return
	var base: Vector2 = await _reposo()
	# a) el temblor primero, el disparo en medio
	fx.temblor(0.8)
	await avanzar(2)
	Sensacion3D.disparo(lanzador, "fuego", Vector3.RIGHT, jugador.position, true, 5)
	await avanzar_s(0.6)
	_ok("3 temblor y, a los 2 fotogramas, retroceso de 5 glifos: la cámara acaba en su base", (_off() - base).length() < 1.0e-5 and not _cam().has_meta("temblor_base"), str(_off() - base))
	# b) el retroceso primero, el temblor encima
	Sensacion3D.disparo(lanzador, "fuego", Vector3.RIGHT, jugador.position, true, 5)
	await avanzar(1)
	fx.temblor(0.8)
	await avanzar_s(0.6)
	_ok("3 retroceso y, al fotograma, temblor: acaba en su base", (_off() - base).length() < 1.0e-5 and not _cam().has_meta("temblor_base"), str(_off() - base))
	# c) los dos en el mismo instante
	fx.temblor(0.8)
	Sensacion3D.disparo(lanzador, "fuego", Vector3.RIGHT, jugador.position, true, 5)
	await avanzar_s(0.6)
	_ok("3 temblor y retroceso a la vez: acaba en su base", (_off() - base).length() < 1.0e-5 and not _cam().has_meta("temblor_base"), str(_off() - base))
	# d) disparos seguidos dentro del temblor
	fx.temblor(1.0)
	for _i in range(3):
		Sensacion3D.disparo(lanzador, "fuego", Vector3.RIGHT, jugador.position, true, 4)
		await avanzar(2)
	await avanzar_s(0.8)
	_ok("3 tres disparos dentro de un temblor: acaba en su base", (_off() - base).length() < 1.0e-5 and not _cam().has_meta("temblor_base"), str(_off() - base))
	_ok("3 y sin metas ni vigilante colgando", not _cam().has_meta("retro_aplicado") and _cam().get_node_or_null("VigilaRetroceso") == null)
	# e) una base que no es cero (el laboratorio desplaza la vista): se conserva
	_cam().h_offset = base.x + 0.37
	var base2: Vector2 = _off()
	fx.temblor(0.6)
	Sensacion3D.disparo(lanzador, "fuego", Vector3.RIGHT, jugador.position, true, 5)
	await avanzar_s(0.8)
	_ok("3 con la cámara ya desplazada (+0,37): vuelve a ESA base", (_off() - base2).length() < 1.0e-5, str(_off() - base2))
	_cam().h_offset = base.x


# --- 4 · sustituye, no suma ---------------------------------------------------------------------------------------------
func _caso_sustituye() -> void:
	var base: Vector2 = await _reposo()
	Sensacion3D.disparo(lanzador, "fuego", Vector3.RIGHT, jugador.position, true, 5)
	var a: float = _px(_off() - base)
	await avanzar(1)
	Sensacion3D.disparo(lanzador, "fuego", Vector3.RIGHT, jugador.position, true, 5)
	var b: float = _px(_off() - base)
	_ok("4 un segundo disparo a medias del primero no suma (%.2f px y %.2f px, tope %.1f)" % [a, b, Sensacion3D.RETROCESO_CAM_MAX], b <= Sensacion3D.RETROCESO_CAM_MAX + 0.01)
	await avanzar_s(0.3)
	_ok("4 y vuelve a la base", (_off() - base).length() < 1.0e-5)


# --- 5 · temblor por daño -----------------------------------------------------------------------------------------------
func _caso_temblor_golpe() -> void:
	_jugadora(Vector2i(11, 33))
	var g: Combate3D = _goblin(Vector2i(9, 33))
	await avanzar(3)
	g._k_golpe = 0.6
	g._impacto_visual("fuego", false, Vector3(-1, 0, 0))
	await avanzar(1)
	var flojo: float = Sensacion3D.ultimo_temblor
	await avanzar_s(0.4)
	g._k_golpe = 1.0
	g._impacto_visual("fuego", false, Vector3(-1, 0, 0))
	await avanzar(1)
	var normal: float = Sensacion3D.ultimo_temblor
	await avanzar_s(0.4)
	g._k_golpe = 1.6
	g._impacto_visual("fuego", false, Vector3(-1, 0, 0))
	await avanzar(1)
	var fuerte: float = Sensacion3D.ultimo_temblor
	await avanzar_s(0.4)
	_ok("5 empujón flojo (k 0,6): TEMBLOR_GOLPE × 0,6 = %.3f" % flojo, absf(flojo - Combate3D.TEMBLOR_GOLPE * 0.6) < 0.001)
	_ok("5 empujón normal (k 1): TEMBLOR_GOLPE = %.3f" % normal, absf(normal - Combate3D.TEMBLOR_GOLPE) < 0.001)
	_ok("5 empujón fuerte (k 1,6): TEMBLOR_GOLPE × 1,6 = %.3f, más que el normal y el flojo" % fuerte, absf(fuerte - minf(Combate3D.TEMBLOR_GOLPE * 1.6, Combate3D.TEMBLOR_MAX)) < 0.001 and fuerte > normal and normal > flojo)
	var tope: float = Combate3D.TEMBLOR_MAX
	Combate3D.TEMBLOR_MAX = 0.3
	g._k_golpe = 1.6
	g._impacto_visual("fuego", false, Vector3(-1, 0, 0))
	await avanzar(1)
	_ok("5 con TEMBLOR_MAX = 0,3 el temblor no pasa de 0,3 (%.3f)" % Sensacion3D.ultimo_temblor, absf(Sensacion3D.ultimo_temblor - 0.3) < 0.001)
	Combate3D.TEMBLOR_MAX = tope
	await avanzar_s(0.4)
	g._k_golpe = 1.6
	g._impacto_visual("agua", true, Vector3(-1, 0, 0))
	await avanzar(1)
	_ok("5 con debilidad se mantiene TEMBLOR_DEBIL (%.3f), sin multiplicar" % Sensacion3D.ultimo_temblor, absf(Sensacion3D.ultimo_temblor - Combate3D.TEMBLOR_DEBIL) < 0.001)
	await avanzar_s(0.4)
	var t0: int = int(Sensacion3D.cuenta["temblor_golpe"])
	g.recibir_golpe_cuerpo(Vector3(-1, 0, 0), 5.0, 0.0)
	await avanzar(2)
	_ok("5 el golpe F (sin elemento) no tiembla más que antes: no tiembla", int(Sensacion3D.cuenta["temblor_golpe"]) == t0)
	await avanzar_s(0.4)
	var t1: int = int(Sensacion3D.cuenta["temblor_golpe"])
	g.on_spell_hit(_runa("fuego"), Vector3(-1, 0, 0))
	await avanzar(2)
	_ok("5 un hechizo real sí tiembla", int(Sensacion3D.cuenta["temblor_golpe"]) == t1 + 1 and Sensacion3D.ultimo_temblor > 0.0, str(Sensacion3D.ultimo_temblor))
	_limpiar()
	await avanzar_s(0.5)


# --- 6 · el mismo fotograma ---------------------------------------------------------------------------------------------
func _caso_mismo_fotograma() -> void:
	_jugadora(Vector2i(11, 33))
	var a: Combate3D = _goblin(Vector2i(9, 33))
	var b: Combate3D = _goblin(Vector2i(9, 35))
	var c: Combate3D = _goblin(Vector2i(9, 31))
	await avanzar(3)
	var t0: int = int(Sensacion3D.cuenta["temblor_golpe"])
	a._k_golpe = 1.6                                           # el más fuerte va PRIMERO: el último no debe ganar
	a._impacto_visual("fuego", false, Vector3(-1, 0, 0))
	b._k_golpe = 0.6
	b._impacto_visual("fuego", false, Vector3(-1, 0, 0))
	c._k_golpe = 1.0
	c._impacto_visual("fuego", false, Vector3(-1, 0, 0))
	_ok("6 en el mismo fotograma todavía no ha temblado nadie", int(Sensacion3D.cuenta["temblor_golpe"]) == t0)
	await avanzar(1)
	_ok("6 tres golpes en el mismo fotograma = UN temblor", int(Sensacion3D.cuenta["temblor_golpe"]) == t0 + 1, str(int(Sensacion3D.cuenta["temblor_golpe"]) - t0))
	_ok("6 ... con el mayor (%.3f, el de k 1,6) y no el último" % Sensacion3D.ultimo_temblor, absf(Sensacion3D.ultimo_temblor - Combate3D.TEMBLOR_GOLPE * 1.6) < 0.001)
	await avanzar_s(0.4)
	b._k_golpe = 0.6
	b._impacto_visual("fuego", false, Vector3(-1, 0, 0))
	await avanzar(1)
	a._k_golpe = 1.6
	a._impacto_visual("fuego", false, Vector3(-1, 0, 0))
	await avanzar(1)
	_ok("6 en fotogramas distintos sí son dos temblores", int(Sensacion3D.cuenta["temblor_golpe"]) == t0 + 3)
	_limpiar()
	await avanzar_s(0.5)


# --- 7 · apagada ---------------------------------------------------------------------------------------------------------
func _caso_apagada() -> void:
	_jugadora(Vector2i(11, 33))
	var base: Vector2 = await _reposo()
	Sensacion3D.ACTIVA = false
	var r0: int = int(Sensacion3D.cuenta["retroceso_cam"])
	Sensacion3D.disparo(lanzador, "fuego", Vector3.RIGHT, jugador.position, true, 5)
	var quieta: bool = (_off() - base).length() < 1.0e-6
	await avanzar(2)
	quieta = quieta and (_off() - base).length() < 1.0e-6
	_ok("7 ACTIVA = false: el disparo no mueve la cámara", quieta and int(Sensacion3D.cuenta["retroceso_cam"]) == r0)
	var g: Combate3D = _goblin(Vector2i(9, 33))
	await avanzar(3)
	var t0: int = int(Sensacion3D.cuenta["temblor_golpe"])
	g._k_golpe = 1.6
	g._impacto_visual("fuego", false, Vector3(-1, 0, 0))
	await avanzar(1)
	var movida: bool = _cam().has_meta("temblor_base")
	_ok("7 ACTIVA = false: el golpe tiembla como siempre (en el acto, sin multiplicar por la fuerza), sin pasar por el pendiente", movida and int(Sensacion3D.cuenta["temblor_golpe"]) == t0)
	Sensacion3D.ACTIVA = true
	await avanzar_s(0.5)
	_ok("7 y la cámara acaba en su base", (_off() - base).length() < 1.0e-5)
	_limpiar()
	await avanzar_s(0.3)
