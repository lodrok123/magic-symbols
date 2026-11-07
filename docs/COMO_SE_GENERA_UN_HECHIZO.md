# Cómo se genera un hechizo en Magic Symbols (y cómo se le hace el VFX)

Contexto para empezar en frío (escrito el 7/11/2026). Resume la cadena entera, de lo que dibuja la jugadora a lo que se ve en pantalla, y dice en qué archivo vive cada pieza. Lo que no esté aquí, está en `docs/DIARIO.md` (entradas numeradas, lo último al final) y en `docs/ESPEC_HECHIZO.md`.

## La idea de la que sale todo

**No hay recetas escritas a mano.** No existe una tabla que diga «línea + tierra = púas». Un hechizo es **un elemento más unos glifos**, y de ahí salen por cálculo sus propiedades físicas (tamaño, solidez, velocidad, estado de la materia, empuje…). Lo que ocurre en el juego se decide mirando esas propiedades, no el nombre del hechizo.

De ahí la frase que se repite en el código: **la lógica decide, el VFX representa**. Si un efecto se ve de una manera, es porque la lógica ya dijo que es un haz, un muro o un proyectil; el dibujo nunca inventa.

Añadir un elemento o un glifo nuevo debería ser **solo datos**: una runa `.tres` o una fila en la tabla de glifos.

## La cadena, paso a paso

1. **Dibujo.** La jugadora dibuja glifos en una página del grimorio. El reconocedor ($P) los identifica. Reglas del libro: un glifo por sector y una receta por página.
2. **Receta.** Los glifos de la página se juntan en una `Receta3D` (`Lanzador3D.Receta3D`, hereda de `SpellRecipe`): el multiconjunto de glifos (`contadores`), su **orden de dibujo** (`orden`), la calidad del trazo y la runa del elemento.
3. **Construcción.** `Hechizo.construir(runa, contadores, calidad, permitir_cinematico, orden)` devuelve un `Hechizo`: **datos puros, sin nodos**. Se construye UNA sola vez por lanzamiento (`Lanzador3D._preparar_pagina` lo guarda en `_preparado`); la previsión, el coste, la recarga y el disparo leen ese mismo objeto.
4. **Lanzamiento.** `Lanzador3D.lanzar_ahora(...)` cobra la tinta y la recarga y llama a `lanzar_hechizo`, que crea un `HechizoVivo`.
5. **Ejecución.** `HechizoVivo.crear(hechizo, origen, dir, lanzador)` lo materializa en el mundo y lo deja vivir hasta que cumple todos sus plazos.
6. **Dibujo del efecto.** El lanzador emite señales (`hechizo_v2` y las del proyectil) y el VFX las escucha. Hoy conviven dos dibujantes: los **toys** procedurales (`VfxToyJuego`) y el dibujo antiguo (`VfxElemento3D`), y un ajuste decide cuál habla por cada elemento.

## 3. El `Hechizo`: orden de construcción

`nucleo/hechizo.gd` (`class_name Hechizo`, un `RefCounted`). Se construye **en un orden fijo**, y ese orden importa:

1. **Defectos**: los valores de los `var` de la clase.
2. **Elemento**: los campos de su `RuneData` más su diccionario `modificadores` (duraciones de estado, fuerza del golpe, temperatura, conductividad…).
3. **Glifos** (`Sigils.GLIFOS`): primero las fijas y las sumas, después las multiplicaciones.
4. **Topes y suelos** (`_limitar`): los límites globales de la especificación.
5. **Derivados** (`_derivar`): forma, niveles, coste, recarga, cast point. **No se tocan a mano.**

Un modificador es una fila de datos: `{campo, op, valor, tope, desde}`.

Además, el **orden de dibujo** puede encender cosas (`_aplicar_orden`, tabla `ORDEN_PARES`): si ᛇ flecha va dibujada **antes** que ᚠ repetición, el hechizo es **ráfaga** (las copias salen en fila, una cada 0,12 s, en vez de en abanico); si ᛝ barrera va antes que ᚷ pulso, la barrera **late**. Lo que cambia un par queda apuntado al glifo que lo completa, para que el grimorio sepa a quién atribuirlo.

Cada campo recuerda **de dónde viene** (`origen`: defecto, elemento, `glifo:<nombre>`, calidad, derivado, lab). De ahí sale lo que el libro enseña al añadir un glifo (`diferencia()` / `texto_cambio`).

## 4. Las piezas: elementos y glifos

