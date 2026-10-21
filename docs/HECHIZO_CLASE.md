# La clase `Hechizo`: un solo sitio donde se construye un hechizo (18/10/2026, Juego)

Pablo (18/10, 15:46): una clase principal `Hechizo` que reciba los parámetros del elemento y de los glifos y desde la
que se construya el hechizo. De base, cada parámetro vale 0 o un valor por defecto. Con su lista de parámetros
(movimiento, daño, comportamientos, estados, colisión y visual, eventos). **Responsable: Juego.** Nombres en español
(regla del proyecto); los eventos van en la fase 4.

## 1. Por qué (medido el 18/10)

Hoy un hechizo se decide en seis sitios que se pasan diccionarios:

| dónde | qué decide |
|---|---|
| `Sigils.aplicar_v2` (`GLIFOS_V2`) | semiejes X/Y/Z, viaja, solidez, copias, rebotes, crece |
| `RuneData` + `*_rune.tres` | daño, etiquetas, estado de la materia, persiste, empuje, pisable, deja |
| `Receta3D` (hereda de la `SpellRecipe` del 2D) | recarga, calidad del trazo, vida |
| `Lanzador3D` (158 KB): `_materializar_v2`, `_eventos_v2`, `_materia_*`, `trazar`, `_golpear` | materialización, movimiento, choques, golpe |
| `Combate3D.golpe` | duraciones de estado escritas a mano (quemado 3 s, mojado 6 s, congelado 1,5/2,5 s, aturdido 1,2 s, lento 3 s), fuerza por elemento |
| `Tinta.coste_receta`, `CastPoints` | coste, lanzamiento |

Añadir un parámetro hoy obliga a tocar varios de esos sitios. Con `Hechizo` se toca uno.

## 2. Diseño

### 2.1 Tres piezas

1. **`Hechizo`** (`nucleo/hechizo.gd`, `RefCounted`, datos puros): todos los campos con su valor por defecto. Se construye
   con `Hechizo.construir(elemento: RuneData, glifos: Dictionary, calidad: float) -> Hechizo`, en un orden fijo:
   1. valores por defecto;
   2. modificadores del elemento;
   3. modificadores de los glifos, primero las sumas y después las multiplicaciones;
   4. topes;
   5. derivados (forma, coste, recarga, cast point, nombre).

   Funciones: `a_diccionario()` para PlayLog, el lab y las pruebas, y `describir()` para depurar.
2. **Modificadores, el mismo idioma para glifos y elementos:** `{campo: {"op": "suma"|"multiplica"|"fija", "valor": v,
   "tope": t}}`.
   - `GLIFOS_V2` pasa a ser `Sigils.GLIFOS` con una lista de modificadores por glifo.
   - Los `.tres` de elemento ganan un `@export var modificadores: Dictionary`.
   - Los campos de `RuneData` de hoy (`damage`, `persiste`, `empuje`…) se leen como modificadores mientras existan.
   - **Un glifo o elemento nuevo es solo datos.**
3. **`HechizoVivo`** (`magia/hechizo_vivo.gd`, `Node3D`): ejecuta un `Hechizo`.
   - Nace en el origen del cast point, crece, se mueve (velocidad, aceleración, gravedad, buscar objetivo, rebotes,
     retorno), ocupa sus casillas según el estado de la materia (`_materia_*` se muda aquí) y choca.
   - Aplica el golpe con los campos del hechizo y dispara los eventos.
   - **Su estado en marcha** (posición, rotación, velocidad actual, objetivo, golpes dados) vive aquí, no en la definición.
   - El `Lanzador3D` solo conjura y lo crea: `HechizoVivo.crear(hechizo, origen, dir, lanzador)`.
   - `Combate3D.golpe` recibe el `Hechizo` (o un `Golpe` con sus campos) en lugar de un `RuneData`.

### 2.2 Campos

Los nombres de Pablo, traducidos. Marcas: ✓ = ya existe en otro sitio (se muda) · ◇ = nuevo · ⧗ = después.

**Forma y volumen**

| campo | defecto | qué es | de |
|---|---|---|---|
| `semiejes` (Vector3) | (r, r, r) | volumen elipsoide: hitbox y tamaño visual a la vez | ✓ glifos de eje |
| `copias` | 1 | n volúmenes repartidos en X | ✓ repetición |
| `crece` | 0 | escala por segundo al nacer | ✓ pulso |
| `solidez` | 1 | bloquea y aguanta golpes | ✓ barrera |

