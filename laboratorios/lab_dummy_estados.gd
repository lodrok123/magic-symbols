class_name LabDummyEstados
extends Node3D

## DUMMY DE ESTADOS DEL LAB (18/11/2026, Pablo: «crea en el panel del laboratorio un dummy para ver los estados al aplicarle un elemento»).
## Un muñeco (cápsula) al que se le APLICA un elemento y enseña en qué estado queda: en su cuerpo (tinte, costra de hielo, arcos) y, con números, en el panel del lab.
## NO inventa reglas: cada golpe se lo pregunta a un `Combate3D` suelto (sin árbol ni mundo) con `decidir_golpe`, la misma decisión que usa el juego, y con la runa de serie del
## elemento (`nucleo/<x>_rune.tres`, sin glifos). El dummy solo guarda los relojes que salen de ahí y los va gastando. Así, lo que se ve aquí es lo que haría un enemigo normal
## (sin debilidad ni resistencia): fuego sobre mojado = vapor, hielo sobre mojado congela más, rayo sobre congelado lo rompe, etc.
## Lo que NO hace: no recibe daño de verdad (lleva la cuenta del último golpe), no se mueve, no se empuja, no muere, y no es un enemigo concreto (gólem, limo, elemental).
##   aplicar("hielo") -> Dictionary     la decisión del golpe (la de `Combate3D.decidir_golpe`), ya aplicada a los relojes
##   limpiar()                          quita todos los estados
##   texto() -> String                  las líneas del panel

const RUNAS: Dictionary = {"fuego": "fire", "agua": "water", "hielo": "ice", "rayo": "lightning", "magma": "magma", "viento": "wind", "tierra": "earth", "naturaleza": "naturaleza"}
const ALTO: float = 1.3
const RADIO: float = 0.32
const COLOR_BASE: Color = Color(0.5, 0.52, 0.46)
## [variable, rótulo, color del tinte]
const ESTADOS: Array = [
	["quemando", "QUEMANDO", Color(1.0, 0.4, 0.12)], ["mojado", "MOJADO", Color(0.25, 0.5, 1.0)], ["congelado", "CONGELADO", Color(0.6, 0.92, 1.0)],
	["aturdido", "ATURDIDO (rayo)", Color(1.0, 0.92, 0.35)], ["envenenado", "ENVENENADO", Color(0.45, 0.85, 0.3)], ["enraizado", "ENRAIZADO", Color(0.35, 0.6, 0.25)],
	["lento", "LENTO", Color(0.6, 0.45, 0.3)], ["costra", "COSTRA (tierra o golpe F = roto)", Color(0.75, 0.42, 0.22)]]

## los relojes (s que quedan); con los mismos nombres que Combate3D donde los hay (CongeladoToy lee `congelado` y `muerto`)
var quemando: float = 0.0
var mojado: float = 0.0
var congelado: float = 0.0
var aturdido: float = 0.0
var envenenado: float = 0.0
var enraizado: float = 0.0
var lento: float = 0.0
var costra: float = 0.0                  ## 21/11: triángulo de la demo (fuego sobre lento)
var muerto: bool = false

var ultimo: Dictionary = {}              ## del último golpe: {elemento, dano, mult, avisos, vapor, arco, roto}
var _cerebro: Combate3D = null           ## nunca entra en el árbol: solo decide
var _vis: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _rotulo: Label3D = null
var _arcos: Node = null


func _ready() -> void:
	_cerebro = Combate3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = RADIO
	cm.height = ALTO
	_vis = MeshInstance3D.new()
	_vis.name = "Cuerpo"
	_vis.mesh = cm
	_vis.position = Vector3(0, ALTO * 0.5, 0)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR_BASE
	_vis.material_override = _mat
	add_child(_vis)
	_rotulo = Label3D.new()
	_rotulo.name = "Rotulo"
	_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rotulo.no_depth_test = true
	_rotulo.font_size = 40
	_rotulo.outline_size = 10
	_rotulo.pixel_size = 0.006
	_rotulo.position = Vector3(0, ALTO + 0.45, 0)
	add_child(_rotulo)
	_pintar()


func _exit_tree() -> void:
	if _cerebro != null and is_instance_valid(_cerebro):
		_cerebro.free()
		_cerebro = null