**Elementos** (runas en `nucleo/*.tres`): fuego, agua, hielo, rayo, tierra, viento, magma, naturaleza y tiempo. Cada uno trae su estado de materia (`solido`, `liquido`, `plasma`, `energia`, `gas`, `campo`), su daño, su empuje (`fuerza_golpe`: la tierra es la más alta, 2200) y lo que deja en el suelo (`deja`).

**Glifos** (`Sigils.GLIFOS`, el catálogo cerrado): `linea_x`, `linea_z`, `altura`, `flecha`, `barrera`, `repeticion`, `rebote`, `pulso`, `permanencia`, `raido`, `perforar`, `retorno`, `buscar`, `retardo`. Los de eje suman con **rendimiento decreciente** (el primero suma más que el siguiente).

## 5. Los derivados que deciden la FORMA

Esto es lo que hay que mirar para entender por qué un hechizo sale como sale. Todos viven en `Hechizo`:

| Derivado | Qué significa |
|---|---|
| `haz` | ᛁ línea sin barrera ni flecha: un chorro recto desde la mano, **instantáneo**, que golpea todo el recorrido y se para en lo sólido. Un sólido NO hace haz… salvo los de `SOLIDOS_CON_HAZ` (hoy la tierra: su ᛁ es el haz de púas que empuja). |
| `viaja` / `proyectil` | tiene alcance y velocidad: ᛇ flecha. |
| `volumen_viaja` | volumen con solidez + flecha: se desplaza el volumen entero, no una bola. |
| `orbita` | ᛃ retorno + ᚠ repetición sin flecha: las copias dan vueltas al lanzador. |
| `solido_quieto` | elemento sólido que no es haz ni viaja: nace donde apuntas. |
| `en_punto` | nace en la casilla apuntada en vez de en la jugadora. |
| `persistente` | se queda (solidez, permanencia o elemento sólido). Un haz no se queda. |
| `estalla` | líquido que ha crecido: explota al acabar. |

**Las cinco reglas generales** (R1–R5, decisión de Pablo del 3/11; las mide `herramientas/prueba_reglas_glifos.gd`): ᛇ sobre algo con forma hace que **la forma viaje**; ᛃ sobre lo que viaja añade la **vuelta**; ᛃ sin flecha y con ᚠ hace que las copias **orbiten**; ᛚ altura + ᚷ pulso **crece de abajo arriba y eleva** lo que haya dentro; ᚷ **golpea al crecer** y el agua que crece **estalla**.

## 6. El `HechizoVivo`: lo que de verdad pasa

`magia/hechizo_vivo.gd`. Ejecuta la definición y **guarda el estado en marcha** (el camino, a quién ya golpeó, lo que le queda por hacer). `_materializar` reparte por tres caminos:

- `_materializar_orbita` si orbita,
- `_materializar_haz` si es haz: calcula el recorrido, lo corta en lo sólido (ᚦ `perfora` atraviesa), **golpea una vez a cada cosa del camino**, marca el suelo con lo que deja el elemento y avisa al dibujo; todo en el mismo fotograma,
- el camino normal si no: rasteriza el volumen en casillas, lo llena según el estado de la materia, levanta solidez si hay barrera, y programa sus eventos (viaje, rebote, persistencia, eco, extinción).

Lo que deja en el mundo (zonas, solideces, tierra levantada, agua) **tiene vida propia** y sobrevive al `HechizoVivo`, que se borra solo cuando cumple sus plazos.

Para golpear a algo, ese algo implementa el contrato `on_spell_hit(rune_data, direccion, hechizo)`; hay variantes opcionales (`spell_reacts`, `spell_passes_through`, `spell_flies_over`, `carried_element`).

## 7. El dibujo

- **Toys procedurales** (`presentacion/vfx/toy/`): un toy por elemento (FuegoToy, AguaToy, HieloToy, RayoToy, MagmaToy, VientoToy, TierraToy) con la MISMA API: cinco figuras (BOLA, MURO, PILAR, BARRERA, HAZ), `definir(figura, x, y, z, vuela)`, `desde_hechizo(h)` y un ciclo de vida (`empezar_carga`, `soltar`, `impactar_en`, `finalizar`). Los impactos son clases hermanas (`ImpactoXToy`) con variantes GOLPE / FIN / REBOTE / ÁREA.
- **El enganche al juego** es `presentacion/vfx_toy_juego.gd` (`VfxToyJuego`): escucha las señales del lanzador y crea el toy que toque. El ajuste `magic_symbols/vfx_procedural` lo enciende y `vfx_procedural_elementos` dice para qué elementos (hoy fuego, agua, rayo, magma, viento y tierra; el hielo sigue con el dibujo antiguo).
- **El dibujo antiguo** es `VfxElemento3D`: se calla para los elementos que ya tienen toy.

