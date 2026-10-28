# Propuesta de combate: apuntado, objetos y enemigos

27/10/2026 · contexto JUEGO · **propuesta para estudiar, nada construido**.

Pablo pidió tres cosas:
- mejorar el apuntado con una previsualización tipo LoL o Dota;
- objetos de uso aparte de las pociones;
- enemigos que pidan más complejidad o hechizos concretos.

El motivo es que hoy el combate se reduce a huir y tirar hechizos. Este documento recoge las ideas para elegir cuáles se construyen.

---

## 0. De dónde se parte (27/10)

- **Apuntado** (`magia/lanzador_3d.gd`). El flujo de hoy:
  1. Se elige una página con el libro cerrado (1, 2 o 3), o se compone una con el libro abierto. Con el libro abierto el tiempo va al 30 % (`TIEMPO_LIBRO`).
  2. Al elegirla se entra en el **modo lanzar** (`_entrar_modo_lanzar`, ~:833), también con el tiempo al 30 % (`TIEMPO_LANZAR`).
  3. Con el ratón: se pulsa para fijar el origen, se arrastra para dar la dirección y se suelta para lanzar. Clic derecho o Esc cancelan.

  El origen es siempre la jugadora; la barrera es la excepción (`en_punto`, a 3 casillas o menos). Mientras se apunta **ya se dibuja**, en ~:1324-1409:
  - el anillo de origen;
  - el anillo de alcance;
  - la barra de dirección;
  - cajas en las casillas que ocupará el hechizo (`GeometriaV2.celdas`), en rojo si no vale para ese elemento.

  Falta la ayuda de puntería y no se marcan los enemigos tocados, el daño ni las reacciones.
- **Objetos** (`nucleo/objetos.gd`, `nucleo/consumibles.gd`, `presentacion/ui/hud_eow.gd`). Hay cuatro consumibles, todos de uso propio: poción, tónico de tinta, bálsamo protector e infusión de brezo. Q usa el equipado y R cambia de uno a otro. Los ingredientes salen de reacciones: setas electrificadas, asadas, heladas… No hay ningún objeto que se lance, ni trampas, ni síntesis; la síntesis está propuesta en `docs/RECOGIBLES_DB.md` y en DISENO_FUTURO §7.
- **Enemigos** (`enemigos/combate_3d.gd`).
  - **Goblins:**
    - el **guerrero**, que persigue con pathfinding;
    - el **arquero**, que se mueve o se queda en su puesto;
    - el **asesino**, de ataque doble, que todavía no está en ningún nivel.
  - **Escudo del goblin:** es un componente; el fuego lo quema y entonces le quema la mano.
  - **Elemental de bosque:** es un jefe que se cura con enredaderas.
  - **Loberno:** pelea igual que un goblin.
  - **Gatopedro:** huye y no ataca.

  Todos tienen debilidad y resistencia (×2 y ×0,5) y las reacciones de A3: quemado, mojado, aturdido, congelado, empujado y hundido. DISENO_FUTURO §4 ya plantea enemigos «base + componentes»: escudo, armadura, montura.

**La idea que lo cruza todo:** este juego se diferencia de un MOBA en que lo importante es *lo que pasa al tocar algo*. El apuntado, los objetos y los enemigos deberían girar alrededor de **leer y provocar reacciones**.

---

## 1. Apuntado

### 1.1 Lanzamiento rápido con indicador (tipo LoL o Dota)
- **Mantener 1, 2 o 3** previsualiza el hechizo de esa página bajo el ratón, con la misma previsualización que ya existe; **soltar** lo lanza.
  - En los hechizos con dirección, la dirección va de la jugadora al ratón.
  - En los que nacen en un punto, el punto es el ratón, recortado al alcance.
- **Opción de «lanzamiento inteligente»:** pulsar una vez lanza directamente al ratón, sin indicador, para quien ya domina el juego.
- La **cámara lenta** se queda para cuando se compone con el libro abierto. Al disparar una página va a velocidad normal, o con una ralentización ligera que hay que medir. Quedan así dos ritmos: preparar las páginas antes del combate y dispararlas al instante durante él.
- Arrastrar para dar la dirección sigue valiendo en el modo con el libro.

