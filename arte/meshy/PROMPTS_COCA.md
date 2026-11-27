# La Coca de Redondela (27 de noviembre de 2026)

Jefe de la Cueva del Lago Termal (DC-04 de `docs/INVENTARIO_MONTE_SUMICIO.md`). Serpiente de agua. Para la historia es la
**amiga de la Moura viajera**, encantada en forma de serpiente: no muere, se calma.

**Elementos disponibles en esa parte: fuego, agua y tierra.** Ni rayo ni hielo.

## 0. Diseño

**Aspecto (Pablo, 27/11: «es un monstruo, tiene que aparecer aterradora y es un jefe»):** la lámina
`arte/meshy/referencias/coca_concepto_v1.webp`. Serpiente de agua enorme, turquesa con el vientre crema, escamas grandes como
hojas, cresta dura de púas, ceño marcado y ojo ámbar de pupila vertical. Durante el combate no hay nada amable en ella.
Las únicas pistas de quién es son **la anilla dorada en un barbillón**, igual que las del pelo de la Moura, y la runa.
El cambio llega solo al final: en `calma` baja la cresta y la pupila se redondea.

**La runa: ᛃ Jera, en la frente.** La jugadora ya la conoce como «Vuelve» (el glifo de retorno); en el futhark es el ciclo, lo
que regresa. Dos mitades que giran una sobre otra sin tocarse: serpiente y persona. Apagada mientras está en el agua; se
enciende cuando queda en seco, y es su único punto débil. Al vencerla la runa da media vuelta y ella se calma.
(Interpretación de «compatible con la transformación»: sirve para el momento en que vuelve a su forma. Alternativa si el
encantamiento es una maldición: ᛈ Perthro.)

**Combate:**
- **En el agua es invulnerable.** El agua le resbala y el fuego se hace vapor en las escamas mojadas (golpe sordo, C20).
- **Emerge por pozas** del lago, de una en una; entre ataques se hunde y cambia de poza.
- **Ataques, con aviso:** chorro a presión que empuja en línea, y coletazo que barre la orilla.
- **La ventana: dejarla en seco.** Varada, la runa se enciende unos 4 s y recibe daño de todo.
- **Evita la condición:** escupe agua sobre los bloques de tierra para deshacerlos (tierra + agua = barro), así que hay que
  tapar mientras ataca.
- **Tres soluciones, con fuego, agua y tierra:**
  1. **Tierra:** tapar las pozas con bloques hasta que emerja por la única que queda, que es un bajío: sale medio cuerpo
     fuera y queda varada.
  2. **Fuego:** las pozas pequeñas se secan con fuego sostenido (vapor, la reacción que ya existe). No la daña, pero una
     poza seca no la puede deshacer con barro. Si asoma por una poza que se está secando, queda varada.
  3. **Agua:** devolverle el chorro con la protección de agua (el reflejo de X10): el empuje la saca a la orilla. Si X10 no
     está hecho, esta tercera pasa a ser una compuerta de la sala que baja el nivel del lago un rato.
- **Fases:** con cada tercio de vida inunda una pasarela (agua honda) y hay una poza menos en seco.

**Qué reutiliza:** la mámoa del mouro (fuente que se tapa), agua honda, estados del suelo, el chorro de la trampa dragón,
avisos de ataque y presentación de jefe.

---

## 1. Imagen de concepto

**Ya hay lámina de estilo:** `arte/meshy/referencias/coca_concepto_v1.webp` (Pablo, 27/11). Vale para la cara, las escamas,
la cresta, la cola y la paleta. **No vale para generar el 3D:** enroscada, las vueltas se funden en un bloque. De ella se
sacan tres imágenes, una por pieza, con la lámina como referencia:

> Same creature, same style, same colours and same fierce face as the reference. ONLY the head and neck, perfectly
> STRAIGHT and VERTICAL like a column rising from the ground, side view, mouth closed, crest of hard teal spikes on the
> head, two whiskers with the small gold ring, empty cream oval patch on the forehead. The scales on the neck lie FLAT
> against the body (not raised), cream belly plates on the front. The neck ends in a flat cut at the bottom. Plain light
> background, soft even lighting.

> Same creature and style as the reference. ONLY one segment of the body, shaped as a single ARCH like a bridge, side
> view, big raised leaf-like teal scales on top, cream belly plates underneath, both ends cut flat at ground level. Plain
> light background.

> Same creature and style as the reference. ONLY the tail, straight and vertical, ending in the wide spiked teal fan fin,
> base cut flat. Plain light background.

**Si sale mal:**
- **Cuello curvado o en S:** *"neck perfectly straight, a vertical column"* (se dobla por código; si viene doblado, el rig sale mal).
- **Escamas del cuello levantadas:** *"neck scales flat and smooth"* (levantadas se clavan unas en otras al doblar).
- **Dibuja una runa en la frente:** *"forehead patch plain and empty"* (la runa se pone en Godot).
- **Dragón con alas o patas:** *"a serpent only, no wings, no limbs"*.

## 2. Meshy, de imagen a 3D

Emerge del agua por tramos, así que **no hace falta el cuerpo entero riggeado**. Tres piezas:

> stylized fierce water serpent head and neck, straight vertical column, teal scales flat on the neck, cream belly, hard
> spiked crest, whiskers with a gold ring, amber slit eyes, closed mouth, game boss creature

> stylized water serpent body segment shaped as an arch, raised leaf-like teal scales on top, cream belly, both ends cut
> flat, single object

> stylized water serpent tail, straight, teal scales, a wide spiked teal fan fin at the end, base cut flat, single object

- Nombres: `coca_cabeza` (con rig de cuello: 5 o 6 huesos en cadena, para el chorro y el coletazo), `coca_arco` y `coca_cola`.
- Alto de la cabeza fuera del agua: unas 2,5 casillas.
- **La runa ᛃ** es una pieza emisiva aparte (`runa_coca`), plana, pegada al parche de la frente: se enciende, se apaga y gira.

## 3. Animaciones (cabeza)

| Rol | Qué |
|---|---|
| `emerge` / `hunde` | sale y entra en el agua en vertical |
| `idle` | balanceo lento del cuello |
| `chorro` | echa el cuello atrás (aviso) y lo lanza al frente con la boca abierta |
| `coletazo` | lo hace `coca_cola`: sale, barre la orilla y se hunde |
| `varada` | cabeza y cuello tendidos en la orilla, respirando; la runa encendida |
| `calma` | levanta la cabeza despacio y la inclina; baja la cresta y la pupila se redondea: el final del combate |

Se mueve por código, no con clips: cada fila es una pose de la curva del cuello (cadena de unos 8 huesos más mandíbula).
Para `calma` hacen falta además un hueso o forma para la cresta y la pupila como pieza o material aparte.
