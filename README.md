# Tumble Rush — Temporada 1

Carrera de obstáculos en 3D estilo _Fall Guys_, hecha con **Godot Engine 4.7** (Forward Plus), **GDScript** y física **Jolt**.

La iteración 3 convierte la primera versión en un juego con sensación moderna: coyote time, salto bufferizado, dive, cámara con SpringArm, hitstop, resultados con medallas, perfil persistente, ajustes, arte con postproceso y un modo de carrera contra bots con clasificación por rondas.

La iteración 4 añade **cinco personajes seleccionables** (con vista previa 3D y skins aleatorios para los bots), una **flecha estilo FIFA** sobre el jugador, **pasos y saltos con sonido** para todos los corredores, **sonidos de obstáculos** (viento, cañón, balancín, trampolín y martillos), una **canción nueva que solo suena en el menú**, un **arco de meta** nuevo con confeti y un **icono de juego** propio.

La iteración 5 ordena la experiencia: el menú se queda con **dos modos** (carrera clásica y torneo con bots) y un **submenú Personaje** donde el corredor de serie empieza desbloqueado y el resto se compra con monedas. Las **monedas se reparten según el tiempo y el puesto**, la vista previa enseña al personaje entero, la meta pasa a ser un **pórtico limpio**, la flecha del jugador deja de estar duplicada, el respawn del pasillo de cintas cae sobre plataforma firme, el balancín desemboca en una **rampa pisable** hacia su landing y la tabla volcada **desliza a los bots igual que al jugador**.

La iteración 6 convierte el menú en un **lobby estilo Fall Guys** con acabado de **pegatina 3D**: fondo de **degradado neón** (magenta → violeta → cian) sin líneas, paneles violeta con **borde blanco grueso** y **sombra sólida** desplazada (sin desenfoque), botones **inclinados** con esquinas asimétricas, tipografía redondeada **Baloo 2 ExtraBold** con contornos y un **JUGAR!** magenta enorme que **se hunde** al pulsarlo. El corredor equipado gira en 3D sobre su peana magenta, y el lobby incluye tarjeta de **temporada con progreso al oro** e insignia de monedas. El juego es **Tumble Rush** (el perfil anterior se migra solo) y al cruzar la meta suena una **canción de victoria** sobre la pantalla de resultados.

## Cómo ejecutar

1. Abre Godot 4.7 e importa la carpeta `proyecto/` (el archivo `project.godot`).
2. Pulsa **Play (F5)**.

## Generar un ejecutable

El proyecto incluye `proyecto/export_presets.cfg` con presets de _release_ para **Linux** y **Windows** (x86_64), ambos con el PCK incrustado, así que cada build es **un único archivo autocontenido**. Requiere las _export templates_ de Godot 4.7.2 instaladas.

```bash
godot --headless --path proyecto --export-release "Linux" exports/linux/TumbleRush.x86_64
godot --headless --path proyecto --export-release "Windows Desktop" exports/windows/TumbleRush.exe
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

### Personajes

- **Cinco skins, todas animadas**: Coco, Menta y Nube (Kenney Mini, CC0) y Mochi y Turbo (mascotas de Quaternius, CC0). Todas traen idle, caminar, correr, salto, aterrizaje y caída: no queda ningún cuerpo tieso, sin esqueleto.
- **Submenú Personaje** con una tarjeta por corredor, **vista previa 3D** girando con el personaje entero en cuadro y el estado de cada uno (elegido, libre o su precio).
- **Desbloqueos con monedas**: **Coco** es gratis y los demás cuestan 400, 800, 1200 y 1600 monedas; la compra se guarda en el perfil y el personaje equipado se usa en la siguiente carrera. Un personaje bloqueado no se puede equipar.
- **Bots con personaje aleatorio** entre todo el catálogo, así que cada carrera tiene una panda distinta.
- **Flecha dorada única sobre la cabeza del jugador** (gira y flota) para distinguirlo de los bots, como en FIFA.

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
- **Monedas según tiempo y puesto**: 10 de base + medalla (40/25/10) + 1 por cada 2,5 s por debajo del tiempo de bronce (máx. 40) + puesto en los modos con bots (1º 40, 2º 25, 3º 15, resto 5). El resultado muestra el desglose.
- **Perfil persistente** en `user://profile.json`: récord, medallas, monedas, estadísticas, ajustes y tutorial. Migra automáticamente el antiguo `user://best_time.save` y el perfil de las carpetas de datos de versiones anteriores.
- **Tutorial** de primera vez y **menú de pausa** con reinicio desde checkpoint, reinicio de carrera y ajustes.

