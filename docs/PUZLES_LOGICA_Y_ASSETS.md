# Puzles de Magic Symbols

Las ubicaciones de las variantes son propuestas. El pantano requiere su propio mapa. Antes de situar un puzle, comprobar que la jugadora ya dispone de sus sellos y glifos y que los objetivos se ven desde la cámara del juego.

## Lógica de montaje

| Puzle | Condición y resultado | Piezas que se reutilizan |
|---|---|---|
| **P01 · Balanza del claro** | Las dos placas alcanzan su peso mínimo y aparece el cofre. Ya está en Bosque 02. | Dos `pulsador modo=presencia peso=…`, rocas empujables y cofre. |
| **P02 · Molino** | Agua en el pulsador abre la entrada del caudal. Fuego rompe la cuerda del desvío y permite que el agua llegue a la rueda. Al girar, abre la reja del atajo. Ya está en Bosque 02. | Pulsador de agua, cuerda, compuertas, manantial, canal, molino y reja. |
| **P03 · Cornisa partida** | El escalón de Tierra permite subir al rellano seco. El hueco de apoyo tiene que admitir una plataforma y quedar al alcance de la subida. | Plataforma de Tierra y cofre normal en el rellano. |
| **P04 · Veta interrumpida** | El bloque de enlace completa la veta. El receptor se activa con Rayo + Pulso y abre la reja. Colocar el inicio de la veta donde alcance un pulso y comprobar que el disparo directo al receptor no evita el enlace. | Veta con `enlaces=`, bloque de piedra, `receptor elemento=rayo`, reja y flag. |
| **P05 · Galería del dragón** | Cruzar al refugio durante el apagado por Agua o Hielo. También se puede interponer una barrera si la galería deja espacio para colocarla. | `trampa_dragon`, ciclos de aviso y disparo, apagado elemental y colisión del hechizo con cobertura. |
| **P06 · Vado helado** | Congelar el agua y llegar al islote seco antes del deshielo. Repetir en el segundo tramo. | Hielo transitable sobre agua, orillas e islote. Verificar ambos tramos a pie con el tiempo real del hielo. |
| **P07 · Jardín dormido** | Regar y aplicar Naturaleza a cada bancal, en cualquier orden. El último abre el vivero. Los bancales germinados se recuerdan entre visitas. | Nueva pieza `bancal`, reacción de suelo existente, puerta y flags. |
| **P08 · Paso de la colmena** | Viento o Fuego despejan la nube del paso. Viento sobre la colmena suelta el panal. Quemar la colmena la consume, así que el panal debe ser un premio opcional. | `nube_veneno`, `colmena` y botín de panal. Separar la nube de la colmena para que un lanzamiento hacia la nube no alcance también la colmena. |
| **P09 · Tiro de esquina** | Un proyectil con Flecha + Rebote llega a un pulsador oculto tras un saliente. El pulsador abre un cofre o una reja. | Pared sólida, `pulsador modo=magia`, previsión del recorrido y cofre. Comprobar que existe un tiro de rebote y que la pared impide el tiro directo desde la zona accesible. |

### Plantilla de mapa para P07

Cada bancal ocupa una casilla de tierra o arena desnuda y tiene su propia flag. Las coordenadas son de ejemplo. Usa suelo seco sin hierba de partida y deja la casilla libre de colisión para que reciba los impactos de Agua y Naturaleza.

```text
; material 2 4 tierra
; material 3 4 tierra
; material 4 4 tierra
; pieza bancal_a bancal 2 4 flag=pantano.jardin.a
; pieza bancal_b bancal 3 4 flag=pantano.jardin.b
; pieza bancal_c bancal 4 4 flag=pantano.jardin.c
; pieza vivero puerta 5 4 modelo=reja
; puzle fin_a cuando=bancal_a.germino si=bancal_b.germinado+bancal_c.germinado hace=flag.poner(pantano.jardin.abierto)
; puzle fin_b cuando=bancal_b.germino si=bancal_a.germinado+bancal_c.germinado hace=flag.poner(pantano.jardin.abierto)
; puzle fin_c cuando=bancal_c.germino si=bancal_a.germinado+bancal_b.germinado hace=flag.poner(pantano.jardin.abierto)
; puzle abrir_vivero cuando=flag.pantano.jardin.abierto hace=vivero.abrir
```

## Lista de assets para generar

| Prioridad | Asset | Puzle y entrega |
|---|---|---|
| **Primera tanda** | **Borde de bancal de piedra y madera** | **P07.** Un módulo que enmarque una casilla. Centro abierto, bajo y sin colisión sobre la tierra, con los bordes visibles cuando el suelo se moja o crece hierba. Repetir el mismo módulo en los tres bancales. |
| **Primera tanda** | **Brote de referencia del vivero** | **P07.** Un brote decorativo con silueta legible desde la cámara. Colocarlo junto al canal como pista. Los bancales germinados reutilizan la hierba y los VFX existentes. |
| **Primera tanda** | **Huella de peldaño roto** | **P03.** Marca a ras de suelo o pieza muy baja que encaje con la escalera de piedra. Debe quedar libre la casilla donde se crea la plataforma. |
| **Primera tanda** | **Grabado de rayo para receptor** | **P04.** Variante del engaste o decal sobre el receptor rúnico. La silueta de rayo debe leerse con el receptor apagado. Reutilizar el modelo y el brillo actuales. |
| **Primera tanda** | **Marca de hollín para galería** | **P05.** Decal de borde quemado que delimite el tramo expuesto al chorro. Reutilizar el mascarón del dragón, la piedra de cueva y el VFX del fuego. |
| **Tras probar la sala** | **Pista para tiro de rebote** | **P09.** Decal para diferenciar el paño de pared útil y variante de la losa rúnica existente para marcar el punto de tiro. Ajustar la pista a la trayectoria validada en juego. |
| **Acabado** | **Grabados de una y dos muescas** | **P01.** Variantes de la misma textura o dos decals sobre la placa actual. Deben leerse con la placa arriba y hundida. |
| **Acabado** | **Raíces o postes de orilla** | **P06 y P08.** Kit común de marcas de sendero para destacar un islote seguro o encuadrar el acceso a la colmena. Reutilizar raíces y postes existentes si la silueta funciona. |

P02 se puede montar con sus piezas actuales. P08 ya tiene modelo de colmena, icono de panal y VFX de veneno. P06 usa el hielo transitable del juego.
