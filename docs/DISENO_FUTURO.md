# Diseño futuro — lo que se quiere, no lo que hay

ATLAS DE PRIORIDADES:
P0: Prioridad muy alta, Implementar primero
P1: Prioridad alta
P2: Prioridad media 
P3: Prioridad baja

P0 y P1 tienen prioridad si hay tareas en P2 solo se harán si requieren poco código y que no rompa nada en el proceso. 

`ARQUITECTURA.md` cuenta **lo que el código hace hoy**. Este archivo cuenta
**lo que se quiere que haga**: es la cola de sistemas por implementar, con
la prioridad de cada uno en su título. Se prueban en local y cada idea
lleva su coste al lado para poder elegir con los ojos abiertos.

Cuando una idea se implementa, cruza de aquí a `ARQUITECTURA.md` en
presente, y aquí se borra.

> **El criterio que manda sobre todo lo demás: solo se añade lo que da
> opciones nuevas al jugador.** Un sistema que no abre jugadas nuevas no
> entra, aunque sea bonito. Si los elementos y los glifos están bien
> elegidos, **los puzles se hacen solos**: salen de combinar lo que ya hay,
> no de escribir una regla para cada sala. Es la misma idea que sostiene
> `sigils.gd`: no se escriben combinaciones, emergen.

Cada idea lleva: **qué**, **por qué**, **cómo encaja con la arquitectura**,
**qué cuesta** y **qué hay que decidir** antes de empezar.


---

## 0. La prueba 3D (`poc_25d`): cuándo termina y qué decide (P0)

**Qué.** `poc_25d/` es una maqueta en Godot 3D (cámara ortográfica
isométrica, personajes chibi de Meshy directos del GLB, suelo con estado por
casilla, agua por profundidad, hierba que se aparta). Nació para responder
una pregunta: **¿merece la pena pasar el juego a 3D?** Igual que la rama
isométrica de septiembre, es una prueba, no un segundo juego: **tiene que
terminar**.

**Lo que resuelve el 3D por construcción** (hoy son tareas del plan, en 3D
son propiedades): profundidad y altura reales (adiós `y_sort`, elevación
fingida, colisiones de rombo), apuntar en 360°, luz única para personaje y
mundo (el "arte choca"), el fuego ilumina, sombra que ancla al suelo, clips
sin renderizar a 8 direcciones (se retiran `MsAtlas`/`MsActor`, los atlas y
el mapeo este-oeste), pilar/columna sólidos.

**Lo que cuesta:** traducir la capa de presentación y la física
(`nivel_base`, `spell_form`/`spell_material`/`spell.gd`, `player`, bloques,
enemigos: `Area2D→Area3D`, `Vector2→Vector3`), aprender materiales, luces y
shaders, un estilo coherente por shader y no por dibujo, y rendimiento
(hierba, maleza, partículas) que en 2D nunca hubo que pensar. El núcleo
(grimorio, $P, receta, etiquetas, estados, mochila, niveles por letras) no
cambia.

**Criterio de decisión, escrito antes de seguir.** El 3D gana si de este
documento se necesitan **al menos tres** de:

1. altura real (saltar sobre bloques, columna de barrera + levitación que se vea sólida);
2. luz del fuego sobre la escena;
3. apuntar en 360° con cast point en el ratón (playtest del 4/10);
4. agua que se comporte como fluido (§2);
5. muchos personajes o clips nuevos (§5: cada clip en 2D es una noche de render);
6. agua helada, charcos, ceniza y hierba como **estado por casilla** sin un PNG por estado (§6).

Con dos o menos, el 2D isométrico basta y lo que toca es terminar de
sustituir `art/` por el pipeline.

**Condición de fin de la prueba** (una semana desde el 5/10, es decir, el
12/10; las tareas con dueño están en `PLAN_ARREGLOS.md`, fase 4 "Test 3"): `PruebaTest2` jugable con el grimorio real (no F1–F6), fuego que
prende hierba y se contagia, un goblin con `Combate`, y una tabla de
medición (ms por fotograma a 40×40, MB de VRAM, tiempo de traducir
`spell_form`). Con eso Pablo decide y lo escribe aquí; si es 3D, la
migración entra en `PLAN_ARREGLOS.md` como fase 4 con pasos; si es 2D,
`poc_25d/` se archiva (`.gdignore` + `_descartado`) y lo aprendido
(shaders de estado, rampa de luz) se queda como referencia.

