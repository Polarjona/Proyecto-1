# Informe de Seguimiento — Primera Entrega

**Proyecto:** Tumble Rush
**Autores:** Pol Arjona e Yazan Issa
**Motor elegido:** Godot Engine 4.7 (Forward Plus)
**Lenguaje:** GDScript
**Fecha:** Septiembre 2026

> **Nota:** este documento es el histórico de la **primera entrega** y se conserva tal como se entregó. El estado actual del juego (cinco circuitos, torneo de cuatro rondas, rendimiento y verificación vigente) está en `README.md` y `documentacion/Segunda_iteracio.md`.

---

## 1. Resumen del Estado y Avance

**Porcentaje de avance:** ~55 % del total del proyecto | ~32 horas invertidas de las 60 estimadas.

### Hitos cubiertos

- **Hito 1 — Idea y prototipo: COMPLETADO**
  - Definición de la propuesta: carrera de obstáculos en 3D estilo _Fall Guys_.
  - Motor elegido: Godot Engine 4.7 con física Jolt.
  - Creación del repositorio Git con la estructura de carpetas correcta (`proyecto/`, `documentacion/`).
  - Escena principal de juego configurada con iluminación, entorno y circuito completo.
  - Primeros assets: materiales de colores en `materials/`.

- **Hito 2 — Core del proyecto: COMPLETADO (mecánica principal)**
  - Mecánica de movimiento del jugador completamente implementada (movimiento 3D, salto, inercia, control de cámara).
  - Sistema de carrera con cronómetro en tiempo real.
  - Tres tipos de obstáculos funcionales: cinta transportadora, péndulo y plataforma giratoria.
  - Sistema de checkpoints y respawn.
  - HUD básico que muestra el tiempo y mensajes de feedback.
  - Física de Jolt integrada para resultados más realistas.

- **Hito 3 — UI / UX: COMPLETADO**
  - **Menú principal** (`scenes/menu/main_menu.tscn`): botones de inicio, controles, créditos y salir, récord visible y paneles informativos. Es la escena de arranque del proyecto (`run/main_scene`).
  - **Menú de pausa** (`scenes/menu/pause_menu.tscn`): se abre con `Escape`, con continuar / reiniciar / menú principal. Usa `process_mode = PROCESS_MODE_ALWAYS` y pausa el árbol con `get_tree().paused`.
  - **Mejoras de HUD:** contador de checkpoints completados (`2/3`) y récord personal visibles durante la carrera.

- **Hito 4 — Persistencia, audio y animaciones: COMPLETADO**
  - **Persistencia:** el mejor tiempo se guarda en `user://best_time.save` con `FileAccess` al cruzar la meta y se carga al inicio; se muestra en el menú principal y en el HUD.
  - **Audio:** `AudioManager` (autoload) con música en bucle y pool de 6 reproductores para SFX (salto, checkpoint, meta, caída). Comprueba la existencia de los archivos y omite la reproducción si no están (degradación elegante). Los archivos de audio ya están incluidos en el repositorio, generados desde cero con `tools/generate_audio.py`.
  - **Animaciones:** animaciones procedurales del personaje (idle con bob, carrera con rebote según velocidad, salto con estiramiento y _squash_ al aterrizar) en `player.gd`.
  - **Transiciones de pantalla:** `TransitionManager` (autoload) con fade a negro entre escenas.
  - **Feedback visual:** ráfaga de partículas verdes al activar cada checkpoint, confeti amarillo al cruzar la meta y animación de «pop» en la barra del checkpoint.

### Objetivo de la entrega

El prototipo cumple todo el ciclo pedido para la primera entrega: el jugador arranca desde un **menú principal**, inicia la carrera con **transición fade**, corre por las tres zonas de obstáculos, activa **checkpoints con feedback visual y sonoro**, puede **pausar** en cualquier momento, y al llegar a la meta el tiempo se registra y el **récord se guarda en disco** y se muestra en el menú. El núcleo jugable (core loop) y toda la capa de UI/persistencia/feedback son funcionales.

---

