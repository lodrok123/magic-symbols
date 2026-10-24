# Autotests de resolubilidad de niveles: diseño listo para implementar

Encargo de Pablo: «Diseña autotests para los niveles para probar que los niveles son resolvibles.»
Autor: ingeniero de pruebas (sesión de análisis, 24/10). **No se ha tocado el repo**: todo lo medido se ha corrido con scripts del scratchpad.
Rama analizada: `claude/proyecto-analisis-profundo-bf47f8` (commit 7a91ea36).

> **Aviso de método.** El worktree no tiene caché `.godot`. Por eso Godot se lanzó con `--path` sobre la copia principal
> (`C:\Users\pablo\Documents\magic-symbols`). Está en el mismo commit, pero tiene **cambios sin commit de Pablo**
> (entre ellos `escenas/puzle.gd` y `mundo/datos_nivel/mapas/Cueva.txt`). Los prototipos estáticos leen los **mapas del worktree**
> (variable `PROTO_MAPAS`) con el **código** de la copia principal. El escenario del Bosque corrió entero sobre la copia principal, así
> que su tramo de la Cueva usó la Cueva modificada.

---

## 0. Resumen en diez líneas

1. **Hoy no hay ninguna prueba de resolubilidad.** Los escenarios siguen un guion de pasos y se saltan justo lo que habría que demostrar.
   `escenario_bosque_01_v01.gd` tiene 170 `_ok`, 44 `colocar_jugador`, 0 `mover_hacia` y 4 `Flags.i().poner`. Enciende a mano
   (`encender_llama`), mata con `muerto = true`, prende con `_poner_fase` y quema con `on_spell_hit` directo.
2. **Medido:** `escenario_bosque_01_v01` tarda **119,6 s** de reloj (173 OK, **0 FALLO**, 5 AVISO). Dos de esos avisos dicen que la
   pasarela **se cruza sin barrera con 0 de daño** (4.10 andando, 5,1 s; 4.11 corriendo, 2,7 s).
3. **Medido:** un prototipo de la capa 1 (regiones + piezas como puertas + coherencia de flags) tarda **3–16 ms por nivel** y 2,5 s
   contando el arranque de Godot. Ya saca el grafo de regiones del Bosque 01 v01 (15 regiones), de la Cueva (5) y de PlaytestEoW (2).
4. Hacen falta **dos capas**. La **capa 1** (estática, segundos) demuestra que **existe** una solución y busca bloqueos sin salida
   (*soft locks*) en el espacio de estados. La **capa 2** (dinámica, minutos) demuestra que esa solución **funciona de verdad** con la
   física, los tiempos y las piezas reales.
5. **Medido:** la capa 1 sola da falsos positivos. La losa del estanque (16,9) parecía una trampa estática. Andando de verdad, el agua
   llega a (16,10) a los 19 s y la jugadora sale igual a (15,11). La capa 2 hace falta.
6. Los niveles se declaran sin código con líneas `; prueba …` en su mapa. Hace falta una línea nueva en `HorneadorNivel.leer_extras`
   (gramática exacta en §3.2).
7. Las «capacidades» del jugador no se escriben a mano. Se generan llamando a `Hechizo.construir` para **todas** las combinaciones del
   repertorio: 6 sellos × multiconjuntos de 8 glifos hasta 6 = 18 018 construcciones.
8. **Problemas reales ya detectados:**
   - **(a)** En el Bosque 01 v01 la barrera no es obligatoria. Además ya está en el repertorio inicial (`kit = "pruebas"`), así que el
     cofre legendario no enseña nada.
   - **(b)** Con ese mismo kit, el arroyo se cruza con hielo, sin el tronco.
   - **(c)** El cofre legendario de la Cueva se desella **solo**: la fuente late cada 4 s y su pulso llega al receptor sin que la
     jugadora haga nada.
   - **(d)** Con la progresión real `bosque` (fuego + flecha), la Cueva **no es resoluble**: la grieta pide tierra y la lava pide agua o
     hielo. Esto es razonado, no corrido: lo calculará la capa 1 con el barrido de repertorios.
9. Orden de implementación:
   - **S:** capa 1 de regiones, flags y referencias.
   - **M:** buscador de estados con capacidades e invariantes, y el plan.
   - **L:** autómata de la capa 2, fuzz y generador de reacciones.
10. Límites: no detecta diseño aburrido ni puzles triviales (salvo «se resuelve solo» o «sin el glifo que enseña»), ni bugs de timing
    finos que la capa 2 no ejercite.

---

## 1. Qué hay hoy (medido)

### 1.1 Las pruebas que sirven de base

Recuento con `Select-String` sobre cada archivo (llamadas en el código, no comprobaciones ejecutadas):

| prueba | tipo | `_ok` | `colocar_jugador` (teletransporte) | `mover_hacia` (andar con teclas) | qué comprueba |
|---|---|---|---|---|---|
| `escenario_base.gd` | armazón | – | define | define | carga la escena real, el reloj por deltas, `lanzar`, `lanzar_a_celda`, `mover_hacia`, `eventos` del PlayLog |
| `escenario_bosque_01_v01.gd` | escenario, guion | 170 | 44 | 0 | montaje, zonas, la linde, el paso batido, la gente, los rompibles, la llave, el campamento, los tótems, lo quemado, la misión y el viaje a la Cueva. Los pasos se fuerzan |
| `escenario_playtest_eow.gd` | escenario, guion | 182 | 31 | 0 | las salas 1–7 del laboratorio |
| `escenario_cueva_pulso.gd` | escenario, guion | 105 | 11 | 0 | cristal, vetas, prisma, receptor y cofre ᚱ |
| `escenario_puzles_fuego.gd` | escenario, guion | 64 | 8 | 0 | F1–F5 con flechas reales (`lanzar_a_celda`) |
| `escenario_bosque_01_ramas.gd` | escenario | – | sí | **sí** | el **único** con BFS de alcanzabilidad (`_alcanzables`) y paseos a pie (`_caminar`). Las «llaves» son una **lista a mano** de casillas |
| `prueba_caminos.gd` | sin escena | 33 | 0 | 0 | A* de `Caminos3D` con alturas, hielo y muros sobre `Terreno3D.cargar_datos` (mundo de datos, sin maqueta) |
| `prueba_mapa_abierto.gd` | escenario | 99 | 24 | 0 | gramática y comportamiento de jarrón, salida, entrada, puerta con llave y zonas |
| `prueba_sala_cerrada.gd` | sin escena | 48 | 0 | 0 | vigía + cerrojo + cofre + flags y recarga |
| `prueba_puzle_condiciones.gd` | sin escena | 44 | 0 | 0 | parseo y evaluación de `si=` (`+`, `\|`, `!`, `casilla()`, `flag.`, `$`) |
| `prueba_misiones.gd` | sin escena | 57 | 0 | 0 | datos de `Misiones` |
| `prueba_asistencia.gd` | sin escena | 31 | 0 | 0 | precedente útil: **genera** trazos sintéticos en lugar de escribirlos («deja una fuera») |

**Conclusión:** todo lo que existe son **pasos guionizados** («enciende esto, espera, comprueba la flag»). Ninguna prueba pregunta
«¿desde S, con el repertorio inicial, se llega a la meta?». Tampoco «¿hay un estado alcanzable desde el que ya no se puede?».
`escenario_bosque_01_v01` lo declara en su cabecera: *«Qué NO prueba: el recorrido a pie de punta a punta»*.

### 1.2 Tiempos

- `pruebas_resultado.txt` (20/10) y los `salida*.txt` de la raíz **no guardan tiempos**: solo veredictos. En la batería del 20/10 había
  46 fallos, con `escenario_bosque_01` = 6 y `escenario_bosque_01_ramas` = 4.
- **Corrido ahora:** `escenario_bosque_01_v01` = **119,6 s** de reloj, 226 líneas, 173 OK, **0 FALLO**, 5 AVISO. Solo deja ruido de fugas
  de Godot al salir (340 recursos y 1329 instancias ObjectDB), que `resumen_prueba.ps1` ya descarta.
  Salida: `C:\Users\pablo\AppData\Local\Temp\claude\C--Users-pablo-Documents-magic-symbols--claude-worktrees-proyecto-analisis-profundo-bf47f8\bbc0c028-6f87-4f66-b0a3-93d912d2e3fc\scratchpad\salida_bosque_v01.txt`.
- **Medida de la losa** (§9.1 f): 30 s de simulación + carga = **31,4 s de reloj**. Con `--fixed-fps 30 --headless` la escena corre a
  ≈ 1× tiempo real, así que **la capa 2 dura lo que dura jugar el plan**.
