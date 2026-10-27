# Informe de Seguimiento — Tercera Iteración

**Proyecto:** Tumble Rush
**Autores:** Pol Arjona e Yazan Issa
**Motor:** Godot Engine 4.7.2 (Forward Plus, física Jolt)
**Lenguaje:** GDScript
**Fecha:** Octubre 2026

---

## 1. Objetivo de la iteración

La segunda entrega dejó un curso de 85 m con seis zonas, checkpoints, HUD y un personaje procedural. La tercera iteración ataca los cuatro puntos que separaban al juego de un juego con sensación moderna:

1. **Game feel**: que saltar, caer y recibir golpes se sienta justo y contundente.
2. **Presentación**: cámara, postproceso, cielo, multitud y UI con identidad.
3. **Contenido**: obstáculos nuevos y un circuito con decisiones.
4. **Meta y modos**: perfil persistente, medallas, resultados, bots y torneo.

---

## 2. Movimiento y cámara

| Sistema | Implementación | Parámetros |
| --- | --- | --- |
| Coyote time | Se conserva una ventana de salto tras abandonar el suelo | `coyote_time = 0.12 s` |
| Jump buffer | Una pulsación justo antes de aterrizar se recuerda | `jump_buffer_time = 0.12 s` |
| Ápice flotante | La gravedad se reduce cerca de la velocidad vertical cero | `apex_threshold = 2.0`, `apex_gravity_scale = 0.65` |
| Dive / prone | Impulso frontal, deslizamiento, recuperación y cooldown | `dive_speed = 9.0`, `prone_time = 0.55`, `dive_cooldown = 0.9` |
| Herencia de plataforma | La velocidad horizontal de la plataforma se suma al salto, con tope | `platform_jump_cap = 6.0` |
| Hitstop | Congela el juego ~50 ms en golpes fuertes | `GameFeel.hit_stop(0.05)` |
| Sacudida | Offset aleatorio de cámara escalado por los ajustes | `GameFeel.shake()` |
| Cámara | `SpringArm3D` con esfera de colisión, FOV dinámico y look-ahead | `6.5 m`, `-18°`, FOV 55→70 |

El aturdimiento ahora se comunica con estrellas giratorias, inclinación, flash rojo, hitstop y un tinte frío en el postproceso. Se añadió **boca**, **gorro**, **parpadeo** y pupilas al personaje.

La cámara mantiene un yaw fijo (no hay ratón) para que el control con WASD siga siendo estable, pero incorpora colisión, seguimiento suavizado, adelanto según la velocidad y zoom por FOV. El jugador deja de atravesar paredes con la cámara en los tramos estrechos.

---

## 3. Carrera, perfil y resultados

- **Cuenta atrás** 3-2-1-¡YA!: bloquea el input del jugador, deja quietos a los bots y mantiene el cronómetro a cero; reloj y carrera arrancan a la vez en el «¡YA!». En headless se omite para que los tests sigan siendo deterministas.
- **Splits** por checkpoint comparados con los del mejor tiempo guardado.
- **Medallas**: oro ≤ 70 s, plata ≤ 95 s, bronce ≤ 130 s (reajustadas al circuito largo).
- **Pantalla de resultados** con tiempo, récord, medalla, splits, monedas, caídas y botones de reintentar/menú/siguiente ronda.
- **Perfil JSON** (`user://profile.json`, versión 1) con récord, splits, estadísticas, monedas, medallas, ajustes y tutorial. Importa el antiguo `user://best_time.save`.
- **Ajustes**: volumen de música/SFX, intensidad de sacudida y pantalla completa; se aplican al instante y se guardan.
- **Tutorial** de primera vez (se muestra solo si no se ha visto y no estamos en headless).

Los ajustes se aplican mediante los buses `Music` y `SFX` creados en runtime por `AudioManager`, de modo que el volumen no depende del bus maestro.

---

## 4. Contenido nuevo

