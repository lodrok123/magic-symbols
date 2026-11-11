# Viento y rayo con el gas volumétrico (y dónde queda el agua) — 11/11/2026

Origen de la técnica: https://github.com/lejrimostfa/force-field-vfx-threejs (MIT). El port está en `laboratorios/haz_gas/` (`docs/HAZ_GAS_PORT_2026-11-09.md`) y el catálogo
de técnicas, en `docs/TECNICAS_REPO_GAS_OTROS_ELEMENTOS_2026-11-10.md`. Este documento añade dos elementos al MISMO solver, sin fork: **viento** y **rayo**. El **agua** ya
estaba (entrada 468 del diario) y no se ha tocado.

## 1. Cómo hace la demo el volumen (lo que se reutiliza)

La demo no dibuja partículas ni láminas: guarda el fuego en **texturas 3D** y las avanza con compute shaders, un paso fijo de 1/60 s.

1. **Campos en rejillas de distinta resolución.** Gas (4 canales: temperatura, hollín, polvo, combustible) a resolución entera; velocidad, presión y rotacional a la mitad;
   luz a un cuarto y a un octavo. Lo caro (la presión) va en la rejilla barata.
2. **Transporte.** El gas se mueve con MacCormack (nítido); la velocidad, con semi-Lagrangiana RK2 (suave, a propósito: da pliegues gordos y no ladrillos).
3. **Fuentes por reglas, no a mano.** El chorro es el punto más cercano de un segmento, con bamboleo y un radio que respira. El humo no se emite: es el calor que
   pierde el gas que se frena. El polvo lo levanta el aire rápido a ras de suelo.
4. **Fuerzas.** Flotación, arrastre hacia un viento de fondo, empuje de un solo sentido (nada vuelve al lanzador), piel del sólido (quita lo que entra y tira hacia la
   superficie para que el gas lo envuelva), confinamiento de vorticidad y turbulencia sin divergencia horneada.
5. **Proyección de presión** (Jacobi con arranque en caliente): es lo que hace que el gas rodee el obstáculo en vez de atravesarlo o amontonarse.
6. **Dibujo.** Un raymarch por píxel dentro de la caja del dominio, cortado contra la profundidad de la escena. En el juego no se acumula densidad: se busca la
   **superficie** del campo (umbral + bisección) y se pinta con el lenguaje toon de cada elemento.
7. **Chispas en GPU** que leen la velocidad del gas, caen y rebotan.

Lo que ya era nuestro y hace que valga para hechizos procedurales: `HazGas.derivar_haz` (dominio, rejilla y escalas a partir de largo, ancho y alto del hechizo) y el campo
de sólidos reales del nivel (`solido.glsl`, `HazGasJuego`).

## 2. Qué es «gas» en cada elemento

Un elemento nuevo son tres cosas: un juego de parámetros (`HazGas.PARAMS_ELEMENTO`), una rama en los dos kernels de fuentes (`gas_fuentes.glsl`, `vel_fuentes.glsl`) y un
dibujo (`raymarch_toon_<elemento>.glsl`). El resto de la cadena (advección, vorticidad, presión, sólidos, chispas) es común. El elemento viaja en `key_pos.w` del UBO
(0 fuego, 1 agua, 2 viento, 3 rayo).

| | Canal x | Otros canales | Lo que lo hace distinto | Dibujo |
|---|---|---|---|---|
| Fuego | temperatura | hollín, polvo, combustible | combustión, flotación, humo por regla | rampa del FuegoToy, lenguas |
| Agua | cantidad de agua | — | peso: cae y se reparte en lámina por la pared | tres tonos, cáusticas, fresnel |
| **Viento** | **ráfaga** (pulsos que viajan con el aire) | **etiquetas de línea de corriente** (y, w) y **polvo** (z) | no se pinta masa: solo los caminos del aire | trazos blancos largos con punta, funda tenue, polvo |
| **Rayo** | **ionización** (aire cargado) | — | se apaga en décimas; repta por la piel del sólido | trazo en zigzag + arcos + halo, en AZUL; el único que brilla |

