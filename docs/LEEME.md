# docs/ — cómo está organizado

**Empieza por aquí (2/11/2026):**

- [`GDD.md`](GDD.md): qué juego es, pilares, bucle, qué está decidido y qué no (dos páginas).
- [`DIRECCION_2026-11-02.md`](DIRECCION_2026-11-02.md): dónde está el proyecto y por dónde seguir.
- [`CONTEXTO.md`](CONTEXTO.md) y [`PROPIETARIOS.md`](PROPIETARIOS.md): cómo se trabaja y quién toca qué.

**VFX de hechizos (13/11/2026):**

- [`VFX_HECHIZOS_VIGENTE_2026-11-13.md`](VFX_HECHIZOS_VIGENTE_2026-11-13.md): cómo se dibuja hoy un hechizo (enganche, toys, capas, ajustes y topes).
- [`VFX_MATRIZ_COBERTURA_2026-11-13.md`](VFX_MATRIZ_COBERTURA_2026-11-13.md): qué dibuja cada elemento en cada figura y en cada tiempo, y los huecos.

Los documentos nuevos van fechados `NOMBRE_AAAA-MM-DD.md` y se enlazan desde este archivo.

> Aviso: la tabla de carpetas de abajo (`proyecto/`, `arte/`, `sistemas/`) es de la reorganización del 5/10 y **no refleja la disposición actual**: hoy los documentos están sueltos en `docs/`, con `qa/`, `Playtests/`, `capturas/` y `maqueta_3d/` como subcarpetas. Sin reescribir por no estar en el encargo; las rutas de abajo (`proyecto/PROPIETARIOS.md`, `poc_25d/LEEME.md`) ya no existen.

Cuatro carpetas por tema. Un documento vive en una sola; si no sabes dónde
va, es que no hace falta crearlo (regla 7 de `proyecto/PROPIETARIOS.md`).

| carpeta | qué hay | dueño |
|---|---|---|
| `proyecto/` | reglas y estado: `CONTEXTO.md`, `PROPIETARIOS.md`, `PLAN_ARREGLOS.md` (el único plan), `DIARIO.md`, `DISENO_FUTURO.md` | Pablo (el diario lo escriben los dos contextos) |
| `arte/` | dirección de arte y assets: `ARTE.md`, `ASSETS_PENDIENTES.md`, `PERSONAJE.md`, `ANIMACION.md`, las referencias PNG, y los borradores de hoy sobre estilo | Pipeline |
| `sistemas/` | contratos y guías de sistemas de juego: `NUEVOS_SISTEMAS.md`, `ESTADOS_SUELO.md`, `runas.png`, y los borradores de técnicas para la maqueta 3D | Juego (lo que es contrato lo lee el Pipeline) |
| `qa/` | lo medido: `QA_ARTE.md`, `TEST2_CONCLUSIONES.md`, `playtests/` (un archivo por sesión de juego) | Juego; los playtests, Pablo |

Fuera de `docs/`, en la raíz: `ARQUITECTURA.md` (lo que el código hace hoy) y
`README.md`. El contrato del pipeline con Godot está en
`export_godot/CONTRATO_GODOT.md`, y el estado de la maqueta 3D en
`poc_25d/LEEME.md`.

**Borradores.** Los documentos creados el 5/10 que no aparecen en la tabla
de `proyecto/PROPIETARIOS.md` §7 están en su carpeta de tema pero son
borradores: su dueño los integra en los vivos y los borra.

