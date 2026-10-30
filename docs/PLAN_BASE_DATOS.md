# Plan · Base de datos del juego: objetos, botín, síntesis, guardado y estados del mundo

29/10/2026 · propuesta para que Pablo la valide y la programe **Sonnet** por fases. Sale de leer el proyecto tal como está hoy
(`nucleo/objetos.gd`, `estado.gd`, `flags.gd`, `misiones.gd`, `tinta.gd`, `consumibles.gd`, `objetos/recolectable_3d.gd`,
`rompible_3d.gd`, `enemigos/botin_goblin.gd`, `escenas/puzle.gd`, `docs/RECOGIBLES_DB.md`, `MATERIALES_CUEVA.md`,
`DISENO_FUTURO.md` §7, `ESTADOS_SUELO.md`, `ANALISIS_EOW.md`) y del esbozo de tablas de Pablo del 29/10.

**Las tablas ya están escritas** en `nucleo/datos/*.tsv` (una por sistema, editables en hoja de cálculo y legibles en git). Este
documento dice qué significan, qué cambia en el código y en qué orden se programa. Nada de lo de abajo está cableado todavía.

> Regla 7 de `PROPIETARIOS.md`: este documento lo pidió Pablo el 29/10 («implementa un plan de acción»). Cuando se apruebe, se
> integra en `PLAN_ARREGLOS.md` y `DISENO_FUTURO.md` §7 y este archivo se retira.

---

## 0. Qué hay hoy y qué falta (medido)

| sistema | dónde vive hoy | qué le falta |
|---|---|---|
| Catálogo de objetos | `Objetos.DATOS` (43 ids), `PLANTAS`, `MINERALES`, `CALIDADES`, `CATEGORIAS` en código | no dice **para qué sirve** un objeto en una receta ni **de dónde sale**; añadir uno es tocar tres diccionarios |
| Botín | `Rompible3D.BOTIN_ZONA`, `BotinGoblin` (solo colmillo), `CofrePuzle.da=`, `Combate3D.Botin3D` (oro) | tres formas distintas de tirar; limo, chamán, gólem y elemental no sueltan nada; un objeto no cae al suelo (va directo a la bolsa) |
| Reactivos del mundo | `Reactivo3D` (papeles), `Recolectable3D`, `MineralPulso`, `Lava3D`, `GeodaPulso3D` | reaccionan, pero solo las plantas y los minerales **dan** algo; hierba, árboles, telarañas y setos no |
| Síntesis | **no existe** (`DISENO_FUTURO.md` §7, decidido el 24/10: vida, tinta y pigmentos salen de recetas; la ropa y los glifos no) | todo |
| Mejoras | `Estado.mejoras` (id → nivel) y el alquimista 2D; `Tinta` lee `tinta_jefe` / `tinta_secreto` | no hay tabla de qué hace cada mejora ni tope |
| Guardado | `Flags` → `user://flags.json`, `Misiones` → `user://misiones.json`, en los puntos de guardado de `Jugabilidad3D` | **la bolsa, el oro, las mejoras, la tinta, la ropa y la posición no se guardan**; tres archivos sin versión común; no hay «continuar» |
| Estados del mundo | por casilla (`EstadosSuelo3D`: mojada, helada, quemada, electrificada, segada) y por personaje (quemadura, mojado, congelado, **veneno** ya en `Jugador3D.envenenar`) | no hay estados **de zona** (calor, frío, niebla tóxica, oscuridad…) ni protección contra ellos |

---

## 1. Principios

1. **El comportamiento son datos.** Una fila por objeto, por fuente, por receta, por estado. El código pregunta a la tabla; no hay
   `if id == "seta_asada"`. Es la regla del proyecto (`CONTEXTO.md`) y la idea 1 del estudio de EoW: *tablas que se referencian*.
2. **TSV, no `.tres` ni SQLite.** Pablo edita en hoja de cálculo, git enseña el diff, y una prueba sin escena valida la tabla entera.
   SQLite no aporta nada: no hay consultas relacionales en tiempo de juego, solo lecturas por id. Los `.tres` siguen para lo que ya
   son `.tres` (runas, gestos).
3. **Datos fijos ≠ progreso.** Las tablas de `nucleo/datos/` no cambian al jugar. Lo que cambia va a **un solo** archivo de partida
   (`user://partidas/ranura_<n>.json`, §5) con versión.
4. **Etiquetas, no ingredientes.** Una receta pide «`vital` ≥ 4 y `calor` ≥ 2», no «seta asada + bayas» (`RECOGIBLES_DB.md` §3).
   Así tres objetos de calor valen para todas las recetas de calor. Un épico puede ir como **ancla** (ingrediente fijo) para que la
   receta se lea en el libro: «Núcleo de eco + 6 de tinta».
5. **Lo que no es atrezo se coge o se usa.** Todo objeto de la tabla tiene `uso` (ingrediente, equipar, pigmento, clave, ropa, glifo, moneda). Lo
   que no está en la tabla es decorado y no se puede coger. Una pieza del mundo que reacciona está en `reactivos_mapa.tsv` con lo que
   hace y lo que da.
6. **Compatibilidad hacia atrás.** `Objetos.DATOS`, `PLANTAS`, `MINERALES`, `Rompible3D.BOTIN_ZONA` y `Flags` siguen funcionando para
   quien los lee hoy: se **generan** desde las tablas. Ninguna fase rompe lo que ya pasa las 127 pruebas.

---

## 2. Las tablas (`nucleo/datos/`)

Diagrama de cómo se referencian (clave → tabla):

