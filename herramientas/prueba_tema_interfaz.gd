extends SceneTree
## TEMA COMÚN DE LA INTERFAZ Y MARCOS POR CALIDAD (24/10; presentacion/ui/tema_interfaz.gd, marco_calidad.gd, pista_interaccion.gd, barra_hud.gd).
##   godot --headless --fixed-fps 30 --path . -s res://herramientas/prueba_tema_interfaz.gd
## Sin ventana: lo que se mide es la lógica y los píxeles de las texturas generadas, los estilos y el contraste (no «que se vea bien»: eso son las capturas
## de docs/capturas/interfaz_eow). Comprueba además que pulir no tocó el tamaño de los huecos de la mochila.

const CONTRASTE_MIN: float = 7.0
const LADO_HUECO: float = 58.0           ## BolsaUI.TAM_BOLSA: el tamaño de hit de un hueco de la mochila antes y después de pulir

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	_tema()
	_contraste()
	_marcos()
	await _huecos()
	await _iconos_y_avisos()
	await _pista_y_barra()
	await _rotulo()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------------------------------------------------------------
func _tema() -> void:
	var t: Theme = TemaInterfaz.tema()
	_ok("tema: es un Theme, único (la misma instancia cada vez) y con fuente propia", t != null and t == TemaInterfaz.tema() and t.default_font != null and t.default_font_size == TemaInterfaz.TAM_FUENTE)
	_ok("tema: etiquetas con texto claro y contorno oscuro", t.get_color("font_color", "Label").is_equal_approx(TemaInterfaz.TEXTO) and t.get_color("font_outline_color", "Label").get_luminance() < 0.1)
	var panel: StyleBoxFlat = t.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	_ok("tema: panel oscuro translúcido, esquinas redondas, borde cálido y sombra", panel != null and panel.bg_color.a < 1.0 and panel.bg_color.get_luminance() < 0.1
		and panel.corner_radius_top_left == TemaInterfaz.ESQUINA_PX and panel.border_color.is_equal_approx(TemaInterfaz.BORDE_CALIDO) and panel.shadow_size > 0)
	_ok("tema: botones, tooltip, barra y separador definidos", t.has_stylebox("normal", "Button") and t.has_stylebox("hover", "Button") and t.has_stylebox("panel", "TooltipPanel")
		and t.has_stylebox("fill", "ProgressBar") and t.has_stylebox("separator", "HSeparator"))
	_ok("tema: la fuente se comparte", TemaInterfaz.fuente() == TemaInterfaz.fuente())


func _contraste() -> void:
	var casos: Array = [
		["texto del tema sobre FONDO_PANEL", TemaInterfaz.TEXTO, TemaInterfaz.FONDO_PANEL],
		["texto suave sobre FONDO_PANEL", TemaInterfaz.TEXTO_SUAVE, TemaInterfaz.FONDO_PANEL],
		["texto del aviso común sobre su panel", Color(1, 0.9, 0.6), AvisoObjeto.FONDO_COMUN],
		["texto del aviso de calidad sobre su panel", AvisoObjeto.COLOR_TEXTO, AvisoObjeto.FONDO_CALIDAD],
		["texto del rótulo de zona sobre su panel", RotuloZona3D.COLOR_TEXTO, RotuloZona3D.FONDO],
		["letra de la pista «E» sobre la tecla", PistaInteraccion.COLOR_LETRA, PistaInteraccion.COLOR_TECLA],
		["rótulo de la barra sobre su pista (contorno oscuro)", TemaInterfaz.TEXTO, BarraHud.FONDO_PISTA],
	]
	for c in casos:
		var v: float = TemaInterfaz.contraste_peor(c[1] as Color, c[2] as Color)
		_ok("contraste %s (peor caso %.1f, mínimo %.1f)" % [c[0], v, CONTRASTE_MIN], v >= CONTRASTE_MIN)
	# La mochila: tinta sobre pergamino en sus tres estados del hueco (opacos).
	for par in [["pergamino", BolsaUI.PERGAMINO], ["pergamino sombra", BolsaUI.PERGAMINO_SOMBRA], ["pergamino claro", BolsaUI.PERGAMINO_CLARO]]:
		var v2: float = TemaInterfaz.contraste(BolsaUI.TINTA, par[1] as Color)
		_ok("contraste tinta de la mochila sobre %s (%.1f, mínimo %.1f)" % [par[0], v2, CONTRASTE_MIN], v2 >= CONTRASTE_MIN)
	var v3: float = TemaInterfaz.contraste(BolsaUI.TINTA, BolsaUI.SOLAPA)
	_ok("contraste del título «Mochila» sobre la solapa (%.1f; el encargo pedía ≥ 4,5 como mínimo, aquí se mide, no se exige 7)" % v3, v3 >= 4.5)