### 1.2 Previsualizar la reacción (lo propio del juego)
Dentro del área del indicador se marca **qué va a reaccionar y cómo**:
- **Enemigos:** un icono con la reacción que se espera (congela, empuja, se moja), «×2» si es su debilidad y «½» si la resiste.
- **Terreno:** el agua que se hiela y hará de puente, la hierba que prende, el suelo mojado que se electrifica, la lava que se enfría.
- **Piezas:** el brasero que se enciende, el bloque que el viento va a mover, la placa que se va a pisar.

Se calcula con las mismas reglas que el impacto (`Mundo3D.reaccion`, `ReaccionesSuelo3D`) llamadas «en seco», sin aplicar nada. Esto convierte el combate en planificar combos y no en lanzar a ciegas.

### 1.3 Trayectorias y empujes
- **Rebote:** se dibuja la línea quebrada de los rebotes.
- **Viento:** una flecha fantasma enseña dónde acaba el enemigo empujado. Si acaba en el agua honda, sale el aviso de que se hunde.
- **Repetición:** las copias se ven en tono más tenue.

### 1.4 Imán suave (más adelante, pensando en el mando)
Un cono pequeño (±10°) que corrige la dirección hacia el enemigo más cercano a la línea de tiro. No fija el objetivo.

---

## 2. Que el combate no sea huir y disparar

- **Ataques avisados y esquiva con premio.**
  - Los enemigos marcan en el suelo la zona de su golpe antes de darlo, como los avisos rojos de un MOBA.
  - Una voltereta justo a tiempo, en los últimos ~0,2 s, abre ~0,6 s de cámara lenta para disparar una página, como el tiempo bruja de Bayonetta. La cámara lenta ya existe, y aquí se gana en combate.
- **Tinta por reacción.** Matar con una reacción devuelve algo de tinta: hundido, congelado y roto, combo de electricidad sobre mojado, quemado por el escudo. Premia la creatividad y castiga repetir el mismo hechizo.
- **Golpe cuerpo a cuerpo** con el libro o un bastón.
  - Gasta poca o ninguna tinta y empuja un poco.
  - Sirve para quitarse de encima a quien se acerca, romper jarrones y tumbar un escudo ya quemado.
  - Existe el clip `attack` (rol de `Pj3D`); hay que comprobar si la jugadora lo tiene.
- **Encuentros con escenario.** Cada combate tiene algo con lo que jugar: un barril, un brasero, agua, un bloque empujable, hierba. Es la regla de los puzles llevada al combate.

---

## 3. Objetos (además de las pociones)

Todos se lanzan con el **mismo indicador** que los hechizos (§1.1). Así no hay que aprender un segundo sistema de puntería.

| familia | ejemplos | qué aporta | de dónde sale |
|---|---|---|---|
| **Frascos arrojables** | aceite (se prende), agua, escarcha, chispa | dejan **estados en el suelo** que se combinan con los hechizos: aceite + fuego = charco ardiendo, frasco de agua + rayo = zona electrificada | síntesis con los ingredientes que ya hay (seta electrificada → frasco de chispa, seta helada → escarcha) |
| **Trampas** | semilla de enredadera (sujeta), seta de esporas (una nube que adormece), cepo | preparar el terreno antes del combate | recogibles de la Cueva y del Bosque |
| **Señuelos** | piedra resonante (late y atrae a los enemigos), cascabel | moverlos sin tocarlos: llevarlos al agua, separar a un arquero de su puesto | `seta_resonante` / materiales de la Cueva |
| **Herramientas permanentes** (una por mazmorra, como en Zelda) | gancho de raíz (atrae al enemigo, le quita el escudo o tira de un bloque); espejo (devuelve flechas y rayos); linterna (descubre al asesino en la hierba) | cambian el combate **y** abren puzles nuevos | cofres de mazmorra |

**Interfaz:**
- Q y una segunda tecla para dos objetos rápidos, y R para cambiar el objeto de cada una.
- Una rueda con el libro abierto para el resto. Es la parte que más tiempo lleva.
- La mochila (`bolsa_ui.gd`) ya existe.