| Elemento | Escena / script | Comportamiento |
| --- | --- | --- |
| Túnel de viento | `wind_tunnel.tscn` / `wind_tunnel.gd` | Empuje lateral continuo con rachas; ventilador 3D sobre una plataforma independiente, separada del puente por un hueco y orientada con el viento. |
| Cañón lanzador | `launcher.tscn` / `launcher.gd` | Lanza al jugador (método `launch()`, sin aturdimiento) con cooldown, boca, culata y flechas de dirección. Atajo opcional en la plataforma central. |
| Balancín | `see_saw.tscn` / `see_saw.gd` | `AnimatableBody3D` real: nivelado con el peso en el centro y vuelco completo hacia el lado con carga (±0,62 rad). Un único balancín cubre el tramo sobre el vacío. |

La plataforma de aproximación a la giratoria se desplazó de `z = -40,5` a `z = -42,6` para abrir el hueco que ocupa el balancín. Las alturas del tramo de bolas se actualizaron con la rampa larga actual.

---

## 5. Arte y presentación

- **Postproceso** (`shaders/post_process.gdshader` + `post_process.gd`): viñeta, grano animado, aberración cromática, líneas de velocidad radiales, desaturación por aturdimiento y flash de color. Se dibuja por debajo del HUD.
- **Cielo con nubes** (`sky_clouds.gdshader`): cúpula de 380 m con FBM animado, degradado y opacidad configurable.
- **Entorno**: SSAO, bloom, niebla volumétrica, ajuste de saturación/contraste y tonemap ACES.
- **Multitud**: gradas y ~150 beans con `MultiMeshInstance3D` y colores pastel (`crowd.gd`).
- **Materiales**: rim light en las siete paletas y emisión suave en amarillo, naranja y rosa para que los hazards brillen con el bloom.
- **UI**: `ui/theme.tres` con botones redondeados, foco amarillo, paneles translúcidos, separadores y barra de progreso. Menú principal con degradado, título con contorno y resumen de perfil.

---

## 6. Modos con bots

- **Carrera vs bots**: 7 bots con el mismo cuerpo bean, colores aleatorios y velocidad 4,8–6,4 m/s. Recorren el circuito real por waypoints, saltan los huecos, tropiezan y se rescatan si caen o se atascan.
- **Ranking en vivo** por progreso en el eje Z y **clasificación** de los 3 primeros.
- **Torneo**: cada ronda añade un bot (hasta 11), sube un 5 % su velocidad y reduce las plazas de clasificación. El panel de resultados permite jugar la siguiente ronda.
- Los bots solo se instancian en esos modos; la carrera clásica y los tests no se ven afectados.
- Los bots resisten parcialmente el viento y las cintas (40 %) para que su ruta sea viable, pero reciben empujes de hazards (`apply_push`) y del cañón (`launch`).

---

## 7. Arquitectura

Nuevos autoloads, en orden de dependencia:

1. `SaveManager` — perfil, ajustes, monedas y medallas.
2. `GameSession` — modo/ronda y bindings de mando.
3. `GameFeel` — hitstop, slow motion, shake y flash.
4. `AudioManager` — buses, música y pool de SFX.
5. `TransitionManager` — fades y reset de game feel.

Contratos conservados para no romper la suite existente:

- `RaceManager` sigue exponiendo `elapsed_time`, `is_running`, `is_finished`, `time_penalty`, `player`, `checkpoints_total`, `checkpoints_completed`, `register_checkpoint()`, `respawn_player()` y `finish_race()`.
- El circuito se rehízo entero: 13 tramos y ~220 m, con 5 checkpoints y todos los obstáculos en uso (3 barras giratorias en pasarela estrecha, 4 cintas perpendiculares, 1 balancín, 4 péndulos, disco giratorio, 2 plataformas móviles, 2 túneles de viento, cañón, 3 dispensadores de pelotas y 6 muros).
- Rutas estables que usan los tests: `Course/BouncePadFinal`, `Course/Sweeper`, `Course/MovingPlatform`, `Course/MovingPlatform2`, `Course/BallDropper`, `Course/SpinningPlatform`, `Course/FinishLine`, `Decor/StartGateBeam` y `Decor/DistantPillarLeftA`.
- El HUD conserva `Root/TimeLabel`, `Root/CheckpointsLabel`, `Root/BestTimeLabel` y `Root/MessageLabel`.
- El menú conserva `CenterContainer/VBoxContainer/StartButton`.

Nuevos grupos: `bot`, `bots`, `race_director`, `wind_tunnels`, `launchers`, `see_saws`.

---

