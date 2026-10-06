# Estados del suelo y de los personajes: contrato de reglas (5 de octubre de 2026)

**Fuente de verdad: el código 2D. Si este documento y el código difieren, manda el código y se
actualiza este documento.**

> **Cambio de contrato del Test 3 (6/10/2026, ver §7): en el 3D la TIERRA y el HIELO caducan** (tierra 25 s,
> tope de 8 bloques; hielo 20 s, salvo casillas de hielo permanente que marque el nivel). En el 2D siguen
> siendo permanentes (§1.1, §1.4, §1.5 y §4 describen el 2D). El Pipeline: `_decaer_estado` sigue sin tocar
> G ni B; quien devuelve B a 0 es `Lanzador3D` (§7.2).

Lo escribe el contexto **Juego** para que el Pipeline programe la capa de estado por celda de la maqueta
3D (`poc_25d/PruebaTest2`, `docs/IMPLEMENTAR_TECNICAS.md` Paso 1) **copiando** estas reglas, sin inventar
otras. Cada fila cita la función de la que sale. Se ha extraído leyendo los archivos de la copia
`C:\Users\paranda\Documents\magic-symbols` el 5/10/2026: `neutral_block.gd`, `grass_block.gd`,
`water_block.gd`, `earth_block.gd`, `earth_builder.gd`, `combustible.gd`, `combate_comun.gd`, `enemy.gd`,
`archer.gd`, `circuit.gd`, `player.gd` y las clases `Empujable` / `ZonaGolpe` de `nivel_base.gd`.

---

## 0. Cómo leer las tablas

**Etiquetas de runa** (las columnas "llega"): un hechizo no dice "soy fuego", trae etiquetas. Cada `.tres`:

| runa | etiquetas | daño base |
|---|---|---|
| `fire_rune` | `fuego`, `calor` | 40 |
| `water_rune` | `agua` | 40 |
| `ice_rune` | `hielo`, `frio` | 20 |
| `lightning_rune` | `rayo`, `electrico` | 55 |
| `wind_rune` | `viento` | 0 |
| `earth_rune` | `tierra` | 0 |
| `time_rune` | `tiempo`, `disipar` | 0 |
| `steam_rune` (solo lo genera el mundo) | `vapor` | 0 |

- **Nombres en el 3D.** La maqueta habla de elementos (`fuego`, `agua`, `hielo`, `rayo`, `viento`,
  `tierra`); aquí se usan las etiquetas. Equivalencia: `fuego` = `calor`, `hielo` = `frio`, `tiempo` =
  `disipar`; el resto, igual.
- **Orden de comprobación.** Cada bloque mira las etiquetas en un orden fijo (`if / elif`) y solo aplica
  la **primera** que encuentra. El orden de cada bloque va en su tabla.
- **"—"** = no pasa nada. Está puesto a propósito: el Pipeline no debe rellenar esas celdas.
- **Dura**: "∞" = no caduca nunca; solo lo cambia otro hechizo.
- **Tierra "quieta"**: la tierra solo construye si el hechizo llega **sin dirección** (pilar, barrera,
  algo que nace en el sitio). Una flecha de tierra que vuela no construye.
- **Escala.** En el 2D, una casilla = 64 px de paso en pantalla (`IsoGrid.STEP` = 58 × 27,5). Los radios
  de abajo están en px; para pasarlos a celdas, ÷ 64.
- **Un impacto afecta a las casillas que toca el hechizo**, no a un cuadrado de 3×3. Una flecha toca
  una; una barrera, las de su corro. Ver Dudas 7.

---

## 1. Transiciones por tipo de bloque

### 1.1 Suelo neutro (`neutral_block.gd`) — es casi todo el suelo de los niveles

Estados: **SECO** (`DRY`), **MOJADO** (`WET`), **HELADO** (`ICY`). Nunca bloquea el paso.
Orden en `on_spell_hit`: `tierra` → `frio` → `agua` → `calor` → `rayo` → `disipar`. **No tiene rama
`viento`.**

| estado | llega | resultado | efecto lateral | dura | función |
|---|---|---|---|---|---|
| SECO | `agua` | MOJADO | — | ∞ | `_wet` |
| MOJADO | `agua` | HELADO | empieza a resbalar quien esté encima | ∞ | `_wet`, `_set_state`, `_grab_ice_contacts` |
| HELADO | `agua` | — | — | — | `_wet` |
| SECO | `frio` | HELADO | resbala quien esté encima | ∞ | `on_spell_hit` → `_set_state(ICY)` |
| MOJADO | `frio` | HELADO | resbala quien esté encima | ∞ | ídem |
| HELADO | `frio` | — | — | — | `_set_state` (mismo estado: no hace nada) |
| SECO | `calor` | — | — | — | `_heat` |
| MOJADO | `calor` | SECO | **vapor**: hechizo quieto `steam_rune` 2,5 s | ∞ | `_heat`, `_emit_steam` |
| HELADO | `calor` | MOJADO | deja de resbalar | ∞ | `_heat`, `_release_ice_contacts` |
| SECO | `rayo` | — | — | — | `_electrify` |
| MOJADO | `rayo` | MOJADO (**electrificado** 0,6 s) | descarga: hechizo quieto `lightning_rune` 0,6 s encima (hiere a quien esté). Pestillo `is_electrified` 0,6 s: mientras dura, ignora otros rayos | 0,6 s (`ELECTRIFY_TIME`), lo corta `_calm_down` | `_electrify`, `_calm_down` |
| HELADO | `rayo` | — | — | — | `_electrify` |
| cualquiera | `viento` | — | **el viento que pasa se carga**: de agua si MOJADO, de hielo si HELADO, nada si SECO | — | `carried_element` (lo lee `spell.gd::_try_carry`) |
| cualquiera | `tierra` quieta | (no cambia) | **construye un bloque de tierra encima** si no hay ya uno | el bloque: ver 1.4 | `on_spell_hit` → `EarthBuilder.build_on` |
| cualquiera | `tierra` volando | — | — | — | `on_spell_hit` |
| cualquiera | `disipar` | SECO | se lleva el bloque de tierra que hubiera encima; deja de resbalar si estaba HELADO | ∞ | `_dispel` |
| cualquiera | `vapor` | — | — | — | (sin rama) |

