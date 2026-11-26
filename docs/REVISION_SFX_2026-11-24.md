# Revisión de SFX del juego — 24/11/2026

**Clasificación técnica y funcional provisional: 83 aceptados, 69 mejorables y 4 a cambiar sobre 156 entradas.** Además hay 7 grupos de carencias de cobertura. No se han modificado sonidos, código ni escenas.

**Esta revisión no incluye escucha de los archivos ni de una partida.** Se han decodificado y medido los 352 archivos de la raíz de audio/, comprobado la selección de catálogos y revisado las llamadas. «Aceptado» significa conservar la base por adecuación funcional y ausencia de un defecto local detectado; **no es una aprobación del timbre, musicalidad, fatiga ni mezcla final**. Todas las valoraciones artísticas siguen pendientes de escucha. Se respetan las elecciones de Pablo del 13/11.

## Alcance y criterio

- **Aceptado:** conservar recurso y función.
- **Mejorable:** conservar la base con recorte, ganancia, sincronización, variantes o limpieza de capas.
- **A cambiar:** sustituir un recurso inadecuado para su reproducción, o replantear un enganche que hoy no da la respuesta. Se indica cuál es el caso.

La unidad es la entrada lógica: los nombres duplicados en Sfx y Sfx3D son rutas distintas. Se cubren las 156 entradas, incluidos seis ambientes 3D, con 245 archivos únicos seleccionados. Con las opciones por defecto, 15 entradas eligen el pack de magia, 56 Sonniss y 85 el recurso base. Se comprobó que existen todas las variantes seleccionadas y sus .import. No se ejecutó ResourceLoader en el juego completo: falta validar su caché importada y la exportación.

Se midieron también alternativas y archivos fuera de catálogo. audio/fuentes/ contiene bibliotecas originales, no el montaje integrado: no se califican cientos de candidatos que no forman parte de los efectos actuales. Los 36 archivos de la raíz no referidos por los catálogos figuran en el anexo de archivos; no se propone borrarlos. combate_loop se incluye como capa musical que afecta a los SFX.

## Prioridades

1. **Contacto y aviso:** resolver suelo mudo, impactos sin enganche y golem_carga inexistente.
2. **Control de mezcla:** Sfx.play_en y Sfx.bucle no asignan bus, por lo que quedan en Master; Sfx3D usa Mundo/Ocluido. El volumen Mundo no controla toda la magia ni todas las reacciones. Cambiar archivos no arregla esto.
3. **Inicio de hojas:** paginas_bucle tarda unos 1001 ms en superar −60 dBFS. Recortar antes de retocar volumen.
4. **Variantes:** conjuro_arcano abarca 19.4 dB RMS y comprar 17.7 dB. Son energías de archivo completo, no LUFS ni volumen percibido; revisar tramo útil e igualar escuchando.
5. **Remates:** priorizar resolver puzle, revelar cofre, limpiar sala y completar misión cuando coinciden; no sustituir sonidos para corregir simultaneidad.

## Aceptado

Conservar la base. Validación auditiva pendiente en todos los casos.

