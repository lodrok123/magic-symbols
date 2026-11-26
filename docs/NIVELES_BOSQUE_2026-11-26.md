# Niveles de bosque de la sección jugable: BosqueGen01 → BosqueGen02 → BosqueCabana (26/11/2026)

Encargo de Pablo: «hacer al menos 3 niveles medio grandes de bosque para las siguientes escenas: 01, 02 y cabaña del guardabosques, con el objetivo de preparar una sección jugable. El flujo será primero generar una aproximación con el generador y retocar a mano; los niveles actuales [Bosque_01, Bosque_02] son POC».

Esto es la **primera aproximación**: tres mapas hechos con el generador de mapas (algoritmo «bosque»), enlazados entre sí y jugables de principio a fin, para que Pablo los retoque a mano en el generador o en el editor. No se ha tocado ningún nivel existente ni `NIVEL_INICIAL`.

## 1. Resumen

| | **BosqueGen01** · El umbral del bosque | **BosqueGen02** · El bosque profundo | **BosqueCabana** · La senda del guardabosques |
|---|---|---|---|
| Papel | Entrada del bosque, tutorial: amable | Bosque profundo: grande, bucles, río, campamento | Claro grande y seguro con la cabaña; premios y algún encuentro |
| Tamaño | 72 × 60 | 90 × 68 | 84 × 68 |
| Semilla | 1 | 1 | 1 |
| Claros | 9 (entrada, salida, 5 con puzle, 1 de goblins, 1 del tesoro) | 12 (entrada, salida, 7 con puzle, campamento, 2 de goblins) | 10 (entrada, cabaña, 6 con puzle, 2 de goblins) |
| Puzles | 5 | 7 | 6 |
| Enemigos | 6 goblins guerreros (en 2 claros) | 6 guerreros + 3 arqueros (en 3 claros, uno es el campamento) | 4 guerreros + 2 arqueros (en 2 claros; la cabaña, sin ninguno) |
| Cofres | 6 | 7 (uno épico, el del campamento) | 5 |
| Jarrones | 12 | 12 | 9 |
| Río | norte–sur, con vados | norte–sur, con vados (4 cruces) | este–oeste, con vados; pasa justo al norte de la cabaña |
| Kit de la jugadora | `demo_inicio` (fuego, flecha, barrera) | `demo` (fuego, agua, tierra + flecha, línea, barrera, altura, raido, suelo) | `demo` |
| Paso de tierra | no | sí: precipicio de 6 casillas en el camino de la salida a la cabaña | no |
| Escena | `escenas/PruebaBosqueGen01.tscn` | `escenas/PruebaBosqueGen02.tscn` | `escenas/PruebaBosqueCabana.tscn` |
| Mapa | `mundo/datos_nivel/mapas/BosqueGen01.txt` | `…/BosqueGen02.txt` | `…/BosqueCabana.txt` |

Capturas: `docs/capturas/niveles_bosque_2026-11-26/` (la vista cenital de cada mapa, y fotos con la cámara del juego: entrada, un claro con puzle, el río, el campamento, la salida y la cabaña).

## 2. Enlaces entre niveles

```
 MonteSumicio ──desde_fraga──┐
                             ▼ (entrada «desde_sumicio»)
                        BosqueGen01 ── a_salida_2 ─────────────► BosqueGen02:desde_01
                             ▲ (entrada «desde_02»)                    │ (entrada «desde_01», en su inicio)
                             └──────────────── a_salida_1 ◄────────────┤
                                                                       │ a_salida_2 ─► BosqueCabana:desde_02
                        BosqueGen02 (entrada «desde_cabana») ◄─ a_salida_1 ── BosqueCabana (entrada «desde_02», en su inicio)
```

| Nivel | Salida | Destino (`Nivel:entrada`) | Dónde está | Llegada propia |
|---|---|---|---|---|
| BosqueGen01 | `a_salida_1` | `MonteSumicio:desde_fraga` | claro de entrada, borde sur | `desde_sumicio` (la `S`) |
| BosqueGen01 | `a_salida_2` | `BosqueGen02:desde_01` | claro de la esquina NE, borde norte | `desde_02` |
| BosqueGen02 | `a_salida_1` | `BosqueGen01:desde_02` | claro de entrada, borde sur | `desde_01` (la `S`) |
| BosqueGen02 | `a_salida_2` | `BosqueCabana:desde_02` | claro de la esquina NO, tras el precipicio | `desde_cabana` |
| BosqueCabana | `a_salida_1` | `BosqueGen02:desde_cabana` | claro de entrada, borde sur | `desde_02` (la `S`) |