### Viento

Primera versión (descartada el mismo día): una «bruma» en hélice dibujada como superficie. Pablo: «parece vapor… no parece una ráfaga sostenida de aire sino un fluido».
La conclusión es que **el aire no se puede pintar como masa**: cualquier cuerpo con borde se lee como líquido o vapor. Lo que se pinta ahora son los **caminos del aire**.

- **Líneas de corriente transportadas.** Dos canales del gas (y, w) guardan una ETIQUETA: la posición de cada punto en la sección del chorro, en radios. El gas las
  transporta sin cambiarlas, así que la curva donde las dos etiquetas son constantes es de verdad el camino que sigue el aire, también cuando rodea un sólido.
  Dentro del chorro las etiquetas son analíticas (nítidas); fuera quedan libres y la simulación las dobla.
- **Ráfaga.** El canal x son pulsos que nacen por línea en la mano (cada línea con su ritmo) y viajan a la velocidad del chorro: trazos largos que corren, aparecen y se
  van. `cool` 1,6 es lo que tardan en apagarse.
- **Velocidad.** Chorro con un giro leve alrededor del eje (`sootYield` hace aquí de `REMOLINO`), sin flotación ni peso, turbulencia y confinamiento moderados (las líneas
  se doblan y se rizan al final, no se deshacen). La ráfaga es 1,5 veces más ancha que el lápiz de fuego (`VIENTO_ANCHO`).
- **Polvo.** La regla de la demo: el aire bastante más rápido que el viento de fondo, a ras de suelo, levanta polvo, que se despeja con la altura.
- **Dibujo** (`raymarch_toon_viento.glsl`). Por cada rayo de vista se busca el punto más cercano a una línea de corriente y se afina: trazo blanco nítido, más fino en las
  puntas, con una funda muy tenue alrededor. Sin cuerpo ni contorno. El polvo es una franja terrosa plana (tonos POLVO de HumoRegla) y las chispas del solver se dibujan
  como **hojas** (una de cada ocho).
- **11/11, noche: hacia la referencia en vídeo de Pablo** (§7): las líneas se **retuercen en hélice**, jirones en vez de rectas paralelas, **brillo blanco en la mano**,
  **vórtice de lazos** que giran alrededor del contacto, **mechones** que el choque despide y **disolución** en 0,55 s al soltar.

### Rayo

Un rayo no es un gas, y simular el trazo como gas no funciona (dura menos que lo que tarda la masa en formarse). Lo que sí es gas es el **aire cargado**: la simulación dice
*dónde puede haber electricidad* y el dibujo pone la electricidad encima.

- **Fuente.** Núcleo fino del chorro, mancha en el choque y carga que **repta por la piel del sólido** alrededor del contacto, a ráfagas. Enfriamiento 6/s: al cortar el haz
  quedan arcos unas décimas y se van. El aire casi no se mueve (chorro lento, turbulencia fina).
- **Dibujo** (`raymarch_toon_rayo.glsl`), de dentro a fuera con `RayoPaleta`:
  - **Trazo principal y dos ramas**: tramos rectos entre nudos al azar (9 gordos + 27 finos) de la mano al contacto, sin desvío en los extremos, que se redibujan 14 veces
    por segundo. Por cada rayo de vista se busca la distancia mínima al trazo y se afina, así sale nítido aunque el paso sea de una celda.
  - **Arcos** dentro del aire cargado: la curva donde dos componentes del flujo sin divergencia horneado (`flujo_48`, el de la turbulencia) se anulan a la vez. Como el gas
    envuelve el sólido, los arcos se ciñen a su forma real.
  - **Halo**: la ionización acumulada, en tres escalones de azul.
  - Núcleo y cuerpo tapan el fondo (se leen sobre la hierba clara); el halo se suma.
  - **Color**: en el haz de gas el trazo va en AZUL (núcleo blanco azulado, cuerpo con el HALO_BORDE), no en el amarillo de `RayoPaleta.CUERPO`, para separarlo del
    fuego (decisión de Pablo del 11/11). Los RayoToy del resto de figuras siguen como estaban.