| Entrada | Archivos seleccionados | Motivo | Ajuste o decisión |
|---|---|---|---|
| `Sfx.fuego` | `lc_fuego_0.ogg`, `lc_fuego_1.ogg`, `lc_fuego_2.ogg`, `lc_fuego_3.ogg` | Familia elemental con varias tomas propias; conservar la base por elemento.  | Validar identidad y colas en combate. |
| `Sfx.agua` | `lc_agua_0.ogg`, `lc_agua_1.ogg`, `lc_agua_2.ogg` | Familia elemental con varias tomas propias; conservar la base por elemento.  | Validar identidad y colas en combate. |
| `Sfx.hielo` | `lc_hielo_0.ogg`, `lc_hielo_1.ogg`, `lc_hielo_2.ogg`, `lc_hielo_3.ogg` | Familia elemental con varias tomas propias; conservar la base por elemento.  | Validar identidad y colas en combate. |
| `Sfx.rayo` | `lc_rayo_0.ogg`, `lc_rayo_1.ogg`, `lc_rayo_2.ogg`, `lc_rayo_3.ogg` | Familia elemental con varias tomas propias; conservar la base por elemento.  | Validar identidad y colas en combate. |
| `Sfx.viento` | `lc_viento_0.ogg`, `lc_viento_1.ogg`, `lc_viento_2.ogg`, `lc_viento_3.ogg` | Familia elemental con varias tomas propias; conservar la base por elemento.  | Validar identidad y colas en combate. |
| `Sfx.tierra` | `lc_tierra_0.ogg`, `lc_tierra_1.ogg`, `lc_tierra_2.ogg`, `lc_tierra_3.ogg` | Familia elemental con varias tomas propias; conservar la base por elemento.  | Validar identidad y colas en combate. |
| `Sfx.prender` | `prender.wav` | Señal específica para cada transición material.  | Conservar; comprobar balance frente al hechizo que la provoca. |
| `Sfx.derrumbe` | `sn_derrumbe_0.ogg` | Función concreta y recurso disponible; no hay evidencia para sustituir la base.  | Conservar; validar sincronía y jerarquía en mezcla. |
| `Sfx.rodar` | `rodar.wav` | Función concreta y recurso disponible; no hay evidencia para sustituir la base.  | Conservar; validar sincronía y jerarquía en mezcla. |
| `Sfx.arco` | `arco.wav` | Función concreta y recurso disponible; no hay evidencia para sustituir la base.  | Conservar; validar sincronía y jerarquía en mezcla. |
| `Sfx.pira` | `pira.wav` | Función concreta y recurso disponible; no hay evidencia para sustituir la base.  | Conservar; validar sincronía y jerarquía en mezcla. |
| `Sfx.dano` | `sn_dano_0.ogg` | Función concreta y recurso disponible; no hay evidencia para sustituir la base.  | Conservar; validar sincronía y jerarquía en mezcla. |
| `Sfx.muerte` | `sn_muerte_0.ogg` | Función concreta y recurso disponible; no hay evidencia para sustituir la base.  | Conservar; validar sincronía y jerarquía en mezcla. |
| `Sfx.clavar` | `kenney_clavar_0.ogg`, `kenney_clavar_1.ogg` | Respuesta específica; la síntesis de una señal musical no es un defecto por sí misma.  | Conservar; comprobar claridad a bajo volumen. |
| `Sfx.creak` | `creak.ogg` | Respuesta específica; la síntesis de una señal musical no es un defecto por sí misma.  | Conservar; comprobar claridad a bajo volumen. |
| `Sfx.trazo` | `trazo.wav` | Respuesta específica; la síntesis de una señal musical no es un defecto por sí misma.  | Conservar; comprobar claridad a bajo volumen. |
| `Sfx.sello_ok` | `sello_ok.wav` | Respuesta específica; la síntesis de una señal musical no es un defecto por sí misma.  | Conservar; comprobar claridad a bajo volumen. |
| `Sfx.amb_bosque` | `sn_amb_bosque_0.ogg` | La selección actual usa ambientes largos de 20 s; conservar esta base.  | Validar varias vueltas y transiciones entre zonas en escucha. |
| `Sfx.amb_cueva` | `sn_amb_cueva_0.ogg` | La selección actual usa ambientes largos de 20 s; conservar esta base.  | Validar varias vueltas y transiciones entre zonas en escucha. |
| `Sfx.amb_grillos` | `sn_amb_grillos_0.ogg` | La selección actual usa ambientes largos de 20 s; conservar esta base.  | Validar varias vueltas y transiciones entre zonas en escucha. |
| `Sfx.pulso_resonante` | `pulso_resonante.wav` | Respuesta específica; la síntesis de una señal musical no es un defecto por sí misma.  | Conservar; comprobar claridad a bajo volumen. |
| `Sfx.sello_no` | `sello_no.wav` | Respuesta específica; la síntesis de una señal musical no es un defecto por sí misma.  | Conservar; comprobar claridad a bajo volumen. |
| `Sfx.boton_clic` | `sn_boton_clic_0.ogg` | Respuesta específica; la síntesis de una señal musical no es un defecto por sí misma.  | Conservar; comprobar claridad a bajo volumen. |
| `Sfx.compuerta_baja` | `compuerta_baja.wav` | Hay recursos por mecanismo; llenado dispone de tono ligado al nivel.  | Conservar; comprobar sincronía y corte al terminar. |
| `Sfx.mecha` | `mecha.wav` | Hay recursos por mecanismo; llenado dispone de tono ligado al nivel.  | Conservar; comprobar sincronía y corte al terminar. |
| `Sfx.explosion` | `sn_explosion_0.ogg` | Hay recursos por mecanismo; llenado dispone de tono ligado al nivel.  | Conservar; comprobar sincronía y corte al terminar. |
| `Sfx.zumbido_electrico` | `sn_zumbido_electrico_0.ogg` | Hay recursos por mecanismo; llenado dispone de tono ligado al nivel.  | Conservar; comprobar sincronía y corte al terminar. |
| `Sfx.llenado` | `llenado.wav` | Hay recursos por mecanismo; llenado dispone de tono ligado al nivel.  | Conservar; comprobar sincronía y corte al terminar. |
| `Sfx.siseo_apagado` | `sn_siseo_apagado_0.ogg` | Señal específica para cada transición material.  | Conservar; comprobar balance frente al hechizo que la provoca. |
| `Sfx.chapoteo` | `chapoteo.wav` | Señal específica para cada transición material.  | Conservar; comprobar balance frente al hechizo que la provoca. |
| `Sfx.hundido_burbujas` | `sn_hundido_burbujas_0.ogg` | Señal específica para cada transición material.  | Conservar; comprobar balance frente al hechizo que la provoca. |
| `Sfx.escudo_golpe` | `sn_escudo_golpe_0.ogg` | Respuestas distintas para bloquear, romper, aturdir y empujar.  | Conservar; comprobar que romper destaque frente a bloquear. |
| `Sfx.escudo_roto` | `sn_escudo_roto_0.ogg` | Respuestas distintas para bloquear, romper, aturdir y empujar.  | Conservar; comprobar que romper destaque frente a bloquear. |
| `Sfx.aturdido` | `sn_aturdido_0.ogg` | Respuestas distintas para bloquear, romper, aturdir y empujar.  | Conservar; comprobar que romper destaque frente a bloquear. |
| `Sfx.empujado` | `empujado.wav` | Respuestas distintas para bloquear, romper, aturdir y empujar.  | Conservar; comprobar que romper destaque frente a bloquear. |
| `Sfx.no_puedes` | `sn_no_puedes_0.ogg` | El rechazo del mundo y el de menús tienen entradas separadas.  | Conservar; evitar sumar rechazo y sello_no para una sola acción. |
| `Sfx.tiempo_tic` | `sn_tiempo_tic_0.ogg` | Señal específica de tiempo bruja con tono fijo.  | Conservar; alinear ritmo y duración del estado. |
| `Sfx.moneda` | `sn_moneda_0.ogg`, `sn_moneda_1.ogg` | Dos tomas específicas de recompensa pequeña con nivel discreto.  | Conservar; agrupar recogidas simultáneas si ocultan señales de peligro. |
| `Sfx.latido` | `latido.wav` | La pausa entre pulsos forma parte de la cadencia; no es una costura defectuosa.  | Conservar; equilibrar frente a avisos de ataque. |
| `Sfx.secado` | `secado.wav` | Señal específica para cada transición material.  | Conservar; comprobar balance frente al hechizo que la provoca. |
| `Sfx.derretido` | `derretido.wav` | Señal específica para cada transición material.  | Conservar; comprobar balance frente al hechizo que la provoca. |
| `Sfx.logro_pista` | `logro_pista.wav` | Señales específicas de progresión local, diferenciadas del daño y rechazo.  | Conservar; evitar añadir remate general si ya suena el local. |
| `Sfx.bolsa` | `sn_bolsa_0.ogg` | Recursos específicos de interfaz con ruta play_ui disponible.  | Conservar y verificar consistencia entre menús. |
| `Sfx.brasero_linde_paso` | `brasero_linde_paso.wav` | Señales específicas de progresión local, diferenciadas del daño y rechazo.  | Conservar; evitar añadir remate general si ya suena el local. |
| `Sfx.brasero_linde_resuelto` | `brasero_linde_resuelto.wav` | Señales específicas de progresión local, diferenciadas del daño y rechazo.  | Conservar; evitar añadir remate general si ya suena el local. |
| `Sfx.pocion` | `pocion.wav` | Recursos específicos de interfaz con ruta play_ui disponible.  | Conservar y verificar consistencia entre menús. |
| `Sfx.pocion_fin` | `pocion.wav` | Recursos específicos de interfaz con ruta play_ui disponible.  | Conservar y verificar consistencia entre menús. |
| `Sfx.barrido` | `sn_barrido_0.ogg` | Recurso dedicado a una acción o desenlace identificable.  | Conservar; comprobar jerarquía frente a voces y otros remates. |
| `Sfx.reaparecer` | `lc_reaparecer_0.ogg` | Recurso dedicado a una acción o desenlace identificable.  | Conservar; comprobar jerarquía frente a voces y otros remates. |
| `Sfx.cofre_tapa` | `kenney_cofre_tapa_0.ogg`, `kenney_cofre_tapa_1.ogg`, `kenney_cofre_tapa_2.ogg` | Recurso dedicado a una acción o desenlace identificable.  | Conservar; comprobar jerarquía frente a voces y otros remates. |
| `Sfx.ping_debil` | `ping_debil.wav` | Recurso dedicado a una acción o desenlace identificable.  | Conservar; comprobar jerarquía frente a voces y otros remates. |
| `Sfx.golpe_sordo` | `golpe_sordo.wav` | Recurso dedicado a una acción o desenlace identificable.  | Conservar; comprobar jerarquía frente a voces y otros remates. |
| `Sfx.pira_muerte` | `pira.wav` | Recurso dedicado a una acción o desenlace identificable.  | Conservar; comprobar jerarquía frente a voces y otros remates. |
| `Sfx.hielo_rompe` | `sn_hielo_rompe_0.ogg` | Recurso dedicado a una acción o desenlace identificable.  | Conservar; comprobar jerarquía frente a voces y otros remates. |
| `Sfx.chispazo` | `lc_chispazo_0.ogg`, `lc_chispazo_1.ogg`, `lc_chispazo_2.ogg` | Recurso dedicado a una acción o desenlace identificable.  | Conservar; comprobar jerarquía frente a voces y otros remates. |
| `Sfx.salpicadura` | `lc_salpicadura_0.ogg`, `lc_salpicadura_1.ogg`, `lc_salpicadura_2.ogg` | Recurso dedicado a una acción o desenlace identificable.  | Conservar; comprobar jerarquía frente a voces y otros remates. |
| `Sfx.magma` | `lc_magma_0.ogg`, `lc_magma_1.ogg`, `lc_magma_2.ogg` | Familia elemental con varias tomas propias; conservar la base por elemento.  | Validar identidad y colas en combate. |
| `Sfx.salto` | `sn_salto_0.ogg` | Acción con señal específica y archivo disponible.  | Conservar y comprobar sincronía con acción o recompensa. |
| `Sfx.aterrizar` | `sn_aterrizar_0.ogg` | Acción con señal específica y archivo disponible.  | Conservar y comprobar sincronía con acción o recompensa. |
| `Sfx.flecha_clava` | `sn_flecha_clava_0.ogg` | Acción con señal específica y archivo disponible.  | Conservar y comprobar sincronía con acción o recompensa. |
| `Sfx.trueno` | `lc_trueno_0.ogg`, `lc_trueno_1.ogg`, `lc_trueno_2.ogg` | Acción con señal específica y archivo disponible.  | Conservar y comprobar sincronía con acción o recompensa. |
| `Sfx.sintetizar` | `sn_sintetizar_0.ogg` | Acción con señal específica y archivo disponible.  | Conservar y comprobar sincronía con acción o recompensa. |
| `Sfx.tinta_sube` | `logro_fanfarria.wav` | Acción con señal específica y archivo disponible.  | Conservar y comprobar sincronía con acción o recompensa. |
| `Sfx.hielo_flecha` | `lc_hielo_flecha_0.ogg`, `lc_hielo_flecha_1.ogg`, `lc_hielo_flecha_2.ogg`, `lc_hielo_flecha_3.ogg` | Familia elemental con varias tomas propias; conservar la base por elemento.  | Validar identidad y colas en combate. |
| `Sfx3D.goblin_muere` | `sn_goblin_muere_0.ogg` | Recursos por cuerpo y posición; Sfx3D evita repetir inmediatamente la misma variante.  | Conservar; contrastar aviso y muerte y comprobar peso de pasos. |
| `Sfx3D.golpe_carne` | `sn_golpe_carne_0.ogg`, `sn_golpe_carne_1.ogg`, `sn_golpe_carne_2.ogg`, `sn_golpe_carne_3.ogg` | Recursos por cuerpo y posición; Sfx3D evita repetir inmediatamente la misma variante.  | Conservar; contrastar aviso y muerte y comprobar peso de pasos. |
| `Sfx3D.golpe_piedra` | `kenney_golpe_piedra_0.ogg`, `kenney_golpe_piedra_1.ogg`, `kenney_golpe_piedra_2.ogg` | Recursos por cuerpo y posición; Sfx3D evita repetir inmediatamente la misma variante.  | Conservar; contrastar aviso y muerte y comprobar peso de pasos. |
| `Sfx3D.paso_golem` | `kenney_paso_golem_0.ogg`, `kenney_paso_golem_1.ogg`, `kenney_paso_golem_2.ogg`, `kenney_paso_golem_3.ogg` | Recursos por cuerpo y posición; Sfx3D evita repetir inmediatamente la misma variante.  | Conservar; contrastar aviso y muerte y comprobar peso de pasos. |
| `Sfx3D.limo_golpe` | `sn_limo_golpe_0.ogg` | Recursos por cuerpo y posición; Sfx3D evita repetir inmediatamente la misma variante.  | Conservar; contrastar aviso y muerte y comprobar peso de pasos. |
| `Sfx3D.limo_muere` | `sn_limo_muere_0.ogg` | Recursos por cuerpo y posición; Sfx3D evita repetir inmediatamente la misma variante.  | Conservar; contrastar aviso y muerte y comprobar peso de pasos. |
| `Sfx3D.derrumbe` | `sn_derrumbe_0.ogg` | Está en la ruta 3D que lo llama; conserva las elecciones de loberno e impacto de Pablo.  | Conservar; comprobar distancia y prioridad en escena. |
| `Sfx3D.escudo_golpe` | `sn_escudo_golpe_0.ogg` | Está en la ruta 3D que lo llama; conserva las elecciones de loberno e impacto de Pablo.  | Conservar; comprobar distancia y prioridad en escena. |
| `Sfx3D.sello_ok` | `sello_ok.wav` | Está en la ruta 3D que lo llama; conserva las elecciones de loberno e impacto de Pablo.  | Conservar; comprobar distancia y prioridad en escena. |
| `Sfx3D.loberno_ladrido` | `sn_loberno_ladrido_0.ogg`, `sn_loberno_ladrido_1.ogg`, `sn_loberno_ladrido_2.ogg` | Está en la ruta 3D que lo llama; conserva las elecciones de loberno e impacto de Pablo.  | Conservar; comprobar distancia y prioridad en escena. |
| `Sfx3D.loberno_muere` | `sn_loberno_muere_0.ogg` | Está en la ruta 3D que lo llama; conserva las elecciones de loberno e impacto de Pablo.  | Conservar; comprobar distancia y prioridad en escena. |
| `Sfx3D.impacto_suelo` | `sn_impacto_suelo_0.ogg`, `sn_impacto_suelo_1.ogg`, `sn_impacto_suelo_2.ogg`, `sn_impacto_suelo_3.ogg` | Está en la ruta 3D que lo llama; conserva las elecciones de loberno e impacto de Pablo.  | Conservar; comprobar distancia y prioridad en escena. |
| `Sfx3D.limo_divide` | `sn_limo_divide_0.ogg` | La división tiene señal distinta de golpe y muerte en la selección actual.  | Conservar; limitar acumulación de divisiones simultáneas si hace falta. |
| `Sfx3D.raices_brotan` | `lc_raices_brotan_0.ogg`, `lc_raices_brotan_1.ogg`, `lc_raices_brotan_2.ogg` | Tres tomas por evento y distinción de salida, contacto y brote.  | Conservar; equilibrar frente a los ataques de la jugadora. |
| `Sfx3D.arco` | `arco.wav` | Hay enganche en la suelta de flecha y ruta posicional.  | Conservar; comprobar claridad frente al tensado. |
| `Ambiente3D.fuego` | `oga_fuego_crepita_loop.wav` | Recurso específico y emisor espacial limitado; inicio aleatorio dentro del bucle.  | Conservar; validar continuidad y mezcla con varios emisores. |
| `Ambiente3D.agua` | `oga_agua_corriendo_loop.ogg` | Recurso específico y emisor espacial limitado; inicio aleatorio dentro del bucle.  | Conservar; validar continuidad y mezcla con varios emisores. |
| `Ambiente3D.agua_cae` | `agua_cae_loop.ogg` | Recurso específico y emisor espacial limitado; inicio aleatorio dentro del bucle.  | Conservar; validar continuidad y mezcla con varios emisores. |
| `Ambiente3D.gato_ronroneo` | `oga_gato_ronroneo_loop.wav` | Recurso específico y emisor espacial limitado; inicio aleatorio dentro del bucle.  | Conservar; validar continuidad y mezcla con varios emisores. |