* Las tres filas nuevas están en `nucleo/niveles.gd` (`Niveles.ESCENAS`): `BosqueGen01`, `BosqueGen02`, `BosqueCabana`. Es el único cambio en esa tabla; los enlaces de los niveles existentes no se han tocado.
* **La salida de BosqueGen01 hacia atrás va a `MonteSumicio:desde_fraga`** (la llegada que ya usa Bosque_02 en su sendero norte). Para que Monte Sumicio lleve a BosqueGen01 habría que repuntar su salida `a_fraga`, que no he tocado.
* **Para que «Nueva partida» empiece en BosqueGen01**: en `nucleo/niveles.gd`, línea 32, `const NIVEL_INICIAL: String = "Bosque_02"` → `"BosqueGen01"`. (No se ha cambiado.) La partida entra por la `S` (la entrada `desde_sumicio`).

## 3. Cómo se generan y cómo se regeneran

`herramientas/generar_niveles_bosque.gd` (headless) lleva en una **tabla al principio** (`NIVELES`, y `BASE` para lo común) los parámetros del generador de cada nivel, la semilla por la que buscar y la lista de puzles del catálogo, en orden de cercanía a la entrada. Busca una semilla en la que quepa todo sin errores ni avisos que no estén permitidos, exporta (`mapas/<Nombre>.txt` + `escenas/Prueba<Nombre>.tscn`, con el exportador del botón «Exportar») y carga cada escena para comprobar lo básico.

```
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 30 --path E:\magic-symbols --script res://herramientas/generar_niveles_bosque.gd
   -- nivel=BosqueGen02     solo ese nivel
   -- sin_cargar            solo genera y exporta (más rápido: ~10 s por nivel)
   -- buscar                ignora la semilla fija y vuelve a buscar desde `semilla_ini`
```

La semilla de cada nivel está fijada a 1 (la primera en que cabe todo). Para cambiar un nivel, se cambia su fila de `NIVELES` (parámetros, `puzles`, `semilla`) y se vuelve a ejecutar. **Regenerar pisa los retoques que se hayan hecho a mano en el .txt**: el exportador guarda antes una copia `<Nombre>_copia_<fecha>.txt` si el archivo no es exactamente lo que sale de sus parámetros. Por eso, una vez que Pablo empiece a retocar, lo que se retoque en el generador (pestañas Puzles, Enemigos, Cofres, mover, pintar…) queda en el propio `.txt` (`; retoques`, `; movidos`, `; anadidos`, `; puzles`…) y **sobrevive a «Exportar»**; lo que no conviene es volver a ejecutar la herramienta.

Los tres mapas se regeneran idénticos desde su propio `.txt` (`; generador {…}`): `prueba_niveles_bosque.gd` lo comprueba (el rótulo de cada claro, el nombre de las zonas y la cabaña salen también del generador, no son líneas puestas a mano).

### Abrir cada nivel (jugar)

```
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaBosqueGen01.tscn
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaBosqueGen02.tscn
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://escenas/PruebaBosqueCabana.tscn
```

Entrando en BosqueGen01 se llega **andando** a la cabaña (01 → 02 → cabaña) sin abrir escenas a mano; la vuelta también funciona.

### Abrir cada nivel (retocar en el generador)

```
E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols res://herramientas/generador_mapas/GeneradorMapas.tscn
```
y «Abrir mapa generado» → `BosqueGen01`, `BosqueGen02` o `BosqueCabana`. (Las casillas nuevas del panel —cabaña, centro de la cabaña, rótulos por claro, títulos de claros— están en la sección MAPA con el algoritmo «bosque».)

## 4. Los puzles

