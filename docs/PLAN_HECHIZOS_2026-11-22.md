# Plan de HECHIZOS Y LIBRO (22/11/2026)

22/11/2026 · contexto **dirección (análisis)** · **plan para que Pablo decida; nada implementado.** Parte de `CATALOGO_EXISTENTE_2026-11-22.md` (§0, §2, §4), de las propuestas H1–H12, TU1–TU6 y M1 de `PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md`, de `DIBUJAR_EN_GAMEPLAY_2026-11-21.md`, de `REFERENCIAS_JUEGOS_2026-11-21.md` §2 y de la ruta de `PUZLES_DEMO_RUTA_2026-11-20.md`. Las cifras dudosas se han vuelto a mirar en el código (§1).

**Costes:** **B** = una tarde o menos, casi todo datos o mapas · **M** = un par de días, con interfaz o lógica nueva · **A** = una semana o más, sobre todo el libro.
**Vocabulario del código** (para leer las rutas): en el código, `SIGILS` y `TrazosRectos.SELLOS` son los **glifos**; los **sellos** de diseño (elementos) son `ELEMENTS` y `TrazosRectos.ELEMENTOS`.

---

## 0. Resumen y orden propuesto

**Rehecho el 22/11** al integrar las mejoras de glifos de Pablo (`docs/MEJORAS_HECHIZOS_MYSTRALIA_2026-11-22.md`, H14) y la repetición a la vez (H13). Ver §11. **Primero lo que se juega en la demo** (glifos ᛇ ᛁ ᛜ ᛏ ᚱ ᛒ con fuego, agua y tierra); después, lo que espera a que crezca el libro (P3, aplazada).

### 0.1 Lo que entra en la demo
| Orden | Bloque | Qué resuelve | Coste | Depende de |
|---|---|---|---|---|
| 1 | **B1 · Montar la demo de verdad** | Arranque con fuego, ᛇ y ᛜ; lo demás, en cofres. **Hecho en parte** (§2.2b) | B–M | La minimazmorra del tutorial (por diseñar) y TU2 |
| 2 | **B8 · M1, cifras del libro** | Medir antes de cambiar el libro | B | Nada (aprobada, en pausa) |
| 3 | **B9a · Qué glifos suben el daño** (H14 §10) | La base del balance de todo lo demás | B (un dato por glifo) + regenerar los golden | **P9** |
| 4 | **B9b · Barrera legible con la tabla C19** (H14 §3) | Saber qué para cada barrera y cuál se irá | M | La tabla de combate (`nucleo/contacto.gd`, ya hecha) |
| 5 | **B9c · Flecha: trayectoria completa en la previsión** (H14 §8) · **hecho 23/11** | Ver adónde llega antes de lanzar | B–M | B9a (el daño implícito sale de ahí) |
| 6 | **B9d · Sobrecarga legible** (H14 §4, la parte de la demo) | Progreso, umbral y coste antes de soltar | B–M | Coordinar con GAMEFEEL (arco dorado del HUD) |
| 7 | **B3 · Presentación de glifos (H5, H6, H8)** | Que cada glifo nuevo se entienda al ganarlo | M | B1 |
| 8 | **B4 · Coste visible al dibujar (H9)** | Que la tinta se lea en el libro | B | Mejor después de B9a (cambia los números) |
| 9 | **B9e · ᚱ pulso se distingue de un hijo** (H14 §9) | Que propagar y crear otro hechizo no se confundan | B | Ver nacer el hijo (B2) si hay hijos |
| 10 | **B5 · Selector de página activa (H10)** | Preparar en el libro y cambiar en combate | M | P6 |
| 11 | **B6 · ᛒ que viaja (H11)** | Más usos de ᛒ por reglas generales | M | P8 |

### 0.2 Después de la demo (glifos que no caben en el primer libro: ⧖, ᚠ, ᚷ, ᛉ, ᚨ, ᚢ)
| Orden | Bloque | Qué resuelve | Coste | Depende de |
|---|---|---|---|---|
| 12 | **B2 · ⧖ dibujable y Carga** (H14 §4) | ⧖ fuera de la paleta F1 y **solo como carga**: el disparador pasa a los dos círculos | B + M | P3, P5 |
| 13 | **B9f · Repetición a la vez en todas las formas (H13) y sus distribuciones** (H14 §2) | Haz y ᛒ repetidos; abanico, paralelo o ráfaga | B–M | P3, **P5 (H4)**, **P10** |
| 14 | **B7 · Dos círculos (H12 = H14 §6), con «a la vez» (H15) y Rebote (H14 §7) como condiciones extra** | Hechizo A → condición → hechizo B, cada uno con su sello | M–A | B2, B4; **conviven** con el libro avanzado (P4 respondida) |
| 15 | **B9g · Crecer y Permanencia** (H14 §5) | Cobertura y duración con coste propio; aviso común al caducar | B–M | B9a, temporizador común (P8 de PROPUESTAS) |
| 16 | **B9h · Buscar conserva el objetivo** (H14 §1) | Seguimiento estable | B–M | Que ᚨ entre en el juego |
| 17 | Emisiones periódicas de hijos (H14 §9) | — | M | B7 validado |

**Por qué este orden:**
- B1 bloquea una demo jugable de principio a fin.
- M1 es barato y da datos para el libro.
- **B9a va antes que cualquier ajuste de números**: si ᛇ deja de subir el daño, cambian la tinta que enseña H9, la flecha de B9c y todos los golden.
- **Cambio sobre el orden revisado de H14:** H13 (repetición) baja del 4.º al 13.º puesto, porque **ᚠ no está en el kit de la demo**. Si P3 lo mete en el libro, sube.

---

## 1. Lo comprobado hoy en el código (correcciones y matices al catálogo)

1. **El kit «pruebas» no lleva ᚱ.** Son 6 elementos y 13 glifos, pero los 13 son flecha, barrera, línea, altura, levitación, repetición, rebote, pulso, perforar, retorno, buscar, retardo y suelo (`magia/lanzador_3d.gd:125-127`). El kit «demo» sí lleva ᚱ (`:137`).
2. **El kit «demo» llena el primer libro.** Lleva `capacidad` = `CAPACIDAD_PRIMER_LIBRO` = [4 elementos, 6 glifos] (`lanzador_3d.gd:113`, `:137-138`), y sus 6 glifos (flecha, línea, barrera, altura, ᚱ, ᛒ) lo ocupan entero. **Lo que la ruta añade, ᛉ en las Ruinas y ᛖ posición en el Bosque 02 (`PUZLES_DEMO_RUTA` §1), no cabe; ⧖ tampoco.** `Repertoire.unlock_sigil` lo rechaza con un aviso por consola (`nucleo/repertoire.gd:143-145`). Es la primera decisión (P3).
3. **La persistencia de lo ganado ya existe.** Cada nivel reinicia el repertorio al montarse (`Lanzador3D.aplicar_progresion` → `Repertoire.set_active`, `lanzador_3d.gd:596-609`), pero los cofres ponen el flag `global.glifo.<id>` (`objetos/ceremonia_cofre_3d.gd:391-392`) y `Puzle3D._restaurar_glifos` los vuelve a dar en cada nivel, junto con los sellos `global.sello.<id>` (`escenas/puzle.gd:1327-1332`). **Montar la demo no necesita un sistema nuevo de progresión.**
4. **Las páginas y los huecos también se ganan ya.** `hoja_grimorio` suma una página (mejora `paginas`) y `engarce_glifo` abre un hueco (`nucleo/datos/objetos.tsv:95-96`, `nucleo/mejoras.gd:16-18`). El `cofre_corazon` del Bosque 02 ya da `hoja_grimorio:1` (`Bosque_02.txt:311`), el elemental suelta un engarce (`botin_tablas.tsv:65`) y el cofre de la Cueva Resonante otro.
5. **Ningún cofre puede dar un sello (elemento).** Solo hay `glifo=` en los mapas. El agua sale de `EncargoMarimanta.dar_sello_agua()` (`nucleo/encargo_marimanta.gd:92`). **El cofre de la tierra de las Ruinas necesita una clave `sello=`** (poca cosa: copiar `glifo=` en `escenas/puzle.gd` y en la ceremonia, con el flag `global.sello.<id>` que ya se rearma).
6. **El libro muestra 3 páginas como mucho.** `PAGES = 3` en `magia/spellcaster.gd:67` y en `magia/grimorio.gd:80`, aunque `mejoras.tsv:5` permita llegar a 8 hojas. Afecta a H10 si quiere 4 botones (§6).
7. **Faltan mapas de la ruta.** No existen `Ruinas`, `Cuevas` (la ruta habla de unas Cuevas nuevas, distintas de `Cueva.txt`) ni `Pantano 01`. Tampoco están en `Niveles.ESCENAS` (`nucleo/niveles.gd:21-28`). B1 puede montar el principio de la ruta (Gruta → Bosque 01 → Bosque 02 → Cueva → Sumicio) y dejar los cofres de tierra, ᛏ y ᛒ para cuando existan esos mapas.
8. **La ceremonia del cofre ya es media H5.** `CeremoniaCofre3D` hace travelling, primer plano, el libro y la mano que escribe el glifo, y espera a que la jugadora confirme (`objetos/ceremonia_cofre_3d.gd:9-17`, `:380-395`). Falta el texto que explica qué hace el glifo (§4).
9. **⧖ tiene dibujo pero no trazo.** `art/ui/glyphs/retardo.png` existe; lo que falta es su entrada en `TrazosRectos.SELLOS` (`nucleo/trazos_rectos.gd:54-67`).
10. **El libro no enseña el coste.** `presentacion/ui/spellbook.gd` no calcula ni pinta la tinta. La previsión de tinta (E4) sale **en el mundo, al apuntar** (`magia/prevision_hechizo.gd`), no en el libro (§5).
11. **`REFERENCIAS_JUEGOS` §2 está atrasado**, como dice el catálogo: «PROP A3» (coste por soporte, §2.1 y §2.2), «PROP C5» (golpe F que devuelve tinta, §2.2), «PROP E4» (§2.4) y «PROP B5» (hechizo contra hechizo, §2.3) **ya están en el código**. «PROP C3» (al impactar) existe como ⧖ entre formas, pero solo con la paleta. No hace falta reescribir ese documento; basta con no planificar esas cosas como nuevas.

---

## 2. B1 · Montar la demo de verdad (TU1–TU4)

