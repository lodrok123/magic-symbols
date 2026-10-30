# Plan: mejorar el sistema de hechizos (29/10/2026, Juego)

Propuesta de Pablo en ocho frentes (construcción única, orden de ejecución, daño independiente, tinta por propiedades, glifos
nuevos, propiedades físicas, interfaz del grimorio, pruebas de regresión), contrastada con el código de hoy: `nucleo/hechizo.gd`,
`nucleo/sigils.gd`, `nucleo/dano.gd`, `magia/hechizo_vivo.gd`, `magia/lanzador_3d.gd` (`Receta3D`), `enemigos/combate_3d.gd`,
`objetos/objetos_3d.gd`, los `*_rune.tres` y las pruebas de `herramientas/`. Docs vigentes: `ESPEC_HECHIZO.md`, `GLIFOS_RECETA.md`,
`HECHIZO_CLASE.md`, `DANO_Y_TINTA.md`, `MEJORAS_POTENCIA.md` §5-6.

**Resumen:** de los ocho puntos, cuatro están **más hechos de lo que la propuesta supone** (1, 2, 5 y 8 tienen ya la mitad del
camino andado) y dos **chocan con decisiones recientes de Pablo** (3 con el daño por potencia del 29/10; 5 con el aparcado de
«retardo» del 17/10). El plan propone **cambiar el orden**: primero fijar la red de pruebas (8), después quitar la construcción
duplicada (1) y unificar el despachador (2), y dejar para el final lo más grande y arriesgado (6, materiales).

---

## 1. Lo que hay hoy, punto a punto

### 1.1 Construcción única — HECHO A MEDIAS

Existe ya un único constructor, `Hechizo.construir(elemento, glifos, calidad)`, y `HechizoVivo` lo ejecuta. Pero un lanzamiento del
libro construye el `Hechizo` **cuatro veces** y mantiene **un camino paralelo**:

| dónde | qué construye | para qué |
|---|---|---|
| `Lanzador3D._preparar_pagina` (869) | `receta.hechizo(element_data)` | solo para leer `en_punto` |
| `Lanzador3D.rechazo_de_construccion` (2352) | `receta.hechizo(rune)` | sólido quieto, alcance |
| `Lanzador3D.hechizo_de` (1392) ← `_disparar` | `receta.hechizo(rune)` + pigmento | el que se lanza |
| `PrevisionHechizo.prever` (152) | `lanzador.hechizo_de(datos)` | cada fotograma al apuntar |

Y `Receta3D` (dentro de `lanzador_3d.gd`, hereda del `SpellRecipe` del 2D) calcula por su cuenta `geo()` (`GeometriaV2.evaluar` =
`Sigils.aplicar_v2` + `GLIFOS_V2`), `coste_tinta()` (`Dano.tinta(n_glifos(), recargos)`), `cooldown` (`Sigils.cooldown_v2`) y sincroniza
los campos antiguos (`travels`, `spread`, `blocks`, `lifetime`, `bounces`, `pull`…) que todavía leen `_crear_campo`, `es_barrera_cupula`,
`_barrido` y `_una_ola` (el camino «Campo» del 2D: hoy solo lo usan `prueba_barrera` y `guardian_barrera_3d`). La tinta se cobra con
`receta.coste_tinta()`, no con `hechizo.coste_tinta`; coinciden porque `prueba_hechizo` compara las dos tablas (`GLIFOS` y `GLIFOS_V2`)
en 495 × 6 × 2 combinaciones. Es decir: **la coherencia existe, pero la sostiene una prueba, no el diseño.**

`Receta3D` aparece en 28 archivos (93 usos): lanzador, 4 laboratorios, grimorio, spellbook, previsión, tinta, dano, y 15 pruebas.

### 1.2 Orden de ejecución — HECHO A MEDIAS

El momento de ejecución ya es un dato del glifo (`momento`, `momento_si`, `paso`, `accion`), `Hechizo.acciones_en(momento)` ordena por
paso y por tabla (nunca por orden de dibujo: la receta es un multiconjunto) y `HechizoVivo._momento` impide reentradas. Lo que falta:

- **Dos despachadores con dos catálogos.** `disparar_evento` → `_accion` (eventos HC4: `al_nacer`, `al_golpear`, `al_matar`,
  `al_expirar`, `al_rebotar`, `al_viajar`; catálogo `Hechizo.ACCIONES` = danar_area, crear_hijo, estado_suelo, sonido, vfx, en el
  orden de la lista) y `_momento` (inicio/continuo/final; catálogo `HechizoVivo.ACCIONES_MOMENTO` = emitir_pulso, ordenado por paso).
  Un glifo que quiera «crear hijo al final» no puede hoy: `crear_hijo` no está en el catálogo de momentos.