**Encaje con la síntesis:** las etiquetas de `RECOGIBLES_DB.md` (calor, frío, agua, eléctrico, tierra, viento, resonante, vital) dicen qué frasco o trampa sale de cada ingrediente.

---

## 4. Enemigos que piden pensar

La misma regla que las salas: **cada enemigo plantea una pregunta**. Se presenta solo, después se combina con otros y con el terreno.

| enemigo | pregunta | cómo se le gana |
|---|---|---|
| **Limo elemental** | ¿con qué le doy? | absorbe el elemento que recibe y lo devuelve en su ataque. Con fuego se **divide**; con hielo se vuelve un **bloque que se puede empujar** (enlaza con `BloqueEmpujable3D`): al agua, sobre una placa, contra otro limo. **27/10 (Pablo): si recibe el MISMO elemento que ya lleva, lo absorbe y CRECE** (pequeño 0,6 → normal 1,0 → grande 1,6; más vida y más alcance de golpe, por decidir). Dividirse baja un escalón: un grande da dos normales y un normal dos pequeños. Castiga repetir el elemento sin pensar |
| **Chamán goblin** | ¿a quién ataco primero? ¿qué va a lanzar? | **27/10 (Pablo): ataca TRAZANDO UNA RUNA EN EL SUELO con el bastón.** La runa es la misma que la del libro de la jugadora (el trazo sale de las muestras grabadas de `GestureLibrary`), del color de su elemento, y **es su aviso**: se lee qué va a pasar antes de que pase. **Su conjuro (Pablo, 27/10): ᛜ barrera + ᚱ pulso = ESCUDO DE NATURALEZA (verde) para TODOS sus aliados.** Traza los dos glifos seguidos, primero ᛜ y luego ᚱ, y clava el bastón: del sello sale una onda verde, como el pulso de la Cueva, y cada goblin al que llega queda envuelto en un escudo de hojas y enredaderas. **Se le contesta:** un golpe o un viento mientras traza dejan la runa a medias y se apaga (con la primera mitad, ᛜ, ya se ve venir). El **fuego quema el escudo de naturaleza** deprisa, como el escudo de madera del goblin y las enredaderas del elemental, y el fuego sobre la runa sin acabar la borra. Si la jugadora está dentro del sello al pulsar, también le toca el escudo. Por decidir: cuánto absorbe y cuánto dura. Detrás de sus guerreros, sigue siendo «¿a quién ataco primero?» |
| **Gólem de piedra** | ¿qué uso del escenario? | las flechas no le hacen daño. Hay que derribarlo con viento sobre hielo, para que resbale, o empujarlo al agua o a la lava. Su núcleo queda al aire cuando ataca (tras el aviso, §2) |
| **Escarabajo acorazado** | ¿desde dónde? | por delante es invulnerable. Se le da la vuelta con tierra que sale debajo (barrera en el punto) o se le ataca por la espalda (señuelo, §3) |
| **Enjambre de murciélagos** (Cueva) | ¿área o precisión? | son rápidos y pequeños, y una flecha suelta falla. Hace falta un área (línea, pulso, que los aturde) o luz de fuego, que los dispersa |
| **Mago espejo** | ¿estoy repitiendo? | devuelve el último elemento que se ha usado contra él. Obliga a variar; es el antídoto al spam |
| **Espectro** | ¿cómo lo hago visible? | las flechas lo atraviesan. Solo se ve mojado o cuando le llega un pulso, y entonces el rayo sí le hace daño |
| **Goblin del terreno** (apaga braseros, hiela el agua) | ¿uso lo que me cambia? | cambia el escenario: apaga la luz o abre un camino de hielo, que también sirve a la jugadora |
| **Armaduras por componentes** (DISENO_FUTURO §4) | ¿qué atraviesa? | aguanta la tierra pero el rayo la atraviesa, o se oxida con agua y se rompe con tierra |

**Fichas en el libro:** al derrotar a un enemigo se apunta en el grimorio su debilidad y la reacción que se descubrió con él. Da ganas de experimentar y sirve de pista.

---

## 5. Orden propuesto