```
objetos.tsv ─────────┬── fuentes.tsv        (objeto → de dónde sale)
   id, etiquetas,    ├── botin_tablas.tsv   (tabla → objeto, peso, min, max)
   potencia, uso,    ├── recetas.tsv        (requiere etiquetas → da objeto | mejora)
   efecto            └── reactivos_mapa.tsv (pieza + elemento → hace, botín, flag)
mejoras.tsv          (id → tope, por_nivel, campo)        ← recetas.tsv «mejora:<id>»
estados_mundo.tsv    (id → efectos, protección, dinámico) ← objetos.efecto «resiste=|inmune=»
partida (json)       (progreso: bolsa, mejoras, flags, estados, mundo, misiones)
```

### 2.1 `objetos.tsv` — el catálogo (77 filas: 43 hay, 34 nuevas)

| columna | valores | para qué |
|---|---|---|
| `id` | texto | la clave de siempre (`Estado.agregar`) |
| `nombre`, `desc` | texto | bolsa y avisos |
| `categoria` | `hongo` `planta` `raiz` `mineral` `animal` `botin` `consumible` `pigmento` `clave` `ropa` `glifo` | pestañas de la bolsa y filtros del libro de síntesis. La bolsa de hoy (`componentes` / `pociones` / `clave`) sale de agrupar: consumible+pigmento → pociones; clave+ropa+glifo → clave; el resto → componentes |
| `calidad` | `comun` `epico` `legendario` | lo de `Objetos.CALIDADES` |
| `pila` | entero | cuántos por hueco. **Hoy `Estado.PILA_MAX` = 9 para todo**; pasa a leerse por objeto (20 los ingredientes, 9 los frascos, 1 la ropa y las llaves, 999 el oro) |
| `etiquetas` | lista de §2.2 | lo que aporta a una receta |
| `potencia` | 1–5 | cuánto aporta cada etiqueta (común 1–2, transformado +1, épico 4–5) |
| `uso` | `ingrediente` `equipar` `pigmento` `clave` `ropa` `glifo` `moneda` | qué hace la tecla de usar en la bolsa |
| `efecto` | `k=v;k=v` | los números de un consumible (`cura=40`, `frascos=1`, `dura=12;tasa=3`, `pigmento=<id>`, `resiste=calor;dura=90`, `inmune=veneno;dura=60`) o de una prenda (`ranura=exterior;inmune=frio;defensa=1`) |
| `zona` | `bosque` `cueva` `todas`… | dónde buscarlo (diario) |
| `forma`, `color` | las formas de `Objetos.dibujar`, hex | el icono dibujado de hoy, hasta que haya PNG |
| `modelo` | id de pieza | el `.glb` del mundo (botín en el suelo) y del que se renderiza el icono (§7) |
| `estado` | `hay` `nuevo` | si ya existe en `Objetos.DATOS` |

**Nuevos (34).** Hongos: `esporas_luminosas`, `seta_cristalizada`, `seta_palida` (tóxica). Plantas: `alga_cargada`, `musgo_cueva`,
`helecho_cueva`, `resina`, `corteza`. Animal: `panal`, `pluma`, `seda`, `jiron_escudo`, `baba_limo`, `pluma_chaman`, `polvo_golem`.
Minerales: `carbon`, `obsidiana`, `polvo_cristal`, `cristal_cargado`, `ceniza_geoda`. Épico: `savia_elemental` (lo suelta el jefe
del Bosque). Consumibles: `pocion_grande`, `antidoto`, `frescor`, `abrigo`, cinco `pigmento_*` (hoy los pigmentos son solo filas de
`Tinta.PIGMENTOS` sin objeto; pasan a ser frascos que se usan con Q y llaman a `Tinta.activar_pigmento`). Clave: `llave` como objeto.
Ropa: `capa_escarcha`, `tunica_salamandra`, `capucha_musgo` (resultado de bordar una prenda que ya se tiene, §4.3).

### 2.2 Vocabulario de etiquetas (cerrado)

`calor` `frio` `agua` `electrico` `tierra` `viento` `resonante` `vital` `tinta` `raro` (los diez de `RECOGIBLES_DB.md` §3) y dos
nuevos: **`toxico`** (veneno: baba de limo, pluma de chamán, seta pálida; dan el antídoto y el forro de musgo) y **`proteccion`**
(corteza, seda, colmillo, jirón, polvo de gólem; dan el bálsamo, la defensa y los bordados). La prueba de la tabla rechaza cualquier
etiqueta fuera de esta lista.

### 2.3 `fuentes.tsv` — de dónde sale cada objeto (una fila por vía)

`fuente` ∈ `recoger` `reaccion` `pulso` `golpe` `romper` `enemigo` `cofre` `tabla` `reactivo` `receta` `comprar` `mision`. `de` es la
pieza o el objeto del que sale, `via` lo que hay que hacerle (elemento, `golpes:n`, `pulso`, `E`), `condicion` la expresión `si=` de
`Puzle3D`, `prob` / `min` / `max` la tirada. Sustituye a `Objetos.PLANTAS` (las filas `reaccion`), a `MINERALES` (las `golpe`) y a
`BotinGoblin` (las `enemigo`). El diario de la bolsa («dónde se consigue») se escribe solo desde aquí.

### 2.4 `botin_tablas.tsv` — tablas de botín con pesos (el `RegionItemDrop` de EoW)

`tabla` → filas `objeto, peso, min, max`. `nada` es una fila más (en EoW la mayoría de los jarrones salen vacíos). Quien tira:
jarrones y cajas (`jarron_<zona>`: la zona de `Zonas3D` elige la tabla, como hoy elige la fila de `BOTIN_ZONA`), hierba segada,
árboles golpeados, setos consumidos, cada enemigo al morir, y los cofres con `da=tabla:<id>`. Una fila con `independiente=si` hace
tirada propia (el goblin da oro **y** puede dar colmillo).