18 plantillas distintas del catálogo, **ninguna repetida entre niveles**, de dificultad creciente. Se han repartido a mano (en `NIVELES`), uno por claro y en orden desde la entrada. `solo_aceptados = false`: solo 4 de las 18 están «aceptado»; las demás están **pendientes de que Pablo las juegue** (y una, `escondite_muro`, tiene el estado «pendiente» en su .txt como el resto). Todos los claros con puzle llevan rótulo con su título al entrar.

### BosqueGen01 (fuego y empujar, un paso; kit `demo_inicio`)

| Orden | Claro | Puzle (id) | Sellos | Estado |
|---|---|---|---|---|
| 1 | 5 | Tres braseros y un cofre (`braseros_premio`) | fuego + flecha | **aceptado** |
| 2 | 7 | Peso de la piedra (cofre) (`piedra_premio`) | empujar | pendiente |
| 3 | 2 | Voladura: barril contra el muro (`barril_muro`) | fuego + flecha | **aceptado** |
| 4 | 3 | Dos braseros que abren (`braseros_puerta`) · activador: lleva enlazado un cofre común que aparece al encenderlos | fuego + flecha | **aceptado** |
| 5 | 6 | Contrafuego: setos y barril (`contrafuego`) | fuego + flecha | **aceptado** |

### BosqueGen02 (agua y tierra, y dos sellos; kit `demo`)

| Orden | Claro | Puzle (id) | Sellos | Estado |
|---|---|---|---|---|
| 1 | 9 | Riega la placa (`riega_pulsador`) · activador: cofre común enlazado | agua + flecha | pendiente |
| 2 | 6 | Escudo de tierra contra las flechas (`escudo_flechas`) | tierra + barrera | pendiente |
| 3 | 11 | El puente de zarcillos (`puente_raices`) | agua + flecha | pendiente |
| 4 | 8 | La placa de la isla (`placa_isla`) | tierra + barrera | pendiente |
| 5 | 5 | Dos riegos a la vez (`dos_riegos`) | agua + línea | pendiente |
| 6 | 10 | El pasillo de las setas de veneno (`setas_veneno`) | fuego o agua + flecha | pendiente |
| 7 | 4 | Choque térmico: la roca al rojo (`choque_termico`) | fuego + agua + flecha | pendiente |

Más el **campamento goblin** (claro 7: empalizada con puerta que arde, fogata, torre, tienda, estandarte, 2 guardias, vigía y un cofre épico al limpiarlo).

### BosqueCabana (premios, los más difíciles; kit `demo`)

| Orden | Claro | Puzle (id) | Sellos | Estado |
|---|---|---|---|---|
| 1 | 5 | Braseros en orden y mural de barro (`braseros_orden`) | fuego + agua + flecha | pendiente |
| 2 | 6 | Escondite tras el muro agrietado (`escondite_muro`) | tierra + flecha | pendiente |
| 3 | 4 | El cofre que viene a ti (`cofre_balsa`) | agua o fuego + flecha | pendiente |
| 4 | 9 | El brasero tras el chorro (`dragon_brasero`) | fuego + flecha | pendiente |
| 5 | 3 | El puente y el aliviadero (`puente_aliviadero`) | fuego + flecha | pendiente |
| 6 | 2 | Tres estatuas: fuego, agua, tierra (ᚱ) (`estatuas_sellos`) | fuego + agua + tierra + raido + flecha | pendiente |

### Qué se ha dejado fuera, y por qué

Se han usado solo plantillas que se resuelven con fuego, agua y tierra y los glifos de la demo (flecha, línea, barrera, altura, raido, suelo), y que tienen sentido en un bosque. Fuera:

* **Hielo** (`charca_helada`) y las que dependen de hielo en el sentido del juego (`hielo_pista`, `molino_hielo`: aunque se resuelve con fuego, su aspecto es una compuerta helada): no hay hielo en la demo ni en un bosque templado.
* **Vagonetas y raíles** (`vagoneta_pista`, `vagoneta_curva`, `vagoneta_boton`, `vagoneta_aguja`): son de mina, desentonan en un bosque.
* **Cristales y prismas de pulso** (`cristal_receptor`, `prisma_rojo_azul`, `pared_hueca_nicho`, `veta_dos_caminos`, `geoda_columna`): su estética es de cueva (cristal resonante, geoda, vetas); piden además el glifo raido en casi todas, que en la demo no tiene fuente.
* **Lava** (`rio_lava`, `lava_roca_peso`): no hay lava en un bosque.
* Los que Pablo dejó en «ajustes» (`balanza_rocas`, `presa_barril`) para no meter en un nivel jugable algo que él ya pidió cambiar. (`balanza_rocas` estaba en una versión anterior de la cabaña y se cambió por `escondite_muro`.)
* Válidas y de bosque pero sin usar, por no quedar claros (quedan para ampliar o sustituir): `rele_braseros`, `piedra_pista`, `puente_cuerda`, `molino_paso_bajo`, `retener_cuenca`, `dragon_seto_cofre`, `gotera_brasero`.

