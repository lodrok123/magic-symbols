class_name CorazaElemento3D
extends Node3D

## B1 de docs/PLAN_COMBATE_2026-11-22.md (C1, escudos de elemento; Pablo 22/11: «valen los tres» y «sí» a los casos contraproducentes que se ven venir). Dueño: Juego.
##
## Una CAPA sobre todo el cuerpo de un enemigo (no un disco en el brazo como `Escudo3D`): cubre por todos los lados y solo la rompe UN elemento. Mientras está entera,
## ningún hechizo llega al enemigo: o la rompe, o la cambia, o rebota en ella («Bloqueado»). Rota, el enemigo es vulnerable a todo como siempre.
## Obliga a cambiar de página: el fuego + flecha de siempre no sirve contra ellas.
##
##   material «barro» (coraza de barro seco, goblin)  · la rompe la TIERRA (2 golpes; 1 si está ablandada)
##                                                    · el AGUA la ablanda T_ABLANDA s (se ve oscura y húmeda): el siguiente golpe de tierra la rompe
##                                                    · el FUEGO la cuece: se endurece (+1 golpe, hasta GOLPES_MAX) y se ve rojiza. Contraproducente, pero se ve.
##   material «brasa» (costra de brasa, limo de fuego) · la rompe el AGUA (1 golpe: vapor)
##                                                    · el FUEGO la aviva: +1 golpe (hasta GOLPES_MAX), brilla más. Contraproducente, pero se ve.
##                                                    · la TIERRA rebota
##
## CÓMO SE CONSULTA: igual que el escudo. `Combate3D.on_spell_hit` pregunta `coraza.para(direccion, hechizo)` antes de aplicar nada; si responde true, el golpe ya lo recibió
## la coraza. `cubre` y `reaccion_a` son la misma decisión sin tocar nada (la previsión). Se equipa con `CorazaElemento3D.equipar(combate, material)`.
## Mientras está entera, el rombo y el borde del enemigo van del color del elemento que la rompe; al romperse vuelven al de su debilidad.

const MATERIALES: Dictionary = {
	"barro": {"rompe": "tierra", "ablanda": "agua", "endurece": "fuego", "golpes": 2, "color": Color(0.55, 0.4, 0.26), "rotulo": "Coraza de barro"},
	"brasa": {"rompe": "agua", "ablanda": "", "endurece": "fuego", "golpes": 1, "color": Color(0.16, 0.1, 0.08), "rotulo": "Costra de brasa"},
}
const GOLPES_MAX: int = 3                     ## lo más dura que se pone (endurecida)
const T_ABLANDA: float = 6.0                  ## s que el barro mojado sigue blando
const EMPUJE_REBOTE: float = 1.6              ## u/s del empujón sin daño cuando un hechizo rebota en ella
const ALFA: float = 0.82
const RADIO_K: float = 0.42                   ## radio de la capa respecto al alto del enemigo
const COLOR_ENDURECIDA: Color = Color(0.72, 0.3, 0.16)
const COLOR_ABLANDADA: Color = Color(0.25, 0.2, 0.16)
const EMISION_BRASA: Color = Color(1.0, 0.38, 0.08)

signal rota(material: String)

var combate: Combate3D = null
var material: String = "barro"
var golpes: int = 2
var estado: String = "entera"                 ## entera · rota
var ablandada_t: float = 0.0
var rebotes: int = 0                          ## hechizos que rebotaron (para las pruebas)
var endurecidas: int = 0
var _malla: MeshInstance3D = null
var _mat: StandardMaterial3D = null


## Le pone a `c` una coraza de `p_material` (o devuelve la que ya tiene).
static func equipar(c: Combate3D, p_material: String = "barro") -> CorazaElemento3D:
	if c == null or not MATERIALES.has(p_material):
		return null
	if c.coraza != null and is_instance_valid(c.coraza):
		return c.coraza
	var k := CorazaElemento3D.new()
	k.name = "Coraza"
	k.combate = c
	k.material = p_material
	k.golpes = int(MATERIALES[p_material]["golpes"])
	c.coraza = k
	c.add_child(k)
	k._construir()
	k._pintar_marca()
	return k


func rompe_con() -> String:
	return String(MATERIALES[material]["rompe"])


func activa() -> bool:
	return estado == "entera" and combate != null and is_instance_valid(combate) and not combate.muerto


## ¿Para este hechizo? Cubre por todos los lados mientras esté entera (la dirección no importa; se deja por simetría con `Escudo3D.cubre`).
func cubre(_direccion: Vector3, hechizo: Hechizo) -> bool:
	return hechizo != null and activa()


## Qué le haría el hechizo (sin tocarla): «rompe», «agrieta» (le quita un golpe sin romperla), «ablanda», «endurece» o «rebota».
func reaccion_a(hechizo: Hechizo) -> String:
	var m: Dictionary = MATERIALES[material]
	var el: String = hechizo.elemento
	if el == String(m["rompe"]):
		var quita: int = 2 if ablandada_t > 0.0 else 1
		return "rompe" if golpes - quita <= 0 else "agrieta"
	if el != "" and el == String(m["ablanda"]):
		return "ablanda"
	if el != "" and el == String(m["endurece"]):
		return "endurece"
	return "rebota"