### 2.5 `recetas.tsv` — síntesis (§4)

### 2.6 `mejoras.tsv` — qué hace cada mejora del personaje y hasta dónde (§4.2)

### 2.7 `reactivos_mapa.tsv` — piezas del mundo que reaccionan y dan loot (§3.2)

### 2.8 `estados_mundo.tsv` — estados de zona (§6)

---

## 3. Loot y recompensas

### 3.1 Cómo cae el botín

Hoy el oro cae al suelo (`Combate3D.Botin3D`, imantado) y **cualquier otro objeto va directo a la bolsa** con aviso (`BotinGoblin`,
`Rompible3D`). Es una incoherencia que `PENDIENTES.md` ya anota. Propuesta: **una sola pieza de botín**, `objetos/botin_objeto_3d.gd`
(`BotinObjeto3D`), que hereda el imán y el salto del oro y enseña el `modelo` del objeto (o, mientras no haya `.glb`, una esfera con el
color del icono). Al tocarla: `Estado.agregar` + `AvisoObjeto.mostrar`. Si la bolsa está llena, se queda en el suelo (hoy se pierde).
`Botin.tirar(tabla, pos, zona)` en `nucleo/botin.gd` hace la tirada y crea las piezas; es la **única** función que reparte botín.

### 3.2 Objetos reactivos del mapa (lo que pide Pablo)

Las piezas que ya reaccionan siguen igual; lo nuevo es que **reaccionar puede dar algo** o ejecutar una acción, y está en
`reactivos_mapa.tsv`. Lo más valioso por lo que cuesta:

| pieza | llega | pasa | da | coste |
|---|---|---|---|---|
| hierba | viento o golpe F | se siega (ya existe `segada`) y rebrota a los 60 s | tabla `hierba_segada` (85 % nada, bayas, flor) | bajo: una tirada al segar |
| árbol | golpe F | se sacude (hojas) | tabla `tronco_golpe` (resina, corteza), cada 30 s | bajo: papel `+sacudible` en `Reactivo3D` |
| seto / tronco / puerta goblin | fuego | se consume (hoy) | tabla `seto_quemado` (30 % carbón) | muy bajo |
| **colmena** (pieza nueva, en un árbol) | viento | cae el panal | 1–2 `panal`, flag | medio: pieza y modelo |
| colmena | fuego | arde: nube de **veneno** 3 s y sin panal | nada | premia usar el viento |
| **nido** (pieza nueva) | viento | suelta una pluma, cada 45 s | `pluma` | medio |
| telaraña | hielo | se hiela: deja de enganchar y se recoge con E | `seda` | bajo: papel `+helable` |
| lava | **hielo** (hoy, igual que agua) | se enfría 10 s | `obsidiana` en vez de basalto | bajo: `Lava3D` distingue `frio` de `agua` |
| cristal resonante | rayo | queda cargado 20 s | la siguiente esquirla es `cristal_cargado` | bajo |
| geoda | pulso | explota (hoy) | 1–2 `ceniza_geoda` en el suelo | muy bajo |
| cofre | E **con llave** | gasta la llave de la bolsa | `da=` | bajo: condición `tener.<objeto>` en `si=` |
| fogata / brasero encendido | E | **hoguera**: síntesis de campo + guardar | — | ver §4.4 |

Cada fila da una `flag` si no debe repetirse (`<nivel>.<sala>.colmena_<id>`), o un `cada_s` si rebrota.

### 3.3 Enemigos

Hoy solo el goblin suelta material. Con `botin_tablas.tsv`: goblin (colmillo 60 %), goblin con escudo quemado (`jiron_escudo`,
lo decide `Escudo3D`), limo (`baba_limo`), chamán (`pluma_chaman`), gólem (`polvo_golem` ×1–2), elemental del Bosque
(`savia_elemental`, épico, siempre). `Combate3D._morir` deja de llamar a `BotinGoblin.soltar` y llama a `Botin.tirar(tabla_del_enemigo)`.

---

## 4. Síntesis

### 4.1 Cómo funciona una receta

`requiere` es una lista `etiqueta>=n`. La bolsa cumple si, sumando `potencia` de los objetos que llevan esa etiqueta, llega a `n`.
**El jugador elige qué gastar**: el libro de síntesis enseña la receta, la barra de cada etiqueta y los objetos de la bolsa que la
suben; se arrastran (o se pulsa) hasta llenar. Lo que sobra no se devuelve (una seta asada de calor 2 llena «calor ≥ 2» exacta; dos
flores ardientes también, y se gastan las dos). `ancla` es un ingrediente obligatorio además de las etiquetas (los épicos y la
prenda a bordar). `oro` es lo que cobra el alquimista (0 en la hoguera).

`da` es `objeto:n` o `mejora:<id>` (sube un nivel de `mejoras.tsv`). `donde` ∈ `alquimista`, `hoguera` (ambas separadas por coma).
`se_conoce` decide si aparece en el libro: `siempre`, `al tener los ingredientes` (se descubre al llevar lo que pide), `flag:<nombre>`,
`mejora:<id>>=n` (la II pide la I), `tener:<objeto>`, `al entrar en una zona con <estado>` (el frescor aparece al pisar el calor:
la receta se enseña cuando hace falta, no antes).

### 4.2 Las recetas (29 filas en `recetas.tsv`)

**Consumibles (8):** poción, poción grande, infusión de brezo (ancla helecho), bálsamo protector, tónico de tinta, antídoto, frasco de
frescor (resiste calor 90 s), brasa embotellada (resiste frío 90 s).