Notas del código:
- **El mojado no caduca.** No hay temporizador: un charco es un charco hasta que otro hechizo lo cambie.
- **"Dos aguas hielan".** Es una decisión escrita (`_wet`): el agua es la ruta larga y barata al hielo
  (dos impactos); el hielo, la corta (uno).
- **Resbalar** lo decide el jugador: el bloque solo le avisa (`add_ice_contact` / `remove_ice_contact`) y
  `player.gd` pierde agarre (`ICE_GRIP = 1.8`). Solo el suelo neutro HELADO avisa; el **agua helada no
  resbala** (`water_block.gd` no llama a `add_ice_contact`).
- **No hay sonido** en ninguna transición del suelo neutro (solo `print`).

### 1.2 Hierba (`grass_block.gd`) — letras `v` (fina) y `G` (tupida) del plano

Estados: **FINA** (`THIN`, se cruza), **CRECIDA** (`GROWN`, sólida: bloquea el paso), **PRENDIENDO**
(`IGNITING`), **ARDIENDO** (`BURNING`), **CENIZAS** (`ASHES`).
Orden en `on_spell_hit`: `calor` → `rayo` → `disipar` → (`agua` **o** `frio`) → `viento`. **No tiene
rama `tierra`.**

| estado | llega | resultado | efecto lateral | dura | función |
|---|---|---|---|---|---|
| FINA | `calor` | PRENDIENDO | la llama nace en el punto de impacto | 1 s y pasa sola a ARDIENDO | `ignite`, `_fijar_origen`, `_on_fire_phase_finished` |
| CRECIDA | `calor` | PRENDIENDO | ídem; deja de bloquear el paso | 1 s → ARDIENDO | ídem |
| PRENDIENDO | `calor` | — | — | — | `ignite` |
| ARDIENDO | `calor` | — | — | — | `ignite` |
| CENIZAS | `calor` | — | — | — | `ignite` |
| FINA | `rayo` | ARDIENDO (se salta PRENDIENDO) | Sfx `prender` | 5 s → CENIZAS | `_strike` |
| CRECIDA | `rayo` | ARDIENDO | Sfx `prender`; deja de bloquear | 5 s → CENIZAS | `_strike` |
| PRENDIENDO | `rayo` | ARDIENDO | Sfx `prender`, chispas | 5 s → CENIZAS | `_strike`, `_apply_particles` |
| ARDIENDO | `rayo` | — | — | — | `_strike` |
| CENIZAS | `rayo` | — | — | — | `_strike` |
| FINA | `agua` o `frio` | CRECIDA (pasa a bloquear) | — | ∞ | `_water` |
| CRECIDA | `agua` o `frio` | — | — | — | `_water` |
| PRENDIENDO | `agua` o `frio` | FINA (apagada) | — | ∞ | `_water` |
| ARDIENDO | `agua` o `frio` | FINA (apagada) | humo (`BlockFx` "ceniza") | ∞ | `_water`, `_apply_particles` |
| CENIZAS | `agua` o `frio` | FINA (**rebrota**) | — | ∞ | `_water` |
| PRENDIENDO | `disipar` | FINA | — | ∞ | `_dispel` |
| ARDIENDO | `disipar` | FINA | humo | ∞ | `_dispel` |
| FINA, CRECIDA, CENIZAS | `disipar` | — (no riega, no resucita) | — | — | `_dispel` |
| ARDIENDO | `viento` **con dirección** | ARDIENDO (avivado) | lanza una flecha de fuego hacia delante y prende toda la hierba/objetos que ardan a ≤ 230 px **en el cono** del viento (producto escalar ≥ 0,3). La llama se ve avivada (`_aviva` = 1, baja sola en 2,5 s) | — | `_fan_flames`, `_spread_fire` |
| PRENDIENDO | `viento` | — (aún no aviva) | — | — | `_fan_flames` |
| FINA, CRECIDA, CENIZAS | `viento` | — | — | — | `_fan_flames` |
| PRENDIENDO, ARDIENDO | (el viento pasa) | — | el viento que pasa **se carga de fuego** | — | `carried_element` |
| cualquiera | `tierra` | — | — | — | (sin rama) |
| cualquiera | `vapor` | — | — | — | (sin rama) |