### Modos

- **Carrera clásica**: contrarreloj y récord personal.
- **Torneo con bots**: 7 bots recorren el circuito, hay ranking en vivo y clasifican los 3 primeros; al clasificarse, el panel de resultados ofrece "Siguiente ronda", con más bots, bots más rápidos y menos plazas cada ronda.

### Contenido y obstáculos

Un único circuito de **~220 m y 13 tramos** que usa todos los obstáculos del juego, con 5 checkpoints:

1. **Salida** (plataforma azul) → salto de 2,5 m.
2. **Sala de barras** (18 m) en una pasarela de solo 9 m: dos barras barren todo el ancho en sentidos opuestos, así que no hay hueco por los lados. **Las dos aturden por igual**, con el mismo tiempo de recuperación. El empuje ya no te lanza de un extremo al otro.
3. **Cintas perpendiculares** (14,5 m): dos filas de cintas de 6 m de largo cruzadas al recorrido, que empujan hacia los bordes en sentidos opuestos; hay que cruzar en diagonal o te tiran al vacío.
4. **Balancín gigante**: una única tabla de 13 × 10 m sobre el vacío, girada 90° para que el eje visible y el eje real coincidan; como uno real, se mantiene nivelado si estás en el centro y vuelca hacia el lado con peso, así que hay que cruzar con decisión. La tabla volcada desliza a jugador y bots, y la punta baja desemboca en una **rampa** que sube hasta la plataforma de llegada, así que el tramo se puede completar.
5. **Avenida de martillos** (22 m, puente de 5 m): cuatro péndulos desfasados.
6. **Disco giratorio** y dos plataformas móviles seguidas; la primera está bajo una lluvia de pelotas.
7. **Puente del viento** (4 m de ancho): dos túneles en sentidos opuestos, cada uno con su ventilador sobre una plataforma independiente separada del puente y orientado hacia donde sopla el viento.
8. **Salto del cañón**: 9 m de vacío que solo cruza el cañón lanzador.
9. **Rampa de pelotas**: una subida larga y empinada bajo dos dispensadores; hay que trepar esquivando las bolas que caen, que ruedan fuera de la meseta, y luego bajar la pendiente hasta la plataforma.
10. **Recta final**: barra giratoria, martillo, raíles y una cinta que empuja hacia atrás.
11. **Meta elevada**: el único trampolín del circuito, al final de la recta, lanza al jugador a la plataforma de meta, 4 m más arriba; sin él no se llega. La meta es un **pórtico limpio**: dos torres, un dintel, un cartel a cuadros con «META», una franja de suelo, focos y tres cañones de confeti.

### Arte y presentación