## 2. Implementación del MVP y Funcionalidad Central

### Mecánica principal

El jugador controla un personaje en 3D desde una perspectiva de cámara en tercera persona fija. El circuito es lineal e incorpora tres zonas de obstáculos secuenciales que el jugador debe superar para llegar a la meta:

1. **Cinta transportadora** — empuja al jugador lateralmente; requiere compensar la fuerza para mantener la trayectoria.
2. **Péndulo oscilante** — un martillo que gira y lanza al jugador si colisiona con él.
3. **Plataforma giratoria** — una plataforma que gira sobre el eje Y; el jugador debe mantener el equilibrio.

**Estado:** totalmente funcional. Las colisiones, el movimiento y las respuestas físicas funcionan sin errores graves.

### Flujo de juego completo

```
Menú principal → INICIAR (fade) → Carrera → [Escape → Pausa] → Meta
                                      ↑                    │
                                      └── Reiniciar ───────┘
                                └── Menú Principal (fade) ─┘
```

### Estructura de escenas

| Escena                                    | Estado       | Descripción                                                                   |
| ----------------------------------------- | ------------ | ----------------------------------------------------------------------------- |
| `scenes/menu/main_menu.tscn`              | ✅ Operativa | Menú principal: iniciar, controles, créditos, salir, récord                   |
| `scenes/menu/pause_menu.tscn`             | ✅ Operativa | Menú de pausa (CanvasLayer): continuar, reiniciar, menú                       |
| `scenes/main.tscn`                        | ✅ Operativa | Escena principal de juego: circuito, jugador, obstáculos, HUD, RaceManager, PauseMenu |
| `scenes/player/player.tscn`               | ✅ Operativa | Personaje jugable con CharacterBody3D y animación procedural                  |
| `scenes/obstacles/conveyor.tscn`          | ✅ Operativa | Cinta transportadora (Area3D)                                                 |
| `scenes/obstacles/pendulum.tscn`          | ✅ Operativa | Péndulo con AnimatableBody3D                                                  |
| `scenes/obstacles/spinning_platform.tscn` | ✅ Operativa | Plataforma rotatoria                                                          |
| `scenes/obstacles/wall.tscn`              | ✅ Operativa | Pared estática de límite                                                      |
| `scenes/race/checkpoint.tscn`             | ✅ Operativa | Punto de control (Area3D) con partículas one-shot                             |
| `scenes/race/finish_line.tscn`            | ✅ Operativa | Línea de meta (Area3D) con confeti                                            |
| `scenes/race/hud.tscn`                    | ✅ Operativa | HUD: tiempo, checkpoints, récord y mensajes                                   |
| `scenes/race/kill_plane.tscn`             | ✅ Operativa | Plano invisible que detecta caídas                                            |

> **Nota:** la carpeta `scenes/ui/` queda reservada para UI adicional. Las transiciones de pantalla se hacen con el autoload `TransitionManager` (no requiere escena propia).

### Cómo ejecutar el proyecto

1. Abrir **Godot Engine 4.7** e importar la carpeta `proyecto/` (archivo `proyecto/project.godot`).
2. Pulsar **Play (F5)**. La escena de arranque es `scenes/menu/main_menu.tscn`.
3. No hace falta ningún paso manual previo: al abrir el proyecto, Godot importa automáticamente la escena, los materiales y los archivos de audio.

### Controles e interacción

| Acción             | Teclado  | Teclado alternativo  |
| ------------------ | -------- | -------------------- |
| Mover hacia delante| `W`      | ↑ (flecha arriba)    |
| Mover hacia atrás  | `S`      | ↓ (flecha abajo)     |
| Mover a la izquierda| `A`     | ← (flecha izquierda) |
| Mover a la derecha | `D`      | → (flecha derecha)   |
| Saltar             | `Espacio`| —                    |
| Pausar / Reanudar  | `Escape` | —                    |

Los controles están mapeados a través del sistema de `InputMap` de Godot en el archivo `project.godot` (incluida la acción `pause`).

---

## 3. Calidad Técnica y Estructuras Básicas

### Calidad del código