**Movimiento** (`viaja` de hoy = `distancia_max` > 0)

| campo | defecto | qué es | de |
|---|---|---|---|
| `velocidad` | 0 (quieto) | u/s | ✓ (hoy fija en Lanzador/VFX) |
| `aceleracion` | 0 | u/s² (negativa = frena) | ◇ |
| `gravedad` | 0 | caída: 1 = como un objeto | ◇ |
| `distancia_max` | 0 | casillas que recorre | ✓ flecha |
| `persiste` | del elemento | s que vive | ✓ |
| `rebotes` | 0 | cambios de dirección al chocar | ✓ rebote |
| `retorna` | false | vuelve al lanzador al acabar (búmeran) | ◇ |
| `busca` | 0 | fuerza de giro hacia un objetivo (0 = recto) | ◇ |

**Daño y combate** (`tipo de daño` = el elemento)

| campo | defecto | qué es | de |
|---|---|---|---|
| `dano` | del elemento | daño base × calidad | ✓ |
| `empuje` | del elemento | fuerza al golpear (luego `Combate3D` aplica ×2 y suelo) | ✓ |
| `perfora` | 0 | enemigos que atraviesa antes de pararse | ◇ |
| `radio_explosion` | 0 | casillas de daño en área al golpear | ◇ (se hace con un evento, §2.3) |
| `golpea_lanzador` | false | puede herir a quien lo lanzó | ◇ |
| `critico` | — | ⧗ podría salir de la calidad del trazo | ⧗ |
| `perfora_armadura`, `robo_vida` | — | sin sistema de armadura ni curación por golpe aún | ⧗ |

**Estados** (los que hoy están escritos a mano en `Combate3D.golpe`)

| campo | defecto | qué es | de |
|---|---|---|---|
| `quema` | 0 s | duración del quemado | ✓ fuego 3 s |
| `moja` | 0 s | duración del mojado | ✓ agua 6 s |
| `congela` | 0 s | congelado (más si estaba mojado) | ✓ hielo 1,5 / 2,5 s |
| `aturde` | 0 s | aturdido | ✓ eléctrico 1,2 s |
| `ralentiza` | 0 (0–1) | porcentaje de lentitud y su duración | ✓ tierra 3 s |
| `interrumpe` | 0 s | corta el ataque enemigo | ✓ viento 0,7 s |
| `veneno` | 0 | daño por segundo y duración | ◇ |
| `deja` | del elemento | estado de suelo que deja | ✓ |

**Choque y aspecto**

| campo | defecto | qué es | de |
|---|---|---|---|
| `choca_con` | mundo + enemigos | máscara: qué lo para | ◇ (hoy implícito) |
| `color` | del elemento | | ✓ |
| `estela`, `efecto_impacto` | "" | nombre de VFX (lo resuelve el Pipeline) | ◇ |

**Lanzamiento y coste** (derivados, no se modifican a mano)

`forma` (x_mano / alto / abajo), `cast_point` (variación de `CastPoints`), `coste` (tinta, ∝ volumen y propiedades),
`recarga`, `calidad`.

### 2.3 Eventos (fase 4)

`al_nacer`, `al_golpear`, `al_matar`, `al_expirar`, `al_rebotar`, `al_viajar` (cada N casillas). Cada uno es una
**lista de acciones de un catálogo fijo y pequeño**, en datos y nunca en código por combinación:

| acción | parámetros | da |
|---|---|---|
| `danar_area` | radio, dano | explosión, salpicadura |
| `crear_hijo` | cuántos, abanico, hechizo (copia con cambios) | dividirse, encadenar (hijo con `busca` al enemigo más cercano), metralla |
| `estado_suelo` | estado, radio | rastro (con `al_viajar`), charco |
| `sonido`, `vfx` | nombre | |
| `curar_lanzador` | cantidad | robo de vida (⧗) |

**Límites:**
- profundidad de hijos ≤ 2;
- ≤ 32 hechizos vivos por lanzamiento;
- los eventos de un hijo no vuelven a crear al padre.

Así, *dividirse en 3 al golpear* o *explotar al expirar* son una línea en la tabla de un glifo.

### 2.4 Qué NO cambia