Lo que pasa **solo**, sin hechizo:

| estado | qué pasa | cuándo | función |
|---|---|---|---|
| PRENDIENDO | → ARDIENDO (Sfx `prender`, chispas) | a 1 s (`IGNITE_TIME`) | `_on_fire_phase_finished` |
| ARDIENDO | → CENIZAS (ceniza) | a 5 s (`BURN_TIME`) | `_on_fire_phase_finished` |
| PRENDIENDO / ARDIENDO | **contagio por frente**: desde el punto donde prendió crece un círculo a 32 px/s (`FRONT_SPEED`); a partir de 26 px de radio (`FRONT_MIN`), la **primera** hierba u objeto que pueda arder que toque prende (en PRENDIENDO) y toma el relevo, y este frente deja de contagiar. Si llega a 110 px (`SPREAD_RADIUS`) sin tocar nada, se acaba | continuo | `_avanzar_fuego`, `_primer_comburente`, `_terminar_frente` |
| ARDIENDO | daño de 10 a quien esté encima, cada 0,5 s (`DamageTimer` de `GrassBlock.tscn`) | mientras arde | `_start_burning_damage`, `_on_damage_tick` |
| CENIZAS | — | ∞ | — |

(`SPREAD_INTERVAL` y `_on_spread_tick` existen pero **no se usan**: el temporizador nunca se arranca.)

### 1.3 Agua (`water_block.gd`) — letra `~`

Estados: **LÍQUIDA** (bloquea el paso), **HELADA** (`is_frozen`: se pisa), y encima de cualquiera de
las dos el pestillo **ELECTRIFICADA** (`is_electrified`, 0,6 s).
Orden en `on_spell_hit`: (`frio` y no helada) → `calor` → `rayo` → `disipar` → `viento` → `tierra`
quieta. **No tiene rama `agua`.**

Esta tabla es el agua **normal** (`hielo_permanente = false`: Blockout, IsoTest, ReactionLab). En
**todos los niveles nuevos** el agua es de hielo permanente: ver 1.5.

| estado | llega | resultado | efecto lateral | dura | función |
|---|---|---|---|---|---|
| LÍQUIDA | `frio` | HELADA (se puede pisar) | Sfx `congelar`; apaga las chispas si las había | ∞ | `_freeze` |
| HELADA | `frio` | — | — | — | `on_spell_hit` (condición `not is_frozen`) |
| LÍQUIDA | `calor` | LÍQUIDA ("hierve") | **vapor** 2,5 s | — | `_heat`, `_emit_steam` |
| HELADA | `calor` | LÍQUIDA (vuelve a bloquear) | vapor 2,5 s | ∞ | `_heat`, `_unfreeze` |
| LÍQUIDA | `rayo` | LÍQUIDA **electrificada** | descarga quieta `lightning_rune` 0,6 s encima (hiere a quien esté); **pasa la corriente al circuito**: a toda pieza del grupo `circuito` (otras aguas, tótems de rayo, placas, puertas) a ≤ 80 px, o sea, las 4 vecinas, nunca en diagonal; Sfx `chispa`; destello de luz; chispas sueltas 5 s | 0,6 s (`CONDUCT_TIME`), lo corta `_calm_down` | `_conduct`, `Circuit.spread` |
| LÍQUIDA electrificada | `rayo` | — (el pestillo corta la onda) | — | — | `_conduct` |
| HELADA | `rayo` | — (**el hielo no conduce**) | — | — | `_conduct` |
| HELADA | `disipar` | LÍQUIDA | se lleva el bloque de tierra que hubiera encima; destello "magia" | ∞ | `_dispel`, `_unfreeze` |
| LÍQUIDA | `disipar` | — | se lleva el bloque de tierra; destello "magia" | — | `_dispel` |
| HELADA | `viento` con dirección | — | lanza una flecha de **agua** hacia delante | — | `_propagate_wind` |
| LÍQUIDA | `viento` | — | — | — | `_propagate_wind` |
| cualquiera | (el viento pasa) | — | el viento **vuela por encima** del agua y se carga de agua (LÍQUIDA) o de hielo (HELADA); lo que el viento lleva también vuela por encima | — | `spell_flies_over`, `carried_element` |
| cualquiera | `tierra` quieta | (no cambia) | **pasadero**: un bloque de tierra encima si no hay ya uno | el bloque: ver 1.4 | `EarthBuilder.build_on` |
| cualquiera | `agua` | — | — | — | (sin rama) |
| cualquiera | `vapor` | — | — | — | (sin rama) |

### 1.4 Tierra: bloque construido (`earth_block.gd`) y bloques empujables (`Empujable` en `nivel_base.gd`)

**Bloque de tierra construido** (sale de `EarthBuilder.build_on` sobre suelo neutro o agua). Es sólido y
**se puede subir encima** (grupo `climbable`). Orden: `agua` → `disipar`.