El código sigue un diseño modular basado en scripts independientes, cada uno con una única responsabilidad clara:

| Script                  | Responsabilidad                                                                         |
| ----------------------- | --------------------------------------------------------------------------------------- |
| `player.gd`             | Movimiento, salto, gravedad, cámara, respawn, animación procedural, SFX de salto          |
| `race_manager.gd`       | Cronómetro, checkpoints, estado de la carrera, pausa, persistencia del récord, señales   |
| `hud.gd`                | Muestra tiempo, checkpoints, récord y mensajes; se suscribe a las señales del RaceManager |
| `checkpoint.gd`         | Detectar el paso del jugador, avisar al RaceManager, feedback (partículas + pop + SFX)   |
| `finish_line.gd`        | Detectar la llegada a meta, avisar al RaceManager, confeti + SFX                         |
| `kill_plane.gd`         | Detectar caída, SFX de caída, activar respawn                                            |
| `conveyor.gd`           | Aplicar velocidad de cinta a los cuerpos que están encima                                |
| `pendulum.gd`           | Movimiento sinusoidal del martillo, aplicar impulsos al jugador                          |
| `spinning_platform.gd`  | Rotación constante sobre el eje Y                                                        |
| `main_menu.gd`          | Navegación del menú principal, carga del récord, transición a la carrera                 |
| `pause_menu.gd`         | Grupo `pause_menu`, continuar/reiniciar/salir con transiciones                           |
| `audio_manager.gd`      | **Autoload.** Música en bucle + pool de SFX con fallback si faltan archivos              |
| `transition_manager.gd` | **Autoload.** Fade a negro y cambio de escena (`change_scene(path)`)                     |

**Buenas prácticas aplicadas:**

- Variables y funciones con nombres descriptivos en inglés.
- Comentarios de documentación con `##` en las clases y funciones clave.
- Sin código duplicado: los obstáculos comparten la interfaz `apply_push()` del jugador.
- Comunicación desacoplada mediante señales de Godot (`signal`): `time_updated`, `checkpoint_reached`, `finished`, `respawned`, `best_time_updated`, `checkpoints_updated`.
- Uso de grupos de Godot (`add_to_group`) para localizar nodos sin dependencias directas: `player`, `race_manager`, `pause_menu`, `checkpoints`.
- Autoloads para servicios globales (audio y transiciones) en lugar de singletons duplicados por escena.
- El script de la plataforma giratoria usa `AnimatableBody3D` para que `CharacterBody3D` pueda montarse correctamente mediante `move_and_slide`.
- Gestión de errores en la persistencia (`FileAccess.file_exists`, comprobación de null) y en el audio (`ResourceLoader.exists`).

### Control de versiones (Git)

- Repositorio local activo en la carpeta del proyecto.
- Se usa la estructura de carpetas requerida: `proyecto/`, `documentacion/`, `README.md`.
- Añadido **`.gitignore`** en la raíz que excluye `proyecto/.godot/` (caché del editor y shaders compilados), las exportaciones (`exports/`) y los binarios de exportación (`*.exe`, `*.pck`, `*.x86_64`, `*.zip`, etc.).

### Estructura del repositorio

```
.
├── README.md                   # Cómo ejecutar, controles, características y arquitectura
├── .gitignore                  # Excluye .godot/, exports/ y binarios de exportación
├── documentacion/
│   └── Primera_entrega.md      # Este informe de seguimiento
└── proyecto/                   # Proyecto de Godot (detallado a continuación)
```

### Árbol de assets