## Mejorable

La base puede utilizarse tras estos ajustes.

| Entrada | Archivos seleccionados | Motivo | Ajuste o decisión |
|---|---|---|---|
| `Sfx.tiempo` | `elem_tiempo.wav` | Recursos heredados fuera de los seis sellos actuales.  | Conservar como reserva; decidir su uso antes de afinarlos. |
| `Sfx.congelar` | `oga_congelar_0.wav`, `oga_congelar_1.wav` | Señal específica para cada transición material. Rango RMS entre tomas: 7.3 dB (archivo completo, no sonoridad percibida). | Conservar; comprobar balance frente al hechizo que la provoca. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx.chispa` | `chispa.wav` | Entrada heredada o con enganche limitado; el archivo no demuestra cobertura en los niveles.  | Verificar el emisor real; integrar donde exista esa acción. |
| `Sfx.paso` | `paso_0.ogg`, `paso_1.ogg`, `paso_2.ogg`, `paso_3.ogg`, `paso_4.ogg`, `paso_5.ogg` | Entrada heredada o con enganche limitado; el archivo no demuestra cobertura en los niveles. Rango RMS entre tomas: 7.9 dB (archivo completo, no sonoridad percibida). Algún pico decodificado sobre 0 dBFS; la ganancia del juego atenúa después. No prueba distorsión audible. | Verificar el emisor real; integrar donde exista esa acción. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx.puerta_abre` | `puerta_abre_0.ogg`, `puerta_abre_1.ogg` | Foley acorde con la acción; alguna toma decodifica sobre 0 dBFS. Eso no demuestra distorsión con la ganancia del juego. Algún pico decodificado sobre 0 dBFS; la ganancia del juego atenúa después. No prueba distorsión audible. | Dar margen al archivo y equilibrar tomas por volumen percibido. |
| `Sfx.puerta_cierra` | `puerta_cierra_0.ogg`, `puerta_cierra_1.ogg` | Foley acorde con la acción; alguna toma decodifica sobre 0 dBFS. Eso no demuestra distorsión con la ganancia del juego. Rango RMS entre tomas: 4.2 dB (archivo completo, no sonoridad percibida). Algún pico decodificado sobre 0 dBFS; la ganancia del juego atenúa después. No prueba distorsión audible. | Dar margen al archivo y equilibrar tomas por volumen percibido. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx.libro_abre` | `sn_libro_abre_0.ogg` | Selección de Pablo del 13/11: se conserva el libro antiguo. Comparte recurso con otras pantallas o acciones.  | Ajustar la porción útil y la sincronía con apertura/hojeo. |
| `Sfx.libro_cierra` | `libro_cierra.ogg` | Foley acorde con la acción; alguna toma decodifica sobre 0 dBFS. Eso no demuestra distorsión con la ganancia del juego. Algún pico decodificado sobre 0 dBFS; la ganancia del juego atenúa después. No prueba distorsión audible. | Dar margen al archivo y equilibrar tomas por volumen percibido. |
| `Sfx.pagina` | `sn_pagina_0.ogg` | Selección de Pablo del 13/11: se conserva el libro antiguo. Comparte recurso con otras pantallas o acciones.  | Ajustar la porción útil y la sincronía con apertura/hojeo. |
| `Sfx.pluma_bucle` | `fs_pluma_pergamino.mp3` | El control por velocidad existe; el archivo tiene unos 81 ms finales bajo −60 dBFS.  | Elegir un tramo continuo y preparar la costura conservando el control por gesto. |
| `Sfx.paginas_bucle` | `fs_paginas_bucle.mp3` | Grabación de 101 s; la primera señal sobre −60 dBFS llega a unos 1001 ms. La animación puede acabar antes.  | Quitar la espera inicial y extraer un tramo de hojeo inmediato. |
| `Sfx.conjuro_arcano` | `oga_conjuro_arcano_0.ogg`, `oga_conjuro_arcano_1.ogg`, `oga_conjuro_arcano_2.ogg`, `oga_conjuro_arcano_3.ogg`, `oga_conjuro_arcano_4.ogg`, `oga_conjuro_arcano_5.ogg`, `oga_conjuro_arcano_6.ogg` | Siete tomas con energía muy desigual para una misma capa común. Rango RMS entre tomas: 19.4 dB (archivo completo, no sonoridad percibida). | Igualar por tramo útil y volumen percibido; dejar espacio a la carga elemental. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx.descarga_electrica` | `oga_relampago_1.wav` | La separación de golpe inicial y sostenido es útil; las fuentes alcanzan 0 dBFS sin margen.  | Conservar ambas capas, dar margen y comprobar el final del sostenido. |
| `Sfx.chasquidos_electricos` | `oga_descarga_chasquidos.wav` | La separación de golpe inicial y sostenido es útil; las fuentes alcanzan 0 dBFS sin margen.  | Conservar ambas capas, dar margen y comprobar el final del sostenido. |
| `Sfx.amb_sala` | `amb_sala_loop.wav` | Un único ambiente genérico no diferencia los interiores.  | Mantener bajo como fondo provisional y ajustar presencia por sala. |
| `Sfx.amb_pajaros` | `amb_pajaros_0.wav`, `amb_pajaros_1.wav`, `amb_pajaros_2.wav` | Los trinos se añaden a un bosque grabado que ya incluye pájaros.  | Espaciar eventos o suprimir la capa adicional si duplica la densidad. |
| `Sfx.placa_hunde` | `placa_hunde.wav` | Entrada heredada o con enganche limitado; el archivo no demuestra cobertura en los niveles.  | Verificar el emisor real; integrar donde exista esa acción. |
| `Sfx.hielo_quiebra` | `sn_hielo_quiebra_0.ogg`, `sn_hielo_quiebra_1.ogg`, `sn_hielo_quiebra_2.ogg` | Entrada heredada o con enganche limitado; el archivo no demuestra cobertura en los niveles. Rango RMS entre tomas: 4.3 dB (archivo completo, no sonoridad percibida). | Verificar el emisor real; integrar donde exista esa acción. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx.rueda_chirria` | `rueda_chirria.wav` | Entrada heredada o con enganche limitado; el archivo no demuestra cobertura en los niveles.  | Verificar el emisor real; integrar donde exista esa acción. |
| `Sfx.fuego_carga` | `fuego_carga.wav` | Carga distinta del disparo, pero superpuesta a conjuro_arcano y al sostenido general.  | Ajustar envolvente y nivel de las capas en una secuencia completa. |
| `Sfx.fuego_carga_bucle` | `fuego_carga_bucle.wav` | Existe junto al bucle de carga general; comprobar su función real.  | Evitar dos sostenidos simultáneos sin una jerarquía definida. |
| `Sfx.agua_carga` | `agua_carga.wav` | Carga distinta del disparo, pero superpuesta a conjuro_arcano y al sostenido general.  | Ajustar envolvente y nivel de las capas en una secuencia completa. |
| `Sfx.hielo_carga` | `hielo_carga.wav` | Carga distinta del disparo, pero superpuesta a conjuro_arcano y al sostenido general.  | Ajustar envolvente y nivel de las capas en una secuencia completa. |
| `Sfx.rayo_carga` | `sn_rayo_carga_0.ogg` | Carga distinta del disparo, pero superpuesta a conjuro_arcano y al sostenido general.  | Ajustar envolvente y nivel de las capas en una secuencia completa. |
| `Sfx.viento_carga` | `viento_carga.wav` | Carga distinta del disparo, pero superpuesta a conjuro_arcano y al sostenido general.  | Ajustar envolvente y nivel de las capas en una secuencia completa. |
| `Sfx.tierra_carga` | `tierra_carga.wav` | Carga distinta del disparo, pero superpuesta a conjuro_arcano y al sostenido general.  | Ajustar envolvente y nivel de las capas en una secuencia completa. |
| `Sfx.tiempo_carga` | `tiempo_carga.wav` | Recursos heredados fuera de los seis sellos actuales.  | Conservar como reserva; decidir su uso antes de afinarlos. |
| `Sfx.arde_bucle` | `sn_arde_bucle_0.ogg` | Conservar la hoguera elegida por Pablo; objetos y braseros usan fuentes distintas.  | Igualar ambos fuegos y revisar la suma de varios emisores. |
| `Sfx.lanzar_salida` | `lanzar_salida.wav` | La salida común puede coincidir con el disparo elemental.  | Recortar o bajar la capa común si tapa la identidad del elemento. |
| `Sfx.no_puedes_ui` | `kenney_error_0.ogg`, `kenney_error_1.ogg`, `kenney_error_2.ogg`, `kenney_error_3.ogg` | El rechazo del mundo y el de menús tienen entradas separadas. Algún pico decodificado sobre 0 dBFS; la ganancia del juego atenúa después. No prueba distorsión audible. | Conservar; evitar sumar rechazo y sello_no para una sola acción. |
| `Sfx.aviso_ataque` | `aviso_ataque.wav` | Necesita prioridad frente a magia, pasos y gritos; el catálogo no garantiza legibilidad en combate.  | Ajustar en mezcla y sincronizar con el comienzo de la anticipación. |
| `Sfx.reaccion_grande` | `sn_reaccion_grande_0.ogg` | Añade otra capa al daño y la reacción material.  | Limitar su frecuencia o nivel cuando ya existe una respuesta suficiente. |
| `Sfx.combate_loop` | `combate_loop.wav` | Capa musical continua que comparte espacio con los efectos.  | Afinar entradas, salidas y nivel con avisos y ambiente activos. |
| `Sfx.sala_limpia` | `sala_limpia.wav` | Los hitos tienen señales propias, pero pueden coincidir. Se respeta el puzle elegido por Pablo.  | Definir prioridad o secuencia para resolver, revelar cofre y completar misión. |
| `Sfx.dano_jugadora` | `sn_dano_jugadora_0.ogg` | Una toma para un evento frecuente; variar tono no aporta otra interpretación.  | Conservar; afinar tono por daño y añadir variantes si la repetición molesta. |
| `Sfx.voltereta` | `sn_voltereta_0.ogg`, `sn_voltereta_1.ogg`, `sn_voltereta_2.ogg` | Tres tomas y variación de tono para una acción frecuente. Rango RMS entre tomas: 5.9 dB (archivo completo, no sonoridad percibida). | Conservar; alinear con el movimiento. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx.recarga_lista` | `sn_recarga_lista_0.ogg` | Clic breve de disponibilidad; el tercer parámetro de Sfx.play modifica tono, no volumen.  | Comprobar claridad a bajo nivel y documentar el significado de la llamada. |
| `Sfx.golpe_mundo` | `golpe_mundo.wav` | Golpe genérico para distintos elementos/materiales; además excluye el suelo.  | Conservar de respaldo y añadir respuesta material en contactos relevantes. |
| `Sfx.carga_bucle` | `sn_carga_bucle_0.ogg` | El hojeo sostenido es elección de Pablo; sus ventanas inicial y final difieren unos 11 dB RMS.  | Conservar el concepto, preparar región estable y cruzar la costura. |
| `Sfx.logro_acierto` | `sn_logro_acierto_0.ogg` | Los hitos tienen señales propias, pero pueden coincidir. Se respeta el puzle elegido por Pablo.  | Definir prioridad o secuencia para resolver, revelar cofre y completar misión. |
| `Sfx.objetivo_cumplido` | `sn_objetivo_cumplido_0.ogg` | Los hitos tienen señales propias, pero pueden coincidir. Se respeta el puzle elegido por Pablo.  | Definir prioridad o secuencia para resolver, revelar cofre y completar misión. |
| `Sfx.puzle_resuelto` | `sn_puzle_resuelto_0.ogg` | Los hitos tienen señales propias, pero pueden coincidir. Se respeta el puzle elegido por Pablo.  | Definir prioridad o secuencia para resolver, revelar cofre y completar misión. |
| `Sfx.mision_completada` | `mision_completada.wav` | Los hitos tienen señales propias, pero pueden coincidir. Se respeta el puzle elegido por Pablo.  | Definir prioridad o secuencia para resolver, revelar cofre y completar misión. |
| `Sfx.logro_brillo` | `sn_logro_brillo_0.ogg` | Los hitos tienen señales propias, pero pueden coincidir. Se respeta el puzle elegido por Pablo.  | Definir prioridad o secuencia para resolver, revelar cofre y completar misión. |
| `Sfx.logro_fanfarria` | `logro_fanfarria.wav` | Los hitos tienen señales propias, pero pueden coincidir. Se respeta el puzle elegido por Pablo.  | Definir prioridad o secuencia para resolver, revelar cofre y completar misión. |
| `Sfx.cofre_revelado` | `sn_cofre_revelado_0.ogg` | Los hitos tienen señales propias, pero pueden coincidir. Se respeta el puzle elegido por Pablo.  | Definir prioridad o secuencia para resolver, revelar cofre y completar misión. |
| `Sfx.recoger` | `kenney_recoger_0.ogg`, `kenney_recoger_1.ogg`, `kenney_recoger_2.ogg`, `kenney_recoger_3.ogg` | Recursos específicos de interfaz con ruta play_ui disponible. Rango RMS entre tomas: 10.0 dB (archivo completo, no sonoridad percibida). | Conservar y verificar consistencia entre menús. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx.golpe_ui` | `golpe_ui.wav` | Entrada heredada; el alias no demuestra una interacción vigente que la necesite.  | Confirmar uso real antes de considerarla cobertura. |
| `Sfx.comprar` | `kenney_comprar_0.ogg`, `kenney_comprar_1.ogg` | Recursos específicos de interfaz con ruta play_ui disponible. Rango RMS entre tomas: 17.7 dB (archivo completo, no sonoridad percibida). Algún pico decodificado sobre 0 dBFS; la ganancia del juego atenúa después. No prueba distorsión audible. | Conservar y verificar consistencia entre menús. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx.ui_tick` | `kenney_clic_0.ogg`, `kenney_clic_1.ogg`, `kenney_clic_2.ogg`, `kenney_clic_3.ogg`, `kenney_clic_4.ogg` | Recursos específicos de interfaz con ruta play_ui disponible. Rango RMS entre tomas: 13.6 dB (archivo completo, no sonoridad percibida). | Conservar y verificar consistencia entre menús. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx.ui_equipar` | `kenney_equipar_0.ogg`, `kenney_equipar_1.ogg` | Recursos específicos de interfaz con ruta play_ui disponible. Rango RMS entre tomas: 3.8 dB (archivo completo, no sonoridad percibida). | Conservar y verificar consistencia entre menús. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx.derrumbe_muerte` | `derrumbe.wav` | Usa el sintetizado mientras derrumbe normal selecciona Sonniss; ataque sobre −60 dBFS tras unos 180 ms.  | Unificar la familia y recortar el previo si debe coincidir con la rotura. |
| `Sfx.naturaleza` | `sn_naturaleza_0.ogg` | Wood Shaker fue elegido por Pablo; falta una carga propia y se reutiliza el disparo.  | Mantener la madera, añadir detalle vegetal si hace falta y distinguir la carga. |
| `Sfx.explosion_barril` | `sn_explosion_barril_0.ogg`, `sn_explosion_barril_1.ogg` | Las dos explosiones elegidas por Pablo compiten con destrucción, daño y muertes.  | Conservar; ordenar capas y medir la suma en explosiones múltiples. |
| `Sfx3D.paso_hierba` | `oga_paso_hojas_0.ogg`, `oga_paso_hojas_1.ogg` | Solo dos o tres tomas por suelo; tierra y roca comparten grava. Rango RMS entre tomas: 5.8 dB (archivo completo, no sonoridad percibida). | Igualar tomas, conservar la sutileza pedida por Pablo y ampliar variedad si se reconoce la repetición. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx3D.paso_tierra` | `oga_paso_barro_0.ogg`, `oga_paso_grava_0.ogg` | Solo dos o tres tomas por suelo; tierra y roca comparten grava. Rango RMS entre tomas: 6.3 dB (archivo completo, no sonoridad percibida). | Igualar tomas, conservar la sutileza pedida por Pablo y ampliar variedad si se reconoce la repetición. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx3D.paso_roca` | `oga_paso_piedra_0.ogg`, `oga_paso_grava_0.ogg` | Solo dos o tres tomas por suelo; tierra y roca comparten grava. Rango RMS entre tomas: 6.2 dB (archivo completo, no sonoridad percibida). | Igualar tomas, conservar la sutileza pedida por Pablo y ampliar variedad si se reconoce la repetición. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx3D.paso_madera` | `oga_paso_madera_0.ogg`, `oga_paso_madera_1.ogg`, `oga_paso_madera_2.ogg` | Solo dos o tres tomas por suelo; tierra y roca comparten grava. Rango RMS entre tomas: 8.6 dB (archivo completo, no sonoridad percibida). | Igualar tomas, conservar la sutileza pedida por Pablo y ampliar variedad si se reconoce la repetición. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx3D.goblin_grito` | `sn_goblin_grito_0.ogg`, `sn_goblin_grito_1.ogg`, `sn_goblin_grito_2.ogg` | Recursos por cuerpo y posición; Sfx3D evita repetir inmediatamente la misma variante. Rango RMS entre tomas: 3.1 dB (archivo completo, no sonoridad percibida). | Conservar; contrastar aviso y muerte y comprobar peso de pasos. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx3D.paso_goblin` | `kenney_paso_goblin_0.ogg`, `kenney_paso_goblin_1.ogg`, `kenney_paso_goblin_2.ogg`, `kenney_paso_goblin_3.ogg` | Combina hierba y madera con tono base 1,2 sin seguir necesariamente el suelo real. Rango RMS entre tomas: 9.1 dB (archivo completo, no sonoridad percibida). | Igualar tomas y seleccionar material según superficie cuando importe. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx3D.gato_maullido` | `oga_gato_maullido_0.wav`, `oga_gato_maullido_1.wav`, `oga_gato_maullido_2.ogg` | Tres tomas de duración distinta; una tarda unos 276 ms en superar −60 dBFS. Rango RMS entre tomas: 4.1 dB (archivo completo, no sonoridad percibida). | Recortar el previo sin perder respiración y equilibrar las tomas. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx3D.conversacion_voz` | `conversacion_voz_0.ogg`, `conversacion_voz_1.ogg`, `conversacion_voz_2.ogg` | Tres voces genéricas sirven de base pero no diferencian personajes.  | Afinar cadencia por frase y familias de voz si hablan varios personajes. |
| `Sfx3D.maza_impacto` | `sn_maza_impacto_0.ogg` | Impact Cut Sweep fue elegido por Pablo y también se usa en reaccion_grande.  | Alinear el golpe con el contacto y evitar duplicarlo con la reacción. |
| `Sfx3D.arco_carga` | `sn_arco_carga_0.ogg` | Wood Shaker fue elegido por Pablo; ya se dispara al empezar a tensar y dura unos 1,73 s.  | Ajustar duración al aviso real sin solapar innecesariamente tensado y disparo. |
| `Sfx3D.golem_rugido` | `sn_golem_rugido_0.ogg` | Una toma por familia; sin Sonniss el respaldo es derrumbe y se pierde la voz específica.  | Preparar respaldo apropiado y comprobar que no tape la anticipación. |
| `Sfx3D.jefe_rugido` | `sn_jefe_rugido_0.ogg` | Una toma por familia; sin Sonniss el respaldo es derrumbe y se pierde la voz específica.  | Preparar respaldo apropiado y comprobar que no tape la anticipación. |
| `Sfx3D.veneno_bola` | `lc_veneno_bola_0.ogg`, `lc_veneno_bola_1.ogg`, `lc_veneno_bola_2.ogg` | Tres tomas por evento y distinción de salida, contacto y brote. Rango RMS entre tomas: 3.2 dB (archivo completo, no sonoridad percibida). | Conservar; equilibrar frente a los ataques de la jugadora. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Sfx3D.veneno_charco` | `lc_veneno_charco_0.ogg`, `lc_veneno_charco_1.ogg`, `lc_veneno_charco_2.ogg` | Tres tomas por evento y distinción de salida, contacto y brote. Rango RMS entre tomas: 8.0 dB (archivo completo, no sonoridad percibida). | Conservar; equilibrar frente a los ataques de la jugadora. Igualar variantes por tramo útil antes de aplicar ganancia común. |
| `Ambiente3D.murmullo` | `conversacion_murmullo_loop.ogg` | No se encontraron peticiones literales de este ambiente en los scripts de juego revisados.  | Decidir si se usará antes de contarlo como cobertura vigente. |