- **Shaders propios**: toon de bandas + rim + brillo de globo (`toy.gdshader`) en obstáculos y multitud; suelos con rejilla, vetas y barrido de energía (`platform.gdshader`); mar de nubes animado bajo el circuito (`void_sea.gdshader`).
- **Postproceso** en tiempo real: viñeta, grano, aberración cromática, *split-toning* frío/cálido, desenfoque radial al correr, líneas de velocidad, dithering, tinte de aturdimiento y flash de impacto.
- **Cielo procedural** con sol, halo cálido y **dos capas de nubes** a distinta velocidad; niebla volumétrica, SSAO, SSIL, bloom y ajuste de color.
- **Personajes 3D descargados**: dos packs libres (Kenney Mini Characters y las mascotas de Quaternius) y todos los cuerpos son GLB con esqueleto. El catálogo renombra los clips de idle, caminar, correr, salto, aterrizaje y caída al vuelo, el jugador usa el que elige en el menú, los bots reciben uno al azar y todos se escalan a la misma altura. Ver `assets/characters/README.md`.
- **Escenografía procedural** alrededor del circuito: mar de nubes, islas flotantes con cristales y árboles, arcos de neón, torres de luz, montañas lejanas, anillos de estadio, chispas ambientales, bordes luminosos y soportes en cada plataforma.
- **Multitud** en gradas laterales con `MultiMeshInstance3D`: cuerpos y cabezas pastel con el shader toon, más guirnaldas luminosas en las gradas.
- **UI pegatina 3D en el lobby y los menús**: degradado neón de fondo (magenta, violeta y cian), paneles violeta con borde blanco de 6 px y sombra sólida de 10 px sin desenfoque, botones amarillos y cian **inclinados** (`skew`) con esquinas asimétricas, y tipografía **Baloo 2 ExtraBold** con contornos oscuros o blancos. El estado pulsado reduce la sombra y baja el texto para que el botón parezca un bloque físico. El HUD de carrera conserva el tema oscuro para no tapar el juego.
- **Lobby principal**: barra superior con el logotipo, navegación y monedas, **tarjeta de temporada** con el progreso hacia el oro y el récord, **escaparate 3D** del corredor equipado girando sobre una peana magenta con base cian, insignia con el nombre del corredor y un botón **JUGAR!** magenta que abre las dos tarjetas de modo (amarilla para la carrera clásica, cian para el torneo). Al terminar cada carrera suena la canción de victoria.

## Estructura

```
proyecto/
├── audio/                  # Tema del menú, canción de victoria y 16 SFX
├── assets/characters/      # 5 skins GLB animadas (Kenney, Quaternius) + licencias
├── materials/              # Materiales toy/platform (shaders) por color
├── shaders/                # postproceso, cielo, toon, plataformas y mar
├── ui/                     # tema compartido y tipografía Baloo 2 (OFL)
├── scenes/
│   ├── main.tscn           # curso + jugador + HUD + pausa + postproceso
│   ├── menu/               # menú principal, pausa y ajustes
│   ├── obstacles/          # 12 obstáculos interactivos
│   ├── player/player.tscn  # bean con cara, guantes, botas y gorro
│   ├── race/               # checkpoint, meta, HUD, kill plane, bot
│   └── ui/                 # (reservada para UI adicional)
├── exports/                # Builds generados (excluido de Git)
├── scripts/                # Un script por responsabilidad + autoloads
└── tools/                  # Tests headless y generador de audio
```

## Verificación

Los tests headless recorren escenas, arranque, flujo completo y las novedades de las iteraciones 3, 4 y 5:

```bash
cd proyecto
godot --headless -s res://tools/check_scenes.gd       # 22/22 escenas OK
godot --headless -s res://tools/smoke_test.gd         # SMOKE OK
godot --headless -s res://tools/flow_test.gd          # RESULT: TODO OK
godot --headless -s res://tools/features_test.gd      # RESULT: TODO OK
godot --headless -s res://tools/iteration3_test.gd    # RESULT: TODO OK
godot --headless -s res://tools/iteration4_test.gd    # RESULT: TODO OK
godot --headless -s res://tools/iteration5_test.gd    # RESULT: TODO OK
godot --headless -s res://tools/bots_test.gd         # 7/7 terminan (rescates variables)
godot --headless -s res://tools/probe_catalog.gd      # catálogo: escala y clips de cada skin
godot --path . tools/audio_probe.tscn                # niveles reales de menú y fanfarria
```

`iteration3_test.gd` comprueba dive, túnel de viento, cañón, balancín, perfil/ajustes, medallas, cámara, HUD de resultados, tutorial y los modos con bots. `iteration4_test.gd` verifica el catálogo de personajes, el selector y la vista previa del menú, la flecha del jugador, los skins aleatorios de los bots, los SFX nuevos, que la música se apaga en carrera, la holgura de la base del balancín y las piezas de la meta. `iteration5_test.gd` valida el **lobby** (nombre, JUGAR, tarjetas de modo sin solapes, escaparate 3D con el personaje entero, tarjeta de temporada, fondo de degradado neón, botones pegatina con inclinación y sombra sólida, hundimiento al pulsar y tipografía propia), la **canción de victoria**, ambos modos, el desbloqueo de personajes con monedas, la flecha única, el respawn de los cinco checkpoints, el cruce real del balancín a su landing y que la tabla volcada empuja a los bots. `bots_test.gd` simula el circuito completo con siete bots y verifica que se reparten en carriles, avanzan y terminan la carrera; su presupuesto de rescates es muy estricto, así que una caída puntual de más en el tramo de plataformas puede marcar ese único aviso aunque los siete crucen la meta.

