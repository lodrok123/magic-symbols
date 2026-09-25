# Magic Symbols — Notas de arquitectura

Prototipo de aprendizaje en Godot 4. Idea central: dibujar símbolos con el
ratón para lanzar hechizos, combinando un elemento (fuego, agua, viento,
tierra) con un patrón de conjuro (flecha, pilar, barrera). Inspiración:
Magicka (combinar elementos), Witch Hat Atelier (el trazo del símbolo
importa), Breath of the Wild (reacciones físicas entre elementos).

---

## Cómo se juega ahora mismo

**Movimiento**: `WASD` en las cuatro direcciones. `Shift` salta (impulso
corto que ignora colisiones: sirve para cruzar huecos, esquivar bloques o
saltar por encima del fuego). `R` reinicia el nivel en cualquier momento,
incluso con el juego pausado por victoria o muerte.

**Lanzar hechizos** — con el grimorio:
1. `T` abre el libro. **El tiempo se detiene** mientras esté abierto.
2. Dibujas dentro del círculo. Un **trazo cerrado** (triángulo, círculo,
   cuadrado, estrella) elige el **elemento**. Un **trazo recto** añade un
   **componente** con su propia dirección.
3. Puedes dibujar **varios trazos rectos**, y de tipos distintos: cuatro
   pilares de tierra en cuatro sectores son cuatro sitios a los que
   subirse; una flecha y dos barreras, un ataque con cobertura.
4. `T` cierra el libro **y lanza** todos los componentes a la vez.

### Sectores y patrones

La corona entre el núcleo y el borde está repartida en **8 sectores**
(los cuatro ejes y las cuatro diagonales). El sector de un trazo se
calcula desde el **centro del trazo** (la media de sus puntos), no desde
donde empieza: el centro es lo único que no cambia si lo dibujas de ida o
de vuelta. Un trazo hecho sobre el núcleo no cae en ningún sector — no
hay dirección que deducir.

**El sector da la dirección; el sentido del trazo da el patrón.** No hizo
falta inventar símbolos nuevos ni tocar el reconocedor: la información ya
estaba en el trazo, solo había que leerla comparándolo con su sector.

| Trazo, respecto al centro | Patrón  | Dónde aparece            |
|---------------------------|---------|--------------------------|
| hacia **fuera**           | Flecha  | sale volando             |
| hacia **dentro**          | Pilar   | a 2 casillas, lejos      |
| de **lado**               | Barrera | a 1 casilla, pegado a ti |

Pilar y barrera son la misma mecánica y solo se diferencian en la
distancia — pero esa distancia **es** la diferencia de intención: el
pilar es un sitio al que llegar, la barrera un escudo. Se mide con el
producto escalar entre el trazo y su sector: vale 1 hacia fuera, −1 hacia
dentro y 0 de lado.

Con la runa de tierra esto da las tres cosas de golpe: flecha = proyectil
de piedra, pilar = lugar escalable en esa dirección, barrera = piedra
pegada a ti (cuatro barreras = encerrarse). Y funciona **sin ninguna
regla nueva**: la tierra ya construía solo cuando el hechizo llegaba
quieto, y flecha es el único patrón que llega con dirección.

Antes se dibujaba encima del juego con los enemigos moviéndose, y se
lanzaba con `Espacio`. El libro resuelve las dos cosas: el dibujo tiene
su sitio y el tiempo parado quita la presión de dibujar con prisa.

### Vocabulario de runas

**Elementos** — se dibujan **en el núcleo**:

| Forma       | Elemento | Etiquetas          |
|-------------|----------|--------------------|
| círculo     | Agua     | `agua`, `frio`     |
| triángulo   | Fuego    | `fuego`, `calor`   |
| cuadrado    | Viento   | `viento`           |
| semicírculo | Tierra   | `tierra`           |

> **El significado lo da DÓNDE dibujas, no qué forma tiene.** Núcleo =
> elemento; sector = componente. Antes lo decidía la forma (cerrada =
> elemento, recta = patrón), y eso dejaba fuera cualquier gesto abierto:
> un semicírculo no se cierra, así que nunca habría podido ser un
> elemento. Mirar la posición libera el vocabulario de gestos por
> completo y elimina de paso una heurística frágil. La estrella se
> descartó por otro motivo, puramente práctico: con ratón se falla.

**Patrones** (trazo abierto, se distinguen por su dirección):

