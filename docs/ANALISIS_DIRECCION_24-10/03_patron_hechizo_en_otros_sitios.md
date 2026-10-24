# El patrón de la clase `Hechizo`: ¿dónde más vale la pena?

Informe de arquitectura para la dirección (24/10/2026). Solo lectura: no se ha tocado nada del repo.
Todas las cifras están medidas sobre la rama `claude/proyecto-analisis-profundo-bf47f8` (commit `7a91ea36`), con Select-String y conteo de líneas. Los conteos de `if`/`match` se han hecho con expresiones regulares, así que pueden desviarse ±2 por línea partida o por un nombre de variable raro.

---

## 0. Resumen en 10 líneas

- **El patrón son 7 piezas, más una octava que suele olvidarse: la capa `CapaBases`.** Esa capa permite tocar desde el laboratorio los valores por defecto y los modificadores, en memoria y sin recompilar.
- **Dónde encaja de verdad:** en lo que se *construye una vez y luego se ejecuta*. Son los enemigos (a), los consumibles, las mejoras y los pigmentos (c), los atributos del jugador (d) y los glifos (g).
- **Dónde ya existe a medias y solo falta cerrarlo:** objetos reactivos (b), con los papeles `+/-` que ya son modificadores; luz y zonas (i), con `LuzZona3D.ZONAS`; reacciones de VFX, con `ReaccionesVfx3D.TABLA` + `EXCEPCIONES`; VFX por elemento, con `ElementoVfx.perfil()`.
- **Dónde NO encaja:** misiones (h), que son una máquina de estados guardable, y la mitad de la IA de `Combate3D`, donde manda el estado en marcha.
- **Niveles (e):** el patrón no se aplica tal cual. Lo que hace falta es la M5 (partir la maqueta), y su primer paso sí es un `DatosNivel` de datos puros.
- **Orden recomendado:**
  1. `Atributos` del jugador con `Mejora`/`Receta` como modificadores (aplicar ya, S–M).
  2. Pigmento como modificador dentro de `Hechizo.construir` (S, dentro del paso 1).
  3. `Enemigo` de datos + `Combate3D` como ejecutor (M).
  4. `Glifo` en un solo sitio (M).
  5. Más adelante: `Pieza` reactiva, `Bioma` y `DatosNivel` (M5).

---

## 1. El patrón, en sus piezas (leído del código)

| # | Pieza | Dónde está en `Hechizo` |
|---|---|---|
| 1 | **Clase de DATOS PUROS** (`RefCounted`): cada campo con su valor por defecto. Los campos se agrupan en `CAMPOS`, y aparte están `EDITABLES` (rango para el lab), `DERIVADOS` y `SOLO_LECTURA` | `nucleo/hechizo.gd:1-2`, `CAMPOS` :24-35, `EDITABLES` :86-107, `DERIVADOS` :109, `SOLO_LECTURA` :77; campos :115-267 |
| 2 | **UN constructor con orden fijo**, `construir()`. El orden es: defectos → fuente (elemento) → extras (glifos: fija/suma y luego multiplica) → topes → mínimos → calidad → límites globales → derivados | `construir` :277-320; `_aplicar` :350-396 (las tres rondas `fija`/`suma`/`multiplica`, después topes y `minimo`); `_limitar` :324-332; `_derivar` :434-447 |
| 3 | **MODIFICADORES como lenguaje común**, `{campo, op, valor, tope, desde, salta}`, más `anade` para los eventos y valores simbólicos `@…` | definición en `nucleo/sigils.gd:365-372`; tabla `Sigils.GLIFOS` :374-398; los `.tres` traen `modificadores = {campo: {op, valor}}` (p. ej. `nucleo/fire_rune.tres`); `RuneData.modificadores` `nucleo/rune_data.gd:67`; los campos antiguos de `RuneData` se traducen a «fija» en `hechizo.gd:336-346` |
| 4 | **`origen`**: de dónde sale cada valor («defecto», «elemento», «glifo:x», «calidad», «lab», «derivado») | `hechizo.gd:270`, se escribe en `_aplicar` :373 y en `con` :589 |
| 5 | **EJECUTOR aparte** (`Node3D`): lee la definición, nunca la toca, y guarda el estado en marcha | `magia/hechizo_vivo.gd:1-14`; `crear` :114-136; `preparar` :146-158; estado en marcha :69-109 (posición, velocidad, golpeados…) |
| 6 | **Utilidades** para el lab, PlayLog y pruebas: `copiar`, `con`, `tabla`, `a_diccionario`, `describir`, `texto_modificadores`, `defecto`/`defecto_original` | `hechizo.gd:562-696` |
| 7 | **Eventos con catálogo CERRADO** de acciones | `EVENTOS`/`ACCIONES` `hechizo.gd:39-40`; `ACCIONES_MOMENTO` `hechizo_vivo.gd:745`; `momento_de`/`acciones_en` `hechizo.gd:507-545` |
| 8 | **Capa de sobrescritura en memoria (`CapaBases`)**: el lab cambia defectos y modificadores sin escribir en `res://`; en el juego normal está vacía | `nucleo/capa_bases.gd:1-70`; `construir` la consulta en :282, :305 y :340 |
| 9 | **Refactor con prueba de igualdad**: HC1–HC3 no cambian nada visible y lo demuestran con pruebas | `herramientas/prueba_hechizo.gd` (366 líneas): todas las combinaciones de hasta 4 glifos × 7 elementos × 2 calidades contra el camino viejo, con tolerancia 1e-4 (:4-5, :57, :73-77) |

Lo que de verdad aporta el patrón:
- Un número se decide en **un solo sitio**.
- Una variante es **una fila de datos**.
- El lab puede **enseñar de dónde viene cada valor y cambiarlo en vivo** (`CapaBases` + `tabla()` + `texto_modificadores()`).

Lo que cuesta:
- Cada campo nuevo tiene que pasar por `_escribir`, que trabaja por nombre con `get`/`set`: los errores de escritura no salen al compilar.
- El ejecutor sigue teniendo su lógica: la mudanza de HC2 dejó `hechizo_vivo.gd` en 1237 líneas.

