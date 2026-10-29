# Tumble Rush — Temporada 1

Carrera de obstáculos en 3D estilo _Fall Guys_, hecha con **Godot Engine 4.7** (Forward Plus), **GDScript** y física **Jolt**.

La iteración 3 convierte la primera versión en un juego con sensación moderna: coyote time, salto bufferizado, cámara con SpringArm, hitstop, resultados con medallas, perfil persistente, ajustes, arte con postproceso y un modo de carrera contra bots con clasificación por rondas.

La iteración 4 añade **cinco personajes seleccionables** (con vista previa 3D y skins aleatorios para los bots), una **flecha estilo FIFA** sobre el jugador, **pasos y saltos con sonido** para todos los corredores, **sonidos de obstáculos** (viento, cañón, balancín, trampolín y martillos), una **canción nueva que solo suena en el menú**, un **arco de meta** nuevo con confeti y un **icono de juego** propio.

La iteración 5 ordena la experiencia: el menú se queda con **dos modos** (carrera clásica y torneo con bots) y un **submenú Personaje** donde el corredor de serie empieza desbloqueado y el resto se compra con monedas. Las **monedas se reparten según el tiempo y el puesto**, la vista previa enseña al personaje entero, la meta pasa a ser un **pórtico limpio**, la flecha del jugador deja de estar duplicada, el respawn del pasillo de cintas cae sobre plataforma firme, el balancín desemboca en una **rampa pisable** hacia su landing y la tabla volcada **desliza a los bots igual que al jugador**.

La iteración 6 convierte el menú en un **lobby estilo Fall Guys** con acabado de **pegatina 3D**: fondo de **degradado neón** (magenta → violeta → cian) sin líneas, paneles violeta con **borde blanco grueso** y **sombra sólida** desplazada (sin desenfoque), botones **inclinados** con esquinas asimétricas, tipografía redondeada **Baloo 2 ExtraBold** con contornos y un **JUGAR!** magenta enorme que **se hunde** al pulsarlo. El corredor equipado gira en 3D sobre su peana magenta, y el lobby incluye tarjeta de **temporada con progreso al oro** e insignia de monedas. El juego es **Tumble Rush** (el perfil anterior se migra solo) y al cruzar la meta suena una **canción de victoria** sobre la pantalla de resultados.

La temporada de torneo añade **tres circuitos completos**: **Pivot Push** retematizado en azul real, magenta y oro, **Spin Go Round** en cian y naranja, y **Pivot Panic** en magenta y oro. Cada ronda tiene su propio récord, sus medallas, sus checkpoints y una ruta de bots. Pivot Push estrena un balancín; Spin Go Round mezcla barridos, plataforma móvil, disco giratorio y lluvia de bolas; Pivot Panic encadena balancín, péndulos, viento, cañón y trampolín final. Los detalles están en `documentacion/Torneo_tres_circuitos.md`.

La última pasada hace tres cosas: los **corredores miden 1,25 m** (escala de juguete) para que los circuitos parezcan enormes, la **carrera clásica deja elegir entre los tres circuitos** desde el panel de modos (y lo recuerda en el perfil) y las **caídas de los bots son honestas**, porque vuelven a su último checkpoint en vez de aparecer en el siguiente. El único empujón hacia delante que queda es el último recurso, cuando un tramo se le atraganta a un bot.

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
| Pausa             | `Escape`    | `Start`          |

El salto es de **altura variable**: mantener el botón salta más alto; soltarlo recorta el ascenso. No hay deslizamiento: la única forma de esquivar un obstáculo es correr y saltar.

## Características

### Personajes

- **Diez personajes animados del *Ultimate Animated Character Pack* de Quaternius (CC0)**: Chef, Obrero, Cowboy, Ninja, Pirata, Vikingo, Kimono, Soldado, Ejecutivo y Caballero. Todos traen idle, andar, andar con carrera acelerada, caída y celebración: no queda ningún cuerpo tieso, sin esqueleto.
- **Dos cuerpos por personaje, un solo personaje**: cada entrada del catálogo trae su versión **masculina y femenina**. Se desbloquea una vez, ocupa una fila del menú y se elige una vez; el jugador corre siempre con uno de los dos cuerpos (se sortea al arrancar y se mantiene toda la sesión) y los bots se reparten entre ambos, así que en la parrilla se ven los dos.
- **Submenú Personaje** con una tarjeta por corredor, **vista previa 3D** girando con el personaje entero en cuadro y el estado de cada uno (elegido, libre o su precio).
- **Desbloqueos con monedas**: **Chef** es gratis y el resto cuesta de 200 a 1000 monedas; la compra se guarda en el perfil y el personaje equipado se usa en la siguiente carrera. Un personaje bloqueado no se puede equipar, y desbloquear uno abre sus dos cuerpos.
- **Bots con personaje y cuerpo aleatorios** entre todo el catálogo, así que cada carrera tiene una panda distinta.
- **Flecha dorada única sobre la cabeza del jugador** (gira y flota) para distinguirlo de los bots, como en FIFA.

