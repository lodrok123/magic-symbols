# Agua: problemas de la mecánica de fluidos, pruebas con objetos reales y puzles para el testeo

Contexto Juego, 15/10. Analizado sobre `mundo/agua_sim_3d.gd`, `mundo/reacciones_agua_3d.gd`,
`objetos/surtidor_3d.gd`, `objetos/flotador_3d.gd`, `objetos/objetos_3d.gd` (tinaja) y `jugador/jugador_3d.gd`
de la versión del 15/10, más un gemelo en Python del simulador (mismas constantes, mismo paso) para medir
antes de afirmar. Donde digo «medido» es un número del gemelo; donde digo «en el código» es lectura directa.

Encaja en PLAN_ARREGLOS Fase 13: 13.8 (escenarios de agua), 13.9 (agua con volumen), 13.12 (lista de bugs del
agua) y 13.13 (grabar/repetir). Este documento es la lista 13.12 y el diseño de 13.8.

---

## 1. Cómo funciona hoy (lo justo para entender los fallos)

- Rejilla de **trocitos** de `l = 2/3 u` (3 por casilla). Cada trocito tiene `prof` (altura de agua), `cerrado`
  (tierra/muro: no admite agua), `helado`, `fuente` (u³/s que entra), `fijo` (nivel que se mantiene: ríos «~»).
- Tuberías virtuales (Mei 2007): el caudal entre trocitos vecinos crece con la diferencia de altura
  `suelo + prof`, se amortigua (0,74) y se recorta para no vaciar un trocito por debajo de `RETIENE` (0,03).
- Un trocito con `prof ≤ PROF_CHARCO` (0,03) y sin fuente ni nivel fijo pierde `ABSORBE` (0,02 u/s): el suelo se lo bebe.
- **No hay paredes entre trocitos abiertos**: el agua solo se queda donde el suelo de alrededor está más alto o cerrado.
- El jugador solo distingue dos estados: `UMBRAL_AGUA` 0,25 (hay agua) y `UMBRAL_NADO` 0,55 (nada a x0,4).

---

## 2. Problemas detectados

Ordenados por lo que más duele para hacer puzles. **P** = bloquea puzles, **B** = bug, **D** = diseño/sensación.