**Pigmentos (5):** uno por los cuatro de `Tinta.PIGMENTOS` y uno nuevo, **Azul de Eco** (`resonante`: quita el recargo del 25 % de ᚱ
60 s; ancla polvo de cristal). Todos piden `tinta ≥ 2` más la etiqueta de su elemento ≥ 3.

**Mejoras del personaje (13, en niveles I/II/III):**

| mejora | hace | nivel I | niveles altos |
|---|---|---|---|
| `vida_max` | +20 de vida (×5) | vital 6, tierra 2 | III pide `savia_elemental` |
| `frascos_tinta` | +1 frasco de reserva (3 → 6) | tinta 4, resonante 2 | II pide `geoda_resonante` |
| `tinta_frasco` | cada frasco recarga +10 % | tinta 4, electrico 2 | II pide `nucleo_eco` |
| `paginas` | +1 página del grimorio (3 → 5) | tinta 6, proteccion 2, raro 4 | con flag de la librera |
| `huecos_glifo` | +1 glifo por página (→ 6) | resonante 4, tinta 3 | la librera sigue vendiéndolos: mismo contador |
| `capacidad` | +4 huecos de bolsa | tierra 3, proteccion 2 | sustituye la compra de hoy |
| `cura_pocion` | las pociones curan +10 | vital 5, agua 2 | |
| `defensa` | la jugadora gana DEF plana (1, 2) con la fórmula de `Dano` | proteccion 4, tierra 3 | simetría con los enemigos |

Así cada épico tiene **un** destino escrito (`MATERIALES_CUEVA.md` lo dejaba «por decidir»): núcleo de eco → frasco hondo II, geoda →
frasco de reserva II, savia del elemental → corazón robusto III.

### 4.3 Ropa: skins con mejoras

Pablo decidió (24/10) que **la ropa no sale de recetas**: se encuentra en cofres o misiones. Se respeta, y se añade lo que pide
ahora: una prenda que ya se tiene se **borda** con una receta de tipo `ropa`, que consume la prenda y da la versión mejorada
(`capa` + frio 4 + proteccion 2 → `capa_escarcha`). La prenda nueva tiene `efecto`: `inmune=<estado>` y `defensa=1`. Tres propuestas,
una por estado dañino de §6: capa de escarcha (frío), túnica de salamandra (calor), capucha de musgo (veneno). Visualmente son el
mismo `.glb` de `arte/modelos/ropa.json` con otro material (tinte + emisión), hasta que haya modelos propios. **Decisión para
Pablo:** ¿tres skins completas (conjunto de tres prendas, un modelo cada una) o tres prendas sueltas bordadas? Lo segundo cabe en
este plan; lo primero es arte.

### 4.4 Dónde se sintetiza

- **Alquimista** (puesto del Bosque, ya existe como NPC): todas las recetas, cobra `oro`.
- **Hoguera** (fogata o brasero encendido, tecla E): solo las de `donde` = hoguera (consumibles básicos), gratis, y **guarda la partida**.
  Así el punto de guardado y el taller de campo son la misma cosa, como en tantos juegos, y las fogatas del mapa ganan un uso.

Interfaz: una pestaña «Síntesis» más en `presentacion/ui/menu_pestanas.gd` (es del **Pipeline**: el Juego entrega `Sintesis` con
señales y el Pipeline la pinta; ver §8).

---

## 5. Guardado: una partida, un archivo

### 5.1 Lo que se guarda

Prototipo real en **`nucleo/datos/partida_ejemplo.json`**. Secciones:

| sección | de dónde sale | hoy |
|---|---|---|
| `meta` | ranura, fecha, segundos, punto de guardado | no existe |
| `jugadora` | `mapa_actual`, `entrada` (la de `SalidaNivel3D`), `posicion` [x, y, z], `vida`, `aguante` (§6), `ropa_puesta`, `consumible_equipado`, `opciones` | no se guarda |
| `tinta` | `Tinta.actual`, `frascos`, `pigmento`, `pigmento_s` | no se guarda |
| `bolsa` | `Estado.oro`, `capacidad`, `items` | no se guarda |
| `mejoras` | `Estado.mejoras` | no se guarda |
| `grimorio` | sellos y glifos conocidos, las páginas preparadas | no se guarda (`Repertoire`) |
| `recetas_conocidas` | las descubiertas | no existe |
| `estados` | entidad → estado con **nombre** (`"abierto"`, `"roto"`, `"derrotado"`) | hoy son flags `true` |
| `flags` | `Flags` (true o entero) | `user://flags.json` |
| `mundo` | estados dinámicos de zona (tormenta activa, nubes de veneno vivas) | no existe |
| `misiones` | `Misiones.a_dic()` | `user://misiones.json` |

### 5.2 `estados` vs `flags`

El esbozo de Pablo usa estados con nombre (`"bosque_cofre_01": "abierto"`). `Flags` solo admite `true` o entero, y el nombre va en tres
trozos `nivel.sala.hecho`. Propuesta: **`Flags` versión 2 admite también una cadena corta** (`poner("bosque1.s1.cofre_01", "abierto")`);
`tiene()` sigue siendo «está puesta», `valor()` da la cadena, y `si=flag.x` de `Puzle3D` no cambia. Al guardar, las flags con cadena se
escriben en `estados` y las demás en `flags`, para que el archivo se lea como el esbozo. Los nombres **mantienen** los tres trozos
(`bosque1.s1.cofre_01`, no `bosque_cofre_01`): es el contrato que ya leen los puzles y las zonas. Coste: `_normalizar`, `a_dic`,
`desde_dic` y `prueba_flags.gd`.

### 5.3 `Partida` (`nucleo/partida.gd`)

