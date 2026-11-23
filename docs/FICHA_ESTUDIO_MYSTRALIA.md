# Ficha de estudio: Mages of Mystralia (para rellenar jugando)

21/11/2026 · contexto **dirección (análisis)** · acompaña a `MAGES_OF_MYSTRALIA_2026-11-21.md`.

**Para qué sirve:** medir su juego desde fuera, con las mismas magnitudes que ajustas en el panel F3, y ponerlo al lado de nuestras cifras. Solo se observa jugando: no se abren ni se descompilan archivos del juego.

**Cómo se reparte el trabajo:**
- **Tú** juegas, grabas y apuntas lo que se ve a simple vista (columna «Mystralia»).
- **Yo** saco los tiempos de los vídeos fotograma a fotograma, relleno lo que falte y escribo el apartado «medido jugando» con las conclusiones.

La columna «Magic Symbols hoy» está sacada del código el 21/11/2026. Si algo cambia, se corrige aquí.

---

## 0. Antes de empezar

1. **Graba con la barra de juego de Windows**: `Win + Alt + R` empieza y para. Los vídeos van a `Vídeos\Capturas`. Ponla a 60 fps (Configuración → Juegos → Capturas).
2. **Juega con mando** y en la dificultad por defecto.
3. **Cuando veas algo que medir**, apunta el **minuto del vídeo** en la tabla. Con eso me basta para encontrarlo.
4. **No hace falta hacerlo todo**. Los bloques 3, 5, 6 y 8 son los que más valen; el resto, si sale.

**Cómo se mide un tiempo:** los vídeos van a 60 fotogramas por segundo, así que 6 fotogramas son 0,1 s. Basta con que me digas el minuto del vídeo y qué acción es.

---

## 1. Primera hora: cómo enseña

| Qué mirar | Mystralia | Para nosotros |
|---|---|---|
| Minutos hasta lanzar el primer hechizo | | Comparar con el arranque del Bosque |
| Minutos hasta abrir el editor de runas por primera vez | | |
| Primera runa que da y cómo la explica (texto, sala, personaje) | | |
| ¿Enseña con texto o con una sala que obliga a usarla? | | |
| ¿Cuántas runas tienes al acabar la primera hora? | | |
| Momento en que piensas «ah, ya lo entiendo» (minuto y qué pasó) | | |

## 2. El editor de runas

| Qué mirar | Mystralia | Magic Symbols hoy |
|---|---|---|
| Pasos (pulsaciones) para crear un hechizo nuevo de 3 runas | | Dibujar sello + glifos en una página |
| ¿Enseña una previsión del hechizo antes de salir? ¿Cómo? | | Previsión de reacciones y texto de cambio por glifo |
| ¿Muestra el coste de maná al montar? | | (comprobar qué enseña la previsión de tinta) |
| Máximo de runas por hechizo | | 1 glifo por sector; primer libro: 4 elementos y 6 glifos |
| Hechizos equipados a la vez y cómo se cambia entre ellos | | 3 páginas (teclas 1/2/3) |
| ¿Se puede editar en mitad de un combate? ¿Pausa o ralentiza? | | Libro abierto: tiempo al 30 % (`TIEMPO_LIBRO` 0,3) |
| ¿Algo de lo que hace una runa te sorprendió? ¿Qué? | | |
| ¿Alguna combinación te pareció que «no hacía nada»? | | Es la queja de Nintendo Life: apúntalas todas |

## 3. Tiempos de la protagonista

**Se mide en vídeo.** Graba cada acción 3 veces seguidas, en un sitio tranquilo.

| Qué medir | Mystralia | Magic Symbols hoy |
|---|---|---|
| Golpe cercano: desde que pulsas hasta que golpea | | Golpe F (sin medir) |
| Bola básica: desde que pulsas hasta que sale | | `magia/cast_points.gd` (por forma) |
| Bola básica: velocidad (casillas o cuerpos por segundo, a ojo) | | `velocidad_flecha` |
| Dash: distancia (en cuerpos de Zia) | | Voltereta: 1 casilla (`DIST_VOLTERETA`) |
| Dash: cuánto hasta poder repetirlo | | 1,5 s (`TIEMPO_VOLTERETA`) |
| Escudo (Ego sin runas): cuánto dura y qué para | | No hay |
| Tras recibir un golpe: cuánto hasta poder moverte | | (sin medir) |
| Tras recibir un golpe: cuánto eres invulnerable (parpadeo) | | 0,4 s (`INVULNERABLE`) |
| ¿Te pueden encadenar golpes? (lo critica Hardcore Gamer) | | |

## 4. Maná

| Qué medir | Mystralia | Magic Symbols hoy |
|---|---|---|
| Lanzamientos de bola básica con la barra llena | | Tinta 100 al empezar, tope 300 |
| Coste de la bola con 1, 2 y 3 runas (en lanzamientos por barra) | | Por glifo: flecha 2, repetición 3, permanencia 3, barrera 4, pulso 4; retorno, buscar y carga 0 |
| ¿Hay runas que no suben el coste? ¿Cuáles? | | Retorno, buscar y carga cuestan 0 |
| Tiempo de barra vacía a llena, fuera de combate | | ~33 s (`REGEN` 3/s) |
| ¿Regenera más lento en combate? | | Sí: 1/s (`REGEN_COMBATE`) |
| ¿El golpe cercano gasta maná? ¿Lo devuelve? | | El golpe F no devuelve tinta (propuesta C5) |
| Pociones o reservas de maná | | 3 frascos de reserva |
| ¿Te quedaste sin maná en combate? ¿Cuántas veces por hora? | | En el playtest, nunca |