**Hallazgo previo: el patrón tiene dos fugas en su propio terreno.**
- `Lanzador3D` modifica el hechizo *después* de `construir`, en dos sitios:
  - `magia/lanzador_3d.gd:1179`: `hechizo.dano *= tinta.mult_dano(elemento)` (el pigmento);
  - `magia/lanzador_3d.gd:1213`: `hechizo.altura_salida = …`.

  El pigmento es exactamente un modificador `{campo: "dano", op: "multiplica", valor: 1.5}` condicionado al elemento, pero hoy no deja `origen` y el lab no lo ve.
- Siguen vivas dos tablas de glifos:
  - `GLIFOS_V2` (`sigils.gd:343-359`) y `GLIFOS` (:374-398) duplican `repertorio` y `cooldown`;
  - `cooldown_v2` (:475-481), `repertorio_de` (:485-486) y `Hechizo.propiedades_usadas` (`hechizo.gd:486`) aún leen `GLIFOS_V2`.

---

## 2. Candidatos

### a) Enemigos: `enemigos/combate_3d.gd`

**Medido.**
- **Tamaño:** 2041 líneas (no 1813: ha crecido), con 86 `const` y 17 `static var` de «sensación de golpe» (:40-55).
- **El tipo de enemigo se decide por el `id` del modelo en el `_ready` del ejecutor:**
  - elemental: `elemental = pj.id == ID_ELEMENTAL` (:316);
  - arquero: `arquero = pj.id.begins_with("goblin_archer")` (:326);
  - asesino: `begins_with("goblin_asesino")` (:329).
- **`elemental` aparece 54 veces en el archivo, `arquero` 16 y `fijo` 6.**
- **Los datos de identidad están en tres sitios distintos:**
  - los `var` por defecto del guerrero: vida 100, debil «agua», resiste «fuego», nombre, oro, sonidos (:171-180);
  - `_preparar_elemental` los sobrescribe a mano: vida 1000, nombre, debil, resiste, oro (:1577-1583);
  - `Gatopedro3D.equipar_gatopedro` vuelve a sobrescribir los mismos 8 campos (`enemigos/gatopedro_3d.gd:61-68`). Es literalmente una «variante = defectos + fija», escrita en código.
- **Constantes por variante sin agrupar:** 25 `ELEM_*` (:84-107), 9 del arquero (:110-119) y 11 del guerrero (:59-80).
- **Loberno:** no hay ni una mención en `combate_3d.gd`. Se crea en `escenas/bosque_01_3d.gd:316-323` con `Combate3D.equipar` y hereda todo del guerrero, incluido `nombre = "Goblin guerrero"`: **en pantalla un loberno se llama «Goblin guerrero»**, y además es débil al agua y resiste el fuego como un goblin.
- **Reacciones:**
  - `reacciones_soportadas` (:442-448) excluye «mojado» y «aturdido» con un `if elemental`;
  - `golpe` (:465-546) mezcla datos (las duraciones vienen del Hechizo, bien) con 6 `if elemental` por regla.
- **Escudo:** ya es un componente (`var escudo: Escudo3D`, :166; consulta única en :370).

**Veredicto: aplicar MÁS ADELANTE, en cuanto entre el próximo enemigo** (el paso 3 del orden). Hoy hay 5 tipos más el Gatopedro, y cada uno nuevo multiplica los `if elemental`.

**Diseño.**
- **Clase `Enemigo`** (`nucleo/enemigo.gd`, `RefCounted`, datos), con estos grupos:
  - *identidad:* `id`, `nombre` (""), `modelos` ([]), `tinte` (blanco), `snd_alerta`, `snd_muere`, `barra` («normal» o «jefe»);
  - *cuerpo:* `vida` (100), `radio` (0,32), `peso_empuje` (1,0; elemental 0,3 = `MULT_EMPUJE_ELEMENTAL`), `alto_ref` (0);
  - *sentidos:* `radio_deteccion` (5,75), `radio_soltar` (10), `tiempo_perder` (3,5);
  - *movimiento:* `vel_perseguir` (2,4), `vel_patrulla` (1,0), `mult_vel` (1; elemental 0,7);
  - *ataque:* `tipo_ataque` («cuerpo», «distancia» o «ninguno»), `rango` (1,2), `dano` (20), `preparar` (0,6), `descanso` (1,6), `momento_golpe`, `alcance_flecha` (6,5), `vel_flecha` (9)…;
  - *afinidades:* `debil` («agua»), `resiste` («fuego»), `mult_debil` (2), `mult_resiste` (0,5), `inmune` ([]; el elemental: «mojado», «aturdido», «veneno»), `cura_con` ({}; elemental: {agua: 120});
  - *botín:* `oro` (10), `botin` ([]);
  - *componentes:* `componentes` ([]: «escudo», «conjura_enredaderas», «crece_con_agua»);
  - *conducta:* `ia` («perseguir», «huir», «puesto»).
- **De dónde salen los modificadores:**
  - una tabla `Enemigos.TIPOS` (o un `.tres` por tipo: `goblin_guerrero.tres`, `loberno.tres`…) donde cada fila es `{base: "guerrero", modificadores: [{campo, op, valor}]}`;
  - el arquero es `base guerrero + {tipo_ataque: fija "distancia", rango: fija 6,5, …}`; el asesino, `base guerrero + {nombre}`;
  - el `fijo` del marcador (`escenas/bosque_01_v01_3d.gd:289`) pasa a ser un modificador de la *colocación* `{ia: fija "puesto"}`, el mismo papel que la «calidad» en `Hechizo`.
- **Constructor:** `Enemigo.construir(tipo, extras_colocacion)`. El orden es: defectos → base → modificadores del tipo → modificadores de la colocación (marcador) → límites → derivados (`radio` desde `alto_ref`, color del borde desde `debil`).
- **Ejecutor:** `Combate3D` se queda como está y lee de `e: Enemigo`. Los `if elemental` de *datos* (vida, empuje, inmunidades) desaparecen. Los de *comportamiento* (`_efectos_elemental`, `_brotar_enredaderas`, :1636-1760) pasan a componentes con un catálogo cerrado, como `ACCIONES`.
- **`CapaBases` propia** (o una genérica, ver §4) para que el lab de enemigos toque la vida o el rango en vivo.