## A cambiar

Sustitución del recurso o replanteamiento de su integración, según la fila.

| Entrada | Archivos seleccionados | Motivo | Ajuste o decisión |
|---|---|---|---|
| `Sfx.x_mano_impacto` | `x_mano_impacto.wav` | Hay archivo pero no se pide la fase impacto del helper en magia/. No cubre hoy el contacto.  | Replantear el enganche al contacto real y elegir respuesta por elemento/material. |
| `Sfx.alto_impacto` | `alto_impacto.wav` | Hay archivo pero no se pide la fase impacto del helper en magia/. No cubre hoy el contacto.  | Replantear el enganche al contacto real y elegir respuesta por elemento/material. |
| `Sfx.abajo_impacto` | `abajo_impacto.wav` | Hay archivo pero no se pide la fase impacto del helper en magia/. No cubre hoy el contacto.  | Replantear el enganche al contacto real y elegir respuesta por elemento/material. |
| `Ambiente3D.arrastre` | `rodar.wav` | Repite rodar.wav, un one-shot de 0,6 s. Sus extremos caen más de 23 dB frente al RMS global.  | Sustituir por una región sostenida estable; reservar golpes para inicio y final. |

### Acciones sin cobertura suficiente

Estos grupos no se suman a las 156 entradas: son huecos o cruces entre ellas.