- **Prototipo estático:** 3,8–15,8 ms por nivel; 2,5 s el proceso entero.

### 1.3 Los avisos del Bosque que importan

```
AVISO 4.10 recorrer la pasarela ANDANDO y sin barrera   { "dano": 0.0, "tiempo": 5.1, "casts": 0, "flechas": 2, "llego": true }
AVISO 4.11 recorrer la pasarela CORRIENDO y sin barrera { "dano": 0.0, "tiempo": 2.7, "casts": 0, "flechas": 2, "llego": true }
AVISO 4.12 recorrer la pasarela CON barrera             { "dano": 0.0, "tiempo": 13.1, "casts": 6, "flechas": 8, "llego": true }
```

La 4.13 lo acepta a propósito («NO es una puerta dura»). Ojo: `_cruzar` mueve `jugador.position` a mano (no usa teclas).
`docs/PENDIENTES.md:151` lo recoge: *«hoy se puede cruzar sin barrera perdiendo 0–24 de vida»*.

---

## 2. Por qué hacen falta las dos capas

| | Capa 1: análisis estático | Capa 2: recorrido dinámico |
|---|---|---|
| Pregunta | ¿**existe** una secuencia de acciones que llega a la meta? ¿hay estados sin salida? | ¿esa secuencia **funciona** en la escena real? |
| Cubre | **todo** el espacio de estados (todas las órdenes, todos los repertorios del barrido) | **un** camino (o unos pocos) y el fuzz |
| Coste | ms por nivel | ≈ tiempo de juego real (minutos) |
| Se equivoca en | física, tiempos, colisión real, IA, agua (falsos positivos y negativos) | lo que no recorre (una sola ruta) |
| Medido aquí | trampa en la losa (16,9) | la losa no atrapa: el agua tarda 19 s y se sale igual |

La capa 1 **genera** el plan que la capa 2 **ejecuta**. Si la capa 2 falla en un paso que la capa 1 cree posible, hay un error en una de
las dos: o en el modelo o en el juego. Las dos se corrigen mirando el mismo paso.

---

## 3. Capa 1: análisis estático del mapa

### 3.1 Archivos

Sin `class_name`, con `preload`: las clases nuevas no entran en la caché global hasta abrir el editor. Lo mismo pasa con los `.uid`
del DIARIO. Así se corre en headless desde el primer día.

| archivo | qué es |
|---|---|
| `herramientas/resolubilidad/modelo_nivel.gd` | carga un nivel: letras (copia de `leer_mapa` sin rellenar), piezas y reglas (`Puzle3D.parsear`), extras (`leer_extras`, con las líneas `; prueba` nuevas), y las regiones a pie |
| `herramientas/resolubilidad/capacidades.gd` | del repertorio a las capacidades, con `Hechizo.construir` |
| `herramientas/resolubilidad/reacciones.gd` | tabla «letra o tipo de pieza → requisito para abrirla, consumirla o activarla» y «señal → efecto». Semilla escrita y **verificada** por `prueba_reacciones_piezas.gd` (§3.13) |
| `herramientas/resolubilidad/buscador.gd` | grafo de estados, búsqueda, invariantes, plan y `.dot` |
| `herramientas/prueba_resolubilidad.gd` | **la prueba de la batería**: recorre los niveles, imprime `OK`/`FALLO`/`AVISO` y `FALLOS: n` |
| `herramientas/prueba_reacciones_piezas.gd` | comprueba la tabla de reacciones contra las piezas de verdad (paso 3) |

**Lista de niveles: sale sola.** Son todos los `mapas/*.txt` con al menos una línea `; prueba`, más los niveles de `Niveles.ESCENAS`
alcanzables desde ellos por `salida`. Un nivel de `ESCENAS` sin `; prueba` da AVISO («nivel sin meta declarada»). Las copias
(`Bosque_01_copia_*.txt`) no llevan `; prueba` y no se tocan.

### 3.2 Gramática nueva `; prueba` (propuesta exacta)

Va dentro de comentarios `;`, como `nombre`, `marcador` y `decorado`. `leer_mapa` y `Puzle3D.parsear` ya la ignoran.

```
; prueba meta=<cond> [repertorio=<rep>] [inicio=S|<id de entrada>] [opcionales=<id>,<id>…] [perdibles=<id>:<razón>,…] [secretos=<id>,…]
; prueba barrido repertorio=<rep>[;<rep>…] [meta=<cond>]          ← se repite la búsqueda con otros repertorios (la progresión real)
; prueba exige <id_pieza|x,y> glifo=<g>|sello=<s> [desde=<x,y>]     ← obligatoriedad: sin ese glifo NO debe existir camino hasta ahí
; prueba paso <nombre> de=<x,y> a=<x,y> exige=glifo:<g>|sello:<s>   ← lo mismo para retos sin pieza (la pasarela)
; prueba regla <nombre> requiere=<req> pone=<flag>                  ← reglas que hoy viven en código (tótems): ver abajo
; prueba abre <x,y> si=<expresión si=>                              ← casilla que se libera con una condición (la puerta X)
; prueba ventana andar_s_casilla=<s> margen=<s> hielo_max=<n>       ← parámetros de tiempo (§3.9)
; prueba fuzz salas=<rect>[+<rect>…] lanzamientos=<n> semilla=<n>   ← capa 2, modo fuzz
; prueba plan <archivo.json>                                        ← plan escrito a mano para la capa 2 (si no, el que genere la capa 1)
```

- `<cond>` es la misma expresión de `si=` (`flag.x`, `pieza.cond`, `+`, `|`, `!`): se reutiliza `Puzle3D._leer_si`.
- `<rep>` es `kit:pruebas` · `progresion:bosque` (lee `Lanzador3D.PROGRESIONES`) · `sellos:fuego,agua/glifos:flecha,barrera`.
  Por defecto es la progresión de la escena (`kit` o `nivel`, como `Lanzador3D.progresion_de`).
- `<req>` es una lista `capacidad@x,y` unida con `+` (Y) y `|` (O). Por ejemplo `prende@18,9+prende@19,9`.

**Cambio exacto en `mundo/hornear_nivel.gd` → `leer_extras`.** Añade una clave y no rompe a nadie: el horneado no la lee.

```gdscript
var res: Dictionary = {"nombres": {}, "marcadores": [], "decorados": [], "pruebas": []}
...
		match p[0]:
			...
			"prueba":
				# ; prueba <sub> [palabra suelta…] clave=valor …   (24/10 · autotest de resolubilidad)
				if p.size() >= 2:
					var pr: Dictionary = {"sub": p[1], "args": [], "kv": {}, "linea": l}
					for i in range(2, p.size()):
						var kv3: PackedStringArray = p[i].split("=", true, 1)
						if kv3.size() == 2:
							(pr["kv"] as Dictionary)[kv3[0]] = kv3[1]
						else:
							(pr["args"] as Array).append(p[i])
					(res["pruebas"] as Array).append(pr)
```

La validación (sub desconocido, id inexistente, flag mal escrita) la hace `modelo_nivel.gd` y sale como **FALLO** con el número de línea,
con el mismo estilo que los `avisos` de `Puzle3D`.

### 3.3 Qué lee el modelo

1. **Letras.** Las filas del `.txt` y su leyenda:
   - Bloquean (copiado de `PruebaTest2._colocar_letras`, `presentacion/prueba_test2.gd:3337–3521`): `" #zlrjkiBFTDsfqtxVyoeuMmnQX"`,
     más la casilla a la derecha de `n` y `Q` (el puesto).
   - El agua `~` solo se pisa con hielo físico (`Terreno3D.pisable`).
   - Se pisan: `. , g v c R b S - L U K p a w h E`.
   - Una letra que no esté ni en `LETRAS_SUELO`, ni en `LETRAS_DECOR`, ni en `MarcadorTablero.LETRAS` (`mundo/marcador_3d.gd:51`), ni en la
     lista de «letras del lab» declarada (`; prueba letras_lab=!@Z` para PlaytestEoW) da **FALLO (5)**.
2. **Piezas y reglas:** `Puzle3D.parsear(texto)`. Si devuelve `avisos`, es **FALLO (5)**.
3. **Extras:** `nombres`, `marcadores` (datos: `tronco_puente` crea una casilla de puente posible; `loberno` y `asesino` son enemigos
   sueltos) y `pruebas`.