- **«Final» mezcla tres cosas.** Un proyectil dispara `MOMENTO_FINAL` al pararse por golpe, por muro, por suelo o por alcance, y
  `al_expirar` salta salvo que la causa sea «golpe». La propuesta pide distinguir **impacto** (golpea algo), **detención** (se para
  sin golpear: muro, suelo, alcance, frenado) y **extinción** (acaba su vida). Hoy `motivo_fin` ya guarda la causa; falta que el
  despachador la use.
- `_contacto_celdas` (29/10) ya resuelve de dónde sale el pulso al pararse: vale para los tres casos.

### 1.3 Daño independiente — CHOCA CON UNA DECISIÓN DEL 29/10

Desde `DANO_Y_TINTA.md` el daño base es `B(potencia) × E`, con **potencia = nº de glifos de la receta** (ligera 0-1, media 2-3, alta ≥ 4).
Es exactamente lo contrario del criterio de aceptación de la propuesta («añadir Línea no aumenta el daño por impacto»): hoy una ᛁ de más
sube de ligera (12) a media (24). El gancho para «glifos con efecto propio sobre el impacto» existe (`Hechizo.potencia` = G, lo multiplica
`Combate3D.decidir_golpe`) y vale 1,0 porque ningún glifo lo toca.

**Hace falta una decisión de Pablo** (§4.1). La vía que respeta las dos cosas: potencia (y tinta) sigue contando glifos, pero **el daño
base B solo cuenta los glifos marcados como ofensivos** en la tabla (`cuenta_dano: true` en `Sigils.GLIFOS`, dato por glifo). Con todos a
`true` nada cambia; Pablo decide cuáles quitar (ᛁ, ᛏ, ᚠ, ᛉ, ᛜ son los candidatos: forma, copias, tiempo, defensa).

### 1.4 Tinta por propiedades — EN PARTE

`T = T_base(potencia) × (1 + Σ recargos)` y el único recargo es el continuo de ᚱ (+25 %), que además **no ve el elemento**
(PENDIENTES línea 62: ᚱ + tierra sin barrera late sin recargo, porque `Receta3D.coste_tinta` lee `props`, no el `Hechizo`). No hay aporte
por glifo ni recargo por instancias (copias ᚠ, hijos de `crear_hijo`) ni por efectos periódicos (`dano_periodico`, veneno). Resolver 1.1
(el coste lo da el `Hechizo`) desbloquea todo esto.

### 1.5 Glifos nuevos — LOS CAMPOS YA SE EJECUTAN

`HechizoVivo` (HC4) ya ejecuta `perfora` (golpes antes de pararse), `retorna` (vuelta al lanzador, `VIDA_RETORNO_S`), `busca` (giro hacia el
enemigo del cono, `BUSCA_COS`, `BUSCA_ALCANCE_CAS`) y `retardo` (solo en `eventos_de`, los volúmenes: **el proyectil lo ignora**, `_iniciar_proyectil`
no lo lee; es lo único de código que pide H5). Lo que falta
es solo **datos y entrada**: una línea en `Sigils.GLIFOS` por glifo, alta en `GestureLibrary.SIGILS`/`RECORDABLE` y `Repertoire`, PNG en
`Sigils.GLYPHS`, quitar `retardo` de `Receta3D.APARCADOS`, y que Pablo grabe las muestras (como ᚱ y ᛉ, PENDIENTES 61). Runas propuestas en
`MEJORAS_POTENCIA.md` §6: ᚦ thurisaz = perforar, ᛃ jera = retorno; «buscar» no tenía runa (ᚨ ansuz era «marca», un combo de dos páginas:
`busca` es más simple y encaja mejor con el campo que ya existe). **Retardo** lo aparcó Pablo el 17/10 («hasta encontrarle uso»): reactivarlo
es decisión suya (§4.2).

### 1.6 Propiedades físicas — SOLO LOS CAMPOS

`Hechizo` tiene `temperatura`, `humedad`, `conductividad`, `densidad` con sus valores propuestos en `ESPEC_HECHIZO.md` §2, pero **ningún
`.tres` los rellena y nadie los lee**. Las reacciones del mundo van por etiquetas y nombres: `rune_data.tags.has("calor"|"agua"|"frio"|
"electrico"|"viento")` en 25 archivos (66 usos: `objetos_3d.gd` 16, barril, cuerda, compuerta, lava, nexo…) y `elemento == "fuego"` en 26
archivos (87 usos: `vfx_3d.gd` 20, `vfx_estado_3d.gd` 7, `lanzador_3d.gd` 7, `combate_3d.gd` 4…). El contrato `on_spell_hit(rune_data, dir)`
recibe un `RuneData`; solo `Combate3D` y `Escudo3D` reciben además el `Hechizo`. `MEJORAS_POTENCIA.md` §5 ya tiene la tabla material × elemento.
Es el frente **más grande** (dos docenas de archivos de objetos) y el que más puede romper los puzles.

