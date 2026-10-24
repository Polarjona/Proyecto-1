# Stumble Guys — Prototipo (Iteración 3)

Prototipo de carrera de obstáculos en 3D estilo _Stumble Guys / Fall Guys_, hecho con **Godot Engine 4.7** (Forward Plus), **GDScript** y física **Jolt**.

La iteración 3 convierte el prototipo en un juego con sensación moderna: coyote time, salto bufferizado, dive, cámara con SpringArm, hitstop, resultados con medallas, perfil persistente, ajustes, coronas, arte con postproceso y un modo de carrera contra bots con clasificación por rondas.

## Cómo ejecutar

1. Abre Godot 4.7 e importa la carpeta `proyecto/` (el archivo `project.godot`).
2. Pulsa **Play (F5)**.

## Generar un ejecutable

El proyecto incluye `proyecto/export_presets.cfg` con presets de _release_ para **Linux** y **Windows** (x86_64), ambos con el PCK incrustado, así que cada build es **un único archivo autocontenido**. Requiere las _export templates_ de Godot 4.7.2 instaladas.

```bash
godot --headless --path proyecto --export-release "Linux" exports/linux/StumbleGuys.x86_64
godot --headless --path proyecto --export-release "Windows Desktop" exports/windows/StumbleGuys.exe
```

Los artefactos quedan en `proyecto/exports/` (excluido de Git).

## Controles

| Acción            | Teclado     | Mando            |
| ----------------- | ----------- | ---------------- |
| Moverse           | `W A S D`   | Stick izquierdo  |
| Saltar            | `Espacio`   | `A` / Cruz       |
| Dive (deslizarse) | `Shift`     | `X` / Cuadrado   |
| Pausa             | `Escape`    | `Start`          |

El salto es de **altura variable**: mantener el botón salta más alto; soltarlo recorta el ascenso. El dive lanza al jugador hacia delante y lo deja tumbado unos instantes: es rápido, pero se pierde control.

## Características

### Movimiento y cámara

- **Coyote time** y **jump buffer** para que los saltos en bordes y las pulsaciones justas se sientan justas.
- **Hang en el ápice** con gravedad reducida y caída más rápida al bajar.
- **Dive / prone** con deslizamiento, recuperación y **cooldown de 1,6 s** indicado en el HUD ("Deslizar listo" / "Deslizar en 0,9 s").
- **Herencia de velocidad** de plataformas móviles al saltar.
- **Aturdimiento** con pérdida temporal de control, estrellas, flash y sacudida.
- **Hitstop** y *slow motion* en impactos y meta.
- **Cámara con SpringArm3D** (no atraviesa paredes), FOV dinámico por velocidad/caída, *look-ahead* y sacudida ajustable.
- **Mando** con stick y botones A/X/Start.

### Carrera y progresión

- Carrera cronometrada con **cuenta atrás**, **splits por checkpoint** y comparación con el récord.
- **Cinco checkpoints** con respawn y penalización (+2,5 s por caída); se marcan con una banda luminosa en el suelo, sin arco.
- **Medallas oro/plata/bronce** (70 s / 95 s / 130 s) y pantalla de **resultados** con tiempo, récord, medalla, splits, monedas y caídas.
- **Perfil persistente** en `user://profile.json`: récord, medallas, monedas, coronas, estadísticas, ajustes y tutorial. Migra automáticamente el antiguo `user://best_time.save`.
- **Tres coronas** coleccionables repartidas por el circuito, persistentes entre partidas.
- **Tutorial** de primera vez y **menú de pausa** con reinicio desde checkpoint, reinicio de carrera y ajustes.

### Modos

- **Carrera clásica**: contrarreloj y récord personal.
- **Carrera vs bots**: 7 bots recorren el circuito, hay ranking en vivo y clasifican los 3 primeros.
- **Torneo**: rondas sucesivas con más bots, bots más rápidos y menos plazas de clasificación. El panel de resultados ofrece "Siguiente ronda" al clasificarse.

