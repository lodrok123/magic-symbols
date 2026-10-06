# Assets de `PruebaTest2` — revisión de QA y lista de regeneración (5 de octubre, tarde)

Revisado todo lo que carga la maqueta: las 36 piezas de `bosque.glb`, `objetos.glb` y `magia.glb`
(hojas `hoja_bosque.png`, `hoja_objetos.png`, `hoja_magia.png`), las 8 texturas de `suelo_meshy\`, los
29 sprites de `vfx\` y las hojas de revisión de los tres personajes chibi. Criterio: **que la prueba no
se contamine** con piezas que no son lo que dicen ser o que rompen el estilo; lo que solo es mejorable se
deja para después.

Veredicto por bloques: suelo ✔ (demasiado claro, se corrige por shader), VFX ✔ con 2 arreglos,
personajes ✔ con 1 aviso, decorado: **9 piezas a regenerar, 2 a sustituir, 1 a retirar**.

---

## 1. Decorado — regenerar (Meshy, una pieza por generación, con `referencias/<id>.png` + [ESTILO])

| id | biblioteca | qué está mal | qué pedir |
|---|---|---|---|
| `matas` | bosque | rocas de cristal rosa/verde, no matas (ya anotado) | mata de hierba redondeada, 3–4 manojos, solo verdes. O **retirar**: `Hierba3D` ya las pone |
| `flores` | bosque | cuatro bolas rosas | **retirar**: las pone `Hierba3D` |
| `arbusto` | bosque | manchas salmón/rosa en la copa: la textura ha pintado "flores" donde no las hay | arbusto solo verde, dos tonos; `no flowers, no pink` |
| `arbusto_flores` | bosque | las flores son parches rosas planos | arbusto verde con 5–7 flores **pequeñas y redondas**, blancas o amarillas (las rosas se confunden con `flor_reactiva` y `pocion`) |
| `cartel` | bosque | es un poste: **no tiene tablón** | poste con una tabla rectangular clavada, texto no, veta de madera |
| `tocon` | bosque | la cara cortada sale rosada | tocón con anillos marrón claro; `no pink` |
| `seto_seco` | magia | plano y alargado, en fila parece un ciempiés (ya anotado) | seto compacto y redondeado, ramas secas marrones, alto ≈ 1 casilla. Mientras tanto, **sustituir** por `arbusto_otono` de `arboles_2.glb` (hojas naranjas, forma de seto) |
| `baldosa_guardado` | objetos | losa gris sin lectura; no se distingue del `pasadero` ni del suelo | losa cuadrada de piedra con una **runa grabada que brilla** (celeste) en el centro, borde biselado |
| `pasadero` | objetos | placa beige/naranja plana, parece un trozo de suelo | piedra pasadera redondeada, gris, con musgo en el borde, claramente **sobre** el agua |
| `puesto` | objetos | toldo azul/blanco de pocos polígonos y textura borrosa | **sustituir** por `puesto_mercado` de `mercado.glb` (mejor malla y textura) |
| `caja_cristal` | objetos | los empujables se harán con cubos y textura (ESTADO.md) | **retirar** de la maqueta |

Pasan tal cual: `arbol_redondo`, `pino`, `roca_grande`, `piedras`, `tronco`, `setas`, `valla`,
`arco_puerta`, `totem_runico`, `brasero`, `fogata`, `caja_pequena`, `placa_peso`, `juncos`, `barril`,
`cofre`, `caja`, `dummy`, `seta_reactiva`, `flor_reactiva`, `raiz_reactiva`, `portal_salida`, `puente`,
`pocion`, `pilar`. Las bibliotecas nuevas (`arboles_2`, `mercado`) pasan; `armas_goblin` no entra en
la prueba (falta preparar origen y orientación).

Regla para las regeneradas: **una pieza por GLB** (no lámina), textura pedida, ~3.000–5.000 triángulos,
y el id de la tabla.

**Cómo se integran (desde el 5/10):**
1. Deja el GLB de Meshy en `meshy\entrada\` **renombrado con su id**: `cartel.glb`, `pasadero.glb`... (el
   `_texture` final de Meshy se quita solo).
2. Doble clic en `meshy\INTEGRAR_PIEZAS.cmd`: lo deja en `meshy\piezas\<id>.glb` (avisa si pasa de 5.000
   triángulos o si el id no lo conoce la maqueta) y mueve el original a `entrada\_procesados\`.
3. Godot: `CatalogoAssets.tscn`, F6, tecla **H** = hoja de contacto: cada pieza nueva junto a la chibi, a la
   medida de la maqueta. Si vale, `PruebaTest2` ya la usa (gana a la de la lámina). Si no, borra
   `piezas\<id>.glb` y vuelve la de antes.

## 2. Suelo (`suelo_meshy\`) — no regenerar

Las 6 texturas son del mismo juego, sin costuras (diferencia en el borde igual que entre vecinos:
0,7–1,4) y a 1024. Lo único: **demasiado claras** para la guía (`path` V 0,99, `dirt`/`water` 0,91,
`hierba` 0,82; la paleta de bosque de `ARTE.md` va de 0,2 a 0,76). `PruebaTest2` ya bajó la luz
(ambiente 0,42, sol 0,78) para compensar; es mejor bajar las texturas (multiplicar por 0,75–0,8 en el
shader o en el PNG) y devolver la luz a valores normales, porque con la luz baja los personajes también
se apagan. `hierba_borde` y `hierba_matojos` bien.

## 3. VFX (`vfx\`) — dos arreglos, el resto pasa

- `remolino_viento`: es **azul**. El viento del juego es verde (`#8FD46A`, `ARTE.md` §1); en azul se
  confunde con agua y hielo, que son sus vecinos. Regenerar en verde claro.