### Movimiento y cámara

- **Coyote time** y **jump buffer** para que los saltos en bordes y las pulsaciones justas se sientan justas.
- **Hang en el ápice** con gravedad reducida y caída más rápida al bajar.
- **Herencia de velocidad** de plataformas móviles al saltar.
- **Aturdimiento** con pérdida temporal de control, estrellas, flash y sacudida.
- **Hitstop** y *slow motion* en impactos y meta.
- **Cámara con SpringArm3D** (no atraviesa paredes), FOV dinámico por velocidad/caída, *look-ahead* y sacudida ajustable.
- **Mando** con stick y botones A/X/Start.

### Carrera y progresión

- Carrera cronometrada con **cuenta atrás**, **splits por checkpoint** y comparación con el récord.
- **Checkpoints** con respawn y penalización (+2,5 s por caída); se marcan con una banda luminosa en el suelo, sin arco. Pivot Push y Pivot Panic tienen 5; Spin Go Round tiene 3.
- **Medallas oro/plata/bronce por circuito** (Pivot Push 70/95/130 s, Spin Go Round 42/58/78 s, Pivot Panic 62/84/112 s) y pantalla de **resultados** con tiempo, récord, medalla, splits, monedas y caídas.
- **Monedas según tiempo y puesto**: 10 de base + medalla (40/25/10) + 1 por cada 2,5 s por debajo del tiempo de bronce (máx. 40) + puesto en los modos con bots (1º 40, 2º 25, 3º 15, resto 5). El resultado muestra el desglose.
- **Perfil persistente** en `user://profile.json`: récord, medallas, monedas, estadísticas, ajustes y tutorial. Migra automáticamente el antiguo `user://best_time.save` y el perfil de las carpetas de datos de versiones anteriores.
- **Tutorial** de primera vez y **menú de pausa** con reinicio desde checkpoint, reinicio de carrera y ajustes.

### Modos

- **Carrera clásica**: contrarreloj y récord personal en **el circuito que elijas**. El panel de modos lista Pivot Push, Spin Go Round y Pivot Panic con su nombre real, el elegido queda marcado y se guarda en el perfil; cada circuito conserva su propio récord, sus medallas y sus checkpoints.
- **Torneo con bots**: 7 bots recorren el circuito, hay ranking en vivo y clasifican los 3 primeros; al clasificarse, el panel de resultados ofrece "Siguiente ronda", con más bots, bots más rápidos y menos plazas cada ronda. El torneo tiene **tres rondas** (Pivot Push → Spin Go Round → Pivot Panic) y termina en la final.
- **Bots que caen como el jugador**: siguen la ruta de cada circuito, esperan a plataformas, barridos y péndulos, esquivan las bolas y se apartan de los carriles peligrosos. Cuando uno **cae al vacío vuelve a su último checkpoint**, nunca al que perseguía: la caída cuesta el tramo. Solo si el tramo se le atraganta dos veces (o se queda atascado sin caerse) recibe un empujón de seguridad al punto siguiente, para que la carrera no se quede colgada. **Los obstáculos les afectan igual**: el túnel de viento los arrastra de lado, el cañón dispara a cada uno en el momento en que pisa el gatillo (sin cola de espera, así que un grupo que llega junto vuela entero) y la tabla volcada del balancín los desliza como al jugador.

### Contenido y obstáculos

**Pivot Push** (~211 m, 5 checkpoints) conserva los 13 tramos originales y añade un **balancín** entre las cintas y los martillos: la tabla de 13 × 10 m se nivela con el peso en el centro y vuelca hacia el lado cargado; la punta baja conecta con una rampa y un landing practicables. La paleta pasa a azul real, magenta, rosa claro y oro.

**Spin Go Round** (~85 m, 3 checkpoints) es la ronda corta: arena de barridos, pasarela con **plataforma móvil**, tramo de **peonzas** con disco giratorio y lluvia de bolas, y meta con arco a cuadros. Usa cian, azul, naranja, magenta y lima.

**Pivot Panic** (~150 m, 5 checkpoints) es la final: barrido de entrada, **balancín** bajo un gran bastidor dorado, avenida de **cuatro péndulos**, plataforma móvil, **puente del viento** con dos túneles opuestos, **cañón** sobre el vacío y recta final con barrido, péndulo y **trampolín** que sube a la meta 4 m. Usa magenta intenso, rosa, azul real y oro.