1. **Lanzamiento rápido y previsualización de reacciones** (§1.1, §1.2). Aprovecha la previsualización que ya existe y es lo que más cambia la sensación de juego.
2. **Ataques avisados y esquiva con premio** (§2). Da sentido a la voltereta y al quedarse a pelear.
3. **Tres enemigos: limo, chamán y gólem** (§4). Cada uno obliga a algo distinto: variar de elemento, elegir a quién atacar primero y usar el terreno.
4. **Frascos arrojables y el señuelo** (§3). Reutilizan el indicador y la base de recogibles.

## 6. Decisiones (Pablo, 27/10)

- **Ralentización al disparar una página:** sin decidir. **Valor de partida: 0,7** (ligera), en una constante para afinarlo en el playtest; la de componer con el libro sigue en 0,3.
- **Golpe cuerpo a cuerpo:** **no gasta tinta**. Es un golpe **débil que empuja mucho**.
- **Objetos:** una **rueda de 8 objetos** jugable (§3). Sustituye a las «dos ranuras rápidas».
- **Herramientas permanentes:** **sí, una por mazmorra**, como base del diseño. Cada una hace mejores ciertas formas de jugar.
- **Tinta por reacción:** **+20 de tinta** por reacción, el coste de dos flechas. Es suficiente para no ignorarlo y poco para hacer farming.

## 7. Tareas

Siguen la regla de trabajo: **Opus diseña y revisa, Sonnet programa** y Pablo decide y prueba. Cada tarea termina con su prueba headless a 0 fallos, salvo que diga otra cosa, y se apunta en `PENDIENTES.md`.