| Acción | Evidencia | Problema | Cambio |
|---|---|---|---|
| Aviso de embestida del verraco | enemigos/verraco_3d.gd:199–200 | Comprueba golem_carga en Sfx y lo pide por Sfx3D; la entrada no existe en ninguno. | Añadir aviso y consultar el mismo catálogo que lo reproduce. |
| Impacto contra el suelo | presentacion/sensacion_3d.gd:1163–1164 | Solo reproduce golpe_mundo si no es suelo. | Añadir respuesta de contacto elemental/material con límite de eventos. |
| Impactos por forma/elemento | magia/lanzador_3d.gd:2431 | El helper admite impacto pero no hay llamada a esa fase en magia/. | Conectar al contacto real, sin dispararlo al materializar una forma sin contacto. |
| Carga de magma y naturaleza | magia/lanzador_3d.gd:2432–2441 | No existen magma_carga ni naturaleza_carga: reutiliza el disparo. | Crear una carga distinguible conservando el disparo. |
| Molino / nexo de rayo / receptor de pulso | Scripts correspondientes en objetos/ | No incluyen llamadas Sfx/Sfx3D; puede haber respuesta general de logro. | Verificar en escena y añadir arranque, activación o parada que falte. |
| Colmena / cuerda / surtidor / tronco puente / enredadera | Scripts correspondientes en objetos/ | No incluyen llamadas Sfx/Sfx3D; falta comprobar respuesta indirecta y herencia por escena. | Verificar cada objeto y añadir el evento material ausente sin duplicarlo. |
| Haz, órbita, zona, rebote y estados continuos | Catálogos y código de magia | No hay entradas dedicadas; el disparo general no demuestra cobertura de su vida completa. | Diseñar inicio/sostenido/final donde mejoren la lectura; limitar emisores por área. |