### Contenido y obstáculos

Un único circuito de **~220 m y 13 tramos** que usa todos los obstáculos del juego, con 5 checkpoints:

1. **Salida** (plataforma azul) → salto de 2,5 m.
2. **Sala de barras** (18 m) en una pasarela de solo 9 m: dos barras barren todo el ancho en sentidos opuestos, así que no hay hueco por los lados. La primera solo te empuja; **solo la segunda aturde**. El empuje ya no te lanza de un extremo al otro.
3. **Cintas perpendiculares** (14,5 m): dos filas de cintas de 6 m de largo cruzadas al recorrido, que empujan hacia los bordes en sentidos opuestos; hay que cruzar en diagonal o te tiran al vacío.
4. **Balancín gigante**: una única tabla de 13 × 10 m sobre el vacío, girada 90° para que el eje visible y el eje real coincidan; se inclina hacia donde estás, como en Fall Guys.
5. **Avenida de martillos** (22 m, puente de 5 m): cuatro péndulos desfasados.
6. **Disco giratorio** y dos plataformas móviles seguidas; la primera está bajo una lluvia de pelotas.
7. **Puente del viento** (4 m de ancho): dos túneles en sentidos opuestos y un trampolín para la corona.
8. **Salto del cañón**: 9 m de vacío que solo cruza el cañón lanzador.
9. **Rampa de pelotas**: el antiguo corredor es ahora una subida y bajada; los dos dispensadores sueltan bolas que ruedan pendiente abajo y caen por un hueco al final de la rampa.
10. **Recta final**: barra giratoria, martillo, raíles y una cinta que empuja hacia atrás.
11. **Meta elevada**: un trampolín obligatorio al final de la recta lanza al jugador a la plataforma de meta, 4 m más arriba; sin él no se llega. Arriba queda la corona alta.

- **Tres coronas** con brillo, luz y partículas: sobre el trampolín de los balancines, en el puente del viento y sobre la meta.

### Arte y presentación

- **Shaders propios**: toon de bandas + rim + emisión (`toy.gdshader`) en obstáculos y multitud; suelos con rejilla, vetas y barrido de energía (`platform.gdshader`); mar de nubes animado bajo el circuito (`void_sea.gdshader`).
- **Postproceso** en tiempo real: viñeta, grano, aberración cromática, *split-toning* frío/cálido, desenfoque radial al correr, líneas de velocidad, dithering, tinte de aturdimiento y flash de impacto.
- **Cielo procedural** con sol, halo cálido y **dos capas de nubes** a distinta velocidad; niebla volumétrica, SSAO, SSIL, bloom y ajuste de color.
- **Personajes 3D descargados**: el jugador usa el modelo *Rogue* de **KayKit Adventurers** (CC0) con animaciones reales de idle, caminar, correr, salto, aterrizaje, caída y aturdimiento; los bots usan *Knight* y *Mage* del mismo pack. Las armas y capas se ocultan en runtime para que corran ligeros. Ver `assets/characters/README.md`.
- **Escenografía procedural** alrededor del circuito: mar de nubes, islas flotantes con cristales y árboles, arcos de neón, torres de luz, montañas lejanas, anillos de estadio, chispas ambientales, bordes luminosos y soportes en cada plataforma.
- **Multitud** en gradas laterales con `MultiMeshInstance3D`: cuerpos y cabezas pastel con el shader toon, más guirnaldas luminosas en las gradas.
- **Tema de UI propio**: interfaz oscura y minimalista, botones planos con borde fino y foco cian, paneles sobrios y barras de progreso.
- Menú principal rediseñado con degradado oscuro, separadores finos, modos, ajustes, récord, medalla, monedas y coronas.

## Estructura