- La receta v2 como idea (volumen × propiedades × elemento).
- El grimorio y el reconocedor.
- `conjuro_fase`, la señal `hechizo_v2`: la emite `HechizoVivo` con los mismos campos.
- `CastPoints`, `VfxEstado3D`, `ConjuroVfx3D`.

El Pipeline no tiene que tocar nada hasta la fase 4 (VFX de estela e impacto por nombre).

## 3. Plan por fases (Juego)

| fase | qué | cambia lo que se ve | prueba |
|---|---|---|---|
| **HC1** | `Hechizo` + `construir()` + modificadores en `Sigils.GLIFOS` y `RuneData`, envolviendo lo de hoy | no | `prueba_hechizo.gd`: para TODAS las combinaciones de hasta 4 glifos × 7 elementos, los mismos números que `aplicar_v2` + `RuneData` + `Receta3D` (semiejes, props, persiste, daño, coste, recarga, forma) |
| **HC2** | `HechizoVivo` sustituye a `_materializar_v2` / `_eventos_v2` / `_materia_*`; `Lanzador3D` solo conjura y crea | no (mismo resultado) | `prueba_receta_v2`, `prueba_materia_v2`, `escenario_lab_hechizos`, `escenario_puzles_agua` y `_fuego` a 0 |
| **HC3** | `Combate3D.golpe(golpe)` lee estados, daño y empuje del hechizo; las duraciones salen de los `.tres` | no (mismos valores) | prueba de combate: mismo daño, empuje y estados por elemento que hoy |
| **HC4** | campos nuevos uno a uno (velocidad, aceleración, gravedad, retorna, busca, perfora, veneno, golpea_lanzador) + eventos y catálogo de acciones | sí | una prueba por campo y por acción; barrido del lab sin «receta_rara» nuevas |
| **HC5** | lab: la pestaña F1 enseña la tabla completa del `Hechizo` construido (campo, valor, de dónde viene) y deja tocar cualquier campo en vivo | herramienta | `escenario_lab_hechizos` |

HC1–HC3 son **refactorización pura**: ningún cambio de comportamiento, comprobado con pruebas de igualdad. Así, si
algo se rompe, se sabe que es la mudanza y no una regla nueva. HC4 y HC5 añaden.

## 4. Prompts (todos para Juego)

**HC1**
```
Contexto Juego. Lee docs/HECHIZO_CLASE.md (proyecto) entero, GLIFOS_RECETA.md y las últimas entradas de docs/DIARIO.md.
Crea nucleo/hechizo.gd (class_name Hechizo, RefCounted, datos puros, nombres en español):
- los campos de §2.2 con sus defectos;
- Hechizo.construir(elemento: RuneData, glifos: Dictionary, calidad: float) en el orden de §2.1 (defectos → elemento → glifos: sumas y luego multiplicaciones → topes → derivados);
- a_diccionario() y describir().
Modificadores con el formato {campo: {op, valor, tope}}:
- Sigils.GLIFOS_V2 se reescribe así, conservando las claves de hoy (linea_x, linea_z, altura, flecha, barrera, repeticion, rebote, pulso) y su efecto exacto;
- RuneData gana @export var modificadores: Dictionary;
- los campos de hoy (damage, persiste, empuje, pisable, deja, estado) se traducen a modificadores al construir, así que no hay que tocar los .tres en esta fase;
- las duraciones de estado de Combate3D.golpe pasan a ser modificadores del elemento en una tabla de transición dentro de Hechizo (fuego quema 3, agua moja 6, hielo congela 1,5 / 2,5 si mojado, eléctrico aturde 1,2, tierra ralentiza 3 s, viento interrumpe 0,7).
No cambies a nadie que use aplicar_v2 todavía: Hechizo convive.
Prueba herramientas/prueba_hechizo.gd: todas las combinaciones de hasta 4 glifos × 7 elementos dan los mismos semiejes, propiedades, persiste, daño, coste, recarga y forma que el camino de hoy (aplicar_v2 + RuneData + Receta3D), con tolerancia 1e-4.
Diario. Sin commit. Recordar a Pablo abrir el editor (clase nueva).
```

