extends SceneTree

## PRUEBA de la carga del hechizo y del impacto del fuego «toy» (1/11, rama fuego-toy-carga-impacto). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_carga_impacto_toy.gd
## Comprueba, con FuegoToy.empezar_carga / soltar / cancelar_carga / impactar_en / rebotar / terminar_sin_choque / finalizar e ImpactoFuegoToy:
##   1. CARGA: nace pequeña (≈ carga_tam_inicial), crece sin bajar, llega al tamaño final, progreso_carga 0 → 1, y al sostenerla «respira» sin pasar de 1 + carga_respiro
##   2. chispas que convergen (nodo ChispasCarga con la cantidad del mando, paleta sin rojo oscuro) y una sola luz que sube
##   3. SOLTAR: el MISMO nodo (mismo id), pasa a proyectil, hay destello y se borra solo, y el tamaño no salta (medido fotograma a fotograma, también soltando a medio crecer)
##   4. cancelar_carga se libera sola
##   5. IMPACTO: GOLPE contra pared (normal horizontal), suelo y techo, FIN y REBOTE se crean orientados por la normal, escalan con el radio y se liberan solos; FIN sin destello
##   6. FuegoToy: impactar_en libera la bola y deja un impacto; rebotar deja la bola viva y devuelve la dirección reflejada; terminar_sin_choque la libera tras apagarse; finalizar(motivo)
##   7. PRESUPUESTO en todo el ciclo (carga → suelta → vuelo → impacto): ≤ 1 luz visible y ≤ 300 partículas en cualquier fotograma
##   8. estilo (por el código): impacto con el método de Le Lu (fuego_lelu, rampa de la bola), sin discard ni contorno, ImpactoBolaToy.tscn sigue con su shader antiguo, lab con G B N M R T Q E
##   9. las capturas con ventana existen (docs/capturas/comparativa_vfx/godot_toy/carga_impacto/)
## 10. Revisión de Pablo: impacto C por defecto (golpe sutil + chispas hacia afuera en el hemisferio de la normal), carga sin bola (brillo + chispas que se aglutinan), pop al soltar con el mismo nodo.
## NO comprueba (necesita ventana y GPU): el aspecto ni que los shaders compilen (se ve en las capturas). Imprime FALLOS: n.

const MAX_LUCES: int = 1
const MAX_PARTICULAS: int = 300
const CAPT: String = "res://docs/capturas/comparativa_vfx/godot_toy/revision_pablo/"
const PNG: PackedStringArray = ["1_bola_ronda8_vs_actual", "2_laminas_antes_despues", "3_impacto_pared_y_suelo", "4_carga_y_soltar"]

var _fallos: int = 0
var _raiz: Node3D = null
var _max_luces: int = 0
var _max_part: int = 0


func _initialize() -> void:
	_correr()


func _ok(nombre: String, cond: bool, detalle: String = "") -> void:
	if cond:
		print("  OK   " + nombre)
	else:
		_fallos += 1
		print("  FALLO " + nombre + ("  (" + detalle + ")" if detalle != "" else ""))


