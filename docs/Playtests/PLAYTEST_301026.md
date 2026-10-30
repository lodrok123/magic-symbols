# Playtest del 30/10/2026

Guía para probar en una sesión lo que se ha hecho del 26 al 30 de octubre, que ha salido de unas quince conversaciones. Está ordenada para ir de lo más aislado a lo más integrado. Calcula unos **60–75 minutos**. Cada parada indica qué abrir, qué hacer y qué decidir.

## Antes de empezar (2 min)

1. **Sincroniza.** Tu `main` local lleva 2 commits de H5 sin subir (`44b59d90` y `96d830df`). Súbelos o pide que los suban, para que el playtest sea sobre lo que hay en el remoto.
2. **Abre el proyecto en Godot.** Cada parada se lanza con **F6** sobre su escena.
3. **El registro se guarda solo.** Cada partida escribe `user://playtest_logs/run_<fecha>.jsonl` (en Windows, `%APPDATA%\Godot\app_userdata\Magic_Symbols\playtest_logs`). Al acabar, dime «analiza los logs del playtest» y los cruzo con tus notas. Así salió el fallo de la esquiva: rodabas 0,45–0,66 s antes del golpe y la ventana era de 0,25 s.
4. **Teclas útiles.** **F12** muestra las mediciones (fps, ms por fotograma, errores) y **F1** la paleta de pruebas (glifos y elementos sin dibujarlos). En el laboratorio de hechizos, **F3** abre los valores de gamefeel en vivo (entradas «S:»).
5. **Ten a mano una hoja para apuntar.** Por cada parada: qué se siente mal, qué no se entiende y qué número cambiarías.

---

## Parada 1 · Laboratorio de hechizos: el sistema nuevo (15 min)

**Escena:** `laboratorios/LabHechizos3D.tscn`

Aquí se ve el plan del sistema de hechizos (H0–H7, `docs/PLAN_SISTEMA_HECHIZOS.md`). Construye páginas con la paleta o el panel y lanza con Espacio.

| Qué mirar | Cómo | Qué decidir |
|---|---|---|
| **H7 · el libro informa** | Abre el grimorio y monta una página. Debería mostrar coste y efecto, y lo que aportó el último glifo, sin lanzar | ¿Se entiende sin leer el manual? |
| **H3 · daño sin geometría** | Compara fuego + flecha con fuego + flecha + ᛁ ᛁ: el daño debe ser el mismo; solo los glifos ofensivos suben el daño | ¿Te parece bien que ensanchar no haga más daño? |
| **H4 · tinta por efectos** | Mira cuánto cuesta cada página según sus efectos (8 / 18 / 34) | ¿Los precios frenan lo justo? |
| **H5 · glifos nuevos** | Perforar ᚦ, retorno ᛃ, buscar ᚨ y retardo, con la paleta (sin muestras de trazo todavía) | ¿Cuál se queda? Retorno + flecha **no** golpea dos veces al mismo enemigo (diario 291): ¿debería? |
| **H6 · materia por propiedades** | Lanza elementos contra los objetos de la sala (barriles, setos, braseros): ahora reaccionan por sus propiedades, no por una lista | ¿Alguna reacción que no esperabas? |
| **Gamefeel en vivo** | F3 → entradas «S:» | Apunta los valores que cambies |

## Parada 2 · Laboratorio de geometrías (8 min)

**Escena:** `laboratorios/LabGeometrias3D.tscn`. Pulsa F1 para quitar la paleta.

- **Espacio** lanza los 8 carriles y **Tab** cambia de elemento. Los glifos se suman a todos con el panel o con el teclado numérico (Mayús resta), **Retroceso** limpia la sala e **Intro** relanza cada 3 s.
- **Tierra y hielo:** «Ancha» y «Larga» ahora **construyen**, porque antes eran un haz. Los bloques siguen el perfil del elipsoide: el borde más estrecho y más bajo.
  - ¿Se nota la forma? Se ajusta con `PERFIL_BORDE_XZ` / `PERFIL_BORDE_Y`.
- **Pasos de 0,5:** cada ᛁ suma una casilla. ¿El muro de ᛜ + 2 ᛁ tiene buen tamaño?
- **ᚱ en la superficie:** suma ᚱ, pon flecha y lanza hacia una pared. El pulso debe salir de la pared.
- **Decidir:** ya no existe el «haz de hielo» que helaba una línea de agua. ¿Hace falta para algún puzle?

