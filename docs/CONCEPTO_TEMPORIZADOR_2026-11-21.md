# Concepto: el temporizador (21/11/2026)

21/11/2026 · contexto **dirección (análisis)** · **concepto para decidir, nada construido**.

**De dónde sale.** El puzle X7 (`PUZLES_DEMO_TRES_SELLOS_2026-11-20.md` §3, visto en Mages of Mystralia, `MAGES_OF_MYSTRALIA_2026-11-21.md` O13): encender un brasero apaga un chorro **durante un tiempo**, y hay que cruzar antes de que vuelva. Pablo confirmó la lectura y pidió el concepto: «el brasero es el disparador que hace que el haz deba estar activo con un timer. Crea el concepto del timer, que puede venir bien».

**La idea en una frase:** un **disparador** cambia algo **durante N segundos**; el tiempo que queda **se ve en el mundo** y **avisa antes de acabar**; al acabar, todo vuelve a como estaba.

---

## 1. Lo que ya existe (temporizadores sueltos)

Hoy cada pieza lleva su propio reloj, sin una forma común de enseñarlo:

| Dónde | Qué cuenta | Se ve el tiempo | Archivo |
|---|---|---|---|
| Brasero con relé | Enciende al siguiente a los 1,5 s y se apaga a los 6 s (`espera`, `dura`) | No | `objetos/objetos_3d.gd:225-229`, `:1286` |
| Pulsador con rearme | Vuelve a su sitio a los `rearme` s | No | `escenas/puzle.gd:446`, `:2107` |
| Lava | Vuelve a ser lava a los `vuelve` s | No | `escenas/puzle.gd:468` |
| Trampa de pared apagada | Agua o hielo la apagan 8 s; una regla, los segundos que diga (`apagar(s)`) | No | `objetos/trampa_pared_3d.gd:24`, `:241` |
| Receptor con rearme | Se reactiva a los `rearme` s | No | `escenas/puzle.gd:492` |
| Bloque de tierra | Dura 25 s y **parpadea sus últimos 3 s** | **Sí, el final** | `magia/lanzador_3d.gd:97-99` (`AVISO_CADUCA`) |
| Estados del suelo | Mojado, helado… caducan con su reloj | Poco | `mundo/estados_suelo_3d.gd` |

**Lo que falta:** que el jugador **vea cuánto queda** y que **todas las piezas lo enseñen igual**. El parpadeo final de la tierra es la única convención que ya existe; el concepto la generaliza.

---

## 2. Las reglas del temporizador

1. **El tiempo se ve en el objeto que lo dispara**, no en la interfaz. En X7, la llama del brasero se va encogiendo; en un pulsador, un aro de runas alrededor que se va apagando por tramos.
2. **Avisa antes de acabar.** El último tramo (proponer **0,8 s**, o el 25 % si es corto) parpadea y suena un tic que se acelera. Es la misma idea que el parpadeo de la tierra.
3. **Dura lo que cuesta llegar, más un margen.** `dura ≥ distancia ÷ velocidad corriendo + 0,5 s`. Con la carrera de la maqueta (3,0 u/s) y casillas de 2,3 u: cruzar 1 casilla ≈ 0,8 s, 3 casillas ≈ 2,3 s. **Mystralia da ~2,4 s** para cruzar un chorro de una casilla: generoso a propósito.
4. **Se puede volver a disparar.** Re-encender reinicia la cuenta. Si el disparador también se alcanza desde el otro lado, no hay forma de quedarse atrapada.
5. **No mata.** Si el peligro vuelve con la jugadora dentro, hace su daño normal y la empuja fuera, no la deja encerrada.
6. **Va con el tiempo del juego.** Con el libro abierto (tiempo al 30 %) o en tiempo bruja, el temporizador también se ralentiza: no se gana tiempo abriendo el libro.
7. **Se encadena.** Dos temporizadores solapados crean puzles de ritmo (el relé de braseros ya lo hace a su manera).

---

## 3. Cómo se escribiría en el mapa (propuesta)

**Opción A · Reutilizar lo que hay (mínimo):** la duración va en la acción que ya admite segundos, y la pieza disparadora enseña la cuenta:

```
; pieza br_x7 brasero 4 6 dura=2.5
; pieza tr_x7 trampa_dragon 7 3 mira=s ciclo=99,0
; puzle x7 cuando=br_x7.encendido hace=tr_x7.apagar(2.5)
```

Lo nuevo sería solo que el brasero con `dura=` **enseñe su cuenta atrás** (llama que se encoge y parpadeo final) y que la trampa apagada **avise antes de volver**.

**Opción B · Una pieza `temporizador` (general):** una pieza lógica, como `vigia` o `contador`, que no se ve por sí misma y enseña su cuenta en otra pieza:

```
; pieza t_x7 temporizador 4 6 dura=2.5 aviso=0.8 reinicia=si muestra=br_x7
; puzle x7a cuando=br_x7.encendido hace=t_x7.empezar
; puzle x7b cuando=t_x7.empieza hace=tr_x7.apagar
; puzle x7c cuando=t_x7.acaba hace=tr_x7.encender y=br_x7.apagar
```

Señales: `empieza`, `aviso` (entra en el último tramo) y `acaba`. Acciones: `empezar`, `parar`. Sirve para cualquier cosa: puertas que se cierran, puentes que se pliegan, plataformas que se hunden.

**Recomendación:** empezar por la **A** (X7 sale casi gratis) y pasar a la **B** cuando haya un segundo puzle que la pida.

---

## 4. La cuenta atrás visible (una sola pieza de dibujo para todos)

Un componente común, `CuentaAtras3D`, que cualquier pieza con duración puede llevar:
- **Forma:** un aro de runas en el suelo alrededor del disparador, dividido en tramos que se apagan uno a uno; o, si la pieza tiene llama o brillo propio (brasero, receptor), ese brillo que se encoge.
- **Último tramo:** parpadeo con el ritmo de `AVISO_CADUCA` y un tic que se acelera.
- **Al acabar:** un «clac» y un destello corto en lo que vuelve (la trampa que se enciende), para que se entienda la causa.
- **Lo usarían:** brasero con `dura`, pulsador con `rearme`, trampa apagada, lava que vuelve, receptor con `rearme` y el bloque de tierra (que ya parpadea).

---

## 5. Puzles que lo usan

| Puzle | Disparador | Qué dura | Archivo |
|---|---|---|---|
| **X7 · El brasero tras el chorro** | Brasero encendido a través del chorro | La trampa apagada ~2,5 s | `PUZLES_DEMO_TRES_SELLOS_2026-11-20.md` §3 |
| T3 · El foso | Plataforma de tierra ᛒ | 8 s de plataforma | ídem |
| T1b · Retener | Presa de tierra | 25 s de presa | ídem |
| Puzles de fuego con botón | Pulsador | 8 s de trampas apagadas | `mundo/datos_nivel/mapas/PuzlesFuego.txt:108`, `:140` |

Con la cuenta visible, los cuatro se leen igual: «tengo X segundos».

## 6. Preguntas para Pablo

1. ¿**A** (reutilizar, mínimo) o **B** (pieza `temporizador` general) para empezar?
2. ¿La cuenta se enseña en el **disparador** (el brasero) o en **lo que cambia** (la trampa)? Mystralia la enseña en el disparador: el brasero sigue encendido mientras dura.
3. ¿Último tramo de **0,8 s** fijo, o proporcional a la duración?