### 2.1 Hoy
- «Nueva partida» entra en `Bosque_02` (`Niveles.NIVEL_INICIAL`, `nucleo/niveles.gd:31`) con `kit = "pruebas"` (`escenas/PruebaBosque02.tscn:13`): 6 elementos, 13 glifos y 3 páginas desde el primer segundo.
- Todas las escenas de la ruta llevan `kit = "pruebas"`, salvo la Gruta Batida (`"gruta"`: fuego + flecha) y el Pantano (`"demo"`).
- El kit «demo» es **el techo** de la demo, no el arranque: lo dice su propio comentario (`lanzador_3d.gd:135-136`).
- La barrera se da en cuatro sitios: el cofre de la Gruta, `cofre_01` del Bosque 01 v01, `cofre_corazon` del Bosque 02 y el guardabosques (`escenas/bosque_3d.gd:448`, y además `escenas/bosque_01_3d.gd:684`).

### 2.2 Propuesta: un kit de arranque y todo lo demás en cofres
1. **Kit nuevo `"demo_inicio"`** en `Lanzador3D.PROGRESIONES`: fuego, flecha, 1 página, 2 huecos, libro «bosque», capacidad del primer libro. Es el que llevan **todas** las escenas de la ruta. Lo demás llega por flags, que ya se restauran en cada nivel (§1.3 y §1.4).
2. **El kit «demo» se queda** como techo, para las salas de prueba y el Pantano mientras no tenga ruta.
3. **`NIVEL_INICIAL` pasa a `"GrutaBatida"`** (TU1), y la salida de la Gruta (`GrutaBatida.txt:40`, hoy `a=Bosque_02:boca_cueva`) lleva al Bosque 01 v01.
4. **Reparto por cofres** (propuesta; las celdas en *cursiva* dependen de P1–P3):

| Paso | Mapa | Qué se gana | Pieza | Qué cambiar |
|---|---|---|---|---|
| 0 | **Minimazmorra-cueva del tutorial (nueva, por diseñar; Pablo, 22/11)** | Libro, fuego y ᛇ al entrar (TU3); **ᛜ** en su cofre; *página 2 al salir o en el Bosque 01 (TU4)* | Kit + cofre `glifo=barrera` + `hoja_grimorio` | Mapa nuevo, escena y entrada en `Niveles.ESCENAS`; `NIVEL_INICIAL` apunta a él. La Gruta Batida sale de la ruta (su cofre de ᛜ queda como otra fuente más de barrera) |
| 1 | Bosque 01 v01 | *Por decidir (TU2)* | `cofre_01` | Quitar `glifo=barrera` y la barrera de `bosque_01_3d.gd:684` |
| 2 | Bosque 02 | **ᛁ línea** (TU5, «posiblemente», Pablo 22/11), **página 3** (ya la da) y **engarce** (elemental) | `cofre_corazon` | `glifo=barrera` → `glifo=linea`. *ᛖ posición: P3* |
| 2b | Cueva (opcional) | **ᚱ** | Cofre `glifo=raido` (ya está) | — |
| 3 | Monte Sumicio | **Agua** | Encargo de Marimanta (ya está) | — |
| 4 | Ruinas (*no existe*) | **Tierra**; *ᛉ: P3* | Cofre con `sello=tierra` | La clave `sello=` (§1.5) |
| 6 | Cuevas (*no existen*) | **ᛏ** y **ᛒ** | Cofres `glifo=` | — |
| — | Guardabosques (Bosque antiguo) | Hoy vende ᛜ por 20 de oro | `bosque_3d.gd:448` | Fuera de la ruta: dejarlo o que venda otra cosa |

5. **TU3 · recompensas celebradas al principio:** hoy el kit lo da todo en silencio al montar el nivel. Para que el libro, el fuego y la flecha sean «entregas», el tutorial arranca con un kit **vacío** y la Gruta da cada pieza con un evento de mapa que reutiliza `CeremoniaCofre3D` (el libro y la mano ya están en la ceremonia). Coste M. Si no se aprueba, el kit `"demo_inicio"` ya da las tres cosas de entrada (coste B).

### 2.2b HECHO el 22/11 (Pablo: «monta lo pendiente»)
- **Kit `"demo_inicio"`** en `Lanzador3D.PROGRESIONES` (`magia/lanzador_3d.gd`): fuego, ᛇ y ᛜ, 2 páginas, 2 huecos, libro «bosque», capacidad del primer libro. **ᛜ y la segunda página van en el kit en lugar del tutorial**, mientras la minimazmorra no exista. Cuando exista, salen del kit y los dan sus cofres.
- **Escenas de la ruta con `kit = "demo_inicio"`:** `PruebaBosque01_v01`, `PruebaBosque02`, `PruebaCueva`, `PruebaCuevaResonante` y `PruebaMonteSumicio`. El Pantano sigue con «demo» (el techo). Las salas de prueba y los labs siguen con «pruebas».
- **`cofre_corazon` del Bosque 02 da ᛁ línea** en vez de ᛜ (TU2 y TU5). Sigue dando la hoja de grimorio (página 3).
- **Clave `sello=<elemento>` en los cofres** (`escenas/puzle.gd`): pone `global.sello.<id>` (la flag que ya se rearma en cada nivel), desbloquea y avisa. Lista para el cofre de la tierra de las Ruinas.
- **Prueba:** `herramientas/prueba_kit.gd`, bloques 14–18.
- **No tocado, a propósito:**
  - `NIVEL_INICIAL` sigue en `Bosque_02`, porque la minimazmorra no existe.
  - El `cofre_01` del Bosque 01 v01 sigue dando ᛜ. Ese nivel está montado en torno a ganarla ahí: su misión dice «Abrir el cofre de la tala (el glifo de barrera)» y su sala R1 pide ᛜ + ᛁ. Con ᛜ en el kit, el cofre no da nada nuevo. Qué debe dar queda en TU2.
  - `escenas/bosque_01_3d.gd:684` es del Bosque 01 **antiguo**, fuera de la ruta.
- **Corrección a lo que decía este plan:** el exportador de mapas **no** pisa los mapas hechos a mano. Solo escribe escenas con su marca (`metadata/generador_mapas`) y da error si el nombre es de un mapa a mano (`exportador_mapa.gd:6`). No hay nada que cambiar.
- **Ojo con ᛁ en el Bosque 02:** el `cofre_corazon` **acaba la demo** (logro `nivel_completado` y vuelta al menú, `escenas/bosque_02_3d.gd:15`). Hoy, la línea se gana justo cuando la partida termina. Tendrá sentido cuando la ruta siga después del Bosque 02.

### 2.3 Archivos
`magia/lanzador_3d.gd` (kit), las escenas `escenas/Prueba*.tscn` de la ruta (`kit =`), `nucleo/niveles.gd` (`NIVEL_INICIAL`), los mapas de la ruta y, para `sello=`, `escenas/puzle.gd`.

### 2.4 Coste y dependencias
- Coste: **B** (kit, escenas, mapas y `sello=`), **M** si entra TU3 con ceremonias.
- Depende de P1 (TU1), P2 (TU5) y P3 (capacidad).
- Riesgo: la ruta se diseñó con el kit de pruebas y quizá algún puzle obligatorio pide algo que aún no se tiene. `PUZLES_DEMO_RUTA` ya avisa: «*verificar* con una partida solo con fuego» (Bosque 02) y que de la entrada de la Cueva al cofre C6 no haga falta agua ni tierra.

### 2.5 Cómo se probaría
- **Sin ventana:** ampliar `herramientas/prueba_kit.gd` con la cadena «partida nueva → GrutaBatida con fuego + ᛇ y 1 página → flag `global.glifo.barrera` → Bosque 01 lo conserva → `hoja_grimorio` da 2 páginas», y que en ningún paso salte el aviso de libro lleno. Volver a pasar `herramientas/prueba_glifos_dibujables.gd`, que ya comprueba de dónde sale cada glifo.
- **Recorrido:** `herramientas/prueba_bosque_02_recorrido.gd` con `"demo_inicio"` + ᛜ + ᛁ, para ver si el Bosque 02 se resuelve solo con fuego.
- **Pablo, con ventana:** Nueva partida y jugar la Gruta y el Bosque 01; abrir el libro tras cada cofre.

---

## 3. B2 · Disparador ⧖ dibujable (H1b)

> **Cambio del 22/11 (H14 §4 y §6):** el conector entre dos hechizos va por la página de dos círculos (B7). **⧖ queda solo como CARGA.** De esta tabla siguen valiendo el trazo, la chuleta y ver nacer el hijo (que B7 necesita igual). «ᛒ como hijo» y «la página lo enseña» pasan a B7. La parte nueva de Carga (unificarla con la sobrecarga, H14 §4) está en §11, B9d.

### 3.1 Hoy
La lógica está hecha y probada (`nucleo/hechizo.gd:35-41`, `:452-507`; `magia/hechizo_vivo.gd:1781-1814`; `herramientas/prueba_bloque_b5_c3.gd`), pero ⧖ solo se pone con la paleta F1.

### 3.2 Qué falta, por piezas
| Pieza | Archivo | Coste |
|---|---|---|
| **Trazo de ⧖** en `TrazosRectos.SELLOS`, por ejemplo `"retardo": "R,DL,R,UL"` (el reloj de arena como figura cerrada, empezada en cualquier esquina, como el rombo). Que no choque con ◇ barrera (`"DL,DR,UR,UL"`): lo comprueba el control de choques | `nucleo/trazos_rectos.gd:54` | B |
| **Que la chuleta del libro lo enseñe** (el PNG ya existe) | `presentacion/ui/spellbook.gd` (la guía se genera desde la tabla) | B |
| **Que ᛒ pueda ser hijo** (trampa donde golpea la flecha): añadir `"suelo"` a `DISPARADOR["despues"]` y comprobar que `GlifoSuelo.plantar` acepta el punto del impacto | `nucleo/hechizo.gd:38`, `magia/glifo_suelo.gd:99` | B |
| **Que se vea nacer el hijo** (destello y sonido propios) | `magia/hechizo_vivo.gd` (`_crear_hijo`), `presentacion/sensacion_3d.gd` | B–M |
| **Que la página lo enseñe** («flecha → al impactar → barrera») con `Hechizo.hijo_siguiente` (`hechizo.gd:255`) | `presentacion/ui/spellbook.gd` y la previsión | M |
| **Hijo de otro elemento** | Lo resuelve H12 (§8), no ⧖ | — |