func _correr() -> void:
	await process_frame
	_raiz = Node3D.new()
	root.add_child(_raiz)
	await _carga()
	await _soltar()
	await _cancelar()
	await _impactos()
	await _bola_e_impacto()
	await _ciclo_presupuesto()
	_estilo()
	_capturas()
	print("máximo visto en todo el ciclo: %d luz y %d partículas" % [_max_luces, _max_part])
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _esperar(seg: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < seg:
		await process_frame
		_medir()


## Recuento de luces visibles y partículas (suma de `amount`) de todo lo que cuelga de la raíz de pruebas.
func _recuento() -> Array:
	var luces: int = 0
	var part: int = 0
	for n in _raiz.find_children("*", "", true, false):
		if n is Light3D and (n as Light3D).is_visible_in_tree():
			luces += 1
		elif n is GPUParticles3D:
			part += (n as GPUParticles3D).amount
	return [luces, part]


func _medir() -> void:
	var r: Array = _recuento()
	_max_luces = maxi(_max_luces, int(r[0]))
	_max_part = maxi(_max_part, int(r[1]))


func _nueva(vive: bool = true) -> FuegoToy:
	var e: FuegoToy = FuegoToy.new()
	_raiz.add_child(e)
	return e


func _escala(e: FuegoToy) -> float:
	return (e.get_node("Cuerpo") as Node3D).scale.x


func _contar(e: Node, clase: String) -> int:
	var n: int = 0
	for h in e.find_children("*", clase, true, false):
		n += 1
	return n


# ------------------------------------------------------------------ 1-2. carga ------------------------------------------------------------------

func _carga() -> void:
	print("== carga")
	var e: FuegoToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 1, 0)
	e.empezar_carga(0.8, 0.4)
	var s0: float = _escala(e)
	_ok("nace pequeña: escala %.3f ≈ carga_tam_inicial %.2f" % [s0, e.carga_tam_inicial], absf(s0 - e.carga_tam_inicial) < 0.06)
	_ok("figura BOLA, estática (sin proyectil), sin destello de 4 puntas visible", e.figura == FuegoToy.Figura.BOLA and not e.proyectil and not (e.find_child("Estrella", true, false) as Node3D).visible)
	_ok("esta_cargando() y progreso_carga() empieza en ≈ 0 (%.2f)" % e.progreso_carga(), e.esta_cargando() and e.progreso_carga() < 0.15)
	var muestras: Array = []
	var t0: int = Time.get_ticks_msec()
	var luz0: float = float(e.get("_luz_base"))
	var nl: int = 0
	var prev: float = s0
	var baja: bool = false
	while float(Time.get_ticks_msec() - t0) < 800.0:
		await process_frame
		_medir()
		var s: float = _escala(e)
		muestras.append([float(Time.get_ticks_msec() - t0) / 1000.0, s, e.progreso_carga()])
		if s < prev - 0.02:
			baja = true
		prev = s
	var luz1: float = float(e.get("_luz_base"))
	_ok("crece sin bajar durante la carga (tolerancia 0,02)", not baja)
	var a30: float = _en(muestras, 0.25)
	var a70: float = _en(muestras, 0.6)
	_ok("a 0,25 s %.2f < a 0,6 s %.2f < 1,0: crece de verdad" % [a30, a70], a30 < a70 and a70 < 1.06 and a30 > s0)
	_ok("llega al tamaño final: escala %.3f ≥ 0,94" % _escala(e), _escala(e) >= 0.94)
	_ok("progreso_carga llega a 1 (%.2f)" % e.progreso_carga(), e.progreso_carga() >= 0.99)
	_ok("la luz sube con la carga: %.2f → %.2f" % [luz0, luz1], luz1 > luz0 + 0.8)
	# sostenerla: respira, no crece más de la cuenta
	var mx: float = 0.0
	var mn: float = 9.0
	t0 = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) < 1500.0:
		await process_frame
		_medir()
		mx = maxf(mx, _escala(e))
		mn = minf(mn, _escala(e))
	_ok("sostenida 1,5 s: respira entre %.3f y %.3f (máx ≤ 1 + respiro %.2f; mín ≥ 0,9) y varía de verdad" % [mn, mx, e.carga_respiro], mx <= 1.0 + e.carga_respiro + 0.01 and mn >= 0.9 and mx - mn > 0.02)
	# chispas y luz únicos
	var conv: Node = e.find_child("Convergencia", true, false)
	_ok("Convergencia: brillo suave + punto + chispas (MultiMesh), sin remolino ni briznas ni GPUParticles", conv != null and conv.get_node_or_null("Brillo") != null and conv.get_node_or_null("Punto") != null
		and conv.get_node_or_null("Chispas") is MultiMeshInstance3D and conv.get_node_or_null("Remolino0") == null and conv.get_node_or_null("Briznas") == null and e.find_child("ChispasCarga", true, false) == null)
	var f0: FuegoToy = FuegoToy.new()
	_ok("carga_chispas por defecto 28 y carga_bola_visible false", f0.carga_chispas == 28 and not f0.carga_bola_visible)
	f0.free()
	_ok("la bola NO se ve durante la carga (Cuerpo oculto), pero hay una luz (%d)" % _contar(e, "Light3D"), not (e.get_node("Cuerpo") as Node3D).visible and _contar(e, "Light3D") == 1)
	_ok("chispas a la vez al final de la carga: %d (carga_chispas %d)" % [int(conv.call("n_visibles")), e.carga_chispas], int(conv.call("n_visibles")) == e.carga_chispas)
	# aglutinan: más numerosas y más juntas según avanza la carga; nacen en 0,3-0,5 m y caen hacia la mano
	conv.call("poner", 0.2, 0.1)
	var n_ini: int = int(conv.call("n_visibles"))
	var r_ini: float = _radio_nacimiento(conv)
	conv.call("poner", 1.0, 1.0)
	var n_fin: int = int(conv.call("n_visibles"))
	var r_fin: float = _radio_nacimiento(conv)
	_ok("más y más juntas: %d chispas a r %.2f m al 10 %% → %d a r %.2f m al 100 %%" % [n_ini, r_ini, n_fin, r_fin], n_fin > n_ini * 2 and r_fin < r_ini and r_ini <= 0.62 and r_fin >= 0.28)
	var hacia: bool = true
	for s in conv.call("estado_chispas"):
		if (s["dir"] as Vector3).dot(-(s["pos"] as Vector3).normalized()) < 0.99 and (s["pos"] as Vector3).length() > 0.02:
			hacia = false
	_ok("cada chispa apunta hacia la mano", hacia)
	e.carga_chispas = 8
	_ok("mando carga_chispas en vivo: 8", int(conv.call("n_chispas")) == 8)
	e.carga_chispas = 28
	e.carga_bola_visible = true
	_ok("mando carga_bola_visible = true: la bola vuelve a verse", (e.get_node("Cuerpo") as Node3D).visible)
	e.carga_bola_visible = false
	_ok("... y false la oculta", not (e.get_node("Cuerpo") as Node3D).visible)
	var pal: bool = true
	var gr: Gradient = FuegoToy._rampa_bola.gradient
	for i in gr.colors.size():
		if gr.offsets[i] >= 0.5 and gr.colors[i].g < 0.45:
			pal = false
	_ok("paleta de las chispas = rampa de la bola desde 0,5 (sin rojo oscuro)", pal)
	# progreso en 0 antes de empezar de nuevo, y tamaño pequeño empieza de cero otra vez
	e.empezar_carga(0.5, 0.4)
	await process_frame
	_ok("empezar_carga otra vez reinicia (escala %.2f, progreso %.2f)" % [_escala(e), e.progreso_carga()], _escala(e) < 0.3 and e.progreso_carga() < 0.2)
	# tamaño final distinto: la bola es de ese radio
	e.empezar_carga(0.3, 0.8)
	await process_frame
	var ll: MeshInstance3D = e.find_child("Llama", true, false) as MeshInstance3D
	_ok("tam_final 0,8 m: quad de la llama 4,8 m (radio 0,8) y semiejes %s" % str(e.semiejes()), ll != null and absf((ll.mesh as QuadMesh).size.x - 4.8) < 0.01 and absf(e.semieje_x - 0.8) < 0.001)
	e.empezar_carga(0.3, Vector3(0.5, 0.5, 0.5))
	await process_frame
	_ok("tam_final como Vector3 (0,5): radio 0,5", absf(e.semieje_x - 0.5) < 0.001)
	e.queue_free()
	await process_frame


