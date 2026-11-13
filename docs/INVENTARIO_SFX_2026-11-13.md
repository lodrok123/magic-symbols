# Inventario de SFX — 13/11/2026

Qué suena en el juego, de dónde sale cada sonido, qué se ha cambiado hoy y qué sigue mudo.
Catálogos: `nucleo/sfx.gd` (`Sfx.CATALOGO`) y `nucleo/sfx_3d.gd` (`Sfx3D.CATALOGO` y `AMBIENTES`).

**Cómo se eligieron los sonidos nuevos.** Del lote GDC 2026 de Sonniss (347 pistas), por el nombre de la pista y por su forma de onda (dónde cae el golpe, cuánto dura). **No se han escuchado**: se validan en `docs/escucha_sonniss.html` (antes y después de cada uno). Todos entran por la clave `f_sn`, así que:

- con `Sfx.SONNISS = false` (fila S:SONNISS del panel F3) vuelve a sonar lo de antes, para comparar;
- quitar uno que no guste es borrar su `"f_sn": [...]` de la entrada;
- el volumen se iguala al del archivo sustituido, y los dB del catálogo no se han tocado.

## 1. Errores encontrados: sonidos que se pedían y no sonaban

| Qué | Por qué no sonaba | Arreglo |
|---|---|---|
| Mazazo del gólem (`golem_3d.gd:770`) y muerte del gólem | pedían `derrumbe` por `Sfx3D.play`, y solo existía en `Sfx` | `derrumbe` añadido a `Sfx3D.CATALOGO` |
| «Piedra» del gólem y runa del ritual del chamán | lo mismo con `escudo_golpe` | añadido a `Sfx3D.CATALOGO` |
| «Ding» de la esquiva perfecta (`jugador_3d.gd:1340`) | lo mismo con `sello_ok` | añadido a `Sfx3D.CATALOGO` |
| Carga y disparo de **magma** y **naturaleza** | el Lanzador pide `magma_carga`/`magma` y no existía ninguno | `magma` (fuego grave de Sonniss) y `naturaleza` (toma el de tierra: **no tiene sonido propio**) |
| Los 7 sonidos de `PiezaPuzle3D` | la clase no se instancia en ningún sitio | sin arreglar: es código muerto (ver §4) |

## 2. Sintetizados por código que pasan a grabados (27)

| Entrada | Dónde suena | Antes | Ahora (pista de Sonniss) |
|---|---|---|---|
| `viento` | lanzar viento | sintetizado | Wind, Rush, Whoosh |
| `rayo_carga` | empezar un conjuro de rayo | sintetizado | Arc Power Up |
| `siseo_apagado` | fuego apagado con agua | sintetizado | hoguera apagada con agua (grabación real) |
| `zumbido_electrico` | reacción eléctrica | sintetizado | Arc Buzz |
| `chispazo` | muerte por rayo | sintetizado | Arc Design |
| `hielo_rompe` | muerte por hielo | sintetizado | Skill Freeze Break Shatter |
| `salpicadura` | muerte por agua | sintetizado | Water Liquid Impact |
| `escudo_golpe` | escudo o bálsamo que para un golpe | sintetizado | golpe metálico seco |
| `escudo_roto` | escudo o burbuja que se rompe | sintetizado | Glass Crystal Fragments |
| `aturdido` | enemigo aturdido | sintetizado | Cartoon Confused Dizzy |
| `reaccion_grande` | rótulo de reacción grande | sintetizado | Impact Cut Sweep |
| `dano` | el golpe F toca algo; objeto lanzado que acierta | sintetizado | Combat Punch Impact |
| `no_puedes` | sin tinta, mochila llena | sintetizado | Deny Muted |
| `tiempo_tic` | tiempo bruja | sintetizado | tic de reloj antiguo |
| `recarga_lista` | la página vuelve a estar lista | sintetizado | clic de interruptor |
| `muerte` | pantalla de muerte | sintetizado | Transition Bass Down |
| `barrido` | vaciar la página del grimorio | sintetizado | pasada sobre cartón |
| `boton_clic` | pulsador | sintetizado | Mechanism Latch Button |
| `logro_acierto` | logro | campanas sintetizadas | Interface Plucks Happy |
| `logro_brillo` | logro | campanas sintetizadas | Button Arp Twinkle |
| `objetivo_cumplido` | objetivo de misión | sintetizado | Game Entry Happy |
| `cofre_revelado` | aparece un cofre | sintetizado | Magic Creation |
| `amb_bosque` | ambiente de bosque | bucle sintetizado de 3 s | pradera con pájaros e insectos, 20 s |
| `amb_grillos` | ambiente de noche | bucle sintetizado | bosque con grillos, 20 s |
| `amb_cueva` | ambiente de cueva | bucle sintetizado | viento en chimenea, 20 s |
| `moneda` | oro | Kenney | Ting Coins + Coin Flip |
| `bolsa` | mochila | Kenney | Inventory Open, Cloth Canvas Bag |

