# Tierra: referencias de Pablo (6/11/2026, pack «Spells Pack – Nature Update»)

Hojas de fotogramas en esta carpeta. Lo que define cada pieza, para TierraToy (`presentacion/vfx/toy/tierra_toy.gd`, `impacto_tierra_toy.gd`), sin GPUParticles3D ni luces.

## 1. LÍNEA (haz) = púas que brotan y desplazan (`puas_linea_hoja_12.png`)
Decisión de Pablo: «para línea, en vez de una línea tipo lanzallamas, usa unas puntas que desplazan». Grietas negras que corren por el suelo en abanico desde el lanzador; luego brotan púas cónicas y curvadas de tierra (estalagmitas pardas) en secuencia de la mano a la punta, de menor a mayor; las losas del suelo se levantan rotas en la base y saltan cascotes; las púas se quedan y luego se hunden, las grietas se desvanecen. El empuje ya lo hace la lógica (`fuerza_golpe` 2200 de la runa de tierra, el haz golpea todo el recorrido al nacer).

## 2. IMPACTO en el suelo (`impacto_barrera_hoja_a.png`, fila 1-2)
Anillo de tierra que se abre en el suelo (borde claro, interior oscuro con grietas), con 2-3 púas pequeñas que asoman y se retiran. Breve y a ras de suelo.

## 3. IMPACTO de rocas / estallido (`impacto_barrera_hoja_a.png`, fila 2-3)
Nube de polvo pardo clara con cascotes oscuros que salen en espiral y caen; polvo de dos tonos (el humo toon ya hecho) con la nube más clara en el centro. Es el impacto grande (área).

## 4. BARRERA / cúpula (`impacto_barrera_hoja_b.png`)
Anillo de piedras que gira a ras de suelo como aviso; luego las rocas CAEN del cielo o suben y se apilan formando una CÚPULA de cascotes con luz cálida dentro que se apaga; destello de polvo al cerrarse. También un tapiz de losas en rejilla (fila 2) para una superficie sólida ancha.

## OJO: el ESTILO del pack es realista y NO vale (Pablo, 6/11). Lo que se toma es la FORMA DE HACERLO (secuencia, piezas, tiempos): grietas → púas en secuencia → losas → hundirse; anillo → púas que asoman; aviso de piedras girando → cúpula. El dibujo va en el estilo del juego: toon, formas planas y facetadas, dos tonos, polvo del humo toon, sin texturas fotográficas ni humo volumétrico.

## Paleta
Pardo tierra del suelo del bosque (polvo y púas), piedra gris del mundo para rocas (`roca_est_*`, `piedra_est_*`). Sin amarillo salvo el brillo breve interior de la cúpula, muy atenuado.