### 3.3 Dependencias
- **¿Entra en la demo?** Solo si hay sitio en el libro (P3). Si no entra, el trazo se hace igual (es barato) y ⧖ se guarda para después de la demo, junto con H12.
- H4 (orden o vecindad, P5): el disparador depende del orden de dibujo, justo lo que H4 pone en duda. Si H12 sale adelante, H12 sustituye a ⧖ entre formas como forma de dibujarlo.

### 3.4 Cómo se probaría
`herramientas/prueba_trazos_rectos.gd` (reconoce ⧖, no choca), `prueba_bloque_b5_c3.gd` con un caso nuevo flecha + ⧖ + ᛒ, y con ventana en `LabHechizos3D`: dibujar ᛇ ⧖ ᛜ a mano y ver nacer la barrera donde para la flecha.

---

## 4. B3 · Presentación de glifos (H5–H8)

### 4.1 Hoy
- La ceremonia del cofre presenta el glifo: luz baja, travelling, la mano lo escribe y la jugadora confirma (§1.8).
- La página derecha del libro anota lo conseguido (`spellbook.gd:2058`).
- **No hay texto de uso, ni antes/después, ni ficha, ni catálogo con huecos bloqueados.**

### 4.2 Propuesta (en este orden)
| Id | Qué | Cómo, reaprovechando | Archivos | Coste |
|---|---|---|---|---|
| **H8** | **Ficha por glifo:** nombre, una frase y en qué bases vale | Texto en `GestureLibrary.BIBLIA` (ya tiene `nombre_runa`, `futhark` y `uso`); añadir `frase` y `bases`. Donde se pueda, sale de `Hechizo.diferencia()` (`hechizo.gd:983`) | `nucleo/gesture_library.gd`, `spellbook.gd` (al señalar una casilla de la página derecha) | B |
| **H5** | **Lámina de presentación** al ganar un glifo o un sello: nombre y la frase de H8 | Una tarjeta en la espera de confirmación de `CeremoniaCofre3D` (`_esperar_confirmacion`); la misma tarjeta para el sello de agua de Marimanta | `objetos/ceremonia_cofre_3d.gd`, `escenas/monte_sumicio_visita.gd:704` | B–M |
| **H6** | **Antes/después:** el mismo hechizo sin el glifo y con él, en dos bases | Dos miniaturas en bucle; la manera barata es grabarlas con `herramientas/captura_recetas_vfx.gd` (ya captura recetas) y enseñarlas como imagen o vídeo en la lámina de H5 y en la ficha de H8 | `herramientas/captura_recetas_vfx.gd`, `spellbook.gd` | M |
| **H7** | **Catálogo por familias, con los que faltan bloqueados** y la etiqueta «nuevo» | La página derecha ya cierra con un velo las casillas que pasan de la capacidad (`spellbook.gd:1911`); se pintan también las que aún no se tienen, en gris y sin nombre. La etiqueta «nuevo» sale de la cola `_por_escribir` | `spellbook.gd`, `nucleo/repertoire.gd` | B–M |

### 4.3 Dependencias
B1, para saber qué glifo se gana en cada sitio y que la lámina salga en la ruta real. H6 necesita que el VFX de cada glifo de la demo esté cerrado: si se graba antes, habrá que volver a grabarlo.

### 4.4 Cómo se probaría
Sin ventana: que cada glifo del kit «demo» tenga `frase` y `bases` no vacías (una línea más en `herramientas/prueba_glifos_dibujables.gd`). Con ventana: abrir el cofre de la Gruta (o el lab de la ceremonia, `modo_prueba`) y leer la tarjeta; abrir el libro y señalar ᛜ.

---

## 5. B4 · Coste visible al dibujar (H9)

### 5.1 Hoy
- El coste existe: base 8 / 18 / 34 más un coste por glifo (`nucleo/dano.gd`, `Sigils.coste_v2`, `nucleo/sigils.gd:477`; `Tinta.coste_efectivo`, `nucleo/tinta.gd:246`).
- La previsión lo enseña **al apuntar, en el mundo**. El libro no lo enseña.

### 5.2 Propuesta
Una **barra bajo el círculo** de la página que crece con cada glifo, con una marca de la tinta que hay ahora (y del máximo). Se calcula con el mismo `Hechizo` que ya construye la previsión (`PrevisionHechizo._hechizo`, `magia/prevision_hechizo.gd:157`). Así no hay dos fórmulas.
- **Archivos:** `presentacion/ui/spellbook.gd` (pintar) y una función estática pequeña que devuelva el coste de una página.
- **Coste:** B.
- **Dependencias:** ninguna. Con H12, la barra suma los dos círculos.
- **Prueba:** sin ventana, que el coste del libro de flecha+flecha sea el mismo que cobra el lanzador al lanzar esa página. Con ventana: dibujar ᚲ ᛇ y luego ᚲ ᛇ ᛇ y ver crecer la barra.

---

## 6. B5 · Selector de página activa (H10)

### 6.1 Decidido por Pablo (21/11)
Un selector de qué hechizo va en cada botón, **en el libro y en combate**. El botón solo lanza (no se toca `pulsar_pagina`).

### 6.2 Hoy
- 3 páginas = 3 botones (`PAGES = 3`).
- `select_page` solo lo usa el libro para pasar la hoja (`spellbook.gd:704`, `:831`). **No hay ni variantes por botón ni control en combate.**
- La mejora `paginas` llega a 8, pero el libro enseña 3 (§1.6).

### 6.3 Propuesta en dos pasos
1. **Paso 1 (B–M): las hojas que pasan de 3 son variantes.** Si el botón 1 tiene dos hojas (por ejemplo la 1 y la 4), el libro deja marcar cuál está **activa**. Así la mejora `paginas` (hasta 8) tiene un sentido que hoy no tiene. Los datos van en `Repertoire.paginas` (cada página con su botón y la marca de activa) y en `Partida`. El HUD (`presentacion/ui/page_hud.gd`) enseña la activa de cada botón.
2. **Paso 2 (M): el control rápido en combate** (P6): por ejemplo, la rueda del ratón o la cruceta pasa a la siguiente variante del botón seleccionado, con un rótulo corto en el HUD.

**H2 «sobre mí» (un cuarto botón):** se deja fuera de este bloque. Pide subir `PAGES` a 4 en `spellcaster.gd` y `grimorio.gd`, una cuarta pestaña en el libro y en el HUD, y decidir cómo se marca un hechizo como «sobre mí» (pendiente de Pablo en PROPUESTAS).

- **Archivos:** `nucleo/repertoire.gd`, `magia/grimorio.gd`, `magia/lanzador_3d.gd` (`select_page`, `receta_de_ficha`), `presentacion/ui/spellbook.gd`, `presentacion/ui/page_hud.gd`, `nucleo/partida.gd`.
- **Dependencias:** B1 (que existan las hojas extra en la ruta), P6. Mejor después de M1: «lanzamientos por página» dice si la jugadora rota o no.
- **Prueba:** sin ventana, guardar y cargar una partida con 4 hojas y la variante activa del botón 1 cambiada, y comprobar que el botón 1 lanza la variante. Con ventana: cambiar de variante en combate en el Bosque 02.

---

### 6.4 H16 · Nombre de cada hechizo (va con B5; aprobado por Pablo el 22/11) · **HECHO EN PARTE el 22/11**
- **Fuente:** `docs/PROPUESTAS_SESION_MYSTRALIA_2026-11-21.md` §H16 (análisis O28 en `MAGES_OF_MYSTRALIA`). Pablo quiere el selector H10 y los nombres juntos.
- **Hecho (lo barato):**
  - **Nombre automático** (`nucleo/nombre_hechizo.gd`, `NombreHechizo.automatico`): forma (del perfil de `PrevisionCasteo3D`) + elemento + un rasgo, concordado. Por ejemplo: «Flecha de fuego», «Flecha de fuego larga», «Escudo de agua», «Muro de agua que avanza», «Chorro de fuego», «Plataforma de tierra», «Trampa de fuego», «Orbes de fuego», «Muro de tierra». Se rehace solo cuando cambia la receta.
  - **Dato:** `Grimorio.nombre_pagina(i)`, `renombrar_pagina(i, texto)` (recorta a 18 caracteres; vacío vuelve al automático) y `nombre_es_propio(i)`. Solo se guarda el nombre propio (`nombre`, `nombre_propio` en `Repertoire.paginas`, como `elemento2`); una partida vieja recibe el automático.
  - **HUD** (`presentacion/ui/page_hud.gd`): el nombre de la página activa encima de las pestañas. Sale grande (22) 1,2 s al cambiar de página o de receta y se reduce a 14.
  - **Prueba:** `herramientas/prueba_nombre_hechizo.gd`, 30 comprobaciones, 0 fallos.
  - **Fotos con ventana:** `docs/capturas/nombre_hechizo_2026-11-22/` (`captura_nombre_hechizo.gd`).
- **Falta:**
  - renombrar en el libro (el campo de texto en la cabecera, M);
  - el nombre en el selector H10 (cuando exista);
  - en la cabecera y en las pestañas del libro;
  - en las cifras M1 (hoy cuentan por página y receta).

### 6.5 Libro rojo · LIBRO DE PRUEBA (Pablo: «implementa un libro de prueba para probar», 22/11)
- **Fuente:** `docs/PROPUESTA_LIBRO_ROJO_Y_TRANSICIONES_2026-11-22.md` (de Codex, con la revisión del §17) y `docs/libro_rojo/` (prototipo HTML e imágenes).
- **Qué es:** un libro SEPARADO, que no sustituye al de siempre.
  - `presentacion/ui/libro_rojo.gd` (`LibroRojo`), montado por `laboratorios/lab_libro_rojo.gd` en **`laboratorios/LabLibroRojo.tscn`** (el Bosque de pruebas).
  - Se abre con **L**, Escape lo cierra y pausa el juego como el de siempre. El libro de siempre (T), el «bosque», el «avanzado» y `spellbook.gd` **no cambian**.
  - Escribe en las **mismas páginas del lanzador** (`Grimorio`): reconoce con el `add_gesture` de siempre, guarda igual y se lanza con 1/2/3 el **mismo `Hechizo`**.
