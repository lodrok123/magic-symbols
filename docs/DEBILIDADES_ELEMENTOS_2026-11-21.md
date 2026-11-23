# Puntos débiles de los cuatro elementos y propuestas (21/11/2026)

21/11/2026 · contexto JUEGO · **propuesta para revisar, no hay nada construido**.

**Fuentes:** `enemigos/combate_3d.gd` (`decidir_golpe`, líneas 970-1078), `mundo/estados_suelo_3d.gd`, `PROPUESTAS_COMBATE_2026-11-06.md`,
`PUZLES_DEMO_TRES_SELLOS_2026-11-20.md`, `REVISIONES_PENDIENTES_2026-11-18.md` y el playtest del 14/11. He leído el código, pero no he jugado nada.
Tengo en cuenta el recorte del 18/11: la demo lleva **fuego, agua y tierra**. El viento sale al final, solo para el juego completo.

---

## 0. El hallazgo principal: en la demo casi no hay reacciones contra enemigos

He cruzado `decidir_golpe` con el kit de la demo. Casi todas las reacciones buenas dependen de **hielo o rayo**, y esas dos son reacciones de
sellos dobles que la demo no tiene:

| Reacción | Qué hace falta | ¿Existe en la demo? |
|---|---|---|
| Rayo sobre mojado ×1,5 y salto | rayo | **no** |
| Hielo sobre mojado ×1,5 | hielo | **no** |
| **Roto** ×2 (congelado + tierra o golpe F) | congelado, que pide hielo | **no** |
| Llamarada (viento sobre quemado) | viento | **no** |
| Raíces (naturaleza), magma | sellos dobles | **no** |
| Fuego sobre mojado = vapor (seca) | fuego + agua | sí, pero **solo anula**: no hace más daño |
| Agua sobre quemado = apaga y ciega | agua + fuego | sí, el único control real |
| Tierra = ralentiza | tierra | sí, sin combinar con nada |

**Conclusión:** en la demo, combinar elementos contra un enemigo no da ningún premio. El juego más rentable es echar el elemento que más pega
y repetirlo. Eso explica lo que salió en el playtest: «se pasó todo con fuego + flecha». No hace falta subir números. Lo que falta es un
**triángulo de reacciones propio de los tres sellos**, que reutilice las piezas que ya hay (`R_ROTO`, `X_ROTO`, `cegado`, `lento`).

---

## 1. Fuego

**Puntos débiles**
1. **Domina sin coste.** Es el primer sello, el que más se practica y el que pega fuerte, y en combate no tiene contrapartida: el fuego amigo
   (B7, aceptado el 6/11) no se nota con proyectiles.
2. **Su verbo de puzle está gastado.** Hay braseros en 6 niveles y Bosque 01 tiene tres seguidos (PUZLES_DEMO §2.1).
3. **Contra un enemigo mojado es peor que no hacer nada:** el vapor seca, anula el estado y no da daño extra.

**Propuestas**
| # | Propuesta | Referencia | Palanca |
|---|---|---|---|
| F-a | **Lo que arde se propaga y también te quema.** Un enemigo quemado que pasa por hierba la prende, y la hierba prendida quema a la jugadora. Así el fuego es potente pero se paga con dónde se usa. | *Divinity: Original Sin 2* (las superficies en llamas dañan a todos); *Breath of the Wild* (el fuego se propaga por la hierba y el viento lo empuja) | `EstadosSuelo3D` QUEMADA + hierba (`_hf`); pulso de zona B7 |
| F-b | **Corriente ascendente:** la hierba ardiendo crea una columna de aire caliente que levanta a la jugadora una altura. Le da al fuego un verbo de movimiento que no es «encender». | *Breath of the Wild* (corrientes térmicas sobre el fuego) | glifo altura ya existente + zona QUEMADA |
| F-c | **El vapor premia en vez de anular:** fuego sobre mojado deja una nube VAPOR (ya existe en el suelo, 4 s) que ciega a los enemigos de dentro. Así la pareja agua → fuego da control de grupo. | *Divinity: Original Sin 2* (la nube de vapor es una capa aparte del suelo) | `vapor` de `decidir_golpe` → escribir `VAPOR` en la casilla; `Combate3D._ve` ya lee el vapor (F14) |
| F-d | **Tope de 2 puzles de braseros por nivel** (ya propuesto el 20/11, falta decidirlo). | *Zelda: Echoes of Wisdom* (cada mazmorra usa un verbo distinto) | solo mapas |