### Kits y progresión

* BosqueGen01 usa el kit `demo_inicio` (fuego, flecha, barrera): es el de Bosque_02 y el arranque de la demo. Todos sus puzles se resuelven con fuego o empujando.
* BosqueGen02 y BosqueCabana usan el kit **`demo`** (fuego, agua, tierra y todos los glifos de la demo): sin él, sus puzles de agua y tierra no se podrían resolver. No he inventado ningún kit. **Hoy no hay ningún cofre del juego que dé el sello de agua ni el de tierra** (en Bosque_02 tampoco; el agua viene de Marimanta en Monte Sumicio): al pasar de 01 a 02 la jugadora gana de golpe los dos sellos. Retoque recomendado: poner a mano, al final de 01, un cofre con `sello=agua` (y otro con `sello=tierra` en el 02) y dejar el kit del 02 en `demo_inicio` (el generador solo filtra los puzles por el kit; en `NIVELES` bastaría con `runas`).

## 5. La cabaña del guardabosques

El generador no sabía colocar una estructura así. **Cambio mínimo** (documentado en `generador_mazmorra.gd`, sección «La cabaña del guardabosques y los rótulos de los claros»): dos parámetros nuevos del algoritmo «bosque».

* `cabana` = el modelo de casa (`prov_house_02`; la tabla `Generador.CABANAS` dice la huella de cada una y su atrezo). `""` = sin cabaña.
* `cabana_en` = `"x,y"` para fijar el centro de la casa; vacío = el claro más grande sin papel, algo al norte de su centro.

Qué hace al levantarla (`_poner_cabana`, antes de repartir enemigos y jarrones):

1. **Reserva el claro** (rol «cabana»): no lleva enemigos, jarrones ni braseros. Es zona segura y tiene su rótulo («La cabaña del guardabosques»).
2. **Casa**: la pieza `prov_house_02` del pack Fantasy Provencal (`arte/piezas/prov_house_02.tscn`, casa de planta rectangular con tejado de teja, la puerta mira al sur, a la cámara) como `; pieza cabana_casa decorado x y modelo=prov_house_02`. Ya trae su colisión y el metadato `bloquea`, así que el juego bloquea **las 9 casillas (3 × 3) de su huella** igual que las casas de Monte Sumicio; el generador las marca como bloqueadas (`_ocupar(c, true)`) y comprueba que **no parten el mapa** ni lo dejan sin solución (si no, prueba otro sitio). Se exige alrededor un patio libre (un anillo a los lados y detrás y cuatro filas delante) sin agua, vados ni precipicio.
3. **Atrezo** (17 piezas `decorado` sin mecánica, las que no caben se saltan): leña (`tronco_sin_resina`, `tocon_alto`), dos barriles y una caja a un lado, una carreta, un banco y un taburete junto a la puerta, un cartel en el camino, una tinaja, y a un lado un huerto de flores con valla y arbustos (`prov_*`). Las que tienen colisión (barriles, caja, carreta, leña, tocón) bloquean su casilla; la valla, las flores, el banco y la tinaja son de adorno.
4. **La guardabosques**, delante de la puerta a un lado, es la **letra `m`** del plano (la misma que en Bosque_02: la maqueta crea el NPC, su gato y bloquea la casilla). Como un nivel generado no lleva guion, el exportador añade a la escena un nodo `GuardabosquesCabana` (`escenas/guardabosques_cabana_3d.gd`, nuevo, ~150 líneas): se vuelve hacia ti, te saluda al acercarte (una vez, flag `bosquecabana.guardabosques.saludo`) y habla con la tecla de interactuar (E) con cinco frases de pista. No da nada ni vende.
5. Tierra pisada (`g`) delante de la puerta.