## 3. Acciones que no sonaban y ahora suenan

| Acción | Sonido | Archivo donde va la llamada |
|---|---|---|
| Salto de la jugadora | `salto` (nuevo) | `jugador/jugador_3d.gd` `_vertical` |
| Aterrizaje (no en agua) | `aterrizar` (nuevo) | `jugador/jugador_3d.gd` `_vertical` |
| Salir del agua | `chapoteo` | `jugador/jugador_3d.gd` `_cambiar_nado` |
| Arma de un enemigo al conectar | `silbido_arma` (nuevo) | `enemigos/combate_3d.gd` `_conectar` |
| El arquero suelta la flecha | `arco` (existía y nadie lo pedía) | `enemigos/combate_3d.gd` `_soltar_flecha` |
| Llega la flecha del arquero | `flecha_clava` (nuevo) | `enemigos/combate_3d.gd` `_flecha_llega` |
| El Elemental del bosque ve a la jugadora, y su muerte | `jefe_rugido` (nuevo) | `enemigos/combate_3d.gd` |
| El chamán ve a la jugadora | su `snd_alerta` (grito de goblin) | `enemigos/chaman_3d.gd` `_ia_vigila` |
| El gólem ve a la jugadora | `golem_rugido` (nuevo) | `enemigos/golem_3d.gd` |
| El limo se divide | `limo_divide` (nuevo) | `enemigos/limo_3d.gd` `dividirse` |
| El limo cae tras la acometida | `limo_golpe` | `enemigos/limo_3d.gd` `_aterrizar_golpe` |
| Mecha del barril y su explosión | `mecha`, `explosion` | `objetos/barril_3d.gd` |
| Pulsador | `boton_clic` | `objetos/pulsador_3d.gd` `_disparar` |
| Compuerta abre y cierra | `compuerta_baja` | `objetos/compuerta_3d.gd` |
| Puerta de puzle abre y cierra | `puerta_abre`, `puerta_cierra` (existía sin uso) | `escenas/puzle.gd` `PuertaPuzle.poner` |
| La barrera para un golpe; la burbuja revienta | `escudo_golpe`, `escudo_roto` | `magia/lanzador_3d.gd` |
| Trampa de flechas: disparo y llegada | `arco`, `flecha_clava` | `objetos/trampa_flechas_3d.gd`, `objetos/flecha_trampa_3d.gd` |
| Rayo de tormenta | `trueno` (nuevo) | `mundo/estado_zona_3d.gd` `caer_rayo` |
| Síntesis: abrir, cerrar, poner, quitar, completar | `bolsa`, `ui_tick`, `sintetizar` (nuevo) | `presentacion/ui/sintesis_ui.gd` |
| Recoger una poción del suelo | `recoger` | `escenas/jugabilidad_3d.gd` |
| Sube la tinta máxima (jefe o secreto) | `tinta_sube` (nuevo; suena la fanfarria sintetizada) | `nucleo/tinta.gd` `_ganar` |

## 3 bis. Elecciones de Pablo (13/11, tercera tanda)

Pablo escuchó la librería y dijo qué pista va con qué. Mandan sobre lo de §2 y §3 donde coinciden.