### Agua

Sin cambios: es el modo agua del 10/11, que ya está de serie. Lo pendiente sigue siendo lo de la entrada 468 (demasiadas gotas finas, el muro bajo, grosor de la lámina).

## 3. En el juego (hechizos procedurales)

`VfxToyJuego._haz` → `HazGasJuego.haz(h, hz, suelo, vida, "viento" | "rayo")`, igual que fuego y agua: el dominio sale del Hechizo real (largo = alcance, ancho, altura de la
mano) y del primer tope de la lógica, contra las casillas, enemigos y bloques reales. Solo dibuja: daño, alcance y choques los sigue decidiendo `HechizoVivo`.

- Ajustes nuevos, **apagados de serie**: `magic_symbols/vfx_haz_gas_viento` y `magic_symbols/vfx_haz_gas_rayo`. Apagados (o sin GPU, o con el tope de 2 gases lleno) sale el
  VientoToy / RayoToy de siempre.
- Con gas, el VientoToy se esconde entero y del RayoToy quedan solo sus luces.
- Solo la figura **haz**. Proyectil, muro, pilar y barrera siguen con sus toys.

## 4. Cómo verlo

- Lab: `laboratorios/LabVfxComparativa3D.tscn`, **Z** hasta VIENTO o RAYO y **Mayús+F12** (esfera) → otra vez (muro) → otra vez sale. Dentro: **B** obstáculo, **C** cámara,
  ESPACIO chorro, U/J largo, I/K alto, O/L ancho.
- Capturas del lab: `godot --path . --resolution 1280x720 --script res://herramientas/captura_gas_elementos.gd` → `docs/capturas/vfx_en_juego/haz_gas_elementos/`
  (`<elemento>_<muro|esfera|nada>_<lateral|juego>.png` y `_corte.png` con el chorro recién cortado).
- Prueba y capturas en el Bosque 01 con hechizos reales: `godot --path . --resolution 1280x720 --script res://herramientas/prueba_haz_gas_viento_rayo.gd`
  (`<elemento>_<aire|muro>_juego.jpg` y `_lateral.jpg` en la misma carpeta, más `rayo_cuerpo_juego.jpg` y `rayo_destello_juego.jpg`; al final imprime la tabla
  `COSTE` de los cuatro haces; `-- <carpeta> --sin-costes` se la salta).
- 11/11 (3070): en el lab, con el gas de RAYO puesto, **G** lanza un solo destello (hechizo de 0,1 s); ESPACIO vuelve al chorro de siempre. Con la ESFERA la rama
  salta a la esfera (hace de cuerpo).
- Antes / después en la 3070: `docs/capturas/vfx_en_juego/haz_gas_elementos/antes_3070/` y `despues_3070/` (`lab/` = captura_gas_elementos, `juego*/` = las pruebas
  en el Bosque), y la hoja `HOJA_RESUMEN_3070.png` (fuego, agua, viento y rayo; al aire y contra el muro; cámara del juego en el Bosque y en el lab).

## 5. Coste

### 5.1 RTX 3070 (11/11, después del pulido)

ms de GPU **por haz** (marcas del RenderingDevice: simulación + chispas + raymarch + composición; media de 0,5 s con el chorro sujeto encendido tras 1,5 s), calidad low,
volumen a media resolución. «fps desde 60 / 120» = a qué se quedaría un juego que va justo a 60 o a 120 fps limitado por la GPU si se le suma ese haz
(1000 / (16,7 + ms) y 1000 / (8,3 + ms)). Ojo: en la máquina corrían a la vez otras sesiones de Godot (otro lab y otra prueba), así que hay ruido entre pasadas;
la columna «rango» son las tres pasadas de la tabla `COSTE` de `prueba_haz_gas_viento_rayo` (la de referencia es la más tranquila, con el fotograma entero en 3–5 ms).