**Lo que no se hace mientras tanto:** añadir contenido a la maqueta que no
sirva para responder la pregunta (grimorios equipables, carteles con runa,
bibliotecas de Meshy). Cada asset nuevo en `poc_25d` tiene que justificar
qué criterio de los seis ayuda a medir.

---

## 0b. Decisiones del 6/10/2026 para el Test 3 (P0, cerradas)

Entran en el `Lanzador3D` y en el jugador 3D desde el principio. Lo que lleva
"ajustar" es un número de partida, no una regla.

**Altura.** Niveles enteros de un bloque. El salto sube **un** nivel. La
tierra se apila hasta **dos**. Barrera + levitación da una columna de dos
niveles **sólida y subible**, que bloquea proyectiles. Los proyectiles
vuelan a medio nivel y chocan con lo que esté a nivel ≥ 1: un bloque es
cobertura contra el arquero. Los goblins no suben. Caer no hace daño.
Hay un **máximo de bloques escalables a la vez** (`MAX_NIVELES_SUBIBLES`,
de partida 2: no se sube a una torre de tres), para que apilar no sea la
solución de todo.

**Lanzar = un modo, no un instante.** Al abrir el libro el tiempo se para
(como hoy). Al cerrarlo con un hechizo compuesto se entra en **modo
lanzar**: el tiempo va al **70 %** (ralentizado un 30 %; ajustar), el
personaje hace la animación `readandwrite` con partículas sutiles del
elemento, y mientras tanto el jugador controla **dirección y posición** del
hechizo con el ratón: el origen es el punto señalado, con alcance máximo de
**3 casillas** (más lejos, se queda en el borde). Soltar lanza. La animación
de lanzar **no es una general**: cada forma declara la suya en datos
(`anim_cast` en la tabla de formas/VFX) y se usa la más coherente con lo que
sale (una flecha de fuego horizontal → el lanzamiento horizontal; una
columna → el de alzar); si una forma no declara ninguna, `readandwrite`.
`pilar` desaparece: el origen lo pone el ratón.

**Tierra y hielo caducan.** Ni la tierra creada ni el hielo pueden ser la
solución de todo: tierra 25 s y tope de 8 bloques; **hielo con duración**
(de partida 20 s, ajustar) salvo donde el nivel lo marque permanente. Cuando
el hielo se deshace con el jugador encima, cae al agua: **evento de caída al
agua** → animación `swim_forward` (está en el inbox del héroe), se mueve
lento hasta la orilla y no puede lanzar. Es el primer castigo del juego que
no es daño. `ESTADOS_SUELO.md` tiene que recoger el cambio (hoy dice que el
hielo no caduca).

**Retardo** se retira del Test 3 (no se porta); si vuelve, vuelve como trampa.

---

## 1. Elementos combinables en el núcleo (P2)

**Qué.** Cuatro elementos base: **fuego, agua, viento y tierra**. A partir de
cierto punto de la progresión se puede dibujar un **segundo elemento en el
núcleo**, y la pareja da un elemento derivado:

| pareja | derivado | estado |
|---|---|---|
| fuego + tierra | magma | por definir |
| fuego + viento | relámpago | el menos intuitivo; ver decisiones |
| fuego + agua | vapor | **ya existe** como elemento que genera el mundo |
| agua + viento | hielo | hoy es elemento base |
| agua + tierra | naturaleza | por definir; ver decisiones |
| viento + tierra | arena / polvo | por definir |

Dos elementos iguales no producen nada (o amplifican; ver decisiones).

**Por qué.** Hace que el núcleo también sea un lenguaje, no solo un menú de
siete opciones; da una curva de progresión natural (empiezas con cuatro,
desbloqueas la mezcla); y convierte rayo y hielo en algo que *descubres*.