### Fase 1 · Apuntado
| # | tarea | hecho cuando | depende de |
|---|---|---|---|
| A1 **(HECHO 27/10)** | **Lanzamiento rápido:** mantener 1, 2 o 3 enseña el indicador bajo el ratón y soltar lanza. Tiempo a `TIEMPO_PAGINA` = 0,7. Esc o clic derecho cancelan. Opción «lanzamiento inteligente» (pulsar = lanzar sin indicador) en ajustes. El modo con el libro y el arrastre siguen igual | una prueba que lanza cada forma (flecha, barrera en punto, línea, rebote) desde la página sin tocar el libro; los autoplays de la Cueva, la Gruta y la sala de empuje siguen a 0. **Hecho:** `herramientas/prueba_lanzamiento_rapido.gd` (68 comprobaciones, 0 fallos, sobre PruebaBosque con teclas y ratón por `Input.parse_input_event`): mantener 1 -> modo rápido a `Engine.time_scale` 0,70 con previsualización y sin bloquear a la jugadora; soltar lanza hacia el ratón (coseno >= 0,98) y cobra la tinta al soltar; Esc y clic derecho cancelan sin cobrar y soltar después no lanza; un toque corto lanza; la barrera con el ratón a 6 casillas nace a <= `ALCANCE_ORIGEN`; con W mantenida ella anda (sin correr, rodar ni saltar) y origen y casillas la siguen cada fotograma; otra página se ignora; el modo con libro (`cast_page`) sigue a 0,3 y bloqueado. Nuevo: `Lanzador3D.pulsar_pagina/soltar_pagina` (las llama `spellbook.gd`), `Estado.lanzamiento_inteligente` (casilla en la paleta F1). `TIEMPO_PAGINA` 0,7 por afinar en el playtest de Pablo. | — |
| A2 **(HECHO 28/10)** | **Reacción «en seco»:** una función que responde a «¿qué pasaría si este hechizo tocara esto?» con las mismas reglas que el impacto, **sin aplicar nada** | una prueba compara, caso por caso, la predicción con lo que pasa al lanzar de verdad: enemigos, suelo y piezas. **Hecho:** `magia/prevision_hechizo.gd` (`class_name PrevisionHechizo`) y `herramientas/prueba_prevision_hechizo.gd` (170 comprobaciones, 0 fallos, sobre PruebaBosque, lanzando por `Lanzador3D.lanzar_ahora`). **API:** `PrevisionHechizo.prever(lanzador, datos, origen, dir) -> Array[Dictionary]` (`datos` = `Lanzador3D._preparado`; `origen` y `dir` los de `lanzar_ahora`) y `prever_rapido(...)` para llamarla cada fotograma (la misma pregunta dentro de 0,1 s sale de una caché). Cada entrada: `{que: enemigo|suelo|pieza, nodo, celda: Vector2i, reaccion, mult: 2,0 · 0,5 · 1,0, extra}`. Reacciones de enemigo: bloquea · hunde · electrocuta · congela · prende · moja · seca · apaga · aturde · empuja · ralentiza · golpe (`extra.reacciones` lleva todas, `extra.dano`, `extra.hundira`, `extra.destino` = adónde llegaría empujado, `extra.escudo`). De suelo: hiela · moja · seca · derrite · evapora · prende · arde · brota · apaga · abanica. De pieza: enciende · apaga · prende · moja · aviva · activa · brota · mueve (`extra.destino`) · agrieta · rompe · enfria (`extra.celdas`). Vacía = no reacciona con nada. **Una sola fuente de verdad:** no hay reglas nuevas, se extrajeron las decisiones a funciones que el camino real también llama: `Combate3D.decidir_golpe` (la que aplica `golpe`), `v0_de_empuje` (la de `push`), `_puede_estar_desde` (la de `_mover_paso`; con ella `prever_empuje` da el destino y si cae al agua), `Escudo3D.cubre` / `reaccion_a`, `Lanzador3D.empuje_de_golpe` (el empuje del viento que ejecuta `_golpear`) y `hechizo_de` (el `Hechizo` que lanza `_disparar`), `EstadosSuelo3D.fila_para` y `ReaccionesSuelo3D.prever` (las de `aplicar`), `PruebaTest2.prever_hierba` y `_puede_prender` (las de `_impacto_en_hierba` / `_poner_fase`), `Reactivo3D.reaccion_a` (la de `on_spell_hit`), `BloqueEmpujable3D.reaccion_a`, `MuroAgrietado3D.reaccion_a`, `Lava3D.celda_de_impacto` / `celdas_enfriables`. El recorrido (vuelo con gravedad, choques, alcance, camino del que viaja, casillas del volumen, haz) lo corre el propio `HechizoVivo` en modo `seco` (`HechizoVivo.prever`): los golpes y las marcas de suelo se anotan en vez de darse. **Coste:** ~1 ms una flecha (3 copias, ~1 ms), 0,3 ms un haz, 0,2 ms un volumen quieto (headless, 18 piezas y 6 goblins en escena); `prever_rapido` repetido: ~1 µs. **No cubre (a propósito):** los eventos del hechizo (hijos, `radio_explosion`, `al_golpear`), los pulsos periódicos de las zonas (el fuego sigue dañando un rato; el empuje del gas a los enemigos suma al del impacto: en la prueba el viento empujó 0,67 u más de lo previsto, dentro de ±0,5 casilla), los combos en cadena (la hierba que contagia el fuego a la vecina, el vapor), el electrificado del suelo mojado por el rayo, el agua que suelta un hechizo líquido en la simulación y lo que moja, los enemigos que se mueven mientras vuela el proyectil, los rebotes (se simulan con el vuelo de `HechizoVivo`, sin ruta aparte, pero sin caso de prueba propio salvo el barrido «sin cambiar nada») y el proyectil con `retorna` (solo la ida). **Detalles que A3 debe saber:** (1) el vuelo en seco usa pasos de 1/20 s (la física, 1/60) por coste; (2) la flecha de tierra y la de hielo suben en arco (impulso 2,5): a 2 casillas pasan por encima de un muro agrietado a ras (la previsión lo dice igual que la realidad: sin entrada); (3) una casilla de agua helada es sólida para el proyectil: la flecha de fuego se para antes y no la derrite (sí lo hace una barrera de fuego que nace encima); (4) `Lava3D` se enfría por el golpe de área, que pasa la posición del nodo (0,0,0) en vez de la del impacto, y por el aviso `Mundo3D.impacto` (el correcto): la previsión repite las dos; (5) un proyectil de agua no escribe «mojada» en el suelo (no marca casillas): la previsión no lo promete, y sí «apaga»/«brota» en la hierba, que la maqueta resuelve en el impacto | — |