Las tres escenas comparten `LevelInfo` (id, ronda, récord, medallas y ruta de bots) y se pueden regenerar con `tools/build_levels.gd`. El atrezo incluye una **pelota de playa CC-BY** de Poly Pizza en los dos circuitos nuevos.

### Arte y presentación

- **Shaders propios**: toon de bandas + rim + brillo de globo (`toy.gdshader`) en obstáculos y multitud; el mismo acabado plástico en los corredores (`character.gdshader`); suelos con rejilla, vetas y barrido de energía (`platform.gdshader`); mar de nubes animado bajo el circuito (`void_sea.gdshader`).
- **Postproceso** en tiempo real: viñeta, grano, aberración cromática, *split-toning* frío/cálido, desenfoque radial al correr, líneas de velocidad, dithering, tinte de aturdimiento y flash de impacto.
- **Cielo procedural** con sol, halo cálido y **dos capas de nubes** a distinta velocidad; niebla volumétrica, SSAO, SSIL, bloom y ajuste de color.
- **Personajes 3D descargados**: los 20 cuerpos del *Ultimate Animated Character Pack* de Quaternius (CC0), GLB con esqueleto y animaciones. El catálogo renombra los clips al vuelo, el jugador usa el que elige en el menú, los bots reciben personaje y cuerpo al azar y todos se escalan a la misma altura. Ver `assets/characters/README.md`. La animación suma una **capa procedural** (`scripts/character_rig.gd`): torso inclinado al esprintar, piernas y brazos recogidos en el salto y flexión al aterrizar, porque el pack no trae clips de carrera ni de salto. La parrilla de salida reparte a los ocho corredores en **cuatro columnas y dos filas** (3 m y 2,2 m de separación) sobre una **plataforma de salida más ancha** (17–19 m, con vallas y arco recolocados), para que la piña del pistoletazo no se vea apelmazada.
- **Escenografía procedural** alrededor del circuito: mar de nubes, islas flotantes con cristales y árboles, arcos de neón, torres de luz, montañas lejanas, anillos de estadio, chispas ambientales, bordes luminosos y soportes en cada plataforma.
- **Multitud** en gradas laterales con `MultiMeshInstance3D`: cuerpos y cabezas pastel con el shader toon, más guirnaldas luminosas en las gradas.
- **UI pegatina 3D en el lobby y los menús**: degradado neón de fondo (magenta, violeta y cian), paneles violeta con borde blanco de 6 px y sombra sólida de 10 px sin desenfoque, botones amarillos y cian **inclinados** (`skew`) con esquinas asimétricas, y tipografía **Baloo 2 ExtraBold** con contornos oscuros o blancos. El estado pulsado reduce la sombra y baja el texto para que el botón parezca un bloque físico. El HUD de carrera conserva el tema oscuro para no tapar el juego.
- **Lobby principal**: barra superior con el logotipo, navegación y monedas, **tarjeta de temporada** con el progreso hacia el oro y el récord, **escaparate 3D** del corredor equipado girando sobre una peana magenta con base cian, insignia con el nombre del corredor y un botón **JUGAR!** magenta que abre las dos tarjetas de modo (amarilla para la carrera clásica, cian para el torneo). Al terminar cada carrera suena la canción de victoria.

## Estructura

```
proyecto/
├── audio/                  # Tema del menú, canción de victoria y 16 SFX
├── assets/characters/      # 20 cuerpos GLB CC0 de Quaternius + licencia
├── assets/props/           # Pelota de playa CC-BY de Poly Pizza + licencia
├── materials/              # Materiales toy/platform (shaders) por color
├── shaders/                # postproceso, cielo, toon, plataformas y mar
├── ui/                     # tema compartido y tipografía Baloo 2 (OFL)
├── scenes/
│   ├── main.tscn           # Pivot Push (ronda 1) + jugador + HUD + pausa
│   ├── levels/             # Spin Go Round y Pivot Panic (rondas 2 y 3)
│   ├── menu/               # menú principal, pausa y ajustes
│   ├── obstacles/          # 12 obstáculos interactivos
│   ├── player/player.tscn  # bean con cara, guantes, botas y gorro
│   ├── race/               # checkpoint, meta, HUD, kill plane, bot
│   └── ui/                 # (reservada para UI adicional)
├── exports/                # Builds generados (excluido de Git)
├── scripts/                # Un script por responsabilidad + autoloads
└── tools/                  # Tests headless, generador de audio y de niveles
```

## Verificación

Los tests headless recorren escenas, arranque, flujo completo, las novedades de las iteraciones 3 a 5 y los tres circuitos del torneo:

```bash
cd proyecto
godot --headless -s res://tools/check_scenes.gd       # 24/24 escenas OK
godot --headless -s res://tools/smoke_test.gd         # SMOKE OK
godot --headless -s res://tools/flow_test.gd          # RESULT: TODO OK
godot --headless -s res://tools/features_test.gd      # RESULT: TODO OK
godot --headless -s res://tools/iteration3_test.gd    # RESULT: TODO OK
godot --headless -s res://tools/iteration4_test.gd    # RESULT: TODO OK
godot --headless -s res://tools/iteration5_test.gd    # RESULT: TODO OK
godot --headless -s res://tools/levels_test.gd        # RESULT: TODO OK (tres circuitos)
godot --headless -s res://tools/levels_bots_test.gd   # bots terminan Spin y Pivot Panic
godot --headless -s res://tools/bots_test.gd         # 7/7 terminan (avisos conocidos)
```

`iteration3_test.gd` comprueba el salto, el túnel de viento, el cañón (que ya no tiene cooldown ni cola de espera), balancín, perfil/ajustes, medallas, cámara, HUD de resultados, tutorial y los modos con bots. `iteration4_test.gd` verifica el catálogo de personajes, el selector y la vista previa del menú, la flecha del jugador, los skins aleatorios de los bots, los SFX nuevos, que la música se apaga en carrera, la holgura de la base del balancín y las piezas de la meta. `iteration5_test.gd` valida el **lobby**, la **canción de victoria**, ambos modos, el desbloqueo de personajes, la flecha única, el respawn, el cruce del balancín a su landing y que la tabla volcada empuja a los bots. `levels_test.gd` carga los tres circuitos, comprueba `LevelInfo`, checkpoints, meta, plataformas, obstáculos propios, decoración y el flujo de rondas. `levels_bots_test.gd` recorre Spin Go Round y Pivot Panic con un bot. `bots_test.gd` simula Pivot Push con siete bots y verifica que se reparten, avanzan y terminan, que una caída al vacío devuelve al bot a **su último checkpoint** (y no al que perseguía) y que el empujón hacia delante es el último recurso (máximo uno por bot); conserva un aviso conocido: el primer waypoint se consume al arrancar. `probe_catalog.gd` recorre los **20 cuerpos** (los dos de cada personaje), imprime su altura real y falla si alguno no mide lo que pide el catálogo o si le falta un clip.

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

Genera el tema alegre del menú (`menu_theme.wav`, 38 s en bucle) y los SFX: salto, paso, checkpoint, meta, caída, aterrizaje, impacto, moneda, UI, cuenta atrás, viento, cañón, crujido del balancín, trampolín y whoosh de martillos. La música **solo suena en el menú**; durante la carrera se detiene y dejan oírse los pasos, los bots y los obstáculos, estos últimos con audio 3D atenuado por distancia. Al cruzar la meta suena `audio/music/victory.mp3` (**22 s**, recortado y normalizado a −14 LUFS) sobre el panel de resultados. Va por su propio bus `Victory`, así que se oye aunque el volumen de música esté bajo; volver al lobby o reintentar la corta.

## Documentación

- `documentacion/Primera_entrega.md` — Informe de la primera entrega.
- `documentacion/Segunda_iteracio.md` — Mapa e interacción ampliados y mejoras de física/gráficos.
- `documentacion/Tercera_iteracio.md` — Game feel, cámara, arte, perfil, contenido y modos con bots.
- `documentacion/Torneo_tres_circuitos.md` — Los tres circuitos del torneo, paletas, rutas, récords, verificación y créditos de las referencias.

## Créditos

- Autores: **Pol Arjona** e **Yazan Issa**
- Motor: [Godot Engine](https://godotengine.org) 4.7
- Pelota de playa: [beach ball](https://poly.pizza/m/4IwPTeOmq6c) de **the_ normalgamer**, licencia **CC-BY 3.0** (ver `proyecto/assets/props/README.md`).
- Referencias de mapa: [Pivot Push](https://sketchfab.com/3d-models/stumble-guys-pivot-push-map-c7abc0bdd0a8490d9f1e9c805e3c05cd) y [Spin Go Round](https://sketchfab.com/3d-models/stumble-guys-spin-go-round-map-71224cc13db44948b91b8bb43c635d5c) de **amogusstrikesback2**, **CC-BY 4.0**; usadas solo como referencia de composición y color, sin redistribuir sus mallas.
- Personajes 3D:
  - [Ultimate Animated Character Pack](https://quaternius.com/packs/ultimatedanimatedcharacter.html) de [Quaternius](https://quaternius.com), licencia **CC0** (ver `proyecto/assets/characters/ultimate/LICENSE_Quaternius.txt`).
- Tipografía: [Baloo 2](https://fonts.google.com/specimen/Baloo+2) de Ek Type, licencia **SIL OFL 1.1** (ver `proyecto/ui/fonts/OFL-Baloo2.txt`).
- IA usada en el desarrollo (ver informe en `documentacion/`).
