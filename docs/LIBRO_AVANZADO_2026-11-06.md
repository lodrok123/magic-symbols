# Libro avanzado: 2 sellos + 6 glifos

6/11/2026 · contexto JUEGO · **propuesta para revisión, nada construido**. Viene de `PROPUESTAS_COMBATE_2026-11-06.md` §5 (sellos dobles con 4 elementos base).

---

## 0. Qué hay ya

- **Maqueta visual del libro avanzado:** `presentacion/grimorio/paginas.json` trae la distribución `s2g6` (2 sellos, 6 glifos: núcleo partido en dos mitades tipo yin-yang, 6 huecos en dos filas de 3 bajo el círculo, página derecha con rejilla 4 × 3 y 6 círculos de elemento). Láminas `pagina_{botanico,astral,acuarela}_s2g6.png` y `grimorio_ui.gd` (tecla 2 con el libro abierto). Solo aspecto: no reconoce dibujos.
- **Libro de juego:** `presentacion/ui/spellbook.gd` (Control montado por script desde `magia/lanzador_3d.gd:625`), lógica en `magia/grimorio.gd` (`Lanzador3D extends Grimorio`). Lámina «bosque»: círculo de radio 232,8, núcleo 119,6, 8 sectores, huecos `[2,3,1]`.
- **Hechos del código que condicionan el diseño:**
  1. **El sector donde cae un glifo no cambia el hechizo.** `Lanzador3D.receta_de_ficha` (`lanzador_3d.gd:809-828`) funde los glifos de todos los sectores en una receta por página; `Receta3D.contadores` es un multiconjunto (`:2878`). Lo único posicional que sobrevive es `linea_x` / `linea_z`, y eso depende de la **orientación del trazo**, no del sector (`spellcaster.gd:238-245`).
  2. **Un segundo gesto en el núcleo sustituye al primero** (`grimorio.gd:515-521`). La página guarda un solo `element` (`grimorio.gd:169`) y `Hechizo.construir` recibe un solo `RuneData` (`nucleo/hechizo.gd:340`).
  3. `Hechizo.MAX_GLIFOS = 6` (`hechizo.gd:62`) ya coincide con el libro avanzado.
  4. La capacidad del libro (`Repertoire.max_elementos/max_glifos`, `CAPACIDAD_PRIMER_LIBRO = [4, 6]`, `lanzador_3d.gd:100`) la fija el nivel, no se gana jugando.
  5. Las páginas guardadas en `Repertoire.paginas` **no se vuelven a cargar en el Grimorio** (`repertoire.gd:216-217`) y pierden el sector. Con el libro avanzado hay que arreglarlo de paso.
  6. Hay dos copias de la lógica (`grimorio.gd` y `spellcaster.gd`, la 2D). El libro avanzado se hace solo en `Grimorio`; `spellcaster.gd` se retira o se deja fuera.

---

## 1. Idea de Pablo (6/11): dos zonas de dibujo, no huecos

> En vez de dibujar en cada hueco, dejar dos espacios de dibujo grandes, uno para sellos y otro para glifos, y que los glifos se coloquen solos en la página.

**La apoyo, y el punto 1 de arriba es la razón:** como el sector no significa nada al lanzar, pedir al jugador que apunte a un hueco de 32 px es exigir precisión sin recompensa. Con dos zonas grandes:

- el gesto se dibuja a **tamaño cómodo** (hoy un glifo en un sector cabe en ~90 px; en una zona propia cabe en 250–300 px), lo que mejora el reconocimiento ($P y trazos rectos trabajan mejor con más puntos);
- **dónde dibujas sigue decidiendo qué es** (zona de sellos = elemento, zona de glifos = glifo), que es la regla que liberó el vocabulario (ARQUITECTURA «Sectores»);
- el glifo reconocido **vuela solo a su hueco** con la mano y la pluma, que ya escriben glifos (`spellbook._escribiendo`, `:1809`), y así la página llena se lee igual que ahora;
- el orden de dibujo queda en la fila de huecos, que es lo que haría falta si algún día el orden importa (C2 de las propuestas).

**Lo que se pierde:** el atajo «trazo recto suelto en un sector = flecha o barrera según su sentido respecto al centro» (`Sigils.PATTERN_AS_SIGIL`). Se puede conservar por orientación (horizontal = flecha, vertical = barrera) o retirarlo: propongo retirarlo, es azúcar que nadie echará de menos y confunde con `linea_x` / `linea_z`.

### 1.1 Distribución propuesta (página izquierda)

```
┌──────────────────────────┬──────────────────────────┐
│   ZONA DE SELLOS         │   ZONA DE GLIFOS         │
│   (círculo, Ø ~300 px)   │   (cuadro ~300 × 300 px) │
│                          │                          │
│   se dibuja aquí;        │   se dibuja aquí;        │
│   el sello reconocido    │   el glifo reconocido    │
│   cae en ◐ o ◑ abajo     │   cae en el 1er hueco    │
│                          │   libre de la fila       │
├──────────────────────────┴──────────────────────────┤
│  ◐ ◑  = sello 1 · sello 2 · [runa resultante]       │
│  ○ ○ ○ ○ ○ ○  = 6 huecos de glifo (orden de dibujo) │
│  resumen: «Magma · flecha ×2 · rebote»   tinta  CD  │
└─────────────────────────────────────────────────────┘
```