**Cómo encaja.** Muy bien: una tabla `par → RuneData` es "datos, no código",
y `vapor` ya demuestra que un elemento derivado funciona contra el mundo
sin tocar el mundo. Los `.tres` de rayo y hielo **no se tiran**: pasan a ser
el *resultado* de una pareja. Las cámaras de rayo y hielo del Test 2 pasan a
ser pruebas de combinación (contenido de media partida, no de inicio). Las
debilidades de `combate_comun` siguen funcionando porque van por etiqueta.

**Qué cuesta.**
- El grimorio tiene que aceptar **dos gestos en el núcleo** y mostrar la
  mezcla (hoy el núcleo guarda un solo elemento y el libro enseña un
  símbolo por sitio).
- Los valores nuevos de `Runes.Type` (`MAGMA`, `ARENA`…) van **al final del
  enum**, como manda `ARQUITECTURA.md`.
- Cada derivado nuevo necesita tira de efecto, color, etiquetas y, sobre
  todo, **algo que solo él haga** (ver abajo).
- Gestos: con cuatro bases hay menos plantillas que grabar y menos
  confusiones en el reconocedor, lo que es una ganancia.

**Qué decidir antes de empezar.**
- **Relámpago = fuego + viento** es poco intuitivo. Alternativa legítima:
  el rayo sigue siendo base y solo hay cinco derivados. Se evita explicar
  una tormenta.
- **Naturaleza (agua + tierra) ya existe en el mundo**: tierra + agua da
  `GrassBlock`. Si además es un elemento lanzable, hay dos caminos para lo
  mismo. O se define como algo distinto (*crecimiento*: hace brotar
  reagentes, hace crecer la maleza sin regar) o se deja como reacción del
  mundo y no entra como elemento.
- **Arena/polvo y magma necesitan un trabajo exclusivo**, o serán otra vez
  la pregunta 2 del Test 2. Arena: ¿ciega enemigos? ¿apaga? ¿rellena un
  foso? Magma: ¿tierra que quema? ¿bloque que se enfría a piedra? Decidir
  eso antes de dibujar nada.
- **Igual + igual.** La receta ya tiene `power` multiplicativo, así que
  "fuego + fuego = amplificar" sale gratis. Pero si no cuesta nada, el glifo
  de amplificar queda redundante. Propuesta: igual + igual = nada en la
  primera versión; medir si alguien usa el glifo; si nadie lo usa,
  fusionarlos.

---

## 2. Intención de diseño por elemento (P2)

 
Lo que cada elemento *debería* significar, más allá de sus etiquetas de
hoy. La tabla de `ARQUITECTURA.md` es el contrato (gesto, etiquetas, daño);
esto es la dirección hacia la que empujar ese contrato.

| elemento | intención | cómo se traduciría |
|---|---|---|
| fuego | quemar; **útil sobre todo contra lo que lleva madera** | etiqueta `quema_madera` en el fuego y `madera` en los combustibles (`combustible.gd` ya tiene las letras `z l h r`) |
| agua | apagar incendios, hacer crecer la hierba en casos concretos, **rellenar espacios y comportarse como fluido** | `apaga`, `riega` son etiquetas; lo del fluido es otra cosa, ver coste |
| tierra | bloques sólidos; dejar paso / cerrar paso; peso | ya existe (`earth_block`, placa de peso); falta decidir qué más hace solo ella |
| rayo | conductividad entre elementos y metal; aturdir | `conduce`, `aturde`; hoy es base, en §1 pasa a derivado (se guarda el código) |
| hielo | congelar acciones; es **sólido** en general, salvo un "spray de congelación" en casos concretos | sólido/spray no son dos elementos: son dos glifos (barrera = bloque, flecha = spray) |
| viento | mover lo ligero, llevar llamas, empujar | ya arrastra (`carried_element`); falta: molinos, nubes de esporas, apagar velas a distancia |

**Coste del "agua como fluido".** `ARQUITECTURA.md` descartó la vista
lateral justo porque el agua tendría que acumularse y caer. En isométrico,
un agua que se extiende a N losas vecinas más bajas es viable, pero obliga
a rediseñar `water_block.gd` y los puzles de puente y foso. Si se quiere,
es una decisión aparte con su propio coste, no una celda de tabla.