| # | Tipo | Problema | Evidencia | Dónde |
|---|------|----------|-----------|-------|
| 1 | **P** | **No existe el recipiente.** No hay letra ni pieza «cuenca»: solo `~` (río, nivel fijo infinito) y `c` (cauce sellado que se abre). Un hueco de 1×1 rodeado de hierba **rebosa** en cuanto el nivel supera el suelo de al lado. | Medido: cuenca 1×1 con fuente 0,5 u³/s llega a 0,93 u y vierte fuera 0,67 u³ a los 12 s y 3,5 u³ a los 40 s. | `agua_sim_3d.gd` (`cerrado` solo por casilla entera), mapas `datos_nivel/mapas/*.txt` |
| 2 | **P** | **Los ríos son sumideros y fuentes infinitas.** `fijo` mantiene el nivel: no se puede llenar, vaciar ni desviar un río, y `abrir_cauce` fija nivel en las «~» vecinas en vez de aportar volumen. | En el código: `fijar_nivel`, `ReaccionesAgua3D.abrir_cauce`. | `agua_sim_3d.gd`, `reacciones_agua_3d.gd` |
| 3 | **P** | **La tinaja no vierte en la simulación.** En la maqueta era solo visual; `Surtidor3D` solo lo crea `bosque_3d.gd`. La fachada `Mundo3D.abrir_cauce` está lista; falta conectar `tinaja.agua_llega → Mundo3D.abrir_cauce(orden, Surtidor3D.CAUDAL_TINAJA)` (encargo 1 del Pipeline). Es la causa de «se activa la animación pero no hay volumen». | Diario Juego 14/10 22:55. | `objetos/objetos_3d.gd`, `presentacion/prueba_test2.gd` |
| 4 | **B** | **Charco eterno.** Agua por encima de `PROF_CHARCO` en trocitos aislados (vecinos más altos o cerrados) nunca baja de ese umbral y **no se absorbe jamás**. | Medido: 0,24 u³ (un impacto de hechizo) en hierba llana deja 0,071 u³ en 4 trocitos para siempre. | `agua_sim_3d.gd` paso de absorción (`p <= PROF_CHARCO`) |
| 5 | **B** | **`anadir` sobre hielo pierde volumen.** El reparto divide entre todos los trocitos del círculo y descarta los helados: el agua «desaparece». | En el código: comentario «se pierde ese trocito del reparto». | `agua_sim_3d.gd:anadir` |
| 6 | **B** | **Levantar tierra con agua y sin vecinos abiertos** deja el agua atrapada dentro del trocito cerrado (no se ve, no fluye, reaparece al reabrir). Conserva volumen pero da una sensación de agua que se esfuma. | En el código: `_poner_cerrado`. | `agua_sim_3d.gd` |
| 7 | **B** | **El chorro de la tinaja llena demasiado deprisa.** `CAUDAL_TINAJA` 1,5 u³/s; una cuenca de 1 casilla sube a 0,5 u en 1,8 s. Para un puzle de «espera a que se llene» hace falta 10–30 s. | Medido. | `objetos/surtidor_3d.gd` |
| 8 | **B** | **Un canal sin paredes desborda.** Al conectar una cuenca alta con una baja por un canal de 1 casilla, 0,95 u³ se salen por los lados antes de llegar. La pieza visual del canal (`Canal3D`) tiene paredes; la simulación no. | Medido. | `agua_sim_3d.gd`, `presentacion/canal_3d.gd` |
| 9 | **D** | **Sin vadeo.** Entre 0,25 y 0,55 u el jugador anda igual que en seco; a partir de 0,55 nada a x0,4. Falta un estado intermedio (vadear a x0,7, no puede lanzar) para que «subir el nivel» cambie algo antes de nadar. | En el código: `jugador_3d.gd`. | `jugador/jugador_3d.gd` |
| 10 | **D** | **Los flotadores no son pisables.** `Terreno3D.y_pies` ignora a `Flotador3D`: no se puede usar un tronco/plataforma flotante como puente. | En el código: `flotador_3d.gd` (4 sondas, FLOTA 30, FRENO 3) sin colisión para el jugador. | `objetos/flotador_3d.gd`, `mundo/terreno_3d.gd` |
| 11 | **B** | **`abrir_caudal` usa temporizadores del `SceneTree`.** No se pueden simular en headless a velocidad fija ni grabar/repetir (13.13); el caudal termina por reloj real, no por paso de simulación. | En el código. | `reacciones_agua_3d.gd` |
| 12 | **D** | **Dos dibujos del agua** (`Canal3D` con su superficie propia y `AguaRender3D` leyendo `prof`): en un canal se ven dos aguas o ninguna según la altura. Es lo que 13.9 arregla metiendo la superficie dentro de la pieza. | Captura de Pablo 14/10. | `presentacion/canal_3d.gd`, `agua_render_3d.gd` |
| 13 | **D** | **Sub 3 trocitos/casilla** hace que una cuenca de 1 casilla sean 9 trocitos con bordes de 2/3 u: los recipientes pequeños «respiran» (olas de un trocito a otro) y cuesta leer el nivel. 13.11 propone sub 2. | Observación del gemelo. | `agua_sim_3d.gd` |

Lo que **sí funciona** (medido): vasos comunicantes por canal con compuerta (0,64 u → 0,36/0,36 tras abrir);
presa de hielo que detiene el flujo y al deshelar equilibra; evaporación por fuego (`quitar`) devuelve lo quitado.

---

## 3. Qué piezas faltan para poder hacer puzles de agua

Cinco piezas, todas del Juego salvo la visual. Con ellas se cubren todos los puzles del §5.