### 1.7 Interfaz del grimorio — CASI NADA

El libro (`presentacion/ui/spellbook.gd`, `ejes_receta_ui.gd`) pinta el cubo de casillas (x·y·z) y el contador de usos por glifo. La tinta, la
potencia, la recarga y los avisos («Aún sin uso», «Tinta insuficiente», altura rechazada, «Ahí no se puede construir») solo aparecen **al
intentar lanzar**, en `_preparar_pagina`. La tabla completa del `Hechizo` (HC5) solo está en el laboratorio (F1). El archivo que nombra la
propuesta (`spellcaster.gd`) es hoy la lógica de escritura; la parte «de libro» es `magia/grimorio.gd` + `spellbook.gd` + `page_hud.gd`.

### 1.8 Pruebas — HAY MUCHAS, FALTA LA RED

Sin ventana y relacionadas con hechizos: `prueba_hechizo` (igualdad de las dos tablas, 495 × 6 × 2), `prueba_hechizo_vivo`,
`prueba_ejecucion_combinaciones` (990 hechizos ejecutados en un mundo falso), `prueba_dano_tinta`, `prueba_campos_ejecutados`,
`prueba_barrido_hechizos`, `prueba_materia_v2`, `prueba_receta_v2`, `prueba_haz`, `prueba_pulso`, `prueba_reacciones`,
`prueba_colisiones_forma`, `prueba_prevision_hechizo`, `prueba_tinta`, `prueba_en_punto_proyectil`, `prueba_trayectorias`. Lo que no hay:

- una **foto fija** («golden») de los números de `Hechizo.a_diccionario()` para todas las recetas: hoy, si un cambio mueve un número, solo se
  entera la prueba que lo tenía escrito a mano (y el 29/10 hubo que tocar 20 pruebas por el daño nuevo);
- una prueba del **orden y unicidad de eventos y momentos** (cada uno una vez, mismo resultado con cualquier orden de dibujo);
- una lista nombrada del **conjunto de hechizos** para `tools\pruebas.cmd solo …` (hoy el patrón es libre).

---

## 2. Discrepancias de la propuesta con el código

| punto | la propuesta dice | lo que hay | qué hacer |
|---|---|---|---|
| 1 | tocar `spell_recipe.gd` | `SpellRecipe` es del 2D; lo vivo es `Receta3D` dentro de `lanzador_3d.gd` y el camino «Campo» que todavía lee sus campos | adaptador en `Receta3D`; `SpellRecipe` se queda para `prueba_barrera` hasta retirar «Campo» |
| 2 | «conservar momento y paso» | ya existen | lo nuevo es **un** despachador y los tres finales |
| 3 | «eliminar la dependencia del total de glifos» | la potencia por nº de glifos es decisión del 29/10 | **decisión de Pablo** (§4.1); si sigue, B cuenta solo glifos ofensivos |
| 4 | `dano.gd` + `sigils.gd` | `Dano.tinta(n, recargos)` no ve el `Hechizo` | `Dano.tinta_de(h)` tras el punto 1 |
| 5 | «activar mediante campos existentes» | cierto: perfora, retorna, busca, retardo se ejecutan | datos + muestras; `retardo` pide **decisión** (§4.2) |
| 6 | `rune_data.gd` | los campos están en `Hechizo` y en la ESPEC, no en los `.tres`; las reacciones leen `tags` | rellenar `.tres`, interfaz `Materia`, migrar objeto a objeto |
| 7 | `spellcaster.gd` | la UI es `spellbook.gd` / `page_hud.gd`; la lógica `grimorio.gd` | `Hechizo.resumen()` + pintarlo en el libro |
| 8 | «crear pruebas» | ya hay 16 | la foto fija, los eventos, y **ponerlo primero** |

---

## 3. Plan de implementación

Orden propuesto (no el de la propuesta): **H0 → H1 → H2 → H4 → H3 → H5 → H7 → H6.** H0 protege lo demás; H1 es prerrequisito de H4 y H7;
H3 y H5 esperan decisiones de Pablo y no bloquean a nadie; H6 es el más grande y va al final. Cada fase acaba con la regresión de hechizos a 0,
una entrada en el DIARIO y sin commit (como siempre).

### H0 · Red de pruebas (punto 8, parte 1)