Una clase que **reúne** lo de arriba: `Partida.guardar(ranura)` pide a cada sistema su `a_dic()` (`Estado`, `Tinta`, `Flags`,
`Misiones`, `Repertoire`, `Mundo3D` para la posición y los estados de zona) y escribe `user://partidas/ranura_<n>.json`;
`Partida.cargar(ranura)` reparte con `desde_dic()`. **Sustituye** a las dos llamadas sueltas de `Jugabilidad3D` (`Misiones.i().guardar()`,
`Flags.i().guardar()`). `Partida.existe(ranura)` para el «Continuar» del menú. Versión en la raíz; `cargar` migra la 1 (dos archivos
sueltos) a la 2 una vez. `Estado` y `Tinta` ganan `a_dic` / `desde_dic` como ya tienen `Flags` y `Misiones`.

Se guarda **solo** en los puntos de guardado y en las hogueras (como hoy), nunca al cambiar algo: una prueba que reinicia no hereda nada.

---

## 6. Estados del mundo (de zona)

Ya hay estados **por casilla** y **por personaje**. Lo nuevo es el estado **de zona**: se declara en el mapa en la línea de la zona
(`; zona 0,0..20,20 volcan estado=calor` en `Zonas3D`) y vale mientras la jugadora está dentro. Tabla completa en `estados_mundo.tsv`:

| estado | te hace | al suelo y a los hechizos | te protege |
|---|---|---|---|
| **calor** | el **aguante** baja 10/s; a 0, 2 de vida/s; mojarse lo rellena | lo mojado se seca en 6 s; el hielo dura 1/3; el fuego ×1,5 | frescor (90 s) · túnica de salamandra · pisar agua |
| **frío** | aguante −8/s (×2 mojada); junto a un brasero se rellena | el agua se hiela sola en 5 s; el helado no caduca; hielo ×1,5 | brasa embotellada · capa de escarcha · un brasero a ≤ 2 casillas |
| **veneno** | 2 de vida/s dentro de la nube y 3 s después (el `envenenar` que ya hay) | el viento la dispersa 8 s; el fuego la consume | antídoto (quita y 60 s) · capucha de musgo |
| **humedad** | nada | todo nace mojado y vuelve a mojado a los 10 s; la hierba no prende | — (pensado para el pantano) |
| **oscuridad** | ves 4 casillas | fuego, rayo, esporas luminosas y el pulso iluminan | — (la luz) |
| **tormenta** (evento) | nada directo | cada 6 s cae un rayo en una casilla mojada a ≤ 6 | no pisar mojado |
| **vendaval** | te empuja 0,5 casillas/s salvo tras un muro | el fuego se propaga ×2 a favor; los proyectiles se desvían | un bloque de tierra · agacharse |
| **resonancia** | nada | el pulso ambiental cada 8 s (ya existe) | — |

**Aguante** es una barra nueva de `Jugador3D` (0–100, como la estamina de clima de Breath of the Wild) que solo aparece en zonas
con calor o frío: baja dentro, se rellena fuera a 20/s. Un enemigo con `Combate3D` también la tiene (los goblins se cansan en el
volcán); limo de fuego y gólem son inmunes (`inmune` por enemigo, una constante). `veneno`, `tormenta` y `vendaval` son **dinámicos**:
tienen vida propia (una nube nace, dura y se dispersa) y se guardan en `mundo` de la partida; los demás son fijos de la zona.

Los tres estados dañinos tienen las tres respuestas en escalera: un consumible (barato, 90 s), una prenda bordada (permanente) y una
forma de aguantar sin nada (mojarse, un brasero, el viento). Así la síntesis tiene razón de ser en cada zona nueva.

---

## 7. Arte: los materiales del inventario

Hoy los iconos se **dibujan por código** (`Objetos.dibujar`, 11 formas). Con 77 objetos hacen falta iconos de verdad. Propuesta: **un
`.glb` pequeño por objeto** (Meshy, chibi pastel, un objeto por generación) que sirve para dos cosas: el botín en el suelo
(`BotinObjeto3D`) y el icono, que se renderiza del modelo con una herramienta (`herramientas/captura_iconos.gd`: cámara ortogonal a
60°, 128×128, fondo transparente → `arte/iconos/<id>.png`). Un asset, dos usos, y los iconos quedan del mismo estilo que el mundo.
Los prompts, uno por objeto y por familias, están en **`arte/meshy/PROMPTS_INVENTARIO.md`**. Prioridad: lo que sale en el Bosque 01
y la Cueva (ingredientes base y sus reacciones: 24 modelos), luego consumibles y pigmentos (13), luego el resto.

---

## 8. Plan de acción para Sonnet (fases, archivos, pruebas)

> **Estado (30/10):** F0, F1, F2, F3 y F4 programadas con Sonnet y revisadas (diario 281, 283, 285, 287 y 289). Cada fase pasó su prueba
> nueva y las afectadas a 0 fallos con verificación acotada; **la batería completa la lanza Pablo antes del commit**. F5 (arte) empezó con
> la lámina 2D de iconos (diario 288). Pendientes cruzados: Pipeline (pestaña «Síntesis», menú «Continuar», barra de aguante, `Zonas3D`
> con `estado=`, `bolsa_ui` con `Objetos.pila`) y Hechizos (`HechizoVivo` × `factor_persiste` + `viento_zona`, `iluminar`, Azul de Eco,
> páginas del grimorio). Ningún mapa real declara `estado=` todavía ni guarda en hoguera salvo `Jugabilidad3D`.