| estado | llega | resultado | efecto lateral | dura | función |
|---|---|---|---|---|---|
| construido | `agua` | desaparece y en su sitio queda **hierba FINA** (ver 1.2) | destello "tierra" | la hierba: ∞ | `on_spell_hit` → `_sprout` |
| construido | `disipar` | desaparece | destello "magia" | — | `on_spell_hit` |
| construido | `fuego`/`calor`, `frio`, `rayo`, `viento`, `tierra`, `vapor` | — | — | — | (sin rama) |
| construido | (solo) | si hay más de **20** bloques, se desmorona el **más antiguo** | destello "tierra" | — | `_enforce_block_limit` |

*(Test 3 en 3D: el bloque dura **25 s**, se apila hasta **2** y hay un tope de **8** niveles vivos: ver §7.1.)*

**Bloque empujable de tierra** (`Empujable`, `tipo = "tierra"`): **no reacciona a ningún elemento**
(`golpeado` solo mira el hielo). Se empuja andando contra él: avanza **una casilla** por empujón.
Pesa: pisa las baldosas y las placas de peso.

**Bloque empujable de hielo** (`tipo = "hielo"`): detiene los hechizos (`detiene_hechizo`).

| estado | llega | resultado | efecto lateral | dura | función |
|---|---|---|---|---|---|
| entero | `calor` | **se derrite y desaparece** (deja la casilla libre) | vapor 2 s; se desvanece en 1 s | — | `golpeado` → `derretir` |
| entero | (solo) **una llama encendida a < 75 px**: una fogata o un objeto que arde (nodos de `flammable`/`ground` con `is_lit = true`). **La hierba ardiendo no cuenta**: `grass_block.gd` no tiene `is_lit` | se derrite | ídem | se comprueba cada 0,5 s | `_physics_process`, `_hay_fuego_cerca` |
| entero | `agua`, `frio`, `rayo`, `viento`, `tierra`, `disipar`, `vapor` | — | — | — | `golpeado` |
| entero | empujón | resbala **hasta chocar** con algo | Sfx `congelar` | — | `_empujar` |

### 1.5 Agua de hielo permanente (`water_block.gd` con `hielo_permanente = true`)

Es **el agua de todos los niveles nuevos** (`nivel_base.gd::_agua` la crea siempre así). Igual que 1.3
salvo que **el hielo ya no vuelve a ser agua**:

| estado | llega | resultado | efecto lateral | dura | función |
|---|---|---|---|---|---|
| LÍQUIDA | cualquiera | igual que en 1.3 | | | |
| HELADA | `frio` | — | — | — | `on_spell_hit` |
| HELADA | `calor` | **HELADA** (no se derrite) | vapor 2,5 s | ∞ | `_heat` |
| HELADA | `rayo` | — | — | — | `_conduct` |
| HELADA | `disipar` | **HELADA** | se lleva el bloque de tierra que hubiera encima | ∞ | `_dispel` |
| HELADA | `viento` con dirección | — | flecha de agua hacia delante | — | `_propagate_wind` |
| HELADA | `tierra` quieta | (no cambia) | pasadero encima | — | `EarthBuilder.build_on` |
| HELADA | `agua` | — | — | — | (sin rama) |
| HELADA | `vapor` | — | — | — | (sin rama) |

*(Test 3 en 3D: esta casilla **sí** vuelve a ser agua a los 20 s de helarse, salvo que el nivel la marque como hielo
permanente: ver §7.2. Quien estuviera encima cae al agua y nada.)*

**Cómo se ve el deshielo** (solo aspecto: se pisa desde el primer instante): al congelarse sale el
dibujo **nevado**; a los 4 s (`PAUSA_DESHIELO`) se funde en 1,4 s (`FUNDIDO_DESHIELO`) a **escarcha**;
4 s después se funde en 1,4 s a **claro**, que se queda. Funciones `_freeze`, `_programar_deshielo`,
`_fundir_a`.

### 1.6 Fuera del contrato del suelo: objetos que arden (`combustible.gd`, letras `z l h r`)

No son suelo (son objetos encima de una casilla), pero el fuego los toca. Para que el 3D no los
confunda con la hierba:

| estado | llega | resultado | dura | función |
|---|---|---|---|---|
| sano | `calor` o `rayo` | ardiendo (Sfx `pira`, luz de fuego) | `tiempo_arder` (seto 3,5 s, tronco 4, setas 2,5, telaraña 1,6), luego **desaparece** con su cuerpo | `ignite`, `_consumido` |
| ardiendo | `agua` o `frio` | sano otra vez (se puede volver a prender) | ∞ | `_apagar` |
| ardiendo | `viento` | contagia a ≤ 230 px en el cono del viento | — | `_contagiar` |
| ardiendo | (solo) | contagia a ≤ 110 px cada 0,8 s | — | `_contagiar` |
| cualquiera | `tierra`, `disipar`, `vapor` | — | — | `on_spell_hit` |

---

## 2. Estados en los personajes (`combate_comun.gd`)

Solo los **enemigos nuevos** (goblin guerrero, arquero, dummy) llevan el componente `Combate`. **El
jugador no tiene estos estados** (ver §5). Los contadores bajan con el tiempo en `_process`.