## Aplica un golpe del elemento con su runa de serie. Devuelve la decisión (vacía si el elemento no tiene runa).
func aplicar(elemento: String) -> Dictionary:
	var ruta: String = "res://nucleo/%s_rune.tres" % String(RUNAS.get(elemento, ""))
	if _cerebro == null or not ResourceLoader.exists(ruta):
		return {}
	var h: Hechizo = Hechizo.construir(load(ruta), {})
	_cerebro.mojado = mojado
	_cerebro.quemando = quemando
	_cerebro.congelado = congelado
	_cerebro.enraizado = enraizado
	_cerebro.lento = lento
	_cerebro.costra = costra
	var d: Dictionary = _cerebro.decidir_golpe(h)
	mojado = float(d["mojado"])
	quemando = float(d["quemando"])
	congelado = float(d["congelado"])
	enraizado = float(d["enraizado"])
	costra = float(d["costra"])
	if float(d["lento"]) >= 0.0:
		lento = float(d["lento"])
	if bool(d["aturde"]):
		aturdido = maxf(aturdido, maxf(h.aturde, Combate3D.SOFOCADO_ATURDE_S if bool(d["sofocado"]) else 0.0))
	if bool(d["veneno"]):
		envenenado = maxf(envenenado, h.veneno)
	ultimo = {"elemento": elemento, "dano": float(d["dano"]), "mult": float(d["mult"]), "avisos": (d["avisos"] as Array).duplicate(), "vapor": bool(d["vapor"]), "arco": bool(d["arco"]), "roto": bool(d["roto"]),
		"sofocado": bool(d["sofocado"]), "empapado": bool(d["lento_mojado"])}
	_efectos_de_estado()
	_pintar()
	return d


func limpiar() -> void:
	for e in ESTADOS:
		set(String(e[0]), 0.0)
	ultimo = {}
	_pintar()


func activos() -> Array:
	var r: Array = []
	for e in ESTADOS:
		if float(get(String(e[0]))) > 0.0:
			r.append(e)
	return r


func _process(delta: float) -> void:
	var antes: int = activos().size()
	for e in ESTADOS:
		var n: String = String(e[0])
		set(n, maxf(0.0, float(get(n)) - delta))
	_efectos_de_estado()
	if antes > 0 or not activos().is_empty():
		_pintar()


## Lo que se ve además del tinte: el cuerpo en llamas del que arde (ArdiendoToy), la costra, los cuadraditos y el vaho del congelado (CongeladoToy) y los arcos del aturdido por rayo (EstadoRayoToy).
func _efectos_de_estado() -> void:
	if congelado > 0.0:
		CongeladoToy.asegurar(self, ALTO, RADIO)
	if quemando > 0.0 and not muerto:                                    # 18/11: el cuerpo incandescente, lenguas, brasas y luz (ArdiendoToy)
		ArdiendoToy.asegurar(self, ALTO, RADIO)
	if aturdido > 0.0 and (_arcos == null or not is_instance_valid(_arcos)):
		_arcos = EstadoRayoToy.para_entidad(ALTO, RADIO, aturdido)
		add_child(_arcos)
	elif aturdido <= 0.0 and _arcos != null and is_instance_valid(_arcos):
		_arcos.queue_free()
		_arcos = null


func _pintar() -> void:
	var act: Array = activos()
	var col: Color = COLOR_BASE
	for e in act:
		col = col.lerp(e[2], 0.55)
	if _mat != null:
		_mat.albedo_color = col
	if _rotulo != null:
		var partes: PackedStringArray = PackedStringArray()
		for e in act:
			partes.append("%s %.1f" % [String(e[1]).split(" ")[0], float(get(String(e[0])))])
		_rotulo.text = "\n".join(partes) if not partes.is_empty() else "dummy"
		_rotulo.modulate = col.lightened(0.3) if not partes.is_empty() else Color(1, 1, 1, 0.7)


## Las líneas del panel del lab.
func texto() -> String:
	var s: String = "\nDUMMY DE ESTADOS (Intro aplica el elemento actual · Mayús+Intro lo limpia · Ctrl+Intro lo quita): "
	var act: Array = activos()
	if act.is_empty():
		s += "sin estados"
	else:
		var partes: PackedStringArray = PackedStringArray()
		for e in act:
			partes.append("%s %.1f s" % [e[1], float(get(String(e[0])))])
		s += " · ".join(partes)
	if not ultimo.is_empty():
		var extra: PackedStringArray = PackedStringArray()
		for k in ["vapor", "arco", "roto", "sofocado", "empapado"]:
			if bool(ultimo[k]):
				extra.append(k)
		s += "\n   último golpe: %s → daño %.1f (×%.2f) · reacciones: %s%s" % [String(ultimo["elemento"]).to_upper(), float(ultimo["dano"]), float(ultimo["mult"]),
			", ".join(PackedStringArray(ultimo["avisos"])) if not (ultimo["avisos"] as Array).is_empty() else "ninguna", (" · " + ", ".join(extra)) if not extra.is_empty() else ""]
	return s