```
proyecto/
├── icon.svg                    # Icono del proyecto (Godot por defecto)
├── project.godot               # Configuración (autoloads, InputMap, escena inicial)
├── audio/                      # Archivos de audio incluidos (generados con tools/generate_audio.py)
│   ├── music/                  #   background.ogg (música en bucle)
│   └── sfx/                    #   jump.wav, checkpoint.wav, finish.wav, fall.wav
├── materials/                  # Materiales de color (StandardMaterial3D)
│   ├── blue.tres, cyan.tres, lime.tres
│   ├── orange.tres, pink.tres
│   ├── purple.tres, yellow.tres
├── scenes/
│   ├── main.tscn               # Escena principal de juego (incluye PauseMenu)
│   ├── menu/
│   │   ├── main_menu.tscn      # Menú principal
│   │   └── pause_menu.tscn     # Menú de pausa
│   ├── player/player.tscn
│   ├── obstacles/
│   │   ├── conveyor.tscn
│   │   ├── pendulum.tscn
│   │   ├── spinning_platform.tscn
│   │   └── wall.tscn
│   ├── race/
│   │   ├── checkpoint.tscn     # Con CPUParticles3D one-shot
│   │   ├── finish_line.tscn    # Con CPUParticles3D de confeti
│   │   ├── hud.tscn            # Tiempo, checkpoints, récord, mensajes
│   │   └── kill_plane.tscn
│   └── ui/                     # Reservada para UI adicional
├── scripts/
    ├── player.gd
    ├── race_manager.gd
    ├── hud.gd
    ├── checkpoint.gd
    ├── finish_line.gd
    ├── kill_plane.gd
    ├── conveyor.gd
    ├── pendulum.gd
    ├── spinning_platform.gd
    ├── main_menu.gd
    ├── pause_menu.gd
    ├── audio_manager.gd        # Autoload
    └── transition_manager.gd   # Autoload
└── tools/                      # Scripts auxiliares (verificación y generación de assets)
    ├── check_scenes.gd         # Valida que las 12 escenas cargan
    ├── smoke_test.gd           # Ejecuta menú + partida en headless
    ├── flow_test.gd            # Recorre el flujo de juego completo en headless
    └── generate_audio.py       # Sintetiza la música en bucle y los 4 SFX
```

**Assets externos:** no hay ningún asset externo. Materiales, geometrías y partículas son generados proceduralmente por Godot (CSGBox3D, `StandardMaterial3D`, `CPUParticles3D`), y el sonido (música y 4 SFX) se sintetiza desde cero con `proyecto/tools/generate_audio.py`, de modo que es libre de derechos y reproducible.

---

## 4. Próximos Pasos y Gestión de Riesgos

### Completado en Hito 3 y Hito 4

- ✅ Menú principal como escena de arranque.
- ✅ Pausa con `Escape` (acción `pause` en el InputMap, `get_tree().paused`, `PROCESS_MODE_ALWAYS` en el menú).
- ✅ Marcador de checkpoints completados en el HUD.
- ✅ Persistencia del mejor tiempo con `FileAccess` (`user://best_time.save`).
- ✅ Sistema de audio completo (música + 4 SFX) con degradación elegante.
- ✅ Animaciones procedurales idle/carrera/salto con squash & stretch.
- ✅ Partículas en checkpoints y meta; transiciones fade entre escenas.
- ✅ `README.md` completo y `.gitignore`.
- ✅ Build ejecutable para Linux y Windows (`export_presets.cfg`).

### Build ejecutable (hecha)

El proyecto incluye `proyecto/export_presets.cfg` con dos presets de _release_ para **Linux (x86_64)** y **Windows Desktop (x86_64)**, ambos con el PCK incrustado (`binary_format/embed_pck=true`), de modo que generan **un único ejecutable autocontenido** sin ningún archivo adjunto:

| Plataforma     | Archivo generado                            | Tamaño |
| -------------- | ------------------------------------------- | ------ |
| Linux x86_64   | `proyecto/exports/linux/StumbleGuys.x86_64` | 72 MB  |
| Windows x86_64 | `proyecto/exports/windows/StumbleGuys.exe`  | 106 MB |

Se regeneran con Godot 4.7.2 y sus _export templates_ instaladas:

```bash
godot --headless --path proyecto --export-release "Linux" exports/linux/StumbleGuys.x86_64
godot --headless --path proyecto --export-release "Windows Desktop" exports/windows/StumbleGuys.exe
```