## 2. Agua

**Puntos débiles**
1. **Su premio está fuera de la demo.** El agua prepara: moja para que el rayo o el hielo hagan ×1,5. Sin esos dos, mojar no lleva a nada,
   salvo a que el fuego después lo anule.
2. **Daño propio bajo y ningún efecto físico.** No empuja, y el muro de agua que debía mojar hacia delante está sin hacer (REVISIONES 18/11).
3. **Sin hielo se pierde el verbo «cortar o cruzar agua»** (Q3, Q4 y Gruta Permanencia se rompen).

**Propuestas**
| # | Propuesta | Referencia | Palanca |
|---|---|---|---|
| Q-a | **El chorro empuja.** La línea y el haz de agua echan para atrás a los enemigos y mueven bloques ligeros. Así vuelve el verbo «empujar desde lejos», que se perdió con el viento, y sustituye a T6 o lo complementa. | *Magicka* (el chorro de agua moja y derriba); *Splatoon* (el agua como herramienta de control del terreno) | `fuerza` del `Hechizo` de agua; `BloqueEmpujable3D` |
| Q-b | **Mojado + tierra = atascado:** un enemigo mojado al que le llega tierra se queda clavado 1,5 s, y el siguiente golpe lo derriba. Es un estado de enemigo, no un elemento, así que **no resucita el barro** (decidir). | *Divinity: Original Sin 2* (combinar superficies cambia el estado); *Genshin Impact* (el estado de un elemento cambia la reacción del siguiente) | rama `golpea` de `decidir_golpe` con `mojado > 0` |
| Q-c | **Mojado alarga lo que viene después:** quemado dura menos, ralentizado dura el doble. El agua pasa a ser un amplificador de la tierra dentro de la demo. | *Genshin Impact* (el agua amplifica otros elementos) | multiplicador en `lento` si `mojado > 0` |
| Q-d | **Puzles de caudal como sustituto del hielo:** la presa en seco (T1, ya hecha en el lab) y la balsa que sube con el nivel (Q16). | *Zelda: Ocarina of Time*, Templo del Agua (subir y bajar el nivel como llave de la mazmorra) | mapas |

## 3. Tierra

**Puntos débiles** (es el sello más pobre, según PUZLES_DEMO §2.2)
1. **En combate solo ralentiza**, y su única reacción (**roto**) pide congelado, que no hay en la demo.
2. **Su verbo propio, construir, no tiene puzles.** El ᛒ suelo entra en la demo y no lo enseña ningún puzle.
3. **No cuaja sobre el agua y no empuja.** En el Pantano, que es el bioma final, apenas tiene sitio.
4. **Arte sin revisar en el Bosque:** los estratos no casan con las rocas grises del mapa (REVISIONES 18/11).