> Los tests asumen que el proyecto ya se ha abierto una vez en Godot para importar las escenas y los WAV nuevos. Ejecutar sin esa caché puede hacer que `ResourceLoader.exists()` no encuentre los SFX recién generados (el juego sigue funcionando, simplemente sin ese sonido).

## Arquitectura

- **Autoloads:**
  - `SaveManager` — perfil JSON, ajustes, monedas, medallas y migración del récord.
  - `GameSession` — modo (clásico/torneo), ronda y bindings de mando.
  - `GameFeel` — hitstop, slow motion, sacudida y flash globales.
  - `AudioManager` — tema del menú, **canción de victoria** + pools de SFX 2D/3D con buses `Music`/`SFX`/`Victory`, pitch variable y degradación elegante. La carrera corta la música; la fanfarria va por su propio bus para no quedar enterrada por el volumen de música.
  - `TransitionManager` — fades entre escenas y reset de `GameFeel`.
- **Señales:** `RaceManager` emite `time_updated`, `split_reached`, `checkpoint_reached`, `finished`, `respawned`, `best_time_updated`, `checkpoints_updated`, `countdown_tick`, `race_started` y `results_ready`; el HUD se suscribe.
- **Grupos:** `player`, `bot`, `bots`, `checkpoints`, `race_manager`, `race_director`, `pause_menu`, `wind_tunnels`, `launchers`, `see_saws`.
- **Datos:** `user://profile.json` (perfil, personaje elegido, personajes desbloqueados, monedas y ajustes) y `user://best_time.save` (solo legado, se importa una vez).

## Audio

Todo el audio se sintetiza desde cero con `tools/generate_audio.py`:

```bash
cd proyecto
python tools/generate_audio.py
```

Genera el tema alegre del menú (`menu_theme.wav`, 38 s en bucle) y 16 SFX: salto, paso, checkpoint, meta, caída, dive, aterrizaje, impacto, moneda, UI, cuenta atrás, viento, cañón, crujido del balancín, trampolín y whoosh de martillos. La música **solo suena en el menú**; durante la carrera se detiene y dejan oírse los pasos, los bots y los obstáculos, estos últimos con audio 3D atenuado por distancia. Al cruzar la meta suena `audio/music/victory.mp3` (**22 s**, recortado y normalizado a −14 LUFS) sobre el panel de resultados. Va por su propio bus `Victory`, así que se oye aunque el volumen de música esté bajo; volver al lobby o reintentar la corta.

## Documentación

- `documentacion/Primera_entrega.md` — Informe de la primera entrega.
- `documentacion/Segunda_iteracio.md` — Mapa e interacción ampliados y mejoras de física/gráficos.
- `documentacion/Tercera_iteracio.md` — Game feel, cámara, arte, perfil, contenido y modos con bots.

## Créditos

- Autores: **Pol Arjona** e **Yazan Issa**
- Motor: [Godot Engine](https://godotengine.org) 4.7
- Personajes 3D:
  - [Kenney Mini Characters](https://kenney.nl/assets/mini-characters) de Kenney, licencia **CC0** (ver `proyecto/assets/characters/mini/LICENSE_Kenney.txt`).
  - Mascotas animadas de [Quaternius](https://quaternius.com) vía [Poly Pizza](https://poly.pizza), licencia **CC0** (ver `proyecto/assets/characters/mascots/LICENSE_Quaternius.txt`).
- Tipografía: [Baloo 2](https://fonts.google.com/specimen/Baloo+2) de Ek Type, licencia **SIL OFL 1.1** (ver `proyecto/ui/fonts/OFL-Baloo2.txt`).
- IA usada en el desarrollo (ver informe en `documentacion/`).