Reglas de todas las fases: español en código y comentarios; cada fase acaba con `tools\pruebas.cmd` en `TOTAL DE FALLOS: 0`; no se
hace commit (lo hace Pablo); un módulo nuevo nace con `herramientas/prueba_<modulo>.gd`; entrada en `docs/DIARIO.md` al terminar
cada fase; `presentacion/` es del Pipeline (el Juego entrega la clase y sus señales, no la pinta). Sonnet lee este documento, la
tabla de la fase y los archivos que cita, **y nada más** de arranque.

### F0 · `BD`: cargar las tablas y generar lo de hoy (1 sesión)

- **Nuevo** `nucleo/bd.gd` (`class_name BD`, RefCounted, estático): `cargar()` lee los siete TSV de `nucleo/datos/` una vez
  (`FileAccess`, `split("\t")`, cabecera = nombres de columna; listas separadas por coma; `efecto` → Dictionary por `;` y `=`; números
  a `float`/`int`). Acceso: `BD.objeto(id)`, `BD.objetos()`, `BD.fuentes_de(id)`, `BD.tabla(id)`, `BD.receta(id)`, `BD.recetas()`,
  `BD.mejora(id)`, `BD.reactivo(pieza, llega)`, `BD.estado_mundo(id)`. `BD.errores()` devuelve las filas mal formadas.
- **Cambio** `nucleo/objetos.gd`: `DATOS`, `PLANTAS`, `MINERALES`, `CLAVE`, `CURAN`, `CONSUMIBLES` dejan de ser `const` y se
  **construyen** desde `BD` en el primer uso (`static var` + `_asegurar()`); `categoria()` agrupa por la columna `categoria` como dice
  §2.1; `pila(id)` nueva. `efecto()` devuelve el diccionario de la tabla. Todo lo que hoy los lee (bolsa, `Recolectable3D`,
  `MineralPulso`, `AvisoObjeto`, `Consumibles`) no cambia.
- **Cambio** `nucleo/estado.gd`: `huecos_usados` y `sitio_para` usan `Objetos.pila(id)` en vez de `PILA_MAX`.
- **Prueba** `herramientas/prueba_bd.gd`: las siete tablas cargan sin errores; cada `de` de `fuentes` existe como objeto o pieza; cada
  `via` es elemento, `pulso`, `golpes:n`, `E` o `golpe`; cada etiqueta está en §2.2; los épicos tienen potencia ≥ 4; cada `da` de
  `recetas` apunta a un objeto o a una mejora; cada `requiere` solo usa etiquetas del vocabulario; `objetos` tiene los 43 ids que
  tenía `DATOS` (lista fija en la prueba); las 127 pruebas de antes siguen en 0.
- **Hecho cuando** la bolsa del juego enseña lo mismo que ayer y `prueba_bd` pasa.

### F1 · Botín: una sola forma de tirar y de caer (1–2 sesiones)

- **Nuevo** `nucleo/botin.gd` (`Botin`): `tirar(tabla: String, n_tiradas = 1) -> Array[{que, n}]` (pesos, `nada`, `independiente`;
  `tirada_forzada` estática para las pruebas, como ya hacen `Rompible3D` y `BotinGoblin`) y `soltar(mundo, pos, lista)` que crea las
  piezas. `tabla_de_zona("jarron", zona)` → `jarron_<zona>` o `jarron_bosque`.
- **Nuevo** `objetos/botin_objeto_3d.gd` (`BotinObjeto3D`): como `Combate3D.Botin3D` (salto, imán, recoger al tocar) pero con un `id`
  de objeto; modelo = `BD.objeto(id).modelo` si hay pieza, si no una esfera del color del icono con el aro de calidad; si la bolsa está
  llena se queda en el suelo y avisa.
- **Cambio** `objetos/rompible_3d.gd`: `BOTIN_ZONA` y `PERFIL_DEFECTO` desaparecen; `_soltar_botin` llama a `Botin.tirar`. `botin=zona`
  → tabla de la zona; `botin=<objeto>` sigue valiendo.
- **Cambio** `enemigos/combate_3d.gd` `_morir`: `Botin.tirar(tabla_botin)` con `tabla_botin` `@export` por enemigo (goblin, limo, chaman,
  golem, elemental); `enemigos/botin_goblin.gd` se queda como envoltorio de compatibilidad para `prueba_materiales_cueva`. `Escudo3D`
  marca `escudo_quemado` y `_morir` añade la tirada `goblin_escudo`.
- **Cambio** `escenas/puzle.gd` `CofrePuzle`: `da=tabla:<id>`; condición `tener.<objeto>` en `cumple_expr`; `abre_si=tener.llave`
  gasta la llave (`gasta=si`).
- **Cambio** `objetos/recolectable_3d.gd`: tabla de reacciones desde `BD.fuentes_de` (filas `reaccion` con `de` = planta); plantas
  nuevas `musgo`, `helecho_cueva`, `seta_palida` (modelo de la columna `modelo`).
- **Cambio** `objetos/lava_3d.gd`: con `frio` la planta que aparece es `obsidiana`; con `agua`, `basalto` (hoy las dos dan basalto).
- **Cambio** `objetos/objetos_3d.gd` (`Reactivo3D`): al consumirse un combustible, `Botin.tirar("seto_quemado")`; papel `+sacudible`
  (árbol: golpe F → `tronco_golpe`, cada 30 s); papel `+helable` (telaraña + hielo → se recoge con E y da `seda`). `GeodaPulso3D` suelta
  `ceniza_geoda`. `MineralPulso`: `rayo` carga el cristal 20 s → `cristal_cargado`.
- **Nuevo** piezas `colmena` y `nido` en `escenas/puzle.gd` (gramática `; pieza <id> colmena <x> <y>`), con primitivas hasta que haya
  `.glb` (`PiezaPuzle3D.crear`). Hierba: al segar (ya existe) `Botin.tirar("hierba_segada")`, una vez por 60 s por casilla.