| Trazo      | Patrón   | Qué hace                                        |
|------------|----------|-------------------------------------------------|
| izq / der  | Flecha   | Proyectil que sale del jugador en esa dirección |
| arriba     | Pilar    | El elemento aparece quieto delante del jugador  |
| abajo      | Barrera  | 4 copias del elemento rodean al jugador         |

Existe un quinto "elemento" que el jugador **no puede dibujar**: el
**vapor** (`steam_rune.tres`). Solo lo genera el mundo, al evaporarse el
agua. Es el primer caso de un elemento que existe únicamente como
consecuencia de una reacción.

---

## Las piezas del sistema, de abajo a arriba

### `runes.gd` — el vocabulario de formas

Un único `enum Runes.Type`. Vive en su propio script (no dentro de
`Spellcaster`) para que cualquier otro script pueda usarlo sin depender
del nodo del jugador.

> ⚠️ **Cuidado al reordenar un enum**: los valores se guardan en las
> escenas como números. Cuando `GrassBlock.State` pasó de 3 a 5 estados,
> el `initial_state = 2` del `GrassWall` dejó de significar `GROWN` y pasó
> a significar `IGNITING`. Si reordenas un enum, revisa las escenas que lo
> exportan.

### `spellcaster.gd` — captura y reconocimiento de gestos

- Captura los puntos del ratón mientras se dibuja (`stroke_points`).
- Distingue **trazo abierto** (dirección: ángulo entre primer y último
  punto) de **trazo cerrado** (el final vuelve cerca del principio).
- En los cerrados, cuenta **esquinas**: cambios de ángulo mayores de 40°
  entre segmentos consecutivos. Un círculo dibujado a mano da 0–1 porque
  cada giro es suave; una estrella da muchos.
- La clasificación es una **escalera de tramos** (`<=1`, `<=3`, `<=5`,
  resto). Añadir un quinto elemento es insertar un tramo, no reescribir
  las condiciones existentes.
- **Limitación conocida**: contar esquinas no distingue formas parecidas
  (una gota vs. un círculo). Para eso hará falta el algoritmo **$1
  Unistroke Recognizer**. Pospuesto a propósito.

### `spellbook.gd` — el grimorio

La interfaz de dibujo, abierta con `T`. Está pintada **entera por
código** (`_draw()`: arcos, líneas y círculos), sin una sola imagen: su
aspecto se cambia tocando números, no buscando arte.

**Es solo la cara del sistema.** Captura el trazo y lo pinta; quién
reconoce ese trazo y qué hechizo sale de él sigue siendo del
`Spellcaster`, al que encuentra por el grupo `"spellcaster"`. Si mañana
cambias el reconocimiento de gestos, este archivo no se entera.

Detalles que no son evidentes:

- **`process_mode = ALWAYS`** (puesto en la escena), como el
  `LevelController`: sin eso, el libro se congelaría con su propia pausa
  y no podrías ni cerrarlo.
- **Se abre con `T`, no con `TAB`**: `TAB` es la tecla que Godot usa por
  defecto para saltar de un control de interfaz al siguiente, así que
  siempre habría riesgo de que las dos cosas se pisaran.
- **Al cerrar se despausa ANTES de lanzar**, para que el hechizo nazca en
  un mundo que ya corre.
- **El libro no se abre si el árbol ya estaba pausado**: esa pausa es de
  la pantalla de muerte o de victoria, y cerrarlo luego la descongelaría.
- **El trazo debe nacer dentro del círculo**, y salirse de él lo termina.
  Se prefirió eso a recortar el punto contra el borde: recortar
  deformaría el gesto y el reconocimiento fallaría sin que se entienda
  por qué.

El núcleo central toma su color y su nombre del `RuneData` del elemento,
así que tampoco conoce la lista de elementos que existen. El anillo
exterior muestra **solo el patrón ya dibujado**, no las opciones
disponibles: decisión de diseño, más cercana a Witch Hat Atelier.

### `gesture_recognizer.gd` — el reconocedor $1 Unistroke

Algoritmo de Wobbrock, Wilson y Li (UIST 2007, Universidad de
Washington), portado a GDScript. Licencia **New BSD**: uso libre incluso
comercial, conservando el aviso de la cabecera.
Original: https://depts.washington.edu/acelab/proj/dollar/