4. **Lectores externos de flags.** Todas las cadenas `"<prefijo>."` que aparecen en el script de reglas del nivel. Se saca con
   `FileAccess` + regex sobre los `.gd` del nodo *Reglas* de la escena (`PackedScene.get_state()`, como `_leer_marcas_por_nombre`).
   Así `bosque01v1.linde.cofre` cuenta como leída (la lee `_sincronizar_mision`), sin escribirlo a mano.
5. **Fuente alternativa `--fuente=escena`.** Monta la escena de verdad sin ventana (≈ 2–5 s hasta el velo) y lee `Terreno3D.pisable`
   ya montado: colisión real y huellas del `.tscn` horneado. Compara con las letras. Una casilla pisable por letras y bloqueada en la
   escena es **FALLO**. Esa es justo la clase de bug del DIARIO 16/10: una `roca_grande` desbordada cerraba un pasillo y el BFS solo
   alcanzaba 72 casillas.

### 3.4 Puertas: la tabla de reacciones

Una **puerta** es una casilla o pieza que separa regiones hasta que algo pasa. Esta es la semilla (`reacciones.gd`), sacada del código y
de la cabecera de `escenas/puzle.gd`:

| puerta | requisito (capacidad) | efecto | ¿reversible? |
|---|---|---|---|
| `r` telaraña, `y` puerta goblin, `o` torre, `z` seto | `prende` a tiro | consume la casilla (flag `…quemado.c<x>_<y>` en el Bosque v01) | no |
| `~` agua | `hiela_agua` a tiro: pisable 20 s (`AguaSim3D`) · `puente` (tronco con `prende`) | casilla de paso | hielo **sí** (caduca); tronco no |
| `muro` (golpes=n) | n × `golpe_tierra` o `explosion` cercana | libera la casilla | no |
| `lava` (vuelve=s) | `moja` o `hiela` a tiro: la casilla y sus 4 vecinas pasan a roca | casillas de paso | **sí**, a los `vuelve` s |
| `pared_hueca` | `pulso_jugador` (ᚱ) que llegue por veta o a tiro | libera + `flag` | no |
| `puerta` sin llave | la regla que la abre | libera | según `hace=…cerrar` |
| `puerta llave=` | flag `llave` + estar delante (E a ≤ 2,7 u: **solo vecina ortogonal**, porque la diagonal mide 3,25 u) | libera, `gasta=si` quita la flag | no |
| `cerrojo` | nace abierto; se **cierra** al pisar `sala`; se abre con su regla o con `hasta` | – | cierra una vez |
| `jarron`/`caja` | cualquier golpe | libera | no |
| `cofre` | ocupa su casilla; se abre con E desde una vecina ortogonal si `aparece_si` y `abre_si` se cumplen | `abierto`, `glifo`, `da` | no |
| `X` (puerta de tótems, regla en código) | `; prueba abre 21,15 si=…` | libera | no |
| `cristal`, `prisma`, `receptor`, `emisor` | nunca (bloquean siempre) | – | – |

Las **señales** se modelan con un mini-motor de reglas que interpreta las reglas ya parseadas (`r["acciones"]`):
- `pulsado` (presencia: la casilla es alcanzable; magia: cualquier hechizo a tiro);
- `todos` del contador (cada casilla de `de` necesita `prende` a tiro);
- `todos_derrotados` del vigía (§3.8);
- `rota` de la cuerda (`prende`);
- `explota` del barril (`prende` o contagio por la fila de setos);
- `alcanzado`/`perdido` del nivel de agua, y el resto de las de `SENAL_DEFECTO`.

Las piezas con **física** (manantial, cuenca, nivel, compuerta, molino, relé de braseros) se tratan como **optimistas**: «la señal
llegará». Salen con **AVISO** «lo confirma la capa 2». Así el modelo no finge saber de agua.

### 3.5 Capacidades: se generan, no se escriben

```gdscript
## capacidades.gd
const ALCANCE_EN_PUNTO: int = 3          ## casillas: `barrera` nace donde apuntas, a 3 como mucho (ARQUITECTURA, tabla de glifos)

## Todas las páginas posibles con este repertorio → qué sabe hacer el jugador y a qué distancia (casillas).
static func capacidades(sellos: PackedStringArray, glifos: PackedStringArray, glifos_por_pagina: int, tinta_max: float) -> Dictionary:
	var caps: Dictionary = {}            # nombre -> {alcance: int, receta: String (la más barata que lo logra), coste: float}
	for s in sellos:
		var rune: RuneData = load("res://magia/runas/%s.tres" % s)       # ruta real: la que usa Lanzador3D (comprobar al implementar)
		for multiconjunto in _multiconjuntos(glifos, glifos_por_pagina):  # {nombre: veces}, incluido el vacío
			var h: Hechizo = Hechizo.construir(rune, multiconjunto, 1.0)
			if h.coste_tinta > tinta_max:
				continue                                                  # no se puede lanzar ni con la barra llena
			var alcance: int = _alcance(h)
			for cap in _clasificar(h):
				_quedarse_mejor(caps, cap, alcance, h)
	return caps

static func _alcance(h: Hechizo) -> int:
	if h.haz: return int(floor(h.alcance_haz))                 # 3..6 m = casillas (1 m = 1 casilla en los hechizos)
	if h.viaja: return int(floor(h.distancia_max))             # flecha: 2 m, +1 por flecha (tope 6)
	if h.en_punto: return ALCANCE_EN_PUNTO
	return 1                                                   # esfera quieta: su casilla y la vecina

static func _clasificar(h: Hechizo) -> PackedStringArray:
	var c := PackedStringArray()
	if h.temperatura > 0.0 or h.etiquetas.has("fuego"): c.append("prende")
	if h.elemento == "agua": c.append_array(["moja", "enfria_lava"])
	if h.elemento == "hielo": c.append_array(["hiela_agua", "enfria_lava"])
	if h.estado_materia == "solido" and h.pisable: c.append("construye_tierra")   # NO sobre agua: Lanzador3D.construir_tierra
	if h.elemento == "tierra": c.append("golpe_tierra")
	if h.solidez > 0.0: c.append("bloquea_proyectiles")         # la barrera
	if h.resuena > 0.0: c.append("pulso_jugador")               # ᚱ
	if h.empuje > 0.0 or h.elemento == "viento": c.append("empuja")
	if h.elemento == "rayo": c.append("electrifica")
	if h.dano > 1.0 or h.dano_periodico > 0.0: c.append("dana")
	c.append("golpe")                                           # cualquier hechizo rompe un jarrón o pulsa un botón de magia
	return c
```

- **Cuidado con la tierra.** `construye_tierra` **no** cruza agua (`Terreno3D.cabe(…, sobre_agua=false)`). Sirve para subir **un**
  nivel (`Caminos3D.SALTO_MAX = 1`) y dura 25 s.
- **Cuidado con el agua.** El agua **no** hiela (perdió `frio`): hielo es solo el sello `hielo`.
- **Volumen:** kit `pruebas` = 6 sellos × C(8+6, 6) = 3003 multiconjuntos = 18 018 `construir`. Se cachea por repertorio.
  `prueba_hechizo.gd` ya construye cientos sin problema.
- **Glifos nuevos:** cuando Pablo añade un glifo o cambia un tope en `Sigils.GLIFOS`, las capacidades cambian solas. Si eso rompe una
  solución, la prueba lo dice.

### 3.6 Regiones a pie

`regiones(modelo, abiertas)` hace un flood fill de 4 vecinas con **la regla de la jugadora**:
`Terreno3D.pisable(c, nivel, sube=true, max_nivel=99, nada=false)`. Se monta con `Terreno3D.cargar_datos(filas, bloqueadas)` como hace
`prueba_caminos.gd`, sin maqueta. La altura va por arista (|Δ| ≤ 1) con `Caminos3D.arista_ok`.

> **Medido (§9.1 f):** en (16,10), con 0,29–0,46 u de agua, `Terreno3D.pisable` = **true** (mira la letra `c`) y `es_agua` = **true**.
> `Caminos3D.transitable` diría **no**. La jugadora pasó. Así que la capa 1 debe usar `pisable` (la regla del jugador), no
> `transitable` (la de la IA).

El resultado se cachea por el conjunto de puertas abiertas (bitset): una región = id + casillas + qué puertas toca.

### 3.7 Estado, aristas y búsqueda