**Archivos:** `herramientas/prueba_hechizo_golden.gd` (nueva), `herramientas/golden_hechizos.json` (nuevo, se genera), `herramientas/prueba_eventos_hechizo.gd`
(nueva), `tools/pruebas.cmd` (o `resumen_prueba.ps1`: alias `hechizos`).

- **Foto fija:** para todas las recetas de hasta 4 glifos de `Sigils.GLIFOS` × 6 elementos × 2 calidades, `Hechizo.construir(...).a_diccionario()`
  se compara con `golden_hechizos.json` (tolerancia 1e-4). Con `--regenerar` reescribe el JSON. Cualquier cambio de número pasa a ser explícito:
  se regenera a propósito y se anota en el diario qué cambió.
- **Eventos y momentos:** con `HechizoVivo.crear(..., a_mano = true)` en el mundo falso de `prueba_ejecucion_combinaciones`: cada evento de
  `eventos_vistos` y cada momento de `momentos_vistos` sale **una vez** (salvo continuo, ≤ `MAX_DISPAROS_CONTINUOS`); el mismo resultado con los
  glifos en orden inverso; `motivo_fin` ∈ {golpe, muro, suelo, alcance, tiempo, frenado, retorno} y el momento final sale de `celdas_de_contacto`.
- **Alias de suite:** `tools\pruebas.cmd solo hechizos` lanza la lista nombrada (las 16 de §1.8 + las dos nuevas).

**Aceptación:** las dos pruebas nuevas a 0 con el código de hoy; `golden_hechizos.json` generado y revisado.

### H1 · Construcción única (punto 1)

**Archivos:** `magia/lanzador_3d.gd` (`Receta3D`, `_preparar_pagina`, `rechazo_de_construccion`, `hechizo_de`, `_disparar`, `lanzar_ahora`),
`magia/prevision_hechizo.gd`, `nucleo/sigils.gd`, `nucleo/hechizo.gd`, `presentacion/ui/ejes_receta_ui.gd`, los 4 laboratorios.

1. `_preparar_pagina` construye el `Hechizo` **una vez** (con el pigmento de daño dentro de `construir` o de un `Hechizo.con_pigmento(tinta)`) y lo guarda en
   `_preparado["hechizo"]`. `rechazo_de_construccion`, `_disparar`, `PrevisionHechizo` y `en_punto` leen ese. `hechizo_de(datos)` devuelve
   `datos["hechizo"]` (y lo construye solo si falta, para los laboratorios).
2. Tinta y recarga se cobran de `hechizo.coste_tinta` y `hechizo.recarga`; `Receta3D.coste_tinta()`/`n_glifos()`/`cooldown` delegan en un `Hechizo`
   cacheado por contadores + calidad (**adaptador temporal**: `Receta3D` pasa a ser «contadores + calidad → Hechizo» y nada más).
3. `Receta3D.geo()` devuelve `hechizo.geo()`; `GeometriaV2.evaluar` y `Sigils.aplicar_v2` se quedan solo en `prueba_hechizo` hasta retirarlos.
   `GLIFOS_V2` se marca en desuso: el lab y `EjesRecetaUi` leen `GLIFOS` (`repertorio`, `cooldown`, modificadores).
4. Los campos antiguos de `SpellRecipe` que sincroniza `_sincronizar` se dejan **solo** mientras viva el camino «Campo» (`_crear_campo`,
   `_barrido`, `_una_ola`): se anota en PENDIENTES retirarlo con `prueba_barrera` y `guardian_barrera_3d`.

**Aceptación:** un contador estático de construcciones en `Hechizo` (solo pruebas) marca **1 por lanzamiento** del libro y **1 por fotograma** de previsión;
`prueba_hechizo_golden`, `prueba_dano_tinta`, `prueba_prevision_hechizo`, `prueba_tinta`, `escenario_libro` y `escenario_lab_geometrias` a 0 sin cambiar el
JSON. Grimorio, previsión y ejecución enseñan los mismos `coste_tinta`, `recarga`, `forma`, `en_punto`.

### H2 · Un despachador y tres finales (punto 2)

**Archivos:** `magia/hechizo_vivo.gd`, `nucleo/hechizo.gd`, `nucleo/sigils.gd`, `docs/GLIFOS_RECETA.md` §2.4 bis.

1. **Un catálogo:** `Hechizo.ACCIONES` absorbe `emitir_pulso`; `ACCIONES_MOMENTO` desaparece. `_momento` llama a `_accion` con `{accion, …}`.
2. **Un orden:** las acciones de un evento se ordenan con `Hechizo.ordenar_acciones` (paso, orden de tabla), las de los eventos HC4 incluidas
   (hoy van en el orden de la lista de modificadores).