**En el juego** (Bosque 01, hechizo real `linea_x · linea_x`, 9,2 m; cámara del juego; ventana de 1280 × 720, pantalla interna 1423 × 801):

| Haz | Caso | Total | Simulación | Volumen | fps desde 60 | fps desde 120 | Rango (3 pasadas) |
|---|---|---|---|---|---|---|---|
| Fuego | aire | 2,82 | 0,27 | 2,55 | 51 | 90 | 2,8–4,4 |
| Fuego | muro | 2,09 | 0,20 | 1,89 | 53 | 96 | 2,1–3,9 |
| Agua | aire | 1,00 | 0,18 | 0,83 | 57 | 107 | 0,8–1,2 |
| Agua | muro | 0,81 | 0,12 | 0,69 | 57 | 109 | 0,8–1,6 |
| Viento | aire | 0,30 | 0,21 | 0,08 | 59 | 116 | 0,3–0,6 |
| Viento | muro | 0,22 | 0,15 | 0,07 | 59 | 117 | 0,2–0,4 |
| Rayo | aire | 0,28 | 0,12 | 0,16 | 59 | 116 | 0,3–0,4 |
| Rayo | muro | 0,27 | 0,16 | 0,11 | 59 | 116 | 0,2–0,3 |

**En el lab** (LabVfxComparativa3D, haz de referencia de 3 m, vista «juego», 1280 × 720; `captura_gas_elementos`, «aire» = obstáculo nada, «muro» = el muro de
prueba de 1 × 2,4 × 0,3 m):

| Haz | Aire | Muro | fps desde 60 (aire / muro) | fps desde 120 (aire / muro) |
|---|---|---|---|---|
| Fuego | 2,98 | 4,41 | 51 / 47 | 88 / 78 |
| Agua | 0,63 | 2,14 | 58 / 53 | 112 / 96 |
| Viento | 0,20 | 0,57 | 59 / 58 | 117 / 112 |
| Rayo | 0,21 | 0,35 | 59 / 59 | 117 / 115 |

Lo que se lee: el fuego es el caro (su volumen toon es el que más pasos da); el agua, un tercio; viento y rayo son casi gratis (≤ 0,6 ms) porque su rejilla es más
pequeña y su dibujo no acumula masa. Con la ventana MAXIMIZADA (2560 × 1369, que es como a veces la abre Windows) el volumen cuesta el doble o más: fuego 6–7 ms, y
16 ms en el caso «aire_diagonal» de `prueba_haz_gas_juego`. El pulido de este día no cambia el coste de forma medible (viento contra el muro en el juego: 0,24 ms
antes, 0,22–0,42 después).

### 5.2 Portátil con gráfica integrada (la sesión del 11/11 por la mañana; solo sirve para comparar entre elementos)

| Haz | Total | Simulación | Volumen |
|---|---|---|---|
| Agua (referencia, ya de serie) | 34 | 4,3 | 30 |
| Viento | 8–13 | 5–9 | 3–4 |
| Rayo | 6–17 | 2,5–3 | 4–14 (el pico, contra el muro) |

## 6. Lo que se pulió en la 3070 (11/11, tarde) y lo que queda

**Validación.** Las cuatro pruebas con ventana en la 3070: `prueba_haz_gas_viento_rayo`, `prueba_haz_gas_agua` y `prueba_gas_haz` a 0 a la primera;
`prueba_haz_gas_juego` dio **2 fallos** con el código tal cual (goblin: «chorro limpio y caliente», T_eje 0,17; dragón: hollín en el eje 0,104 frente a un tope de 0,102).
Causa: la ventana se abrió MAXIMIZADA (2560 × 1369), cada fotograma tardaba más, y `HazGasJuego` corta el chorro por **reloj real** mientras la prueba avanza a pasos
fijos: en el caso del goblin el primer «quemado» del enemigo daba además un tirón y la foto llegaba con el chorro ya cortado (se ve en la captura: la masa suelta y
nada junto a la mano). No es un fallo del fuego. Arreglo **en la prueba** (como ya hacía la de viento y rayo): se sujeta el chorro hasta que la simulación ha dado los
pasos de la medida y luego se suelta. Con eso, 0 fallos (y los números del fuego idénticos antes y después del pulido). Las pruebas que hacen capturas y miden fijan
ahora la ventana a 1280 × 720 sin maximizar.