Exterior solamente: sin interior. **Sobrevive a regenerar y a los retoques**: son parámetros de `; generador {…}` del `.txt`, no líneas sueltas; el atrezo y la casa salen de ellos. Si Pablo mueve algo con el pincel «mover», eso queda en `; movidos` (las piezas de la cabaña no son movibles: se mueve la casa con `cabana_en`).

Dónde está: BosqueCabana, claro 8 (rect 3,28 – 15,41), casa centrada en (9, 34), guardabosques en (10, 37). El claro tiene el río pegado al norte y el camino de tierra que sube desde la entrada pasa por el lado este.

Escala y aspecto (mirados en las capturas `BosqueCabana_cabana_*`): la puerta de la casa mide ~1,5 veces la altura de la jugadora; apoyada en el suelo; la fachada mira a la cámara; ningún árbol la atraviesa (el patio exige suelo libre y la huella está en pleno claro). **Es una casa de pueblo provenzal (muros de yeso blanco y teja naranja), no una cabaña de madera**: es lo que mejor leía de lo que hay; si Pablo prefiere algo más rústico, está la casa montada de SH (`arte/sh_assets/casa_sh_d50.glb`) o `prov_watermill_house` / `prov_house_barn`, y bastaría con una fila nueva en `Generador.CABANAS` (huella y atrezo) y cambiar `cabana` en `NIVELES`.

## 6. Cambios de código

| Archivo | Qué y por qué |
|---|---|
| `herramientas/generar_niveles_bosque.gd` | Nuevo. La herramienta reproducible (tabla `NIVELES`). |
| `herramientas/generador_mapas/generador_mazmorra.gd` | Parámetros `cabana`, `cabana_en`, `rotulos_claros`, `titulos_claros`; `CABANAS`, `_poner_cabana`, `_cabana_en` y `_rotulos_de_claros` (sección nueva); `_poblar` los llama; el claro de la cabaña queda sin enemigos, jarrones ni braseros; `_resultado` devuelve `cabana`. Sin esos parámetros (valores por defecto) el generador sale igual que antes (las pruebas del generador lo comprueban). |
| `herramientas/generador_mapas/exportador_mapa.gd` | Si hay cabaña, añade a la escena el nodo `GuardabosquesCabana`. `titulo_nivel` (opcional) = el rótulo de la zona del mapa entero en vez del nombre del nivel. |
| `herramientas/generador_mapas/generador_mapas_ui.gd` | Un icono para los objetos «cabana» y cuatro campos en el panel (cabaña, centro de la cabaña, rótulos por claro, títulos de claros). |
| `escenas/guardabosques_cabana_3d.gd` | Nuevo: la guardabosques de la cabaña (saludo y frases). |
| `nucleo/niveles.gd` | Tres filas en `ESCENAS` (los tres niveles). |
| `herramientas/prueba_niveles_bosque.gd`, `captura_niveles_bosque.gd`, `medir_niveles_bosque.gd` | Nuevos: el recorrido, las capturas y la medida de rendimiento. |

No se ha tocado `presentacion/prueba_test2.gd` ni `escenas/puzle.gd`: la cabaña se monta con piezas `decorado` y la letra `m` que ya existían.

## 7. Verificación

(Resultados literales al final de este documento, sección 9.)

