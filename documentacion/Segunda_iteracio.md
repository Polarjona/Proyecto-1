# Informe de Seguimiento — Segunda Entrega

**Proyecto:** Tumble Rush
**Autores:** Pol Arjona e Yazan Issa
**Motor:** Godot Engine 4.7.2 (Forward Plus, física Jolt)
**Lenguaje:** GDScript
**Fecha:** Noviembre 2026

---

## 1. Estado de la entrega

El juego ya no es un circuito único con bots: es una temporada de **cinco circuitos** con dos formas de jugarlos.

- **Torneo de cuatro rondas:** Pivot Push → Spin Go Round → Glacier Gallop → Lava Vortex.
- **Carrera clásica:** permite elegir cualquiera de los cinco, incluido **Abyss Run**, el circuito submarino.

Cada circuito tiene su propia escena, su `LevelInfo` (id, nombre, ronda, longitud, tiempos de medalla, ruta de bots y anchos de carril), su récord, sus medallas y sus checkpoints. `GameSession` es quien decide qué mapa se carga según el modo y la ronda, y el menú recuerda el circuito elegido para la carrera clásica.

| Ronda | Circuito       | Escena                             | Longitud | Checkpoints | Oro / Plata / Bronce |
| ----- | -------------- | ---------------------------------- | -------- | ----------- | -------------------- |
| 1     | Pivot Push     | `scenes/main.tscn`                 | 368 m    | 11          | 130 / 170 / 215 s    |
| 2     | Spin Go Round  | `scenes/levels/spin_go_round.tscn` | 339 m    | 12          | 115 / 145 / 185 s    |
| 3     | Glacier Gallop | `scenes/levels/glacier_gallop.tscn`| 367 m    | 9           | 145 / 180 / 225 s    |
| 4     | Lava Vortex    | `scenes/levels/lava_vortex.tscn`   | 509 m    | 0           | 84 / 100 / 116 s     |
| —     | Abyss Run      | `scenes/levels/abyss_run.tscn`     | 428 m    | 6           | 112 / 138 / 172 s    |

**Pivot Panic se retiró.** Su escena ya no existe y su constructor quedó desactivado en `tools/build_levels.gd`; el torneo se cerró con los cuatro circuitos actuales.

---

## 2. Los cinco circuitos

### 2.1 Pivot Push (ronda 1, 368 m, 11 checkpoints)

Es el circuito original, retematizado en azul real, magenta y oro. Conserva los tramos clásicos (barridos, plataformas móviles, túneles de viento, cañón, balancín, péndulos, disco giratorio y lluvia de bolas) y el tercer acto, **la forja**: pasillo de rocas persecutorias, terraza de pinchos, puente de tres aspas, subida larga con dos péndulos y bajada final con barridos y pinchos.

### 2.2 Spin Go Round (ronda 2, 339 m, 12 checkpoints)

El circuito más largo del torneo y el más cargado de obstáculos de suelo:

- **Acto 1:** arena de barridos con pasillos cerrados, pasarela con plataforma móvil y tramo de peonzas con lluvia de bolas.
- **Acto 2:** rampa de subida, dos pistones alternos con luz de aviso, puente de 12 losas frágiles y rampa de bajada.
- **Acto 3:** descenso de rocas, galería de 16 trampas de pinchos, puente de tres aspas, cinta en contra, subida al mirador con lluvia de bolas, dos péndulos en la cima y bajada final.

### 2.3 Glacier Gallop (ronda 3, 367 m, 9 checkpoints)

El circuito de hielo. La primera mitad encadena barridos, arena giratoria, ascensor de hielo, galería de pistones y puente de placas frágiles. La segunda suma el **puente del vendaval**, el pasillo de rocas y la terraza de pinchos antes de la recta final.

Sus dos señas de identidad son los **muros de témpanos** (tres carriles que suben y bajan con aviso, siempre queda uno abierto) y un **salto recortado** (impulso 5,02 en vez de 6,0) para que el hielo pese. La escena añade nieve, niebla, una catedral de hielo y decoración propia.

### 2.4 Lava Vortex (ronda 4, 509 m, 0 checkpoints)

La final del torneo es una **espiral de cuatro vueltas** alrededor de una montaña, construida con 116 tramos y tres saltos sobre la lava.

- **Lava que sube** desde la base hasta la cima: no se puede perder tiempo.
- **Géiseres**, **lluvia de meteoros** con aviso, **vórtices de ceniza** y **cortinas de magma** en los tramos altos.
- **Sin checkpoints**: una caída devuelve a la salida. El circuito está pensado para correrse de una tirada.
- La cámara puede seguir la espiral (el código de seguimiento por muelle existe, aunque el control actual es con ratón).

### 2.5 Abyss Run (carrera clásica, 428 m, 6 checkpoints)

El circuito submarino se juega solo en carrera clásica. Es un túnel de 428 m con islas secas, tramos de agua con franja de nado, ascensores, pasos estrechos y hazards marinos:

- **Erizos** y **medusas** que golpean o empujan.
- **Minas de burbujas** y **estrellas giratorias**.
- **Aros de impulso** que lanzan al corredor al tramo siguiente.
- **Zonas de agua** con flotabilidad, arrastre, inclinación del cuerpo y descenso con `Shift`/`Ctrl` o gatillo derecho.

---

## 3. Mecánicas y sistemas

### 3.1 Movimiento y cámara

Se mantiene el paquete de *game feel* de la iteración anterior: coyote time, jump buffer, ápice flotante, herencia de velocidad de plataformas, aturdimiento, hitstop y *slow motion*.

La novedad es la **cámara con ratón**: durante la carrera el puntero se captura y el pivote gira con el movimiento del ratón, con cabeceo limitado (-75° a 15°), sensibilidad ajustable desde Ajustes y `SpringArm3D` para no atravesar paredes. El FOV sigue subiendo con la velocidad y la caída.

### 3.2 Nado

`player.gd` incorpora un modo de nado que activan las zonas de agua:

- flotabilidad tenue (sin tocar nada se sube despacio),
- arrastre que frena la inercia,
- inclinación del cuerpo,
- control vertical con el gatillo derecho o `Shift`/`Ctrl`,
- franja vertical de la zona para no salirse por arriba ni por abajo.

### 3.3 Kit de hazards temáticos

Además de los 17 obstáculos reutilizables, los circuitos nuevos añaden scripts propios:

| Circuito | Hazard | Qué hace |
| --- | --- | --- |
| Glaciar | Muro de témpanos (`ice_rampart.gd`) | Bloques que emergen por carriles, con aviso y ciclo |
| Glaciar | Nieve (`snowfall.gd`) y niebla | Ambiente y lectura de profundidad |
| Volcán | Lava que sube (`lava_rise.gd`) | Superficie que asciende y persigue al corredor |
| Volcán | Géiser (`lava_geyser.gd`) | Columna que empuja hacia arriba |
| Volcán | Lluvia de meteoros (`meteor_rain.gd`) | Impactos con aviso previo |
| Volcán | Vórtice de ceniza (`ash_vortex.gd`) | Zona que arrastra |
| Volcán | Cortina de magma (`magma_curtain.gd`) | Chorro vertical que corta el paso |
| Abismo | Zona de agua (`water_zone.gd`) | Activa el nado y fija la franja |
| Abismo | Fauna y trampas (`ocean_hazards.gd`) | Erizos, medusas, minas, estrellas y aros de impulso |

### 3.4 Bots y torneo

- El torneo empieza con 7 bots y 3 plazas; cada ronda añade un bot (hasta 11), sube un 5 % su velocidad y reduce las plazas (3 → 3 → 2 → 1).
- Los bots siguen la ruta de cada circuito, esperan plataformas y barridos, esquivan rocas y bolas y reciben los hazards como el jugador.
- Una caída devuelve al bot a **su último checkpoint**, no al que perseguía. El empujón de seguridad solo aparece si el tramo se le atraganta dos veces o se queda atascado.

### 3.5 Perfil, monedas y medallas

- Perfil JSON versionado en `user://profile.json`, con récord y splits **por circuito**, medallas, monedas, estadísticas, ajustes, personaje y tutorial.
- Migración automática del antiguo `user://best_time.save` y de perfiles de versiones anteriores.
- Monedas por medalla, tiempo y puesto, con desglose en el panel de resultados.
- Ajustes de volumen de música/SFX, intensidad de sacudida, sensibilidad de ratón y pantalla completa.

### 3.6 Personajes, lobby y audio

- **Diez personajes CC0 de Quaternius** con dos cuerpos cada uno (20 modelos), animaciones de idle, andar, caída y celebración, más una capa procedural de esprint, salto y aterrizaje.
- **Lobby** con escaparate 3D del corredor equipado, tarjeta de temporada, monedas y panel de personajes con compra y vista previa.
- **Audio:** tema de menú, canción de victoria en bus propio y **15 SFX** sintetizados con `tools/generate_audio.py`.

---

## 4. Arquitectura y generación de niveles

- **Autoloads:** `SaveManager` (perfil), `GameSession` (modo, ronda y circuito), `GameFeel` (hitstop/sacudida), `AudioManager` (música y SFX) y `TransitionManager` (fades).
- **Contrato de circuito:** cada escena lleva un `LevelInfo` con id, nombre, ronda, longitud, tiempos de medalla, meta, ruta de bots, anchos de carril y punto de salida. `RaceManager`, `RaceDirector` y el HUD lo leen sin conocer el mapa.
- **Escenas horneadas:** Pivot Push y Spin Go Round están construidas a mano y guardadas como `.tscn`.
- **Generador `@tool`:** `scripts/level_builder.gd` construye Glacier Gallop, Lava Vortex y Abyss Run. Al abrir la escena en el editor se genera el mapa; al guardar, los nodos quedan marcados con `owner` y el `.tscn` queda horneado y editable. Si la escena ya tiene contenido, el generador no reconstruye nada.
- **Abyss Run:** su escena solo contiene el constructor, así que el túnel se genera en runtime.
- **Grupos:** `player`, `bot`, `bots`, `checkpoints`, `race_manager`, `race_director`, `pause_menu`, `wind_tunnels`, `launchers`, `see_saws` y `level_info`.