3. **Momentos sobre eventos:** `inicio` = `al_nacer`; `continuo` = disparos periódicos (como hoy) ; `final` se parte en tres eventos nuevos o
   renombrados: `al_impactar` (se para por golpe: tras `al_golpear`), `al_detenerse` (muro, suelo, alcance, frenado) y `al_extinguirse`
   (acaba su vida: hoy `al_expirar`). Un glifo declara en cuál con `momento`/`momento_si` («final» = los tres, para no cambiar a ᚱ).
   `_terminar(causa)` elige el evento con `motivo_fin`; `_contacto_celdas` da las casillas en los tres.
4. **Sin duplicados:** `_momento_hecho` pasa a contar por evento; `al_expirar` ya no se salta por «golpe», sino que «golpe» es otro evento.

**Aceptación:** `prueba_eventos_hechizo` ampliada (impacto / detención / extinción una vez cada uno, nunca dos de los tres en el mismo tramo);
`prueba_pulso`, `prueba_ejecucion_combinaciones`, `escenario_cueva_resonante`, `escenario_lab_geometrias` a 0; el golden no cambia.

### H4 · Tinta por efectos y magnitud (punto 4)

**Archivos:** `nucleo/dano.gd`, `nucleo/sigils.gd`, `nucleo/hechizo.gd`, `docs/DANO_Y_TINTA.md` §2.

`T = T_base(potencia) + Σ aporte_glifo(n) × (1 + recargo_instancias + recargo_periodico)`, calculada por `Dano.tinta_de(h: Hechizo)`:

- `aporte`: dato por glifo en `Sigils.GLIFOS` (`"tinta": {por_glifo, tope}`), 0 por defecto (sin cambio hasta que Pablo ponga números);
- `recargo_instancias`: `(copias − 1) × K_COPIA` + hijos previstos de `crear_hijo` (`cuantos × profundidad`);
- `recargo_periodico`: el continuo de hoy, pero decidido con `h.persistente` (cubre tierra/hielo sin barrera: cierra PENDIENTES 62) + `dano_periodico > 0`
  o `veneno > 0` × `K_PERIODICO`;
- `Receta3D.coste_tinta()` y `Hechizo.coste_tinta` llaman a lo mismo (ya garantizado por H1).

**Aceptación:** tabla nueva en `prueba_dano_tinta` (receta → tinta exacta: barrera+ᚱ, ᚠᚠ+flecha, tierra+ᚱ sin barrera, fuego con zona…);
con todas las constantes nuevas a 0 el golden no cambia; con los números de Pablo se regenera y se anota.

### H3 · Daño separado de la geometría (punto 3) — decidido en §4.1

**HECHO (29/10, diario 282):** `cuenta_dano` en `Sigils.GLIFOS` (ᛁ ᛁ ᛏ a false) + `Sigils.cuenta_dano`, `Dano.nivel_dano/base_dano` con cortes 3/5, `Hechizo.n_glifos_dano/nivel_dano`; golden regenerado (solo cambia `dano` en 7248 de 12012 entradas, más los dos campos nuevos).

**Archivos:** `nucleo/dano.gd`, `nucleo/sigils.gd` (`cuenta_dano` por glifo), `nucleo/hechizo.gd` (`n_glifos_dano`, `nivel_dano`), `docs/DANO_Y_TINTA.md` §1.

- `Sigils.GLIFOS[linea_x | linea_z | altura]["cuenta_dano"] = false`; los demás (y los nuevos de H5) `true` por defecto.
- `Hechizo.n_glifos` sigue siendo la potencia de la **tinta** (cortes 0-1 / 2-3 / ≥ 4, sin cambio); `Hechizo.n_glifos_dano` cuenta solo los glifos con
  `cuenta_dano`, y `Hechizo.nivel_dano` usa los cortes nuevos `Dano.GLIFOS_MEDIA_DANO = 3` y `GLIFOS_ALTA_DANO = 5` (1-2 ligera · 3-4 media · 5-6 alta).
  `Dano.base_elemental(n_glifos_dano, …)` da B; las tablas B 12/24/40 y E no cambian.
- Rótulos y previsión («ligera/media/alta») pasan a enseñar `nivel_dano`.

**Aceptación:** «añadir ᛁ o ᛏ no cambia `dano`» y «flecha + rebote + ᚱ = media, + ᚠ = media, + 2 más = alta» en `prueba_dano_tinta`; `prueba_prevision_hechizo`
(previsión = golpe real); el golden se regenera a propósito (solo cambia `dano`/`nivel` en recetas con geometría) y la tabla de golpes para matar de
`DANO_Y_TINTA.md` §3 se recalcula.

### H5 · Glifos nuevos: perforar, retorno, buscar; después retardo (punto 5)

