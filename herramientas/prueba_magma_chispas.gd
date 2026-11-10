extends SceneTree

## PRUEBA del HUMO DE MAGMA POR REGLA y de las CHISPAS TIPO REPO DE GAS (11/11/2026; docs/TECNICAS_REPO_GAS_OTROS_ELEMENTOS_2026-11-10.md, top 5 nº 1 y 2). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_magma_chispas.gd
## Comprueba:
##   1. DE SERIE: HumoRegla «magma» apagada; ChispasRepo: las capas que solo añaden encendidas y «electrificado_capsula» apagada
##   2. HUMO DE MAGMA: apagada, nada; encendida: el cráter (GOLPE y AREA, no el REBOTE) suelta humo de materia MAGMA (tonos de hollín de HUMO) que se ve; la cima del muro y del pilar de magma
##      (y el FuegoToy hijo no pone además su humo); la bola que rueda deja un penacho y la quieta no; el tope de 420 bocanadas se respeta
##   3. CHISPAS: apagadas, ningún emisor; encendidas: impacto de rayo y de magma, pilar de rayo al llegar al suelo, estela de las bolas en vuelo y estado electrificado.
##      Vidas ESCALONADAS, nacen en la PIEL, REBOTAN en el suelo, se ESTIRAN con la velocidad, colores de las paletas (RayoPaleta; tramo bajo de la rampa en el magma), se liberan solas
##   4. ELECTRIFICADO EN LA CÁPSULA REAL: con la capa, los arcos se pegan a la CapsuleShape3D del cuerpo; sin ella, al cilindro de siempre
##   5. LAB: las teclas «.» y «,»
## Imprime FALLOS: n.

const RayoPaleta = preload("res://presentacion/vfx/toy/rayo_paleta.gd")

var _fallos: int = 0
var _raiz: Node3D = null


func _initialize() -> void:
	_correr()


func _ok(nombre: String, cond: bool, detalle: String = "") -> void:
	if cond:
		print("  OK   " + nombre)
	else:
		_fallos += 1
		print("  FALLO " + nombre + ("  (" + detalle + ")" if detalle != "" else ""))


func _esperar(s: float) -> void:
	await create_timer(s).timeout


func _correr() -> void:
	await process_frame
	_raiz = Node3D.new()
	root.add_child(_raiz)
	_de_serie()
	await _humo_magma()
	await _chispas()
	await _capsula()
	await _lab()
	HumoRegla.capas = HumoRegla.DE_SERIE.duplicate()
	ChispasRepo.de_serie()
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _hr(materia: int = -1) -> Array:
	var r: Array = []
	for n in root.find_children("*", "Node3D", true, false):
		if n is HumoRegla and (materia < 0 or (n as HumoRegla).materia == materia):
			r.append(n)
	return r


func _cr() -> Array:
	var r: Array = []
	for n in root.find_children("*", "Node3D", true, false):
		if n is ChispasRepo and not n.is_queued_for_deletion():
			r.append(n)
	return r


func _limpiar() -> void:
	for c in _raiz.get_children():
		_raiz.remove_child(c)
		c.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# ------------------------------------------------------------------ 1. de serie ------------------------------------------------------------------

func _de_serie() -> void:
	print("== de serie")
	_ok("HumoRegla tiene la capa «magma» y va APAGADA de serie", HumoRegla.capas.has("magma") and not bool(HumoRegla.capas["magma"]) and not bool(HumoRegla.DE_SERIE["magma"]))
	_ok("las demás capas de HumoRegla no cambian (impacto_bola, barril, suelo y vapor encendidas)", HumoRegla.capas["impacto_bola"] and HumoRegla.capas["barril"] and HumoRegla.capas["suelo"] and HumoRegla.capas["vapor"] and not HumoRegla.capas["muro"])
	_ok("el tope de HumoRegla sigue en 420", HumoRegla.MAX_VIVAS == 420)
	var esperadas: Array = ["rayo_impacto", "rayo_pilar", "rayo_proyectil", "electrificado", "electrificado_capsula", "magma_impacto", "magma_proyectil"]
	_ok("ChispasRepo: siete capas", ChispasRepo.capas.size() == 7 and esperadas.all(func(k: String) -> bool: return ChispasRepo.capas.has(k)))
	for k in esperadas:
		var debe: bool = k != "electrificado_capsula"
		_ok("chispas «%s» de serie %s" % [k, "encendida (solo añade)" if debe else "APAGADA (cambia los arcos de siempre)"], bool(ChispasRepo.capas[k]) == debe)
	_ok("las capas de FuegoToy siguen sin tocar", FuegoToy.formas_extra.size() == 7 and not FuegoToy.formas_extra["humo_cima_muro"])