Sustituye al conteo de esquinas porque este no distingue un **rombo de
un cuadrado** (ambos tienen 4 esquinas) ni un rayo de una estrella. Con
los sellos por delante, hacía falta algo que distinga *formas*, no
cantidades.

Cómo funciona: remuestrea el trazo a 64 puntos repartidos por igual, lo
escala y lo centra, y lo compara punto a punto con una biblioteca de
plantillas. El paso que de verdad hace el trabajo es el **remuestreo**:
después de él, dos trazos de la misma forma tienen sus puntos en sitios
equivalentes aunque uno se dibujara despacio (muchos puntos amontonados)
y el otro de un tirón.

> ⚠️ **Rotación acotada a ±20°, no invarianza total.** El $1 original
> normaliza el ángulo para reconocer una figura la dibujes como la
> dibujes. Pero **un rombo es un cuadrado girado 45°**, así que con
> invarianza total los dos gestos se vuelven el mismo. Medido con 150
> gestos sintéticos: con invarianza total, cuadrado y rombo aciertan
> 12/30 y 15/30 — azar puro entre dos opciones —, y el total baja al
> 77%. Con rotación acotada, ambos 30/30 y el total 98%. Los trazos
> rectos ni pasan por aquí: su orientación ya la resuelve el sector.

La búsqueda del mejor ángulo usa **sección áurea**: como el parecido en
función del ángulo tiene un solo valle, cada vuelta descarta la mitad
peor del intervalo. Unas diez comparaciones en vez de cuarenta.

### `gesture_library.gd` / `.tres` — los gestos como dato

Igual que un elemento es un `RuneData` y no código, **un gesto es un
dato y no una heurística**. Añadir una forma nueva es dibujarla, no
escribir una función que la detecte. Ese es todo el sentido del $1.

Cada gesto guarda **varias muestras** a propósito (3-5): el mismo trazo
sale distinto rápido que despacio. Con una sola muestra el reconocedor
es frágil.

**Modo de grabación**: dentro del grimorio, `G` lo activa, las teclas
`1..9` eligen qué gesto se graba y cada trazo guarda una muestra. El
libro se pone naranja para que no haya duda de que no vas a lanzar nada.

Vive dentro del propio libro a propósito: así las plantillas se graban
**en las mismas condiciones** en que luego se dibujan — mismo tamaño de
círculo, mismo ratón, mismo pulso. Una herramienta aparte grabaría
gestos que no se parecen a los de la partida real.

Guarda en disco tras cada muestra (perder 40 trazos por cerrar el juego
sin pensar sería para tirar la mesa). Solo funciona desde el editor:
`res://` es de solo lectura en un juego exportado, y está bien — es una
herramienta de desarrollo, no una función del juego.

**Migración con red**: mientras la biblioteca esté vacía manda el conteo
de esquinas; en cuanto haya plantillas, manda el $1. Los mensajes de
consola van marcados con `[esquinas]` o `[$1]` para poder comparar los
dos en la misma partida.

### `rune_data.gd` + archivos `.tres` — las propiedades de cada elemento

Un elemento no es solo un color: es un `Resource` con propiedades
(`color`, `damage`, `tags`). Añadir una propiedad nueva es añadir un
`@export var` y rellenarlo en el `.tres` — sin tocar ninguna lógica.

Las **`tags`** son la pieza más importante de todo el diseño. Los objetos
del mundo no preguntan "¿eres fuego?", preguntan "¿traes la etiqueta
`calor`?". Gracias a eso, el día que haya tres runas de fuego distintas,
todas derretirán hielo sin tocar el código del hielo.

### `spell.gd` + `spell_factory.gd` — el hechizo y el contrato `on_spell_hit`

El hechizo lleva su `RuneData` completo. Al tocar cualquier `Area2D`, no
sabe qué ha tocado: comprueba si tiene `on_spell_hit()` y se lo pasa.

```gdscript
func _hit(area: Area2D) -> void:
	if area.has_method("on_spell_hit"):
		area.on_spell_hit(rune_data, direction)
```

**Este es el patrón clave del proyecto**: cualquier objeto que implemente
`on_spell_hit()` reacciona a los hechizos, sin que `Spell` tenga una lista
de "cosas que existen". Combate y puzzles usan el mismo mecanismo.

Un hechizo puede ser de dos tipos, decidido por su `direction`:

- **Con dirección** → vuela y desaparece al primer impacto.
- **Sin dirección (ZERO)** → se queda quieto un tiempo
  (`stationary_lifetime`) y puede afectar a varias cosas. Así están hechos
  el pilar, la barrera y las nubes de vapor: **el vapor no es una escena
  nueva, es un hechizo quieto con otra ficha**.

Un hechizo quieto que nace ya solapado con un bloque no recibiría nunca
`area_entered` (nadie "entra": ya estaban juntos), así que al nacer espera
un ciclo de física (`await get_tree().physics_frame`) y mira a mano con
`get_overlapping_areas()`.

**`spell_factory.gd`** centraliza la creación porque **el orden importa**:
`add_child()` ejecuta `_ready()` al instante, así que todo lo que `_ready`
necesite leer (`direction`, `stationary_lifetime`) debe asignarse **antes**
de meter el nodo en el árbol, y lo que necesite estar en escena
(`global_position`, `$ColorRect`) **después**.

---

## El mundo: objetos que reaccionan

### `neutral_block.gd` — el suelo de los niveles

**Por qué existe**: si todos los bloques reaccionan, el jugador no puede
distinguir decorado de puzzle. Este es la base mayoritariamente inerte.
Nunca bloquea el paso (no tiene `SolidBody`); sus reacciones son de
superficie.

| Estado | Con agua | Con fuego              | Con tierra           |
|--------|----------|------------------------|----------------------|
| DRY    | → WET    | —                      | construye EarthBlock |
| WET    | → ICY    | → DRY **+ vapor**      | construye EarthBlock |
| ICY    | —        | → WET                  | construye EarthBlock |

En `ICY` es **resbaladizo**, no sólido: el bloque no empuja al jugador,
solo le avisa (`add_ice_contact()` / `remove_ice_contact()`) y es el
jugador quien decide qué significa. El jugador cuenta contactos en vez de
usar un `bool` porque puede tocar dos bloques helados a la vez.

> Detalle sutil: avisar de "sales del hielo" se hace mirando la
> **transición** (`ICY → otro`), no el estado nuevo. Si no, un bloque que
> pasa de seco a mojado restaría un contacto que nunca sumó.

### Altura: subirse a las cosas en un juego sin eje Z

Este juego es cenital, así que no existe una coordenada de altura. La
altura es una **convención** montada con tres piezas que hay que mantener
de acuerdo entre sí:

1. **Un número**: `Player.elevation` (0 = suelo, 1 = subido). Un solo
   nivel basta para todo lo que hay; apilar más sería subir ese número,
   no rehacer la idea.
2. **Un truco visual**: el sprite se dibuja `ELEVATION_OFFSET` píxeles
   más arriba y se enciende una sombra en el suelo. La sombra no es
   decorativa: sin ella, un sprite desplazado 16px solo parece mal
   colocado. Con ella, se lee "está en alto".
3. **Una regla física**: arriba se apaga la máscara de colisión con el
   mundo (`set_collision_mask_value(1, false)`). No es que atravieses las
   cosas, es que estás por encima. Lo que te limita ya no son las
   paredes, es **el borde de la estructura**: en cuanto lo pasas, caes.

**Se sube saltando**, sin tecla ni animación nuevas: al terminar el
salto, si hay algo trepable debajo, te quedas encima. **Se baja andando**
hasta salirse.

Un `CharacterBody2D` no puede preguntar con qué áreas se solapa, así que
el jugador lleva un `Area2D` pequeño llamado `Feet` que sí puede, y que
mantiene la lista `supports`. Es una lista y no un contador porque un
bloque puede **desaparecer solo** (convertirse en vegetación, o
desmoronarse al llegar al tope de 20): en ese caso nunca llega el aviso
de "has salido de mí". Por eso se filtra con `is_instance_valid()` antes
de usarla — y por eso, si te quitan el suelo de debajo, te caes.

Lo que marca qué se puede escalar es el **grupo `"climbable"`**, no el
tipo de nodo. Es el mismo criterio que `on_spell_hit`: cualquier cosa
futura (una caja, una plataforma) se vuelve trepable con solo entrar en
ese grupo.

**Simplificación conocida**: mientras estás arriba, `receive_damage()`
ignora todo golpe. Es el motivo de ser de la altura (las llamas y los
enemigos del suelo no te alcanzan), pero es una regla tajante: el día que
haya enemigos voladores o a distancia, habrá que decirle a esa función
desde qué altura viene el golpe. El `Spellcaster` tampoco sube con el
sprite, así que los hechizos siguen saliendo a ras de suelo.

