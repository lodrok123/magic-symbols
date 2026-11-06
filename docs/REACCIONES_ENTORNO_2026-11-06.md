# Reacciones con el entorno: cobertura actual e integración (6/11/2026)

Contraste entre `REACCIONES_ENTORNO_PROPUESTA_PABLO_2026-11-06.md` (el diseño de Pablo, v1.1) y lo que hay hoy en el repo. Los ejemplos del diseño no se toman al pie de la letra: lo que se integra es el **principio** (elemento × material × estado × dosis, por datos) sobre lo que ya existe, con los cambios más pequeños posibles.

## 0. Decisiones de integración (las que no cambian el diseño, solo cómo se aterriza)

| Diseño (§) | Hoy | Decisión |
|---|---|---|
| Vector de estado continuo `(w, θ, q, g, f, b)` con umbrales e histéresis (§2.2, §5) | Estados **discretos con reloj** (`EstadosSuelo3D.DURA`), transiciones por tabla (`TRANSICIONES`), materiales por casilla (`REACCION_MATERIAL`) | **Se mantiene el modelo discreto.** La «dosis» se expresa como lo que ya hace el juego: dos aguas hielan, el barril necesita calor, el muro agrietado necesita N pedradas. Donde el diseño pide umbral (madera mojada tarda en prender), se añade un **contador de dosis por objeto** en `Reactivo3D`, no un vector continuo. Motivo: 19 mapas, 630 piezas, la previsión y los puzles ya razonan en estados sí/no; un modelo continuo los rehace todos. |
| `MaterialReactivo` como `Resource` con 17 campos (§2.1) | `Reactivo3D.PAPELES_POR_TIPO` (inflamable, propaga_llama, apaga, mojable, pesado, conduce, congelable, fuente_fuego, activable, recibe_agua, sacudible, helable), `MATERIAL_POR_TIPO`, `Materia.reaccion` (material × propiedad) | **Los papeles SON los rasgos.** Se completan los dos que están declarados y no se leen (`conduce`, `congelable`) y `reaccion_a` cae en `Materia.reaccion` para lo que los papeles no cubren (magma, naturaleza, hielo sobre metal/cristal). Nada de `Resource` nuevo. |
| Motor central `reacciones_elementales_3d.gd` + `ContactoElemental` (§9) | `Mundo3D.aplicar_accion` → `ReaccionesAgua3D` / `ReaccionesSuelo3D`; `on_spell_hit` en cada objeto; `Combate3D.decidir_golpe`; `HechizoVivo.CRUCES` | **No se crea motor nuevo.** Las tres entradas (suelo, objeto, enemigo) ya son tablas; se amplían con las filas de magma, naturaleza y hielo que faltan. |
| Eventos `ignited`, `extinguished`, `electrified`, `grown`, `frozen`, `muddied`, `broken` (§5.6) | `Mundo3D.avisar_reaccion` con catálogo cerrado `R_*` (prendido, apagado_agua, consumido, mojado, secado, congelado, derretido, electrocutado, roto, llamarada, cegado…) | Es lo mismo con otros nombres. Se añade **`R_ENRAIZADO`** (naturaleza) y **`R_COSTRA`** (magma que se enfría). `R_APAGADO_VIENTO` existe y nadie lo emite: el viento sobre una llama débil lo emitirá. |
| Presupuestos (§10): profundidad 4, 24 reacciones/tick, 16 nodos conductores, 8 estructuras | `MAX_ARDIENDO`, `Hechizo.MAX_PROFUNDIDAD`, `MAX_BARRERAS_VIVAS` 3, `_descarga` por agua conectada (sin tope de nodos), contagio de `Reactivo3D` cada 0,8 s | Faltan dos topes: **nodos por descarga** y **brotes por hechizo de naturaleza**. Se añaden como constantes. |
| Glifos Radio, Elevación (§0, §8) | `altura`, `linea`, `levitacion` (receta antigua); «radio» no existe: el radio sale de la potencia | **No se añaden glifos** (la tabla está en 14 y el golden depende de ella; ver decisión de C3). Elevación = `levitacion` cuando se rescate. |
| Barro (§1, §4 `MUD`) | Descartado por Pablo (agua + tierra = naturaleza) | No se implementa. «Suelo embarrado» del diseño pasa a ser **tierra mojada**, que ya ralentiza si se quiere con `FACTOR_VELOCIDAD`. |