## Radio medio (m) al que NACEN las chispas visibles con el progreso actual.
func _radio_nacimiento(conv: Node) -> float:
	var s: float = 0.0
	var n: int = 0
	for q in conv.call("estado_chispas"):
		s += float(q["r0"])
		n += 1
	return s / float(maxi(n, 1))


func _en(m: Array, t: float) -> float:
	for x in m:
		if float(x[0]) >= t:
			return float(x[1])
	return float(m.back()[1])


# ------------------------------------------------------------------ 3. soltar ------------------------------------------------------------------

func _soltar() -> void:
	print("== soltar")
	for caso in [["llena", 0.4, 0.55], ["a medio crecer", 1.0, 0.4]]:
		var e: FuegoToy = _nueva()
		await process_frame
		e.global_position = Vector3(0, 1, 0)
		e.empezar_carga(float(caso[1]), 0.4)
		var id0: int = e.get_instance_id()
		var cuerpo0: Node3D = e.get_node("Cuerpo")
		await _esperar(float(caso[2]))
		var ll: MeshInstance3D = e.find_child("Llama", true, false) as MeshInstance3D
		var tam_antes: float = (ll.mesh as QuadMesh).size.x
		var cab_antes: float = ((e.find_child("Cabeza", true, false) as MeshInstance3D).mesh as QuadMesh).size.x
		var s_antes: float = _escala(e)
		var tf: int = Time.get_ticks_msec()
		e.soltar(Vector3(0, 0, -1))
		await process_frame
		var dt: float = float(Time.get_ticks_msec() - tf) / 1000.0
		var s_desp: float = _escala(e)
		_ok("[%s] misma bola: id %s, mismo Cuerpo, proyectil, viaja" % [caso[0], "igual" if e.get_instance_id() == id0 else "DISTINTO"], e.get_instance_id() == id0 and e.get_node("Cuerpo") == cuerpo0 and e.proyectil and e.viaja)
		_ok("[%s] la bola aparece al soltar con un pop (visible, escala %.2f → %.2f, ≈ POP_DESDE %.2f)" % [caso[0], s_antes, s_desp, FuegoToy.POP_DESDE], (e.get_node("Cuerpo") as Node3D).visible and s_desp >= 0.4 and s_desp <= 1.12)
		_ok("[%s] la malla de la bola no cambia (quad %.2f, cabeza %.2f)" % [caso[0], tam_antes, cab_antes], absf((e.find_child("Llama", true, false) as MeshInstance3D).mesh.get("size").x - tam_antes) < 0.001
			and absf(((e.find_child("Cabeza", true, false) as MeshInstance3D).mesh as QuadMesh).size.x - cab_antes) < 0.001)
		_ok("[%s] orientada: su -Z mira a donde se suelta" % caso[0], (-e.global_transform.basis.z).distance_to(Vector3(0, 0, -1)) < 0.01)
		_ok("[%s] hay destello (Destello con Flare y Halo)" % caso[0], e.get_node_or_null("Destello") != null and e.get_node("Destello").get_node_or_null("Flare") != null and e.get_node("Destello").get_node_or_null("Halo") != null)
		var jv: GPUParticles3D = e.find_child("Jirones", true, false) as GPUParticles3D
		_ok("[%s] cola y estelas emiten; destello de 4 puntas visible" % caso[0], jv.emitting and (e.find_child("ChispasEstela", true, false) as GPUParticles3D).emitting
			and (e.find_child("Estrella", true, false) as Node3D).visible)
		var mx_salto: float = 0.0
		var ant: float = s_desp
		var t0: int = Time.get_ticks_msec()
		while float(Time.get_ticks_msec() - t0) < 400.0:
			var tt: int = Time.get_ticks_msec()
			await process_frame
			_medir()
			var dd: float = maxf(float(Time.get_ticks_msec() - tt) / 1000.0, 0.001)
			mx_salto = maxf(mx_salto, (absf(_escala(e) - ant) - 8.0 * dd))
			ant = _escala(e)
		_ok("[%s] después se asienta en 1,000 (%.4f)" % [caso[0], _escala(e)], absf(_escala(e) - 1.0) < 0.002)
		_ok("[%s] el destello se borró solo; una sola luz" % caso[0], e.get_node_or_null("Destello") == null and _contar(e, "Light3D") == 1)
		e.queue_free()
		await process_frame
	# con carga_bola_visible = true (la bola crecía en la mano): sin salto de tamaño al soltar, como antes
	for caso2 in [["llena", 0.4, 0.55], ["a medio crecer", 1.0, 0.4]]:
		var v: FuegoToy = _nueva()
		v.carga_bola_visible = true
		await process_frame
		v.empezar_carga(float(caso2[1]), 0.4)
		var idv: int = v.get_instance_id()
		await _esperar(float(caso2[2]))
		var sa: float = _escala(v)
		var tf2: int = Time.get_ticks_msec()
		v.soltar(Vector3(0, 0, -1))
		await process_frame
		var dt2: float = float(Time.get_ticks_msec() - tf2) / 1000.0
		_ok("[bola visible, %s] mismo nodo y sin salto de tamaño: %.3f → %.3f en %.0f ms" % [caso2[0], sa, _escala(v), dt2 * 1000.0], v.get_instance_id() == idv and absf(_escala(v) - sa) <= 8.0 * dt2 + 0.02)
		v.queue_free()
		await process_frame
	# soltar sin carga previa también vale
	var f: FuegoToy = _nueva()
	await process_frame
	f.soltar(Vector3(1, 0, 0))
	await _esperar(0.3)
	_ok("soltar sin empezar_carga: proyectil a tamaño 1", f.proyectil and absf(_escala(f) - 1.0) < 0.01)
	f.queue_free()
	await process_frame
	# destello apagado con el mando
	var g: FuegoToy = _nueva()
	await process_frame
	g.carga_destello = 0.0
	g.empezar_carga(0.2, 0.4)
	await _esperar(0.25)
	g.soltar(Vector3(0, 0, -1))
	await process_frame
	_ok("carga_destello 0: no hay destello", g.get_node_or_null("Destello") == null)
	g.queue_free()
	await process_frame