| Entrada | Dónde suena | Pista |
|---|---|---|
| `puzle_resuelto` | al resolver un puzle | Accept Boing Crunch |
| `loberno_ladrido` (nuevo, 3 tomas) | el loberno ve a la jugadora | Dog Barks |
| `loberno_muere` (nuevo) | muere el loberno | Dog Shuffle, Grunt |
| `impacto_suelo` (nuevo, 4 tomas) | puños del gólem (antes `derrumbe`) y del Elemental (antes mudo) | Swing To Thud Impact |
| `libro_abre` | abrir el libro, la pausa, la tienda y el diario | Pile Of Antique Books Falling Over |
| `pagina` | pasar página; volumen de −10 a −6 dB | Antique Books Flicking Through Pages |
| `carga_bucle` | bucle mientras se castea (el del modo lanzar, todos los elementos) | Antique Books Slow Page Turns |
| `naturaleza` | lanzar naturaleza | Wood Shaker (primera pasada) |
| `arco_carga` (nuevo) | el arquero goblin tensa el arco | Wood Shaker (segunda pasada) |
| `maza_impacto` (nuevo) | el arma del goblin al conectar; sustituye a `silbido_arma` de §3 | Impact Cut Sweep |
| `explosion_barril` (nuevo, 2 tomas) | explota un barril (la geoda sigue con `explosion`) | 13 Fireworks, powerful explosions |
| `arde_bucle` | objeto ardiendo | 24 Campfire, Dropping Fresh Pine Branches |
| `siseo_apagado` | apagar fuego con agua | 42 Campfire, Putting Out Fire (ya estaba en §2) |

Con esto, de §4 salen `naturaleza` y la voz del loberno. `Power Up Bright Positive` es la **flecha de hielo** (`hielo_flecha`, nuevo): suena al salir un hechizo de hielo que viaja, en vez del sonido de hielo de siempre. `tinta_sube` se queda con la fanfarria sintetizada.

## 4. Lo que sigue sin sonido

**Sin candidato en el lote de Sonniss (hay que buscar o grabar):**

- `naturaleza`: no hay nada vegetal (hojas, ramas, raíces). Hoy toma el sonido de tierra. Afecta también a raíces, enredaderas y escudo de naturaleza.
- Voces propias de loberno y canouro: usan las de goblin. En el lote hay un gruñido de hombre lobo y perros, sin probar.
- Mouro espectro y ánima: silencio puesto a propósito. Si se quiere, en el lote hay «Ethereal Entity», el silbato de la muerte azteca y campanas de iglesia (para la Santa Compaña).
- Latido de vida baja, trazo de tiza, `sello_ok`/`sello_no`: siguen sintetizados a propósito (son señales musicales del grimorio) y no hay equivalente.
- Gato: no hay más maullidos.

**Con sonido posible, pero es una decisión de diseño antes que de audio:**

- Estados del suelo (helada, electrificada, quemada, mojada…) al ponerse y al caducar: se propagan por muchas casillas a la vez; hace falta decidir un tope por impacto para que no sea ruido.
- Impacto propio por elemento y vuelo de los proyectiles: `x_mano_impacto`, `alto_impacto` y `abajo_impacto` existen y nadie los llama (`_sonar_fase_v2("impacto", …)` no se usa). El proyectil contra el suelo no suena (`Sensacion3D.impacto_mundo` lo excluye).
- Formas de hechizo sin sonido: haz, órbita, columna, zona, descarga, rebote.
- Daño ambiental (suelo eléctrico, veneno, frío, calor): solo viñeta. Sonaría cada tic.
- Estados de la jugadora: envenenar, enraizar, curar, mojada, quemada.
- Avance de texto en los diálogos y voz de Marimanta.
- Transiciones: cambio de nivel, salida de nivel, rótulo de zona.
- Coger, soltar y lanzar objetos; el silbido del golpe F (hoy solo suena al impactar).

**Objetos interactuables todavía mudos:** molino (`rueda_chirria` existe sin uso), nexo de rayo, receptor de pulso, veta al picar, surtidor, cuerda (arder y romperse), enredadera, colmena y su zumbido, nido, mamoa, puente reactivo, tronco puente al caer, trampa de pared, chorro de la trampa dragón, cerrojo de sala, cofre sellado, fuego que consume seto, tronco o telaraña.

**Enemigos:** chamán (lanzar la bola, ritual, cura), bola y nube de veneno, raíces y enredaderas del Elemental, brinco del limo, limo en bloque de hielo, gólem resbalando, levantándose y cayendo a la lava, embestida del canouro.

**Código muerto:** `PiezaPuzle3D.crear` no se llama en ningún sitio, así que `placa_hunde`, `hielo_quiebra`, `mecha` y `compuerta_baja` solo suenan por las llamadas nuevas de §3. `paso`, `chispa`, `golpe_ui`, `tiempo`, `tiempo_carga` y el ambiente `murmullo` no los pide nadie.