| estado | lo provoca | dura | qué lo anula | qué cambia | tinte del sprite (`self_modulate`) | función |
|---|---|---|---|---|---|---|
| **mojado** | `agua` | 6 s | `fuego` (lo seca: texto "¡Vapor!" y **no** quema) | velocidad ×0,75; `rayo` hace ×1,5 y **salta** al goblin más cercano a < 190 px con la mitad del daño; `hielo` congela 2,5 s en vez de 1,5 y hace +15 de daño | `tinte.lerp(Color(0.6, 0.75, 1.2), 0.45)` | `golpe`, `vel_mult`, `_arco_cercano`, `_process` |
| **quemando** | `fuego` si no está mojado | 3 s | `agua`, `hielo` | 3 de daño cada 0,5 s (×2 si es débil al fuego) | `tinte.lerp(Color(1.5, 0.7, 0.4), 0.5 + 0.3·sin(ms·0.02))` (late) | `golpe`, `_process` |
| **congelado** | `hielo` | 1,5 s (2,5 s si estaba mojado) | — (se acaba solo) | velocidad ×0: ni se mueve ni ataca | `tinte.lerp(Color(0.6, 0.9, 1.4), 0.7)` | `golpe`, `vel_mult`, `_process` |
| **lento** | `tierra` | 3 s | — | velocidad ×0,6 | (ninguno) | `golpe`, `vel_mult` |
| **aturdido** | cualquier runa con etiqueta `electrico` (el rayo) | 2,5 s (`STUN_TIME`); un rayo nuevo **renueva** el plazo, no lo suma | — | no se mueve ni ataca | `modulate = Color(1.5, 1.45, 0.7)` (en el nodo del guerrero, en el sprite del arquero) | `enemy.gd::_stun`, `archer.gd::_stun` |
| **interrumpido** | `viento` | 0,7 s | — | cancela la carga o el apuntado en curso | (ninguno) | `golpe`, `_cancelar_acciones` |
| **destello** | cualquier golpe | 0,10 s (0,12 si el golpe no hace daño) | — | — | `Color(2.2, 2.2, 2.2)` (manda sobre todo lo demás) | `herido`, `golpe`, `_process` |

- **Prioridad de tintes** cuando coinciden: congelado > quemando > mojado; el destello tapa a todos.
  `tinte` es el color propio de cada enemigo (el dummy, por ejemplo, `Color(0.55, 0.8, 1.35)`).
- **Daño**: el del `.tres` + `DANO_EXTRA` (tierra +18), × 2 si es su debilidad, × 0,5 si la resiste
  (quien resiste el agua resiste también el hielo). Función `multiplicador`.
- **Retroceso** por elemento (`golpe`): viento 2600, tierra 2200, agua 600, fuego 500, rayo 400, hielo 300.
- Colores de elemento para textos y rombos (`COLORES`): fuego `(1.0, 0.45, 0.2)`, agua `(0.35, 0.65, 1.0)`,
  rayo `(1.0, 0.95, 0.35)`, hielo `(0.65, 0.95, 1.0)`, viento `(0.75, 1.0, 0.8)`, tierra `(0.75, 0.55, 0.3)`.

---

## 3. Cómo se ve cada estado en el 2D

El 2D tiñe con `modulate`, que **multiplica** el color de la textura (1 = tal cual; < 1 oscurece;
> 1 aclara). Para comparar con el 3D hay que comparar **textura × modulate**, no el modulate solo.

| bloque · estado | textura | `modulate` | extra | función |
|---|---|---|---|---|
| neutro · SECO | la losa del nivel (`_suelo`: un bloque de `export_godot/terrain/bosque_01`) | `(1, 1, 1)` | — | `neutral_block.gd::_apply_state` |
| neutro · MOJADO | la misma | `(0.62, 0.66, 0.78)` | — | ídem |
| neutro · HELADO | la misma | `(0.8, 0.95, 1.05)` | — | ídem |
| neutro · electrificado | la misma | sin cambio | el destello lo pone el hechizo de rayo | `_electrify` |
| hierba · FINA | `tex_thin` (en los niveles, hierba + mata + helecho + flores compuestos) | `(1, 1, 1)` | — | `grass_block.gd::_apply_state`, `_set_visual` |
| hierba · CRECIDA | `tex_grown` (hierba tupida) | `(1, 1, 1)` | — | ídem |
| hierba · PRENDIENDO | `tex_thin` | `(1.15, 1.0, 0.75)` | llama pequeña: tira de fuego a escala 0,35 y alfa 0,7 | `_apply_flames` |
| hierba · ARDIENDO | `tex_thin` | `(0.92, 0.85, 0.78)` | `GrassBurn` dibuja el círculo quemado que crece: carbón `(0.09, 0.05, 0.03)` al 50 %, borde de llamas `(1.0, 0.42, 0.10)`, brasas `(0.70, 0.10, 0.02)` / `(0.92, 0.25, 0.04)` / `(1.0, 0.55, 0.10)` / `(1.0, 0.90, 0.40)`; partículas de llama y humo | `_set_emitter`, `grass_burn.gd` |
| hierba · CENIZAS | `tex_thin` | `(0.28, 0.26, 0.26)` | — | `_apply_state` |
| agua · LÍQUIDA | `water` del bosque | `(1, 1, 1)` | — | `water_block.gd::_unfreeze` / inicial |
| agua · HELADA (sin dibujos) | la misma | `(0.85, 1.0, 1.1)` | — | `_freeze` |
| agua · HELADA (niveles) | `water_frozen_1_nevado` → `_2_escarcha` → `_3_claro` (en `paranda`, bloques de `export_godot/terrain/bosque_01/sprites/blocks/`) | `(1, 1, 1)` | fundidos de 1,4 s tras 4 s | `_freeze`, `_fundir_a` |
| agua · electrificada | la de su estado | `(1.5, 1.45, 0.7)` 0,6 s | chispas azules, destello de luz `Glow.LUZ_RAYO`, chispas sueltas 5 s | `_conduct` |
| tierra construida | `art/earth.png` | `(1, 1, 1)` | — | `EarthBlock.tscn` |
| empujable hielo · derritiéndose | `art/empujable_hielo.png` | a `(0.8, 0.95, 1.0, 0)` en 1 s, y se aplasta (escala Y a 0,25) | vapor | `Empujable.derretir` |
| objeto que arde · ardiendo | sprite `sano` → `chamuscado` | — | llamas, luz `Glow.LUZ_FUEGO` | `combustible.gd` |