## 0 bis. Dos criterios de Pablo por encima de todo (suelo)

1. **Legible.** Un hechizo de agua no moja todo el escenario: cada impacto marca como mucho `MAX_CASILLAS_POR_IMPACTO` casillas (las más cercanas al punto), y cada estado tiene un tope global `MAX_CASILLAS_VIVAS`.
2. **Propagación controlada y rendimiento.** Los estados más viejos se retiran poco a poco: al pasar el tope se desaloja primero la casilla con menos reloj, y `avanzar` retira `DESALOJO_POR_TICK` por tick (gradual, no un corte). La propagación (fuego de hierba, germinar) nunca pasa de `PROPAGA_POR_TICK` casillas por tick ni de `MAX_ARDIENDO`.

Estas constantes viven en `EstadosSuelo3D` (bloque R1) y la previsión no promete casillas que el tope recorte.

## 1. Cobertura por punto del diseño

Leyenda: ✅ existe · 🟡 existe a medias · ❌ no existe · ➕ se integra ahora (bloques R1-R3 de §2).

### 1.1 Elementos y fusiones (§1, §1.1)
- ✅ 4 sellos base, 4 derivados por `CombosSellos.TABLA`; fuego+agua y tierra+viento se anulan **en la receta** (no se lanza, no se cobra).
- ✅ Dos hechizos independientes sí reaccionan en el mundo (`HechizoVivo.CRUCES`: fuego×agua, viento×fuego, rayo×agua).
- 🟡 Magma y naturaleza solo existen como runa y daño: **no tienen fila en el suelo ni en el enemigo** (`ReaccionesSuelo3D.ACCION_DE` no los conoce; `decidir_golpe` los trata por etiquetas heredadas). ➕ R1, R3.

### 1.2 Rasgos del material (§2.1)
- ✅ Suelo: `MATERIALES` (hierba, roca, tierra, madera, agua, arena), `MATERIAL_DE_LETRA`, `; material x y mat` en el mapa.
- ✅ Objetos: `PAPELES_POR_TIPO`, `COMBUSTIBLES` (fuel), `MATERIAL_POR_TIPO`.
- 🟡 `conduce` y `congelable` declarados y no leídos. ➕ R2.
- 🟡 `Materia.reaccion` (madera, vegetal, tela, piedra, metal, cristal × calor/frío/agua/rayo/viento) solo lo usan pruebas. ➕ R2 la usa como respaldo de `reaccion_a`.
- ❌ `permanent_changes_allowed`: hoy lo permanente es por puzle (flags). Se queda así (decisión §0).

### 1.3 Estado cambiante (§2.2) y umbrales (§4)
- ✅ Suelo: helada, electrificada, quemada, mojada, segada, escombro, vapor; relojes; `AL_CADUCAR`.
- ✅ Enemigo: quemando, mojado, congelado, lento, cegado, aturdido, envenenado, roto (reacción).
- ✅ `WET`/`FREEZE`/`ELECTRIFY`/`IGNITE`/`STEAM` como transiciones de tabla; `BREAK` en muro agrietado y rompibles.
- 🟡 `IGNITE` con humedad: la hierba mojada no prende (✅) y el objeto mojado se apaga (✅), pero **no hay «dosis»: la madera mojada prende al primer fuego en cuanto se seca**. ➕ R2: contador `dosis_calor` en `Reactivo3D` (mojable: 2 fuegos; seco: 1).
- ❌ `GROW`/`ROOT`: no hay crecimiento ni enraizado. ➕ R1 (suelo: naturaleza germina en tierra mojada y brota en hierba), R3 (enemigo enraizado).
- ❌ `MAGMA_CRUST`: no hay costra. ➕ R1: magma sobre agua/mojada = vapor + **escombro** (reutilizado como costra, 6 s, bloquea proyectiles, frena).
- ❌ `SLIP`: el suelo helado no resbala. Pendiente de decisión (hoy `FACTOR_VELOCIDAD` solo frena; resbalar pide control de inercia en `Jugador3D`).

### 1.4 Tipos de interacción (§2.3)
- ✅ Puntual (proyectil), continuo (barrera/campo con `intervalo`), volumétrico (zonas, charco, vapor), vecindad (contagio de fuego, agua conectada para el rayo), mecanismos (`Puzle3D`), contra estado previo (`TRANSICIONES` con `con`/`sin`).