### `earth_block.gd` — lo que el jugador construye

Sólido y **trepable**, se crea con la runa de tierra sobre suelo neutro o
sobre agua (no en el aire: da una regla clara y limita el spam de forma
natural). Sobre agua funciona como pasadero: una segunda forma de cruzar,
distinta de congelarla, que no depende del frío pero gasta bloques y
obliga a ir saltando.

Solo construye con **pilar o barrera**, no con flecha. Para distinguirlos
no hizo falta un dato nuevo: una flecha llega con dirección (va volando)
y un pilar o una barrera llegan quietos, con dirección cero. Si algún día
aparece un patrón quieto que no deba construir, entonces sí habrá que
pasar el patrón explícitamente.

Dónde se puede construir lo decide **quien recibe el hechizo**, no la
tierra: `NeutralBlock` y `WaterBlock` llaman a `EarthBuilder.build_on()`,
y cada uno guarda su propio `occupant` para no apilar dos cosas en la
misma casilla. La receta de construir vive en `earth_builder.gd` una sola
vez, ya que la necesitan dos sitios y mañana probablemente más.

**Tope: 20 bloques simultáneos** (`MAX_EARTH_BLOCKS`). Cada bloque es un
área + un cuerpo estático que el motor consulta cada ciclo; sin límite, la
memoria y la física se degradan rápido. La política es **FIFO**: al pasarse
del tope desaparece el **más antiguo**, nunca el recién creado — así el
jugador nunca siente que su última acción "no hizo nada".

**Tierra + agua = vegetación**: en vez de darle al bloque de tierra un
estado "con hierba" (y duplicar toda la lógica de incendios), el bloque se
sustituye a sí mismo por un `GrassBlock`. Cada script sigue haciendo una
sola cosa.

### `grass_block.gd` — simulación de incendio

Cinco estados con un ciclo de vida real:

```
THIN ──agua──> GROWN          (hierba baja / tupida y sólida)
  │              │
  └──fuego───────┴──> IGNITING ──1s──> BURNING ──5s──> ASHES
                          │               │              │
                          └───agua────────┴──agua────────┘
                                   (vuelve a THIN)
```

- **IGNITING** (1s): ha prendido pero aún no quema. Es la ventana de
  reacción del jugador.
- **BURNING** (5s): hace daño y **contagia** a la vegetación en un radio de
  110px cada 1.2s (los bloques están a ~90px, así que salta a los vecinos).
- **ASHES**: se consumió. Inerte, ya no arde. Regándolo rebrota.

El fuego se apaga solo: un incendio no dura para siempre, lo que convierte
el tiempo en un recurso del puzzle.

**Viento sobre llamas** hace dos cosas, como un incendio real: lanza una
lengua de fuego hacia delante (un hechizo que vuela) y **salta
directamente** a la vegetación a favor de viento, hasta 230px y solo en un
cono en esa dirección (producto escalar > 0.3).

`ignite()` es pública a propósito: es como un bloque contagia a otro, sin
fabricar un hechizo para cada contagio.

### `water_block.gd`

`frio` congela (pasable), `calor` derrite. **Agua + fuego = vapor** tanto
si estaba helada (se derrite) como líquida (hierve).

`viento` sobre agua congelada propaga el frío hacia delante.

### `enemy.gd`

Patrulla entre dos puntos (`patrol_distance` desde su posición inicial) y
hace `damage_per_second` de daño por contacto mientras el jugador esté
encima.

Para decidir si un hechizo le duele **no lista elementos a ignorar**, mira
el dato que importa: `rune_data.damage <= 0`. Así viento, tierra y vapor
se ignoran solos, y cualquier elemento futuro también.

---

## Bloqueo físico vs. detección de hechizos

Un objeto interactivo necesita **dos tipos de colisión** en el mismo nodo:

- Un `Area2D` (raíz) — detecta cuándo un `Spell` lo toca. No bloquea.
- Un `StaticBody2D` hijo (`SolidBody`) — este sí bloquea al `Player`. Se
  activa/desactiva con `set_deferred("disabled", true/false)`.

`set_deferred` en vez de asignar directamente: cambiar una forma de
colisión en mitad del paso de física puede ser inestable; `set_deferred`
aplica el cambio de forma segura al terminar el ciclo actual.

---

## Interfaz y estados de partida