- [Previsión durante el casteo](PROPUESTA_PREVISION_CASTEO_2026-11-22.md): siluetas funcionales durante la preparación y verificación.
- [Combustión de objetos](COMBUSTION_OBJETOS_2026-11-24.html): telaraña y barril de madera, frente desde el impacto, llamas de superficie, apagado y restos; laboratorio y lámina de seis fases.
- [Revisión de interacciones](REVISION_INTERACCIONES_2026-11-24.html): 251 comprobaciones, nueve capturas y prioridades; colmena vacía, cuerda ardiendo y discrepancia de la seta resonante.
- [Colmena y cuerda: revisión aplicada](COLMENA_CUERDA_2026-11-24.html): panal y soporte separados por código, estado vacío consistente al recargar y cuerda con combustión progresiva; ocho capturas.
- [Reacciones de setas](REACCIONES_SETAS_2026-11-24.html): esporas con viento, escarcha con hielo, gotas y humedad con agua; pulso seguido de viento/hielo, ingredientes y lámina de seis estados.
- [Interacciones por código: siete lotes](INTERACCIONES_CODIGO_2026-11-25.html): inventario de 28 actuaciones, componentes reutilizables, laboratorio con 18 muestras, pruebas y tanda posterior de Blender.
- [Tanda de Blender: 12 variantes](BLENDER_INTERACCIONES_2026-11-25.html): fragmentos, frutos separados, deformaciones, agotados y tapa articulada; editables y comparativas.
- [Variantes conectadas al juego](CONEXION_BLENDER_2026-11-25.html): agotamiento del cristal, restos quemados persistentes, roca destructible, caldera dañable y barril abrible; laboratorio y lámina.
- [Prueba integrada en Bosque02](REVISION_ZONA_BLENDER_2026-11-25.html): doce capturas y recarga real del nivel, con lámina, corrección de prioridad de E y carbonización parcial persistente.
- [Primera escucha de SFX](ESCUCHA_SFX_2026-11-25.html): barrido técnico actualizado de 160 entradas y seis candidatos con reproductores, variantes y notas para validar con Pablo.
- [Cambios tras validar los SFX](VALIDACION_SFX_2026-11-25.html): recortes de papel, escritura con el elemento, variantes de interfaz elegidas y piedra aprobada con nivel sutil.
- [Segunda escucha de SFX](ESCUCHA_SFX_TANDA2_2026-11-25.html): casos 7–12, pasos de madera y goblin, impacto de veneno, congelación, voltereta y muerte por tierra; variantes y notas para validar.
- [Segunda tanda aplicada](VALIDACION_SFX_TANDA2_2026-11-25.html): variantes 7–11 fijadas; veneno más grave y voltereta más discreta. Desmoronamiento del caso 12 sustituido por el recorte corto aprobado.
- [Tercera escucha de SFX](ESCUCHA_SFX_TANDA3_2026-11-25.html): casos 13–18, pasos en hierba/tierra/roca, cierre de puerta, maullidos y equipamiento; lista, variantes y notas para validar.
- [Tercera tanda aplicada](VALIDACION_SFX_TANDA3_2026-11-25.html): seis variantes aceptadas, cierre de puerta 3 dB más bajo y preescucha de las selecciones.
- [Cuarta escucha de SFX](ESCUCHA_SFX_TANDA4_2026-11-25.html): casos 19–24, rechazo de interfaz, alerta del goblin, salida de veneno, apertura de puerta, cierre de libro y daño de la jugadora.
- [Cuarta tanda aplicada](VALIDACION_SFX_TANDA4_2026-11-25.html): goblin, impacto de veneno y daño más bajos, apertura elegida, libro conservado y rechazo sutil C aprobado e integrado.
- [Quinta escucha de SFX](ESCUCHA_SFX_TANDA5_2026-11-25.html): casos 25–30, golpe y rotura de escudo, recarga lista, rechazo en el mundo y muertes de goblin y limo.
- [Quinta tanda revisada](VALIDACION_SFX_TANDA5_2026-11-25.html): ajustes 27–30 aplicados y propuestas de madera y rotura para validar los casos 25–26.
- [Rotura de madera y variedad del goblin](VALIDACION_SFX_TANDA5_REVISION2_2026-11-25.html): golpes de madera y burbuja aprobados integrados; nuevas fracturas C/D y variantes de montaje para la muerte del goblin, otros 5 dB más baja.
- [Referencia de madera y goblin aprobado](VALIDACION_SFX_MADERA_GOBLIN_2026-11-25.html): recorte de 0,9 s del vídeo de referencia para validar; tres muertes del goblin integradas a −18 dB.
- [Nueva madera y goblin corto](VALIDACION_SFX_MADERA_GOBLIN_CORTO_2026-11-25.html): 26A aceptado e integrado para madera; tres muertes del goblin cortas aceptadas, a −18 dB.
- [Sexta escucha de SFX](ESCUCHA_SFX_TANDA6_2026-11-25.html): casos 31–36, impactos de carne, piedra y limo, fractura de hielo, explosión de puzle y golpe de maza; trece muestras para validar.
- [Sexta tanda aceptada](VALIDACION_SFX_TANDA6_2026-11-25.html): seis casos aprobados; piedra con variantes 1 y 2, hielo con variante 1 y resto conservado.
- [Séptima escucha de SFX](ESCUCHA_SFX_TANDA7_2026-11-25.html): casos 37–42, apertura de libro, inventario, beber poción, recompensa de cofre, puzle resuelto y pantalla de muerte.
- [Séptima tanda revisada](VALIDACION_SFX_TANDA7_2026-11-25.html): 37–41 aceptados; opción B aceptada e integrada para la pantalla de muerte.
- [Octava escucha de SFX](ESCUCHA_SFX_TANDA8_2026-11-26.html): casos 43–48, señales generales de fuego, agua, hielo, rayo, viento y tierra; 23 variantes para validar.
- [Octava tanda revisada](VALIDACION_SFX_TANDA8_2026-11-26.html): impactos de agua 2 sutil, hielo 3, rayo 1, viento A y tierra 1; fuego A para carga y bucles de fuego ardiendo.