**Reglas de rendimiento de este proyecto** (GPU integrada): los toys usan **MultiMesh por CPU**, **nada de `GPUParticles3D`**, y **una luz como mucho** por hechizo.

## 7 bis. Cómo se hace un VFX aquí

Esta es la parte práctica: qué hay que escribir para que un elemento tenga efecto, y con qué se juzga.

### El contrato, de abajo arriba

Son tres capas, cada una sobre la anterior:

1. **`EfectoVfx3D`** (`presentacion/vfx/efectos/efecto_vfx_3d.gd`): el contrato mínimo de cualquier efecto. `preparar(volumen, dir, elemento)` lo escala al hechizo, `lanzar(vida)` lo pone en marcha, `morir()` lo apaga, `impactar()` para los proyectiles. La escena lleva el dibujo y un `AnimationPlayer` con **«nacer», «vivir» (en bucle) y «morir»**.
2. **`EfectoToy`** (`presentacion/vfx/toy/`): añade los **diez mandos** que más cambian el aspecto, en castellano y con rango, para tocarlos en el inspector sin abrir código: altura, chisporroteo, blandura, ondulación, velocidad, brillo, halo, tono, chispas y luz. Cada instancia **duplica sus materiales al nacer**, así que mover un mando en una no toca a las demás. Fuera de los diez: `vida` y `aparicion` (0 apagado, 1 pleno; lo animan «nacer» y «morir»).
3. **El toy del elemento** (`FuegoToy`, `AguaToy`, `HieloToy`, `RayoToy`, `MagmaToy`, `VientoToy`, `TierraToy`): la geometría se **construye por código** a partir de la figura y los tres semiejes, no se monta en el editor.

### La API que todos comparten

```gdscript
definir(figura, x, y, z, vuela)   # figura + semiejes en METROS; la geometría se rehace sola
desde_hechizo(h)                  # lee el Hechizo y rellena figura, tamaños y vuelo
preparar(volumen, dir, elemento)  # lo que manda el lanzador por señal
lanzar(vida)                      # vida ≤ 0 = la suya
```

Y el ciclo de un lanzamiento: `empezar_carga(duracion)` → `progreso_carga()` → `soltar(dir)` o `cancelar_carga()` → en el mundo, `impactar_en(pos, normal)`, `rebotar(...)`, `terminar_sin_choque()` → `finalizar(motivo)`.

**Cinco figuras**, iguales para todos: `BOLA`, `MURO`, `PILAR`, `BARRERA`, `HAZ`. Los impactos son clases hermanas (`ImpactoXToy`) con variantes `GOLPE`, `FIN`, `REBOTE` y `AREA`.

**El origen importa**: la bola va por su centro; muro, pilar y barrera, apoyados en el suelo y centrados; el haz sale de la mano hacia −Z. Un muro se alarga por su X local.

### Las reglas que no se saltan

- **GPU integrada**: los toys dibujan con **MultiMesh por CPU**. **Nada de `GPUParticles3D`**. **Una luz como mucho** por hechizo. Hay pruebas que lo miden y fallan si te pasas.
- **El color sale de la paleta del mundo**, no de un color bonito suelto: la tierra usa la piedra del mapa, el polvo el pardo del suelo del Bosque. Y se juzga **sobre el suelo real del nivel**, no sobre el gris del laboratorio: un color que funciona en el lab puede cantar en el Bosque.
- **Toon**: color plano, borde duro, sin degradados realistas. De una referencia se toma **la forma y la secuencia, no el estilo**.
- **La lógica manda**: el toy no decide si hay daño, ni dónde llega; eso ya lo dijo el `Hechizo`. Si hace falta cambiar lo que pasa, se cambia la lógica, no el dibujo.
- Nada aparece de golpe: todo tiene su **nacer**. Y ojo con que la vida del dibujo sea más corta que su nacer, porque entonces se muere a medio salir.

### Cómo se engancha al juego

`presentacion/vfx_toy_juego.gd` (`VfxToyJuego`) escucha las señales del lanzador y crea el toy que toque:

- `_nuevo(elemento)` elige la clase, `_en_hechizo` / `_haz` montan la figura según lo que diga el `Hechizo`,
- el ajuste `magic_symbols/vfx_procedural` lo enciende y `vfx_procedural_elementos` dice para qué elementos,
- el dibujo antiguo (`VfxElemento3D`) se calla para esos elementos.