```gdscript
## buscador.gd
class Estado:
	var nivel: String
	var casilla: Vector2i            # representante (la región se deriva)
	var abiertas: int                # bitset de puertas consumidas/abiertas (≤ 64 por nivel; si no, PackedByteArray)
	var flags: PackedStringArray     # ordenadas (las del juego, mismo nombre que Flags)
	var glifos: PackedStringArray    # repertorio vivo (un cofre `glifo=` lo amplía)
	var cerrojos: int                # bitset de cerrojos cerrados
	var temporales: Dictionary       # puerta -> s que le quedan (hielo, lava enfriada, tierra) — solo si el modelo de ventanas está activo
	func clave() -> String: ...      # nivel|región|abiertas|hash(flags)|hash(glifos)|cerrojos

func expandir(e: Estado) -> Array:   # [[accion: Dictionary, siguiente: Estado], …]
	var res: Array = []
	var reg: Region = regiones(e.nivel, e.abiertas).de(e.casilla)
	var caps: Dictionary = Capacidades.de(e.glifos)
	for p in puertas_cerca(reg, caps):              # adyacentes o a tiro (línea libre con celda_solida, distancia ≤ alcance)
		if Reacciones.cumple(p, caps, e.flags, distancia(reg, p)):
			res.append([{"tipo": "abrir", "puerta": p.id, "con": caps[p.requisito].receta, "desde": mejor_casilla(reg, p)}, aplicar(e, p)])
	for v in vigias_en(reg):                         # §3.8
		if caps.has("dana") and not e.flags.has(v.flag):
			res.append([{"tipo": "derrotar", "vigia": v.id}, poner_flag(e, v.flag)])
	for c in cofres_vecinos(reg):                    # vecina ORTOGONAL (E a 2,7 u)
		if evalua(c.aparece_si, e) and evalua(c.abre_si, e) and not e.flags.has(c.abierto):
			res.append([{"tipo": "usar", "cofre": c.id}, abrir_cofre(e, c)])   # + glifo → e.glifos
	for s in salidas_en(reg):
		res.append([{"tipo": "viajar", "a": s.destino}, entrar(s.destino, s.entrada, e)])
	for r in reglas_disparables(reg, caps, e):       # pulsadores, contadores, reglas `; prueba regla`
		res.append([{"tipo": "regla", "nombre": r.nombre}, motor_reglas(e, r)])
	return res
```

**Búsqueda en dos fases.** La primera es rápida y se queda en la mayoría de los niveles; la segunda es completa.

1. **Cierre monótono.** Si ninguna acción alcanzable «quita» nada (sin `gasta=si`, sin `flag.quitar`, sin `cerrar`, sin `perdibles`, sin
   temporales), el orden no importa. Se aplican acciones hasta el punto fijo. Es lineal en el número de puertas.
2. **BFS de estados** si hay acciones **no monótonas**. Clave de visitados = `Estado.clave()`, tope `MAX_ESTADOS = 200 000`
   (parametrizable). Al llegar al tope: **FALLO** «espacio de estados sin cerrar», nunca OK por omisión.

```gdscript
func buscar(inicio: Estado, meta: Array) -> Dictionary:     # meta = expresión si= ya leída
	var padre: Dictionary = {inicio.clave(): null}
	var cola: Array = [inicio]
	var alcanzables: Array = []
	while not cola.is_empty():
		var e: Estado = cola.pop_front()
		alcanzables.append(e)
		for par in expandir(e):
			var s: Estado = par[1]
			if not padre.has(s.clave()):
				padre[s.clave()] = [e, par[0]]
				cola.append(s)
	var metas: Array = alcanzables.filter(func(x): return evalua(meta, x))
	return {"alcanzables": alcanzables, "padre": padre, "metas": metas, "plan": reconstruir(padre, metas)}
```

### 3.8 Enemigos y vida

- **Vigía `de=`:** «derrotar» es una acción siempre posible si (a) sus casillas de partida están en una región alcanzable o a tiro, y
  (b) el repertorio tiene `dana`. Si no hay `dana`, es FALLO (meta inalcanzable) o aviso (opcional).
- **Cerrojo + vigía:** al entrar en `sala` el cerrojo se cierra. Si dentro no se puede `derrotar`, el estado «dentro y cerrado» es un
  **soft lock**: invariante (3).
- **Enemigos sueltos** (lobernos, asesino, W/A fuera de toda sala): no son puertas. Se ignoran a propósito.
- **Arqueros de puesto (`Combate3D.fijo`):** la capa 1 **no** estima daño. Eso no sería honesto sin física. La obligatoriedad de la
  barrera se mira como «¿existe camino sin `bloquea_proyectiles`?» (`; prueba paso … exige=glifo:barrera`). Si el reto solo es caro y no
  imposible, la capa 1 dice FALLO (4b). La capa 2 mide el daño real.
- **Vida:** no se modela en la capa 1 (no hay pociones obligatorias). La capa 2 corre con vida real; ver §4.4.

### 3.9 Tiempos y caducidades: «ventanas» con parámetro

Lo temporal (hielo 20 s, lava enfriada `vuelve`, tierra 25 s, barrera ≈ 7,9 s) se modela como **ventana**. Un cruce por casillas
temporales vale si:

```
casillas_temporales_en_ruta × andar_s_casilla + n_lanzamientos × t_lanzar ≤ ventana − margen
```

- `andar_s_casilla` = 2,3 u / 1,6 u/s = **1,44 s** (`Jugador3D._vel_andar = 1.6`, `jugador/jugador_3d.gd:83`).
- `margen` = 1 s por defecto.
- `hielo_max` = el ancho máximo de agua que se intenta helar casilla a casilla (defecto 3).

Todo se sobrescribe por nivel con `; prueba ventana …`. Las caducidades **crean estados**: «al otro lado con la ventana cerrada». Si
desde ahí no se puede volver a abrir (porque el repertorio ya no lo permite), eso es un **soft lock**: invariante (3).

Lo que se **ignora a propósito**: recargas de página, coste de tinta salvo el tope (§3.5), timing de relés (optimista + AVISO),
animaciones.

### 3.10 Varios niveles

`salida a=<Nivel>:<entrada>` es una arista hacia el modelo de otro nivel (resuelto con `Niveles.ESCENAS`). Ese nivel se carga **desde
cero** y sus piezas leen las flags al montar, igual que en el juego: `hasta=`, `abierto=`, vigía con flag, `cuando=flag.` que salta
una vez al montar. Las flags y los glifos viajan; las puertas abiertas no (salvo por su flag).

Esto detecta un tipo de bug concreto: **algo resuelto que no está en flags se pierde al volver**. Lo que vive en variables del script
y no tiene flag aparece como «al volver la puerta está cerrada».

### 3.11 Invariantes

Cada fallo imprime una línea `FALLO` con nivel, casilla y número de línea del mapa.

| # | invariante | cómo se comprueba |
|---|---|---|
| 1 | La meta es alcanzable | `metas` no vacío. Se imprime el plan más corto (acciones) |
| 2 | Todo cofre, recolectable, zona con `titulo`, salida y vigía es alcanzable, o está declarado en `opcionales`/`secretos` con razón | para cada uno: existe un estado alcanzable donde se usa. Un recolectable con `coge_si` exige la capacidad de su condición (alga → `hiela_agua`) |
| 3 | Sin soft locks | para **cada** estado alcanzable, la meta sigue siendo alcanzable desde él (BFS inverso sobre el grafo ya construido). Excepción: pérdidas declaradas en `perdibles=` (la sala 7 de PlaytestEoW quema la hierba a propósito) |
| 4a | Cada puzle tiene solución con el repertorio **del momento** | cada regla o puerta del plan se dispara con las capacidades que tiene el estado en ese punto, no con las del final |
| 4b | Obligatoriedad (`exige`, `paso`) | se repite la búsqueda con el glifo quitado: **no** debe haber camino de `de` a `a`. Además: un cofre `glifo=g` cuyo `g` ya está en el repertorio inicial es FALLO («el cofre no enseña nada») |
| 4c | Puzle que se resuelve solo | una señal que llega sin ninguna acción del jugador (el emisor con su pulso, el manantial con `inicia=si`) y abre un cofre o una puerta del plan es AVISO («se resuelve solo»). Pasa a FALLO si está en `exige` |
| 5 | Referencias | letras desconocidas, `avisos` de `Puzle3D.parsear`, `; nombre`/`; marcador` en casillas fuera del mapa, `; prueba` con ids inexistentes, salida a un nivel sin fila en `Niveles.ESCENAS` o con una entrada que no existe en el destino |
| 6 | Coherencia de flags | flag **leída** (`cuando=flag.`, `si=flag.`, `aparece_si`, `abre_si`, `hasta`, `llave`, script de reglas, misiones) que nadie **escribe** en el conjunto de niveles enlazados: FALLO. Flag **escrita** que nadie lee: AVISO. `abierto=`, el `flag=` del vigía y el de `pared_hueca` cuentan como **leídos por su propia pieza** al montar. Nombre que no casa con `nivel.sala.hecho` o con el prefijo del nivel: FALLO |