| Pieza | Qué es | Por qué |
|-------|--------|---------|
| **Cuenca** (letra `u` en los mapas) | Casilla con **paredes por trocito** (`pared[i*4+k]`: bloquea el caudal en ese lado sin cerrar el trocito) y suelo hundido. El borde superior de la pared marca la altura a la que rebosa. | Resuelve #1 y #8 (el canal también lleva paredes laterales). |
| **Compuerta** (`objetos/compuerta_3d.gd`) | Pared entre dos trocitos que se abre/cierra (palanca, hielo que se funde, rayo). Expone `abierta` y señal `cambio`. | Trasvase entre recipientes; es el «interruptor» de los vasos comunicantes. |
| **Detector de nivel** (`objetos/nivel_3d.gd`) | Mira `profundidad_casilla(c)` y emite `nivel_alcanzado(si)` con histéresis (±0,05) al cruzar `objetivo`. | Es la Condición de `escenas/puzle.gd` (12.3) para todo lo de «llena hasta la marca». |
| **Plataforma flotante pisable** | `Flotador3D` + colisión que `y_pies` respeta; sube con el nivel. | Puente de nivel de agua (ya pedido en 12.4/12.x). |
| **Río finito** | `~` con `fijo` sigue valiendo para el borde del mapa; para puzles, `cerrar_cauce(c)` y `abrir_cauce` que **aporta caudal** (fuente) en vez de fijar nivel. | Resuelve #2: desviar y cortar corrientes. |

Arreglos pequeños en el simulador: #4 absorber también lámina fina aislada (`p ≤ PROF_CHARCO*2` si ningún vecino
puede recibir); #5 repartir el volumen solo entre los trocitos no helados; #7 `CAUDAL_TINAJA` 1,5 → 0,25 (una
tinaja de ~2 u³ se vacía en 8 s, llena una cuenca de 1 casilla a 0,5 u en ~9 s); #11 temporizadores con `dt` dentro de
`paso()`.

---

## 4. Pruebas con objetos reales (`herramientas/escenario_agua_*.gd`)

Todas headless, sin ventana (13.10), con paso fijo `PASO_FIJO` y sin `SceneTree` timers, para que `tools\pruebas.cmd`
las corra y den el mismo resultado siempre. Cada una monta un mapa de texto pequeño, coloca los objetos
**reales** (`Objetos3D`, `Surtidor3D`, `Flotador3D`…) y comprueba con tolerancias. La conservación de volumen se
mide siempre: `suma(prof)·l² + absorbido + evaporado + fuera_del_mapa == entrado ± 1 %`.

| Prueba | Montaje | Aserciones (lo que diría un playtester, en números) |
|--------|---------|-----------------------------------------------------|
| **E1 Tinaja vierte** | Tinaja real sobre cuenca 1×1. Hechizo Agua+Flecha al punto de impacto. | `agua_llega` se emite; a los 3 s hay agua en la cuenca (`prof > 0,1`); a los 20 s nivel ≥ 0,45; la tinaja deja de verter al agotar `VOL_TINAJA`; volumen conservado. Hoy falla por #3. |
| **E2 Cuenca estanca** | Cuenca 1×1 con paredes, fuente 0,5 u³/s. | Fuera de la cuenca `prof == 0` hasta que el nivel toca el borde de la pared; a partir de ahí rebosa **solo** por el lado más bajo. Hoy falla por #1 (rebosa desde 0,07 u). |
| **E3 Vasos comunicantes** | Dos cuencas 1×1 unidas por canal de 2 casillas con compuerta cerrada. A: 0,64 u. | Con compuerta cerrada B queda a 0 durante 10 s; al abrir, a los 15 s ambas a 0,36 ± 0,03; nada fuera del canal. Hoy falla por #8 (pierde 0,95 u³). |
| **E4 Presa de hielo** | Canal con corriente (fuente 0,3 u³/s aguas arriba, sumidero abajo). Hielo en medio. | Mientras hay hielo, aguas abajo baja a < 0,05 en 10 s y aguas arriba sube; al derretir, se iguala en 15 s. Ya funciona (medido). |
| **E5 Charco se seca** | Un impacto de hechizo (0,24 u³) en hierba llana. | A los 60 s `suma(prof) == 0` y las casillas pasan de «mojado» a seco en `SECA_EN`. Hoy falla por #4 (quedan 0,071 u³). |
| **E6 Fuego evapora** | Charco 0,5 u³; Fuego+Flecha encima. | `quitar` devuelve ≤ `VOL_EVAPORA`; aparece vapor; el resto sigue ahí; nada se crea. |
| **E7 Plataforma sube** | Cuenca 2×2 con flotador pisable; fuente. | El flotador sube con el nivel (y ≈ suelo + prof − calado ± 0,05); `y_pies` sobre él devuelve su altura; el jugador puede quedarse encima. Hoy falla por #10. |
| **E8 Hielo no traga agua** | Casilla medio helada; `anadir` 0,24 u³ en el centro. | Volumen conservado (lo que no cabe sobre hielo va a los trocitos libres). Hoy falla por #5. |
| **E9 Desviar corriente** | Río finito (fuente) con bifurcación; compuerta en un brazo. | Al cerrar un brazo, el otro recibe todo el caudal en 10 s; al cortar la fuente (`cerrar_cauce`) el río se vacía. Hoy falla por #2. |
| **E10 Vadeo** | Jugador en casilla a 0,4 u. | Velocidad x0,7, no puede lanzar; a 0,6 nada a x0,4; a 0,2 anda normal. Hoy falla por #9. |