- **Hecho:**
  - **Prioridad 1–2 (§17.7):**
    - Página izquierda: una zona de trazado, con el aviso de lo que se espera (sello o glifo, núcleo o hueco N).
    - Página derecha: el conjuro con su **doble contorno**, el núcleo y la corona (los huecos abiertos de la página, 3 → 6, la `CORONA_ANGULOS` del avanzado).
    - Se elige un hueco a la derecha, se dibuja a la izquierda y la **tinta lo escribe trazo a trazo** (punta de tinta, sin mano; trazos de `TrazosRectos`). Luego se asienta la runa de la lámina.
    - **Un trazo no reconocido se queda** para corregirlo, con el aviso del reconocedor; clic derecho lo borra.
    - Clic derecho en un hueco quita su glifo.
    - El **catálogo va en una pestaña** que se abre sobre la página izquierda, sin tapar el conjuro, con la **capacidad** a la vista («sellos x/4 · glifos y/6»).
    - Cabecera con el **nombre** (H16) y **barra de coste** (H9).
  - **Prioridad 3:** la **combinación de dos sellos** (estructura B): la marca «+» del núcleo, el segundo sello en el mismo contorno (la lógica del libro avanzado, `element2` + `CombosSellos`), una **transición de 0,75 s** (los dos alojamientos se separan y el contorno late) y la **cruz** si se anulan. «Separar sellos» la deshace.
  - **Prioridad 4:** la **anidación (C) solo como maqueta**: principal y hijo con contornos propios, sin envolvente común, y un enlace con su condición y su dirección. No se lanza.
  - **§17.1, orden de los glifos:** el botón «Orden: dibujo / huecos» deja probar H4 en mano. En «huecos», la página se reordena por la corona (de arriba en el sentido del reloj) y la ráfaga sale del orden de los huecos.
- **Prueba:** `herramientas/prueba_libro_rojo.gd`, 31 comprobaciones, 0 fallos: abrir y cerrar, sello y glifo por el reconocedor, rechazo que se queda, orden dibujo/huecos (ráfaga), magma y separar, capacidad, maqueta, mismo `Hechizo` y lanzamiento real, libros de siempre intactos.
- **Fotos con ventana:** `docs/capturas/libro_rojo_2026-11-22/` (`herramientas/captura_libro_rojo.gd`).
- **Lo que NO hace todavía (§12 y §15 de la propuesta):**
  - los gestos estructurales sobre el núcleo y el borde (de momento son clics y botones);
  - la recogida de tinta al reconstruir un alojamiento;
  - el arte del libro rojo (está dibujado por código: cuero rojo, pergamino y rubíes);
  - mover glifos entre principal e hijo;
  - la anidación de verdad (H12, después de la demo).
- **2.ª vuelta (22/11), tras probarlo Pablo** («el core está bien hasta la anidación; falta la ayuda al dibujo; hay errores de reconocimiento; no he conseguido rellenar el segundo sello y sus glifos»):
  - **Reconocimiento:** el libro rojo mandaba el trazo CRUDO. El de siempre lo rectifica a la escala de su círculo. Medido con runas sintéticas con temblor: en crudo, 12/72 a un tercio de la zona; **rectificado a la escala de la zona, 268/270** de 45 a 220 px (solo ᛒ suelo falla alguna vez). Ahora se rectifica (`preparar_trazos`, `ESCALA_RECTIFICADO` 1,0).
  - **PlayLog:** cada intento se apunta como «libro_rojo_trazo» (destino, qué se esperaba, qué se leyó, rival, desviación, secuencia, si entró).
  - **Ayuda al dibujo:**
    - bajo la zona, la **chuleta** de la familia esperada (la guía de `TrazosRectos`, la del libro de siempre);
    - en la zona, la guía tenue del símbolo que ya hay en el destino;
    - un clic en un símbolo del **catálogo lo enseña animado para practicar** (punto de inicio, punta que avanza), **sin inscribirlo**.
    - La asistencia imantada del libro de siempre (`GestureAssist`) no está enganchada.
  - **Anidación EDITABLE** (no se lanza):
    - el núcleo y los huecos del hijo se eligen y se dibujan, con el mismo reconocedor, la raya ᛁ y las mismas runas activas;
    - la condición se elige con clic en el rombo (al impactar → al acabar → a la vez);
    - **6 glifos en total** entre los dos (el séptimo se rechaza con «quita o mueve uno»);
    - **«Mover al otro»** pasa el glifo elegido al primer hueco libre del otro círculo;
    - clic derecho borra.
    - El hijo y la condición se **guardan en la página** (`hijo`, `condicion`, como `elemento2`).
    - La cabecera dice el círculo y el hueco («Hijo · hueco 2»).
  - **Lanzar el hijo (H12) no es barato todavía:**
    - el disparador hace el hijo con el elemento del padre (`h.fuente`);
    - las condiciones no llegan de la página al `Hechizo`;
    - el coste del hijo es el recargo fijo `K_HIJO`.
    
    Es el B7 de este plan: después de la demo.
  - **Texto de la izquierda:** ya no se sale; baja el tamaño hasta caber.
  - **Prueba:** `prueba_libro_rojo` crece a 52 comprobaciones, 0 fallos (reconocimiento 46/48, umbral ≥ 95 %).
  - **Fotos:** `docs/capturas/libro_rojo_2026-11-22/` 10–14.
- **3.ª vuelta (22/11): la LÁMINA del libro rojo** (`art/ui/grimorio_rojo.png`, 1513 × 926, de Pablo, importada):
  - Es el fondo del libro, con una sombra suave debajo. Sin lámina, se dibuja el de antes.
  - Todo se coloca en **coordenadas de lámina**, como en las del libro de siempre, en constantes de `libro_rojo.gd` que se pueden ajustar:
    - **medidas sobre los píxeles:** pergamino izquierdo x 97–722, y 53–824; derecho x 782–1409, y 56–824; lomo x 722–782;
    - **en uso, con margen:** `PAGINA_IZQ_LAM` (115, 75, 590 × 730) y `PAGINA_DER_LAM` (800, 75, 590 × 730).
  - Escala con la proporción de la lámina (1,63) en X y en Y por igual, sin deformarse.
  - Las páginas 1/2/3 van en la **pestaña roja izquierda** (`PESTANA_IZQ_LAM`) y el catálogo se abre con el **cierre derecho** (`CIERRE_DER_LAM`). Nada tapa las esquinas de bronce.
  - La capacidad se ve siempre al pie de la página derecha.
  - Con el catálogo abierto se esconden los botones de prueba, que tapaban su última fila.
  - **Fotos:** antes en `docs/capturas/libro_rojo_2026-11-22/antes_lamina/` y después en la carpeta de arriba. `prueba_libro_rojo` sigue en 0 fallos.
- **4.ª vuelta (22/11): la HOJA DE CATÁLOGO** (Pablo: «vamos a probar así»; inspirada en el libro de runas de Mystralia, adaptada):
  - Es una hoja que se pasa sobre la página izquierda; el conjuro sigue a la vista. Se abre con el cierre derecho.
  - **Familias en huecos fijos**, con candado lo que aún no se tiene:
    - SELLOS, aparte, como las gemas de Mystralia;
    - **FORMA** (cómo se mueve o crece; no sube el daño): ᛇ ᛁ ᛏ ᚷ ᛉ ᚢ ᚨ ᚠ ᛃ;
    - **POTENCIA** (lo que sube el daño): ᛜ ᚱ ᚦ ᛒ ⧖;
    - **CONDICIONES** de los dos círculos, bloqueadas.
    
    Forma y Potencia son la regla de P9 (B9a): la hoja la enseña sin explicarla. ᛃ va en Forma, aunque hoy aún sube el daño (sin decidir).
  - **Ficha al pie** (H8), fija, no flotante: runa, nombre, una frase, con qué vale y el trazo animado, con «▶ Practicar». Lo bloqueado dice «Aún no lo tienes» y no se practica.
  - **Chuleta mínima** en la zona de trazado: solo los últimos 4 símbolos escritos o practicados de la familia esperada. Si no hay, el recordatorio de dónde está el catálogo.
  - **Textos de la ficha: PROVISIONALES** (`LibroRojo.FICHAS`); los decide Pablo.
  - **Prueba:** `prueba_libro_rojo` (bloque 10b), 0 fallos.
  - **Fotos:** `docs/capturas/libro_rojo_2026-11-22/` 08 (kit de pruebas) y 15–16 (cómo se vería al empezar la demo, con candados).
- **5.ª vuelta (22/11): NOTAS DEL PERSONAJE y CUADERNO DE RUNAS** (boceto de Pablo; sustituyen a la hoja de catálogo):
  - **Notas laterales**, fuera del libro, a la izquierda (el libro se aparta a la derecha): hojas sueltas con las pestañas Sellos · Unión · Glifos. Son «inteligentes»:
    - la hoja de delante es la del destino elegido (núcleo → Sellos, hueco → Glifos, enlace → Unión);
    - solo apuntan lo que el personaje conoce, con «N por descubrir» al pie;
    - cada runa lleva su VERBO (Viaja, Solidez, Copias…) y su trazo con el punto de inicio y la flecha.
    - **Mientras se dibuja**, se apagan las runas que ya no pueden salir (`LibroRojo.puede_ser`: trazos terminados enteros y el último como principio de uno, con la tolerancia del reconocedor) y la que va ganando lleva ✓.
    - El **último intento fallido queda tachado** junto a la runa que parecía.
  - **Nombres:** los hechizos guardados se **bautizan** (H16), como en Mystralia. Las notas no tienen que llamarse igual.
  - **El cuaderno de runas** (página extendida, a doble página): se abre con un clic en una nota (cae en esa runa) o con el cierre derecho. Tiene:
    - pestañas e índice;
    - por runa: el verbo, la runa del futhark, cuántos trazos, el trazo animado, la frase y con qué vale;
    - **un recuadro de PRÁCTICA**: se dibuja ahí y contesta «¡Bien!», «Eso es «Viaja», no «Solidez»» o «No lo reconozco (se parece a…)», sin tocar el conjuro. Se apunta en PlayLog («libro_rojo_practica»).
    - «Practicar en el libro» lleva el trazo animado a la zona de trazado.
  - La zona de trazado queda limpia: la chuleta está en las notas.
  - **Prueba:** `prueba_libro_rojo`, bloque 12, 0 fallos.
  - **Fotos:** `docs/capturas/libro_rojo_2026-11-22/` 17–21.
  - **Para probar a mano:** si las notas a medio dibujar ayudan o distraen, y si se entienden los verbos.