- **Zona de sellos** a la izquierda, redonda, con el anillo decorativo del núcleo de hoy ampliado. Es donde está «la magia»; mantener el círculo preserva la identidad del libro (`docs/referencia_grimorio.png`).
- **Zona de glifos** a la derecha, cuadrada. Mismo tamaño útil.
- **Fila de resultado** abajo: dos medallones de sello (◐ ◑) y, entre ellos o a la derecha, el medallón de la **runa resultante** cuando los dos sellos reaccionan (hielo, rayo, magma, barro); si se anulan, los dos medallones se apagan con un soplo de vapor o polvo y el resumen dice «Se anulan».
- **6 huecos** en fila (o 2 × 3 como en la maqueta `s2g6`). La maqueta ya tiene medidas para 2 × 3: `paginas.json` `s2g6.huecos`.
- La maqueta `s2g6` con el yin-yang en el núcleo sirve **como lámina de la fila de resultado**, no como zona de dibujo.

### 1.2 Alternativa conservadora (por si no convence)

Mantener el círculo con 8 sectores y partir el núcleo en dos mitades (la maqueta `s2g6`). Un gesto cuyo centro caiga en la mitad izquierda es el sello 1, en la derecha el sello 2. Es menos trabajo de UI (solo `_sector_of_point`, `spellbook.gd:1400`, y `_draw_core`, `:1929`), pero no resuelve el problema de espacio que señala Pablo. Se deja anotada.

---

## 2. Reglas del libro avanzado

| regla | propuesta |
|---|---|
| Sellos por página | 2. El tercero sustituye al **más antiguo** (hoy sustituye al único); deshacer lo recupera (`undo_history`). |
| Orden de los sellos | No importa: fuego + agua = agua + fuego. La tabla se consulta con la pareja ordenada alfabéticamente. |
| Opuestos (fuego/agua, tierra/viento) | **Se anulan en el libro, no al lanzar:** al cerrar el segundo, soplo de vapor o polvo, los dos medallones se vacían y el resumen avisa. No gasta tinta. La primera vez que ocurre, el grimorio escribe solo la regla en la página derecha (como escribe un glifo nuevo). |
| Reacción | Pareja no opuesta → runa derivada (hielo, rayo, magma, barro) según la tabla de `PROPUESTAS_COMBATE_2026-11-06.md` §5.2. La página lanza **el derivado**; `Hechizo` sigue recibiendo un solo `RuneData`. |
| Runa descubierta | Al lanzar por primera vez un derivado, su runa se escribe en la página derecha. **Decisión pendiente:** si después se puede trazar directamente en la zona de sellos (propuesta: sí; así nivel 3 = runa descubierta + base cabe en los 2 huecos). |
| Glifos por página | 6 (`Hechizo.MAX_GLIFOS`). Se abren con `Repertoire.max_sigils_per_page` como hoy (base del libro + `Mejoras.huecos_glifo`): el libro avanzado trae **4 abiertos** y los otros 2 se ganan (librera, cofre), para que cambiar de libro no lo dé todo de golpe. |
| Un sello solo | Vale igual que hoy: el libro avanzado no obliga a dos. |
| Tinta | Dos sellos suben un nivel la potencia de tinta (ligera → media) sin subir el daño base: lo que se paga es la reacción. Constante en `Dano`. |
| Páginas | Siguen siendo 3. |
| Recarga | Igual: el mayor `cooldown` de los glifos; el derivado puede llevar `cooldown` propio en su `.tres`. |

---

## 3. Página derecha (lámina)

Con 4 elementos base la lámina cambia:

- **Fila de sellos:** 4 base siempre visibles (fuego, agua, tierra, viento) + **4 medallones de runa derivada** en gris hasta descubrirlas (hielo, rayo, magma, barro). La maqueta `s2g6` ya dibuja 6 círculos de elemento abajo (`paginas.json` `s2g6.elementos`): pasan a 8, o 4 + 4 en dos filas.
- **Rejilla de glifos:** 4 × 3 = 12 casillas (maqueta `s2g6.rejilla_*`). Hoy hay 10 glifos de receta + 4 aparcados: cabe todo.
- **Tabla de reacciones** descubiertas (opcional, segunda hoja al pasar página): «agua + viento = hielo», se va rellenando. Sirve de pista y de ficha de enemigo (idea de «fichas en el libro» de PROPUESTA_COMBATE §4).

---

## 4. Cómo se consigue el libro