- **Prueba** `herramientas/prueba_botin.gd` (tiradas con `tirada_forzada`: pesos, nada, independiente, zona → tabla, bolsa llena deja
  la pieza en el suelo) y `escenario_botin.gd` (una escena con jarrón, seto, telaraña, colmena, lava y un limo: se rompe, se quema, se
  hiela, se sopla, se enfría y se mata; se comprueba lo que hay en la bolsa).
- **Hecho cuando** los jarrones y goblins dan lo mismo que ayer con la tabla, y las piezas nuevas de la tabla de §3.2 dan lo que dice.

### F2 · `Partida`: guardar y continuar (1 sesión)

- **Cambio** `nucleo/flags.gd`: versión 2, admite cadenas (§5.2); `a_dic()` separa `estados` y `flags`; `desde_dic` lee las dos.
- **Cambio** `nucleo/estado.gd`, `nucleo/tinta.gd`, `nucleo/repertoire.gd`: `a_dic()` / `desde_dic()`.
- **Nuevo** `nucleo/partida.gd` (`Partida`): `guardar(ranura)`, `cargar(ranura)`, `existe(ranura)`, `borrar(ranura)`,
  `RUTA = "user://partidas/ranura_%d.json"`, `VERSION = 2`, migración desde `flags.json` + `misiones.json`. Posición y mapa se piden a
  `Mundo3D` (`nivel`, `_jugador.position`) y a `Niveles` (nombre de entrada).
- **Cambio** `escenas/jugabilidad_3d.gd` (línea del «Punto de guardado»): `Partida.guardar(Partida.ranura_actual)` en vez de las dos
  llamadas. Al arrancar un nivel con `Partida.continuar = true`, `cargar` antes de `definir` misiones (como pide `Misiones`) y colocar a
  la jugadora en `posicion`.
- **Prueba** `herramientas/prueba_partida.gd`: guardar → nueva instancia → cargar → todo igual (bolsa, oro, mejoras, tinta, flags con
  cadena, misiones, recetas, posición); el archivo generado se compara campo a campo con `nucleo/datos/partida_ejemplo.json` (mismas
  claves); un archivo de versión 1 migra; uno corrupto no rompe (`push_warning` y partida nueva).
- **Hecho cuando** cerrar el juego en una fogata y abrir «Continuar» devuelve la bolsa y el sitio.

### F3 · Síntesis y mejoras (2 sesiones)

- **Nuevo** `nucleo/sintesis.gd` (`Sintesis`, singleton como `Estado`): `conocidas() -> Array[String]` (aplica `se_conoce` con `Flags`,
  `Estado.mejoras`, la bolsa y `Mundo3D.estado_zona`), `puede(id, eleccion: Dictionary) -> {ok, falta}` (`eleccion` = objeto → n que
  el jugador ha puesto; suma potencias por etiqueta; comprueba `ancla`, `oro`, `donde`), `sugerir(id) -> Dictionary` (rellena la
  elección sola con lo más barato: menos potencia primero, nunca épicos salvo ancla), `hacer(id, eleccion) -> bool` (gasta, da el
  objeto o sube la mejora, `descubierta`/`hecha` señales). Las recetas de `mejora:` llaman a `Mejoras.subir(id)`.
- **Nuevo** `nucleo/mejoras.gd` (`Mejoras`): `nivel(id)`, `tope(id)`, `subir(id)`, `valor(id)` = `por_nivel × nivel`; aplica el campo
  de `mejoras.tsv`: `vida_max`, `capacidad`, `cura_pocion` sobre `Estado`; `frascos_tinta`, `tinta_frasco` sobre `Tinta`
  (`FRASCOS_MAX` pasa a `frascos_max()`); `paginas`, `huecos_glifo` sobre `Repertoire`; `defensa` nueva en `Estado` que
  `Jugador3D.recibir_dano` aplica con `Dano.impacto` (`D_final = máx(0,2·D, D − DEF)`). La librera y el alquimista 2D que hoy suben
  cosas sueltas llaman a `Mejoras.subir`.
- **Cambio** `nucleo/consumibles.gd`: efectos nuevos de la columna `efecto`: `cura_estado`, `inmune`, `resiste`, `pigmento`
  (`Tinta.activar_pigmento`). `Objetos.CONSUMIBLES` sale de la tabla (uso = equipar; los pigmentos, uso = pigmento, se aplican a una página y no entran en la rueda de R).
- **Cambio** `jugador/pj_3d.gd` / `Ropa3D`: `efecto` de la prenda (`inmune=`, `defensa=`) se lee de `BD.objeto(prenda)`; `ropa.json`
  sigue diciendo el `.glb` y las zonas; las prendas bordadas apuntan al mismo `.glb` con `tinte`.
- **Hoguera:** `Reactivo3D` fogata/brasero encendido + E → `hoguera_abierta` señal; `Jugabilidad3D` guarda y abre la síntesis con
  `donde = hoguera`. El alquimista (NPC del Bosque) abre con `donde = alquimista`.
- **Pipeline (pedir, no hacer):** pestaña «Síntesis» en `menu_pestanas.gd`: lista de `Sintesis.conocidas()`, barras por etiqueta,
  los objetos de la bolsa que suben cada una, botón «Sugerir», «Hacer». El Juego deja un escenario sin ventana que lo ejercita por API.
- **Prueba** `herramientas/prueba_sintesis.gd`: con una bolsa fija, cada receta de la tabla es o no posible como dice su `requiere`;
  `sugerir` nunca gasta un épico que no sea ancla; `hacer` quita lo justo, da lo que dice, sube la mejora y respeta el tope;
  `se_conoce` en sus seis formas; el bordado consume la prenda; `defensa` entra en `recibir_dano` con el suelo del 20 %.