- **6.ª vuelta (23/11): PROTOTIPO LANZABLE de la anidación y de la combinación** (Pablo: «crea un prototipo del hechizo anidado y el de la combinación»):
  - **Anidación:** `laboratorios/prototipo_anidado.gd`, solo en el lab del libro rojo. No toca `Hechizo` ni `HechizoVivo`. El lanzador solo gana la señal `hechizo_vivo_creado`, que nadie más usa.
    - Si la página lanzada tiene un hijo escrito en el libro rojo, el segundo círculo sale con **su propio elemento y sus glifos** (un `Hechizo` normal, el `lanzar_hechizo` de siempre):
      - **al impactar**, donde choca el primero (golpe, muro, suelo o cruce); si llega a su alcance sin chocar, no nace;
      - **al acabar**, donde termina, sea como sea;
      - **a la vez**, desde la mano, 0,17 s después.
    - **Se cobra al nacer** (P11 sigue abierta).
    - Al nacer: destello, rótulo «→ al impactar: tierra» y sonido.
    - **Sin** los contrapesos de «a la vez» (recarga y tiempo sumados, sin sobrecarga).
  - **Combinación:** ya se lanzaba (fuego + tierra en el mismo núcleo = **magma**, la lógica del libro avanzado). Ahora tiene prueba.
  - **Prueba:** `herramientas/prueba_prototipo_anidado.gd`, 0 fallos. Cubre al impactar contra un goblin (nace junto a él, cobra 12 de tinta, levanta el muro), al impactar sin nada (no nace), al acabar, a la vez (0,27 s medidos a 30 fps), sin tinta y magma.
  - **Fotos:** `docs/capturas/prototipo_anidado_2026-11-23/`.
  - **Para pasarlo al sistema de verdad (B7):** la condición y el hijo en `Hechizo`, el coste en `Dano`, la previsión del segundo círculo y los contrapesos.
  - **Pablo (23/11): «no hace falta de momento».** Los contrapesos y el balance se ajustarán **con playtest** cuando llegue el momento. El prototipo se queda como está.
- **No cuadra con el código (para Pablo):**
  - el libro de prueba pone `Repertoire.libro = "avanzado"` mientras la página tiene dos sellos, porque la combinación solo existe en ese libro. El lab lo devuelve al salir.
  - En la estructura B, dibujar en el núcleo 1 cuando ya hay dos sellos **reemplaza el más antiguo** (la regla del avanzado, `element_viejo`), no necesariamente el de la izquierda.

## 7. B6 · ᛒ que viaja (H11)

### 7.1 Hoy
ᛒ manda sobre todas las formas y planta una sola casilla (`magia/glifo_suelo.gd:17`). Máximo 6 piezas vivas (`:23`).

### 7.2 Propuesta (PROPUESTAS §H11)
- **ᛒ + ᛇ:** avanza y deja un rastro de casillas, una cada ~0,2 s, con el largo del alcance de la flecha.
- **ᛒ + ᛇ + ᛃ:** el rastro vuelve en curva.
- Todo el rastro cuenta como **una pieza** para el tope.

En la demo no hay ᛃ, así que en la demo solo cuenta el rastro recto.

- **Archivos:** `magia/glifo_suelo.gd` (plantar en fila a lo largo de una trayectoria, con temporizador), `magia/lanzador_3d.gd` (`_suelos` y el tope), quizá `nucleo/hechizo.gd` (que ᛇ no se ignore cuando hay ᛒ).
- **Coste:** M.
- **Dependencias:** decidir qué pasa con T3 · El foso (P8). Si el rastro sobre el vacío existe, T3 se resuelve de un solo lanzamiento.
- **Prueba:** `herramientas/prueba_glifo_suelo.gd` (ya existe) con casos ᛒ+ᛇ de tierra sobre el vacío (N plataformas en línea, una sola pieza en el tope) y de fuego sobre el suelo (fila de trampas). Con ventana: en `LabHechizos3D`, tierra ᛒ ᛇ sobre un foso.

---

## 8. B7 · Dos círculos (H12) y el libro avanzado

### 8.1 Hoy
- **El libro avanzado está hecho, pero nadie lo da.** Tiene 2 medallones, la corona de 6 huecos y dos zonas de dibujo (`spellbook.gd:150-183`, `:2391-2501`), y guarda y conserva las páginas (`Repertoire.cambiar_libro`, `nucleo/repertoire.gd:247`; `herramientas/prueba_libro_guardado.gd`). Fuera de las pruebas, nada llama a `cambiar_libro`.
- Hace **sellos dobles en un solo hechizo** (agua+viento = hielo, etc.). En la demo no hay viento, así que con fuego, agua y tierra solo salen magma y naturaleza. Hielo y rayo, no. Y la memoria «4 elementos base y sellos dobles» los deja como reacciones.

### 8.2 H12 · Página de dos círculos (aprobada como hechizo muy avanzado: 2 sellos y 6 glifos en total)
| Pieza | Qué hay | Qué falta | Coste |
|---|---|---|---|
| Lógica padre → hijo | Disparador C3 completo: `crear_hijo`, profundidad 2, recargo `K_HIJO` | Partir la página por **círculo** en vez de por el ⧖ | B |
| Hijo de otro elemento | El hijo usa `h.fuente` del padre | Pasar la runa del círculo 2 a `Hechizo.construir` | B |
| Condición | Eventos `al_impactar`, `al_detenerse`, `al_expirar`… (`hechizo.gd:65`) | Un símbolo en el recuadro; empezar con dos: al impactar y al acabar | B |
| Guardar | `paginas` admite `elemento2` (`repertoire.gd:298-300`) | `{hijo: {sello, glifos}, condicion}` | B–M |
| **Libro** | Reconocimiento por zonas del avanzado (`spellbook.gd:1087`) | Dos círculos pequeños y un recuadro; los 6 huecos repartidos (3 + 3 o libres) | **M–A** |
| Previsión y coste | `hijo_siguiente`; B4 | Enseñar los dos hechizos y la suma | M |

~~**Propuesta:** H12 ocupa el sitio del libro avanzado como «el segundo libro».~~ **P4 respondida (H14 §6, 22/11): conviven.** La mezcla de dos sellos (libro avanzado) da una manifestación; los dos círculos relacionan dos manifestaciones. Son operaciones distintas. **No entra en la demo.**

**Reparto de glifos, confirmado por Pablo (22/11): «6 repartidos»**, 6 glifos EN TOTAL entre los dos círculos, no 6 + 6. Es lo que ya hace el libro rojo de prueba (§6.5). Los números, medidos con `Hechizo.construir` (fuego; sección H12 de `PROPUESTAS_SESION_MYSTRALIA`):
- Un círculo de 3 glifos: daño 13, tinta 20–28. Uno de 6: daño 26–44, tinta 54–72.
- **3 + 3** cuesta lo mismo que una página llena (40–56 de tinta) y hace igual daño o menos: lo que se gana es la combinación, no la potencia.
- **6 + 6** duplica el daño (53–88) y cuesta **108–145 de tinta**, más que la barra inicial (100). Además son 15 huecos y 14 trazos por página.
- **Si hace falta margen,** sería una mejora del libro: de 6 a 8 glifos en total, nunca 6 por círculo.

**La especificación es H14 §6** (`docs/MEJORAS_HECHIZOS_MYSTRALIA_2026-11-22.md`). Lo que añade a la tabla de arriba:
- **Coste real del hijo** en vez del recargo fijo `K_HIJO` 0,10. Hay que comparar dos políticas, cobrar al activarse o reservar al lanzar, y **enseñar** el coste inicial, el condicionado y el máximo.
- **El círculo 2 puede afectar al enemigo que golpeó el círculo 1**, sin perder la protección contra golpes repetidos dentro de cada círculo.
- **Límites:** la profundidad (2) y los vivos (32) ya existen. Falta un **tope de efectos generados por lanzamiento**.
- **El premio de tinta por reacción ya va una vez por enemigo y tipo** (`nucleo/tinta_reaccion.gd`), así que una cadena no cobra dos veces la misma reacción.
- **Rebote (`al_rebotar`, H14 §7) como otra condición**, después de «al impactar» y «al acabar». El evento ya existe (`hechizo.gd:65`).
- **«A la vez» (H15, Pablo 22/11, el disparador «De una vez» de Mystralia):** el círculo 2 sale en el mismo instante que el círculo 1, con el evento `al_nacer`, que ya existe (`hechizo.gd:65`).
  - **Usos con fuego, agua y tierra:** flecha de fuego + barrera de tierra (disparar y cubrirse de una pulsación); barrera de agua + pulso ᚱ de tierra; ᛒ de tierra + flecha.
  - **Orden de las condiciones:** primero al impactar y al acabar; después «a la vez» y el rebote.
  - **Decisiones (P13):**
    1. ¿Reaccionan entre sí al nacer? Propuesta: no, hasta que se separan.
    2. ~~El coste se paga entero al lanzar · la recarga es la del más lento.~~ **Pablo (22/11): no basta, «el problema de este glifo es que es muy poderoso».** Contrapesos posibles (tabla en la sección H15 de PROPUESTAS):
       1. recarga = la suma de las dos;
       2. tiempo de lanzar = la suma;
       3. tinta = la suma más un recargo;
       4. sin sobrecarga;
       5. solo un círculo hace daño;
       6. glifos repartidos (ya existe: 6 en total entre los dos).
       
       **Decidido por Pablo (22/11): 1 + 2 + 4** (recarga sumada, tiempo de lanzar sumado y sin sobrecarga). «Si vemos que no es práctico, mejoraremos algo».
    3. **Retardo entre los dos (vídeo de Mystralia, medido fotograma a fotograma):** el segundo sale **≈ 0,17 s** después del primero (5 fotogramas a 30 fps, igual en los tres lanzamientos), cada uno con su destello de salida. Pablo: «parece lógico» y evita errores.
       - Constante prevista: `RETARDO_A_LA_VEZ` ≈ 0,15–0,2 s.
       - **Esto resuelve casi toda la decisión 1:** al salir separados, ya no nacen uno encima del otro. El filtro por linaje de `_cruzar_zonas` sigue haciendo falta para lo que **no se mueve** (dos barreras en el mismo sitio).
    - **Nota:** en el editor de Mystralia, «De una vez» apunta a **otro conjuro guardado** (como H1), no a un segundo círculo (O21 en `docs/MAGES_OF_MYSTRALIA_2026-11-21.md`). Nosotros lo hacemos con los dos círculos de H12.
  - **Hallazgo en el código (22/11):** hoy el cruce hechizo contra hechizo **no mira el linaje** (`HechizoVivo._cruzar_zonas` → `zonas_en`, `magia/hechizo_vivo.gd:2192-2205`). Si la respuesta a la decisión 1 es «no», hay que filtrar por linaje ahí. Coste B.