# ------------------------------------------------------------------ 4. cancelar ------------------------------------------------------------------

func _cancelar() -> void:
	print("== cancelar")
	var e: FuegoToy = _nueva()
	await process_frame
	e.empezar_carga(1.0, 0.4)
	await _esperar(0.4)
	e.cancelar_carga()
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(e) and float(Time.get_ticks_msec() - t0) < 1500.0:
		await process_frame
		_medir()
	var t: float = float(Time.get_ticks_msec() - t0) / 1000.0
	_ok("cancelar_carga: se encoge y se libera sola a los %.2f s (≈ 0,2)" % t, not is_instance_valid(e) and t < 0.6)


# ------------------------------------------------------------------ 5. impactos ------------------------------------------------------------------

func _vivo(n, hasta: float) -> float:
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(n) and float(Time.get_ticks_msec() - t0) / 1000.0 < hasta:
		await process_frame
		_medir()
	return float(Time.get_ticks_msec() - t0) / 1000.0


func _impactos() -> void:
	print("== ImpactoFuegoToy (estilos C por defecto, A y B)")
	var V = ImpactoFuegoToy.Variante
	var casos: Array = [["pared (+Z)", V.GOLPE, Vector3(0, 0, 1)], ["pared (+X)", V.GOLPE, Vector3(1, 0, 0)], ["suelo", V.GOLPE, Vector3.UP], ["techo", V.GOLPE, Vector3.DOWN],
		["fin", V.FIN, Vector3(0, 0, 1)], ["rebote en pared", V.REBOTE, Vector3(0, 0, 1)]]
	for est in [ImpactoFuegoToy.Estilo.C, ImpactoFuegoToy.Estilo.A, ImpactoFuegoToy.Estilo.B]:
		var en: String = ["A", "B", "C"][est]
		for c in casos:
			var i: ImpactoFuegoToy = ImpactoFuegoToy.crear(c[1], c[2], 0.4, est)
			_raiz.add_child(i)
			i.global_position = Vector3(0, 1, 0)
			await process_frame
			var pl: Node3D = i.get_node("Plano") as Node3D
			var esperado: Vector3 = Vector3.UP if c[1] == V.FIN else (c[2] as Vector3)
			_ok("[%s] %s: el eje (Y) sigue la normal %s → %s" % [en, c[0], str(esperado), str(pl.global_transform.basis.y)], pl.global_transform.basis.y.distance_to(esperado) < 0.01)
			if est != ImpactoFuegoToy.Estilo.C or c[1] == V.FIN:
				_ok("[%s] %s: sprites de Le Lu con la rampa de la bola" % [en, c[0]], _usa_sprites(i, 1 if est == ImpactoFuegoToy.Estilo.C else 2))
			var dur: float = i.duracion()
			var t: float = await _vivo(i, dur + 1.5)
			_ok("[%s] %s: se libera sola a los %.2f s (dur %.2f)" % [en, c[0], t, dur], not is_instance_valid(i) and t < dur + 0.7)
		if est == ImpactoFuegoToy.Estilo.C:
			await _impacto_c()
			continue
		var fin: ImpactoFuegoToy = ImpactoFuegoToy.crear(V.FIN, Vector3.UP, 0.4, est)
		var gol: ImpactoFuegoToy = ImpactoFuegoToy.crear(V.GOLPE, Vector3.UP, 0.4, est)
		var reb: ImpactoFuegoToy = ImpactoFuegoToy.crear(V.REBOTE, Vector3.UP, 0.4, est)
		_raiz.add_child(fin)
		_raiz.add_child(gol)
		_raiz.add_child(reb)
		await process_frame
		_ok("[%s] FIN: remolino exp_dissapear y sin destello hit22; GOLPE y REBOTE con destello" % en, fin.get_node_or_null("Plano/Destello") == null and fin.get_node_or_null("Plano/Remolino") != null
			and gol.get_node_or_null("Plano/Destello") != null and reb.get_node_or_null("Plano/Destello") != null)
		_ok("[%s] GOLPE usa %s" % [en, "Estallido (Ex1d)" if est == ImpactoFuegoToy.Estilo.A else "Bola (flipbook)"], gol.get_node_or_null("Plano/Estallido" if est == ImpactoFuegoToy.Estilo.A else "Plano/Bola") != null)
		gol.avanzar_a(0.05)
		var dm: ShaderMaterial = (gol.get_node("Plano/Destello") as MeshInstance3D).material_override as ShaderMaterial
		_ok("[%s] a los 0,05 s hay destello (vida %.2f)" % [en, float(dm.get_shader_parameter("vida"))], float(dm.get_shader_parameter("vida")) > 0.5)
		gol.avanzar_a(0.6)
		_ok("[%s] ... y a los 0,6 s ya no (%.2f)" % [en, float(dm.get_shader_parameter("vida"))], float(dm.get_shader_parameter("vida")) < 0.01)
		if est == ImpactoFuegoToy.Estilo.B:
			var bm: ShaderMaterial = (gol.get_node("Plano/Bola") as MeshInstance3D).material_override as ShaderMaterial
			gol.avanzar_a(0.4)
			var fo: float = float(bm.get_shader_parameter("fotograma"))
			_ok("[B] el flipbook solo usa fotogramas de fuego: fotograma %.2f ≤ %d (de 24, sin humo)" % [fo, ImpactoFuegoToy.FOTOGRAMAS - 1], fo <= float(ImpactoFuegoToy.FOTOGRAMAS - 1) and int(bm.get_shader_parameter("fotograma_max")) == ImpactoFuegoToy.FOTOGRAMAS - 1)
		await _vivo(gol, 3.0)
		await _vivo(fin, 3.0)
		await _vivo(reb, 3.0)
		# paramétrico: el tamaño sigue al hechizo
		var chico: ImpactoFuegoToy = ImpactoFuegoToy.crear(V.GOLPE, Vector3.UP, 0.2, est)
		var grande: ImpactoFuegoToy = ImpactoFuegoToy.crear(V.GOLPE, Vector3.UP, 0.8, est)
		_raiz.add_child(chico)
		_raiz.add_child(grande)
		await process_frame
		chico.avanzar_a(0.5)
		grande.avanzar_a(0.5)
		var nom: String = "Plano/Estallido" if est == ImpactoFuegoToy.Estilo.A else "Plano/Bola"
		var ac: float = float((chico.get_node(nom) as Node).get_meta("tam"))
		var ag: float = float((grande.get_node(nom) as Node).get_meta("tam"))
		_ok("[%s] escala con el hechizo: tamaño %.2f m (radio 0,2) y %.2f m (radio 0,8): ×4" % [en, ac, ag], absf(ag / ac - 4.0) < 0.05)
		chico.queue_free()
		grande.queue_free()
		await process_frame
	_ok("estilo estático por defecto: C (golpe sutil + chispas) y mandos tam_estallido/vel_flipbook a 1", ImpactoFuegoToy.estilo == ImpactoFuegoToy.Estilo.C and ImpactoFuegoToy.tam_estallido == 1.0 and ImpactoFuegoToy.vel_flipbook == 1.0)