- **`health_bar.gd`**: un `ProgressBar` en un `CanvasLayer`. Encuentra al
  jugador por el **grupo** `"player"` y se suscribe a su señal
  `health_changed`. El jugador no sabe que existe una barra de vida.
- **Victoria** (`goal.gd`) y **muerte** (`player.gd::_die()`) siguen el
  mismo patrón: buscan su cartel por grupo (`"victory_ui"` /
  `"gameover_ui"`), lo hacen visible y pausan el árbol.
- **`level_controller.gd`**: nodo aparte con `process_mode = ALWAYS`, para
  seguir leyendo la tecla `R` **estando en pausa**. No se puede poner
  ALWAYS en el nodo raíz porque los hijos lo heredan y entonces nada se
  pausaría. Antes de recargar hace `get_tree().paused = false`, porque el
  flag vive en el `SceneTree` y sobreviviría al cambio de escena.
- `receive_damage()` del jugador tiene una guarda `is_dead`: sin ella, los
  temporizadores de daño ya en marcha seguirían llamando a `_die()` en
  bucle.

---

## Decisiones de diseño ya tomadas

- **Vista 2D top-down**, no isométrica: los puzzles de rejilla son mucho
  más simples de razonar, e isométrico añadiría proyección y arte sin
  aportar a la mecánica.
- **Sin arte propio todavía** — todo son `ColorRect`. Deliberado: validar
  mecánicas antes que estética.
- **2 runas por hechizo** (elemento + patrón), a propósito, para no
  bloquear el progreso del mundo mientras crece el vocabulario de gestos.
- **Las reacciones viven en el objeto que reacciona**, nunca en el
  elemento. El fuego no sabe que existe la hierba; la hierba sabe qué
  hacer cuando le llega algo con la etiqueta `calor`.

---

## Arte actual

Los sprites salen del pack **Kenney Mini Forest** (CC0, uso libre incluso
comercial). Es un pack **3D**, pero incluye *previews* renderizadas de
64×64 con transparencia que funcionan perfectamente como sprites 2D en
perspectiva 3/4 — justo la cámara "top-down ligeramente inclinada" que
buscábamos.

Las texturas usadas se copiaron a `art/` con nombres propios del juego, en
vez de referenciar rutas del pack. Así, cambiar de pack mañana es
sustituir 8 archivos, sin tocar ninguna escena:

| Archivo             | Origen              | Se usa en          |
|---------------------|---------------------|--------------------|
| `art/floor.png`     | `patch-dirt`        | NeutralBlock       |
| `art/water.png`     | `patch-dirt` teñido | WaterBlock         |
| `art/grass.png`     | `patch-grass`       | GrassBlock (baja)  |
| `art/grass_grown.png`| `plant`            | GrassBlock (crecida)|
| `art/earth.png`     | `rocks-low`         | EarthBlock         |
| `art/hero.png`      | `character-archer`  | Player             |
| `art/enemy.png`     | `target`            | Enemy              |
| `art/goal.png`      | `flag`              | Goal               |

El pack no traía agua, así que `water.png` es la **misma losa de tierra
recoloreada a azul**. Conserva silueta, perspectiva y sombreado del resto
del pack, que es lo que hace que no desentone — un cuadrado azul plano
habría cantado muchísimo.

**Convención de nodos**: cada bloque tiene un `Sprite2D` llamado `Visual`.
Los estados se pintan con `modulate`, que **multiplica** el color de la
textura: blanco `(1,1,1)` la deja tal cual, por debajo la oscurece, por
encima de 1 la aclara. Así el suelo mojado, el hielo o las cenizas son la
misma textura teñida, sin necesitar un archivo por estado. La única
excepción es la hierba, que sí cambia de textura al crecer porque una mata
alta no es "hierba baja más oscura".

### Efectos de hechizo (`art/fx/`)

Cada elemento tiene su animación, tomada de un pack de VFX organizado por
elemento e intensidad (`weak`/`medium`/`strong`). Las originales son ~30
fotogramas sueltos de ~500×500 por animación: cargar las 537 del pack
serían **cientos de MB de VRAM**, así que se muestrearon ~18 fotogramas de
cada variante *weak* y se montaron en una hoja de 128px por fotograma
(unos 80 KB por elemento).