---

## 4. Mapa a los cuatro canales de la textura de estado 3D

Canales: **R quemado · G mojado · B helado · A pisado**. Esta sección **decide** qué valor pone el 3D
para cada estado 2D. Valores de 0 a 1.

### 4.1 Suelo neutro (las celdas de suelo de la maqueta)

| estado 2D | R | G | B | A | nota |
|---|---|---|---|---|---|
| SECO | 0 | 0 | 0 | (libre) | |
| MOJADO | 0 | 1 | 0 | (libre) | **no decae** |
| HELADO | 0 | 0 | 1 | (libre) | **no decae**. En el 2D HELADO **sustituye** a MOJADO: G vuelve a 0 |
| electrificado | — | — | — | — | **no va en la textura: lo hace el VFX** (chispas + destello 0,6 s) |

Reglas que se derivan, en lenguaje de canales, para `_al_impactar()` en una celda de suelo:
- `agua`: si B = 1 → nada. Si G = 1 → G = 0, B = 1. Si no → G = 1.
- `hielo` (frío): G = 0, B = 1 (desde SECO o MOJADO).
- `fuego` (calor): si B = 1 → B = 0, G = 1. Si G = 1 → G = 0 y **vapor** (VFX). Si no → **nada** (el suelo
  neutro no se quema: **R no se escribe en suelo**).
- `rayo`: si G = 1 → VFX de descarga 0,6 s. Si no → nada. **No escribe R.**
- `viento`: no cambia canales del suelo (A es visual, ver §5).
- `tierra` (quieta): construye el bloque de tierra; no cambia canales.
- `disipar`: R = G = B = 0 y quita el bloque de tierra.
- **`_decaer_estado()`: G y B no bajan.** Ningún estado del suelo caduca en el 2D. *(Test 3: B del suelo helado
  vuelve a 0 a los 20 s, y G pasa a 1: lo hace `Lanzador3D`, no `_decaer_estado`; §7.2.)*

### 4.2 Hierba (solo las celdas que en el 2D son hierba: letras `v` y `G`)

| estado 2D | R | G | B | A | nota |
|---|---|---|---|---|---|
| FINA | 0 | 0 | 0 | (libre) | |
| CRECIDA | 0 | 0 | 0 | (libre) | **no va en la textura** (ver decisión 1) |
| PRENDIENDO | 0 | 0 | 0 | (libre) | **lo hace el VFX**: llama pequeña 1 s (decisión 2) |
| ARDIENDO | 0 → 1 en los 5 s | 0 | 0 | (libre) | R sube lineal mientras arde (el círculo quemado que crece en el 2D) + VFX de llamas |
| CENIZAS | 1 | 0 | 0 | (libre) | ∞ |

Reglas en canales para una celda de hierba:
- `fuego`: FINA/CRECIDA → PRENDIENDO (VFX 1 s) → ARDIENDO (R sube) → CENIZAS (R = 1). Sobre lo que ya arde
  o es ceniza → nada.
- `rayo`: FINA/CRECIDA/PRENDIENDO → ARDIENDO directamente.
- `agua` y `hielo` (las dos igual): PRENDIENDO/ARDIENDO → FINA, **R = 0** (se apaga sin dejar rastro);
  CENIZAS → FINA, **R = 0** (rebrota); FINA → CRECIDA. **La hierba no se moja ni se hiela: G y B no se
  escriben en celdas de hierba.**
- `disipar`: PRENDIENDO/ARDIENDO → FINA, R = 0. Sobre CENIZAS → nada (R se queda en 1).
- `viento` sobre ARDIENDO: contagio en cono a ≤ 230 px (≈ 3,6 celdas) + VFX avivado.
- Contagio solo: el frente crece a 32 px/s (≈ 0,5 celdas/s) y prende la primera hierba que toque a
  ≤ 110 px (≈ 1,7 celdas).

### 4.3 Agua (las celdas de agua de la maqueta: siempre de hielo permanente)