- `llama`: la llama toca el borde inferior del PNG (alfa 9 en el borde): sale recortada. Usar
  `llama_tira8` (está bien) o regenerar con margen.
- Sprites con "satélites" (`burbuja` trae dos burbujas más, `gota` gotitas, `hoja` hojas extra, `brasa`
  chispas, `petalo` pétalos): como partícula repetida, los satélites se ven como fantasmas. No bloquea la
  prueba; cuando se regeneren, pedir `single object, no extra pieces`.
- Buenos y coherentes entre sí: `chispa_electrica`, `circulo_runico`, `copo`, `cristal_hielo`,
  `destello`, `esporas`, `grieta`, `humo`, `ondas`, `pua_tierra`, `rayo`, `salpicadura`, `telarana`,
  `terrones`, `polvo`, `anillo_polvo`, `piedrecitas`, `roca_*`, `pasadero`.

## 4. Personajes — pasan, con un aviso

- `chibi_elf`: en la maqueta (modelo master) tiene el pelo dorado y el vestido verde azulado; en la hoja
  de revisión del pipeline (fase de arte, look pastel de `npc_e2e_v2_4`) el pelo sale **casi blanco** y el
  vestido azul. Son dos looks del mismo personaje: decidir cuál es el canon **antes** de regenerar nada más,
  porque el decorado se pidió "con el mismo acabado que la chibi". Para la prueba, el master.
- `bookseller_chibi`: bien.
- `goblin_warrior_chibi`: el pelo le tapa la cara en S y SW y la piel verde es muy pálida; a 75 px es un
  bulto marrón. No bloquea la prueba, pero si se regenera: pelo corto o recogido y piel verde más saturada
  (`goblin_referencia.png` la tiene así).

## 5. Orden sugerido

1. Retirar `flores`, `caja_cristal`; sustituir `puesto` → `puesto_mercado` y `seto_seco` → `arbusto_otono`
   (cambios en `prueba_test2.gd`, sin Meshy).
2. Regenerar `cartel`, `baldosa_guardado`, `pasadero` (son los que cambian la lectura de la prueba:
   guardado, cruzar agua, cámaras).
3. Regenerar `arbusto`, `arbusto_flores`, `tocon`, `seto_seco`, `matas` (estética).
4. `remolino_viento` y `llama` en vfx.
5. Oscurecer suelo y subir luz.