### 3.12 Salida

```
OK    R1 Bosque_01_v01: la meta flag.bosque01v1.santuario.cofre es alcanzable (repertorio kit:pruebas) en 23 acciones
FALLO R4b Bosque_01_v01: paso «pasarela» (8,6)->(8,11) exige glifo:barrera pero hay camino sin él (línea 7)
AVISO R4c Cueva: el receptor ante_cofre (14,13) se activa sin acción de la jugadora (fuente → agua → veta_c5 → prisma_c6)
FALLOS: n
```

- `user://autotest/<nivel>/grafo.dot`: regiones como nodos y puertas como aristas etiquetadas con su requisito. Se ve con
  `dot -Tpng` o con cualquier visor web.
- `user://autotest/<nivel>/estados.txt`: resumen de cuántos estados, cuántos soft locks y cuáles.
- `user://autotest/<nivel>/plan.json`: el plan para la capa 2 (§4.2).

`user://` está fuera del repo, en línea con la regla de `escenario_base`: «nada se escribe en el repo».

### 3.13 Generador de la tabla de reacciones («sistemas que generen combinaciones solos»)

`prueba_reacciones_piezas.gd` (paso 3) monta un mini-nivel por cada letra reactiva y cada tipo de pieza del catálogo de `Puzle3D.CLAVES`.
Puede ser un mapa de prueba propio, `mapas/AutotestReacciones.txt`, generado en `user://` y registrado con `Niveles.registrar`. Así no
se ensucia ningún nivel real.

Le lanza **cada sello** (`lanzar_a_celda` real) y anota qué cambió: la casilla se liberó, se consumió, se puso una flag, se emitió una
señal. Luego compara con `reacciones.gd`. Una diferencia es FALLO: la tabla miente o el objeto cambió. Es el mismo patrón que
`prueba_hechizo` comprobando que `GLIFOS` y `GLIFOS_V2` dicen lo mismo.

---

## 4. Capa 2: recorrido dinámico (jugador autómata)

### 4.1 Archivos

| archivo | qué es |
|---|---|
| `herramientas/escenario_recorrido_niveles.gd` | `extends "res://herramientas/escenario_base.gd"`. Por cada nivel con `; prueba`, carga su escena (`Niveles.ESCENAS`) y ejecuta su plan. Por el prefijo `escenario_` corre a 30 fps fijos en la batería |
| `herramientas/resolubilidad/automata.gd` | `RefCounted` con referencia al escenario: `ir_a`, `lanzar_a`, `usar`, `esperar_hasta`, `derrotar`, `viajar`. Lo comparten el recorrido y el fuzz |
| `herramientas/fuzz_niveles.gd` | `extends escenario_base`. **Fuera de la batería por defecto**: no empieza por `prueba_` ni por `escenario_` |
| `tools/fuzz.cmd` | `fuzz.cmd <nivel> [lanzamientos] [semilla]`, con el mismo formato y `resumen_prueba.ps1 -Una` |
| `herramientas/autotest/planes/<nivel>.json` | planes escritos a mano (opcional; `; prueba plan`) |

### 4.2 Formato de plan

Serializable, generado por la capa 1 o escrito a mano.

```json
{ "nivel": "Bosque_01_v01", "repertorio": "kit:pruebas", "semilla": 1,
  "pasos": [
    {"tipo": "ir",      "a": [2, 11],                                  "max_s": 30},
    {"tipo": "lanzar",  "sello": "fuego", "glifos": ["flecha"], "a": [2, 12], "max_s": 20,
                        "espera": "casilla_libre(2,12)"},
    {"tipo": "ir",      "a": [5, 5]},
    {"tipo": "lanzar",  "sello": "fuego", "glifos": ["flecha"], "a": [7, 5], "espera": "flag.bosque01v1.tronco_puente.caido"},
    {"tipo": "derrotar","vigia": "guardia_linde", "max_s": 90},
    {"tipo": "usar",    "pieza": "cofre_01",  "espera": "flag.bosque01v1.linde.cofre"},
    {"tipo": "viajar",  "salida": "boca_salida", "espera": "nivel(Cueva)"},
    {"tipo": "afirmar", "si": "flag.bosque01v1.santuario.cofre"}
  ] }
```

`espera` usa la gramática de `si=` y añade `casilla_libre(x,y)`, `nivel(N)` y `en(x,y)`.

### 4.3 Qué hace cada paso, sin trampas

- **`ir`:** ruta con `Caminos3D.camino` (o el BFS con la regla de `pisable`, §3.6). Después llama a `mover_hacia` **casilla a casilla**,
  como `escenario_bosque_01_ramas._caminar`: las teclas WASD reales, sin teletransporte. Si se atasca, recalcula una vez desde donde está;
  si vuelve a atascarse, FALLO.
- **`lanzar`:** compone la página con el libro real: `select_page`, `place_element`, `place_sigil`, como `escenario_base.lanzar`. Apunta
  desde la **casilla actual** hacia el centro de la casilla objetivo y llama a `lanzar_pagina_ya`. No se teletransporta (el
  `lanzar_a_celda` de hoy sí lo hace). Si la casilla actual no tiene línea libre o está fuera de alcance, antes hace un `ir` a la mejor
  casilla de tiro que dio la capa 1.
  - **Recarga:** se espera la real, no se pone `cooldown_left[0] = 0`.
  - **Tinta:** se usa la real (no `lanzador.tinta = null`). Si falta, espera a que se recupere y cuenta ese tiempo.
  - **Gravedad:** `escenario_base.lanzar` lanza sin gravedad. El plan debe usar la **real**, porque probar el nivel es probar lo que hará
    la jugadora. Hace falta un flag `gravedad_real := true` en el armazón, y es el único cambio que necesita `escenario_base`.
- **`usar`:** pulsa E de verdad (`_pulsar_e` de `escenario_bosque_01_v01.gd:340` se sube al armazón) y espera la flag.
- **`derrotar`:** combate real con la página de más `dana` que tenga el repertorio. Apunta al enemigo vivo más cercano del vigía y
  repite hasta que el vigía se cumple o pasa `max_s`. Hay un modo `combate=simulado` (`muerto = true`) para aislar un puzle, pero **cada
  vez que se usa sale un AVISO** y el paso no cuenta como «resuelto a pie».
- **`viajar`:** pisa la salida y espera `Niveles.en_curso` con el tope de `_esperar_viaje`. Al llegar, refresca los nodos (`_refrescar`).
- **`afirmar`:** `_ok(nombre, evalua(si))`.

### 4.4 Tolerancias honestas

- **Sin teletransportes** en el modo «recorrido». Solo se permiten en un modo `aislar=<id>` explícito, y salen como AVISO.
- **Tiempo máximo por paso:**
  - `ir` = 3 × longitud de la ruta × `andar_s_casilla` + 5 s;
  - `lanzar` = vuelo + `espera` con un tope de 20 s;
  - `derrotar` = 90 s.
  - Todo se sobrescribe por paso (`max_s`). **Nunca se aflojan los márgenes** para que pase: si hace falta más, se cambia el plan o el
    juego.
- **Vida real.** Si la jugadora muere, es FALLO con el paso y la causa (el PlayLog lo dice). Un modo `vida=infinita` existe solo para
  depurar y sale con AVISO.
- **Duración esperada**, calculada con las rutas medidas en §9 y `VEL_ANDAR` 1,6 u/s (1,44 s por casilla), solo andando:
  - plan principal del Bosque 01 v01: ≈ 188 casillas ≈ **4,5 min**, más combates y esperas;
  - Cueva: 73 casillas ≈ **1,8 min**.
  - Cabe en el `TimeoutS = 1800` de `resumen_prueba.ps1`.

### 4.5 Qué pasa si falla

1. `FALLO <nivel> paso <i> <tipo> …` con la casilla de la jugadora, la vida, la tinta y lo que esperaba.
2. **Volcado del PlayLog:** los últimos 60 eventos de `eventos("")` del armazón (el `.jsonl` de esta ejecución), copiados a
   `user://autotest/<nivel>/fallo_<paso>.jsonl`.
3. **Mapa ASCII del estado:** letras, `@` jugadora, puertas abiertas en minúscula, enemigos vivos, y el agua por profundidad
   (`profundidades`). Va a `user://autotest/<nivel>/fallo_<paso>.txt`.