- **Objeto de aventura, no de nivel.** Hoy el libro lo fija la progresión del nivel (`Repertoire.libro`, `aplicar_progresion`, `lanzador_3d.gd:571-581`). Propongo que el libro avanzado sea un **cofre legendario** (como los glifos: `objetos/secuencia_cofre_legendario_3d.gd`) en la primera mazmorra tras el Bosque (el «nivel posterior con más habilidades» que Pablo decidió el 6/11), y que `Repertoire.libro` se guarde en `a_dic` / `Partida`.
- **Conserva las páginas:** al cambiar de libro, las 3 páginas se copian (elemento → sello 1, glifos → huecos). Exige arreglar la carga de `Repertoire.paginas` en el Grimorio (punto 0.5).
- **Secuencia:** abrir el cofre → el libro viejo se cierra y el nuevo se abre con la animación de `_animar_libro` → la mano escribe la regla «dos sellos» en la página derecha.

---

## 5. Cambios en código (orden de trabajo)

| # | qué | dónde | tamaño |
|---|---|---|---|
| L1 | Tabla de parejas → derivado y lista de opuestos; un `.tres` por derivado (hielo y rayo ya existen: `ice_rune.tres`, `lightning_rune.tres`; nuevos: magma, barro) con etiquetas heredadas | `nucleo/combos_sellos.gd` (nuevo), `nucleo/*.tres` | S |
| L2 | Página con dos sellos: `element2`, `element2_q`; `_add_element` rellena 1 o 2 y sustituye el más antiguo; `undo_last`, `clear_sequence`, `page_ready`, `page_element_data`, `_clave_ficha`, `resumen_pagina` | `magia/grimorio.gd:169, 492-525, 741, 762, 786-798, 214, 205-259` | M |
| L3 | Resolver la pareja antes de construir: `receta_de_ficha` y `_preparar_pagina` llaman a la tabla; si se anulan, no se lanza; color del HUD por derivado | `lanzador_3d.gd:809, 907-915`, `page_hud.gd:53` | S |
| L4 | Zonas de dibujo: `_sector_of_point` devuelve «sello» o «glifo» por zona; el glifo reconocido va al primer hueco libre con la escritura de la mano; nueva entrada en `LIBROS` con medidas `s2g6` | `spellbook.gd:120-155, 1400, 1567, 1809, 1929` | L |
| L5 | Lámina derecha: 4 + 4 sellos, rejilla 4 × 3, casillas en gris hasta descubrir; `_por_escribir` también para derivados; guardado en `a_dic` | `spellbook.gd:1606-1680`, `repertoire.gd:170-188, 221-243` | M |
| L6 | Libro como objeto: `Repertoire.libro` persistente, cofre que lo da, copia de páginas, carga de `paginas` en el Grimorio | `repertoire.gd:57, 214-243`, `partida.gd`, cofre | M |
| L7 | Tinta: nivel +1 con dos sellos | `nucleo/dano.gd` | S |
| L8 | Previsión: `PrevisionHechizo` y `PrevisionReaccion3D.ESTILO` con rótulo y color de cada derivado | `magia/prevision_hechizo.gd`, `presentacion/prevision_reaccion_3d.gd` | S |
| L9 | Retirar `spellcaster.gd` o dejarlo explícitamente fuera | `magia/spellcaster.gd` | S |

Pruebas: ampliar `prueba_libro_bosque.gd`, `prueba_capacidad_libro.gd` y `prueba_escritura_glifo.gd` con la lámina avanzada; prueba nueva `prueba_sellos_dobles.gd` (pareja → derivado, opuestos se anulan sin tinta, tercer sello sustituye al más antiguo, un solo sello sigue valiendo, página copiada al cambiar de libro, carga y guardado).

Reparto: Opus diseña y revisa, Sonnet programa (L1–L3 y L7 primero, que no tocan UI; L4–L6 después con las láminas).

---

## 6. Arte y sonido que hace falta

- **Lámina del libro avanzado** con las dos zonas de dibujo y la fila de resultado (base: `pagina_*_s2g6.png` y `docs/referencia_grimorio.png`; medidas en `docs/ARTE.md` §16).
- **Runas de magma y barro** (hielo y rayo ya están en `docs/runas.png`), y sus medallones en gris.
- **Efecto de anulación** (soplo de vapor y polvareda sobre la página) y **efecto de reacción** (los dos medallones se funden en el tercero).
- Sonido: anular, reaccionar, pasar al libro nuevo.

---

## 7. Decisiones para Pablo

1. Dos zonas de dibujo (§1.1) o núcleo partido con sectores (§1.2).
2. Huecos en fila de 6 o en 2 × 3.
3. ¿Una runa descubierta se puede trazar directamente?
4. ¿El libro avanzado trae 4 huecos de glifo abiertos y 2 por ganar, o los 6?
5. ¿Retirar el atajo de trazo recto suelto (`PATTERN_AS_SIGIL`)?
6. Dónde se consigue: ¿cofre de la primera mazmorra tras el Bosque?