## EL PUNTO DE CONSULTA de `Combate3D`: si responde true, la coraza ya recibió el golpe y el enemigo no.
func para(direccion: Vector3, hechizo: Hechizo) -> bool:
	if not cubre(direccion, hechizo):
		return false
	_recibir(hechizo, direccion)
	return true


func _recibir(h: Hechizo, direccion: Vector3) -> void:
	var r: String = reaccion_a(h)
	match r:
		"rompe":
			_romper()
		"agrieta":
			golpes -= 2 if ablandada_t > 0.0 else 1
			ablandada_t = 0.0
			combate.texto("¡Se agrieta!", MATERIALES[material]["color"], 0.28)
			Sensacion3D.golpe_sordo(combate)
			_temblar()
		"ablanda":
			ablandada_t = T_ABLANDA
			combate.texto("Se ablanda", Combate3D.COLORES.get(h.elemento, Color.WHITE), 0.26)
		"endurece":
			golpes = mini(golpes + 1, GOLPES_MAX)
			endurecidas += 1
			ablandada_t = 0.0
			combate.texto("¡Se endurece!" if material == "barro" else "¡Se aviva!", COLOR_ENDURECIDA, 0.28)
		_:
			rebotes += 1
			combate.texto("Bloqueado", Color(0.75, 0.72, 0.68), 0.26)
			Sensacion3D.golpe_sordo(combate)
			var d := Vector3(direccion.x, 0.0, direccion.z)
			if d.length() > 0.01 and combate.enraizado <= 0.0:
				combate._empuje += d.normalized() * EMPUJE_REBOTE
	_actualizar_aspecto()
	PlayLog.event("coraza_recibe", {"material": material, "elemento": h.elemento, "reaccion": r, "golpes": golpes})


func _romper() -> void:
	if estado == "rota":
		return
	estado = "rota"
	golpes = 0
	ablandada_t = 0.0
	if combate != null and is_instance_valid(combate):
		combate.texto("¡%s rota!" % ("Coraza" if material == "barro" else "Costra"), Combate3D.COLORES.get(rompe_con(), Color.WHITE), 0.34)
		Sensacion3D.golpe_sordo(combate)
		_pintar_marca()
	if _malla != null:
		var tw: Tween = _malla.create_tween()
		tw.tween_property(_malla, "scale", Vector3.ONE * 1.25, 0.12)
		tw.parallel().tween_property(_mat, "albedo_color:a", 0.0, 0.25)
		tw.tween_callback(_malla.hide)
	rota.emit(material)
	PlayLog.event("coraza_rota", {"material": material})


func _construir() -> void:
	var alto: float = maxf(combate.altura, 0.6)
	var cap := CapsuleMesh.new()
	cap.radius = alto * RADIO_K
	cap.height = alto * 1.08
	cap.radial_segments = 16
	cap.rings = 6
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 1.0
	_mat.cull_mode = BaseMaterial3D.CULL_BACK
	_malla = MeshInstance3D.new()
	_malla.name = "Capa"
	_malla.mesh = cap
	_malla.material_override = _mat
	_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_malla.position = Vector3(0.0, alto * 0.52, 0.0)
	add_child(_malla)
	_actualizar_aspecto()


func _actualizar_aspecto() -> void:
	if _mat == null or estado == "rota":
		return
	var base: Color = MATERIALES[material]["color"]
	var k_duro: float = clampf(float(golpes - int(MATERIALES[material]["golpes"])) / float(maxi(GOLPES_MAX - int(MATERIALES[material]["golpes"]), 1)), 0.0, 1.0)
	var c: Color = base.lerp(COLOR_ENDURECIDA, k_duro * 0.6) if material == "barro" else base
	if ablandada_t > 0.0:
		c = COLOR_ABLANDADA
	_mat.albedo_color = Color(c, ALFA)
	_mat.metallic_specular = 0.9 if ablandada_t > 0.0 else 0.2
	_mat.roughness = 0.35 if ablandada_t > 0.0 else 1.0
	_mat.emission_enabled = material == "brasa"
	if material == "brasa":
		_mat.emission = EMISION_BRASA
		_mat.emission_energy_multiplier = 0.6 + 0.5 * float(golpes - 1)


## El rombo y el borde del enemigo: del color del elemento que rompe la coraza mientras está entera; al romperse, el de su debilidad (como siempre).
func _pintar_marca() -> void:
	if combate == null or not is_instance_valid(combate):
		return
	var el: String = rompe_con() if estado == "entera" else combate.debil
	var col: Color = Combate3D.COLORES.get(el, Color.WHITE)
	if combate._marca_debil != null and is_instance_valid(combate._marca_debil):
		combate._marca_debil.modulate = col
	if combate.pj != null and is_instance_valid(combate.pj):
		combate.pj.set_rol_visual("enemigo", (Combate3D.COLORES.get(el, Pj3D.RIM_ENEMIGO) as Color).lerp(Color.WHITE, 0.25))


func _temblar() -> void:
	if _malla == null:
		return
	var tw: Tween = _malla.create_tween()
	tw.tween_property(_malla, "scale", Vector3(1.08, 0.94, 1.08), 0.05)
	tw.tween_property(_malla, "scale", Vector3.ONE, 0.1)


func _physics_process(delta: float) -> void:
	if combate == null or not is_instance_valid(combate) or combate.muerto:
		visible = false
		return
	if ablandada_t > 0.0:
		ablandada_t = maxf(0.0, ablandada_t - delta)
		if ablandada_t <= 0.0:
			_actualizar_aspecto()