---

## 3. Más glifos por hechizo y la matriz de formas (P2; la regla del libro, P0)

**Qué.** Hasta **6 glifos** en un hechizo, **uno por sector**. Cada sector
es un hueco: una vez dibujado un glifo, dibujar encima no hace nada; el
clic derecho borra lo escrito. El libro tiene que **enseñar el hueco
ocupado** y rechazar el segundo trazo con un aviso, no en silencio. El
tope por página sigue siendo `Repertoire.max_sigils_per_page`, que ya se
compra a la librera.

Las soluciones largas tienen que dar hechizos con sentido: flecha +
elemento dispara un bloque pequeño del elemento que se mueve; si añades
barrera, es un muro que se mueve.

**Decidido (4/10/2026): un glifo por sector.** Lo que eso cambia:

- Hoy los glifos **solo se combinan si están en el mismo sector**
  (`spellcaster._component_at`: un sector = un componente; sectores
  distintos = hechizos independientes). Con un glifo por sector, `barrera +
  levitación` ya no se puede escribir en el mismo hueco.
- En los niveles se apunta con el ratón (`Repertoire.aim_with_mouse`), así
  que el sector **ya no da la dirección**: solo es un hueco. Por tanto, con
  ratón, **todos los glifos de la página van a una sola receta** (un solo
  componente), y la dirección la pone el ratón. Es un cambio pequeño en
  `_component_at` (con `aim_with_mouse`, devolver siempre el mismo
  componente) y la paleta (`place_sigil`) ya hace exactamente eso.
- Sin ratón (Blockout, IsoTest, laboratorios), cada sector sigue siendo
  un componente con su dirección: el comportamiento antiguo no se toca.
- El libro deja de tener el problema de "barrera sola y barrera +
  levitación se dibujan igual": cada glifo tiene su hueco y se ve.

**Lo que ya está hecho.** El ejemplo de arriba **es exactamente lo que el
sistema hace hoy**: `barrera + flecha` da el muro de través. La semántica
no hay que redefinirla: la tabla de acumulación de `spell_recipe.gd` tiene
seis ejes ortogonales (viaja, origen, área, permanencia/altura, copias,
potencia) más los cinco parámetros de los glifos nuevos (`bounces`,
`delay`, `pulse`, `pull`, `mirror`), y cada glifo escribe solo en el suyo.
"Reconocer la solución más larga y usar el resto como apoyo" sería volver
a una tabla de combinaciones con prioridad, que es lo que `sigils.gd`
evita a propósito.

**Lo que de verdad falta: los sprites.** Hay combinaciones cuya receta
sale bien pero cuya forma visual no existe. La tarea no es cambiar la
semántica sino hacer la **matriz receta → forma visual**
(`spell_form.gd` / `spell_material.gd`) y ver qué celdas no tienen dibujo.
Es un documento de media hora y produce directamente la lista de assets
que pedir al Pipeline. Las combinaciones que salgan "gratis" en pruebas se
toman sin tocar código.

**Qué cuesta.** La regla del libro (un glifo por sector + una receta por
página con ratón) toca `spellcaster.gd` (`_component_at`, `add_sigil`) y
`spellbook.gd` (dibujar el hueco ocupado): poco código, no rompe nada, y
las cámaras del Test 2 se juegan con el libro, por eso va **P0** aunque el
resto del apartado sea P2. La matriz de formas es P2.

---

## 4. Enemigos: el elemento adecuado te apoya (P1)

**Qué.** El núcleo de un enemigo es que **usar el elemento adecuado ayuda a
derrotarlo**. Ejemplos: un goblin con escudo que bloquea hechizos pierde
esa ventaja si le quemas el escudo; un elemental de fuego recibe mucho más
daño del agua.

**Lo que ya está hecho.** El segundo ejemplo ya funciona: `Combate`
(`combate_comun.gd`) lleva debilidad ×2 y resistencia ×0,5 por etiqueta,
con el rombo de color al lado de la barra.