**Viento.**
- Polvo a la altura de la mano: la ráfaga **barre el suelo** que tiene debajo (una franja bajo el chorro que crece con el recorrido) y, en el choque, el pie del sólido,
  solo por la cara del choque. Vetas sueltas (ruido al cubo), no una manta; `dustFade` 0,6 → 1,4 para que no se acumule.
- Contra un muro: junto a la cara las etiquetas de línea de corriente quedan **libres** (antes se reponían hasta la cara y los trazos acababan en ella) y la velocidad
  se **abre en abanico** por el plano de la pared, desde el contacto hacia fuera, con un giro leve alrededor de la normal (`vel_fuentes.glsl`): los trazos se reparten y
  se rizan a los dos lados del muro.
- Dientes a media resolución: el borde del trazo se suaviza en lo que mide un píxel del volumen a esa distancia (rayo del píxel vecino, vale con la cámara ortogonal) y,
  si el trazo es más fino que el píxel, se ensancha hasta él y se aclara en proporción (cobertura).
**Rayo.**
- **Un solo destello** (`HazGas.destello`, `HazGasJuego.DESTELLO_MAX_S` = 0,2 s): un hechizo de rayo que vive eso o menos dibuja el trazo UNA vez (sin redibujos) y lo
  apaga a los `vida` s + 0,12 s de caída, por tiempo de SIMULACIÓN (si el primer fotograma tarda, el destello se ve igual). El aire cargado (arcos, halo) se queda las
  décimas que dure la ionización. Hoy ningún haz del juego dura tan poco (HAZ_DURA_S 0,9 s): está listo para cuando lo haya. Lab: G.
- **Ramas que saltan a los cuerpos**: con los choques «enemigo» / «objeto» de la lógica, `HazGasJuego` busca el Combate3D de cada punto (hasta 2) y pasa su cápsula al
  dibujo cada fotograma; la rama sale del trazo ~1,5 M antes del cuerpo y acaba en su hombro, en zigzag, sin parpadear. Sin cuerpos, las ramas de siempre.
**Los dos.** Prueba de píxeles de color en `prueba_haz_gas_viento_rayo`: viento = trazos BLANCOS (~2 700–3 000 px) y 0 naranja; rayo = AZUL (~1 500 px) y 0 naranja;
el rayo que salta al goblin tiene trazo encima del cuerpo; el destello se ve al salir (~1 500 px azules) y a los 0,4 s queda la quinta parte (arcos).
**Agua (pendientes del 468).** Gotas: 1 de cada 7 chispas (antes 3) y 1,7 veces más gordas. Muro bajo: la lógica para el haz en la casilla, pero su caja de sólido
acababa bajo la mano y el agua pasaba por encima; ahora, solo para el agua, la casilla del TOPE llega al menos a la mano + 0,3 casillas (lámina pegada a la cara 29 %
→ 51 %). El fuego, el viento y el rayo siguen viendo el muro bajo como antes.

**Queda.**
- Que Pablo decida si enciende viento y rayo de serie (siguen apagados).
- Viento: detrás del muro del lab queda una mancha de polvo (la regla de la demo con el aire que rodea el muro); se puede bajar si molesta. El muro de tierra de las
  pruebas del Bosque casi no se ve en las capturas (es bajo y se hunde), así que el abanico se lee mejor en el lab.
- Agua: con el muro bajo el agua ahora se queda delante aunque el muro visible sea más bajo que la mano (es lo que dice la lógica); si se prefiere que salpique por
  encima, es quitar `AGUA_TOPE_SOBRE_MANO_CAS`.