* **Generador**: los tres mapas se generan sin `errores`; el único aviso que sale es «El cofre que ponías en (x, y) ha quedado en (x, y−1)»: los puzles de tipo «salida» (`braseros_puerta` en 01, `riega_pulsador` en 02) no tienen premio propio y la herramienta les enlaza un cofre común que se pide encima de su activador; el generador lo deja en la casilla libre más cercana (la de al lado). Es lo mismo que hacen los niveles Pt. Cualquier otro aviso hace que la herramienta descarte la semilla. El validador de solubilidad (`_resoluble`) pasa: la herramienta solo exporta si no hay errores.
* **Carga** (`prueba_niveles_bosque.gd`): cada nivel carga; `Puzle3D` y `Zonas3D` no dan avisos; cada `; pieza` existe como nodo (salvo `cuenca` y `manantial`, que son solo datos); hay un enemigo montado por cada `W`/`A` del plano; el suelo es suelo, las paredes bloquean, el agua es agua; el precipicio es vacío.
* **Recorrido a pie**: con las teclas de verdad (la jugadora se mueve como el jugador), por el ruteo de casillas que usa el juego, hasta cada claro y cada salida. El precipicio de 02 se cruza con el **puente de tierra de verdad** (hechizo tierra + barrera + 2 líneas, la receta de la prueba de LC3). Los enemigos se apartan y la vida se mantiene alta (el recorrido prueba el mapa, no el combate; el centro de los claros de trampas —chorro del dragón, flechas— es línea de tiro, así que a esos claros se llega por su entrada).
* **Viajes**: 01 → 02 → cabaña → 02 → 01 con fundido real, escena nueva y llegada en la entrada con nombre; las partidas del recorrido se guardan en una carpeta de prueba (no se toca `user://partidas/`).
* **Capturas**: mirada cada una; véase `docs/capturas/niveles_bosque_2026-11-26/`.

## 8. Densidades frente a Echoes of Wisdom

| | EoW (referencia) | 01 | 02 | Cabaña |
|---|---|---|---|---|
| Claros | — | 9 | 12 | 10 |
| Puzles por claro (≈ 1) | ≈ 1 | 0,56 | 0,58 | 0,60 |
| Enemigos por claro (0,6–0,75, concentrados en pocos claros) | 0,6–0,75 | 0,67 en 2 de 9 | 0,75 en 3 de 12 (con el campamento) | 0,60 en 2 de 10 |
| Cofres (uno cada 2–3 claros = 0,33–0,5) | 0,33–0,5 | 0,67 | 0,58 | 0,50 |
| Rompibles o empujables por claro (≈ 2) | ≈ 2 | 1,3 jarrones + 1 bloque + 2 barriles | 1,0 | 0,9 |

Los enemigos y los cofres están en la referencia (los cofres algo por encima en el 01: es el tutorial y premia). Los **puzles quedan en ~0,6 por claro** y los **rompibles en ~1** porque en un mapa de 9–12 claros la entrada, la salida, el campamento o la cabaña y al menos un claro de goblins ya ocupan 4 o 5 claros, y los claros con puzle, campamento o cabaña no llevan jarrones. Para llegar a 1 puzle por claro harían falta más claros (14 o más: se sale de 70–90 × 60–70) o quitar un claro de goblins. Con la hierba y los jarrones del generador (`jarrones` = 3 por claro libre) no se llega a 2 por claro; si se quiere, se añaden a mano.

## 9. Resultados de las pruebas (27/11/2026)

Todo con `godot --headless --fixed-fps 30 --path . --script res://herramientas/<prueba>.gd` (salvo lo marcado «con ventana»):

| Prueba | Resultado |
|---|---|
| `generar_niveles_bosque` (los tres niveles, cargando cada escena) | `FALLOS: 0` por nivel |
| `prueba_niveles_bosque` (cadena 01 → 02 → cabaña → 02 → 01, andando de verdad, puente de tierra incluido, ~30 min) | `FALLOS: 0` (112 comprobaciones `OK`, ninguna `FALLO`, ningún `AVISO`) |
| `prueba_generador_mapas` | `114150 comprobaciones en 500648 ms` · `FALLOS: 0` |
| `escenario_generador_mapas` (`-- salas` y `-- bosque`) | `FALLOS: 0` y `FALLOS: 0` |
| `escenario_catalogo_nuevos` | `FALLOS: 0` |
| `prueba_tabla_decorado` | `FALLOS: 0` |
| `prueba_riqueza_suelo` | `FALLOS: 0` |