**Propuestas**
| # | Propuesta | Referencia | Palanca |
|---|---|---|---|
| T-a | **Costra: fuego sobre un enemigo ralentizado (tierra) lo cuece y lo endurece.** El siguiente golpe de tierra o el golpe F es **roto** (×2). Recupera el remate en la demo sin hielo, con el aviso, el rótulo y el multiplicador que ya existen. | *Magicka* y *Divinity: Original Sin 2* (un estado abre un remate); es la regla B1 sin hielo | `roto` en `decidir_golpe`: aceptar «costra» además de `congelado`; `R_ROTO`, `X_ROTO` |
| T-b | **Tierra sobre quemado = sofocado:** apaga sin vapor y aturde 0,5 s. Le da una respuesta al fuego distinta de la del agua. | lógica física, como echar tierra a una hoguera; *Divinity* (unas superficies apagan otras) | rama `golpea` + `quemando > 0` |
| T-c | **Construir es la herramienta de mazmorra:** escalones (T2), puente ᛒ a ritmo (T3), muro contra trampas (T4). Que el laboratorio de tierra sea el siguiente. | *Zelda: Echoes of Wisdom* (colocar bloques para subir y cruzar es todo el sistema de puzles) | `LabPuzlesTierra3D` nuevo, según PUZLES_DEMO §6.5 |
| T-d | **Tierra en agua poco honda:** dejar que cuaje en casillas de agua por debajo de un umbral. Abre el Pantano a la tierra sin hielo. | *Echoes of Wisdom* (bloques que se apoyan en el fondo de agua poco profunda) | `puede_construir_en` con umbral de profundidad (PUZLES_DEMO T1, coste B) |
| T-e | **La flecha de tierra empuja bloques** (T6, decisión §7.5 pendiente). Si se hace Q-a, sobra una de las dos: hay que elegir cuál. | *Zelda: Oracle of Seasons* (empujar bloques a distancia) | retroceso de la flecha de tierra |

## 4. Viento (fuera de la demo)

**Puntos débiles**
1. **No hace daño de verdad:** interrumpe y empuja. Su valor está en lo que hace con otros elementos (hielo, rayo, llamarada).
2. **Sin la demo, es el elemento menos probado:** no tiene puzles en mapas reales y la Sala de Empuje E4 depende de él.
3. **Lo que tiene de único (empujar) lo pueden cubrir el agua (Q-a) o la tierra (T-e).** Si eso se hace, el viento se queda sin identidad propia.

**Propuestas** (para después de la demo)
| # | Propuesta | Referencia | Palanca |
|---|---|---|---|
| V-a | **El viento es movimiento de la jugadora:** voltereta larga o planeo corto con una página de viento. Así tiene un sitio que ningún otro elemento ocupa. | *Spellbreak* (el viento da movilidad); *Wind Waker* (planear con la Hoja Deku) | voltereta de `Jugador3D` (C6) |
| V-b | **El viento limpia y aspira:** quita los estados del suelo (B3) y absorbe nubes (veneno, vapor) para soltarlas en otro sitio. | *Minish Cap* (el Ánfora Mágica aspira y sopla); *Okami* (el Vendaval apaga el fuego y disipa la niebla) | `EstadosSuelo3D` + nube de veneno de los goblins |
| V-c | **Tumba a los enemigos voladores** y los deja en el suelo, donde sí reciben tierra. | *Okami* (el Vendaval derriba enemigos voladores) | murciélagos, nuevo estado «derribado» |

---

## 5. Orden que propongo

1. **Triángulo de la demo (todo en `decidir_golpe`, son tablas):** T-a costra/roto, F-c vapor que ciega, T-b sofocado y Q-b o Q-c.
   Con estas cuatro, cada pareja de los tres sellos tiene una reacción con premio. Es la respuesta más directa a «el combate es fácil».
2. **Feedback propio de reacción** (E2 del 6/11): sin él, el jugador no ve el triángulo.
3. **Tierra en puzles:** el laboratorio de tierra (T-c) y T-d.
4. **Fuego con coste:** F-a propagación y fuego amigo. Probarlo con cuidado, porque castiga.
5. Agua empuja (Q-a) **o** pedrada (T-e): elegir una.
6. Viento (V-a a V-c) cuando vuelva al juego.

## 6. Decisiones para Pablo

1. ¿El «atascado» de Q-b se puede usar como estado de enemigo, o se parece demasiado al barro descartado? Si se parece, mejor Q-c.
2. ¿Quién recupera el empuje a distancia: el agua (Q-a) o la flecha de tierra (T-e)?
3. ¿El fuego debe dañar a la jugadora al propagarse (F-a)? Encaja con B7, pero cambia mucho cómo se juega.
4. ¿El viento se queda como movilidad (V-a) cuando vuelva?