# ---------------------------------------------------------------------------------------------------------------------
func _marcos() -> void:
	var calidades: Array = [Objetos.CALIDAD_COMUN, Objetos.CALIDAD_EPICO, Objetos.CALIDAD_LEGENDARIO]
	_ok("marcos: hay uno por cada calidad de Objetos", MarcoCalidad.MARCOS.size() == Objetos.CALIDADES.size() and Objetos.CALIDADES.keys().all(func(k): return MarcoCalidad.MARCOS.has(k)))
	_ok("marcos: una calidad desconocida cae en común", MarcoCalidad.normalizar("mitico") == Objetos.CALIDAD_COMUN)
	var imgs: Dictionary = {}
	for cal in calidades:
		imgs[cal] = MarcoCalidad.generar_imagen(cal)
	for cal in calidades:
		var img: Image = imgs[cal]
		var n: int = MarcoCalidad.LADO_TEX
		_ok("marco %s: textura %d×%d y el centro es transparente (el hueco se ve por dentro)" % [cal, n, n], img.get_width() == n and img.get_height() == n and img.get_pixel(n / 2, n / 2).a < 0.01)
		# Un píxel de la mitad del lado de arriba, sobre el filo: opaco.
		var y_filo: int = int(MarcoCalidad.INSET + 1.0)
		_ok("marco %s: el filo es opaco en el centro del lado de arriba" % cal, img.get_pixel(n / 2, y_filo).a > 0.9)
		_ok("marco %s: la esquina de fuera está vacía (esquinas redondas)" % cal, img.get_pixel(0, 0).a < 0.01)
		var tex: Texture2D = MarcoCalidad.textura(cal)
		var estilo: StyleBoxTexture = MarcoCalidad.estilo(cal)
		_ok("marco %s: textura y NinePatch compartidos y con margen de esquina" % cal, tex == MarcoCalidad.textura(cal) and estilo == MarcoCalidad.estilo(cal)
			and estilo.texture == tex and estilo.texture_margin_left == MarcoCalidad.MARGEN_NUEVE)
	var filo_c: Color = (imgs[Objetos.CALIDAD_COMUN] as Image).get_pixel(MarcoCalidad.LADO_TEX / 2, int(MarcoCalidad.INSET + 1.0))
	var filo_e: Color = (imgs[Objetos.CALIDAD_EPICO] as Image).get_pixel(MarcoCalidad.LADO_TEX / 2, int(MarcoCalidad.INSET + 1.0))
	var filo_l: Color = (imgs[Objetos.CALIDAD_LEGENDARIO] as Image).get_pixel(MarcoCalidad.LADO_TEX / 2, int(MarcoCalidad.INSET + 1.0))
	_ok("marco común: gris cálido sobrio (poca saturación)", filo_c.s < 0.25)
	_ok("marco épico: morado (azul y rojo por encima del verde)", filo_e.b > filo_e.g + 0.2 and filo_e.r > filo_e.g)
	_ok("marco legendario: dorado (rojo > verde > azul)", filo_l.r > filo_l.g and filo_l.g > filo_l.b + 0.1)
	# Brillo: épico y legendario tienen resplandor por dentro del filo; el común no.
	var dentro: int = int(MarcoCalidad.INSET + float(MarcoCalidad.MARCOS["epico"]["grosor"]) + 2.0)
	var cx: int = MarcoCalidad.LADO_TEX / 2
	_ok("marco épico y legendario: resplandor interior (alfa > 0 junto al filo)", (imgs[Objetos.CALIDAD_EPICO] as Image).get_pixel(cx, dentro).a > 0.1
		and (imgs[Objetos.CALIDAD_LEGENDARIO] as Image).get_pixel(cx, dentro).a > 0.1)
	_ok("marco común: sin resplandor interior", (imgs[Objetos.CALIDAD_COMUN] as Image).get_pixel(cx, dentro).a < 0.01)
	# Remaches: solo el legendario tiene un punto claro y opaco en la esquina (en el punto medio del arco).
	var rad_filo: float = MarcoCalidad.RADIO_PX - float(MarcoCalidad.MARCOS["legendario"]["grosor"]) * 0.5
	var mitad: float = float(MarcoCalidad.LADO_TEX) * 0.5 - MarcoCalidad.INSET
	var esq: int = int(float(MarcoCalidad.LADO_TEX) * 0.5 + (mitad - MarcoCalidad.RADIO_PX) + rad_filo * 0.70710678)
	var rem: Color = (imgs[Objetos.CALIDAD_LEGENDARIO] as Image).get_pixel(esq, esq)
	var sin_rem: Color = (imgs[Objetos.CALIDAD_EPICO] as Image).get_pixel(esq, esq)
	_ok("marco legendario: remache claro en la esquina (y el épico no lo tiene)", rem.a > 0.9 and rem.get_luminance() > 0.7 and sin_rem.get_luminance() < rem.get_luminance())
	_ok("marcos: los tres son distintos entre sí", filo_c != filo_e and filo_e != filo_l and filo_c != filo_l)
	# Animación: solo épico y legendario, con constantes con nombre.
	_ok("animación: común quieto; épico y legendario animan", not MarcoCalidad.anima("comun") and MarcoCalidad.anima("epico") and MarcoCalidad.anima("legendario"))
	_ok("latido épico: siempre entre su mínimo y su máximo y llega a los dos", absf(MarcoCalidad.alfa_latido(0.0) - MarcoCalidad.LATIDO_ALFA_MIN) < 0.001
		and absf(MarcoCalidad.alfa_latido(MarcoCalidad.PERIODO_LATIDO_S * 0.5) - MarcoCalidad.LATIDO_ALFA_MAX) < 0.001)
	_ok("destello legendario: arranca al principio del borde, recorre y descansa", absf(MarcoCalidad.posicion_destello(0.0)) < 0.001
		and MarcoCalidad.posicion_destello(MarcoCalidad.PERIODO_DESTELLO_S * 0.5 * MarcoCalidad.FRACCION_RECORRIDO) > 0.4
		and MarcoCalidad.posicion_destello(MarcoCalidad.PERIODO_DESTELLO_S * (MarcoCalidad.FRACCION_RECORRIDO + 0.1)) < 0.0)
	# El destello va por el borde: todos los puntos del recorrido caen dentro del rectángulo del marco.
	var r := Rect2(0, 0, LADO_HUECO, LADO_HUECO)
	var per: Array = MarcoCalidad._perimetro(r, 3.0)
	var dentro_ok: bool = true
	for i in range(21):
		if not r.grow(0.5).has_point(MarcoCalidad.punto_en(per, float(i) / 20.0)):
			dentro_ok = false
	_ok("destello: el recorrido sigue el borde del marco (todos los puntos dentro del hueco)", dentro_ok)