- **La previsión** enseña el punto donde se activa y el primer efecto del círculo 2.
- **Ejemplos para la demo:** flecha de agua → barrera de tierra (muro donde cae), o fuego → agua (vapor). El «mojar y electrificar» de Mystralia usa rayo, que no está en la demo.
- **Guardar:** la recarga de páginas ya funciona (`Grimorio.cargar_paginas`, `magia/grimorio.gd:222`). Lo que falta es guardar el segundo círculo. El documento de Pablo decía lo contrario y lo he corregido.

- **Archivos:** `presentacion/ui/spellbook.gd`, `magia/grimorio.gd`, `nucleo/hechizo.gd`, `magia/hechizo_vivo.gd`, `nucleo/dano.gd` (coste del hijo), `nucleo/repertoire.gd`, `nucleo/partida.gd`.
- **Dependencias:** B2 (trazo y ver nacer el hijo) y B4 (el coste sumado). Además, **el cobro de hijos × copias** de B9f: hoy `Dano.hijos_previstos` (`nucleo/dano.gd:169`) no multiplica por las copias.
- **Prueba:** sin ventana, que una página de dos círculos (fuego ᛇ | al impactar | tierra ᛜ) construya un padre de fuego con un hijo de tierra y cobre las dos partes; guardar y cargar. Con ventana: dibujarla en el libro y lanzarla contra un muro.

---

## 9. B8 · M1, cifras del libro (aprobada el 21/11) · **HECHO el 22/11**

> **Hecho:**
> - **Dónde:** `nucleo/estadisticas.gd`, apartado `libro` en `total` y en `por_nivel`.
> - **Se guarda** en la partida, en `estadisticas.libro`.
> - **Enganches:**
>   - `Spellbook._open` y `_close`;
>   - `Lanzador3D.add_gesture`, `_rechazar_libro_en_combate` y `_disparar`;
>   - el principio y el fin del combate en `Sensacion3D` (música).
> - **Para leerlo:** `Estadisticas.filas_libro(d)` da 10 líneas (aperturas, tiempo, páginas reescritas, segundos por página, lanzamientos por página, cuota de la página más usada, recetas distintas, encuentros con más de una página, trazos no reconocidos e intentos en combate). **La pestaña de la jugadora no las enseña.**
> - **Prueba:** `herramientas/prueba_cifras_libro.gd`, 0 fallos.
> - **Pendiente:** decidir si salen en el resumen de nivel o en un archivo para el playtest.

Añadir a `nucleo/estadisticas.gd` las cifras de `DIBUJAR_EN_GAMEPLAY` §3:
- aperturas del libro y segundos abierto;
- páginas reescritas;
- lanzamientos por página y por receta;
- encuentros con más de una página usada;
- trazos no reconocidos;
- segundos por página;
- intentos de abrir el libro en combate (`_rechazar_libro_en_combate`).

Todo con los mismos `_sumar` y `por_nivel` que ya hay, y conectado en `Estadisticas.conectar` (`:181`).
- **Coste:** B.
- **Dependencias:** ninguna.
- **Prueba:** sin ventana, abrir y cerrar el libro, reescribir una página, lanzar 2 veces la 1 y una la 2, y leer `por_nivel`.
- **Por qué pronto:** da datos para B4, B5 y B7, y para cualquier playtest con la demo de B1.

---

## 11. B9 · Mejoras de glifos (H14, de Pablo) y repetición a la vez (H13)

**Fuente:** `docs/MEJORAS_HECHIZOS_MYSTRALIA_2026-11-22.md`: el texto de Pablo, revisado punto por punto por la sesión de análisis. La sesión HECHIZOS ha vuelto a comprobar sus cifras el 22/11; todas coinciden menos una (el guardado, ver B7). Regla del documento: de Mystralia se toman **reglas e ideas, no su código ni sus tablas**.

**Reparto:**
- H14 §6 (conectores) → B7.
- §4 (Carga) → B2 y B9d.
- §7 (Rebote) → B7.
- El resto, aquí.

**Nada se implementa hasta que Pablo apruebe el orden (§0).**

### B9a · Qué glifos suben el daño (H14 §10) · en la demo · **HECHO el 22/11 (P9: «tu propuesta»)**
> **Hecho:**
> - **El cambio:** `cuenta_dano: false` en ᛇ flecha, ᚷ crecer (`pulso`), ᛉ permanencia, ᚨ buscar, ᚢ rebote y ᚠ repetición (`nucleo/sigils.gd`).
> - **Siguen contando:** ᛜ, ᚱ, ᚦ, ⧖ (×2) y ᛒ. **ᛃ retorno no estaba en la propuesta y sigue contando:** queda para decidir.
> - **La tinta no cambia.**
> - **`prueba_dano_tinta`:** reescrita a propósito (el relleno pasa a ᚦ y hay un bloque 5c nuevo); da 0 fallos.
> - **`prueba_catalogo_reacciones`:** da 0 fallos sin tocarla.
> - **En la demo:** fuego + ᛇ hace 13,2 haya una flecha o tres. Solo ᛜ, ᚱ y ᛒ suben el daño.
>
> **Lo que había antes:**
- **Hoy:** el daño base sale del recuento de glifos ofensivos: 12 / 24 / 40 (`Dano.BASE`, `nucleo/dano.gd:39`), con cortes en 1–2, 3–4 y 5–6.
  - Cuentan todos menos ᛁ, ᛏ y posición (`cuenta_dano: false`, `nucleo/sigils.gd:380-382`, `:427`).
  - ⧖ cuenta doble (`CARGA_PESO_DANO` = 2, `sigils.gd:319`).
  - Por eso ᛇ, ᚷ, ᛉ, ᚨ, ᚢ y ᚠ suben el daño aunque solo mueven, crecen, duran o multiplican.
- **Propuesta:** decidir glifo a glifo cuáles son de **forma o transporte** y cuáles de **potencia** (**P9**). Es poner `cuenta_dano: false` en los de forma.
- **Ojo con la demo:** si ᛇ deja de contar, «fuego + flecha» pasa a 0 glifos ofensivos. Se queda en daño ligero (12), y con ᛇ ᛇ también. En la demo solo subirían el daño ᛜ, ᚱ y quizá ᛒ. El daño dependería entonces de la reacción, la debilidad y la sobrecarga. Es coherente con el pilar de las reacciones, pero cambia mucho el combate, y por eso se pregunta.
- **Archivos:** `nucleo/sigils.gd` (dato). Hay que regenerar a propósito `prueba_dano_tinta` y `prueba_catalogo_reacciones` (los golden) y avisar a COMBATE, porque cambia la vida efectiva de cada enemigo.
- **Coste:** B.
- **Prueba:** que la receta fuego ᛇ ᛇ dé el mismo daño que fuego ᛇ, y que la tinta siga subiendo con cada ᛇ.

### B9b · Barrera legible con la tabla C19 (H14 §3) · en la demo · **HECHO EN PARTE el 22/11**
> **Hecho:**
> - **Rótulo «para… · no para…»** bajo el de la tinta, mientras se apunta una página que levanta algo sólido (`solidez` > 0). Por ejemplo, la de fuego dice «para flechas y agua · no para fuego y piedras». Sale de `Contacto.accion`, sin copiar la tabla (`PrevisionReaccion3D.texto_barrera`).
> - **«se disolverá» parpadea** sobre la barrera que se irá si la nueva llena el tope (`Lanzador3D.barrera_que_se_ira`, que solo mira). La regla del tope está ahora en un solo sitio (`Lanzador3D.cuenta_para_tope_barreras`), compartida con `_materializar`.
> - **Prueba:** `herramientas/prueba_barrera_legible.gd`, 18 comprobaciones, 0 fallos. `prueba_contacto`, `prueba_kit` y `prueba_dano_tinta` siguen en 0.
> - **Hallazgo:** el tope de 3 solo cuenta lo sólido que **nace donde se apunta** (tierra, hielo). La barrera de fuego o de agua que **rodea a la jugadora** no cuenta (`en_punto` = false). **Decisión de Pablo (22/11): se deja así.** El tope es para los muros que se quedan en el mapa; la barrera que rodea dura poco.
>
> **Falta:**
> - las siluetas que distinguen protección personal, obstáculo e hijo (VFX);
> - que el anillo de tierra de COMBATE se lea como «solo proyectiles»;
> - separar enemigos al aparecer la protección personal;
> - el rótulo en la ficha del libro (depende de H8).
>
> **Lo que se planeó:**
- **No se duplica la tabla.** La de contacto barrera × proyectil es de COMBATE y ya está en `nucleo/contacto.gd` (`Contacto`). La usan las flechas, la trampa de flechas y el aliento del dragón, y la prueba `herramientas/prueba_contacto.gd`. Aquí solo se **lee**.
- **Qué falta:**
  - **La previsión y la página dicen qué para esta barrera.** Se consulta `Contacto` con el elemento de la barrera en `PrevisionReaccion3D` y en la ficha del libro (H8).
  - **Las siluetas distinguen** la protección personal (rodea a la jugadora), el obstáculo colocado (tierra donde apuntas) y la barrera que nace como hijo (B7).
  - **Se marca cuál se irá** al llegar al tope de 3 (`MAX_BARRERAS_VIVAS`, `magia/lanzador_3d.gd:68`): un parpadeo en la más antigua mientras se apunta la nueva.
  - **El anillo fino de tierra** (A4 de COMBATE) solo para proyectiles: tiene que verse.
  - **Separar enemigos al aparecer la protección personal**, solo para resolver solapes, sin empuje ofensivo.
- **Archivos:** `presentacion/prevision_reaccion_3d.gd`, `magia/prevision_hechizo.gd`, `magia/lanzador_3d.gd` (aviso de la más antigua), `presentacion/vfx_3d.gd` (siluetas).
- **Coste:** M.
- **Depende de:** COMBATE (la tabla y el anillo de tierra), que ya están.
- **Prueba:** escenario sin ventana. Con barrera de fuego, la previsión dice «quema flechas»; con 3 barreras vivas, al apuntar la cuarta queda marcada la más antigua.