**Consola**: los tres niveles cargan sin `SCRIPT ERROR` y sin avisos de `Puzle3D` ni de `Zonas3D`. Lo único que sale, y no es de estos niveles: (1) `WARNING: Pj3D[ranger_human]: falta el clip 'walk' de un npc` al montar a la guardabosques (sale igual en Bosque_02, mismo modelo); (2) al CERRAR la escena de la cabaña, cuatro líneas `Parameter "material" is null` del servidor de render (es de la limpieza al salir: no hay ningún material nulo en las piezas de la cabaña, comprobado, y no salen al cargar); (3) las líneas de recursos sin liberar al salir, que salen en todas las pruebas con ventana. Nota: en una pasada anterior de esta misma prueba (22:5x del 26/11) la maqueta llevaba en `_avisos` unos «sin pieza» de adornos del decorado de claros (`musgo_suelo`, `seta_pradera`, `margarita_*`…); en la pasada final ya no salen (alguien ha tocado las tablas de decorado entre una y otra; no son de estos niveles ni los he tocado). La prueba los anota como `AVISO`, no como fallo.

**Rendimiento** (con ventana, 1600 × 900, sin vsync, RTX 3070, cámara quieta; `medir_niveles_bosque.gd`; una medición por lugar, sin repetir):

| Nivel · lugar | Llamadas de dibujo | Objetos | Primitivas | fps |
|---|---|---|---|---|
| BosqueGen01 · entrada | 417 | 2663 | 1,32 M | 172 |
| BosqueGen01 · primer puzle | 424 | 2684 | 1,30 M | 162 |
| **BosqueGen02 (el más grande, 90 × 68)** · entrada | 436 | 2609 | 1,96 M | 95 |
| BosqueGen02 · campamento | 416 | 2597 | 1,77 M | 80 |
| BosqueGen02 · primer puzle | 476 | 2671 | 1,73 M | 91 |
| BosqueCabana · entrada | 555 | 2712 | 2,30 M | 37 |
| BosqueCabana · junto a la cabaña | 571 | 2795 | 2,80 M | 36 |
| BosqueCabana · un puzle | 398 | 2548 | 1,67 M | 56 |
| *Bosque_02 (hecho a mano, referencia)* · entrada | 494 | 3039 | 3,01 M | 92 |

BosqueGen01 y 02 van igual o mejor que el Bosque_02 hecho a mano. **BosqueCabana es el más lento (36–56 fps) aunque dibuja menos primitivas que Bosque_02**: la causa más probable (no la he medido con el perfilador) es la simulación de agua que arrastran sus puzles (`cofre_balsa`, `puente_aliviadero`, `braseros_orden` y `escondite_muro` llevan cuencas y manantiales) o el zoom de cámara más abierto de sus claros de radio 6. Si molesta, bajar `tamano_claro` a 5 o cambiar un puzle de agua por otro. Tiempo de carga de la escena: 10–13 s (el mismo orden que Bosque_02: 15 s).

## 10. Lo que conviene retocar a mano

1. **Progresión de sellos** (§4): el 02 y la cabaña dan agua y tierra por el kit; poner los cofres que los dan.
2. **Puzles pendientes**: jugarlos y marcarlos (`; validacion`), sobre todo `piedra_premio` (01) y los 7 del 02, que enseñan agua y tierra casi sin tutorial. Ajustar su colocación (se pueden mover de claro en la pestaña Puzles).
3. **Los claros sin papel** (los de goblins) son de relleno: darles forma (cofres escondidos, una emboscada, un gatopedro de tutorial…).
4. **La cabaña**: la casa es provenzal (ver §5), el atrezo es una primera pasada (sin farol: no he encontrado una pieza de farol exenta que sirva), y la guardabosques solo da pistas genéricas: darle diálogo propio, una misión o su tienda.
5. **El río de 02**: tiene cuatro vados y la salida queda tras un precipicio, pero ningún puente que haya que tender (el tipo de barrera `puente` está desactivado en 01 y 02: `barreras = 0`). Subir `barreras` en 02 pone puerta/puente con su activador si Pablo quiere más cerrojo.
6. **Los rótulos** son los títulos de las plantillas y unos cuantos nombres puestos en `titulos_claros`; pulirlos.
7. **Enlaces con Monte Sumicio**: repuntar `a_fraga` de Sumicio (o el sendero de Bosque_02) a `BosqueGen01:desde_sumicio` cuando 01 sustituya al POC.
8. **Mapa / cartografía**: Bosque_02 llama a `Cartografia.preparar_desde_mapa`; los niveles generados no lo hacen (no lo he comprobado).
9. **Dificultad**: no se ha jugado a mano ningún combate ni puzle de estos niveles.