# ---------------------------------------------------------------------------------------------------------------------
func _huecos() -> void:      # (con await: se llama con await)
	BolsaUI.calidad_prueba = {"seta_asada": "legendario"}
	_ok("mochila: calidad_de usa la de Objetos y respeta el forzado de pruebas", BolsaUI.calidad_de("seta") == "comun" and BolsaUI.calidad_de("nucleo_eco") == "epico"
		and BolsaUI.calidad_de("seta_asada") == "legendario")
	var casos: Array = [["seta", false], ["nucleo_eco", true], ["seta_asada", true]]
	for c in casos:
		var h := BolsaUI.Hueco.new()
		h.id = String(c[0])
		h.cantidad = 2
		h.tam = BolsaUI.TAM_BOLSA
		h.size = Vector2(BolsaUI.TAM_BOLSA, BolsaUI.TAM_BOLSA)
		root.add_child(h)
		await process_frame                      # el _ready de lo añadido durante _initialize se retrasa al primer fotograma
		_ok("hueco de %s: calidad %s, anima=%s, tamaño de hit intacto (%.0f)" % [c[0], h.calidad, str(c[1]), h.size.x], h.is_processing() == bool(c[1]) and h.size == Vector2(LADO_HUECO, LADO_HUECO)
			and h.calidad == BolsaUI.calidad_de(String(c[0])))
		h.queue_free()
	var vacio := BolsaUI.Hueco.new()
	root.add_child(vacio)
	await process_frame
	_ok("hueco vacío: sin marco ni animación", vacio.calidad == "comun" and not vacio.is_processing())
	vacio.queue_free()
	BolsaUI.calidad_prueba = {}