```
proyecto/
├── audio/                  # Música y SFX generados (10 SFX)
├── assets/characters/      # Modelos GLB CC0 de KayKit + licencia
├── materials/              # Materiales toy/platform (shaders) por color
├── shaders/                # postproceso, cielo, toon, plataformas y mar
├── ui/theme.tres           # tema compartido de la interfaz
├── scenes/
│   ├── main.tscn           # curso + jugador + HUD + pausa + postproceso
│   ├── menu/               # menú principal, pausa y ajustes
│   ├── obstacles/          # 12 obstáculos interactivos
│   ├── pickups/            # corona coleccionable
│   ├── player/player.tscn  # bean con cara, guantes, botas y gorro
│   ├── race/               # checkpoint, meta, HUD, kill plane, bot
│   └── ui/                 # (reservada para UI adicional)
├── exports/                # Builds generados (excluido de Git)
├── scripts/                # Un script por responsabilidad + autoloads
└── tools/                  # Tests headless y generador de audio
```

## Verificación

Los tests headless recorren escenas, arranque, flujo completo, funciones de la iteración 2 y las novedades de la iteración 3:

```bash
cd proyecto
godot --headless -s res://tools/check_scenes.gd       # 23/23 escenas OK
godot --headless -s res://tools/smoke_test.gd         # SMOKE OK
godot --headless -s res://tools/flow_test.gd          # RESULT: TODO OK
godot --headless -s res://tools/features_test.gd      # RESULT: TODO OK
godot --headless -s res://tools/iteration3_test.gd    # RESULT: TODO OK
```

`iteration3_test.gd` comprueba dive, túnel de viento, cañón, balancín, perfil/ajustes, medallas, coronas, cámara, HUD de resultados, tutorial y los modos con bots.

> Los tests asumen que el proyecto ya se ha abierto una vez en Godot para importar las escenas y los WAV nuevos. Ejecutar sin esa caché puede hacer que `ResourceLoader.exists()` no encuentre los SFX recién generados (el juego sigue funcionando, simplemente sin ese sonido).

## Arquitectura

- **Autoloads:**
  - `SaveManager` — perfil JSON, ajustes, monedas, coronas, medallas y migración del récord.
  - `GameSession` — modo (clásico/bots/torneo), ronda y bindings de mando.
  - `GameFeel` — hitstop, slow motion, sacudida y flash globales.
  - `AudioManager` — música + pool de SFX con buses `Music`/`SFX`, pitch variable y degradación elegante.
  - `TransitionManager` — fades entre escenas y reset de `GameFeel`.
- **Señales:** `RaceManager` emite `time_updated`, `split_reached`, `checkpoint_reached`, `finished`, `respawned`, `best_time_updated`, `checkpoints_updated`, `countdown_tick`, `race_started` y `results_ready`; el HUD se suscribe.
- **Grupos:** `player`, `bot`, `bots`, `checkpoints`, `crowns`, `race_manager`, `race_director`, `pause_menu`, `wind_tunnels`, `launchers`, `see_saws`.
- **Datos:** `user://profile.json` (perfil y ajustes) y `user://best_time.save` (solo legado, se importa una vez).

## Audio

Todo el audio se sintetiza desde cero con `tools/generate_audio.py`:

```bash
cd proyecto
python tools/generate_audio.py
```

Genera 10 SFX (salto, checkpoint, meta, caída, dive, aterrizaje, impacto, moneda, UI y cuenta atrás). La música en OGG se conserva si `ffmpeg` no está instalado.

## Documentación

- `documentacion/Primera_entrega.md` — Informe de la primera entrega.
- `documentacion/Segunda_iteracio.md` — Mapa e interacción ampliados y mejoras de física/gráficos.
- `documentacion/Tercera_iteracio.md` — Game feel, cámara, arte, perfil, contenido y modos con bots.

## Créditos

- Autores: **Pol Arjona** e **Yazan Issa**
- Motor: [Godot Engine](https://godotengine.org) 4.7
- Personajes 3D: [KayKit - Character Pack: Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) de Kay Lousberg, licencia **CC0** (ver `proyecto/assets/characters/LICENSE_KayKit.txt`).
- IA usada en el desarrollo (ver informe en `documentacion/`).