**HECHO (30/10, diario 291):** `perforar` (ᚦ), `retorno` (ᛃ, sin PNG), `buscar` (ᚨ) y `retardo` en `Sigils.GLIFOS`, `GestureLibrary` (SIGILS, RECORDABLE, BIBLIA como «sello»), progresiones `todo` y `pruebas`; `HechizoVivo.espera` para el retardo del proyectil; `prueba_glifos_nuevos` (nueva) y `ACTIVABLES` en `prueba_ejecucion_combinaciones`. El 2.º glifo de retorno no hace nada; «dos golpes al mismo enemigo» pide ᚦ además de ᛃ (ver diario). Falta: muestras (Pablo), PNG de jera (Pipeline) y decidir cuándo se ganan.

**Archivos:** `nucleo/sigils.gd` (`GLIFOS`, `GLYPHS`), `nucleo/gesture_library.gd` (`SIGILS`, `RECORDABLE`, `BIBLIA`), `nucleo/repertoire.gd`,
`magia/lanzador_3d.gd` (`Receta3D.APARCADOS`), `art/ui/glyphs/*.png` (Pipeline), `magia/hechizo_vivo.gd` (solo si el proyectil ignora `retardo`).

| glifo | runa (propuesta) | modificador | momento |
|---|---|---|---|
| perforar | ᚦ thurisaz | `perfora` +1, tope 3 | continuo, paso 3 |
| retorno | ᛃ jera | `retorna` fija true (el 2.º glifo: `elasticidad` o nada) | final, paso 3 |
| buscar | ᚨ ansuz (o la que Pablo diga) | `busca` +0,5, tope 2 | continuo, paso 3 |
| retardo | ᛞ dagaz o el «reloj de arena» de hoy | `retardo` +1 s, tope 3 | «antes del inicio», paso 3 |

Cada glifo: una línea de datos, alta en la biblia, PNG, prueba de solo y en combinación (`prueba_ejecucion_combinaciones` admite una lista
`ACTIVABLES` que se prueba aunque no tenga muestras, como `RECETAS_RAIDO`), y Pablo graba las muestras (`G`). Nada de excepciones por receta: si
«retorno + barrera» sale raro, se acepta (decisión 5 de `GLIFOS_RECETA.md` §4).

**Aceptación:** perforar atraviesa `perfora` enemigos del mundo falso y se para en el siguiente; retorno vuelve y golpea dos veces al mismo;
buscar gira hacia el enemigo del cono y no hacia el de fuera; retardo retrasa el nacimiento del volumen **y** del proyectil; combinados dos a dos
sin `SCRIPT ERROR`; previsión (`prever`) los recoge (hoy `retorna` solo se prevé en la ida: anotar).

### H7 · Información del grimorio (punto 7)

**HECHO (29/10, diario 284):** `Hechizo.resumen/diferencia/frases_cambio/texto_cambio`, `Lanzador3D.receta_de_ficha/avisos_de/notas_de/aviso_*`, `Grimorio.resumen_pagina`, banda de texto sobre las pestañas en `spellbook.gd`; `prueba_resumen_hechizo` y `captura_resumen_libro` (`docs/capturas/resumen_libro/`).

**Archivos:** `nucleo/hechizo.gd` (`resumen()`, `diferencia(otro)`), `magia/grimorio.gd`, `presentacion/ui/spellbook.gd`, `presentacion/ui/page_hud.gd`,
`presentacion/ui/ejes_receta_ui.gd`.

- `Hechizo.resumen()` → `{potencia (nombre), tinta_prevista, recarga, forma, avisos: [...]}` y `Hechizo.diferencia(anterior)` → los campos que cambió el
  último glifo (`origen` ya lo sabe: `glifo:<nombre>`). Los avisos son los mismos textos de `_preparar_pagina` (altura, «Aún sin uso», tinta
  insuficiente, haz/sólido quieto), sacados a una función pura `Lanzador3D.avisos_de(hechizo, tinta)` que usan los dos sitios.
- El libro construye el `Hechizo` de la página **al cerrar cada trazo** (barato: es `construir`) y pinta: contadores por glifo (ya), «+1 casilla de ancho»
  o «+2 s» junto al glifo recién escrito, tinta prevista frente a la actual, nombre de potencia y recarga; los avisos en rojo antes de intentar lanzar.
- Con `Sigils.nombre_visible` (PENDIENTES 65) para ᚷ/ᚱ.

**Aceptación:** `prueba_escritura_hud` / nueva `prueba_resumen_hechizo`: por cada glifo añadido a una página, `resumen()` cambia solo en los campos del
glifo, la tinta prevista coincide con la que cobra `lanzar_ahora`, y los avisos del libro coinciden con los de `_preparar_pagina`. Captura para Pablo.