Para **añadir un elemento**: una clase toy nueva con la misma API, su entrada en `_nuevo`, y meterlo en la lista del ajuste.

### Cómo se comprueba

Un VFX **no se da por bueno porque pase una prueba**: se mira. Pero las pruebas sí guardan lo que se puede medir.

- **Pruebas** (`herramientas/prueba_vfx_toy.gd`, `prueba_viento_tierra_toy.gd`, `prueba_magma_toy.gd`, `prueba_vfx_en_juego.gd`, `prueba_lab_vfx_toys.gd`): que la API esté, que el presupuesto se cumpla (luces, partículas, vértices), que los tiempos del ciclo salgan, que el estilo no se rompa (sin `blend_add`, sin emisión donde no toca, borde duro).
- **Capturas** (`herramientas/captura_*.gd`): **necesitan ventana**, o sea sin `--headless`. Escriben PNG en `docs/capturas/` y están para mirarlas. Las del juego (`captura_toys_nuevos_juego.gd`) sacan el efecto en el Bosque a varios tiempos; el número del nombre son centésimas de segundo.
- **Laboratorios**: el de la comparativa (`LabVfxComparativa3D`, F6) tiene los siete elementos, los diez mandos en vivo y la tecla 4, que los pone **todos a la vez con la misma figura** para compararlos de un vistazo. El de hechizos (F4) tiene la matriz de aprobación.
- **No se hacen laboratorios nuevos**: se amplían los que hay.

### Trampas que ya nos han mordido

- **Culling**: los MultiMesh de polvo y piedras son `top_level` y necesitan un `custom_aabb` grande. Con uno pequeño alrededor del origen del mundo, el efecto **desaparece entero** lejos del origen: en el laboratorio se ve y en el juego no.
- **Normales**: al construir una malla a mano, calcular la normal sin mirar hacia qué lado cae deja caras **negras** bajo el sol.
- **Transparencias**: una máscara de textura puede venir con el fondo transparente en vez de blanco; leer solo el canal rojo la saca invertida.
- **Decal de suelo**: hay uno en `decal_suelo.gdshader` que proyecta sobre el relieve (lo que un quad tumbado no sabe hacer). Su caja tiene que ser de 1×1×1 **con el tamaño en la escala del nodo**, porque la prueba de «¿está dentro?» es contra ±0,5 en coordenadas locales.

## 8. Dónde está cada cosa

| Archivo | Qué es |
|---|---|
| `nucleo/hechizo.gd` | la definición y toda la construcción |
| `nucleo/sigils.gd` | el catálogo de glifos y la geometría que sale de ellos |
| `nucleo/*_rune.tres` | los elementos |
| `nucleo/dano.gd` | daño y tinta (coste) |
| `magia/lanzador_3d.gd` | grimorio, páginas, preparación, cobro, señales, servicios del mundo |
| `magia/hechizo_vivo.gd` | la ejecución |
| `presentacion/vfx_toy_juego.gd` | qué toy se crea para qué hechizo |
| `presentacion/vfx/efectos/efecto_vfx_3d.gd` | el contrato mínimo de un efecto (preparar / lanzar / morir) |
| `presentacion/vfx/toy/*.gd` | los toys, sus impactos y sus shaders |
| `laboratorios/lab_hechizos_3d.gd` | el laboratorio de hechizos (F1 receta, F4 matriz de VFX) |
| `laboratorios/lab_vfx_comparativa_3d.gd` | el laboratorio de VFX (tecla 4: los siete elementos a la vez) |

## 9. Cómo se trabaja aquí

- **Las pruebas son de verdad.** Están en `herramientas/prueba_*.gd` y `escenario_*.gd`, y cada una lleva **en su cabecera el comando exacto** con el que hay que lanzarla. Cópialo tal cual: algunas van con `--fixed-fps 30` y otras no, y lanzarlas mal **inventa fallos**. Se buscan las líneas `FALLO` y el `FALLOS: N` final.
  ```
  & "E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe" --headless --path E:\magic-symbols --script res://herramientas/<prueba>.gd
  ```
- **No se afloja una comprobación para que pase.** Si una prueba falla por un cambio deliberado, se discute el umbral y se deja escrito por qué cambia.
- **Nada de laboratorios nuevos**: se amplían los que hay.
- En esta máquina **bash está roto**: se usa PowerShell.
- Todo cambio con su entrada en `docs/DIARIO.md`, numerada, diciendo también lo que NO se ha hecho o no se ha comprobado.
