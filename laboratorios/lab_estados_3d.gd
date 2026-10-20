class_name LabEstados3D
extends RefCounted
## Pestaña F5 del laboratorio de hechizos (PLAN_TRES_FRENTES §0/§1; A1+A2, 20/10, Juego): los ESTADOS DE ANIMACIÓN del personaje EN VIVO.
## Enseña el grafo del `ArbolAnimPj` de la jugadora (qué estado se pidió, cuál tiene la máquina, el clip, por dónde va, a qué velocidad), el estado del libro
## (cinto · en_mano_abierto · en_mano_cerrado · volando) y las últimas transiciones con su motivo cuando la regla las rechaza. Con una tecla se FUERZA cada
## transición, para que Pablo vea con sus ojos que no hay estados colgados ni el libro «cosido» a la mano.
##
## No cambia nada del juego: pide las cosas por la API pública de `Pj3D` (`jugar`, `libro_en_manos`, `set_velocidad_animacion`), la misma que usa el resto
## del Juego. Lo monta `LabHechizos3D._montar_f5` y le pasa las teclas mientras F5 está abierta; `paso(delta)` lo llama el `_process` del lab.
## Teclas:  ↑ ↓ rol · Intro / Espacio lo fuerza · I vuelve a idle (reaparecer) · B libro (abre / cierra) · V velocidad del mundo (1 → 0,25 → 0 → 2) · Supr limpia el historial.

## Los roles que se pueden forzar: [rol de Pj3D, una_vez]. Los de «una vez» se quedan en su último fotograma (muerte, golpe, voltereta).
const ROLES: Array = [
	["idle", false], ["walk", false], ["run", false], ["swim", false], ["leer", false], ["cast_proyectil", false], ["cast_corro", false],
	["cast_columna", false], ["cast_muro", false], ["cast_empuje", false], ["hit", true], ["roll", true], ["drink", true], ["death", true],
	["attack", true], ["talk", false],
]
const VELOCIDADES: PackedFloat32Array = [1.0, 0.25, 0.0, 2.0]
const FILAS_HISTORIAL: int = 8

var lab: Variant = null
var sel: int = 0
var ultimo_mensaje: String = ""
var forzados: int = 0
var _vel_i: int = 0


func iniciar(l: Variant) -> void:
	lab = l


func _pj() -> Pj3D:
	var j: Variant = lab.get("_jug") if lab != null else null
	return (j.get("pj") as Pj3D) if j != null else null


func rol_elegido() -> String:
	return String(ROLES[sel][0])


func mover(d: int) -> void:
	sel = posmod(sel + d, ROLES.size())


## Fuerza el rol elegido. Devuelve true si el árbol lo aceptó (false = lo prohíbe una regla o el modelo no tiene ese clip).
func forzar() -> bool:
	var pj: Pj3D = _pj()
	if pj == null or pj.arbol() == null:
		ultimo_mensaje = "(la jugadora no tiene árbol de animación)"
		return false
	var rol: String = rol_elegido()
	forzados += 1
	if pj._buscar_clip(rol) == "":
		ultimo_mensaje = "«%s»: el modelo no trae ese clip" % rol
		return false
	var rech: int = pj.arbol().rechazos
	pj.animacion_actual = ""                      # forzar = pedirlo aunque ya esté puesto
	pj.jugar(rol, bool(ROLES[sel][1]))
	if pj.arbol().rechazos > rech:
		var h: Dictionary = pj.arbol().historial.back()
		ultimo_mensaje = "✗ %s → %s PROHIBIDA: %s" % [h["de"], h["a"], h["motivo"]]
		return false
	ultimo_mensaje = "✓ %s" % Pj3D.estado_de(rol)
	return true


func idle() -> void:
	var pj: Pj3D = _pj()
	if pj != null:
		pj.animacion_actual = ""
		pj.jugar("idle")
		ultimo_mensaje = "✓ idle"


func libro() -> void:
	var pj: Pj3D = _pj()
	if pj == null:
		return
	pj.libro_en_manos(pj.libro_estado() == "cinto" or pj.libro_estado() == "volando")
	ultimo_mensaje = "libro → %s" % pj.libro_estado()


func velocidad() -> void:
	var pj: Pj3D = _pj()
	if pj == null:
		return
	_vel_i = (_vel_i + 1) % VELOCIDADES.size()
	pj.set_velocidad_animacion(VELOCIDADES[_vel_i])
	ultimo_mensaje = "velocidad del mundo ×%.2f%s" % [VELOCIDADES[_vel_i], "  (hitstop: congelado)" if VELOCIDADES[_vel_i] == 0.0 else ""]