# ---------------------------------------------------------------------------------------------------------------------
func _iconos_y_avisos() -> void:
	var ic := MarcoCalidad.Icono.new()
	root.add_child(ic)
	await process_frame
	ic.configurar("nucleo_eco")
	_ok("icono con marco: lee la calidad del objeto (épico), mide %.0f y anima" % MarcoCalidad.Icono.LADO_PX, ic.calidad == "epico" and ic.size == Vector2(MarcoCalidad.Icono.LADO_PX, MarcoCalidad.Icono.LADO_PX) and ic.is_processing())
	ic.configurar("seta")
	_ok("icono con marco: la seta es común y no anima", ic.calidad == "comun" and not ic.is_processing())
	ic.configurar_calidad("seta", "legendario")
	_ok("icono con marco: la calidad se puede forzar (el glifo del cofre)", ic.calidad == "legendario" and ic.is_processing())
	ic.queue_free()
	# El aviso con icono: se añade, deja sitio, y el siguiente aviso lo quita.
	var l := Label.new()
	l.text = "Núcleo de eco (+1)"
	root.add_child(l)
	AvisoObjeto.estilo_calidad(l, Objetos.color_calidad("nucleo_eco"))
	await process_frame
	var ancho_sin: float = l.get_minimum_size().x
	AvisoObjeto.poner_icono(l, "nucleo_eco", "epico", true)
	await process_frame
	var icono: MarcoCalidad.Icono = l.get_node_or_null(AvisoObjeto.NOMBRE_ICONO) as MarcoCalidad.Icono
	var caja: StyleBoxFlat = l.get_theme_stylebox("normal") as StyleBoxFlat
	_ok("aviso: lleva el icono con marco épico a la izquierda, dentro del panel", icono != null and icono.calidad == "epico" and icono.offset_left >= float(AvisoObjeto.FRANJA_PX)
		and caja.content_margin_left >= icono.offset_right + AvisoObjeto.ICONO_AIRE_PX - 0.001)
	_ok("aviso: con icono el panel es más ancho (%.0f → %.0f) y al menos tan alto como el icono" % [ancho_sin, l.get_minimum_size().x], l.get_minimum_size().x >= ancho_sin + AvisoObjeto.ICONO_PX and l.get_combined_minimum_size().y >= AvisoObjeto.ALTO_MIN_PX - 0.001)
	_ok("aviso: el texto va alineado a la izquierda (el panel mide justo el texto) y con la fuente del tema", l.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and l.theme == TemaInterfaz.tema())
	_ok("aviso: el panel conserva borde y franjas de calidad (lo que miraba prueba_materiales_cueva)", caja.border_width_left == AvisoObjeto.FRANJA_PX and caja.border_width_top == AvisoObjeto.BORDE_PX
		and caja.corner_radius_top_left == TemaInterfaz.ESQUINA_PX)
	AvisoObjeto.estilo_comun(l)
	await process_frame
	_ok("aviso: el siguiente aviso común no hereda el icono ni la altura", l.get_node_or_null(AvisoObjeto.NOMBRE_ICONO) == null and l.custom_minimum_size == Vector2.ZERO)
	AvisoObjeto.poner_icono(l, "seta", "comun", false)
	await process_frame
	var ic2: MarcoCalidad.Icono = l.get_node_or_null(AvisoObjeto.NOMBRE_ICONO) as MarcoCalidad.Icono
	_ok("aviso común: icono con marco sobrio (sin animar)", ic2 != null and ic2.calidad == "comun" and not ic2.is_processing())
	l.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