**Lo que sale gratis.**
- Loberno con su nombre, su vida y sus afinidades (una fila).
- Variantes elementales al estilo EoW: «goblin de escarcha» = guerrero + `{debil: fija fuego, resiste: fija hielo, tinte}`.
- Un jefe = una fila + el componente «barra_jefe».
- El enemigo sale en el PlayLog con `a_diccionario()`.

**Pruebas de igualdad (EN1–EN3, el equivalente de HC1–HC3).**
- **EN1:** para cada tipo de hoy (guerrero, arquero, asesino, elemental, loberno, Gatopedro), `Enemigo.construir(tipo)` da los mismos valores que hoy quedan en el nodo tras `_ready`: `vida_max`, `debil`, `resiste`, `nombre`, `oro`, `arquero`, `elemental` y `reacciones_soportadas()`.
  - Se mide ANTES con una foto de los campos, con la base de `prueba_contrato_enemigo.gd` (338 líneas).
  - Excepción explícita: el nombre del loberno sí cambia, y es la única diferencia admitida.
- **EN2:** `prueba_golpe.gd` (112 líneas), `prueba_reaccion_enemigos`, `prueba_gatopedro`, `prueba_goblin_asesino`, `prueba_escudo_goblin` y `prueba_empujado_goblin`, todas a 0 fallos.
- **EN3:** el mismo daño, empuje y estados por elemento × tipo que hoy (una tabla medida antes del cambio).

**Coste y riesgo.**
- **Coste: M.** Son 2041 líneas, pero el cambio de datos está concentrado en `_ready`, `_preparar_elemental` y los `const`.
- **Riesgo medio.** `_ia` (:829-950) lee muchas constantes. Si se mudan solo las de *datos* y la IA se deja quieta, el riesgo baja.

### b) Objetos reactivos: `objetos/objetos_3d.gd` (`Reactivo3D`)

**Medido.**
- **Tamaño:** 1482 líneas, con 77 `const`.
- **Papeles:** `PAPELES_POR_TIPO` (:121-134) es el equivalente a «la fuente», y el `@export papeles` con `+/-` (:212-256) es literalmente un lenguaje de modificadores de una sola op (`anade`/`quita`): **el patrón ya existe a medias**.
- **Lo que falta:**
  - `COMBUSTIBLES` y `FUENTES` guardan los números como arrays posicionales `[s, escala, medio_lado, alto]` (:81-99). No tienen nombre de campo ni modificadores por pieza: un seto que arda 6 s en vez de 3,5 pide una fila nueva de tipo;
  - `match tipo` aparece 5 veces, `tipo ==` 9 y `tipo !=` 5. El propio comentario (:10-11) dice que el montaje visual «sigue por tipo»;
  - `on_spell_hit` (:420-453) y `spell_reacts` (:456-479) **deciden lo mismo dos veces**: la misma cascada de papeles × etiquetas, escrita dos veces;
  - el elemento se lee por etiquetas (`rune_data.tags.has`): 22 veces en `objetos_3d.gd` y **62 en total** en `objetos/`.
- **Otras 13 piezas de `objetos/` también tienen su propio `on_spell_hit`** y deciden por etiquetas: `barril_3d` (8), `cuerda_3d` (10), `compuerta_3d`, `lava_3d`, `nexo_rayo_3d` (4 cada una)… Ninguna usa papeles.
- **El `Hechizo` ya trae `temperatura`, `humedad` y `conductividad`** (`hechizo.gd:186-188`, «las reacciones saldrán de aquí»), y los `.tres` las rellenan (`fire_rune.tres`: temperatura 1,0). Ningún reactivo las lee.

**Veredicto: aplicar MÁS ADELANTE, en dos pasos.**

**Paso 1 (S): números con nombre.** `COMBUSTIBLES`/`FUENTES` pasan a diccionarios `{arde_s, escala_llama, medio_lado, alto}`. La pieza acepta, además de los papeles, modificadores numéricos: `; pieza seto … mods=arde_s:fija:6`. Con eso, «una pieza nueva = una fila» es casi verdad para lo que arde.

**Paso 2 (M): clase `Pieza` de datos.**
- **Campos:**
  - `tipo`;
  - `papeles` (Dictionary);
  - `combustible` {arde_s 3,5, escala 1, medio_lado 0,8, alto 1,3};
  - `fuente` {alto_llama, escala, radio, alto};
  - `cuerpo` {ancho 0,9·S, fondo 0,9·S, alto};
  - `nivel_altura` (1);
  - `capa_colision`;
  - `montaje` (un nombre de un catálogo cerrado: «totem», «surtidor», «tinaja», «emisor», «puente», «placa», «»);
  - `senales` ([]).
- **Constructor:** `Pieza.construir(tipo, retoques)`. El orden es: defectos → `PIEZAS[tipo]` → retoques de la colocación (papeles `+/-` y números) → derivados (grupos `flammable3d`/`peso`).
- **Reacción en una sola tabla:** `REACCION[papel][estimulo] = {si_estado, accion}`, donde el estímulo sale de los campos físicos del Hechizo (temperatura > 0 = calor, humedad > 0 = moja, conductividad > 0 = rayo) y no de etiquetas. `spell_reacts` se *deriva* de esa misma tabla (la acción ≠ «nada»), así que la duplicación de :420/:456 desaparece.
- **Ejecutor:** `Reactivo3D` se queda con el estado en marcha (`estado`, `is_lit`, `_k`, tweens, tinaja).

**Pruebas de igualdad.**
- **PZ1:** para cada tipo de `PAPELES_POR_TIPO` × cada uno de los 7 elementos, `spell_reacts`/`on_spell_hit` dan la misma decisión que hoy (se graba antes la matriz tipo × elemento × estado).
- **PZ2:** `prueba_papeles` (246 líneas), `prueba_fuego`, `prueba_fases_fuego`, `prueba_contacto_fuego`, `escenario_puzles_fuego` y `escenario_puzles_agua` a 0.

**Coste:** paso 1 S; paso 2 M (L si se meten las 13 piezas sueltas). **Riesgo** medio-alto: la tinaja (:898-1350) es estado en marcha puro y no debe tocarse.