## Lo llama el lab al abrir (true) y al salir (false) de la pestaña: mientras F5 está abierta el Jugador3D no pide su animación de cada fotograma (si no, borraría
## en el acto lo que fuerzas con Intro).
func activar(si: bool) -> void:
	var j: Variant = lab.get("_jug") if lab != null else null
	if j != null:
		j.set("animacion_externa", si)
	if not si:
		var pj: Pj3D = _pj()
		if pj != null:
			pj.set_velocidad_animacion(1.0)
			pj.animacion_actual = ""
			pj.jugar("idle")


func paso(_delta: float) -> void:
	pass


func guardar() -> bool:
	return true                                    # nada que guardar: es una pestaña de mirar


func datos() -> Dictionary:
	var pj: Pj3D = _pj()
	if pj == null or pj.arbol() == null:
		return {}
	var a: ArbolAnimPj = pj.arbol()
	return {"estado": a.estado, "real": a.estado_real(), "clip": a.clip_actual(), "libro": pj.libro_estado(), "rechazos": a.rechazos,
		"estados": Array(a.estados()), "historial": a.historial.duplicate(true)}


func tecla(k: InputEventKey) -> bool:
	var arrastre: bool = k.keycode == KEY_UP or k.keycode == KEY_DOWN
	if k.echo and not arrastre:
		return false
	match k.keycode:
		KEY_UP:
			mover(-1)
		KEY_DOWN:
			mover(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			forzar()
		KEY_I:
			idle()
		KEY_B:
			libro()
		KEY_V:
			velocidad()
		KEY_DELETE:
			var pj: Pj3D = _pj()
			if pj != null and pj.arbol() != null:
				pj.arbol().historial.clear()
			ultimo_mensaje = "historial limpio"
		_:
			return false
	return true


func texto() -> String:
	var t: PackedStringArray = []
	t.append("F5 · ESTADOS DE ANIMACIÓN (en vivo)     ↑↓ rol · Intro fuerza · I idle · B libro · V velocidad · Supr limpia")
	var pj: Pj3D = _pj()
	if pj == null or pj.arbol() == null:
		t.append("(la jugadora no tiene árbol de animación: ¿falta el modelo?)")
		return "\n".join(t)
	var a: ArbolAnimPj = pj.arbol()
	var pos: String = "%.2f / %.2f s" % [a.posicion(), a.largo()] if a.listo() else "…"
	t.append("ÁRBOL  pedido «%s» · en la máquina «%s» · clip %s · %s%s" % [a.estado, a.estado_real(), a.clip_actual(), pos, "  [terminado: se queda en el último fotograma]" if a.terminado() else ""])
	t.append("VELOCIDAD  clip ×%.2f · mundo ×%.2f%s     rechazos %d     grafo %s" % [a.vel_estado, a.vel_global, " · RETENIDO (congelado a propósito)" if a.retenido else "", a.rechazos, a.grafo])
	t.append("LIBRO  %s%s" % [pj.libro_estado(), "" if pj.libro_valido() else "   ← ¡estado incoherente!"])
	t.append("")
	t.append("ROLES (> elegido · ● estado actual · ✗ prohibido desde el estado actual · · aún no pedido)")
	for i in range(ROLES.size()):
		var rol: String = String(ROLES[i][0])
		var est: String = Pj3D.estado_de(rol)
		var sin_clip: bool = pj._buscar_clip(rol) == ""
		var motivo: String = a.motivo_prohibida(a.estado, est) if est != a.estado else ""
		var marca: String = "●" if est == a.estado else ("✗" if motivo != "" else ("·" if not a.estados().has(est) else " "))
		t.append(" %s %-16s → %-18s %s%s" % [">" if i == sel else " ", rol, est, marca, "   (el modelo no trae este clip)" if sin_clip else ("   " + motivo if motivo != "" else "")])
	t.append("")
	t.append("ÚLTIMAS TRANSICIONES")
	var h: Array = a.historial
	for j in range(maxi(h.size() - FILAS_HISTORIAL, 0), h.size()):
		var e: Dictionary = h[j]
		t.append("   %s %s → %s%s" % ["✓" if bool(e["ok"]) else "✗", e["de"] if String(e["de"]) != "" else "(inicio)", e["a"], "   " + String(e["motivo"]) if String(e["motivo"]) != "" else ""])
	if ultimo_mensaje != "":
		t.append("» " + ultimo_mensaje)
	return "\n".join(t)