| estado 2D | R | G | B | A | nota |
|---|---|---|---|---|---|
| LÍQUIDA | 0 | 0 | 0 | — | G no tiene sentido en el agua |
| HELADA | 0 | 0 | 1 | — | 2D: **no decae**. **Test 3: caduca a los 20 s** (§7.2). El shader de agua cambia a hielo con B |
| electrificada | — | — | — | — | **VFX** (chispas + destello 0,6 s y su paso a las 4 vecinas) |
| hirviendo (calor) | — | — | — | — | **VFX** de vapor 2,5 s; no cambia nada |

### 4.4 Decisiones (el Pipeline no las cambia)

1. **CRECIDA vs FINA no va en la textura de estado.** Es un estado del **objeto hierba** de esa celda
   (alta y sólida, o baja), no del suelo. El 3D lo guarda en su propia estructura (por ejemplo un
   `Dictionary` celda → estado de hierba en `Hierba3D`) y cambia la altura y la colisión de las matas.
   No se usa un umbral en ningún canal: R ya significa "quemado", y meter ahí otra cosa haría que una
   hierba crecida pareciera chamuscada.
2. **PRENDIENDO vs ARDIENDO**: no se distinguen por canal. PRENDIENDO es solo VFX (1 s, llama pequeña);
   ARDIENDO sube R de 0 a 1 en 5 s con llamas. Si se apaga a mitad, R vuelve a 0.
3. **Electrificado** (charco o agua): no se representa en el suelo. Lo hace el VFX.
4. **El quemado (R) solo existe en celdas de hierba.** El suelo neutro no se quema en el 2D (ver Dudas 2).
5. **Mojado (G) no caduca**, ni en el suelo ni en el agua. **Helado (B): en el 2D tampoco; en el Test 3 sí
   (20 s, §7.2)**, pero no lo hace `_decaer_estado()`, que solo puede bajar A (pisado): lo hace `Lanzador3D`.
6. **Un impacto escribe en las celdas que toca el hechizo** (radio 0 para una flecha), no en un 3×3.
   Las áreas grandes salen de la forma del hechizo (barrera, pulso...), como en el 2D.

### 4.5 Qué hay que cambiar en `IMPLEMENTAR_TECNICAS.md` Paso 1 (para el Pipeline)

| hoy (provisional) | según el 2D |
|---|---|
| `_decaer_estado`: G baja en 6 s, B en 20 s | G y B **no bajan**. Solo A |
| `fuego`: marca R en radio 1 si G ≤ 0,5 | en suelo: deshace un escalón (B → G, o G → 0 + vapor) y **no marca R**; en hierba: el ciclo de 4.2 |
| `fuego`: resta B | B → G (el hielo pasa a charco), no B → 0 |
| `agua`: G += 1 en radio 1, R −= 0,5 | en suelo: G = 1, o G → B si ya estaba mojado; en hierba: apaga (R = 0) o crece, **sin G** |
| `hielo`: B += 1 en radio 1 | en suelo y agua: B = 1 (y G = 0); en hierba: igual que el agua |
| `rayo`: R += 0,6 | en suelo: solo VFX si G = 1; en hierba: ARDIENDO |
| `viento`: A en radio 2 | se puede dejar como **visual** (§5); en hierba ardiendo, el contagio en cono |
| `tierra`: −1 (no marca) | correcto; además construye el bloque si es quieta |
| (no existe) `disipar` | R = G = B = 0 en suelo; apaga la hierba que arde |

---

## 5. Lo que el 3D tiene y el 2D no: solo aspecto

- **Pisado (canal A)** y **hierba que se aparta** de la chibi (D4): **solo visuales**. No cambian nada del
  juego: ni velocidad, ni ruido, ni lo que ven los goblins. Si alguien quiere que tengan efecto, lo decide
  Pablo antes.
- **El viento tumbando hierba** (A en radio 2): también solo visual.
- **El jugador mojado o quemado** (D14 de `TECNICAS_APLICABLES.md`): en el 2D **el jugador no tiene esos
  estados**; solo los enemigos. Un tinte en la chibi sería solo aspecto mientras no exista la regla.
- **La humedad oscurece y da brillo** (rugosidad baja) en el 3D: es la traducción visual de MOJADO; las
  reglas siguen siendo las de §4.

---

## 6. Dudas para Pablo (no se han cambiado: se apuntan)

1. **El mojado del suelo no caduca y el del enemigo sí (6 s).** ¿Es a propósito? En el 2D un charco se
   queda para siempre hasta que otro hechizo lo cambie.
2. **El fuego no deja marca en el suelo neutro.** En el 2D solo arde la hierba de las letras `v`/`G` y los
   objetos (`z l h r`). En la maqueta 3D la hierba decorativa cubre casi todo el suelo: según este
   contrato **no arde**. Si quieres que arda, es una regla nueva (y habría que llevarla al 2D también).
3. **El agua helada no resbala; el suelo helado sí.** `water_block.gd` no avisa al jugador
   (`add_ice_contact`). ¿Debería?
4. **El viento sobre agua helada lanza una flecha de agua**, aunque el comentario de `_propagate_wind`
   dice "arrastra el frío". ¿Agua o hielo?
5. **Agua normal con dibujos de hielo:** `_unfreeze` devuelve el `modulate` pero no la textura de agua.
   Hoy no se nota (en los niveles el hielo es permanente), pero si un nivel pone dibujos sin hielo
   permanente, el agua derretida seguiría pareciendo hielo.