### 1.5 Matriz elemento × material (§3.1, §3.2)
Lo que hoy decide cada cruce (las filas del diseño que no aparecen son «—» o están cubiertas por el daño normal):

| Objetivo | Fuego | Agua | Tierra | Viento | Magma | Rayo | Naturaleza | Hielo |
|---|---|---|---|---|---|---|---|---|
| Hierba | ✅ prende/propaga | ✅ moja / brota fina | ✅ escombro | ✅ aviva / limpia | ➕ R1 = fuego | ✅ arde si mojada | ➕ R1 brota | ✅ hiela |
| Tierra / arena | ✅ seca charco | ✅ moja (arena seca ×2) | ✅ escombro | ✅ limpia | ➕ R1 calor + costra | ✅ electrifica si mojada | ➕ R1 germina si mojada (pasa a hierba) | ✅ hiela charco |
| Roca | — | — | — | — | ➕ R1 = calor | — | — | — |
| Madera (puente, seto, puerta goblin, tronco) | ✅ prende | ✅ apaga/moja | — | ✅ aviva | ➕ R2 = fuego fuerte | ✅ prende | ➕ R2 enreda (traba) | ✅ hiela telaraña; ➕ R2 escarcha |
| Agua / charco | ✅ evapora | ✅ sube nivel (sim) | ✅ no actúa | ✅ ondas (sim) | ➕ R1 vapor + costra | ✅ electrifica red | — | ✅ placa de hielo |
| Metal (nexo, emisor, reja) | — | ✅ nexo conduce 30 s | — | — | ➕ R2 calienta | ✅ conduce | — | ➕ R2 escarcha |
| Cristal (cristal pulso, veta) | ✅ late | ✅ late | ✅ veta mineral | — | — | ✅ carga | — | ✅ late |
| Tela / cuerda | ✅ arde y cae | ✅ apaga | — | — | ➕ R2 = fuego | ✅ prende | — | ➕ R2 rigidiza (no cae) |
| Mecanismo (pulsador, compuerta, molino, brasero, trampa) | ✅ brasero, compuerta | ✅ pulsador agua, molino, trampa | ✅ placa de peso | ✅ colmena, nido, bloque | ➕ R2 = fuego | ✅ emisor | — | ✅ trampa |
| Enemigo normal | ✅ quema | ✅ moja | ✅ lento | ✅ empuja/interrumpe | ➕ R3 quema + lento | ✅ electrocuta | ➕ R3 envenena + enraíza | ✅ congela |
| Enemigo mojado | ✅ vapor, seca | ✅ refuerza | — | ✅ seca | ➕ R3 | ✅ ×1,5 y salta | ➕ R3 enraíza más tiempo | ✅ congela ×1,5 |
| Hechizo vivo | ✅ CRUCES | ✅ CRUCES | ✅ barrera bloquea | ✅ CRUCES | ➕ R3 magma × agua = vapor + costra | ✅ CRUCES | — | — |

### 1.6 Elemento × elemento en el mundo (§3.4)
- ✅ Los tres cruces de `CRUCES` y los de burbuja (`REACCIONES_BURBUJA`). El resto son «—» por diseño (sin fusión espontánea), salvo **magma × agua** (➕ R3) y **fuego × naturaleza** (quema brotes: ➕ R1 vía material hierba).

### 1.7 Transiciones con orden (§5.6)
- ✅ `TRANSICIONES` gana la primera fila; `decidir_golpe` tiene orden fijo; `PRIORIDAD_ENEMIGO` para la previsión. No se cambia.

### 1.8 Objetos del diseño (§6) que no tienen pieza
Antorcha (= brasero), cadena, puerta de madera reactiva (= compuerta con `abre_con`/`cierra_con`), semilla, pared agrietada con raíces, lago helado con agujero (= helada + calor), tubería, cofre enterrado, nido de papel (= colmena). **Solo la cadena conductora y la semilla** no tienen equivalente; se dejan para cuando un nivel las pida (la cadena es un `nexo` en línea; la semilla es `recolectable` con reacción naturaleza).