### H6 · Interacción material (punto 6) — gradual, el último
**SEGUNDA ENTREGA HECHA (30/10, diario 290): los doce objetos restantes, el lanzador y la previsión por `Materia`; `MATERIAL_POR_TIPO` disponible sin usar.** Quedan `decidir_golpe` de `Combate3D` y sustituir los papeles por el material.
**PRIMERA ENTREGA HECHA (29/10, diario 286): datos, Materia, contrato, `objetos_3d.gd`.** (Los `.tres` ya traían los cuatro campos físicos desde antes: el paso 1 era solo comprobarlo; el golden no cambia. El resto, archivo a archivo, en `docs/PENDIENTES.md` → «Hechizos · H6».)

**Archivos:** `nucleo/materia.gd` (nueva, `Materia`), los 7 `*_rune.tres`, `objetos/objetos_3d.gd`, después uno a uno `barril`, `cuerda`, `compuerta`,
`lava`, `nexo_rayo`, `molino`, `muro_agrietado`, `surtidor`, `tronco_puente`, `bloque_empujable`, `pulsador`…; `enemigos/combate_3d.gd` (`decidir_golpe`:
vapor / congelar mojado / arco por `temperatura` y `conductividad`).

1. **Datos:** los `.tres` reciben `temperatura`, `humedad`, `conductividad`, `densidad` de `ESPEC_HECHIZO.md` §2 vía `modificadores` (ya se leen).
2. **Interfaz común:** `Materia.reaccion(h: Hechizo, material: String, estado_objeto: Dictionary) -> String` con la tabla de `MEJORAS_POTENCIA.md` §5
   (madera, vegetal, piedra, metal, cristal, tela) expresada en **propiedades**: prende si `temperatura ≥ 0,5` y no está mojado; moja si `humedad ≥ 0,5`;
   congela si `temperatura ≤ −0,5` (más si mojado); conduce si `conductividad ≥ 0,5`; empuja si `empuje ≥ 0,5`. Las etiquetas siguen valiendo como
   **respaldo** (`Materia.de_etiquetas(rune)` traduce `calor` → temperatura +1, etc.) para que un `RuneData` suelto (el fuego de un brasero) siga funcionando.
3. **Contrato:** `on_spell_hit(rune_data, dir, hechizo = null)` en todos los reactivos (hoy solo `Combate3D` y `Escudo3D`); `Lanzador3D._golpear` ya pasa
   `hechizo` cuando lo tiene.
4. **Migración por objeto:** primero `objetos_3d.gd` (`spell_reacts`, `reaccion_a`), con `prueba_reacciones` a 0 y una prueba nueva por propiedad
   (un elemento de laboratorio con `temperatura +1` y **sin etiquetas** prende un seto); después el resto, uno por entrada del diario. Los `elemento == "…"` de
   VFX (`vfx_3d.gd`, `vfx_estado_3d.gd`) **no** se migran: son dibujo, no reacción.

**Aceptación:** los materiales responden a propiedades (la prueba sin etiquetas pasa), `prueba_reacciones`, `prueba_fuego`, `prueba_hielo`,
`prueba_agua_hechizos`, `escenario_puzles_fuego`, `escenario_puzles_agua`, `escenario_cueva_completa` a 0; un elemento nuevo (p. ej. «vapor») con solo
propiedades reacciona con todo sin tocar un objeto.

---

## 4. Decisiones de Pablo

1. **Daño y nº de glifos (H3). DECIDIDO (Pablo, 29/10):** los glifos de **geometría** (ᛁ `linea_x`, ᛁ `linea_z`, ᛏ `altura`) **no suman daño**, para que
   «ᛁ × 6» no sea la combinación óptima. El resto cuenta como hasta ahora pero con escalones nuevos: **1-2 ligera · 3-4 media · 5-6 alta** (el 6 no existe de
   momento). La repetición ᚠ sigue contando: ya «duplica el daño» por sí misma (cada copia golpea), y así se mantiene el balance. Queda en H3:
   `cuenta_dano: false` en los tres glifos de eje, `Hechizo.n_glifos_dano`, y `Dano.GLIFOS_MEDIA_DANO = 3`, `GLIFOS_ALTA_DANO = 5`.
   **Supuesto a confirmar:** la **tinta** sigue saliendo del nº TOTAL de glifos con sus cortes de hoy (0-1 / 2-3 / ≥ 4): así una ᛁ cuesta tinta pero no da daño,
   que es el equilibrio buscado. Si Pablo prefiere que la tinta use el mismo recuento, es una constante.