## 8. Verificación

Se añadió `tools/iteration3_test.gd` (dive, viento, cañón, balancín, perfil/ajustes, medallas, cámara, HUD, tutorial y modos). La batería completa es:

```bash
cd proyecto
godot --headless -s res://tools/check_scenes.gd       # 22 escenas
godot --headless -s res://tools/smoke_test.gd
godot --headless -s res://tools/flow_test.gd
godot --headless -s res://tools/features_test.gd
godot --headless -s res://tools/iteration3_test.gd
```

**Estado de esta entrega:** la batería headless se ejecutó con Godot 4.7.2. Las 22 escenas cargan correctamente y `smoke_test`, `flow_test`, `features_test`, `iteration3_test` y `bots_test` terminan en **TODO OK**.

---

## 9. Incidencias y decisiones

- **Viento como velocidad, no aceleración.** El jugador reescribe `velocity` cada frame con `_control_velocity + _external`, así que una aceleración por frame se perdía. El túnel aplica una velocidad lateral constante (2,6 m/s) como una cinta; se reduce en la instancia para que cruzar el puente sea exigente pero justo.
- **La cámara con SpringArm exigió mover los nodos.** Se sustituyó `CameraPivot/Camera3D` por `CameraPivot/SpringArm3D/Camera3D`; el `CameraPivot` sigue siendo `top_level` y el script lo reposiciona. El `SpringArm3D` excluye el RID del jugador y usa máscara `world`.
- **Orden de conexión del HUD.** `RaceManager` emite el récord en su primer frame; el HUD se conecta un frame después. Se conservó la sincronización manual de récord/checkpoints y se retrasó la cuenta atrás 0,2 s para que el “3” no se pierda.
- **Los tests no deben ver cinemáticas.** La cuenta atrás, el tutorial y el slow motion se omiten en headless (`DisplayServer.get_name() == "headless"`).
- **Bots con red de seguridad.** Un watchdog de 3 s y el rescate al caer por debajo de `y = -5` garantizan que terminen; sin él, un mal salto dejaba la carrera bloqueada.
- **Medallas y récord conviven.** El récord se guarda por carrera; las medallas se calculan sobre el tiempo final. El perfil guarda ambas cosas y los splits del mejor tiempo.
- **El balancín mueve un tramo del mapa.** Se desplazó `SpinApproach` para que el hueco y el balancín tengan sentido físico; las comprobaciones de altura existentes no se ven afectadas.

---

## 10. Limitaciones y siguientes pasos

- **Multijugador online** (ENet, servidor autoritativo y predicción) no entra en esta iteración; los bots cubren el bucle de competición.
- **Pantalla dividida local** requiere abstraer la cámara y el input por jugador; el controlador ya acepta `set_bot_drive()` como base.
- **Fantasma de la mejor vuelta**: el perfil ya guarda splits; falta grabar transformaciones y reproducir un ghost.
- **Tip Toe, Door Dash y Hex-A-Gone**: los módulos de obstáculos están listos, pero no se integraron para no alterar la geometría validada.
- **Localización ES/CA/EN**: la UI está en español; queda extraer cadenas a CSV.
- **Rendimiento**: el curso sigue usando `CSGBox3D` en runtime. El siguiente paso es hornear mallas y colisión trimesh, añadir `LightmapGI`, LOD y occlusion culling.
- **Tienda y cosméticos**: el perfil ya acumula monedas; falta la pantalla de desbloqueo y las piezas cosméticas.

---

## 11. Uso de inteligencia artificial

En esta iteración la IA (Freebuff, de Codebuff) se utilizó para:

- Diseñar el paquete de game feel (coyote, buffer, ápice, dive, herencia de plataforma) y la cámara con SpringArm.
- Diseñar y escribir los shaders de postproceso y cielo, el tema de UI y la multitud con `MultiMesh`.
- Implementar el perfil JSON con migración, los ajustes, las medallas y la pantalla de resultados.
- Implementar el túnel de viento, el cañón, el balancín, los bots con waypoints y el director de carrera con clasificación.
- Ampliar el generador de audio con seis SFX nuevos y crear el test de la iteración.

Todo el código debe validarse ejecutando la batería headless en Godot 4.7.2 antes de darlo por cerrado.