**Cómo encaja el escudo.** Por duck typing, como todo lo demás: un nodo
hijo `Escudo` con su propio `on_spell_hit`, la etiqueta `madera` y una
forma de colisión que intercepta proyectiles (`blocks`, el mismo parámetro
que ya tiene la barrera). Si recibe `quema_madera`, se destruye y el goblin
queda expuesto. Ni el goblin ni el fuego se enteran. Es la misma idea que
`Combate`: **comportamiento como componente**, no como `if` dentro del
enemigo. Cada enemigo nuevo debería poder describirse como "base + lista
de componentes".

**Qué decidir.** Qué componentes merecen existir: escudo (bloquea, arde),
armadura (resiste tierra, el rayo la atraviesa), montura (velocidad, el
hielo la frena)… Cada uno solo entra si abre una jugada nueva.

---

## 5. Un flujo de chequeo de las animaciones (P0)

**Qué.** Que un clip mal exportado se detecte al arrancar, no al verlo
cortado en pantalla.

**Lo que ya hay.** `ActorAnimator._check_sheets` validaba las hojas
antiguas; `tests/` tiene pruebas visuales; `docs/QA_ARTE.md` hizo la
medición a mano; el pipeline valida márgenes al renderizar.

**Lo que falta.** Que `MsAtlas` compruebe al cargar un personaje que lo que
promete `meta.json` cuadra con el PNG real: `filas × frame_px.y` y
`frames × frame_px.x` contra el tamaño del atlas, clips sin bucle
marcados, `ancla_suelo_px` dentro del fotograma. Una función, avisa por
consola como `_check_sheets`. Tarea del Pipeline (dueño de `ms_atlas.gd`).
Añadida al plan como **1.8**. Definir por personaje las animaciones minimas necesarias y el formato (preferiblemente 3D) e iterarlas.


---

## 6. Un sprite debajo de las partículas (P0)

**Qué.** Las partículas resuelven el movimiento, pero un **sprite plano en
la cara superior de la losa** (quemadura, charco, escarcha, polvo) anclaría
el efecto a la casilla y puliría el aspecto.

**Por qué encaja.** Es la misma razón que da la sección de partículas de
`ARQUITECTURA.md`: lo que vende el volumen es que las cosas ocurran en el
sitio correcto. El sprite dice *dónde*; las partículas dicen *que pasa
algo*.

**Cómo.** Un PNG por estado con el **mismo lienzo que la losa** (128×64,
cara en y = 33), colocado por el **bloque que reacciona**, no por el
hechizo: el bloque ya sabe su estado y ya tiene `$Visual`. `wet_ground` y
`ash` ya están pedidos en `ASSETS_PENDIENTES.md` §2; faltaría `escarcha` y
`polvo`. Asset del Pipeline, código del Juego (`neutral_block.gd`,
`grass_block.gd`).

---
## 7 Sistema de sistesis (P1)

Crear una lista de ingredientes para que se puedan usar en mejorar el protagonista de distintas formas (mas glifos, mas sellos, mas vida, etc..). Estos ingredientes se 
usaran en recetas para crear esas mejoras..

## 8. Lo que ya estaba en la lista de "pendiente" y sigue siendo futuro (P2)

- **Rueda hidráulica**: primer objeto que reaccione a `vapor`. El gancho
  existe, falta el objeto. P3
- **Combinaciones sugeridas**: `repetición + barrera` → corros
  concéntricos; `amplificar + levitación` → que el aumento escale la
  *permanencia* cuando hay algo que permanece.
- **Iluminación**: cada hechizo ya lleva su luz (`Glow.attach`) y existe
  `Glow.night()`, pero solo lo usa `IsoTest`. Es lo que más acercaría al
  referente sin un asset nuevo. Decidir cuándo.
- **Dónde habla la maga**: los NPC ya tienen caja de diálogo; las frases
  de la maga siguen saliendo por `print()`. La anotación en el propio
  grimorio sigue pareciendo la opción buena. Definir si se quiere utilizar un Sprite en el caso de la protagonista para enfatizar emociones.