**HC2**
```
Contexto Juego. Requiere HC1. Lee docs/HECHIZO_CLASE.md §2.1 y §2.4.
Crea magia/hechizo_vivo.gd (class_name HechizoVivo, Node3D) que ejecuta un Hechizo:
- nace en el cast point, crece, viaja, rebota y persiste;
- ocupa casillas según el estado de la materia (mueve aquí _materia_solido/liquido/plasma/energia/gas/campo y _eventos_v2);
- choca y golpea;
- emite Lanzador3D.hechizo_v2 con los mismos campos que hoy (persiste, suelo, eventos, celdas…) para que VfxEstado3D no cambie.
Lanzador3D:
- construye el Hechizo con Hechizo.construir (receta del libro o del lab) y llama HechizoVivo.crear(hechizo, origen, dir, self);
- borra _materializar_v2 y lo que se haya mudado;
- lanzar_receta (lab) pasa a aceptar un Hechizo.
Sin cambio de comportamiento: prueba_receta_v2, prueba_materia_v2, prueba_hechizo, escenario_lab_hechizos, escenario_puzles_agua, escenario_puzles_fuego y escenario_libro a 0. Mide el tamaño de lanzador_3d.gd antes y después.
Diario. Sin commit.
```

**HC3**
```
Contexto Juego. Requiere HC2. Lee docs/HECHIZO_CLASE.md §2.2 (Estados).
Combate3D.golpe recibe un Golpe (o el Hechizo + punto + dir) en vez de RuneData y lee de ahí:
- daño;
- empuje (antes de MULT_EMPUJE y el suelo, que siguen en Combate3D);
- quema, moja, congela, aturde, ralentiza, interrumpe.
Las reglas de interacción que dependen del estado del ENEMIGO (vapor si está mojado y le da fuego, +daño de rayo mojado, congelado más largo si mojado, el elemental curado por agua) se quedan en Combate3D, porque son del que recibe y no del hechizo.
Mueve la tabla de transición de HC1 a modificadores en los siete *_rune.tres (mismos valores).
Los reactivos (Reactivo3D) y el agua siguen con on_spell_hit(rune_data): no se tocan en esta fase.
Prueba: mismo daño, empuje y estados por elemento que antes (tabla medida antes del cambio). Regresión a 0. Diario. Sin commit.
```

**HC4**
```
Contexto Juego. Requiere HC3. Lee docs/HECHIZO_CLASE.md §2.2 (◇) y §2.3.
Implementa en HechizoVivo, uno a uno y con su prueba cada uno:
- campos: velocidad, aceleracion, gravedad, retorna, busca (objetivo más cercano en un cono), perfora, veneno, golpea_lanzador, choca_con, estela, efecto_impacto;
- eventos: al_nacer, al_golpear, al_matar, al_expirar, al_rebotar, al_viajar, con el catálogo de acciones (danar_area, crear_hijo, estado_suelo, sonido, vfx) y los límites de §2.3 (profundidad 2, 32 vivos).
Ningún glifo existente cambia de efecto. Los campos nuevos quedan disponibles para glifos futuros (perforar ᚦ, marca ᚨ, retorno ᛃ… de MEJORAS_POTENCIA §6) pero NO se asignan a runas sin que Pablo lo diga.
estela y efecto_impacto son nombres: pide al Pipeline por el diario que VfxEstado3D/Vfx3D los resuelva.
Barrido del lab sin receta_rara nuevas. Diario. Sin commit.
```

**HC5**
```
Contexto Juego. Requiere HC1 (mejor tras HC4). Lee docs/HECHIZO_CLASE.md §3.
En la pestaña F1 de LabHechizos3D, un panel con la tabla completa del Hechizo construido:
- por campo: valor, defecto y de dónde viene (elemento / glifo / derivado);
- los campos que difieren del defecto, resaltados.
Cualquier campo se puede sobrescribir en vivo (↑/↓ elige, ←/→ cambia, Retroceso restaura), y el siguiente lanzamiento usa el valor tocado. G guarda en user://lab_hechizos.json y P imprime los cambios como modificadores listos para pegar en Sigils.GLIFOS o en un .tres.
escenario_lab_hechizos ampliado. Diario. Sin commit.
```

## 5. Para Pablo

- Abrir el editor después de HC1 y HC2 (clases nuevas).
- HC1–HC3 no deberían cambiar nada visible: si algo cambia, es un fallo de la mudanza, no una regla nueva.
- Con HC4 y HC5 puedes inventar hechizos tocando campos en el lab y, cuando te guste uno, decidir qué glifo lo da.

— Juego