2. **Retardo (H5).** Aparcado el 17/10 «hasta encontrarle uso». ¿Se reactiva ahora (trampas, combos con pulso) o sigue aparcado?
3. **Runas (H5):** ᚦ perforar y ᛃ retorno (de `MEJORAS_POTENCIA` §6); para «buscar», ᚨ ansuz o la que prefiera; y grabar las muestras (también ᚱ y ᛉ,
   pendientes desde el 23/10).
4. **Números de tinta (H4):** aporte por glifo, `K_COPIA`, `K_PERIODICO`. Se entregan a 0 (sin cambio) con la tabla de la prueba para rellenar.
5. **Orden:** confirmar H0 → H1 → H2 → H4 → H3 → H5 → H7 → H6, o pedir otro.

## 5. Prompts

**H0**
```
Contexto Juego. Lee docs/PLAN_SISTEMA_HECHIZOS.md §3 H0 y §1.8. Crea herramientas/prueba_hechizo_golden.gd (todas las recetas de hasta 4 glifos de Sigils.GLIFOS × 6 elementos × 2 calidades: Hechizo.a_diccionario() contra herramientas/golden_hechizos.json, tolerancia 1e-4; con --regenerar lo reescribe) y herramientas/prueba_eventos_hechizo.gd (mundo falso de prueba_ejecucion_combinaciones; cada evento y momento una vez, mismo resultado con los glifos en orden inverso, motivo_fin y celdas_de_contacto). Alias «hechizos» en tools/resumen_prueba.ps1 con la lista de §1.8. Genera el golden, las dos a 0. Diario. Sin commit.
```
**H1**
```
Contexto Juego. Requiere H0. Lee docs/PLAN_SISTEMA_HECHIZOS.md §1.1 y §3 H1. Un solo Hechizo por lanzamiento: _preparar_pagina lo construye (con el pigmento) y lo guarda en _preparado["hechizo"]; rechazo_de_construccion, _disparar, hechizo_de y PrevisionHechizo leen ese. Tinta y recarga desde Hechizo.coste_tinta / recarga. Receta3D pasa a adaptador (contadores + calidad → Hechizo cacheado): geo(), coste_tinta(), n_glifos(), cooldown delegan. GLIFOS_V2 en desuso: lab y EjesRecetaUi leen GLIFOS. Los campos antiguos de SpellRecipe solo mientras viva «Campo» (anótalo en PENDIENTES). Contador de construcciones en pruebas: 1 por lanzamiento, 1 por fotograma de previsión. Golden sin cambios; prueba_dano_tinta, prueba_prevision_hechizo, prueba_tinta, escenario_libro, escenario_lab_geometrias a 0. Diario. Sin commit.
```
**H2**
```
Contexto Juego. Requiere H1. Lee docs/PLAN_SISTEMA_HECHIZOS.md §1.2 y §3 H2 y GLIFOS_RECETA.md §2.4 bis. Un catálogo (Hechizo.ACCIONES con emitir_pulso; fuera ACCIONES_MOMENTO), un orden (ordenar_acciones también para los eventos HC4), y el «final» partido en al_impactar / al_detenerse / al_extinguirse según motivo_fin, con celdas_de_contacto en los tres; «final» en un glifo sigue valiendo los tres (ᚱ no cambia). Sin reentradas por evento. prueba_eventos_hechizo ampliada; prueba_pulso, prueba_ejecucion_combinaciones, escenario_cueva_resonante, escenario_lab_geometrias a 0; golden sin cambios. Actualiza GLIFOS_RECETA §2.4 bis. Diario. Sin commit.
```
**H4**
```
Contexto Juego. Requiere H1. Lee docs/PLAN_SISTEMA_HECHIZOS.md §1.4 y §3 H4 y DANO_Y_TINTA.md §2. Dano.tinta_de(h: Hechizo): T_base(potencia) + Σ aporte por glifo (dato "tinta" en Sigils.GLIFOS, 0 por defecto) × (1 + recargo por instancias (copias, hijos) + recargo periódico (continuo decidido con h.persistente, dano_periodico, veneno)). Receta3D.coste_tinta y Hechizo.coste_tinta llaman a lo mismo. Constantes nuevas a 0: golden sin cambios. Tabla de recetas → tinta en prueba_dano_tinta. Cierra PENDIENTES 62. Actualiza DANO_Y_TINTA §2. Diario. Sin commit.
```
**H3** (tras la decisión 4.1), **H5** (tras 4.2 y 4.3), **H7** (tras H1 y H4) y **H6** (el último, objeto a objeto): los textos de §3 valen como prompt
añadiendo «Contexto Juego. Lee docs/PLAN_SISTEMA_HECHIZOS.md §3 Hn» y la lista de pruebas de su aceptación.

— Juego