**Lo que abre:** puzles nuevos por combinación de papeles (un tronco `+conduce`, una telaraña `+congelable`) sin código, y que el diseñador de niveles cree variantes desde el `.txt`.

### c) Consumibles, objetos, recetas, mejoras: `nucleo/objetos.gd`, `consumibles.gd`, `tinta.gd`

**Medido.**
- **`Objetos.DATOS`** (`nucleo/objetos.gd:14-68`) ya es datos puros, con `efecto` como «único sitio» de los números (comentario en :12-13). Pero:
  - **la poción no lo cumple**: `Objetos.DATOS["pocion"].efecto.cura = 40` (:17) no lo lee nadie. La cura real es `Jugador3D.CURA_POCION = 40` (`jugador/jugador_3d.gd:47`, que se usa en :630-631). Son dos copias del mismo 40;
  - `Consumibles.usar` resuelve con un `match id` de 4 ramas (`nucleo/consumibles.gd:125-147`), cada una con su defecto repetido (`ef.get("dura", 20.0)`, `ef.get("tasa", 3.0)`…, que duplican `DATOS`).
- **`nucleo/recetas_lab.gd` NO es síntesis:** son recetas de hechizo con nombre para el lab (`{nombre, glifos, elemento, cambios}`, :12-25). El nombre se presta a confusión.
- **Síntesis:** no existe ni una línea. `DISENO_FUTURO.md` §7 (:397-407) recoge la decisión de Pablo del 24/10:
  - vida, tinta y pigmentos se fabrican con recetas;
  - la ropa y los glifos, no (cofres, misiones).

  Los ingredientes épicos ya existen (`nucleo_eco`, `geoda_resonante`, `objetos.gd:65-67`) con el uso «Mejora al personaje (vida o tinta)».
- **`Tinta`** ya funciona como un mini-constructor:
  - `maxima_calculada()` = defecto + niveles de mejora × paso, con tope (`tinta.gd:120-125`);
  - los pigmentos son `{elemento, efecto: rebaja|dano, valor, dura}` (:82-88). Eso es un modificador `{campo, op: multiplica, valor}` con condición de elemento y duración.
- **`Estado.mejoras`** (`nucleo/estado.gd:28`) guarda `id → nivel`. Hoy solo lo usan `tinta_jefe`/`tinta_secreto`.

**Veredicto: APLICAR YA**, junto con (d). Es el sitio donde el patrón paga más por menos: no hay código que mudar, hay que *nacer* bien.

**Diseño.**
- **`Mejora`** (datos): una lista de modificadores sobre `Atributos` (ver d), con el mismo lenguaje: `{campo: "vida_max", op: "suma", valor: 20, tope: 300}`.
  - El nivel conseguido es la `n` del modificador, igual que «cuántas veces se dibujó un glifo»: `vida_max +20 × n`, tope 300.
  - Las mejoras de jefe y de secreto de la tinta pasan a ser dos filas: `tinta_jefe: [{campo: tinta_max, op: suma, valor: 30, tope: 300}]` y `tinta_secreto: [{…valor: 10}]`.
  - Con eso desaparecen `REPARTO_*`/`por_jefe()`, o se quedan como derivados documentados.
- **`Receta`** (datos): `{id, ingredientes: {id: n}, da: {mejora: id} | {objeto: id, n}, requiere: flag}`, en una tabla `Recetas.SINTESIS`.
  - Fabricar = quitar los ingredientes y subir `Estado.mejoras[id]` en 1.
  - No necesita clase: es una fila, como `Misiones`.
- **Consumible:** su `efecto` pasa a ser una lista de acciones de un **catálogo cerrado**: `curar(cantidad, t_bebida)`, `recargar_frasco(n)`, `escudo(dura)`, `regenerar(tasa, dura)`, más el futuro `pigmento(id)`.
  - `Consumibles.usar` deja de tener un `match id` y pasa a recorrer la lista.
  - `CURA_POCION` desaparece del jugador.
- **Pigmento:** es un modificador *temporal* sobre el `Hechizo`. `Tinta` pasa la lista de modificadores activos a `Hechizo.construir(…, extras)` como tercera fuente, con `origen = "pigmento:resina_carmesi"`. Con eso se cierra la fuga de `lanzador_3d.gd:1179` y el lab enseña el ×1,5. La rebaja del coste sigue en `Tinta.coste_efectivo`, que trabaja sobre la tinta y no sobre el hechizo.

**Pruebas de igualdad.**
- **MJ1:** `prueba_tinta` (las E1.x existentes) a 0 tras pasar jefe/secreto a filas de `Mejora`: `maxima_calculada()` da 100 / 130 / 300 igual que hoy.
- **MJ2:** un pigmento de daño da el mismo `dano` final que `hechizo.dano *= mult_dano` hoy, para los 7 elementos × los 5 pigmentos.
- **MJ3:** `prueba_bolsa` y `prueba_hud_eow` a 0, y beber cura 40 igual que hoy.

**Coste:** S para consumibles y pigmento; M para `Receta` + UI de síntesis (la UI no entra en este refactor). **Riesgo bajo.**

**Lo que abre:** el sistema de síntesis que Pablo decidió el 24/10 nace dentro del lenguaje común: una receta nueva es una fila y una mejora nueva es otra. El lab puede enseñar «tu vida máxima: 140 (base 100 + núcleo de eco ×2)».

### d) Jugador: `jugador/jugador_3d.gd`

**Medido.**
- **Tamaño:** 815 líneas, con unas 25 `const` de jugabilidad (:22-51: `GRAVEDAD`, `VEL_SALTO`, `INVULNERABLE`, `TIEMPO_VOLTERETA`, `DIST_VOLTERETA`, `T_BEBER`, `CURA_POCION`, `HIELO_*`, `MULT_NADO`, `MAX_NIVELES_SUBIBLES`…).
- **Las velocidades de andar y correr están en tres sitios:**
  - `prueba_test2.gd:27-28` (`VEL_ANDAR` 1,6, `VEL_CORRER` 3,0);
  - `jugador_3d.gd:83-84` (los `var` con 1,6/3,0);
  - `jugador_3d.gd:138-139`, que las lee de la maqueta con `get_script_constant_map()` y un respaldo 1,6/3,0 repetido.