- Coste medido con otras sesiones de Godot usando la misma GPU (de ahí los rangos). Sin medir en gama media.
- `prueba_rayo_toy`: 16 fallos y un error de índice, IGUAL antes y después (vienen de main, no se han mirado aquí).

## 7. Choque con identidad y viento hacia la referencia de Pablo (11/11, noche; rama `claude/gas-choque-viento`)

Pablo: «Rayo y agua están bien; en el haz mejoraría el choque para darle más identidad. En vez de los "puntitos" del fuego puedes poner chispas para el rayo y gotas
de agua para el agua» y «te paso el haz de viento para que lo mejores» (un vídeo grabado de un haz de viento, **solo como referencia visual**: no se ha copiado ni
textura ni recurso; en el repo solo hay un fotograma reducido dentro de la hoja de comparación). Hoja: `docs/capturas/vfx_en_juego/haz_gas_elementos/HOJA_CHOQUE_VIENTO.png`.

**Chispas por elemento** (`chispas.glsl`: una rama por elemento; el FUEGO pasa por el código de siempre, sin un cambio). El compute sabe ahora si el haz acaba contra
algo (`CHOQUE`, en `mundo_lo.w` del UBO: 0 si el obstáculo es «nada»).
- **Rayo: chispas eléctricas** (`haz_gas_chispas_rayo.gdshader`, 1 de cada 3). Nacen en el contacto a 15–25 u/s, viven 0,15–0,5 s, casi sin peso ni arrastre, y cada
  1/24 s de vida **quiebran** la dirección (codos: zigzag en el espacio); rebotan vivas (0,6). Se dibujan como trazos largos (cola = v · 0,06 s) con **zigzag** dentro
  del quad, una **rama** corta en una de cada tres y **parpadeo** a saltos de 1/30 s. Colores del rayo de gas: núcleo blanco azulado, cuerpo HALO_BORDE y borde HALO
  (RayoPaleta). Nunca naranja.
- **Agua: gotas y salpicaduras** (`haz_gas_gotas_toon.gdshader` con `agua`, 1 de cada 7 como antes). Nacen en la salpicadura del contacto y saltan en corona; gravedad
  de verdad (11 u/s²) y poco aire. Se dibujan como **lágrimas** (cabeza redonda con brillo de ESPUMA, cola SOMERO que se afila con la velocidad), 2,8 veces más gordas
  que el trazo de antes. Al tocar el **sólido** se parten en una gotita de la mitad de grosor que sale despedida por la cara; al tocar el **suelo** se vuelven una
  **salpicadura**: anillo plano que se abre en 0,3 s y al final se rompe en cuentas (SOMERO por dentro, ESPUMA por fuera).
- **Fuego**: igual (mismo shader, mismo compute, mismos números).

**Viento** (sin tocar la idea de §2: el aire NO se pinta como masa, solo trazos):
- **Hélice**: en `gas_fuentes.glsl` las etiquetas de línea de corriente GIRAN con el recorrido (`VIENTO_HELICE` = 1,6 vueltas de la mano al final) y con el tiempo
  (3,2 rad/s), y más por fuera que por dentro: cada línea es una hélice de paso distinto que se enrosca y corre, en vez de rectas paralelas.
- **Jirones**: el grosor del trazo engorda y adelgaza a lo largo (ruido que corre con el haz), como tiras que se retuercen.
- **Brillo en la mano**: disco blanco con halo blando en la boquilla, que respira; se apaga en 0,25 s al soltar (`toon_viento.mano`).
- **Vórtice en el choque** (solo con `CHOQUE`): en `vel_fuentes.glsl` un remolino alrededor del EJE del haz en un anillo grueso que envuelve el contacto
  (`VIENTO_VORTICE`), y en el dibujo tres **lazos** (anillos ladeados y ondulados, rotos en 2–3 arcos que giran cada uno a su ritmo) alrededor del contacto, con el
  mismo trazo blanco y antialias (`toon_viento.anillos`). Los lazos solo se evalúan cerca del contacto.