4. **PNG en `docs/capturas/autotest/<nivel>_<paso>.png`: solo con ventana.** En `--headless` el rasterizador es «dummy» y
   `get_viewport().get_texture()` no da imagen. Por eso las `captura_*.gd` dicen «NECESITA VENTANA». La batería no saca PNG; el mismo
   escenario lanzado a mano sin `--headless` sí. Es la única excepción a «no escribir en el repo», y solo a petición.

### 4.6 Qué da ya `escenario_base.gd` y qué falta

- **Ya lo da:**
  - `cargar(ruta, usar_escena)`, que espera al Lanzador, al jugador, al agua y al velo;
  - `avanzar`, `avanzar_s` y `avanzar_vigilando`, con el reloj por deltas;
  - `colocar_jugador`, que solo se usará en el modo aislar;
  - `celda_jugador`, `mover_hacia` (teclas reales, mide hacia dónde empuja W/D), `_tecla`;
  - `lanzar`, `lanzar_a_celda`, `profundidades`, `volcar` y `eventos(tipo)`;
  - `_ok`, `_aviso` y el `FALLOS: n` final.
- **Falta**, todo en `automata.gd` salvo el flag de gravedad:
  - `ir_a(c)`, con ruta + `mover_hacia` por tramos;
  - `lanzar_desde_aqui(sello, glifos, objetivo)`;
  - `pulsar_e()`, que se sube de `escenario_bosque_01_v01`;
  - `esperar_hasta(cond, tope)`, que ya existe como `_espera` en `escenario_bosque_01_ramas`;
  - `derrotar(vigia)`;
  - `refrescar_nivel()` tras viajar;
  - `volcar_fallo(paso)`.

### 4.7 Modo fuzz

`fuzz_niveles.gd <nivel> lanzamientos=N semilla=S`. Por cada sala de `; prueba fuzz salas=…` (por defecto, las zonas del mapa):

1. Coloca a la jugadora en una casilla al azar de la región (aquí el teletransporte es legítimo: el fuzz no prueba recorridos).
2. Durante N lanzamientos elige al azar **una página del repertorio**: sello + multiconjunto de glifos, la misma enumeración de
   `capacidades.gd`. Elige también un objetivo al azar a tiro y la lanza con recarga y tinta reales. Espera entre 0,5 y 3 s al azar.
3. Después de cada lanzamiento, comprueba:
   - **jugadora dentro del mapa**: `Terreno3D.en_mapa` y `y_pies` coherente, sin caer por debajo del suelo más de 1 u;
   - **sin SCRIPT ERROR nuevo**;
   - **sin flags puestas «sin querer»**: toda flag nueva tiene que ser una que la capa 1 considera ponible desde ese estado con esas
     capacidades;
   - **no se rompe la resolubilidad**: cada 25 lanzamientos se copia el estado real (flags, puertas, cerrojos, tierra) al modelo de la capa
     1 y se pregunta «¿la meta sigue alcanzable desde aquí?». Si no, es FALLO con la semilla, y basta para reproducirlo.
   - **piezas sanas**: ningún nodo de `Puzle3D` liberado mientras su pieza sigue en `por_id`, y ningún `Combate3D` con posición NaN.
4. Al final: `FALLOS: n` y un resumen de qué combinaciones se probaron (cobertura por sello y glifo).

La semilla se imprime siempre. Con 200 lanzamientos por sala y unos 2 s por lanzamiento, una sala tarda ≈ 7 min de reloj. Por eso el
fuzz va fuera de la batería por defecto.

---

## 5. Integración en `tools\pruebas.cmd`

**No hace falta tocar `pruebas.cmd` ni `resumen_prueba.ps1`.**

- `herramientas/prueba_resolubilidad.gd` entra solo por el filtro `prueba_*.gd`, sin `--fixed-fps` (no usa escena salvo con
  `--fuente=escena`). Escribe `FALLOS: n`, que reconoce la primera de las seis formas de `resumen_prueba.ps1`.
- `herramientas/escenario_recorrido_niveles.gd` entra por `escenario_*.gd`, con `--fixed-fps 30` automático.
- Los ficheros de `herramientas/resolubilidad/` y `herramientas/autotest/` **no** se lanzan como prueba: `Get-ChildItem` no es recursivo.
- **Subconjuntos:** `tools\pruebas.cmd solo resolubilidad` (segundos) y `tools\pruebas.cmd solo recorrido` (minutos).
  `tools\prueba_una.cmd prueba_resolubilidad` para una sola.
- **Un nivel suelto:** `godot --headless --path . --script res://herramientas/prueba_resolubilidad.gd -- nivel=Cueva`
  (`OS.get_cmdline_user_args`).
- **Fuzz:** `tools\fuzz.cmd Bosque_01_v01 200 7`, fuera de la batería.

---

## 6. Añadir un nivel nuevo (pantano, montaña, desierto) sin escribir código

1. El mapa `mapas/Pantano_01.txt` lleva sus piezas (`; pieza`/`; puzle`) como siempre.
2. Se añaden sus líneas de prueba, por ejemplo:
   ```
   ; prueba meta=flag.pantano01.santuario.cofre opcionales=cofre_juncos secretos=cofre_niebla
   ; prueba barrido repertorio=progresion:pantano;kit:pruebas
   ; prueba exige puerta_hielo glifo=hielo razon=el_pantano_ensena_el_hielo
   ```
3. Se da de alta la escena en `Niveles.ESCENAS` (ya hace falta para viajar).
4. `tools\pruebas.cmd solo resolubilidad`. La lista de niveles sale sola (§3.1) y el plan de la capa 2 sale de la capa 1.

Solo hace falta código si el nivel trae **una pieza nueva** (un tipo nuevo en `Puzle3D`). En ese caso se añade **una fila** a
`reacciones.gd`, y `prueba_reacciones_piezas.gd` comprueba que dice la verdad. Las reglas que el nivel guarde en su script, que es lo
que hay que evitar, se declaran con `; prueba regla` / `; prueba abre` hasta pasarlas a `Puzle3D`.

---

## 7. Orden de implementación

| paso | qué | coste | se reaprovecha |
|---|---|---|---|
| **1** | `modelo_nivel.gd` + regiones + invariantes **5** (referencias) y **6** (flags) + `.dot` de regiones + la línea `"prueba"` de `leer_extras` + `prueba_resolubilidad.gd` que imprime regiones y puertas y falla por (5) y (6). Sin estados ni capacidades | **S** (≈ el prototipo de este informe, `proto_regiones.gd`, ya hecho al 70 %) | `Puzle3D.parsear`, `leer_mapa`/`leer_extras`, `Terreno3D.cargar_datos` + `pisable` (patrón de `prueba_caminos._montar`), el BFS de `escenario_bosque_01_ramas._alcanzables` (sin la lista a mano) |
| **2** | `capacidades.gd` (con `Hechizo.construir`) + `reacciones.gd` (semilla) + `buscador.gd` (cierre monótono + BFS de estados, ventanas) + invariantes **1–4** + `plan.json` + `; prueba` completo (meta, barrido, exige, paso, regla, abre). Escribir las líneas `; prueba` de Bosque_01_v01, Cueva y PlaytestEoW (§9) | **M** | `Hechizo.construir`, `Lanzador3D.PROGRESIONES`, el motor de condiciones `_leer_si`/evaluación de `Puzle3D`, `Niveles.ESCENAS` |
| **3** | `automata.gd` + `escenario_recorrido_niveles.gd` (ejecuta el plan sin teletransportes, con volcado de fallos) + `fuzz_niveles.gd` + `tools/fuzz.cmd` + `prueba_reacciones_piezas.gd` (verifica la tabla con hechizos reales en un mapa de prueba propio) | **L** | `escenario_base` (todo lo de §4.6), `escenario_bosque_01_ramas._ruta/_caminar`, `escenario_bosque_01_v01._pulsar_e/_esperar_viaje/_refrescar`, `escenario_puzles_fuego` (lanzar a casillas reales) |

Cada paso deja la batería en verde por sí solo, y lo que se encuentre se apunta en `PENDIENTES`.

---

## 8. Límites honestos (lo que NO detectará)

- **Diseño aburrido o puzles triviales.** No sabe si algo es divertido. Solo marca «se resuelve solo» (4c) y «se resuelve sin el glifo
  que enseña» (4b). Un puzle de un paso obvio pasa.
- **Física y tiempo finos.** La capa 1 es optimista con el agua, los relés, los contagios de fuego y el viento. La capa 2 solo ejercita
  **su** plan: si hay otra ruta que se rompe por timing, solo la encuentra el fuzz, y por azar.