### 1.9 Puzles (§7, §9)
- ✅ `Puzle3D`: señales, condiciones `casilla(x,y).<estado>`, flags, `zona.poner`.
- 🟡 `ESTADOS_CASILLA` no conoce `escombro` ni `vapor`. ➕ R1.
- ✅ «Mismo estado por distintos hechizos»: la placa de peso acepta roca del mundo o bloque de tierra (`BloqueEmpujable3D`, `pulsador modo=presencia`).

### 1.10 Previsión (§5.6 eventos → VFX)
- ✅ `PrevisionHechizo` + `PrevisionReaccion3D.ESTILO`. ➕ R1/R3 añaden rótulos: «Germina», «Costra», «Enraíza».

## 2. Plan de integración (hoy)

| Bloque | Qué | Archivos | Prueba |
|---|---|---|---|
| **R1 suelo** | `ACCION_DE` magma (calor + escombro como costra sobre agua/mojada) y naturaleza (brota en hierba; germina en tierra mojada → `poner_material(hierba)` + mojada); filas de `REACCION_MATERIAL` para hielo, rayo, magma, naturaleza; el autómata de hierba pregunta `propaga_fuego` (la madera arde sola); `Puzle3D.ESTADOS_CASILLA` += escombro, vapor; `ESTILO` germina/costra | `mundo/estados_suelo_3d.gd`, `mundo/reacciones_suelo_3d.gd`, `presentacion/prueba_test2.gd`, `escenas/puzle.gd`, `presentacion/prevision_reaccion_3d.gd` | `prueba_reacciones_entorno_suelo.gd` |
| **R2 objetos** | `Reactivo3D`: papel `conduce` (mojado → `Terreno3D.conductores` 30 s, como el nexo), `congelable` (hielo lo hiela: inmóvil/no activable X s), `dosis_calor` (mojable pide 2 calores), respaldo `Materia.reaccion` para magma/naturaleza/hielo (magma = calor fuerte, naturaleza enreda/traba lo activable y lo sacudible, hielo escarcha metal/tela) | `objetos/objetos_3d.gd`, `nucleo/materia.gd`, `nucleo/objetos.gd`, `objetos/cuerda_3d.gd` | `prueba_reacciones_entorno_objetos.gd` |
| **R3 enemigo y cruces** | `decidir_golpe`: magma = quema + lento; naturaleza = `enraizado` (no se mueve `ENRAIZADO_S` 1,5 s, ×2 si mojado; el fuego lo libera) con `R_ENRAIZADO`; `CRUCES` magma×agua = vapor + costra; tope `MAX_NODOS_DESCARGA`; previsión y tinta | `enemigos/combate_3d.gd`, `mundo/mundo_3d.gd`, `magia/hechizo_vivo.gd`, `magia/prevision_hechizo.gd`, `nucleo/tinta*.gd`, `presentacion/feedback_reaccion_3d.gd`, `presentacion/reacciones_vfx_3d.gd` | `prueba_reacciones_entorno_enemigo.gd` |

## 2 bis. Arte que se usa (decisión de Pablo, 6/11)
- **Magma** (costra del suelo y VFX): la roca estilizada ennegrecida, `arte/meshy/aprobacion3d/rocas_estilizadas/texturas/rocas_magma_{albedo,emisivo,normal,rough}.png` (y las piezas `roca_est_magma_*.glb` / `piedra_est_magma_*.glb` si la costra lleva volumen). Engancharla en cuanto R1 cierre `estados_suelo_3d.gd`.
- **Pendiente de Pablo:** textura de escombro (pedrada), hoja de vapor; opcionales: runas de magma y naturaleza, hoja de naturaleza, hierba con brotes.

## 3. Decisiones pendientes de Pablo (del §12 del diseño)
1. **Resbalar** sobre hielo (`SLIP`): ¿sí (inercia en `Jugador3D`) o solo frenar?
2. **Naturaleza de la nada**: hoy germina solo en tierra MOJADA y brota en hierba; en roca y arena no hace nada. ¿Vale?
3. **Costra de magma** = escombro 6 s (bloquea proyectiles, frena). ¿Basta o quieres estado propio «roca» transitable sobre agua?
4. **Cadena conductora** y **semilla**: solo cuando un nivel las pida.
5. Rasgo `permanent_changes_allowed`: sigue siendo cosa de flags de puzle.