El silencio de **mouro_espectro_3d** y **anima_compana_3d** es explícito: snd_alerta y snd_muere están vacíos. Se conserva como decisión de diseño y no se clasifica automáticamente como error.

## Problemas del conjunto

- **Buses:** default_bus_layout.tres fija Interfaz a −6 dB, Mundo a 0 dB y Ocluido a −6 dB con filtro a 900 Hz. play_ui sí asigna Interfaz; play_en y bucle no asignan Mundo. Sfx3D sí configura bus y distancias. Unificar antes de retocar ganancias globales.
- **Repetición:** Sfx puede elegir inmediatamente la misma variante; Sfx3D lo evita. Conviene extender esta política a efectos frecuentes si la escucha revela repetición.
- **Antirráfaga:** Sfx comparte 70 ms por nombre; Sfx3D aplica 70 ms por nombre y emisor. Una puede suprimir eventos distintos y la otra deja sumar muchos enemigos. Revisar prioridades y límite de voces en combate real.
- **Portabilidad:** sin Sonniss, los rugidos recurren a derrumbe, el loberno a goblin y naturaleza a tierra. Revisar los respaldos en otra máquina y la selección de la exportación. El selector solo verifica el primer archivo de cada familia; esta auditoría comprobó todas las variantes elegidas.
- **Conjuro:** pueden superponerse carga elemental, conjuro_arcano, sostenido, salida común y disparo. Afinar una secuencia completa antes de aumentar cada pista por separado.
- **Picos y energía:** medición digital a 44,1 kHz sin buses, distancia ni oclusión. Picos Vorbis sobre 0 dBFS pueden aparecer por reconstrucción del códec; no prueban clipping audible tras atenuar. El RMS completo incluye silencios y colas: no aplicar normalización ciega.