Ambos binarios se ejecutaron para comprobar que arrancan sin errores y que encuentran todos los recursos (escenas, materiales y audio). La carpeta `proyecto/exports/` y los binarios de exportación (`*.exe`, `*.pck`) están excluidos de Git vía `.gitignore`, así que los artefactos se entregan aparte del repositorio.

### Foco inmediato (Hito 6)

- **Vídeo demostrativo:** grabar una partida completa (menú → carrera → pausa → meta) para la entrega.
- **Audio propio (opcional):** sustituir los archivos generados por música/SFX elegidos a mano; solo hay que respetar los nombres y rutas que espera el `AudioManager`.
- **Pulido opcional:** animación visual propia del título del menú, música distinta para el menú y la carrera.

### Revisión del alcance

El alcance actual es realista y todo lo que se pedía para la primera entrega está implementado, incluido el build ejecutable. La única tarea pendiente (el vídeo demostrativo) es corta y sin riesgo técnico.

### Incidencias y desviaciones

- **Física de la cinta transportadora:** la primera implementación aplicaba la fuerza como `velocity +=` directamente, lo que entraba en conflicto con la fricción del jugador. Solucionado separando la velocidad de cinta (`_belt_velocity`) de la velocidad controlada por el jugador (`_control_velocity`) en `player.gd`, de modo que la cinta no se ve afectada por la fricción.
- **Prioridad de procesamiento del conveyor:** el conveyor tiene que procesar _antes_ que el jugador en el mismo frame físico. Solucionado estableciendo `process_physics_priority = -5` en `conveyor.gd`.
- **Cámara colgante:** inicialmente la cámara era hija del nodo del jugador y giraba con él. Solucionado poniendo el pivote de cámara en modo `top_level = true` y actualizando la posición por `lerp` en cada frame.
- **Recuento de checkpoints:** el total de checkpoints se cuenta consultando el grupo `checkpoints`, pero los nodos se añaden al grupo dentro de su `_ready()`; el `RaceManager` espera un frame (`await get_tree().process_frame`) antes de contar para evitar un total de 0.
- **Checkpoint repetido:** cruzar el mismo checkpoint varias veces incrementaba el contador. Solucionado con una bandera `_activated` en `checkpoint.gd` que hace que cada checkpoint solo se registre una vez.
- **La pausa con Escape abría y cerraba en el mismo frame:** la misma pulsación detectada por el `RaceManager` y por los botones del menú podía alternar el estado dos veces. Solucionado centralizando la detección en `pause_menu.gd` vía `_unhandled_input` (es la única acción `pause` del InputMap) y protegiendo `show_menu()`/`hide_menu()` para que ignoren llamadas redundantes.
- **Audio sin archivos:** en lugar de romperse cuando falta un archivo, el `AudioManager` hace `ResourceLoader.exists()` e imprime un mensaje en consola; el juego se mantiene jugable en silencio.
- **Error de parseo en el menú principal:** el archivo `main_menu.tscn` contenía un `sub_resource` con sintaxis inválida (`Gradient(1, 1, 1, 1)`), lo que hacía que la ventana se cerrara inmediatamente al arrancar (la escena principal no cargaba). Solucionado eliminando el recurso, que además no era usado por ningún nodo.
- **Rutas de botones del menú:** los botones «Volver» de los paneles de controles/créditos se buscaban con la ruta incorrecta (`BackButton` en lugar de `VBoxContainer/BackButton`), rompiendo el `_ready()` del menú. Solucionado corrigiendo las rutas.
- **API de prioridad física:** `physics_process_priority` no existe en Godot 4; la propiedad correcta es `process_physics_priority`. Solucionado en `conveyor.gd`.
- **Verificación automática:** se añadieron scripts de comprobación en `proyecto/tools/` (`check_scenes.gd`, `smoke_test.gd` y `flow_test.gd`) que permiten validar todas las escenas, ejecutar unos frames de juego y recorrer el flujo completo en modo headless desde consola.

### Testeo