# ------------------------------------------------------------------ 2. humo de magma ------------------------------------------------------------------

func _impacto_magma(var_: int, pos: Vector3, normal: Vector3 = Vector3.UP, r: float = 0.4) -> ImpactoMagmaToy:
	var imp: ImpactoMagmaToy = ImpactoMagmaToy.crear(var_ as ImpactoMagmaToy.Variante, normal, r)
	_raiz.add_child(imp)
	imp.global_position = pos
	return imp


func _humo_magma() -> void:
	print("== humo de magma por regla")
	HumoRegla.poner_todas(false)
	ChispasRepo.poner_todas(false)
	_impacto_magma(ImpactoMagmaToy.Variante.GOLPE, Vector3.ZERO)
	await _frames(3)
	_ok("capa apagada: el cráter no suelta humo", _hr().is_empty(), str(_hr().size()))
	_limpiar()
	await process_frame
	HumoRegla.capas["magma"] = true
	_impacto_magma(ImpactoMagmaToy.Variante.REBOTE, Vector3(5, 0, 0))
	await _frames(3)
	_ok("REBOTE (sin cráter): nada", _hr().is_empty())
	_limpiar()
	await process_frame
	var imp: ImpactoMagmaToy = _impacto_magma(ImpactoMagmaToy.Variante.GOLPE, Vector3(0, 0, 0))
	await _frames(3)
	var hs: Array = _hr(HumoRegla.Materia.MAGMA)
	_ok("GOLPE: un emisor de materia MAGMA", hs.size() == 1, str(hs.size()))
	if hs.size() == 1:
		var h: HumoRegla = hs[0]
		_ok("materia MAGMA: los tonos de HOLLÍN de la paleta HUMO (nada nuevo)", (h.p["claro"] as Color).is_equal_approx(HumoRegla.PALETAS[HumoRegla.Materia.HUMO]["hollin"]) and (h.p["sombra"] as Color).is_equal_approx(HumoRegla.PALETAS[HumoRegla.Materia.HUMO]["hollin_sombra"]))
		_ok("materia MAGMA: la misma regla (rend 1,3, olvido 0,45)", is_equal_approx(float(h.p["rend"]), 1.3) and is_equal_approx(float(h.p["olvido"]), HumoRegla.OLVIDO_HOLLIN))
		await _esperar(1.0)
		_ok("el cráter suelta bocanadas", h.emitidas >= 8, str(h.emitidas))
		_ok("se ve humo: hollín > 0,3 al frenarse (lento)", h.hollin_max() > 0.3, str(h.hollin_max()))
		var lejos: float = 0.0
		for d in h.estados():
			lejos = maxf(lejos, Vector2((d["pos"] as Vector3).x, (d["pos"] as Vector3).z).length())
		_ok("nace en el cráter (a menos de 2,5 m en horizontal)", lejos < 2.5, str(lejos))
		await _esperar(0.6)
		var antes: int = h.emitidas
		await _esperar(0.8)
		_ok("con el cráter frío (calor < 0,3, a partir de 1,4 s) ya no suelta más", h.emitidas == antes, "%d más" % (h.emitidas - antes))
	_limpiar()
	await process_frame
	_impacto_magma(ImpactoMagmaToy.Variante.AREA, Vector3(0, 0, 10), Vector3.UP, 1.8)
	await _frames(3)
	_ok("AREA: un emisor de MAGMA", _hr(HumoRegla.Materia.MAGMA).size() == 1)
	_limpiar()
	await process_frame
	# muro y pilar de magma (con las capas «muro» y «pilar» del fuego también encendidas: el FuegoToy hijo no duplica)
	for par in [[MagmaToy.Figura.MURO, Vector3(3.45, 1.5, 0.3)], [MagmaToy.Figura.PILAR, Vector3(0.5, 4.0, 0.5)]]:
		HumoRegla.poner_todas(false)
		HumoRegla.capas["magma"] = true
		HumoRegla.capas["muro"] = true
		HumoRegla.capas["pilar"] = true
		var s: Vector3 = par[1]
		var m: MagmaToy = MagmaToy.new()
		m.definir(par[0], s.x, s.y, s.z, false)
		_raiz.add_child(m)
		m.global_position = Vector3(20, 0, 0)
		m.lanzar(-1.0)
		await _esperar(1.4)
		var nom: String = "muro" if par[0] == MagmaToy.Figura.MURO else "pilar"
		var e: HumoRegla = m.get_meta(&"humo_regla_emisor") as HumoRegla if m.has_meta(&"humo_regla_emisor") else null
		_ok("%s de magma: un emisor MAGMA que sigue al MagmaToy" % nom, e != null and e.materia == HumoRegla.Materia.MAGMA and e.sigue == m)
		_ok("%s de magma: el FuegoToy hijo no pone su humo de fuego (solo hay humo MAGMA)" % nom, _hr(HumoRegla.Materia.HUMO).is_empty(), str(_hr(HumoRegla.Materia.HUMO).size()))
		if e != null:
			var min_y: float = 99.0
			for d in e.estados():
				min_y = minf(min_y, (d["pos"] as Vector3).y)
			_ok("%s de magma: suelta y nace arriba (nada por debajo de 0,15 · alto)" % nom, e.emitidas >= 2 and min_y > s.y * 0.15, "emitidas %d, min y %.2f" % [e.emitidas, min_y])
		_limpiar()
		await process_frame
	HumoRegla.poner_todas(false)
	HumoRegla.capas["muro"] = true
	var mf: MagmaToy = MagmaToy.new()
	mf.definir(MagmaToy.Figura.MURO, 3.45, 1.5, 0.3, false)
	_raiz.add_child(mf)
	mf.lanzar(-1.0)
	await _esperar(0.3)
	_ok("con «magma» apagada, la capa «muro» del fuego sigue como estaba (humo HUMO en el FuegoToy hijo)", _hr(HumoRegla.Materia.HUMO).size() == 1 and _hr(HumoRegla.Materia.MAGMA).is_empty())
	_limpiar()
	await process_frame
	# la bola
	HumoRegla.poner_todas(false)
	HumoRegla.capas["magma"] = true
	var quieta: MagmaToy = MagmaToy.new()
	quieta.definir(MagmaToy.Figura.BOLA, 0.4, 0.4, 0.4, false)
	_raiz.add_child(quieta)
	quieta.lanzar(-1.0)
	await _frames(5)
	_ok("bola QUIETA: sin humo", _hr().is_empty())
	_limpiar()
	await process_frame
	var b: MagmaToy = MagmaToy.new()
	b.definir(MagmaToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	_raiz.add_child(b)
	b.global_position = Vector3(0, 0.7, 0)
	b.look_at(Vector3(0, 0.7, -10), Vector3.UP)
	b.lanzar(-1.0)
	for i in 50:
		b.global_position += Vector3(0, 0, -0.12)
		await _esperar(0.02)
	var hb: HumoRegla = b.get_meta(&"humo_regla_emisor") as HumoRegla if b.has_meta(&"humo_regla_emisor") else null
	_ok("bola que RUEDA: un emisor MAGMA que la sigue", hb != null and hb.materia == HumoRegla.Materia.MAGMA)
	if hb != null:
		var bz: float = b.global_position.z
		_ok("bola que rueda: el penacho suelta (≥ 6 bocanadas)", hb.emitidas >= 6, str(hb.emitidas))
		var detras: int = 0
		for d in hb.estados():
			if (d["pos"] as Vector3).z > bz:
				detras += 1
		_ok("el penacho queda DETRÁS de la bola", detras >= hb.vivas() * 0.8, "%d de %d" % [detras, hb.vivas()])
		b.queue_free()
		await _frames(3)
		_ok("al irse la bola, el emisor deja de soltar (cerrado)", hb.cerrado)
	_limpiar()
	await process_frame
	# el tope
	for i in 12:
		_impacto_magma(ImpactoMagmaToy.Variante.AREA, Vector3(i * 4.0, 0, 30), Vector3.UP, 1.8)
	await _esperar(1.2)
	_ok("muchos cráteres: el tope de 420 bocanadas vivas se respeta", HumoRegla.vivas_global() <= HumoRegla.MAX_VIVAS, str(HumoRegla.vivas_global()))
	HumoRegla.poner_todas(false)
	_limpiar()
	await _esperar(0.1)


# ------------------------------------------------------------------ 3. chispas ------------------------------------------------------------------

## Longitud del trazo (eje Y de la instancia) y ancho (eje X) de la chispa i.
func _trazo(e: ChispasRepo, i: int) -> Vector2:
	var tr: Transform3D = e.multimesh().get_instance_transform(i)
	return Vector2(tr.basis.y.length(), tr.basis.x.length())


func _chispas() -> void:
	print("== chispas tipo repo")
	HumoRegla.poner_todas(false)
	ChispasRepo.poner_todas(false)
	var ir: ImpactoRayoToy = ImpactoRayoToy.crear(ImpactoRayoToy.Variante.GOLPE, Vector3.UP, 0.4)
	_raiz.add_child(ir)
	var im: ImpactoMagmaToy = _impacto_magma(ImpactoMagmaToy.Variante.GOLPE, Vector3(4, 0, 0))
	var est: EstadoRayoToy = EstadoRayoToy.para_superficie(2.0, 2.0)
	_raiz.add_child(est)
	await _frames(4)
	_ok("apagadas: ni el impacto de rayo, ni el de magma, ni el estado crean emisores", _cr().is_empty(), str(_cr().size()))
	var n_hijos: int = ir.get_child_count()
	_limpiar()
	await process_frame
	ChispasRepo.de_serie()
	var ir2: ImpactoRayoToy = ImpactoRayoToy.crear(ImpactoRayoToy.Variante.GOLPE, Vector3.UP, 0.4)
	_raiz.add_child(ir2)
	ir2.global_position = Vector3(0, 0, 0)
	await _frames(2)
	_ok("encendidas: el impacto de rayo no cambia sus hijos (la capa cuelga de la escena)", ir2.get_child_count() == n_hijos, "%d vs %d" % [ir2.get_child_count(), n_hijos])
	var cs: Array = _cr()
	_ok("impacto de rayo: UN emisor de paleta RAYO", cs.size() == 1 and (cs[0] as ChispasRepo).paleta == ChispasRepo.Paleta.RAYO, str(cs.size()))
	if cs.size() == 1:
		var e: ChispasRepo = cs[0]
		var temprano: int = e.nacidas
		_ok("al principio ya han nacido algunas, no todas", temprano >= 1 and temprano < e._n, "%d de %d" % [temprano, e._n])
		var m: ShaderMaterial = (e.get_child(0) as MultiMeshInstance3D).material_override as ShaderMaterial
		var rampa: GradientTexture1D = m.get_shader_parameter("rampa") as GradientTexture1D
		_ok("colores del rayo: la rampa es la de RayoPaleta (halo hondo → núcleo)", rampa != null and rampa.gradient.colors[0].is_equal_approx(RayoPaleta.HALO_HONDO) and rampa.gradient.colors[rampa.gradient.colors.size() - 1].is_equal_approx(RayoPaleta.NUCLEO))
		var cerca: bool = true
		for d in e.estados():
			cerca = cerca and (d["pos"] as Vector3).length() < 0.6
		_ok("nacen en la PIEL del choque (a menos de 0,6 m del punto al nacer)", cerca and not e.estados().is_empty())
		await _esperar(0.3)
		_ok("después han nacido más (escalonadas)", e.nacidas > temprano, "%d → %d" % [temprano, e.nacidas])
		var estirada: bool = false
		var corta: bool = true
		var dbg: String = ""
		for i in e._n:
			if e._vida[i] > 0.0:
				var tz: Vector2 = e.trazo(i)
				if e._vel[i].length() > 1.2:
					estirada = estirada or tz.x > tz.y * 1.5
				elif e._vel[i].length() < 0.2:
					corta = corta and tz.x <= tz.y * 1.01
				if dbg.length() < 200:
					dbg += "v%.2f l%.3f w%.3f; " % [e._vel[i].length(), tz.x, tz.y]
		_ok("las rápidas se ESTIRAN (largo del trazo > 1,5 × ancho) y las lentas son un punto", estirada and corta, dbg)
		var arriba: bool = true
		for d in e.estados():
			arriba = arriba and (d["pos"] as Vector3).y >= e.y_suelo
		await _esperar(0.8)
		_ok("REBOTAN en el suelo (rebotes > 0) y nunca lo atraviesan", e.rebotes > 0 and arriba, str(e.rebotes))
		await _esperar(2.0)
		_ok("el emisor se libera solo", not is_instance_valid(e) or e.is_queued_for_deletion())
	_limpiar()
	await process_frame
	# escalonado, determinista: un emisor a mano con escalon 1 s; a los 0,1 s ha nacido ~10 %
	var ex: ChispasRepo = ChispasRepo.crear(ChispasRepo.Paleta.RAYO, _raiz, 40, {"escalon": 1.0, "emite": 2.0})
	ex.set_process(false)
	ex.poner_plano(Vector3(0, 0, 40), Vector3.UP, 0.4)
	for i in 6:
		ex.avanzar(1.0 / 60.0)
	_ok("vidas ESCALONADAS (repo: i / n · escalon): a los 0,1 s de 1 s, ~10 % nacidas", ex.nacidas >= 2 and ex.nacidas <= 6, "%d de 40" % ex.nacidas)
	for i in 60:
		ex.avanzar(1.0 / 60.0)
	_ok("vidas ESCALONADAS: al segundo, (casi) todas", ex.nacidas >= 36, "%d de 40" % ex.nacidas)
	var alt: bool = true
	for d in ex.estados():
		alt = alt and (d["pos"] as Vector3).y >= 0.0
	_ok("nacen FUERA de la piel (a R + 0,15 del plano, nunca dentro)", alt)
	_limpiar()
	await process_frame
	# magma
	var im2: ImpactoMagmaToy = _impacto_magma(ImpactoMagmaToy.Variante.GOLPE, Vector3(0, 0, 0))
	await _frames(2)
	var cm: Array = _cr()
	_ok("impacto de magma: UN emisor de paleta MAGMA", cm.size() == 1 and (cm[0] as ChispasRepo).paleta == ChispasRepo.Paleta.MAGMA)
	if cm.size() == 1:
		var em: ChispasRepo = cm[0]
		var mm: ShaderMaterial = (em.get_child(0) as MultiMeshInstance3D).material_override as ShaderMaterial
		_ok("brasas de magma: el tramo bajo de la rampa (0,15 → 0,55: rojo-naranja, sin amarillo)", (mm.get_shader_parameter("tramo") as Vector2).is_equal_approx(Vector2(0.15, 0.55)))
		await _esperar(0.6)
		var c_min: float = 1.0
		for d in em.estados():
			c_min = minf(c_min, float(d["calor"]))
		_ok("las brasas se ENFRÍAN con la vida (calor = (vida que queda / 1,2)²: las viejas < 0,5)", c_min < 0.5, str(c_min))
		await _esperar(0.6)
		_ok("las brasas botan en el suelo", em.rebotes > 0, str(em.rebotes))
	_ok("las brasas de siempre del impacto de magma siguen (recuento sin cambiar)", im2.recuento()[1] == int(ImpactoMagmaToy.PARAMS[ImpactoMagmaToy.Variante.GOLPE]["brasas"]))
	_limpiar()
	await _esperar(0.1)
	# pilar de rayo
	var pil: RayoToy = RayoToy.new()
	pil.definir(RayoToy.Figura.PILAR, 0.5, 4.0, 0.5, false)
	_raiz.add_child(pil)
	pil.global_position = Vector3(0, 0, 0)
	pil.lanzar(-1.0)
	await _esperar(0.4)
	var cp: Array = _cr()
	_ok("pilar de rayo: al llegar al suelo, UN emisor en su pie", cp.size() == 1, str(cp.size()))
	if cp.size() == 1:
		await _esperar(0.3)
		var ep: ChispasRepo = cp[0]
		var pie: bool = ep.nacidas > 0
		for d in ep.estados():
			pie = pie and (d["pos"] as Vector3).y < 2.5
		_ok("pilar: las chispas salen del pie", pie, str(ep.nacidas))
	_limpiar()
	await _esperar(0.1)
	# estela de las bolas
	for el in ["rayo", "magma"]:
		var bola: Node3D = RayoToy.new() if el == "rayo" else MagmaToy.new()
		bola.call("definir", 0, 0.4, 0.4, 0.4, true)
		_raiz.add_child(bola)
		bola.global_position = Vector3(0, 0.7, 0)
		bola.look_at(Vector3(0, 0.7, -10), Vector3.UP)
		bola.call("lanzar", -1.0)
		for i in 30:
			bola.global_position += Vector3(0, 0, -0.13)
			await process_frame
		var ce: Array = _cr()
		_ok("%s en vuelo: UN emisor de estela" % el, ce.size() == 1, str(ce.size()))
		if ce.size() == 1:
			var ee: ChispasRepo = ce[0]
			var detras: int = 0
			for d in ee.estados():
				if (d["pos"] as Vector3).z > bola.global_position.z + 0.1:
					detras += 1
			_ok("%s: la estela nace y se queda ATRÁS (inercia: el aire la frena)" % el, ee.nacidas >= 4 and detras >= ee.vivas() * 0.7, "%d de %d" % [detras, ee.vivas()])
			bola.queue_free()
			await _frames(3)
			_ok("%s: al irse la bola, el emisor se cierra" % el, not is_instance_valid(ee) or ee.cerrado)
		_limpiar()
		await _esperar(0.1)
	# estado electrificado
	var cuerpo: StaticBody3D = _cuerpo_capsula(0.3, 1.4)
	_raiz.add_child(cuerpo)
	cuerpo.global_position = Vector3(0, 0, 0)
	var ent: EstadoRayoToy = EstadoRayoToy.para_entidad(1.4, 0.6, 3.0)
	cuerpo.add_child(ent)
	await _esperar(0.7)
	var ce2: Array = _cr()
	_ok("electrificado (ENTIDAD): UN emisor que sigue al estado", ce2.size() == 1 and (ce2[0] as ChispasRepo).sigue == ent)
	if ce2.size() == 1:
		var ec: ChispasRepo = ce2[0]
		_ok("electrificado: la piel de las chispas es la CÁPSULA real del cuerpo (radio 0,3)", ec.piel == ChispasRepo.Piel.CAPSULA and is_equal_approx(ec.piel_r, 0.3), "%d %.2f" % [ec.piel, ec.piel_r])
		_ok("electrificado: han nacido chispas", ec.nacidas >= 3, str(ec.nacidas))
		ent.apagar()
		await _frames(4)
		_ok("al apagarse el estado, el emisor se cierra", not is_instance_valid(ec) or ec.cerrado)
	_limpiar()
	await process_frame
	var sup: EstadoRayoToy = EstadoRayoToy.para_superficie(2.0, 2.0)
	_raiz.add_child(sup)
	sup.global_position = Vector3(5, 0.2, 0)
	await _esperar(0.7)
	var cs3: Array = _cr()
	_ok("electrificado (SUPERFICIE): un emisor sobre el agua, rebotan en ella", cs3.size() == 1 and is_equal_approx((cs3[0] as ChispasRepo).y_suelo, 0.2))
	_limpiar()
	await process_frame
	_ok("tope global de chispas (%d)" % ChispasRepo.MAX_VIVAS, ChispasRepo.vivas_global() <= ChispasRepo.MAX_VIVAS)


func _cuerpo_capsula(r: float, h: float) -> StaticBody3D:
	var c: StaticBody3D = StaticBody3D.new()
	var f: CapsuleShape3D = CapsuleShape3D.new()
	f.radius = r
	f.height = h
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = f
	cs.position = Vector3(0, h * 0.5, 0)
	c.add_child(cs)
	return c


# ------------------------------------------------------------------ 4. arcos en la cápsula ------------------------------------------------------------------

## Distancia media (horizontal) de los puntos de los arcos al eje vertical del cuerpo.
## Se muestrea en varios redibujos (los arcos se encienden al azar).
func _radio_arcos(e: EstadoRayoToy) -> float:
	var s: float = 0.0
	var n: int = 0
	for k in 10:
		for t in e.trazos_actuales():
			var a: Vector3 = (t as Dictionary)["a"]
			if a.y > 0.45 and a.y < 0.95:           # en el tramo recto (no en los casquetes)
				s += Vector2(a.x, a.z).length()
				n += 1
		await _esperar(0.08)
	return s / float(n) if n > 0 else -1.0


func _capsula() -> void:
	print("== electrificado: arcos en la cápsula real")
	ChispasRepo.de_serie()
	ChispasRepo.capas["electrificado"] = false
	var c1: StaticBody3D = _cuerpo_capsula(0.3, 1.4)
	_raiz.add_child(c1)
	var e1: EstadoRayoToy = EstadoRayoToy.para_entidad(1.4, 0.6, 3.0)       # el cilindro de siempre, a propósito más gordo que la cápsula (0,6 vs 0,3)
	c1.add_child(e1)
	await _esperar(0.3)
	_ok("encuentra la CapsuleShape3D del cuerpo", e1.tiene_capsula())
	var r_off: float = await _radio_arcos(e1)
	_ok("capa APAGADA: los arcos van al cilindro de siempre (≈ 0,6 m)", r_off > 0.5, str(r_off))
	ChispasRepo.capas["electrificado_capsula"] = true
	await _esperar(0.3)
	var r_on: float = await _radio_arcos(e1)
	_ok("capa ENCENDIDA: los arcos se agarran a la cápsula real (≈ 0,3 m)", r_on > 0.2 and r_on < 0.42, str(r_on))
	var c_m: Array = e1.capsula_mundo()
	_ok("capsula_mundo: los extremos del segmento y el radio de la forma", is_equal_approx(float(c_m[2]), 0.3) and absf((c_m[0] as Vector3).y - 0.3) < 0.01 and absf((c_m[1] as Vector3).y - 1.1) < 0.01, str(c_m))
	_limpiar()
	await process_frame
	var sin_c: Node3D = Node3D.new()
	_raiz.add_child(sin_c)
	var e2: EstadoRayoToy = EstadoRayoToy.para_entidad(1.4, 0.6, 3.0)
	sin_c.add_child(e2)
	await _esperar(0.3)
	var r2: float = await _radio_arcos(e2)
	_ok("sin cápsula en el cuerpo: aunque la capa esté encendida, el cilindro de siempre", not e2.tiene_capsula() and r2 > 0.5, str(r2))
	_limpiar()
	ChispasRepo.de_serie()
	await process_frame


# ------------------------------------------------------------------ 5. lab ------------------------------------------------------------------

func _lab() -> void:
	print("== lab: «.» y «,»")
	var src: String = FileAccess.get_file_as_string("res://laboratorios/lab_vfx_comparativa_3d.gd")
	_ok("el lab tiene la tecla «.» (chispas tipo repo) y «,» (electrificar)", src.find("KEY_PERIOD: alternar_chispas_repo()") >= 0 and src.find("KEY_COMMA: electrificar()") >= 0)
	ChispasRepo.de_serie()
	HumoRegla.poner_todas(false)
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	lab.call("alternar_chispas_repo")
	var todas: bool = true
	for k in ChispasRepo.capas:
		todas = todas and bool(ChispasRepo.capas[k])
	_ok(". las enciende TODAS (también la cápsula)", todas)
	lab.call("alternar_chispas_repo")
	_ok(". otra vez las apaga todas", not ChispasRepo.hay_alguna())
	lab.call("alternar_chispas_repo")
	var m: Node3D = lab.call("electrificar")
	await _esperar(0.5)
	var est: EstadoRayoToy = m.get_node_or_null("EstadoElectrificado") as EstadoRayoToy
	_ok(", pone un muñeco electrificado agarrado a su cápsula", est != null and est.tiene_capsula())
	var hay: bool = false
	for n in lab.find_children("*", "Node3D", true, false):
		hay = hay or n is ChispasRepo
	_ok(", con las chispas encendidas, el muñeco y el agua sueltan chispas", hay)
	lab.call("alternar_humo_regla")
	_ok("8 enciende también la capa «magma» del humo", bool(HumoRegla.capas["magma"]))
	lab.call("poner_elemento", "magma")
	var ia: Node3D = lab.call("impacto_suelo")
	await _frames(3)
	var hm: bool = false
	for n in lab.find_children("*", "Node3D", true, false):
		hm = hm or (n is HumoRegla and (n as HumoRegla).materia == HumoRegla.Materia.MAGMA)
	_ok("lab con 8 y Z = magma: N (impacto en el suelo) suelta humo de magma", ia is ImpactoMagmaToy and hm)
	lab.call("alternar_humo_regla")
	lab.call("limpiar")
	lab.queue_free()
	await process_frame
	HumoRegla.poner_todas(false)
	ChispasRepo.de_serie()