- **Mechones**: 1 de cada 8 chispas son mechones blancos curvos sin peso: con choque, la mitad salen despedidos del contacto girando (el vórtice); el resto nacen a lo
  largo del chorro y viajan con él. Las hojas (1 de cada 8) siguen igual.
- **Disolución al soltar** (`toon_viento.disuelve` = 0,55 s): los trazos se rompen en trozos (ruido fijo en el espacio), adelgazan y se van; los lazos se abren y se
  apagan; el aire se lleva lo que queda. `HazGas` lleva el tiempo desde que se soltó (`_corte_t0`, por tiempo de simulación).
- Se mantienen las líneas que rodean los sólidos, el abanico por la pared y el polvo.

**Coste** (3070, en el juego: tabla `COSTE` de `prueba_haz_gas_viento_rayo`, una pasada antes y otra después; ms de GPU por haz):

| Haz | Caso | Antes | Después |
|---|---|---|---|
| Fuego | aire / muro | 2,73 / 2,49 | 2,63 / 2,54 |
| Agua | aire / muro | 1,31 / 1,44 | 1,11 / 1,40 |
| Viento | aire / muro | 0,28 / 0,44 | 0,21 / 0,25 |
| Rayo | aire / muro | 0,28 / 0,27 | 0,24 / 0,18 |

Dentro del ruido de una pasada. Las marcas miden simulación + chispas (compute) + volumen; el dibujo de los quads de las chispas no está en ellas. En el lab
(`captura_gas_elementos`, más ruidoso) el viento queda en el mismo rango: esfera 1,46–1,53 ms antes y 0,68–1,12 después; muro 2,32–2,64 antes y 2,45–2,73 después (los lazos solo se evalúan cerca del contacto). Capturas antes / después en `docs/capturas/vfx_en_juego/haz_gas_elementos/choque_viento/`.

**Cómo verlo.** Lab: `LabVfxComparativa3D`, Z hasta RAYO / AGUA / VIENTO, Mayús+F12 (esfera), otra vez (muro), otra vez sale; B obstáculo, C cámara, ESPACIO suelta y
vuelve a dar el chorro (la disolución del viento se ve al soltar).

**Pruebas nuevas.** `prueba_haz_gas_viento_rayo`: las chispas del choque del rayo son AZULES y nada naranja; las del viento, nada naranja. `prueba_haz_gas_agua`: las
gotas del choque son turquesa y nada naranja. Las chispas se aíslan con tres fotos en pausa (con chispas y dos sin ellas: lo que cambia entre las dos sin chispas es la escena y no cuenta) y solo junto a las chispas vivas proyectadas
(`colores_chispas`).

**Resultado (3070).** Con ventana a 0: `prueba_haz_gas_juego`, `prueba_gas_haz`, `prueba_haz_gas_agua`, `prueba_haz_gas_viento_rayo`. Headless a 0: `prueba_vfx_toy`,
`prueba_haz_fuego_ideas`, `prueba_vfx_en_juego`, `prueba_agua_toy`, `prueba_lab_vfx_toys`; `prueba_rayo_toy` 16 fallos, los de main.

**Queda.** Que Pablo vea la hoja y diga si el vórtice y el brillo de la mano se leen como aire o hay que bajarlos (`toon_viento.anillos` / `mano`); en la cámara del juego
los lazos se ven casi de canto (se leen mejor desde arriba); los mechones y las hojas juntos pueden ser demasiados puntos alrededor del choque.

## 8. Refuerzo del viento (11/11, noche; Pablo: «Refuerza el viento»)