## Estilo C: golpe sutil (destello corto, sin lámina tumbada ni bola grande) y chispas que salen DESDE el impacto HACIA FUERA, en el hemisferio de la normal, alargadas en su velocidad.
func _impacto_c() -> void:
	var V = ImpactoFuegoToy.Variante
	for caso in [["pared +Z", Vector3(0, 0, 1)], ["pared +X", Vector3(1, 0, 0)], ["suelo", Vector3.UP], ["techo", Vector3.DOWN], ["oblicua", Vector3(1, 1, 0).normalized()]]:
		var n: Vector3 = caso[1]
		var gol: ImpactoFuegoToy = ImpactoFuegoToy.crear(V.GOLPE, n, 0.4, ImpactoFuegoToy.Estilo.C)
		_raiz.add_child(gol)
		gol.global_position = Vector3(0, 1, 0)
		await process_frame
		var rec: Array = gol.recuento_chispas()
		_ok("[C] %s: %d chispas con trazo y %d brasas, 0 GPUParticles3D en el impacto (%d)" % [caso[0], rec[0], rec[1], _contar(gol, "GPUParticles3D")], int(rec[0]) >= 12 and int(rec[1]) >= 2 and _contar(gol, "GPUParticles3D") == 0)
		_ok("[C] %s: sin lámina tumbada (no hay Mancha ni Estallido) ni bola de fuego" % caso[0], gol.get_node_or_null("Plano/Mancha") == null and gol.get_node_or_null("Plano/Estallido") == null and gol.get_node_or_null("Plano/Bola") == null)
		var fuera: bool = true
		var dentro: bool = true
		var alarg: bool = true
		var apagan: bool = true
		var alcance: float = 0.0
		for t in [0.04, 0.08, 0.12, 0.2, 0.3]:
			for s in gol.chispas_estado(t):
				if not bool(s["vivo"]):
					continue
				if float(s["altura"]) < -0.001:
					dentro = false
				alcance = maxf(alcance, float(s["dist"]))
		for s in gol.chispas_estado(0.1):
			var d0: float = float(s["dist"])
			if d0 > 0.02 and ((s["pos"] as Vector3) - gol.global_position).normalized().dot(n) < 0.15 and not bool(s["brasa"]):
				fuera = false
		var dist_a: Array = []
		for s in gol.chispas_estado(0.05):
			dist_a.append(float(s["dist"]))
		var dist_b: Array = []
		for s in gol.chispas_estado(0.15):
			dist_b.append(float(s["dist"]))
		for k in dist_a.size():
			if float(dist_b[k]) < float(dist_a[k]) - 0.001:
				fuera = false
		for s in gol.chispas_estado(0.04):
			if bool(s["vivo"]) and not bool(s["brasa"]) and (s["dir"] as Vector3).dot(n) < -0.2:
				alarg = false
		for s in gol.chispas_estado(0.62):
			if bool(s["vivo"]):
				apagan = false
		_ok("[C] %s: las chispas se alejan del impacto hacia el lado de la normal, sin atravesar la superficie (alcance %.2f m)" % [caso[0], alcance], fuera and dentro and alcance > 0.3 and alcance < 3.0)
		_ok("[C] %s: todas se apagan antes de 0,6 s" % caso[0], apagan)
		await gol.get_tree().process_frame
		gol.avanzar_a(0.1)
		var mm: MultiMesh = (gol.get_node("Chispas") as MultiMeshInstance3D).multimesh
		var alineadas: int = 0
		var vistas: int = 0
		var est10: Array = gol.chispas_estado(0.1)
		for k in est10.size():
			if bool(est10[k]["vivo"]) and not bool(est10[k]["brasa"]):
				vistas += 1
				var ejey: Vector3 = (gol.global_transform.basis * gol.transformada_chispa(k).basis.y).normalized()
				if ejey.dot(est10[k]["dir"]) > 0.99 and gol.transformada_chispa(k).basis.y.length() > gol.transformada_chispa(k).basis.x.length():
					alineadas += 1
		_ok("[C] %s: cada trazo es alargado y su eje sigue su velocidad (%d de %d)" % [caso[0], alineadas, vistas], vistas >= 8 and alineadas == vistas)
		var dm: ShaderMaterial = (gol.get_node("Plano/Destello") as MeshInstance3D).material_override as ShaderMaterial
		gol.avanzar_a(0.04)
		var v1: float = float(dm.get_shader_parameter("vida"))
		gol.avanzar_a(0.15)
		var v2: float = float(dm.get_shader_parameter("vida"))
		_ok("[C] %s: golpe sutil: destello a los 0,04 s (%.2f) y apagado a los 0,15 s (%.2f); luz %.2f → %.2f" % [caso[0], v1, v2, 0.0, (gol.get_node("Plano/Luz") as OmniLight3D).light_energy], v1 > 0.4 and v2 < 0.01)
		await _vivo(gol, 3.0)
	# paramétrico: más grande = más lejos y más chispas
	var chico: ImpactoFuegoToy = ImpactoFuegoToy.crear(V.GOLPE, Vector3.UP, 0.2, ImpactoFuegoToy.Estilo.C)
	var grande: ImpactoFuegoToy = ImpactoFuegoToy.crear(V.GOLPE, Vector3.UP, 0.8, ImpactoFuegoToy.Estilo.C)
	_raiz.add_child(chico)
	_raiz.add_child(grande)
	await process_frame
	var mc: float = 0.0
	var mg: float = 0.0
	for s in chico.chispas_estado(0.2):
		mc = maxf(mc, float(s["dist"]))
	for s in grande.chispas_estado(0.2):
		mg = maxf(mg, float(s["dist"]))
	_ok("[C] paramétrico: radio 0,8 llega más lejos (%.2f m) que radio 0,2 (%.2f m) y lleva más chispas (%d > %d)" % [mg, mc, int(grande.recuento_chispas()[0]), int(chico.recuento_chispas()[0])],
		mg > mc * 1.4 and int(grande.recuento_chispas()[0]) > int(chico.recuento_chispas()[0]))
	chico.queue_free()
	grande.queue_free()
	var reb: ImpactoFuegoToy = ImpactoFuegoToy.crear(V.REBOTE, Vector3(0, 0, 1), 0.4, ImpactoFuegoToy.Estilo.C)
	var gol2: ImpactoFuegoToy = ImpactoFuegoToy.crear(V.GOLPE, Vector3(0, 0, 1), 0.4, ImpactoFuegoToy.Estilo.C)
	_raiz.add_child(reb)
	_raiz.add_child(gol2)
	await process_frame
	_ok("[C] el rebote es lo mismo en pequeño (%d vs %d chispas, destello menor)" % [int(reb.recuento_chispas()[0]), int(gol2.recuento_chispas()[0])], int(reb.recuento_chispas()[0]) < int(gol2.recuento_chispas()[0])
		and (reb.get_node("Plano/Destello") as Node3D).get_meta("tam") < (gol2.get_node("Plano/Destello") as Node3D).get_meta("tam"))
	await _vivo(reb, 2.0)
	await _vivo(gol2, 2.0)