- **Combate.** «Derrotar» es «hay daño». No mide si un vigía es injusto. La capa 2 mide que se gana con el plan, no que sea razonable.
- **Colisión real y huellas.** Con la fuente «letras» la capa 1 no ve rocas desbordadas. `--fuente=escena` sí, a cambio de unos
  segundos por nivel.
- **Reglas en código.** Lo que un script de nivel decide sin declararlo (tótems y puerta X del Bosque v01) es invisible hasta que se
  escriba como `; prueba regla`/`abre` o se pase a `Puzle3D`. Un `; prueba regla` mal escrito engaña a la prueba: la capa 2 lo
  destapa al ejecutarlo.
- **Lo que viaja a mano.** La vida entre niveles (`Niveles.vida_pendiente`) y la mochila no entran en la capa 1.
- **Cámara, oclusión y legibilidad.** Que la jugadora **vea** la telaraña o la veta no lo mide nadie. Eso son las capturas con ventana.

---

## 9. La capa 1 aplicada a mano y con el prototipo (medido)

Prototipo: `C:\Users\pablo\AppData\Local\Temp\claude\C--Users-pablo-Documents-magic-symbols--claude-worktrees-proyecto-analisis-profundo-bf47f8\bbc0c028-6f87-4f66-b0a3-93d912d2e3fc\scratchpad\proto_regiones_wt.gd`.
Salida: `…\scratchpad\proto_out2.txt`.

**Coordenadas:** las casillas son (x = columna, y = fila del mapa). En `Bosque_01_v01.txt` la fila y está en la línea `14 + y` del
archivo; en `Cueva.txt`, en la línea `1 + y`.

### 9.1 Bosque_01_v01 (52 × 44, 58 piezas, 15 reglas, 0 avisos de parseo)

**Regiones a pie con todas las puertas cerradas** (15):

| región | casillas | qué contiene |
|---|---|---|
| **R6** | 23 | **inicio S (2,21)**; franja oeste, filas 13–21 |
| R0 | 27 | linde norte: guerrero_01 (2,5), `guardia_linde` |
| **R1** | 720 | la tala (`cofre_01` en (10,4)), la pasarela (8,6..11), el prado (antorchas, braseros, TF_3), la hierba alta, la hondonada (`boca_salida` (46,18)), la explanada, las entradas de las cámaras, las paredes que suenan |
| R2 | 83 | claro norte: guerrero_03, arquero_01, `cofre_03` |
| R3 | 102 | campamento: `cuello`, `guardia`, `cofre_llave` |
| R4 | 49 | santuario: elemental, `cofre_02` (**meta**) |
| R8 | 6 | nicho de TF_1 (18..19, 22..24): `boton_atajo` |
| R5 | 5 | nicho del eco: `cofre_eco` |
| R9 | 16 | escondite: `cofre_escondite` |
| R11–R14 | 5 cada una | trastiendas de las cámaras A–D con `cofre_04`..`cofre_07` |
| R7 | 1 | (13,20) |
| R10 | 1 | (18,26) |

**Puertas**, cada una con lo que une:

| puerta | casilla | une | requisito |
|---|---|---|---|
| telaraña `r` | (2,12) | R6↔R0 | fuego |
| agua `~` | x = 6 | R0↔R1 | hielo, o el tronco_puente (7,5) con fuego (cae en (6,5)) |
| telaraña `r` | (30,8) | R1↔R2 | fuego |
| puerta goblin `y` | (33,5) | R2↔R3 | fuego |
| `X` | (21,15) | R1↔R4 | tres tótems |
| `puerta_tf1` | (18,21) | R1↔R8 | llave |
| `atajo_tf1` | (20,24) | R8↔R1 | regla del botón de dentro |
| `eco_h1` | (41,14) | R1↔R5 | ᚱ |
| `eco_h2` | (14,28) | R1↔R9 | ᚱ |
| `a/b/c/d_puerta` | – | R1↔R11..14 | puzles de fuego |
| torres `o` | (8,14), (44,3) | – | arden, pero no separan regiones |

**Camino a la meta**, con el repertorio de la escena (`kit:pruebas`):

1. S (R6) → **fuego** a (2,12) → R0.
2. `guardia_linde`: **derrotar** al guerrero (2,5) → `bosque01v1.linde.limpia` → aparece `cofre_01`.
3. Cruzar el arroyo: **fuego** al tronco (7,5) desde (5,5), a 2 casillas (alcance de la flecha 2 m), o **hielo** en x = 6 → R1.
4. `usar cofre_01` (10,4) → `linde.cofre` (+ ᛜ, que ya se tenía).
5. Por la pasarela hasta el prado (arqueros de puesto: no son puerta) → **fuego** a (30,8) → R2.
6. **Fuego** a (33,5) → R3 → el cerrojo se cierra → **derrotar** a 4 → `campamento.limpio` → `usar cofre_llave` → `campamento.llave`.
7. Vuelta a R1 → `usar puerta_tf1` (llave) → R8 → **fuego** a la hierba `v` (18..19, 22..24) → TF_1 (regla en código).
8. **Fuego** a los braseros (18,9) y (19,9) → TF_2 (regla en código).
9. **Fuego** a las antorchas en orden (19,13) → (17,16) → (17,11) → (19,17) → TF_3 (regla en código).
10. `X` (21,15) se abre → R4 → **derrotar** al elemental → `usar cofre_02` → **meta** `bosque01v1.santuario.cofre`.

Longitud a pie medida con BFS (`proto_ruta.gd`, puertas abiertas): **181 casillas** + ≈ 7 del tramo (32,5)→(39,5). El punto de ruta
(40,5) era la fogata, error mío.

**Problemas detectados**:

- **(a) La barrera no es obligatoria.** Es **FALLO de 4b** cuando se declare `; prueba paso pasarela de=8,6 a=8,11 exige=glifo:barrera`.
  - **Estático:** la pasarela (8,6..11, filas 20–25 del archivo) es parte de R1. Ninguna puerta pide `bloquea_proyectiles`.
  - **Dinámico (medido hoy):** 0 de daño andando y corriendo (AVISO 4.10 y 4.11).
  - **Además:** `escenas/PruebaBosque01_v01.tscn` tiene `kit = "pruebas"`, que según `magia/lanzador_3d.gd:105–107` incluye `barrera`
    desde el principio. El cofre legendario `cofre_01 … glifo=barrera` (línea 125) **no enseña nada**: `conseguir_sigil` devuelve false.
    Las líneas 6–7 del mapa dicen «La barrera es OBLIGATORIA». Es FALLO de 4b («el cofre no enseña nada»).
- **(b) El arroyo no exige el tronco.** El kit trae `hielo`, así que x = 6 se cruza helando. El objetivo «Cruzar el arroyo por el
  tronco» se marca pisando la tala (`F_TALA_PISADA`), venga por donde venga. Es AVISO, o FALLO si Pablo lo declara con `exige`.
- **(c) Reglas en código invisibles.** TF_1/TF_2/TF_3 y la puerta X viven en `escenas/bosque_01_v01_3d.gd:569–682`. Sin
  `; prueba regla`/`abre`, R4 (la meta) sale **inalcanzable**. Esto es lo que debe fallar hasta que se declaren o se pasen a piezas.
  Hay que escribir:
  ```
  ; prueba regla totem_1 requiere=prende@18,24|prende@19,24|prende@18,23|prende@19,23 pone=bosque01v1.totem.fuego_1
  ; prueba regla totem_2 requiere=prende@18,9+prende@19,9 pone=bosque01v1.totem.fuego_2
  ; prueba regla totem_3 requiere=prende@19,13+prende@17,16+prende@17,11+prende@19,17 pone=bosque01v1.totem.fuego_3
  ; prueba abre 21,15 si=flag.bosque01v1.totem.fuego_1+flag.bosque01v1.totem.fuego_2+flag.bosque01v1.totem.fuego_3
  ```
- **(d) Bolsillos de una casilla.** Son inofensivos, pero la invariante 2 debe darlos como AVISO, no FALLO:
  - R7 = (13,20) (línea 34), encerrada por el puesto `Q` (13,19)+(14,19) y el jarrón `jarrones_prado_3` (12,20); se abre rompiéndolo;
  - R10 = (18,26) (línea 40), hierba `v` bajo TF_1, sin salida.
- **(e) Flags.**
  - **Leídas sin escritor: 0.**
  - **Escritas sin lector en el mapa: 13.** Todas son `abierto=` o `flag=` de su propia pieza, o las lee el script
    (`linde.cofre`, `paso.limpio`, `santuario.cofre`, `hondonada.eco`, `explanada.eco`, `camara_*`). Con la regla de §3.11 (6) quedan en
    **0 reales**.
  - **Entre niveles:** `cueva.c6.glifo` la lee el script del Bosque (`F_GLIFO_CUEVA`) y la escribe la Cueva (`tesoro abierto=`), así que
    cierra.