## 5. Enemigos y combate

| Qué medir | Mystralia | Magic Symbols hoy |
|---|---|---|
| Golpes de bola básica para matar al goblin más común | | Goblin: 50 de vida, DEF 2; fuego con flecha ≈ 40 → 2 golpes |
| Golpes con tu mejor hechizo del momento | | |
| Golpes cercanos para matarlo | | |
| Aviso antes de su ataque: cuánto dura (en vídeo) | | Guerrero: 0,6 s (`PREPARAR_GOLPE`) |
| Descanso entre ataques | | Guerrero: 1,6 s; arquero: 2,2 s |
| Daño que te hace un golpe (fracción de tu vida) | | Guerrero 20, flecha 12 |
| Enemigos por encuentro (media) | | |
| ¿Se ven las resistencias de elemento? ¿Cómo? | | Ping de debilidad y rótulos |
| ¿Hay hitstop, temblor, destello o números al golpear? | | Hitstop escalado, destello del elemento, rótulos |
| ¿Algún enemigo te obligó a cambiar de hechizo? ¿Cuál y por qué? | | Es lo que nos falta: apúntalo bien |
| ¿Cuál fue una «esponja» (mucha vida y nada más)? | | |

## 6. La gárgola de la Cripta (tercera mazmorra)

Es el caso que su director pone de ejemplo. Graba el encuentro entero.

| Qué mirar | Mystralia |
|---|---|
| Qué hace la gárgola y por qué no se le puede dar de frente | |
| Tu primera solución (sin mirar guías) | |
| Prueba las otras dos: señuelo con Ego + Duplicar, bola quieta como mina, bola con Inversa por la espalda | |
| ¿Cuál fue más divertida? ¿Por qué? | |
| ¿Cómo te da a entender el juego que hay que buscar otra cosa? | |

## 7. Salas de runa y pistas

Una fila por sala de runa que encuentres.

| Sala (dónde) | Runa que da | Qué pedía | ¿Encontraste otra solución? | ¿Usaste la pista? ¿Qué decía? |
|---|---|---|---|---|
| | | | | |
| | | | | |
| | | | | |

**Además:** precio de la pista; ¿alguna sala te pareció de solución «demasiado concreta» (un hechizo que debería funcionar y no funciona)?

## 8. Experimentos con runas

Prueba cada combinación, graba y apunta qué pasa. **Esto es lo que más vale**: son las reglas que no he podido confirmar.

| # | Combinación | Qué pasa | Minuto |
|---|---|---|---|
| 1 | Actus + Derecha + Mover | (debería salir a tu derecha) | |
| 2 | Actus + Mover + Derecha | (debería curvar a la derecha) | |
| 3 | Actus + Mover + Inversa | | |
| 4 | Actus + Mover + Duplicar | | |
| 5 | Actus + Mover + Duplicar + Buscar | | |
| 6 | Actus sin Mover + disparador «al impactar» o «al terminar» con otro hechizo | | |
| 7 | Disparador periódico | | |
| 8 | Un hechizo con disparador que llama a otro con disparador: ¿hasta qué profundidad deja? | | |
| 9 | ¿El hechizo llamado por un disparador cobra su maná aparte? | | |
| 10 | Ego + Mover (el dash) | | |
| 11 | Ego + cada runa que tengas | | |
| 12 | Creo + Mover / Creo + Duplicar | | |
| 13 | Cambiar el elemento de un molde: ¿cómo se hace y qué cambia? | | |
| 14 | ¿Algún elemento cambia el mundo (quema, moja, congela agua)? | | |

## 9. Sensación (a ojo)

| Qué mirar | Mystralia |
|---|---|
| Lo que mejor se siente al golpear (y por qué) | |
| Lo que peor se siente | |
| Sonido de lanzar y de impactar: ¿cambia por runa o por elemento? | |
| ¿Se distingue en pantalla qué runas lleva un hechizo? | |
| ¿La cámara hace algo (temblor, zoom)? | |

## 10. Valoración libre

- **Tres momentos memorables** (minuto y qué pasó):
  1.
  2.
  3.
- **Tres frustraciones**:
  1.
  2.
  3.
- **Una cosa que robarías mañana para Magic Symbols:**

---

## Qué hago yo con esto

1. Me dices dónde están los vídeos (la carpeta `Vídeos\Capturas` o la que uses) y esta ficha con lo que hayas rellenado.
2. Saco los tiempos fotograma a fotograma y relleno la columna «Mystralia» de los bloques 3 y 5.
3. Escribo un apartado «Medido jugando» en `MAGES_OF_MYSTRALIA_2026-11-21.md`: sus cifras, las nuestras y qué cambiaría en el panel F3, con valores para que los pruebes tú.