Lectura de `HOJA_CHOQUE_VIENTO.png` frente a la referencia: al aire, un «garabato» de muchas líneas finas que tiemblan (la referencia tiene POCAS cintas anchas,
lisas y largas que se enroscan juntas); el brillo de la mano, diminuto; los lazos del choque, finos y de canto desde la cámara del juego; demasiados puntitos
(mechones y hojas); al soltar, una nube de líneas finas en vez de unos pocos jirones curvos. Hoja: `docs/capturas/vfx_en_juego/haz_gas_elementos/HOJA_VIENTO_REFUERZO.png`
(antes del refuerzo, b00c548b, frente a ahora; al aire, contra la esfera y recién soltado; cámara lateral y cámara del juego desde arriba; con el mismo fotograma reducido
de la referencia).

- **Cintas del chorro, analíticas** (`raymarch_toon_viento.glsl`, `cintas()`): 5 hélices alrededor del eje con el MISMO giro (`CINTAS_VUELTAS` 0,7 vueltas) y radios
  distintos, rotas en tramos de ~0,4 del haz que corren a la velocidad del aire y se afilan en las dos puntas; borde toon en dos escalones (alma LINEA, orilla CLARO
  medio transparente). Acaban en el contacto. Las líneas de corriente del gas (las que rodean el sólido y se abren en abanico) siguen, pero solo con choque y en el
  último 30 % del haz, más finas y con su ancho medido en el MUNDO (gradiente de las etiquetas: donde el aire las emborrona no engordan hasta hacer una mancha).
  En el gas, menos líneas (`VIENTO_LINEAS` 2 → 1,25), pulsos más largos, giro común y menos turbulencia (22 → 12) y confinamiento (26 → 14).
- **Brillo de la mano**: disco toon en tres escalones (núcleo blanco, halo, orla tenue) de radio igual a la altura de la mano (unos dos tercios del cuerpo de
  diámetro), fuera de la caja del dominio.
- **Lazos del vórtice**: más gruesos (el trazo de las cintas · 1,2), radios 1–2,1 R1 · 1,5, ~1–1,6 vueltas por segundo; la cola de cada arco se abre hacia fuera
  (jirón arrancado) y el plano se LADEA hacia la cámara (normal = haz + 0,9 · dirección de la cámara), así desde la cámara del juego se ven abiertos. Al soltar se
  van en ~0,25 s.
- **Menos puntitos**: hojas 1 de cada 24 (antes 8) y más grandes; mechones 1 de cada 16 (antes 8), más gruesos, largos y curvos, y solo del choque (al aire, ninguno).
- **Al soltar**: las cintas se rompen en unos pocos trozos largos (ruido de baja frecuencia fijo en el aire), derivan con el aire (`DERIVA`: hacia delante y un poco
  arriba) y se apagan en 0,55 s.

**Coste** (3070, en el juego, tabla `COSTE` de `prueba_haz_gas_viento_rayo`; aire / muro): viento 0,21 / 0,25 ms antes del refuerzo → 0,60 / 0,66 ms ahora (las
cintas se evalúan en cada paso del raymarch); fuego, agua y rayo sin cambios (3,00 / 2,55, 0,98 / 1,10, 0,52 / 0,27; ruido de pasada). En el lab, viento al aire
0,4–1,3 ms y contra la esfera o el muro 1,9–4,2 ms (muy ruidoso: otra sesión usaba la GPU).
Capturas de ahora en `docs/capturas/vfx_en_juego/haz_gas_elementos/viento_refuerzo/` (las de antes del refuerzo son las `choque_viento/despues/`).

**Resultado (3070).** Con ventana a 0: `prueba_haz_gas_viento_rayo`, `prueba_haz_gas_juego`. Headless a 0: `prueba_vfx_toy`, `prueba_haz_fuego_ideas`,
`prueba_vfx_en_juego`, `prueba_agua_toy`, `prueba_lab_vfx_toys`; `prueba_rayo_toy` 16 (los de main).

**Queda.** Los trozos al soltar salen algo recortados (bordes del ruido); el coste del viento sube a ~0,6 ms en el juego (las cintas en cada paso); si molesta, acotar
las cintas a un cilindro alrededor del eje antes de evaluarlas.
