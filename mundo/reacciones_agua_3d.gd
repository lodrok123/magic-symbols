## ReaccionesAgua3D · qué le hace cada elemento al AGUA de la simulación (M3, 13/10). Sin nodos, sin hechizos.
##
## Es, con el cuerpo tal cual, lo que antes eran `Lanzador3D.hechizo_sobre_agua` y `Lanzador3D.abrir_caudal`. Ahora entra una
## `AccionElemental` (la manda `Mundo3D.aplicar`, o directamente quien no tenga un Mundo3D, como las pruebas).
##
## Lo que NO es del mundo —dibujar vapor, avisar al render del hielo, atrapar troncos y goblins, soltar presos— sale por UN
## `Callable` (`efecto`), que pone Lanzador3D.configurar. Así el mundo no depende hacia arriba de la magia ni del Pipeline.
##   efecto.call(nombre, punto, radio, segundos), con nombre ∈
##     «vapor»          · se evaporó agua (o se fundió hielo) en `punto`
##     «hielo_desde»    · va a helarse desde `punto` (el render hace crecer el hielo desde ahí)
##     «hielo_formado»  · se heló agua en `punto` (radio, segundos): atrapar lo que quede dentro
##     «hielo_cambios»  · la simulación puede haber cambiado hielo: poner al día lo que dependa de él
class_name ReaccionesAgua3D
extends RefCounted

## Agua echada por un hechizo (11.4), en u³. Un impacto de agua es un charco; cada casilla marcada por un muro o un corro, otro.
## 12/10 (Pablo): un 80 % menos (1,2 → 0,24): el agua convocada debe ser sutil; ya se escalará en hechizos grandes.
const VOL_AGUA_IMPACTO: float = 0.24
## Lo que se evapora por un impacto de fuego (u³): un charco desaparece, un río apenas nota un bocado.
## (Un 80 % menos, como el agua que se echa: 1,5 → 0,3.)
const VOL_EVAPORA: float = 0.3
## --- Hielo de verdad (11.13) ---
## Radio (en casillas) del círculo que hiela o funde un impacto. 0,6 casillas = una casilla casi entera, pero sigue la forma del agua.
const RADIO_HIELO: float = 0.6

static var efecto: Callable = Callable()


static func _efecto(nombre: String, punto: Vector3, radio: float = 0.0, segundos: float = 0.0) -> void:
	if efecto.is_valid():
		efecto.call(nombre, punto, radio, segundos)


## Qué hace cada elemento al agua de la simulación en el punto del impacto. El suelo (hielo, mojado…) lo sigue haciendo la maqueta:
## esto es solo el AGUA. Estática para poder medirla sin escena. No hace nada sin simulación o en una casilla con tierra encima (H4).
##   agua  → echa `cantidad` u³ (por defecto VOL_AGUA_IMPACTO: un charco que corre, se suma al río y puede cruzar una presa abierta);
##           con `duracion` > 0 es un MANANTIAL: `cantidad` u³/s en la casilla mientras dura (un chorro);
##   fuego → evapora `cantidad` u³ (por defecto VOL_EVAPORA) y suelta vapor si de verdad quitó agua (no repite el vapor de la maqueta
##           en las «~»); antes funde el hielo del círculo;
##   hielo → si la maqueta heló la casilla (_helada), el agua se queda quieta y no deja pasar más.
## La tierra (presa) no va aquí: construir_tierra → _recalcular → refrescar_casilla.
static func aplicar(a: AccionElemental) -> void:
	if Terreno3D.agua_sim == null or not Terreno3D.hay_mundo():
		return
	var punto: Vector3 = a.punto
	var c: Vector2i = Terreno3D.celda_de(punto)
	if not Terreno3D.en_mapa(c) or Terreno3D.altura_en(c) >= 1:
		return
	var radio_h: float = a.radio if a.radio > 0.0 else Terreno3D.casilla * RADIO_HIELO
	if Mundo3D.actual != null and a.duracion <= 0.0:
		Mundo3D.actual.impacto.emit(punto, a.elemento, radio_h)       # un chorro que dura no es un impacto por casilla
	match a.elemento:
		"agua":
			if a.duracion > 0.0:
				abrir_caudal(c, a.cantidad, a.duracion)
				return
			var vol: float = a.cantidad if a.cantidad > 0.0 else VOL_AGUA_IMPACTO
			Terreno3D.agua_sim.anadir(punto, vol, Terreno3D.casilla * 0.2)     # radio 0,35 → 0,2 casillas (el mínimo de la simulación es medio trocito)
		"fuego":
			# Primero funde el hielo del círculo; si no había, evapora (no las dos cosas con un mismo golpe).
			var fundidos: int = Terreno3D.agua_sim.derretir(punto, radio_h)
			if fundidos > 0:
				_efecto("vapor", punto)
			else:
				var vol_e: float = a.cantidad if a.cantidad > 0.0 else VOL_EVAPORA
				var quitado: float = Terreno3D.agua_sim.quitar(punto, vol_e, Terreno3D.casilla * 0.5)
				if quitado > 0.1 and Terreno3D.letra_de(c) != "~":
					_efecto("vapor", punto)
		"hielo":
			# Hiela los trocitos CON AGUA del círculo, 20 s, y atrapa lo que está dentro (troncos, goblins).
			# El dibujo del hielo crece desde el punto del impacto (Pipeline, 11.16): se avisa ANTES de helar.
			_efecto("hielo_desde", punto)
			if Terreno3D.agua_sim.helar(punto, radio_h, AguaSim3D.DURA_HIELO) > 0:
				_efecto("hielo_formado", punto, radio_h, AguaSim3D.DURA_HIELO)
	_efecto("hielo_cambios", punto)
	if a.elemento == "hielo":
		# La maqueta heló la casilla ENTERA al impactar; la verdad es la simulación (≥ 5 de 9 trocitos): si no llega, se deshace.
		if Terreno3D.helada(c) and not Terreno3D.agua_sim.casilla_helada(c) and Terreno3D.agua_sim.profundidad_casilla(c) > 0.05:
			Terreno3D.poner_helada(c, false)
			if Terreno3D.letra_de(c) == "~":
				Terreno3D.bloquear_celda(c)


## Un chorro de agua es un MANANTIAL mientras dura: suma `caudal` u³/s en la casilla y lo retira al acabar `dura` s. Si ahí ya
## corría un río o había un surtidor, el chorro SUMA a su caudal (por eso es `sumar_fuente` y no `fuente_en`).
static func abrir_caudal(c: Vector2i, caudal: float, dura: float) -> void:
	if Terreno3D.agua_sim == null or not Terreno3D.en_mapa(c) or Terreno3D.altura_en(c) >= 1:
		return
	var sim: AguaSim3D = Terreno3D.agua_sim          # la de ahora: si el nivel se recarga, el temporizador no toca la nueva
	sim.sumar_fuente(c, caudal)
	(Engine.get_main_loop() as SceneTree).create_timer(dura, false).timeout.connect(func() -> void: sim.sumar_fuente(c, -caudal))