### B9b-bis · Previsión durante el casteo (de Codex, adoptada por HECHIZOS el 22/11)
- **Qué es:** `docs/PROPUESTA_PREVISION_CASTEO_2026-11-22.md`. Mientras se apunta y se conjura, una silueta tenue y abierta según el perfil del hechizo (protección, proyectil, haz, volumen móvil, suelo, órbita…), sin efectos, que desaparece al disparar. Aprobada por Pablo.
- **Archivos:** `magia/prevision_casteo_3d.gd` (`PrevisionCasteo3D`); el enganche en `magia/lanzador_3d.gd` (`PREVISION_CASTEO_ACTIVA`, `_mostrar_prevision_casteo`, `recorrido_visual`). **No pisa nada**: el rótulo y la barrera que se disuelve de B9b, las cifras de M1 y la `solidez_en` de COMBATE siguen igual.
- **Ajustes de HECHIZOS (22/11):**
  1. **«No vale» en gris** (`COLOR_NO_VALE`), no en rojo: el rojo es de los avisos enemigos (G4).
  2. **La tierra en tu casilla se dibuja como el anillo fino de COMBATE** (A4: dos aros y postes, 0,75 u), no como una cúpula. También se quita el volumen amarillo relleno que pintaba la simulación (`recorrido_visual`). Condición: `PrevisionCasteo3D.es_anillo_tierra`.
  3. **El rótulo «para…» de B9b se pega encima de la silueta** (`cima_silueta`), con el color del elemento, en vez de tapar a la jugadora. Dice **«para todos los proyectiles»** en lugar de «para todo» (la tabla de contacto solo habla de proyectiles). Para el anillo añade **«· no para golpes ni explosiones»**.
- **Fotos con ventana:** `docs/capturas/prevision_casteo_2026-11-22/antes/` y `/despues/`: protección de fuego, de agua y de tierra (en tu casilla y colocada), proyectil, volumen móvil, haz, suelo, órbita, muro y casteo. Las saca `escenario_prevision_casteo.gd -- <carpeta>`.
- **Pruebas:** `prueba_prevision_casteo` (1568 comprobaciones), `escenario_prevision_casteo`, `prueba_barrera_legible`, `prueba_apuntado`, `prueba_prevision_hechizo`, `prueba_prevision_reaccion` y `prueba_contacto`: 0 fallos.
- **Decisión de Pablo (22/11): «prefiero la silueta»**, para no recargar la vista. El rótulo «para…» **ya no sale al apuntar** (`PrevisionReaccion3D.ROTULO_BARRERA_AL_APUNTAR = false`). El nombre de la página va abajo, en el HUD (H16), como en Mystralia. `texto_barrera` se queda para la ficha del libro (H8). Siguen saliendo el rótulo de tinta y recarga (E4, que ya existía) y el «se disolverá», que solo aparece con el tope lleno.

### B9c · Flecha: trayectoria completa y sin daño implícito (H14 §8) · en la demo
- **Hoy:** cada ᛇ suma +1 casilla de alcance (tope 6) y un poco de impulso (`sigils.gd:384-387`), y sube el daño por recuento.
- **Propuesta:**
  - el daño lo resuelve B9a;
  - la **previsión dibuja la trayectoria entera**, con el arco y el punto de llegada;
  - alcance, velocidad y curvatura quedan como parámetros separados;
  - la curva hacia un lado solo cuando haya una sala que la pida, y saldría del hueco de la corona (se decide con H4, **P5**).
- **Archivos:** `presentacion/apuntado_3d.gd` (la cinta ya existe), `magia/prevision_hechizo.gd`.
- **Coste:** B–M.
- **Prueba:** que el punto de llegada de la previsión y el de la flecha real coincidan, con una pared en medio y sin ella.
- **Hallazgo de COMBATE (22/11, fase B, `herramientas/prueba_coraza_elemento.gd`):** **tierra + ᛇ** (el sólido que viaja) solo toca a un enemigo a 1 casilla. A 2 casillas, en la ArenaCombate, no le toca; fuego + ᛇ sí llega. Hay que mirarlo dentro de B9c, porque es justo «la previsión dice adónde llega y la flecha llega ahí».
- **Medido por HECHIZOS (22/11)** con una sonda en el Bosque: goblin a 1, 2 y 3 casillas, flecha con un ᛇ (alcance 2).

  | Receta | 1 casilla | 2 casillas | 3 casillas | Altura máxima del vuelo |
  |---|---|---|---|---|
  | fuego + ᛇ | acierta | acierta | no llega | 0,42 u (vuela recto) |
  | tierra + ᛇ | **pasa por encima** | acierta | no llega | **2,57 u** |
  | agua + ᛇ | **pasa por encima** | acierta | no llega | **2,27 u** |

  - **Causa:** tierra y agua salen en arco (`impulso_salida` 2,5 y 1,6 en su `.tres`, con gravedad). El golpe solo cuenta si el proyectil está a menos de ~1 u de altura del pecho del enemigo (`VENTANA_Y_U`, `magia/hechizo_vivo.gd:122`, `:2284`). Cerca, la piedra va por arriba: hay una **zona muerta** a 1 casilla. Con la cámara cenital, se ve atravesar al goblin sin hacerle nada.
  - **COMBATE** lo vio al revés en la ArenaCombate (acierta a 1 y no a 2), seguramente por otra altura del enemigo o del suelo. El fondo es el mismo: el arco decide si acierta, y desde arriba no se lee.
  - **HECHO el 22/11 (Pablo: sin gravedad en los hechizos):**
    - `Hechizo.GRAVEDAD_EN_HECHIZOS = false` (`nucleo/hechizo.gd`): `Hechizo.construir` pone `gravedad` e `impulso_salida` a 0, sea cual sea el elemento. Los `.tres` conservan sus valores por si se vuelve atrás, y el laboratorio puede ponerla con `con({"gravedad": …})`.
    - **Medido con la misma sonda:** fuego, tierra y agua + ᛇ aciertan a 1 y a 2 casillas, y vuelan a 0,42 u.
    - **Puzles:** `escenario_cueva_completa` (el C2 que contaba con el arco), `escenario_cueva_resonante`, `escenario_gruta_batida`, `escenario_puzles_agua` y `escenario_arena_combate` dan 0 fallos.
    - **Golden regenerado a propósito:** solo cambian `gravedad` (las 6 recetas base) e `impulso_salida` (822 recetas).
    - **Pruebas reescritas a propósito:** `prueba_apuntado` 2, `prueba_cast_points` E2b, `prueba_ejecucion_combinaciones` A2, `prueba_hechizo` (§2 y los campos del `.tres`) y `prueba_hechizo_vivo` (el mecanismo del arco se sigue probando con la gravedad puesta a mano). Todas dan 0 fallos.
    - **Sin relación:** `prueba_flecha_agua_revision` da 927 fallos («las gotas activas deben estar por encima del suelo»). Es el laboratorio de efectos de la flecha de agua, con sus propias gotas; no usa `Hechizo`.
    - **Código que ya no se usa:** la rama «con gravedad» de `Lanzador3D._salida_de_mano` (`lanzador_3d.gd:1719-1723`) y la de las cintas del agua en arco (`vfx_elemento_3d.gd:382`). Se dejan por si se vuelve atrás.
  - **HECHO el 23/11 (Pablo: «sigue con B9c, la trayectoria de la flecha»):**
    - **Previsto = real.** Nueva `herramientas/prueba_trayectoria_flecha.gd`: fuego, tierra y agua con ᛇ y con ᛇᛇ, sin nada delante, con un goblin a 2 casillas y con una pared a 1,5. En los 18 casos el punto final previsto cae a ≤ 0,2 u del real (0,7–0,8 u con goblin: la retícula se pone en los pies del goblin y la flecha se para al tocarlo, a menos de media casilla) y acaba por el mismo motivo (alcance / golpe / muro). 148 comprobaciones, 0 fallos.
    - **Arreglado: dos rayas.** Sin gravedad la flecha vuela recta a la altura de la mano, y `Apuntado3D` pintaba la cinta en el aire **y** su sombra punteada en el suelo: dos rayas paralelas, y la cinta no acababa en la retícula. Ahora, si el vuelo no sube ni baja (`_vuelo_plano`, ±0,12 u), la cinta va **a ras de suelo, sin sombra**, y termina dentro de la retícula. La sombra queda para cuando haya arco.
    - **Fotos:** `docs/capturas/trayectoria_flecha_2026-11-23/` (antes_* y despues_*; `herramientas/captura_trayectoria_flecha.gd`).
    - **Siguen bien:** `prueba_trayectorias`, `prueba_apuntado`, `prueba_prevision_casteo`, `prueba_cast_points` y `prueba_hechizo_vivo`, 0 fallos.
    - **Parámetros separados:** alcance (`alcance`, ᛇ +1 casilla) y velocidad ya lo son en `Hechizo`; la curvatura no existe todavía. Se añade solo cuando una sala la pida, desde el hueco de la corona (**P5**/H4).

### Efectos comunes de glifo (24/11) · hecho, a revisar por Pablo
- **Origen:** `docs/MYSTRALIA_VFX_HECHIZOS_CODIGO_2026-11-24.md` §2 (Mystralia tiene efectos de rebote, multidisparo, empuje… que no dependen del elemento). Pablo eligió esta idea de las tres.
- **Qué es:** cada glifo que cambia lo que pasa enseña SU runa (el PNG del libro, `art/ui/glyphs/`), pequeña y un instante (≈ 0,6 s), donde actúa. El elemento ya lo cuenta el toy; esto cuenta el glifo.
  - **ᚠ repetición:** al soltar, la runa sobre la mano y un trazo por copia, paralelos y separados como salen las copias (`desvio`); en ráfaga (ᛇ antes de ᚠ), trazos en fila.
  - **ᚢ rebote:** en cada rebote, la runa en el punto y un aro plano contra lo que rebotó.
  - **Nace un hijo** (de momento solo el prototipo del libro rojo): un aro que se cierra sobre el punto y la runa del sello del hijo. Sustituye al destello de estrella.