Dos reglas para que el conjunto sirva de verdad:
- **Cada bug de la tabla §2 tiene una prueba que hoy falla.** Así el arreglo se ve pasar a verde y no vuelve (13.15 CI).
- **Las pruebas usan los objetos del juego, no llamadas directas al simulador.** `prueba_agua_sim.gd` ya cubre el simulador a pelo; estas cubren lo que ve el jugador.

---

## 5. Puzles típicos de agua y su prueba asociada

Cada puzle se describe con el esquema de `escenas/puzle.gd` (12.3): **Trigger → Condición → Acción**. La columna
«Prueba» es un escenario headless que juega el puzle con las acciones del jugador simuladas (hechizo en un punto,
pisar palanca) y comprueba que la Acción se dispara, y que **no** se dispara por el camino equivocado.

| # | Puzle | Montaje | Solución esperada | Piezas que necesita | Prueba |
|---|-------|---------|-------------------|---------------------|--------|
| **Q1 Llena la cuenca** | Cuenca junto a una puerta cerrada; tinaja encima de la cuenca. | Agua+Flecha a la tinaja → vierte → nivel ≥ 0,5 → detector → puerta abre. | Cuenca, detector, tinaja conectada (#3), caudal 0,25 (#7). | E1 + «puerta abre entre 8 y 15 s; con la tinaja vacía antes del nivel, no abre». |
| **Q2 Trasvase** | Cuenca A llena (río que la alimenta), cuenca B vacía con plataforma flotante que da acceso a una repisa. Canal A→B con compuerta de hielo. | Fuego+Flecha a la compuerta (derrite) → vasos comunicantes → B sube a 0,35 → plataforma a la altura de la repisa. | Cuenca, canal con paredes, compuerta, flotador pisable, detector. | E3 + E7 + «el jugador llega a la repisa; sin derretir, no». |
| **Q3 Presa temporizada** | Corriente que cruza el paso; aguas abajo un vado que solo es cruzable con < 0,25 u. | Hielo+Línea aguas arriba → presa → el vado baja → cruzar en < `DURA_HIELO` (20 s) antes de que el hielo se derrita. | Río finito o fuente, hielo. | E4 + «vado < 0,25 durante al menos 12 s; a los 25 s vuelve a > 0,25». |
| **Q4 Desvía el río** | Río con dos brazos; uno alimenta una rueda (abre puerta), el otro se pierde. Compuerta de tierra. | Tierra+Flecha cierra el brazo que se pierde → el otro recibe el caudal → rueda gira → puerta. | Río finito, compuerta (tierra = `solidificar_casilla` con paredes), detector de caudal (`_velocidad`). | E9 + «rueda recibe > 0,2 u/s en 10 s». |
| **Q5 Vacía para pasar** | Pasillo inundado a 0,6 u (hay que nadar: no se puede lanzar) con un enemigo al otro lado. | Fuego+Línea repetido evapora (`VOL_EVAPORA` 0,3 por golpe) hasta < 0,55 → se puede vadear y lanzar. | Vadeo (#9), evaporación. | E6 + E10 + «tras 4 golpes de fuego el jugador vadea; antes nada». |
| **Q6 Apaga y riega** | Enredadera seca bloquea el paso; antorcha encendida en la otra punta la haría arder. Tinaja inclinable. | Verter agua sobre la enredadera → crece (ya existe `Enredadera3D`) → trepar; alternativamente quemarla (otro camino). | Tinaja conectada, enredadera. | E1 + «enredadera `crecida` a los 6 s; con fuego, `quemada`; nunca las dos». |
| **Q7 Rayo por el agua** | Charco que conecta un emisor de rayo con un receptor; el charco está roto en medio (hierba seca). | Agua+Flecha en el hueco une el charco → Rayo conduce → receptor abre puerta. Fuego seca el hueco → se corta. | Charco que **no** se seca mientras conduce (ojo con #4: aquí el charco eterno es deseable; decidir umbral). | «continuidad de `prof > UMBRAL_AGUA` entre emisor y receptor» + E5. |
| **Q8 Nivel justo** | Cuenca con dos marcas: puerta abre con nivel entre 0,4 y 0,6. Tinaja grande (llena de más) y fuego para bajar. | Llenar y evaporar hasta clavar la banda. | Cuenca, detector con banda, tinaja, evaporación. | «abre solo dentro de la banda; con 0,7 no abre; tras 1 fuego sí». |

Orden recomendado para implementarlos: **Q1 → Q2 → Q3** cubren el 80 % de lo que hace falta (cuenca, detector,
compuerta, flotador pisable) y usan la tinaja, que es lo que Pablo ya tiene en pantalla. Q4–Q8 son variaciones
que reutilizan las mismas piezas.

---

## 6. Plan de trabajo propuesto (para PLAN_ARREGLOS 13.8 / 13.12)

| Paso | Quién | Qué | Comprobación |
|------|-------|-----|--------------|
| 1 | Pipeline | Conectar `tinaja.agua_llega → Mundo3D.abrir_cauce` (encargo 1, ya enviado). | E1 pasa hasta «hay agua a los 3 s». |
| 2 | Juego | Arreglos pequeños: #4, #5, #7, #11. | E5, E8 pasan; E1 tarda 8–15 s. |
| 3 | Juego | Cuenca con paredes por trocito (`pared[]`, letra `u`, canal con paredes). | E2, E3 pasan. |
| 4 | Juego | `objetos/nivel_3d.gd` (detector) y `objetos/compuerta_3d.gd`. | Q1 y Q2 jugables en headless. |
| 5 | Juego | Flotador pisable (`y_pies`) y vadeo. | E7, E10 pasan. |
| 6 | Juego | Río finito: `cerrar_cauce`, `abrir_cauce` por caudal. | E9 pasa; Q3, Q4. |
| 7 | Pipeline | 13.9: superficie del agua dentro de la pieza del canal/cuenca, opacidad por profundidad, menisco. | Capturas 13.14 de E1–E3. |
| 8 | Pablo | Playtest de Q1–Q3 en un nivel de pruebas (`escenas/nivel_pruebas.gd`). | Conclusiones en `docs/Playtests/`. |

Nota sobre el nivel oficial 1: el agua está pospuesta (12.0), así que todo esto es para el **nivel 2** o para el
nivel de pruebas; no bloquea la Fase 12.

---

## 7. Hecho el 15/10 (tarde): el laboratorio de puzles

`laboratorios/LabPuzlesAgua3D.tscn` + `lab_puzles_agua_3d.gd` + `mundo/datos_nivel/mapas/PuzlesAgua.txt` (25 × 25, nueve salas: Q1, Q2,
Q3, Q4, Q5, Q6 y Q8 del §5; la sala (2,2) queda para Q7, que necesita la fuente eléctrica de la maqueta). Cada sala tiene su vía
natural (el hechizo que toca) y dos disparadores de prueba: botón `!` (cualquier magia) y placa `@` (presencia); Q6 añade el
pulsador `%` (solo agua) con un botón de control al lado. Teclas 1–8 llevan a cada sala, R recarga.

Piezas nuevas del §3, en `objetos/`: `Pulsador3D` (disparador), `Compuerta3D` (la compuerta, con `abre_con`/`cierra_con` por
elemento) y `NivelAgua3D` (el detector con histéresis, ≥ / ≤ / banda). `AguaSim3D.apagar_fuente(c)` cierra el grifo. La cuenca
sigue siendo un grupo de casillas `c` abiertas (un pozo de 0,9 u: aguanta sin rebosar hasta ahí); las paredes por trocito del §3
quedan para cuando haga falta un recipiente de otra profundidad o un canal sin desbordes.

Prueba: `herramientas/escenario_puzles_agua.gd` juega los siete puzles por código (botones y hechizos) sobre la escena del lab; los
niveles de régimen de Q3 y Q4 se imprimen como AVISO para calibrar `objetivo` y `CAUDAL_ARROYO`.

---

## 8. Del laboratorio al nivel: piezas, assets y el pegamento declarativo (16/10)

### 8.1 Piezas del Juego ya probadas (objetos/)

| Pieza | Qué hace | Señales / API | Se activa con |
|---|---|---|---|
| `Pulsador3D` | botón (cualquier magia), botón de agua, placa de presencia | `pulsado(modo)`, `soltado`, `pulsar()`, `rearme`, `etiqueta` | hechizo / pisar |
| `Compuerta3D` | pared en casilla `c` o canal; estrecha o ancha; hielo (fuego abre), tierra (hielo cierra), roca (solo explosión) | `abrir/cerrar/alternar`, `cambio(abierta)`, `abre_con`, `cierra_con`, `estrecha` | hechizo / código / barril |
| `NivelAgua3D` | detector de nivel (≥, ≤, banda) con histéresis | `nivel_alcanzado(si)`, `leer()`, `profundidad` | agua |
| `Molino3D` | rueda que gira con corriente ≥ umbral o 6 s por hechizo de agua | `girando(si)`, `velocidad`, `corriente()` | agua |
| `Barril3D` | mecha 1,2 s y explosión de radio 2,6 u a lo `explosionable` | `explota(punto, radio)`, `encender()`, `apagar()` | fuego, rayo |
| `NexoRayo3D` | pila que conduce 30 s al mojarse (Terreno3D.conductores) | `cambio(conduce)`, `mojar()`, `secar()` | agua / fuego |
| `EmisorRayo3D` (ya existía) | descarga periódica por todo lo que `Terreno3D.conduce` | `descarga(celdas)` | — |
| Tinaja (`Reactivo3D`) + `abrir_cauce(celdas, caudal, volumen)` | vierte un volumen finito | `agua_llega` | agua |
| `AguaSim3D` | `limitar_fuente`, `apagar_fuente`, `fijar_nivel`, `helar_casilla` | `fuentes_agotadas()` | — |

### 8.2 Assets que piden esas piezas (Pipeline, Meshy / piezas/)

Todo en la escala de la casilla (2,3 u), estilo chibi-estilizado del Bosque, origen en el centro de la base, sin suelo, colisión aproximada. Donde pone «estados» son variantes o clips que el Juego conmuta con `Pieza3D.cambiar_visual` o un `AnimationPlayer`.

| Asset | Para | Tamaño | Estados / animación | Nota |
|---|---|---|---|---|
| **Pulsador de piedra** (botón redondo sobre base) | `Pulsador3D` magia/agua | Ø 0,9 × 0,9 u | `arriba`, `hundido`; tinte por modo (rojo magia, azul agua) | el cilindro actual es el placeholder |
| **Placa de presión** (losa cuadrada con runa) | `Pulsador3D` presencia | 1,8 × 1,8 × 0,1 u | `arriba`, `hundida`; runa que se enciende | puede reutilizar `placa_peso` |
| **Compuerta de madera/hierro** (losa vertical con guías) | `Compuerta3D` tierra | 2,2 × 1,3 × 0,3 u | `cerrada`, `abierta` (baja 0,9 u) | |
| **Compuerta de hielo** (bloque translúcido) | `Compuerta3D` hielo | igual | `entera`, `derritiéndose`, `nada` | material con refracción como `costra_hielo` |
| **Roca de derrumbe** (pedrusco que tapa la casilla) | `Compuerta3D` roca | Ø 2,2 × 1,3 u | `entera`, `rota` (3–4 cascotes que caen) | |
| **Barril de pólvora** | `Barril3D` | Ø 0,9 × 0,95 u | `entero`, `mecha` (chispa), `explosión` (VFX) | |
| **Rueda de molino** (palas de madera, eje y dos postes) | `Molino3D` | Ø 1,5 u, ancho 0,6 u | rota por código (nodo `rueda` separado del eje) | el eje cruza la casilla |
| **Pila de piedra con bornes de cobre** | `NexoRayo3D` | Ø 1,1 × 0,45 u | `seca`, `mojada` (disco de agua), `electrificada` (bornes brillan) | |
| **Poste de nivel** (vara con marca y farolillo) | `NivelAgua3D` | 0,1 × 1,8 u | `apagado`, `encendido` | el farolillo es el feedback del puzle |
| **Puerta de premio / reja** | `PuertaLab` → puerta de nivel | 2,2 × 2,4 × 0,3 u | `cerrada`, `abriéndose` (baja o se levanta) | la puerta real del nivel 1 puede ser la `X` arco_puerta |
| **Tinaja** (ya existe) | verter | — | ya tiene `llenándose`, `inclinada`; falta `vacía` al agotarse | `fuentes_agotadas()` avisa |
| **Pozo/cuenca** (ya existe `PozoCauce3D`) | cuenca | — | línea de humedad en la pared | ver (96) |
| **Canal recto/codo** (ya existen) | arroyos | — | — | |
| **Tapón de hielo del desagüe** | Q5 | 0,9 × 0,9 u | `entero`, `derritiéndose` | puede ser la compuerta de hielo en pequeño |
| **VFX**: salpicadura al mojar la pila, chispas en bornes, vapor al secar, fogonazo del barril, polvo del derrumbe | — | — | partículas .tres (13.5) | |
| **SFX** (Pipeline, audio): clic de botón, placa que se hunde, compuerta que baja, hielo que se quiebra, mecha, explosión, rueda chirriando, zumbido eléctrico, llenado con tono que sube | — | — | — | |

### 8.3 «Exportar el laboratorio a jugable»: `escenas/puzle.gd` (12.3)

Hoy cada sala del lab está cableada a mano en `lab_puzles_agua_3d.gd` (`_montar_qN`). Para que un nivel use estas piezas **sin código**, el pegamento es declarativo y vive en el `.txt` del mapa, en líneas `; puzle …` que lee un cargador del Juego (`escenas/puzle.gd`, `Puzle3D`), con la misma gramática Disparador → Condición → Acción que el lab ya cumple:

```
; pieza   <id> <tipo> <x> <y> [clave=valor …]
; puzle   <nombre> cuando=<id>[.<señal>] [si=<id>[.<cond>]] hace=<id>.<accion>
```

Tipos de pieza: `pulsador(modo=magia|agua|presencia, rearme=s)`, `compuerta(abierta, abre_con, cierra_con, estrecha, vertical)`, `nivel(objetivo, banda, invertido)`, `molino(umbral)`, `barril`, `nexo`, `puerta`, `cuenca(celdas=x0,y0..x1,y1, nivel=u, fijo=u)`, `manantial(caudal, volumen)`.
Acciones: `abrir`, `cerrar`, `alternar`, `pulsar`, `encender`, `mojar`, `apagar_fuente`, `helar(s)`.

Ejemplo (Q1 tal cual, en un nivel):
```
; pieza  tinaja1   tinaja    13 2  giro=180
; pieza  cuenca1   cuenca    11 4  celdas=11,4..13,5
; pieza  nivel1    nivel     12 5  objetivo=0.45
; pieza  puerta1   puerta    15 1
; puzle  llena_cuenca  cuando=nivel1.alcanzado  hace=puerta1.abrir
; puzle  cierra_otra   cuando=nivel1.perdido    hace=puerta1.cerrar
```

Plan (Juego, ~1 día): (1) `Puzle3D` que lee las líneas, instancia las piezas sobre `_props` y conecta señales por nombre; (2) `HorneadorNivel.leer_mapa` ya ignora las `;` que no conoce, así que no hay que tocarlo: `Puzle3D` relee el archivo (como hace `TerraFina3D.leer_alturas`); (3) rehacer el lab con esa gramática (el mejor test: si el lab se describe entero en el `.txt`, un nivel también); (4) el escenario sin ventana no cambia.