> ⚠️ **Los fotogramas van en REJILLA de 6 columnas, no en una tira.** El
> primer intento fue una tira horizontal, que para 19 fotogramas medía
> 2432px de ancho. Algunas tarjetas gráficas tienen el tamaño máximo de
> textura en 2048px, y el juego arrancaba con un reguero de
> `Texture dimensions exceed device maximum` y texturas nulas. La misma
> animación en 6 columnas mide 768px. **Regla práctica: ninguna textura
> del proyecto debería pasar de ~1024–1280px de lado.** Por eso el fondo
> también es de 1280×800 escalado ×1.6 en la escena, en vez de una imagen
> de 2048px.

Godot recorta la rejilla solo: `hframes` y `vframes` dicen en cuántas
columnas y filas está partida la textura, y `frame` recorre las celdas de
izquierda a derecha y de arriba abajo. No hace falta un
`AnimationPlayer` ni un archivo por fotograma — basta con avanzar `frame`
por tiempo, contando hasta los fotogramas **reales** y no hasta el total
de celdas (la última fila puede tener celdas vacías, que aparecerían como
parpadeos).

Configurar el sprite lo hace el propio elemento (`RuneData.setup_sprite()`),
para que los dos sitios que animan efectos —el hechizo y la hierba
ardiendo— no repitan esa configuración ni el riesgo de desfasarse.

**La animación es un dato del elemento**, no del hechizo: `RuneData` tiene
`vfx_sheet` y `vfx_frames`, igual que tiene `color` y `damage`. `spell.gd`
nunca pregunta "¿eres fuego?", solo "¿traes tira?". Un elemento nuevo con
su animación se verá animado sin tocar una línea de `spell.gd`.

El `ColorRect` sigue ahí como **respaldo** para elementos sin animación
propia (el vapor): al menos transmiten su color.

La hierba ardiendo reutiliza la tira de `FIRE_RUNE`, no un PNG aparte: si
cambias la animación de fuego, cambia en los hechizos y en los incendios a
la vez. Cada bloque arranca su contador de animación al prender, para que
dos hierbas encendidas en momentos distintos no ardan sincronizadas (que
es lo que delataría que son el mismo dibujo repetido).

Queda pendiente y fácil: las variantes **medium** y **strong** del pack
están sin usar. El gancho natural es que la intensidad del efecto refleje
la potencia del hechizo.

**Rejilla**: todo se normalizó a casillas de **64×64 centradas en el
origen** del nodo. Antes cada bloque tenía su `ColorRect` y sus formas de
colisión descuadradas unos píxeles de tanto moverlos a mano, lo que con
sprites reales se habría notado enseguida.

---

## Dirección de arte (referencia: *Children of Morta*)

El pack actual es un placeholder digno. Estas notas fijan hacia dónde ir:

- **Iluminación**: es el rasgo más característico. Escenas base oscuras y
  desaturadas con **focos de luz cálida** (antorchas, fuego, magia) que
  tiñen el entorno. En Godot esto se monta con un `CanvasModulate` oscuro
  global + `PointLight2D` en las fuentes de luz. Encaja perfectamente con
  este juego: **el fuego que lanzas debería iluminar la escena**, y un
  incendio propagándose cambiaría la iluminación de toda la sala.
- **Paleta**: ocres, marrones y rojos apagados de base; el color saturado
  se reserva para lo interactivo (el azul del agua, el naranja del fuego).
  Esto ya es lo que hacen los `ColorRect` actuales — conviene mantener ese
  criterio al pasar a arte real: **lo que brilla, es jugable**.
- **Cámara**: top-down ligeramente inclinada, no cenital pura.

El siguiente paso de arte **no es cambiar sprites, es la iluminación**: es
lo que más acerca al referente y no necesita ningún asset nuevo.

---

## Pendiente / próximos pasos naturales

- **UI radial de runas** (estilo Witch Hat Atelier / runa vikinga): círculo
  exterior que contiene el trazo, núcleo central con el elemento, anillo de
  propiedades alrededor. Es la siguiente pieza grande.
- **Rueda hidráulica**: primer objeto que reaccione a la etiqueta `vapor`.
  El gancho ya existe — solo falta el objeto.
- **Excepciones del viento**: hoy el viento propaga elementos de forma
  generalista. Falta distinguir qué bloques puede mover físicamente.
- Separar el mapa único en escenas de nivel independientes.
- Ampliar el vocabulario de gestos (necesitará $1 Unistroke).
- Sonido, y el ciclo de iluminación descrito arriba.