- **Archivos:** nuevo `presentacion/vfx/glifo_comun_vfx.gd` (`GlifoComunVfx`), conectado en `presentacion/prueba_test2.gd` junto a `VfxToyJuego`; `laboratorios/prototipo_anidado.gd`; laboratorio `LabVfxComparativa3D` (Ctrl+1 ᚠ, Ctrl+2 ᚢ, Ctrl+3 hijo con el sello elegido con Z).
- **Sin luces** (el presupuesto de luces es del toy) y sin tapar: se dibuja por encima del VFX del elemento.
- **A decidir por Pablo:** el color (`COLOR_GLIFO`, tinta clara neutra), el tamaño y si ᚠ en ráfaga necesita algo más que la fila. Siguientes candidatos: ᚱ pulso (va con B9e), ᛇ no (la flecha ya es el proyectil).
- **Prueba:** `herramientas/prueba_glifo_comun.gd` (30 comprobaciones, 0 fallos) y una línea más en `prueba_prototipo_anidado.gd`. Fotos: `docs/capturas/glifo_comun_2026-11-24/` (`captura_glifo_comun.gd`).

### B9d · Sobrecarga legible y, después, Carga ⧖ (H14 §4)
- **Hoy:**
  - la sobrecarga (mantener 0,8 s) da ×1,5 de potencia y tinta ×2 (`lanzador_3d.gd:59-61`);
  - ⧖ da ×1,5 de potencia y ×1,69 de tamaño, y cuenta doble para el daño;
  - las dos cosas se multiplican sin que se vea.
- **En la demo** (⧖ no está): que la sobrecarga **enseñe antes de soltar** el progreso, el umbral y el coste (la tinta ×2 sobre la barra de H9), y qué pasa si se suelta antes, se interrumpe o falta tinta. El arco dorado del HUD ya existe (`page_hud.gd`): **hay que coordinarlo con GAMEFEEL**, que lleva el HUD.
- **Después de la demo:** una regla común. El glifo dice qué se puede potenciar y mantener pulsado ejecuta la carga. No se apilan dos ×1,5 sin verse.
- **Coste:** B–M la sobrecarga, M la carga.

### B9e · ᚱ pulso no se confunde con un hijo (H14 §9) · en la demo
- ᚱ propaga el efecto del hechizo: 4 casillas por glifo, salta al impactar si viaja y es continuo si se queda. Crear otro hechizo es cosa de los conectores (B7).
- **Falta** un efecto propio para «nace un hijo» (B2), distinto de la onda de ᚱ, del crecer de ᚷ y de una detonación.
- **Coste:** B. **Prueba:** con ventana, que se distingan a ojo.

### B9f · Repetición a la vez en todas las formas (H13) y sus distribuciones (H14 §2) · después de la demo
- **Hoy:**
  - el proyectil y el volumen quieto ya se repiten a la vez, en abanico de 15° más separación (`HechizoVivo.salida_de_copia`, `magia/hechizo_vivo.gd:270`);
  - con ᛇ antes de ᚠ sale la ráfaga (`nucleo/hechizo.gd:24`);
  - **el haz ᛁ y ᛒ ignoran ᚠ y cobran la tinta igual.**
- **Propuesta (H13):**
  - haces paralelos, cada uno con su corte en lo sólido;
  - ᛒ repetido en fila perpendicular (ᚠ ensancha, ᛇ alarga, encaja con H11);
  - un solo sonido más grueso.
- **Distribuciones (H14 §2):** abanico, paralelo (la captura de Mystralia es `dispersion` 0) y ráfaga. Hay que decidir **cómo se elige al dibujar** (P5, H4) y **si la repetición por defecto es paralela o en abanico** (**P10**).
- **Copias e hijos:** empezar con la multiplicación apagada. Si se activa, cobrar **hijos × copias** (hoy no se hace).
- **Cuidados:** tres haces solapados no pegan tres veces al mismo enemigo. Las copias cuentan para los topes de vivos (32) y de barreras (3).
- **Coste:** B–M.
- **Depende de:** P3 (ᚠ no está en el primer libro).

### B9g · Crecer y Permanencia (H14 §5) · después de la demo
- Hay que presupuestar por separado el tamaño máximo, el tiempo de crecer, la duración y la frecuencia. Que no suban el daño lo resuelve B9a.
- **El aviso de «va a desaparecer» con la misma convención que el temporizador común** (P8 de PROPUESTAS, `docs/CONCEPTO_TEMPORIZADOR_2026-11-21.md`), para que todo lo que caduca avise igual.
- **Coste:** B–M.

### B9h · Buscar conserva el objetivo (H14 §1) · después de la demo
- **Hoy** `_buscar` (`magia/hechizo_vivo.gd:2147`) elige cada fotograma el enemigo más cercano del cono, sin memoria ni paredes.
- **Propuesta:**
  - guardar el objetivo;
  - cambiarlo solo si otro está claramente más cerca (la regla ×1,2 de Mystralia como punto de partida);
  - buscar a intervalos y girar con suavidad;
  - no elegir lo que no se ve;
  - la misma regla en `_orbe_busca` (`:671`).
- **Coste:** B–M.
- **Prueba:** dos enemigos a distancias parecidas, el objetivo muere, deja de ser apuntable o se pone detrás de una pared.

---

## 10. Preguntas para Pablo

**Respondidas (Pablo, 22/11):**
- **P1 · TU1: no.** El tutorial será **una cueva, pero no la Gruta Batida: una minimazmorra nueva**. Falta diseñarla y hacer su mapa; B1 puede montar el kit, los flags y los cofres del resto de la ruta mientras tanto.
- **P3 · Capacidad: aplazada.** La salida que ve Pablo como «lo más elegante» es **redistribuir la página derecha del libro** para que quepan más glifos, en vez de recortar la lista. «Todavía es pronto para decidir eso.» Mientras tanto: ningún cofre de la demo da un séptimo glifo y ⧖, ᛉ y ᛖ no se reparten. Si hace falta probarlos, se sube el número de `CAPACIDAD_PRIMER_LIBRO` solo para la prueba.
- **P2 · TU5:** ᛁ línea, **posiblemente en el Bosque 02** (`cofre_corazon`). Queda por confirmar, y por decidir qué da entonces el `cofre_01` del Bosque 01.

**Para montar la demo (bloquean B1):**
1. ~~P1~~ (respondida arriba).
2. ~~P2~~ (respondida arriba). Sigue abierto: ¿ᛏ altura en las Cuevas, con la tierra?
3. **P3 · Capacidad del primer libro (6 glifos):** la demo ya la llena con ᛇ ᛜ ᛁ ᛏ ᚱ ᛒ. ¿Qué se hace con ᛉ (Ruinas), ᛖ posición (Bosque 02) y ⧖?
   - a) subir la capacidad del primer libro a 7 u 8;
   - b) cambiar algunos (por ejemplo, ᛉ en lugar de ᚱ, que es opcional en la Cueva);
   - c) dejarlos para después de la demo.
4. **TU2:** ¿qué dan entonces el `cofre_01` del Bosque 01 y el `cofre_corazon` del Bosque 02? (Mi propuesta: ᛁ y la página 3, que ya da.) ¿Y el guardabosques sigue vendiendo la barrera?
5. **TU3:** ¿entregas celebradas (libro, fuego y flecha uno a uno, coste M) o arranque con los tres de golpe (coste B)?
6. **TU4:** ¿la segunda página al final del tutorial o en el Bosque 01?

**Para el libro:**

7. ~~**P4 · H12:** ¿la página de dos círculos sustituye al libro avanzado de sellos dobles, o conviven?~~ **Respondida (H14 §6): conviven.**
8. **P5 · H4:** ¿el orden de dibujo se queda (y se enseña en la página) o se pasa a la vecindad en la corona? Decide cómo se dibuja ⧖ y las ráfagas.
9. **P6 · H10:** ¿qué control cambia la variante en combate: la rueda del ratón, la cruceta o un gatillo + el número? ¿Las hojas 4–8 son variantes de los botones 1–3?
10. **H2:** ¿el botón «sobre mí» va en la demo? Pide un cuarto botón (`PAGES` = 4).
11. **P7 · ⧖ en la demo:** si cabe (P3), ¿dónde se gana?

**Para combate (cruza con el apartado de combate):**

12. **P8 · H11 y T3:** si ᛒ + ᛇ hace un puente de tierra sobre el vacío, ¿T3 · El foso pasa a pedir el rastro, o el rastro es corto y caro para que T3 siga siendo paso a paso?
13. **TU6:** ¿la barrera del tutorial protege de verdad de las flechas? Desde el 22/11 lo decide la tabla de contacto de COMBATE (`nucleo/contacto.gd`; la barrera de fuego quema las flechas). Queda comprobar que la barrera que se gane en la minimazmorra enseñe eso.

**Nuevas, de las mejoras de glifos (H13, H14):**

14. **P9 · Qué glifos suben el daño (B9a).** Propuesta de partida:
    - **forma o transporte, no suben el daño:** ᛇ flecha, ᚷ crecer, ᛉ permanencia, ᚨ buscar, ᚢ rebote y ᚠ repetición (ᚠ ya cobra con `K_COPIA`);
    - **potencia, sí suben:** ᛜ barrera, ᚱ pulso, ᚦ perforar y ⧖ carga.
    
    En la demo, «fuego + flecha» quedaría siempre en daño ligero y el daño saldría de las reacciones, la debilidad y la sobrecarga. ¿Así, otro reparto, o se deja como está?
15. **P10 · Repetición (H13):** ¿las copias salen **paralelas** (como la captura de Mystralia) o en **abanico** (hoy, 15°)? ¿Y el otro reparto se elige al dibujar, o no existe?
16. **P11 · Hijo del conector (B7):** ¿se cobra **al activarse** (si la flecha no impacta, no pagas el segundo hechizo) o se **reserva al lanzar** (pagas todo de golpe y se ve antes)?
18. **P13 · «A la vez» (H15, para después de la demo):**
    - **b) Decidida (Pablo, 22/11):** recarga sumada, tiempo de lanzar sumado y sin sobrecarga. Además, **≈ 0,17 s de retardo** entre los dos, como en Mystralia.
    - **a) Casi resuelta por el retardo:** al salir separados, el fuego y el agua ya no nacen uno encima del otro. Queda decidir si dos cosas **quietas** del mismo lanzamiento (dos barreras en el mismo sitio) reaccionan entre sí. Propuesta: no (filtro por linaje).
19. ~~**P14 · Flechas en arco (tierra, agua)**~~ **Decidida (Pablo, 22/11): «quitar el efecto de la gravedad en hechizos, penaliza demasiado».** Hecho; ver B9c.
17. ~~**P12 · Orden:** ¿apruebas el orden de §0, con H13 detrás porque ᚠ no está en la demo?~~ **Aprobado por Pablo (22/11).** B1 espera a la minimazmorra y B9a a P9, así que lo siguiente es **M1** (B8).