## Parada 3 · Combate y gamefeel: las tres salas (20 min)

Aquí se juntan los lotes 1–4 de gamefeel (`docs/PROMPT_RESUMEN_GAMEFEEL.md`) y los enemigos E1–E3.

### Sala del limo · `escenas/PruebaSalaLimo.tscn`
- La **esquiva perfecta**: rueda con Ctrl cuando el aviso late en blanco (ventana de 0,6 s). Deberías ver la pantalla violeta, el mundo a 0,3 y tú a velocidad normal, las copias y el tic-tac. **Es lo primero que hay que confirmar**, porque no se había notado.
- Polvo al aterrizar, «¡Crece!» y «¡Hundido!» en grande.
- **Decisiones del limo pendientes:** ¿el golpe que lo tiñe le hace daño? ¿El teñido tiene debilidad? ¿60 de vida es poco?

### Sala del chamán · `escenas/PruebaSalaChaman.tscn`
- **Lote 3:** respingo al golpear, flecha roja en el borde cuando ataca uno fuera de pantalla, y **música de combate** que entra y sale con el remate al limpiar la sala.
  - ¿La música vale o se cambia por una grabada?
- **Lote 4:** el cuerpo golpeado suena; hay latido y aviso con poca vida; la voltereta deja polvo y su recarga se ve; la cámara se adelanta; andar tiene arranque; aro de carga al apuntar.
- **Equilibrio:** dijiste que los goblins caen muy rápido. Cuenta cuántos golpes aguanta un guerrero. ¿Hay que matar primero al chamán?

### Sala del gólem · `escenas/PruebaSalaGolem.tscn`
- El mazazo levanta polvo y la cámara tiembla un poco.
- **Decisiones pendientes:** ¿la lava no gasta tinta? ¿El tamaño de la zona del golpe y la ventana del núcleo están bien?

## Parada 4 · Sala del empuje (5 min)

**Escena:** `escenas/PruebaSalaEmpuje.tscn`. Tiene bloques de piedra y hielo con peso, en cuatro salas. ¿El empuje se siente pesado y claro?

## Parada 5 · Niveles de puzle (15 min)

Llevan tiempo pendientes de que los juegues.

- **Cueva Resonante** (`escenas/PruebaCuevaResonante.tscn`, pulso ᚱ):
  - ¿Se ve el brasero tras la reja del nicho de C1?
  - ¿Se entiende que el receptor de C5 abre la reja del oeste?
  - ¿Los 25 s de la reja están bien?
  - Ojo: cambia con lo de hoy, porque el pulso de una flecha sale ahora de la pared que toca.
- **Gruta Batida** (`escenas/PruebaGrutaBatida.tscn`, solo con fuego; tótems guardianes que enseñan la barrera ᛜ):
  - ¿Se entiende sin texto lo de tótem, hilo y llama tras la reja?
  - ¿Dos golpes por arquero está bien?

## Parada 6 · Bosque, el juego entero (10 min)

**Escena principal:** `escenas/PruebaBosque01_v01.tscn` (F5). Es para ver que todo convive: base de datos F0–F4, botín, consumibles y estados del mundo.

- **Botín:** los enemigos sueltan oro y objetos. El oro salta y se imanta.
- **Hoguera:** pulsa E junto a una fogata encendida. Guarda la partida y descubre las recetas de síntesis. Todavía no hay pantalla de síntesis; solo se avisa.
- **Consumibles:** Q usa el equipado y R cambia de consumible (poción, antídoto…).
- Apunta cualquier error que salga en F12.

---

## Al acabar

1. Dime «analiza los logs del playtest». Leo los `run_*.jsonl` de hoy y te devuelvo:
   - cuánto duraste en cada sala y cuánto daño recibiste;
   - cuántas esquivas hiciste y a cuánto del golpe;
   - qué hechizos y qué elementos usaste;
   - errores y caídas de fps.
2. Con eso y tus notas actualizo PENDIENTES y propongo los ajustes de números. Los números de gamefeel están todos en `presentacion/sensacion_3d.gd`.

### Pruebas automáticas conocidas que fallan (no son del playtest)
- `prueba_mapa_abierto` 8: ya fallaba antes de estos cambios.
- `escenario_playtest_eow` 1.12–1.13: el goblin ardiendo no prende el seto. Falla igual con todo el gamefeel apagado, así que no viene de estos cambios; hay que mirarlo aparte.