- **La vida máxima vive en `Estado.vida_max`** (`estado.gd:19,29`, `VIDA_BASE` 100) y se lee 7 veces con `Estado.i().vida_max`. Nadie la modifica: hoy no hay mejora de vida.
- **Estados que modifican atributos, hoy a mano:** `MULT_NADO` (:438) y hielo (`HIELO_*`). Para mojado o lento del jugador no hay nada.
- **`Ropa3D`** (179 líneas) es solo visual (`arte/modelos/ropa.json`: `{nombre, glb, capa, oculta}`): no tiene efecto en jugabilidad.

**Veredicto: APLICAR YA**, como base de (c).

**Diseño.**
- **Clase `Atributos`** (`nucleo/atributos.gd`, `RefCounted`), con estos grupos:
  - *vida:* `vida_max` (100), `invulnerable_s` (0,7);
  - *tinta:* `tinta_max` (100), `regen_tinta` (3), `regen_tinta_combate` (1), `frascos_max` (3);
  - *movimiento:* `vel_andar` (1,6), `vel_correr` (3,0), `vel_salto` (8,4), `gravedad` (22), `mult_nado` (0,4), `niveles_subibles` (1);
  - *voltereta:* `voltereta_cd` (4), `voltereta_dist` (1);
  - *consumir:* `t_beber` (1,5);
  - *libro:* `glifos_por_pagina`, `paginas` (hoy `Repertoire.max_*` y el comentario de `lanzador_3d.gd:89`).
- **Constructor:** `Atributos.construir(mejoras: Estado.mejoras, ropa: [], estados: {})`. El orden es: defectos → la maqueta como fuente (lo que hoy da `get_script_constant_map`, traducido a «fija») → mejoras (`n` = nivel) → ropa (si algún día da algo) → estados temporales (mojado: `vel_* multiplica 0,75`) → límites (`vida_max ≤ 300`, `tinta_max ≤ 300`) → derivados.
- **Ejecutor:** `Jugador3D` lee `atr.vel_andar`, etc., y reconstruye cuando cambian las mejoras o un estado (la señal `Estado.cambiado`). `Tinta` lee `atr.tinta_max` en lugar de `maxima_calculada()`.
- **Física fina** (`TOLERANCIA_SUELO`, `HUNDIDO`, `TASA_TREPAR`): sigue en `const`. No es un atributo de diseño, y meterla diluiría la tabla.

**Pruebas de igualdad.**
- **AT1:** con `Estado.mejoras = {}` y sin estados, `Atributos.construir()` da exactamente las constantes de hoy (la tabla de arriba), y `Jugador3D` montado en cada maqueta (`PruebaBosque01`, `PruebaCueva`, `TerraFina`…) ve la misma `_vel_andar`/`_vel_correr`.
- **AT2:** `prueba_jugadora_base`, `prueba_tinta`, `prueba_nado_desactivado`, `escenario_playtest_eow` y `escenario_bosque_01_v01` a 0.

**Coste:** S–M. **Riesgo bajo:** es mover lecturas.

**Lo que abre:**
- Mejoras de vida y tinta por receta (c).
- Estados del jugador como datos (mojado = más lento; «pesado» con armadura).
- Ropa con efecto si Pablo lo decide algún día.
- Una tabla de atributos en el lab con `origen`.

### e) Niveles: `presentacion/prueba_test2.gd` y las reglas de `escenas/`

**Medido.**
- **`prueba_test2.gd`:** 5798 líneas (no 5304), con 134 `const`, 135 `var`, 210 funciones y **46 `@export`** (:711-874).
- **Las 46 exportaciones mezclan cosas distintas:**
  - datos del nivel: `nivel`, `reglas`, `kit`, `estilo`, `zona_luz`, `arqueros`;
  - interruptores de render: `diorama`, `bisel_*`, `agua_*`, `tilt_shift`…
- **Las reglas de nivel entran en la maqueta por dentro**, con `m.get`/`m.call`/`mundo.get`. Son **128 accesos** en total:

  | archivo | `get` | `call` |
  |---|---|---|
  | `bosque_01_v01_3d.gd` | 19 | 24 |
  | `bosque_3d.gd` | 25 | 9 |
  | `bosque_01_3d.gd` | 17 | 11 |
  | `terra_fina_3d.gd` | 15 | 6 |
  | `puzle.gd` | 1 | 1 |

  Ejemplos: `m.get("_mapa")`, `m.call("_personaje", …)`, `m.get("_goblins")`.
- **El nivel ya es DATOS en archivo:** `mundo/datos_nivel/mapas/*.txt` (13 mapas) con líneas `; pieza`, `; marcador`, `; zona` (`niveles.gd:4-6`, `zonas_3d.gd:9-10`, `hornear_nivel.gd:97`), y `HorneadorNivel` lo convierte en `.tscn`.
- **Lo que no existe** es el objeto que lo *contiene*: `mundo/cargador_nivel.gd` no está (la M5 de `docs/ARQUITECTURA_MODULAR.md:149` sigue pendiente).
- `AccionElemental` (la M3) sí existe (`mundo/accion_elemental.gd`, 30 líneas, 36 usos).

**Veredicto: el patrón «construir con modificadores» NO es lo que falta aquí.** Lo que falta es la mitad de datos puros: separar *qué es el nivel* de *cómo se pinta*. Hay que **aplicarlo más adelante, como el primer paso de la M5**.

**Diseño.**
- **Clase `DatosNivel`** (`RefCounted`). Campos:
  - `nombre`, `mapa: PackedStringArray`, `alturas`;
  - `piezas: Array[{id, celda, giro, papeles, mods}]`, `marcadores: Array[{grupo, tipo, celda, opciones}]`;
  - `zonas: Array[{rect, luz, zoom, tilt, mezcla, nombre, rotulo, botin}]`;
  - `entradas`/`salidas`;
  - `bioma` («bosque», ver i), `reglas` («»), `kit` («»), `musica` («»).