func _pista_y_barra() -> void:
	var capa := CanvasLayer.new()
	root.add_child(capa)
	var p := PistaInteraccion.new()
	capa.add_child(p)
	_ok("pista: nace apagada y no se come el ratón", not p.visible and p.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	p.mostrar("E", "Hablar")
	await process_frame
	_ok("pista: «[E] Hablar» visible con el tema común", p.visible and p.texto_tecla() == "E" and p.texto_accion() == "Hablar" and p.theme == TemaInterfaz.tema())
	_ok("pista: contraste de sus textos (%.1f, mínimo %.1f)" % [PistaInteraccion.contraste_minimo(), CONTRASTE_MIN], PistaInteraccion.contraste_minimo() >= CONTRASTE_MIN)
	_ok("pista: se encoge al texto, abajo y centrada", p.size.x < 300.0 and p.size.y < 80.0 and absf((p.global_position.x + p.size.x * 0.5) - root.get_visible_rect().size.x * 0.5) < 2.0
		and p.global_position.y + p.size.y < root.get_visible_rect().size.y, "%s en %s" % [str(p.size), str(p.global_position)])
	var b := BarraHud.new()
	capa.add_child(b)
	b.configurar("Vida", Color(0.35, 0.85, 0.4), 1.7)
	_ok("barra: la fracción se acota a 0..1 y mide lo de siempre (244 de ancho)", b.fraccion == 1.0 and b.size.x == BarraHud.ANCHO_PX)
	b.poner_fraccion(-0.5)
	_ok("barra: fracción negativa = 0 y se suaviza (sigue procesando hasta llegar)", b.fraccion == 0.0 and b.is_processing())
	capa.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
func _rotulo() -> void:
	var r: RotuloZona3D = RotuloZona3D.mostrar(root, "Bosque de Terra")
	await process_frame
	var caja: StyleBoxFlat = r.etiqueta.get_theme_stylebox("normal") as StyleBoxFlat if r != null else null
	_ok("rótulo de zona: Label con el tema, panel oscuro con borde cálido y esquinas redondas", r != null and r.etiqueta.theme == TemaInterfaz.tema() and caja != null
		and caja.border_color.is_equal_approx(TemaInterfaz.BORDE_CALIDO) and caja.corner_radius_top_left == TemaInterfaz.ESQUINA_PX and caja.bg_color.a > 0.8)
	_ok("rótulo de zona: el cartel se encoge al texto y está en el tercio de arriba", r.etiqueta.size.x < root.get_visible_rect().size.x * 0.8 and r.etiqueta.size.x > 100.0
		and r.etiqueta.global_position.y < root.get_visible_rect().size.y * 0.5, "%s" % str(r.etiqueta.size))
	_ok("rótulo de zona: texto con el color del tema", r.etiqueta.get_theme_color("font_color").is_equal_approx(TemaInterfaz.TEXTO))
	r.queue_free()