| A3 **(HECHO 28/10, falta el visto bueno de Pablo)** | **Previsualizar la reacción** en el indicador (A1 + A2): icono por enemigo (congela, empuja, moja, ×2, ½), terreno que cambia (hiela, prende, electrifica, enfría) y piezas que reaccionan (brasero, bloque, placa) | capturas con ventana de los casos de la prueba de A2; Pablo las da por legibles. **Hecho:** `presentacion/prevision_reaccion_3d.gd` (`PrevisionReaccion3D`), que pinta cada fotograma lo que da `PrevisionHechizo.prever_rapido` con el origen y la dirección de `_soltar`; la crea `Lanzador3D._crear_marcadores` (interruptor `PREVER_REACCIONES`) y se va en `_salir_modo`. Vale para el libro y para el lanzamiento rápido. **Cómo se ve:** *enemigo*, rótulo sobre la barra de vida con la reacción principal y su multiplicador («Moja ×2» en rojo, «Prende ½»), una segunda línea si hay otra reacción («Electrocuta / Aturde») y un anillo en el suelo del color de la reacción; si lo empuja, línea y disco en su destino (azul y «¡Hunde!» si acaba en el agua). *Suelo*, un cuadro de 0,62 casillas por casilla que cambia (dentro de las cajas de 0,9 del hechizo) y un rótulo por reacción; no se repite el rótulo si un enemigo de esa casilla ya lo lleva. *Pieza*, anillo y rótulo («Enciende», «Mueve»…); el bloque lleva disco en su destino y la lava, un cuadro por casilla que enfría. Los textos y colores están en `PrevisionReaccion3D.ESTILO` (el mismo color para la misma reacción en las tres familias). Un hechizo que no se lanzaría (caja roja) no prevé nada. Sin nodos nuevos fotograma a fotograma (pozas); ~0,1 ms por fotograma con la previsión en caché. **Prueba:** `herramientas/prueba_prevision_reaccion.gd` (51 comprobaciones, 0 fallos): lo pintado es exactamente lo previsto, en cada caso de A2 (enemigo, ×2, ½, escudo, hundir, brasero, bloque, hielo al agua, nada delante), sigue al enemigo y a la puntería, y también en el lanzamiento rápido. **Fotos:** `herramientas/captura_prevision_reaccion.gd` (con ventana) → `docs/capturas/prevision_reaccion/` (9). **Para el playtest:** el tamaño de los rótulos con la cámara de juego; si «Brota» o «Prende» del suelo bajo el enemigo sobran; el rótulo del enemigo de delante puede caer sobre el de detrás en la vista isométrica (se bajó a la barra de vida por eso). | A1, A2 |
| A4 | **Trayectorias:** la línea quebrada del rebote, la flecha fantasma del empuje del viento con el aviso de hundido, y las copias de la repetición | prueba: el punto final previsto del empujado y del rebote coincide con el real (±0,5 casilla) | A1, A2 |
| A5 | Imán suave de ±10° (para el mando) | más adelante | A1 |