- **Constructor:** `DatosNivel.desde_txt(ruta)` o `desde_tscn(nodo)`, que es lo que hoy hace `_leer_nivel`/`_leer_nivel_de` (`prueba_test2.gd:3911-3922`). Sin nodos, así que se puede probar en headless.
- **Modificadores:** solo para *variantes de nivel* (el `Bosque_01_v01` como `Bosque_01` + cambios). No es urgente: los `.txt` ya se copian.
- **Ejecutor:** la maqueta (pinta) y las reglas (juegan), que leen `DatosNivel` en vez de `m.get("_mapa")`.
- **Los 128 accesos se sustituyen por una API**: `datos.celdas_con("Q")`, `mundo.personaje(ids, celda)`.

**Pruebas de igualdad.**
- **NV1:** para los 13 mapas, `DatosNivel.desde_txt` da las mismas listas de piezas, marcadores y zonas que coloca hoy la maqueta (comparar el resultado de `_colocar_letras`/`_colocar_extras` con el contenido de `DatosNivel`).
- **NV2:** `prueba_datos_test2`, `prueba_mapa_abierto`, `prueba_terra_fina`, `prueba_piezas_bosque` y `vista_suelo_editor` siguen igual.

**Coste:** L. **Riesgo alto:** es la M5 entera, con un dueño compartido entre Pipeline y Juego. **Lo que abre:** producción de niveles sin abrir la maqueta, reglas de nivel probables sin escena y el editor de mapas.

### f) VFX: `presentacion/`

**Medido** (en `presentacion/`, recursivo, con la regex `match el|elemento|elem…:` / `elemento == "…"`): **13 `match elemento` y 55 `if elemento ==/!=`**.

| archivo | líneas | `match` | `if` |
|---|---|---|---|
| `vfx_3d.gd` | 2404 | 7 | 22 |
| `vfx_elemento_3d.gd` | 533 | 2 | 17 |
| `prueba_test2.gd` | — | 3 | 7 |
| `vfx_estado_3d.gd` | 1613 | 0 | 7 |
| `vfx_kit_3d.gd` | — | 0 | 1 |
| `fases_fuego_3d.gd` | — | 0 | 1 |
| `pieza_fuego_3d.gd` | — | 1 | 0 |

**El patrón ya está a medias.**
- `ElementoVfx` (`presentacion/vfx_elementos/elemento_vfx.gd`, 41 líneas) es «datos por elemento + ganchos»:
  - `rampa()` y `perfil()` = {luz, charco, aro, particula, marca, mult, fijar};
  - `bola()`, `alto_muro()` y `ajustar_tira()` son ganchos.
- `fuego.gd` tiene 20 líneas, solo datos. `hielo.gd` tiene 739 líneas y casi 80 constantes por figura (`RAYO_*`, `PLACA_*`, `ESCARCHA_*`).
- `ReaccionesVfx3D` (`reacciones_vfx_3d.gd`, 209 líneas) es el patrón exacto con otro nombre: `TABLA` (por defecto) + `EXCEPCIONES[tipo][reaccion]` (modificadores «fija» por tipo), con un catálogo cerrado (`CATALOGO`, `EFECTOS`).

**Muchos de los 55 `if` deciden *qué asset cargar*, no números:** `if elemento == "tierra" and _cargar_piedra()` (`vfx_3d.gd:476, 870, 1274`), `elemento == "rayo" and _cargar_energia()` (:489, 874, 1262), `VfxHielo.activo()`…

**Veredicto: aplicar MÁS ADELANTE, poco a poco, y es tarea del Pipeline** (`PROPIETARIOS`).

**Diseño mínimo.**
- Ampliar `perfil()` con claves que hoy son `if`: `modelo` («piedra», «energia», «hielo», «»), `fragmentos` («tierra», «hielo», «»), `mallas_cola` (bool), `salto_visual`, `impacto_dura`.
- Una tabla `FIGURA_MODS[figura]` (haz, barrera, proyectil, pulso, esfera, que ya deriva `Hechizo.figura()`, `hechizo.gd:549-558`) con `{campo, op, valor}` sobre el perfil: «barrera: luz multiplica 1,3».
- Construir con `EfectoVfx.construir(elemento, figura, hechizo)` → perfil del elemento → modificadores de la figura → modificadores del hechizo (`estela`, `efecto_impacto`).

**Pruebas de igualdad.**
- **VX1:** para 7 elementos × 5 figuras, el perfil construido es igual al que hoy resulta de los `if` (grabarlo antes).
- **VX2:** `prueba_vfx_elemento`, `prueba_vfx_v2`, `prueba_vfx_proyectil`, `prueba_vfx_tierra_viento` y `prueba_conjuro_vfx` a 0, más una captura comparada.

**Coste:** M–L (2404 líneas en `vfx_3d.gd`). **Riesgo:** medio para la vista; las pruebas headless no ven el píxel.

**Advertencia.** El VFX tiene mucho *código de dibujo* legítimo (`hielo.gd` arma mallas). El patrón quita los `if` de *qué*, no el *cómo*. No hay que aspirar a 0 `if`.

### g) Glifos y sellos

**Medido: añadir el glifo ᚱ `raido` (23/10) obligó a tocar 9 líneas en 4 archivos, más un PNG:**
- `nucleo/gesture_library.gd`: `SIGILS` :62, `RECORDABLE` :73, `BIBLIA` :88;
- `nucleo/sigils.gd`: `GLYPHS` :128 (preload del PNG), `NOMBRE_VISIBLE` :134, `GLIFOS_V2` :358, `GLIFOS` :395;
- `presentacion/ui/ejes_receta_ui.gd`: :30 (`EFECTO`) y :96.

**Más tablas por glifo:**
- `Sigils.FORM` (:32, la del 2D: `permanencia` aparece en :48);
- `ALIAS_V2` (:433);
- `PATTERN_AS_SIGIL` (:226);
- `Repertoire` (`P0_SIGILS`, desbloqueos).

**Veredicto: APLICAR (paso 4)** cuando entre el próximo glifo o cuando se retire `GLIFOS_V2`. El beneficio es directo y medible: 9 líneas en 4 archivos → 1 `.tres` + 1 PNG.