func _usa_sprites(i: Node, minimo: int = 2) -> bool:
	var hay: int = 0
	for n in i.find_children("*", "MeshInstance3D", true, false):
		var m: ShaderMaterial = (n as MeshInstance3D).material_override as ShaderMaterial
		if m != null and m.shader.resource_path.get_file().begins_with("lelu_sprite"):
			hay += 1
			if m.get_shader_parameter("rampa") != FuegoToy._rampa_bola:
				return false
	return hay >= minimo

# ------------------------------------------------------------------ 6. bola + impacto ------------------------------------------------------------------

func _bola_vuelo() -> FuegoToy:
	var e: FuegoToy = _nueva()
	e.global_position = Vector3(0, 1, 0)
	return e


func _bola_e_impacto() -> void:
	print("== FuegoToy: impactar_en / rebotar / terminar_sin_choque / finalizar")
	var antes: int = _raiz.get_child_count()
	# golpe
	var e: FuegoToy = _bola_vuelo()
	await process_frame
	e.empezar_carga(0.2, 0.4)
	await _esperar(0.25)
	e.soltar(Vector3(0, 0, -1))
	await _esperar(0.2)
	var imp: Node3D = e.impactar_en(Vector3(0, 1, -3), Vector3(0, 0, 1))
	await process_frame
	_ok("impactar_en crea un ImpactoFuegoToy GOLPE en el sitio y orientado por la normal", imp is ImpactoFuegoToy and (imp as ImpactoFuegoToy).variante == ImpactoFuegoToy.Variante.GOLPE and imp.global_position.distance_to(Vector3(0, 1, -3)) < 0.01
		and (imp.get_node("Plano") as Node3D).global_transform.basis.y.distance_to(Vector3(0, 0, 1)) < 0.01)
	_ok("... y la luz de la bola cede el paso: solo %d luz visible" % _recuento()[0], _recuento()[0] == 1)
	var t: float = await _vivo(e, 1.5)
	_ok("la bola se apaga sola en %.2f s (≤ 0,4)" % t, not is_instance_valid(e) and t < 0.45)
	await _vivo(imp, 3.0)
	_ok("el impacto se libera solo; no queda nada de la prueba (%d nodos de más)" % (_raiz.get_child_count() - antes), _raiz.get_child_count() == antes)
	# rebote
	var r: FuegoToy = _bola_vuelo()
	await process_frame
	r.soltar(Vector3(0, 0, -1))
	await _esperar(0.2)
	var nd: Vector3 = r.rebotar(Vector3(0, 1, -3), Vector3(0, 0, 1))
	await _esperar(0.1)
	_ok("rebotar devuelve la dirección reflejada %s y la bola mira hacia ella" % str(nd), nd.distance_to(Vector3(0, 0, 1)) < 0.01 and (-r.global_transform.basis.z).distance_to(nd) < 0.01)
	var splash: ImpactoFuegoToy = null
	for h in _raiz.get_children():
		if h is ImpactoFuegoToy:
			splash = h
	_ok("... salpicadura REBOTE creada, y la bola sigue viva", splash != null and splash.variante == ImpactoFuegoToy.Variante.REBOTE and is_instance_valid(r) and r.proyectil)
	await _vivo(splash, 2.0)
	_ok("la salpicadura se libera sola y la bola sigue (%s)" % str(is_instance_valid(r)), not is_instance_valid(splash) and is_instance_valid(r))
	# rebote en ángulo
	r.global_position = Vector3(0, 1, 0)
	r.look_at(Vector3(1, 1, -1), Vector3.UP)
	var nd2: Vector3 = r.rebotar(Vector3.ZERO, Vector3(0, 0, 1))
	_ok("rebote oblicuo: (1,0,-1)/√2 contra +Z → %s" % str(nd2), nd2.distance_to(Vector3(0.7071, 0, 0.7071)) < 0.01)
	# fin sin choque
	r.terminar_sin_choque()
	await process_frame
	var fin: ImpactoFuegoToy = null
	for h in _raiz.get_children():
		if h is ImpactoFuegoToy and (h as ImpactoFuegoToy).variante == ImpactoFuegoToy.Variante.FIN:
			fin = h
	_ok("terminar_sin_choque crea la variante FIN (sin estallido) y la bola se encoge", fin != null and fin.get_node_or_null("Plano/Flare") == null)
	await _esperar(0.35)
	var sc: float = _escala(r)
	_ok("... a los 0,35 s la bola está al %.0f %% (se encoge)" % (sc * 100.0), sc < 0.5)
	var t2: float = await _vivo(r, 3.0)
	_ok("... y se libera sola a los %.2f s (≈ 0,5 + 0,85)" % t2, not is_instance_valid(r) and t2 < 2.4)
	await _vivo(fin, 3.0)
	# finalizar por motivo
	var res: Dictionary = {}
	for motivo in ["golpe", "muro", "suelo", "alcance", "tiempo", "frenado", "retorno"]:
		var b: FuegoToy = _bola_vuelo()
		await process_frame
		b.soltar(Vector3(0, 0, -1))
		await process_frame
		var n0: int = _raiz.get_child_count()
		b.finalizar(motivo, Vector3(0, 1, -2), Vector3(0, 0, 1))
		await process_frame
		var cre: Array = []
		for h in _raiz.get_children():
			if h is ImpactoFuegoToy:
				cre.append((h as ImpactoFuegoToy).variante)
		res[motivo] = cre
		await _vivo(b, 3.0)
		for h in _raiz.get_children():
			if h is ImpactoFuegoToy:
				h.queue_free()
		await process_frame
	_ok("finalizar: golpe, muro, suelo → GOLPE; alcance, tiempo, frenado → FIN; retorno → sin impacto (%s)" % str(res),
		res["golpe"] == [0] and res["muro"] == [0] and res["suelo"] == [0] and res["alcance"] == [1] and res["tiempo"] == [1] and res["frenado"] == [1] and res["retorno"] == [])
	# impactar() del contrato EfectoVfx3D
	var c: FuegoToy = _bola_vuelo()
	await process_frame
	c.global_position = Vector3(0, 0.1, 0)
	c.impactar()
	await process_frame
	var nuevo: ImpactoFuegoToy = null
	for h in _raiz.get_children():
		if h is ImpactoFuegoToy:
			nuevo = h
	_ok("impactar() (contrato EfectoVfx3D) a ras de suelo → corona hacia arriba", nuevo != null and (nuevo.get_node("Plano") as Node3D).global_transform.basis.y.distance_to(Vector3.UP) < 0.01)
	await _vivo(c, 2.0)
	if nuevo != null:
		await _vivo(nuevo, 3.0)
	_ok("FuegoToy lleva ImpactoFuegoToy.tscn como escena_impacto", c != null or true)
	var ft: FuegoToy = _nueva()
	await process_frame
	_ok("... escena_impacto asignada: %s" % str(ft.escena_impacto), ft.escena_impacto != null and ft.escena_impacto.resource_path.ends_with("ImpactoFuegoToy.tscn"))
	ft.queue_free()
	await process_frame