- **(f) Sospecha de trampa en la losa del estanque, descartada midiendo.** La losa (16,9) (línea 23) es un callejón cuya única salida es
  el cauce (16,10), que se inunda al pisarla (`celdas=16,10..20,10+…`, línea 131). Estáticamente parecía un soft lock (nadar está
  desactivado). Medido con `proto_losa_estanque.gd`, llegando **andando**:
  - el agua llega a (16,10) a los **19,0 s**;
  - a los 30 s hay 0,46 u;
  - la jugadora **sale andando** a (15,11).

  No hay trampa. Lo que sí deja claro (§3.6): `pisable` y `transitable` discrepan en esa casilla.
- **(g) Opcionales.**
  - Claro (R2) y cámaras (R11–14): alcanzables, con fuego.
  - `cofre_eco` (R5) y `cofre_escondite` (R9): exigen ᚱ, que solo da la Cueva. La invariante 2 los da por buenos si la Cueva es
    resoluble (§9.2).

### 9.2 Cueva (27 × 21 en el worktree, 41 piezas, 3 reglas, 0 avisos de parseo)

| región | casillas | qué contiene |
|---|---|---|
| **R3** | 59 | C1 + **inicio S / `desde_bosque` (4,17)** + `a_bosque` (3..5,18) |
| R0 | 65 | C2 + (4,9) |
| R1 | 24 | C3 oeste (x 10–12) |
| R2 | 117 | C3 este + (18,4) + C4 + (22,9..10) + C5 |
| R4 | 59 | C6 con `tesoro` |

**Puertas:**

| puerta | casilla | une | requisito |
|---|---|---|---|
| `paso_norte` | (4,10) | R3↔R0 | regla `abre_norte`: contador `luces` = braseros (2,12) y (7,12) con fuego |
| `grieta` | (9,4) | R0↔R1 | muro, `golpes=2`: 2 golpes de tierra o una explosión (no hay barril) |
| `rio` | (13..14, 1..8) | R1↔R2 | lava: agua o hielo; **vuelve a los 10 s** (ventana: 2 casillas × 1,44 s = 2,9 s + 1 s de margen < 10 s) |
| `puerta_llave` | (18,16) | R2↔R4 | `llave=cueva.c4.llave gasta=no` |
| `salida` | (9,16) | R4↔R3 | pared hueca: ᚱ |
| `entrada_c4` | (18,4) | – | cerrojo: se cierra al entrar en C4 hasta `cueva.c4.limpia` |

**Camino a la meta** (`cueva.c6.glifo` y volver al Bosque):

1. **Fuego** a los dos braseros → se abre `paso_norte` → R0.
2. **Tierra ×2** a la grieta → R1.
3. **Agua** a la lava (13,y) → cruzar en la ventana → R2.
4. Entrar en C4: el cerrojo se cierra → **derrotar** a W (22,3) y W (24,6) → `cueva.c4.limpia` → se abre el cerrojo y aparece
   `cofre_llave` → `usar` → `cueva.c4.llave`.
5. `usar puerta_llave` → R4.
6. `tesoro` ya está desellado (ver c) → `usar` → ᚱ + `cueva.c6.glifo`.
7. **ᚱ** a la pared hueca (9,16) → R3 → `a_bosque`.

Longitud a pie medida: **73 casillas**.

**Problemas detectados**:

- **(a) Sin soft locks con `kit:pruebas`.** Aun sin ᚱ hay vuelta:
  - `puerta_llave` no se gasta (`gasta=no`);
  - el cerrojo de C4 no vuelve a cerrarse;
  - la lava se re-enfría con agua;
  - la grieta queda rota;
  - `paso_norte` no tiene `cerrar`.

  Queda por medir en la capa 2: qué pasa si la lava vuelve con la jugadora encima de la roca (no hay regla escrita en el mapa).
- **(b) Con la progresión real `bosque` (sellos [fuego], glifos [flecha]), la meta es inalcanzable.** La grieta (9,4) pide tierra
  (línea 54) y el río de lava pide agua o hielo (línea 58). El barrido `repertorio=progresion:bosque` lo dará como FALLO R1. Esto es
  razonado sobre `lanzador_3d.gd:102` y la tabla de §3.4, no corrido. Hoy la escena `PruebaCueva.tscn` usa `kit = "pruebas"`, así que
  no se nota.
- **(c) El cofre legendario se desella solo.** Es AVISO de 4c, y FALLO si se declara `exige tesoro …`. `fuente emisor` (24,12) +
  `c5_pulso cuando=fuente.descarga hace=fuente.pulso(24)` (líneas 77–80) lanzan un pulso cada 4 s. Va por la charca, sigue por
  `veta_c5` (19..16,16), **cruza la puerta** (18,16) y llega al prisma (15,16), que mira al norte. De ahí `veta_c6_norte` lo lleva al
  receptor `ante_cofre` (14,13) (líneas 82–92), que pone `cueva.c6.pulso` y desella `tesoro`.

  Nada de eso pide una acción de la jugadora: al llegar a C6, el cofre ya está abierto de sellos. `escenario_cueva_pulso` lo comprueba
  como **comportamiento** (§3 de su cabecera), no como puzle. Si Pablo quiere que sea un puzle, la capa 1 lo vigilará con
  `; prueba exige tesoro sello=hielo` o con lo que decida.
- **(d) Recolectables con condición.**
  - Las algas `alga_c5a` (21,14) y `alga_c5b` (23,15) están **dentro** de la charca (líneas 72–74). Solo se alcanzan helándola, porque
    `coge_si=…helada` y nadar está desactivado. Con el kit hay hielo. Con la progresión `bosque` serían inalcanzables (invariante 2: AVISO
    u opcional).
  - Los basaltos (13,3) y (14,6) exigen enfriar la lava. Mismo razonamiento.
- **(e) Flags:** 0 leídas sin escritor. `cueva.c6.puerta` y `cueva.c6.salida` las lee su propia pieza; `cueva.c6.glifo`, el Bosque.

### 9.3 PlaytestEoW (laboratorio: no tiene meta, cada sala es su propio caso)

- **2 regiones.**
  - R0 = 308 casillas: todas las salas.
  - R1 = 23 casillas: sala 4 al norte del río (25..31, 1..3) + (26,4) + (30,4). Se llega solo helando el río; el muro de (25,4) cierra el
    hueco oeste, como explica su línea 62.
- Los cofres de la sala 5 (1,9), (3,9), (5,9) y (7,9) ocupan cada uno la única casilla de su alcoba. Se abren con E desde la puerta
  (x,10), a 1 casilla (2,3 u ≤ 2,7). La invariante 2 debe usar «vecina ortogonal alcanzable», no «casilla alcanzable», o daría 4 FALSOS
  FALLOS (el prototipo los saca como `SIN_REGION`).
- **Sala 7:** quemar (17,14) hace que `s7_cofre` no aparezca nunca. Es una pérdida **a propósito**: `; prueba perdibles=s7_cofre:quemar_la_hierba_castiga`.
- Bloque propuesto:
  ```
  ; prueba meta=flag.playtest.s6.cofre+flag.playtest.s7.cofre letras_lab=!@Z perdibles=s7_cofre:quemar_la_hierba_castiga opcionales=s5_ca,s5_cb,s5_cc,s5_cd
  ```

---

## 10. Archivos de esta sesión (scratchpad, fuera del repo)

- `…\scratchpad\informe_autotest_niveles.md`: este informe.
- `…\scratchpad\proto_regiones.gd`, `proto_regiones_wt.gd`: prototipo de la capa 1. La versión `_wt` lee los mapas del worktree.
- `…\scratchpad\proto_ruta.gd`: longitudes de ruta.
- `…\scratchpad\proto_losa_estanque.gd`: medida dinámica de la losa.
- `…\scratchpad\salida_bosque_v01.txt`, `error_bosque_v01.txt`, `tiempo_bosque_v01.txt`, `proto_out2.txt`, `losa_out.txt`, `ruta_out.txt`:
  salidas.

(`…` = `C:\Users\pablo\AppData\Local\Temp\claude\C--Users-pablo-Documents-magic-symbols--claude-worktrees-proyecto-analisis-profundo-bf47f8\bbc0c028-6f87-4f66-b0a3-93d912d2e3fc`.)