**Diseño.**
- **Clase `Glifo`** (`Resource`, `nucleo/glifos/<id>.tres`), con estos campos:
  - `id` (el de las muestras: no se renombra), `nombre_visible` (= id), `futhark`, `nombre_runa`;
  - `uso` («sello», «elemento», «asset», «libre», «cinematico»), `icono: Texture2D`;
  - `repertorio` (= id), `alias` ([]);
  - `cooldown` (1,5), `momento` («inicio»), `momento_si` ([]), `paso` (1), `accion` («»), `modificadores` ([]);
  - `grabable` (true), `efecto_ui` («»).
- **Construcción:** `Sigils.GLIFOS`, `GLYPHS`, `NOMBRE_VISIBLE`, `GestureLibrary.SIGILS`/`RECORDABLE`/`BIBLIA` y `EjesRecetaUi.EFECTO` pasan a ser *vistas* que se construyen una vez leyendo la carpeta, igual que `Hechizo.defecto()` lee un `Hechizo.new()` para no tener dos copias. Las `const` actuales se convierten en `static var` que se llenan al cargar, o en funciones.
- `CapaBases.glifos` ya sabe sobrescribir los modificadores: no cambia.
- **Hay que retirar `GLIFOS_V2`** pasando `cooldown_v2`/`repertorio_de` a `GLIFOS` y `propiedades_usadas` (`hechizo.gd:482-487`) a los modificadores de `permanencia`. Es la deuda HC más pequeña que queda.

**Pruebas de igualdad.**
- **GL1:** las vistas construidas son *iguales* a las tablas `const` de hoy (mismas claves, mismo orden: el orden de `Sigils.GLIFOS` importa para `acciones_en`, `hechizo.gd:529`).
- **GL2:** `prueba_hechizo` (ya compara `GLIFOS` y `GLIFOS_V2`, :73-77), `prueba_grimorio`, `prueba_receta_v2`, `prueba_escritura_glifo` y `prueba_ejes_receta_ui` a 0.

**Coste:** M. **Riesgo:** medio. Las `const` se usan en expresiones de tiempo de compilación, y que el orden del diccionario pase a depender del sistema de archivos es un riesgo real: hay que fijar el orden con un campo `orden`.

**Lo que abre:** «añadir un glifo = un `.tres`», los cofres legendarios que dan glifos (`PLAN_PULSO_RESONANTE` §7) con un recurso que contiene icono y nombre, y la chuleta y el libro sin listas a mano.

### h) Misiones y diálogos

**Medido.**
- `nucleo/misiones.gd` (335 líneas) ya es datos, y **decide expresamente no ser una clase** («Una misión es un Dictionary (se guarda tal cual, por eso no es una clase)», :7).
- Lo que domina es el ESTADO: `oculta → activa → completa`, objetivos `hecho`, guardado JSON y conservar el progreso al redefinir (:63-108, :300-330). Los objetivos los marcan las reglas del nivel desde el código.
- **Los diálogos son tablas de texto `const` por nivel:**
  - `bosque_3d.gd:43` y `jugabilidad_3d.gd:220` (`DIALOGOS`);
  - `bosque_01_3d.gd:84`;
  - `bosque_01_v01_3d.gd:110-138`: 9 constantes `DIALOGO_*` sueltas.

**Veredicto: NO APLICAR.**
- No hay «valor por defecto + modificadores» que construir: una misión no tiene variantes que se sumen. Lo que hay es una máquina de estados que hay que guardar.
- `Misiones` ya cumple lo que importa (un sitio, datos, señales).
- Lo único útil y barato (S) es sacar los diálogos a un `dialogos/<nivel>.json` o a la tabla `DIALOGOS` con el mismo formato en todos los niveles, para que se puedan escribir sin tocar GDScript. Eso es orden, no el patrón.

### i) Zonas y biomas: `presentacion/luz_zona_3d.gd`, `zonas_3d.gd`

**Medido.**
- **`LuzZona3D.ZONAS`** (`luz_zona_3d.gd:34-84`) ya es una tabla de datos con defectos globales (`SOL_INCLINACION`, `SOMBRA_*`, :29-33) y sobrescrituras por fila (`sombra_modo`, `sombra_distancia`, `sombra_blur` en «clasico»): es el patrón sin el nombre.
- **El concepto «bioma» está repartido en al menos 5 sitios con vocabularios distintos:**
  - `estilo` (`@export`, `prueba_test2.gd:720`), con **6 `if estilo == "cueva"`** (:1111, :1468, :1493, :3344, :3517, :4469);
  - `zona_luz` (`@export`, :831);
  - las zonas de `Tinta.PIGMENTOS` («bosque», «tumulo», «bosque_humedo», «volcan»; `tinta.gd:82-88`), que **no casan** con las de `LuzZona3D.ORDEN` («bosque», «cueva», «santuario», «ruinas»…, :85);
  - `Rompible3D.BOTIN_ZONA` (vía `Zonas3D.botin_en`, `zonas_3d.gd:128`);
  - `kit` (`@export`).
- Las escenas `.tscn` repiten la pareja `estilo = "cueva"` + `zona_luz = "cueva"` (`PruebaCueva.tscn`, `PruebaCuevaAgua.tscn`).

**Veredicto: aplicar MÁS ADELANTE, junto con el pantano, la montaña o el desierto** (cuando entre el primer bioma nuevo, no antes).

**Diseño.**
- **Clase `Bioma`** (datos o `.tres`): `id`, `luz` (fila de `ZONAS`), `paleta_suelo` (los PNG que hoy elige `estilo`), `piezas_borde`, `pigmento` (el de la zona), `botin` (fila), `estados_ambientales` ([] → «mojado» en el pantano, «helado» en la montaña), `musica`, `ambiente_sonoro`.
- **Constructor:** `Bioma.construir(id)` = la fila + modificadores de la zona del mapa (`; zona … luz=…` ya es una sobrescritura «fija» de `luz`).
- **Ejecutor:** la maqueta (suelo y borde), `Zonas3D` (luz y rótulo) y `Tinta` (pigmento de la zona).