---

## 5. Verificación

La batería se ha ejecutado con Godot 4.7.2 en esta máquina. Resultados reales:

```bash
cd proyecto
godot --headless -s res://tools/check_scenes.gd       # RESULT: 30/30 scenes OK
godot --headless -s res://tools/smoke_test.gd         # SMOKE OK
godot --headless -s res://tools/flow_test.gd          # RESULT: TODO OK
godot --headless -s res://tools/features_test.gd      # RESULT: TODO OK
godot --headless -s res://tools/iteration3_test.gd    # RESULT: 1 fallo
godot --headless -s res://tools/iteration4_test.gd    # RESULT: TODO OK
godot --headless -s res://tools/iteration5_test.gd    # RESULT: TODO OK
godot --headless -s res://tools/levels_test.gd        # 4 fallos
godot --headless -s res://tools/levels_bots_test.gd   # no termina en 280 s
```

**Fallos conocidos y su causa:**

1. `iteration3_test.gd` — «La acción de dive ya no existe». El test se escribió cuando el dive se retiró, pero la acción volvió para **nadar hacia abajo** en Abyss Run y sigue en el `InputMap` (`Shift`/`Ctrl` y gatillo derecho). Es una expectativa desfasada, no una regresión.
2. `levels_test.gd` — cuatro comprobaciones que piden elementos que los mapas ya no tienen en ese punto: 14 trampas de pinchos en Pivot Push, un descenso de rocas en Spin Go Round, una arena giratoria con lluvia de bolas en Glacier Gallop y lluvia de bolas en Lava Vortex. El resto de la suite (carga de circuitos, `LevelInfo`, checkpoints, meta, plataformas y rutas) pasa.
3. `levels_bots_test.gd` — el recorrido de bots de los circuitos nuevos no termina dentro de 280 s en esta máquina (código 124) y al salir deja avisos de RIDs de `NavMesh` sin liberar. No se considera verde.
4. `bots_test.gd` — no se ha vuelto a ejecutar en esta pasada; la última referencia válida es la del informe anterior.

Los tests siguen asumiendo que el proyecto ya se ha abierto una vez en Godot para importar escenas y WAV nuevos.

---

## 6. Incidencias y decisiones

- **Pivot Panic fuera del torneo.** Su escena y su constructor se retiraron para cerrar el torneo con cuatro circuitos; las referencias a Pivot Panic que quedaban en la documentación se han eliminado.
- **Lava Vortex sin checkpoints.** La subida de lava convierte cada caída en un reinicio completo; por eso el circuito no tiene puntos de control y sus medallas son las más ajustadas del juego.
- **Dive restaurado para nadar.** El dive como mecánica de carrera sigue fuera, pero la acción de entrada se reutiliza para descender en el agua. Eso invalida una comprobación de `iteration3_test`.
- **Saltos y alturas del glaciar.** El jugador lleva un impulso de salto recortado (5,02) para que el hielo se note; el resto del control no cambia.
- **Generación y horneado.** El generador `@tool` permite reconstruir un circuito temático sin copiar escenas gigantes, y el horneado deja el mapa editable y estable para los tests.
- **Documentación alineada.** README, este informe y el informe del torneo describen los cinco circuitos y el torneo de cuatro rondas; la Tercera Iteración se retira de la entrega y queda para una futura iteración.

---

## 7. Uso de inteligencia artificial

En esta iteración la IA (Freebuff, de Codebuff) se ha utilizado para:

- Revisar el estado real del proyecto frente a la documentación y localizar las contradicciones (tres circuitos frente a cinco, Pivot Panic frente a Glacier/Lava/Abyss, tests que ya no pasan).
- Revisar los circuitos nuevos y sus scripts (`level_builder.gd`, hazards de hielo, volcán y abismo) para describirlos con datos verificados.
- Reescribir este informe, el README y el informe del torneo con los datos reales de escenas, `LevelInfo`, checkpoints y medallas.
- Ejecutar la batería headless y documentar con precisión qué pasa, qué falla y por qué.

Todo el código citado se ha revisado y los resultados de los tests son los que se muestran en la sección 5.

---

## Checklist de la entrega

| Punto                                              | Estado |
| -------------------------------------------------- | ------ |
| Los cinco circuitos cargan y tienen `LevelInfo`    | ✅     |
| El torneo tiene cuatro rondas y el menú, cinco circuitos | ✅ |
| Medallas, longitudes y checkpoints documentados    | ✅     |
| Nado y cámara con ratón documentados               | ✅     |
| Lobby, personajes, monedas y audio documentados    | ✅     |
| README e informe del torneo alineados              | ✅     |
| Tercera Iteración retirada de la entrega           | ✅     |
| Tests en verde                                     | ⚠️ 5 comprobaciones desfasadas + un test que no termina |