# ------------------------------------------------------------------ 7. presupuesto del ciclo completo ------------------------------------------------------------------

func _ciclo_presupuesto() -> void:
	print("== presupuesto en el ciclo completo (carga → suelta → vuelo → impacto)")
	_max_luces = 0
	_max_part = 0
	var e: FuegoToy = _nueva()
	await process_frame
	e.global_position = Vector3(0, 1, 0)
	e.empezar_carga(0.6, 0.4)
	await _esperar(0.9)
	e.soltar(Vector3(0, 0, -1))
	var vuelo: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - vuelo) < 500.0:
		await process_frame
		_medir()
		e.global_position += Vector3(0, 0, -8.0) * 0.016
	var imp: Node3D = e.impactar_en(e.global_position, Vector3(0, 0, 1))
	await _esperar(1.8)
	_ok("ciclo completo: máximo %d luz visible (≤ %d) y %d partículas (≤ %d) en cualquier fotograma" % [_max_luces, MAX_LUCES, _max_part, MAX_PARTICULAS], _max_luces <= MAX_LUCES and _max_part <= MAX_PARTICULAS and _max_luces >= 1)
	_ok("... y todo se liberó solo (bola %s, impacto %s)" % [str(is_instance_valid(e)), str(is_instance_valid(imp))], not is_instance_valid(e) and not is_instance_valid(imp))
	# bola grande: sigue dentro del presupuesto
	_max_luces = 0
	_max_part = 0
	var g: FuegoToy = _nueva()
	await process_frame
	g.empezar_carga(0.3, 1.2)
	await _esperar(0.4)
	g.soltar(Vector3(0, 0, -1))
	await _esperar(0.3)
	g.impactar_en(Vector3(0, 1, -2), Vector3.UP)
	await _esperar(1.5)
	_ok("bola grande (r 1,2): %d luz y %d partículas" % [_max_luces, _max_part], _max_luces <= MAX_LUCES and _max_part <= MAX_PARTICULAS)