- **Hecho cuando** en el Bosque se hace una poción en la fogata con bayas y helecho, y el alquimista sube la vida con la receta I.

### F4 · Estados del mundo (2 sesiones)

- **Nuevo** `mundo/estado_zona_3d.gd` (`EstadoZona3D`): lee `estados_mundo.tsv`; `Zonas3D` acepta `estado=<id>[,<id>]` en la línea
  `; zona`; `Mundo3D.estado_zona(celda) -> Array[String]`; señal `estado_zona_cambio(entrando, saliendo)`.
- **Jugadora:** `aguante` (0–100) en `Jugador3D`, baja/sube según la tabla (`calor`, `frio`, mojada ×2), a 0 daña; `protegida(estado)`
  mira consumible activo (`Consumibles.resiste`), ropa (`inmune=`) y las condiciones de la tabla (mojada; brasero a ≤ 2 casillas:
  `Reactivo3D` encendido en el radio). HUD: barra de aguante solo cuando hay estado (Pipeline).
- **Suelo y hechizos:** `EstadosSuelo3D._decaer_estado` lee multiplicadores del estado de la zona (secado, hielo); `HechizoVivo`
  multiplica `persiste` por el factor de su elemento en la zona; `AguaSim3D` hiela sola con `frio`.
- **Veneno dinámico:** `mundo/nube_veneno_3d.gd` (`NubeVeneno3D`, Area3D con vida): nace de la bola del chamán al explotar
  (`enemigos/bola_veneno_3d.gd`), de la colmena quemada y de piezas `; pieza <id> nube_veneno x y`; envenena a quien está dentro (lo
  de `Jugador3D.envenenar` y `Combate3D`); el viento la empuja/dispersa, el fuego la consume. Se guarda en `mundo` de la partida.
- **Tormenta y vendaval:** `EstadoZona3D` con temporizador y dirección; acción de puzle `hace=zona.poner(tormenta,60)`; el rayo de la
  tormenta reutiliza la descarga del charco (`EstadosSuelo3D` electrificada 0,6 s); el vendaval es una fuerza en `Jugador3D._physics`
  y en `HechizoVivo` (velocidad + viento).
- **Oscuridad:** viñeta y luz en la jugadora (Pipeline, `LuzZona3D`); el Juego solo expone `estado_zona` y «ilumina» (fuego, rayo,
  esporas luminosas: `Lanzador3D` marca `iluminado(celda, 10 s)`); enemigos con `oscuridad`: `Combate3D` ve a ≤ 3 casillas.
- **Enemigos:** `Combate3D` gana `aguante` e `inmune_estados` por tipo (limo de fuego, gólem).
- **Prueba** `herramientas/prueba_estados_mundo.gd` (sin escena: aguante baja y sube con los números de la tabla; protección por
  consumible, por prenda, por mojada; nube de veneno envenena, el viento la mueve, el fuego la quita; tormenta cae solo en mojado) y
  `escenario_estados_mundo.gd` (un mapa con cuatro zonas: calor, frío, veneno, oscuridad; la jugadora cruza cada una con y sin
  protección y se miden vida y aguante).
- **Hecho cuando** el frescor hecho en F3 deja cruzar C3 sin perder vida y sin él se pierde lo que dice la tabla.

### F5 · Arte y pulido (Pipeline, en paralelo desde F1)

- `arte/meshy/PROMPTS_INVENTARIO.md` → `.glb` en `arte/meshy/entrada/`, piezas en `arte/piezas/`, `herramientas/captura_iconos.gd` →
  `arte/iconos/<id>.png`; la bolsa usa el PNG si existe y, si no, `Objetos.dibujar`. Modelos de `colmena`, `nido`, `obsidiana`.
- Pestaña de síntesis, barra de aguante, viñeta de oscuridad, VFX de las nubes y la tormenta.

Orden y dependencias: **F0 → F1 → F2 → F3 → F4**; F5 en paralelo desde F1. F2 no depende de F1 (puede ir antes si urge «Continuar»).
Cada fase cabe en una o dos sesiones de Sonnet con este documento, la tabla y los archivos citados.

---

## 9. Decisiones para Pablo (antes de F0)

1. **Etiquetas con elección del jugador** (§4.1) o recetas por ingrediente fijo. El plan asume etiquetas con `ancla` para los épicos.
2. **`estados` con cadena en `Flags`** (§5.2) o dejar todo en `true` y que `estados` sea solo cómo se escribe el archivo.
3. **Hoguera = punto de guardado + síntesis de campo** (§4.4): ¿sí a que las fogatas guarden?
4. **Ropa bordada** (§4.3): tres prendas sueltas con tinte, o tres conjuntos con modelo propio (arte).
5. **Aguante** (§6): ¿barra nueva, o el calor y el frío dañan directamente sin aviso? La barra avisa y da tiempo a reaccionar.
6. **Pila por objeto** (§2.1): 20 ingredientes, 9 frascos, 1 ropa y llaves. Hoy es 9 para todo.
7. **Las tres setas de color** siguen dando la misma `seta` (como recomienda `MATERIALES_CUEVA.md`).
8. De los 34 objetos nuevos, cuáles entran en la primera tanda. Propuesta por lo que aportan: `obsidiana`, `polvo_cristal`, `llave`,
   `baba_limo`, `pluma_chaman`, `polvo_golem`, `savia_elemental`, `resina`, `corteza`, `seda`, los cinco `pigmento_*`, `antidoto`,
   `frescor`, `abrigo`; `colmena`, `nido`, `panal`, `pluma` cuando haya modelo.