- Pruebas manuales de movimiento: el jugador se mueve, salta y aterriza correctamente en todas las superficies del circuito.
- Pruebas de colisión: el péndulo aplica impulsos coherentes con la dirección de la oscilación.
- Pruebas de checkpoints: el jugador reaparece correctamente en el checkpoint activado más reciente al caer al plano de muerte; el contador del HUD marca `x/3` correctamente.
- Pruebas de cronómetro: el tiempo se detiene al llegar a la meta y aplica la penalización (+2,5 s) en cada respawn.
- Pruebas de límites: el jugador no puede salir del circuito lateralmente gracias a las paredes laterales del tramo de cinta.
- **Pruebas de flujo completo:** menú → carrera (con fade) → pausa/reanudar/reiniciar → meta → récord actualizado en el menú.
- **Pruebas de persistencia:** el récord se mantiene al reiniciar el juego (archivo `user://best_time.save`).
- **Pruebas de pausa:** el juego se detiene de verdad (física y cronómetro) con `Escape` y se reanuda sin errores.
- **Verificación headless:** las 12 escenas del proyecto cargan correctamente (`12/12 scenes OK`) y el test de humo ejecuta menú y partida unos frames sin ningún error de script (`SMOKE OK`).
- **Flujo de juego completo automatizado:** el test de integración `tools/flow_test.gd` recorre el juego real sin intervención humana y comprueba 14 puntos: que el botón INICIAR carga la carrera, que hay 3 checkpoints contados, que el cronómetro avanza, que el jugador se mueve con `W` y salta con `Espacio`, que cruzar un checkpoint incrementa el contador y actualiza el HUD, que cruzar la meta acaba la carrera y que caer al vacío respawnea con la penalización de +2,5 s. Resultado: `RESULT: TODO OK`.

Estas pruebas se repiten desde la raíz del repositorio con:

```bash
godot --headless --path proyecto -s res://tools/check_scenes.gd
godot --headless --path proyecto -s res://tools/smoke_test.gd
godot --headless --path proyecto -s res://tools/flow_test.gd
```

---

## 5. Uso de Inteligencia Artificial

Durante esta fase del proyecto se ha utilizado IA (Freebuff, de Codebuff) para las tareas siguientes:

- **Generación de ideas de arquitectura:** propuesta de la separación entre `_control_velocity` y `_belt_velocity` para resolver el conflicto física-cinta.
- **Documentación:** generación y actualización de este informe de seguimiento a partir del código fuente real del proyecto.
- **Detección de problemas:** identificación de la necesidad de añadir `process_physics_priority` en el conveyor y de usar `top_level = true` para la cámara.
- **Implementación de los hitos 3 y 4:** con asistencia de IA se han generado el menú principal, el menú de pausa, el `AudioManager`, el `TransitionManager`, la persistencia del récord, las animaciones procedurales y las partículas, siguiendo las convenciones ya existentes en el código (señales, grupos, scripts modulares).
- **Generación de assets de audio:** implementación de `proyecto/tools/generate_audio.py`, un sintetizador en Python que crea la música en bucle y los cuatro SFX desde cero (ondas cuadradas/triangulares, envolventes y ruido).

Todo el código ha sido revisado y comprendido por el autor. Las decisiones técnicas finales se han validado manualmente.

---

## Checklist de la entrega

| Punto                                      | Estado |
| ------------------------------------------ | ------ |
| La mecánica principal funciona             | ✅     |
| Existe una escena de juego operativa       | ✅     |
| Los controles están definidos y funcionan  | ✅     |
| El código es modular y comprensible        | ✅     |
| Existe la estructura de carpetas correcta  | ✅     |
| **Pantalla inicial (menú principal)**      | ✅     |
| **Menú de pausa**                          | ✅     |
| **Mejoras de HUD (checkpoints + récord)**  | ✅     |
| **Persistencia de datos (récord)**         | ✅     |
| **Animaciones del personaje**              | ✅     |
| **Transiciones de pantalla (fade)**        | ✅     |
| **Feedback visual (partículas)**           | ✅     |
| **Audio (música + SFX incluidos)**         | ✅     |
| **README.md completo**                     | ✅     |
| **.gitignore**                             | ✅     |
| **Build ejecutable (temporal)**            | ✅     |