## Validación auditiva pendiente

El [catálogo con reproductores](REVISION_SFX_2026-11-24.html) permite oír cada variante y sus alternativas. Abrirlo en el navegador desde esta carpeta. Reproduce el archivo original y, opcionalmente, la ganancia y tono base del catálogo; no simula escena, buses, oclusión, variación aleatoria ni suma de capas. **No es una escucha ya realizada por el revisor.**

1. Libro: apertura, trazo lento/rápido, aceptar/rechazar, páginas y cierre. Confirmar que el sonido empieza con la acción.
2. Movimiento: 30 s por suelo andando y corriendo; salto, aterrizaje, vadeo y voltereta. Revisar repetición y sutileza.
3. Magia: carga, sostenido, salida y contacto de cada elemento, solo y después con enemigos; incluir suelo y barrera.
4. Combate: goblins, arquero, limo, gólem, loberno, chamán, verraco y jefe; aviso legible antes del daño, también con vida baja.
5. Mundo: puzle, compuerta, cofre y misión; varios fuegos, agua y bloque arrastrado durante diez segundos.
6. Silenciar Mundo e Interfaz por separado; escuchar detrás de un muro; repetir con y sin paquetes y con varias explosiones simultáneas.

Para cerrar la aceptación artística faltan identidad, sincronía, utilidad a bajo volumen, tolerancia a la repetición y legibilidad en mezcla.

## Evidencia y verificación

- [Inventario anterior y elecciones de Pablo](INVENTARIO_SFX_2026-11-13.md).
- [Catálogo general](../nucleo/sfx.gd), [catálogo espacial](../nucleo/sfx_3d.gd), [buses](../default_bus_layout.tres).
- [Decisiones por entrada en CSV](qa/SFX_CATALOGO_2026-11-24.csv) y [todos los archivos medidos](qa/SFX_ARCHIVOS_2026-11-24.csv).
- Scripts y datos reproducibles en output/revision_sfx/: inventariar.cjs, catalogo.json, medir.gd, metricas.json y generar_informe.cjs. Las referencias automáticas son menciones literales, no pruebas de reproducción. Los nombres dinámicos se revisaron en Lanzador3D: no se marcan muertos por carecer de llamada literal.
- mix_audio se detiene al final del flujo, que puede tener unas pocas muestras menos que la duración declarada por redondeo/resampling. Se mide la fuente decodificada, no la compresión WAV importada.

Verificados: cobertura de 156 entradas, existencia de variantes seleccionadas, decodificación de 352 archivos y coherencia entre tablas, CSV y reproductores. No se ejecutaron pruebas de jugabilidad: se añadieron documentación y herramientas aisladas de medición.