### Fase 2 · Combate
| # | tarea | hecho cuando | depende de |
|---|---|---|---|
| C1 | **Golpe cuerpo a cuerpo:** sin tinta, daño bajo (~5) y **empuje fuerte**, con la reacción `empujado` de A3: tira al agua y hunde. Rompe jarrones, mueve un bloque empujable una casilla y tumba un escudo ya quemado. Una tecla propia **HECHO 28/10:** tecla **F** (libre: solo la usaban laboratorios). Cono delante de ella (`_mirada`): alcance 1 casilla (2,3 u) medido hasta el borde de lo golpeado, 70° de ancho; golpe de 0,45 s (impacto a ~0,25 s, donde el clip extiende las manos), reutilización `GolpeCuerpo.CD` = 0,8 s desde que se pulsa, quieta mientras golpea, NO gasta tinta. Enemigos: daño 5 plano (sin debilidades) y empuje `GolpeCuerpo.EMPUJE` = 5000 por el `push` de siempre (medido con `prever_empuje`: 5,12 u = 2,23 casillas en suelo libre; real 4,97 u = 2,16), así que al agua honda lo hunde y da +20 por C2; le cancela el ataque en curso. Escudo ACTIVO de frente: sin daño y la mitad del empuje (medido 0,50); quemado, roto o a la espalda: lo tumba entero. Rompibles: `golpear()`. Bloque empujable: UNA casilla en la cardinal del golpe (`empujar`; el hielo resbala como con el viento). Nada más: no enciende ni moja. Gólem: `Combate3D.empujable_golpe` = false lo deja recibir el daño sin moverse (TODO: ponerlo cuando exista como enemigo). Sonido: «clavar» más grave y «dano» si toca algo; temblor `Vfx3D.temblor(0,12)`. PlayLog: `golpe_inicio`, `golpe`, `golpe_cuerpo_recibido`. **Clip: la jugadora NO tiene clip de golpe propio** (su rol `attack` se resuelve a `FacePunchReaction`, un golpe RECIBIDO): se usa su empuje con las manos, `cast_empuje` (MageSoellCast001) recortado de 0,7 a 1,8 s y acelerado ×2,4 (`Pj3D.golpear_cuerpo`); se lee como un empujón con zancada pero con poco brazo (capturas en `docs/capturas/golpe/`): el clip propio está pedido en PENDIENTES. Código: `jugador/golpe_cuerpo.gd`, `Jugador3D._iniciar_golpe_cuerpo`, `Combate3D.recibir_golpe_cuerpo`. Prueba: `herramientas/prueba_golpe_cuerpo.gd` (61 comprobaciones, por la tecla real). | prueba: el goblin empujado recorre ≥ 2 casillas y se hunde si acaba en agua honda; el jarrón se rompe; la tinta no baja | clip (§8) |
| C2 | **Tinta por reacción:** +20 por reacción contra un enemigo. **Cuentan:** hundido, congelado roto, rayo sobre mojado, quemado por su escudo, empujado contra algo y aplastado. **Tope:** una vez por enemigo y por tipo de reacción; los muñecos de prueba no cuentan. Se ve en el HUD (+20 junto a la barra) **HECHO 28/10:** lista final = hundido, electrocutado (rayo sobre mojado), congelado, mano quemada (escudo que arde) y apagado (agua o hielo a un enemigo que arde); se quedan fuera el quemado normal, el empujón suelto de viento (no hay aviso de «contra algo») y el aplastado (no existe aviso). `Tinta.premiar_reaccion`, detector `TintaReaccion`, tope por marca en el enemigo, `premia_tinta` false en dianas, «¡Hundido! +20» junto a la barra (`HudEoW`). Prueba: `herramientas/prueba_tinta_reaccion.gd`. | prueba con cada reacción de la lista, el tope y el muñeco | — |
| C3 | **Ataques avisados:** zona en el suelo antes del golpe del guerrero, el asesino, el elemental y la ráfaga del arquero de puesto. El tiempo del aviso es constante y propio de cada enemigo | prueba: el aviso sale ≥ 0,4 s antes del impacto y cubre las casillas que daña | — |
| C4 | **Esquiva con premio:** una voltereta en los últimos ~0,2 s del aviso abre 0,6 s de cámara lenta (tiempo bruja), en la que se puede disparar una página | prueba: voltereta a tiempo → cámara lenta; a destiempo → nada | C3, A1 |