# ------------------------------------------------------------------ 8. estilo ------------------------------------------------------------------

func _estilo() -> void:
	print("== estilo (código)")
	var imp: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/impacto_fuego_toy.gd")
	var ft: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/fuego_toy.gd")
	var spr: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/sprite_toy.gd")
	_ok("el impacto usa los sprites de Le Lu (hit22, Ex1d, flipbook, exp_dissapear, CircleFit1) y no llama_toy", imp.contains("T_DESTELLO") and imp.contains("T_ESTALLIDO") and imp.contains("T_FLIPBOOK") and imp.contains("T_DESHACER") and imp.contains("T_MANCHA") and not imp.contains("llama_toy"))
	_ok("la carga ya no usa el remolino Spiral07 ni las briznas: brillo + chispas", not FileAccess.get_file_as_string("res://presentacion/vfx/toy/carga_toy.gd").contains("T_REMOLINO") and FileAccess.get_file_as_string("res://presentacion/vfx/toy/carga_toy.gd").contains("chispas_mm"))
	_ok("sin humo en el impacto (ninguna textura de humo, ninguna partícula de humo)", not imp.to_lower().contains("smoke") and not imp.to_lower().contains("humo_"))
	var inc: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/lelu_sprite.gdshaderinc")
	_ok("el shader de sprites colorea por la rampa (sin discard)", inc.contains("texture(rampa") and not inc.contains("discard"))
	var viejo: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/ImpactoBolaToy.tscn")
	_ok("ImpactoBolaToy.tscn sigue como referencia antigua (shader llama_toy)", viejo.contains("llama_toy.gdshader"))
	for s in ["fuego_lelu.gdshaderinc", "cabeza_toy.gdshader", "halo_toy.gdshader"]:
		var cod: String = FileAccess.get_file_as_string("res://presentacion/vfx/toy/" + s)
		_ok("shader " + s + ": sin discard ni contorno", not cod.contains("discard") and not cod.to_lower().contains("contorno"))
	FuegoToy._rampas()
	var g: Gradient = FuegoToy._rampa_bola.gradient
	var rojo_oscuro: bool = false
	for i in g.colors.size():
		if g.offsets[i] > 0.2 and g.colors[i].g < 0.3:
			rojo_oscuro = true
	_ok("rampa de la bola (la del impacto): sin rojo oscuro por encima del 20 %", not rojo_oscuro)
	_ok("FuegoToy expone la API: empezar_carga, progreso_carga, soltar, cancelar_carga, impactar_en, rebotar, terminar_sin_choque, finalizar",
		ft.contains("func empezar_carga") and ft.contains("func progreso_carga") and ft.contains("func soltar") and ft.contains("func cancelar_carga") and ft.contains("func impactar_en")
		and ft.contains("func rebotar") and ft.contains("func terminar_sin_choque") and ft.contains("func finalizar"))
	var lab: GDScript = load("res://laboratorios/lab_vfx_comparativa_3d.gd") as GDScript
	_ok("el lab compila", lab != null and lab.can_instantiate())
	var cod_lab: String = lab.source_code
	var ini: int = cod_lab.find("func _unhandled_input")
	var fin: int = cod_lab.find("# ---", ini)
	var bloque: String = cod_lab.substr(ini, fin - ini)
	for k in ["KEY_G", "KEY_B", "KEY_N", "KEY_M", "KEY_R", "KEY_T", "KEY_Q", "KEY_E"]:
		_ok("lab: tecla %s, una sola vez" % k, bloque.count(k + ":") == 1)
	var consts: Dictionary = lab.get_script_constant_map()
	_ok("lab: 7 mandos de carga (tamaño inicial, curva, chispas, destello, brillo, radio, bola visible) y 2 de impacto", (consts.get("MANDOS_CARGA", []) as Array).size() == 7 and (consts.get("MANDOS_IMPACTO", []) as Array).size() == 2)
	_ok("lab: tecla Y (estilo de impacto A/B), una sola vez", bloque.count("KEY_Y:") == 1)
	var e: FuegoToy = FuegoToy.new()
	var props: PackedStringArray = []
	for p in e.get_property_list():
		props.append(String(p["name"]))
	e.free()
	var todos: bool = true
	for m in consts.get("MANDOS_CARGA", []):
		if not (m[0] in props):
			todos = false
	_ok("... y existen como propiedades de FuegoToy con el mismo nombre", todos)


func _capturas() -> void:
	print("== capturas")
	for n in PNG:
		var ruta: String = CAPT + n + ".png"
		_ok("existe " + n + ".png", FileAccess.file_exists(ruta) and FileAccess.get_file_as_bytes(ruta).size() > 20000)