**Pruebas de igualdad.**
- **BI1:** `Bioma.construir("cueva")` y `Bioma.construir("bosque")` dan los mismos `estilo`/`zona_luz`/PNG que hoy.
- **BI2:** `prueba_materiales_cueva`, `prueba_presentacion`, `prueba_look_diorama` y capturas a 0.

**Coste:** M. **Riesgo:** bajo-medio. **Lo que abre:** el pantano, la montaña y el desierto como filas (+ arte), y la unificación de los vocabularios de zona, que hoy no casan.

---

## 3. Tabla resumen

| candidato | veredicto | coste | riesgo | sitios que deciden lo mismo hoy (medido) |
|---|---|---|---|---|
| c) Mejora/Receta/Consumible/Pigmento | **aplicar ya** | S–M | bajo | cura de la poción ×2 (`objetos.gd:17`, `jugador_3d.gd:47`); `match id` de 4 ramas; pigmento fuera de `construir` (`lanzador_3d.gd:1179`) |
| d) Atributos del jugador | **aplicar ya** | S–M | bajo | vel_andar/correr ×3 (`prueba_test2.gd:27-28`, `jugador_3d.gd:83-84`, `:138-139`) |
| a) Enemigo | más adelante (próximo enemigo) | M | medio | identidad en 3 sitios (`combate_3d.gd:171-180`, `:1577-1583`, `gatopedro_3d.gd:61-68`); `elemental` ×54; loberno sin nombre propio |
| g) Glifo `.tres` | aplicar (próximo glifo o al retirar `GLIFOS_V2`) | M | medio | 9 líneas en 4 archivos por glifo; `GLIFOS` y `GLIFOS_V2` a la vez |
| b) Pieza reactiva | más adelante (paso 1 S antes) | S + M | medio-alto | `on_spell_hit`/`spell_reacts` duplicados (`objetos_3d.gd:420/456`); 62 `tags.has` en `objetos/` |
| i) Bioma | más adelante (primer bioma nuevo) | M | bajo-medio | 6 `if estilo == "cueva"` + 4 vocabularios de zona |
| f) EfectoVfx | más adelante, Pipeline | M–L | medio | 13 `match` + 55 `if` por elemento |
| e) DatosNivel | más adelante = M5 | L | alto | 128 `m.get`/`m.call` desde las reglas |
| h) Misiones/diálogos | **no aplicar** (solo ordenar los diálogos) | S | bajo | — |

---

## 4. Orden recomendado

1. **`Atributos` + `Mejora` (d + c, primera mitad).**
   - Por qué primero: la síntesis decidida el 24/10 va a nacer ahora, y si nace con su propio lenguaje habrá que reescribirla.
   - Pruebas: AT1–AT2 y MJ1.
   - De paso se arregla la cura duplicada de la poción y las tres copias de 1,6/3,0.
2. **Pigmento como fuente de modificadores en `Hechizo.construir`** (c, segunda mitad, S).
   - Cierra la fuga de `lanzador_3d.gd:1179` y el lab enseña el `origen` «pigmento».
   - A la vez conviene **retirar `GLIFOS_V2`**: `cooldown_v2`, `repertorio_de` y `propiedades_usadas` deben leer `GLIFOS`.
   - Pruebas: MJ2 y `prueba_hechizo`.
3. **`Enemigo` de datos + `Combate3D` como ejecutor** (a), en la semana en que entre el siguiente enemigo o el loberno pida nombre.
   - Pruebas: EN1–EN3.
   - Conviene diseñar una `CapaBases` genérica (`Capa.de("enemigo")`) en vez de copiar la del hechizo.
4. **`Glifo` como `.tres`** (g), cuando entre el próximo glifo del cofre legendario.
   - Pruebas: GL1–GL2.

Después, cuando haya contenido que lo pida: el paso 1 de `Pieza` (b), `Bioma` (i) y `DatosNivel` (e, que es la M5).

**Herramienta común que conviene sacar en el paso 3, no antes.** `_aplicar`, `_leer`, `_escribir`, `tabla()` y `texto_modificadores()` se pueden extraer a una base `DatosModificables` (`RefCounted`), de la que hereden `Hechizo`, `Atributos` y `Enemigo`. Hacerlo en el paso 1 obligaría a tocar `Hechizo`, que está estable y probado. Con la segunda clase ya se verá qué es común de verdad.

---

## 5. Advertencia honesta: dónde el patrón NO encaja

- **Donde manda el estado en marcha.** La IA de `Combate3D` (`_ia` :829-950, el empujado, el hitstop, el hundimiento :1875-2041), la tinaja de `Reactivo3D` (:898-1350), `Misiones` y el agua (`AguaSim3D`, 1148 líneas): ahí lo importante es *cómo cambia el estado con el tiempo*, no *con qué valores se construye*. Meterlo en una clase de datos solo añade una capa. El patrón sirve para la *ficha*, nunca para el *comportamiento*.
- **Donde no hay variantes que sumar.** Una misión, un diálogo o una cinemática no son «base + modificadores». Forzar `op: suma` sobre texto o sobre una lista de objetivos es complicar sin ganar nada.
- **Donde el «dato» es en realidad código de dibujo.** `hielo.gd` construye mallas. El perfil puede decir *qué*, pero el *cómo* sigue siendo código, y hay que aceptarlo.
- **El coste oculto del lenguaje por nombre.** `_escribir`/`_leer` con `get`/`set` hacen que una errata en `campo` sea silenciosa: `Hechizo` no avisa de campos desconocidos en `_aplicar`, mientras que `Reactivo3D` sí lo hace con `PAPELES_VALIDOS`.
  - Cualquier clase nueva debería validar `campo ∈ CAMPOS` al cargar la tabla, con un `push_warning`, y una prueba que recorra todas las tablas.
  - Si no, el patrón cambia `if` visibles por errores invisibles.
- **Refactor no es rediseño.** HC1–HC3 funcionaron porque eran mudanzas con prueba de igualdad y sin reglas nuevas. Si en el refactor del enemigo se cuelan reglas nuevas (variantes elementales), ya no se sabrá si un fallo es de la mudanza o del diseño.
  - La única excepción que propongo es el nombre del loberno, y debe declararse.
  - Las variantes deben ir en un paso posterior, separado, como HC4.