### Fase 3 · Enemigos (cada uno con su sala de laboratorio, su autoplay y sus `[legible]`)
| # | tarea | hecho cuando | depende de |
|---|---|---|---|
| E1 | **Limo elemental:** absorbe el elemento que recibe y lo usa en su ataque. Con fuego se divide en dos más pequeños; con hielo se vuelve un **bloque empujable** durante un rato (al agua: muere) | autoplay que lo derrota de tres maneras y comprueba que el elemento absorbido cambia su ataque | modelo (§8) |
| E2 | **Chamán goblin:** detrás de sus guerreros, **traza una runa en el suelo** con el bastón (≈1,5–2 s, con el trazo de `GestureLibrary`, en un sello de ~2 casillas y del color del elemento). La runa es **ᛜ + ᚱ** (≈2,5 s, en dos mitades). Al clavarla sale una onda verde que pone un **escudo de naturaleza** a cada aliado al que llega (absorbe daño; valor por decidir). El fuego quema el escudo deprisa y borra la runa sin acabar. Un golpe o un viento mientras traza la apagan. La jugadora dentro del sello también recibe el escudo | autoplay: lee la runa a medias (`runa_en_curso`), la interrumpe y no pasa nada; la deja acabar y pasa; matándolo primero no hay protección | modelo y clip `trazar` (§8) |
| E3 | **Gólem de piedra:** las flechas no le hacen daño. Se le derriba con viento sobre hielo, para que resbale, o empujándolo al agua o a la lava. Su núcleo queda al aire tras su ataque avisado (C3) | autoplay: dos formas de vencerlo; la flecha directa no hace daño | C3, modelo (§8) |
| E4 | Resto de §4 (escarabajo, murciélagos, mago espejo, espectro, goblin del terreno, armaduras) | se diseñan cuando E1–E3 estén probados | E1–E3 |

### Fase 4 · Objetos
| # | tarea | hecho cuando | depende de |
|---|---|---|---|
| O1 | **Rueda de 8 objetos:** se abre manteniendo una tecla, con el tiempo lento como el libro. Ratón o teclas 1–8 eligen y Q usa el elegido. Los 4 consumibles de hoy entran en ella | prueba de la rueda: elegir, usar, gastarse, objeto vacío | iconos (§8) |
| O2 | **Frascos arrojables:** aceite (estado de suelo nuevo, inflamable), agua, escarcha y chispa. Se lanzan con el indicador de A1 | prueba: cada frasco deja su estado y se combina (aceite + fuego, agua + rayo, escarcha sobre agua) | A1, O1 |
| O3 | **Señuelo:** la piedra resonante late y atrae a los enemigos durante X s | prueba: un goblin deja su ruta y va al señuelo | O1 |
| O4 | **Trampas:** enredadera que sujeta, esporas que adormecen y cepo | prueba de cada una | O1 |
| O5 | **Síntesis de los frascos y las trampas** desde la base de recogibles | cuando Pablo valide `RECOGIBLES_DB.md` §6 | O2–O4 |

### Fase 5 · Herramientas permanentes
| # | tarea | hecho cuando | depende de |
|---|---|---|---|
| H1 | Elegir la primera herramienta y su mazmorra. Propuesta de Opus: el **gancho de raíz** (atrae al enemigo, le quita el escudo y tira de un bloque) | Pablo elige | — |
| H2 | Construirla con su sala de presentación (como la sala de empuje) | autoplay | H1 |

**Orden:** A1 → A2 → A3 en paralelo con C1 y C2 → C3 → C4 → E1–E3 → O1 → O2–O4 → A4 → H1. C1 y C2 son pequeñas y se pueden adelantar.

## 8. Lo que hace falta de Pablo

- **Decidir:**
  - la tecla del golpe (propuesta: **F**);
  - la tecla de la rueda (propuesta: **Tab** mantenida);
  - si la «barrera ancha» y otros detalles del indicador te parecen bien al ver las capturas de A3.
- **Arte (Meshy):**
  - **modelos** del limo, el chamán goblin (puede ser el goblin base con bastón y máscara) y el gólem de piedra;
  - **iconos** de los objetos de la rueda: los 4 de hoy, 4 frascos, el señuelo y 3 trampas;
  - si la jugadora no tiene un clip de golpe (se comprueba en C1), un **clip de golpe con el libro o el bastón**, corto y con empuje.

  Opus puede escribir los prompts en `arte/meshy/PROMPTS_*.md`, como los anteriores.
- **Sonido:** golpe, el aviso de cada enemigo, el limo, el gólem y el frasco que se rompe. Puede ser de OpenGameArt CC0, como los del 27/10.
- **Playtests:**
  - al acabar la fase 1, cómo se siente apuntar y el valor de `TIEMPO_PAGINA`;
  - al acabar la fase 2, el golpe y la esquiva;
  - al acabar cada enemigo.
- **Validar** la base de recogibles (`RECOGIBLES_DB.md` §6) antes de O5.