6. **El bloque empujable de hielo se derrite con una llama cercana; el suelo helado no** (solo con un
   hechizo de calor directo). Y la llama que cuenta es la de una fogata o un objeto, **no la de la hierba
   ardiendo** (no tiene `is_lit`). ¿Debería el suelo helado derretirse cerca del fuego, y la hierba
   ardiendo derretir el bloque?
7. **Radio de un impacto.** En el 2D un impacto toca las casillas que toca el hechizo. En el 3D se ha
   propuesto marcar un 3×3 por impacto. Recomiendo radio 0 para respetar el 2D; confirmarlo.
8. **La tierra regada brota con el arte viejo** (`art/grass.png`): `_sprout` crea una hierba sin las
   texturas del nivel. Solo aspecto.
9. **El viento no aviva lo que está PRENDIENDO**, solo lo que ya ARDE. ¿A propósito?
10. **El charco electrificado del suelo neutro**: el comentario de `_electrify` dice que no encadena a los
    vecinos (no está en el grupo `circuito`), pero la descarga quieta que suelta podría tocar casillas
    mojadas de al lado. No está medido; si importa para el 3D, lo mido.

---

## 7. Test 3 en 3D: lo que caduca y la altura (6 de octubre de 2026) — CAMBIO DE CONTRATO

Decidido por Pablo el 6/10 (`DISENO_FUTURO.md` §0b, `PLAN_ARREGLOS.md` 4.0c) y hecho por el Juego en
`poc_25d/lanzador_3d.gd` (4.1c). **Solo vale para el 3D del Test 3**; el 2D no cambia. Cuando un número de aquí
choque con §1–§4, manda esta sección en el 3D.

### 7.1 Tierra con duración

| regla | valor | constante en `Lanzador3D` |
|---|---|---|
| duración de un bloque de tierra | **25 s** (parpadea los últimos 3 s) | `DURACION_TIERRA`, `AVISO_CADUCA` |
| bloques apilados en una casilla | hasta **2** (un tercero no se construye; renueva los 25 s) | `MAX_TIERRA_APILADA` |
| bloques vivos a la vez (todo el mapa) | **8** niveles; si se pasa, se deshace el de menos tiempo restante (el más viejo) | `MAX_NIVELES_TIERRA` |
| dónde no se construye | agua sin hielo, puente, casilla con objeto sólido (`_bloqueadas`), cornisa fija del nivel, **encima del jugador o de un enemigo** | `construir_tierra` |
| columna de barrera + levitación | sólida, de **2 niveles**, dura lo que el hechizo (no cuenta para el tope de 8) | `_levantar_columna` |
| subir | se sube un nivel con el salto; el jugador no puede estar a más de `MAX_NIVELES_SUBIBLES = 2` niveles | `Jugador3D` |

Al caducar la tierra el bloque se hunde (0,2 s) y quien estuviera encima **cae** (sin daño).

### 7.2 Hielo con duración

El hielo es el estado B de una casilla. Cuando una casilla pasa a B = 1 (por `hielo`, o por la segunda `agua` sobre
suelo mojado), `Lanzador3D` se apunta la casilla y a los **20 s** (`DURACION_HIELO`) la deshace:

| casilla | al caducar | lo hace |
|---|---|---|
| suelo neutro helado | B = 0 y **G = 1** (queda mojado), vapor | `Lanzador3D._derretir` → `PruebaTest2._poner_canal` |
| agua helada | B = 0, **sale de `_helada` y vuelve a `_bloqueadas`** (es agua otra vez), vapor | ídem |
| casilla en `Lanzador3D.hielo_permanente` (dict `Vector2i → true`, lo rellena el nivel) | **no caduca** | — |

- Un `hielo` nuevo sobre una casilla ya helada **renueva** los 20 s. Un `agua` no.
- Si otro hechizo ya deshizo el hielo (`fuego` sobre suelo helado → mojado), la casilla se borra de la lista y
  no hace nada al cumplirse el plazo. El `fuego` sobre **agua** helada sigue sin derretirla (§1.5): solo el tiempo.
- **Quien esté encima cuando el agua vuelve a ser agua cae y pasa a `nadando`** (`Jugador3D`: velocidad ×0,4, sin
  lanzar ni saltar, clip `swim_forward`, sale al tocar suelo llano; sin daño). Los goblins vuelven a su puesto.
- Hasta ahora el 3D tenía "B no baja": **desaparece**. `_decaer_estado` sigue sin tocar G ni B (sin cambios para
  el Pipeline); el temporizador vive en `Lanzador3D` y escribe por `_poner_canal`.

### 7.3 Cómo engancha con el Pipeline

`Lanzador3D.al_impactar(elemento, punto)` se conecta a `Vfx3D.impacto` DESPUÉS de `PruebaTest2._al_impactar`
(`Jugador3D.montar` lo hace al final de `_ready`), así que el canal B ya está escrito cuando se mira. El Pipeline no
tiene que llamar a nada. Lo que sí tiene que respetar: **`_helada`, `_bloqueadas`, `_poner_canal` y `_img_estado` son
los que lee y escribe `Lanzador3D`** (nombres en el diario del 6/10).
