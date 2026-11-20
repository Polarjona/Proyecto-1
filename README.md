<p align="center">
  <img src="documentacion/banner.jpg" alt="Tumble Rush" width="100%">
</p>

# Tumble Rush — Temporada 1

Carrera de obstáculos en 3D estilo _Fall Guys_, hecha con **Godot Engine 4.7.2** (Forward Plus), **GDScript** y física **Jolt**.

El juego tiene una **temporada de circuitos**: el torneo recorre Pivot Push → Spin Go Round → Glacier Gallop → Lava Vortex y **Abyss Run** se corre en la carrera clásica. Cada circuito guarda su propio récord, sus medallas, sus checkpoints y su ruta de bots. Las longitudes, medallas y recuentos viven en la tabla única de [Datos de referencia](documentacion/Datos_circuitos.md); este README no las duplica.

La última pasada añade los circuitos temáticos nuevos: el **glaciar** (hielo y muros de témpanos), el **volcán** (espiral con lava que sube, géiseres y lluvia de meteoros) y el **abismo** (túnel submarino con nado, islas y peligros marinos). También incorpora **cámara con ratón**, **nado** en Abyss Run y un kit de hazards temáticos. **Pivot Panic se retiró**: su escena ya no existe y su constructor quedó desactivado.

## Cómo ejecutar

1. Abre Godot 4.7.2 e importa la carpeta `proyecto/` (el archivo `project.godot`).
2. Pulsa **Play (F5)**.

## Generar un ejecutable

El proyecto incluye `proyecto/export_presets.cfg` con presets de _release_ para **Linux** y **Windows** (x86_64), ambos con el PCK incrustado, así que cada build es **un único archivo autocontenido**. Requiere las _export templates_ de Godot 4.7.2 instaladas.

```bash
godot --headless --path proyecto --export-release "Linux" exports/linux/TumbleRush.x86_64
godot --headless --path proyecto --export-release "Windows Desktop" exports/windows/TumbleRush.exe
```

Los artefactos quedan en `proyecto/exports/` (excluido de Git).

## Controles

| Acción                      | Teclado               | Mando                    |
| --------------------------- | --------------------- | ------------------------ |
| Moverse                     | `W A S D`             | Stick izquierdo          |
| Saltar                      | `Espacio`             | `A` / Cruz               |
| Girar la cámara             | Ratón                 | Stick derecho            |
| Nadar hacia abajo (Abyss)   | `Shift` / `Ctrl`      | Gatillo derecho          |
| Pausa                       | `Escape`              | `Start`                  |
| Reiniciar carrera           | `R`                   | —                        |

`R` reinicia la carrera en el sitio, sin abrir la pausa. «Reiniciar carrera» y «Menú» del menú de pausa sí piden confirmación antes de tirar la partida. El salto es de **altura variable**: mantener el botón salta más alto; soltarlo recorta el ascenso. No hay deslizamiento: la única forma de esquivar un obstáculo es correr y saltar. En el agua el corredor flota despacio y se impulsa con el stick; el gatillo derecho (o `Shift`/`Ctrl`) lo hunde.

## Características

### Circuitos

La tabla vigente de rondas, escenas, longitudes, checkpoints y medallas está en [Datos de referencia](documentacion/Datos_circuitos.md#circuitos). Aquí solo se describen los circuitos:

- **Pivot Push** conserva los tramos originales y la forja: barridos, plataformas móviles, túneles de viento, cañón, balancín, péndulos, disco giratorio, lluvia de bolas, pasillo de rocas, terraza de pinchos, puente de aspas y bajada final.
- **Spin Go Round** es el circuito de obstáculos: arena de barridos, plataforma móvil sobre el vacío, peonzas y lluvia de bolas; subida con pistones y puente de losas frágiles; y un tercer acto con rocas persecutorias, galería de pinchos, puente de aspas, subida al mirador y bajada final.
- **Glacier Gallop** es el circuito de hielo: barridos y arena giratoria, ascensor de hielo, galería de pistones, puente de placas frágiles, puente del vendaval, pasillo de rocas y terraza de pinchos. Sus **muros de témpanos** (carriles que suben y bajan con aviso) son exclusivos, y el salto del jugador va recortado para que el hielo pese.
- **Lava Vortex** es una espiral alrededor de una montaña: plataforma de salida, saltos sobre la lava, géiseres, lluvia de meteoros, vórtices de ceniza y cortinas de magma. No tiene checkpoints: la lava sube y una caída devuelve a la salida, así que el circuito se corre de una tirada.
- **Abyss Run** es la carrera clásica extra: un túnel submarino con islas, zonas de agua, ascensores, pasos estrechos y peligros marinos (erizos, medusas, minas de burbujas, estrellas giratorias y aros de impulso). Se nada con flotabilidad y se bucea con el gatillo derecho.

### Personajes

- **Personajes animados del *Ultimate Animated Character Pack* de Quaternius (CC0)**: Chef, Obrero, Cowboy, Ninja, Pirata, Vikingo, Kimono, Soldado, Ejecutivo y Caballero. Todos traen idle, andar, andar con carrera acelerada, caída y celebración. El catálogo y sus recuentos están en [Datos de referencia](documentacion/Datos_circuitos.md#recuentos-de-contenido).
- **Cuerpo masculino y femenino, un solo personaje**: cada entrada del catálogo trae las dos versiones. Se desbloquea una vez, ocupa una fila del menú y se elige una vez; el jugador corre siempre con uno de los dos cuerpos y los bots se reparten entre ambos.
- **Submenú Personaje** con una tarjeta por corredor, **vista previa 3D** girando y el estado de cada uno (elegido, libre o su precio).
- **Desbloqueos con monedas**: **Chef** es gratis y el resto cuesta de 200 a 1000 monedas; la compra se guarda en el perfil y el personaje equipado se usa en la siguiente carrera.
- **Bots con personaje y cuerpo aleatorios** entre todo el catálogo.
- **Flecha dorada única sobre la cabeza del jugador** (gira y flota) para distinguirlo de los bots.

### Movimiento y cámara

- **Coyote time** y **jump buffer** para que los saltos en bordes y las pulsaciones justas se sientan justas.
- **Hang en el ápice** con gravedad reducida y caída más rápida al bajar.
- **Herencia de velocidad** de plataformas móviles al saltar.
- **Aturdimiento** con pérdida temporal de control, estrellas, flash y sacudida.
- **Hitstop** y *slow motion* en impactos y meta.
- **Cámara con ratón o stick derecho**: el pivote gira con el ratón o el stick derecho durante la carrera (sensibilidad y FOV ajustables), con `SpringArm3D` para no atravesar paredes, FOV dinámico por velocidad/caída, *look-ahead* y sacudida ajustable.
- **Nado**: flotabilidad, arrastre, inclinación del cuerpo y control vertical con el gatillo derecho en Abyss Run.
- **Mando** con ambos sticks, A/Start y gatillo derecho.

### Ajustes y accesibilidad

- **Ajustes completos**: volumen general, música y efectos; sacudida; sensibilidad; pantalla completa; **calidad gráfica** (bajo/medio/alto); **FOV** de 45° a 85°; **V-Sync**; reducir movimiento e **idioma ES/CA/EN**.
- **Dificultad asistida**: alarga el *coyote time* ×1,5, baja la penalización por caída a 1,0 s y afloja a los bots un 10 %.
- **Confirmaciones**: reiniciar carrera y volver al menú desde la pausa preguntan antes de perder el progreso; `R` reinicia directamente.
- **Tutorial guiado**: tras el panel de primera vez, tres flechas 3D marcan el primer tramo de Pivot Push (corre, salta y sigue hasta la meta).

### Carrera y progresión

- Carrera cronometrada con **cuenta atrás**, **splits por checkpoint** y comparación con el récord.
- **Checkpoints** con respawn y penalización (+2,5 s por caída, 1,0 s con dificultad asistida); se marcan con una banda luminosa en el suelo, sin arco. El número de cada circuito está en la [tabla de datos](documentacion/Datos_circuitos.md#circuitos); Lava Vortex no tiene: la lava sube y una caída devuelve a la salida.
- **Medallas oro/plata/bronce por circuito** (ver [tabla de datos](documentacion/Datos_circuitos.md#circuitos)) y pantalla de **resultados** con tiempo, récord, medalla, splits, monedas y caídas.
- **Monedas según medalla, tiempo y puesto**, con el desglose visible en el panel de resultados.
- **Perfil persistente** en `user://profile.json`: récord y splits por circuito, medallas, monedas, estadísticas, ajustes, personaje y tutorial. Migra automáticamente el antiguo `user://best_time.save` y el perfil de las carpetas de datos de versiones anteriores.
- **Tutorial** de primera vez con panel y tramo guiado, y **menú de pausa** con reinicio desde checkpoint, reinicio de carrera (con confirmación) y ajustes.

### Modos

- **Carrera clásica**: contrarreloj y récord personal en **el circuito que elijas**. El panel de modos lista todos los circuitos con su nombre real; el elegido queda marcado y se guarda en el perfil. Cada circuito conserva su propio récord, sus medallas y sus checkpoints.
- **Torneo con bots**: rondas encadenadas Pivot Push → Spin Go Round → Glacier Gallop → Lava Vortex. La configuración de bots, plazas y velocidad por ronda está en [Datos de referencia](documentacion/Datos_circuitos.md#configuracion-del-torneo). El torneo termina en la final.
- **Bots que caen como el jugador**: siguen la ruta de cada circuito, esperan a plataformas, barridos y péndulos, esquivan las bolas y se apartan de los carriles peligrosos. Cuando uno **cae al vacío vuelve a su último checkpoint**, nunca al que perseguía. Solo si el tramo se le atraganta dos veces (o se queda atascado sin caerse) recibe un empujón de seguridad, para que la carrera no se quede colgada. **Los obstáculos les afectan igual**: el túnel de viento los arrastra de lado, el cañón dispara en el momento en que pisan el gatillo y la tabla volcada del balancín los desliza como al jugador.

### Contenido y obstáculos

- **Escenas de obstáculo reutilizables**: barrido, péndulo, plataforma giratoria, pistón, losa frágil, roca persecutoria, trampa de pinchos, aspa giratoria, muro, trampolín, plataforma móvil, bola, dispensador de bolas, cinta, túnel de viento, cañón y balancín. El recuento vigente está en [Datos de referencia](documentacion/Datos_circuitos.md#recuentos-de-contenido).
- **Hazards temáticos de los circuitos nuevos**:
  - **Glaciar**: muros de témpanos por carriles, nieve y niebla.
  - **Volcán**: lava que sube, géiseres, lluvia de meteoros, vórtice de ceniza y cortinas de magma.
  - **Abismo**: zonas de agua con franja de nado, erizos, medusas, minas de burbujas, estrellas giratorias y aros de impulso.
- Los circuitos temáticos se generan con `scripts/levels/level_builder.gd` (modo `@tool`), que delega en un **kit por tema** (`glacier_kit.gd`, `volcano_kit.gd`, `ocean_kit.gd`) sobre una base común (`level_kit.gd`). Abrir la escena construye el mapa y guardarla lo hornea en el `.tscn`: los circuitos se editan ya como cualquier otro y no se generan en runtime.

### Arte y presentación

- **Shaders propios**: toon de bandas + rim + brillo de globo (`toy.gdshader`) en obstáculos y multitud; el mismo acabado plástico en los corredores (`character.gdshader`); suelos con rejilla, vetas y barrido de energía (`platform.gdshader`); mar de nubes animado bajo el circuito (`void_sea.gdshader`).
- **Postproceso** en tiempo real: viñeta, grano, aberración cromática, *split-toning* frío/cálido, desenfoque radial al correr, líneas de velocidad, dithering, tinte de aturdimiento y flash de impacto.
- **Cielo procedural** con sol, halo cálido y **dos capas de nubes** a distinta velocidad; niebla volumétrica, SSAO, SSIL, bloom y ajuste de color. Cada circuito tiene su paleta: Pivot Push (azul real/magenta/oro), Spin Go Round (cian/naranja), Glacier Gallop (hielo/cian), Lava Vortex (negro/rojo/naranja) y Abyss Run (turquesa/arena/coral).
- **Personajes 3D descargados**: los cuerpos del *Ultimate Animated Character Pack* de Quaternius (CC0), GLB con esqueleto y animaciones. El catálogo renombra los clips al vuelo, el jugador usa el que elige en el menú, los bots reciben personaje y cuerpo al azar y todos se escalan a la misma altura. La animación suma una **capa procedural** (`scripts/character_rig.gd`): torso inclinado al esprintar, piernas y brazos recogidos en el salto y flexión al aterrizar.
- **Escenografía procedural** alrededor de cada circuito: mar de nubes, islas flotantes, anillos de neón, montañas lejanas, gradas con multitud (`MultiMeshInstance3D`), guirnaldas y soportes en cada plataforma.
- **UI pegatina 3D en el lobby y los menús**: degradado neón, paneles violeta con borde blanco y sombra sólida, botones amarillos y cian inclinados, tipografía **Baloo 2 ExtraBold** con contornos. El HUD de carrera conserva el tema oscuro.
- **Lobby principal**: barra superior con logotipo, navegación y monedas, **tarjeta de temporada** con progreso hacia el oro y el récord, **escaparate 3D** del corredor equipado girando sobre su peana y un botón **JUGAR!** magenta que abre las dos tarjetas de modo (carrera clásica y torneo). Al terminar cada carrera suena la canción de victoria.

## Capturas

<p align="center">
  <img src="documentacion/capturas/menu_principal.webp" alt="Menú principal" width="49%">
  <img src="documentacion/capturas/resultados.webp" alt="Pantalla de resultados" width="49%">
</p>
<p align="center">
  <img src="documentacion/capturas/torneo_carrera.webp" alt="Salida de una carrera de torneo" width="49%">
  <img src="documentacion/capturas/pivot_push.webp" alt="Circuito Pivot Push" width="49%">
</p>

La galería completa (menú, todos los circuitos, resultados y torneo) está en [Capturas](documentacion/Capturas.md).

## Estructura

```
proyecto/
├── audio/                  # Tema del menú, canción de victoria y SFX
├── assets/characters/      # cuerpos GLB CC0 de Quaternius + licencia
├── assets/props/           # Pelota de playa CC-BY de Poly Pizza + licencia
├── materials/              # Materiales toy/platform (shaders) por color
├── shaders/                # postproceso, cielo, toon, plataformas y mar
├── ui/                     # tema compartido y tipografía Baloo 2 (OFL)
├── scenes/
│   ├── levels/             # los circuitos y los actos
│   ├── menu/               # menú principal, pausa y ajustes
│   ├── obstacles/          # obstáculos interactivos
│   ├── player/player.tscn  # corredor con personaje 3D y cámara
│   ├── race/               # checkpoint, meta, HUD, kill plane, bot
│   └── ui/                 # (reservada para UI adicional)
├── exports/                # Builds generados (excluido de Git)
├── scripts/                # Un script por responsabilidad + autoloads
│   └── levels/             # Generador de circuitos y un kit por tema
└── tools/                  # Tests headless, generador de audio, niveles y capturas
```

## Verificación

La batería headless vive en `proyecto/tools/` y se ejecuta de una vez:

```bash
cd proyecto
bash tools/run_tests.sh          # suite obligatoria
bash tools/run_tests.sh --long   # tests largos de bots
bash tools/run_tests.sh --all    # todo
```

El resultado vigente, el recuento de tests y las escenas comprobadas están en [Datos de referencia](documentacion/Datos_circuitos.md#verificacion).

- Cada test corre con `timeout`: un cuelgue **falla** en vez de colgar la máquina. Los valores por defecto están en [`proyecto/tools/README.md`](proyecto/tools/README.md).
- `proyecto/tools/test-logs/` guarda el log de cada test y un `summary.md` con la tabla de resultados.
- Un test suelto: `godot --headless --path . -s res://tools/levels_test.gd`.
- Los tests asumen que el proyecto ya se ha abierto una vez en Godot para importar las escenas y los WAV nuevos. Sin esa caché, `ResourceLoader.exists()` puede no encontrar los SFX recién generados (el juego sigue funcionando, solo sin ese sonido).
- El test de bots de los circuitos corre sin jugador en la escena: si el jugador se queda quieto, la lava de Lava Vortex lo quema a los pocos segundos y la carrera se congela, que no es lo que la prueba mide.

### CI

`.github/workflows/tests.yml` corre en cada push y en cada pull request con dos jobs que comparten la acción `.github/actions/setup-godot`:

- **Suite headless** — la batería obligatoria (`bash tools/run_tests.sh`), con `timeout-minutes: 20`. Si falla, la CI está en rojo.
- **Tests largos (bots)** — `bash tools/run_tests.sh --long`: los bots recorren los circuitos generados. También bloquea si falla.

El binario de Godot (~50 MB) se descarga una vez por versión y se reutiliza desde la caché; la importación del proyecto (`proyecto/.godot`) se cachea por huella de recursos. El resumen de cada job se publica en la página del workflow y los logs quedan como artefacto.

## Arquitectura

- **Autoloads:**
  - `SaveManager` — perfil JSON, ajustes, monedas, medallas y migración del récord.
  - `GameSession` — modo (clásico/torneo), ronda, circuito elegido y bindings de mando.
  - `GameFeel` — hitstop, slow motion, sacudida y flash globales.
  - `AudioManager` — tema del menú, **canción de victoria** + pools de SFX 2D/3D con buses `Music`/`SFX`/`Victory`, pitch variable y degradación elegante.
  - `TransitionManager` — fades entre escenas y reset de `GameFeel`.
- **Señales:** `RaceManager` emite `time_updated`, `split_reached`, `checkpoint_reached`, `finished`, `respawned`, `best_time_updated`, `checkpoints_updated`, `countdown_tick`, `race_started` y `results_ready`; el HUD se suscribe.
- **Grupos:** `player`, `bot`, `bots`, `checkpoints`, `race_manager`, `race_director`, `pause_menu`, `wind_tunnels`, `launchers`, `see_saws`, `level_info`.
- **Datos:** `user://profile.json` (perfil, personaje elegido, personajes desbloqueados, monedas, récords y splits por circuito, ajustes) y `user://best_time.save` (solo legado, se importa una vez).
- **Generadores:** `scripts/levels/level_builder.gd` solo elige el tema y mantiene la cámara; `level_kit.gd` reúne materiales, escenario, actores y geometría compartida, y cada circuito aporta su kit (`glacier_kit.gd`, `volcano_kit.gd`, `ocean_kit.gd`) que solo describe su pista. Añadir un circuito nuevo es añadir un kit, no tocar un archivo de tres mil líneas.
- **Rendimiento:** los mapas hechos a mano ya no usan CSG (33 y 45 cajas horneadas a `BoxMesh` + `BoxShape3D`, sin recálculo al arrancar); los circuitos generados se guardan en actos (`_act1.tscn`…`_act3.tscn`) que se instancian; la sombra de contacto y el raycast del suelo de la cámara se refrescan a 25 y 30 Hz en vez de a cada tick de física; el dispensador de bolas recicla sus `RigidBody3D`; el menú templa los shaders de los obstáculos antes de la primera carrera; y cada acto recorta su atrezo a distancia (unos 14 px, con desvanecido *dither*) y convierte sus losas grandes en occluders, sin tocar pista ni obstáculos.
- **Circuitos:** cada escena lleva un nodo `LevelInfo` con id, nombre, ronda, longitud, tiempos de medalla, récord por nivel, ruta de bots y carriles. `RaceManager`, `RaceDirector` y el HUD leen ese contrato, así que el mismo jugador y el mismo bot funcionan en todos los mapas.

## Audio

Todo el audio se sintetiza desde cero con `tools/generate_audio.py`:

```bash
cd proyecto
python tools/generate_audio.py
```

Genera el tema alegre del menú (`menu_theme.wav`, 38 s en bucle) y los **SFX**: salto, paso, checkpoint, meta, caída, aterrizaje, impacto, moneda, UI, cuenta atrás, viento, cañón, crujido del balancín, trampolín y whoosh de martillos. El recuento vigente está en [Datos de referencia](documentacion/Datos_circuitos.md#recuentos-de-contenido). La música **solo suena en el menú**; durante la carrera se detiene y dejan oírse los pasos, los bots y los obstáculos, estos últimos con audio 3D atenuado por distancia. Al cruzar la meta suena `audio/music/victory.mp3` (**22 s**, recortado y normalizado) sobre el panel de resultados. Va por su propio bus `Victory`, así que se oye aunque el volumen de música esté bajo.

## Documentación

- [`documentacion/README.md`](documentacion/README.md) — Índice y orden de lectura de la documentación.
- `documentacion/Primera_entrega.md` — Informe de la primera entrega.
- `documentacion/Segunda_iteracio.md` — Informe de la segunda entrega de seguimiento: los circuitos, el torneo y la verificación real.
- `documentacion/Torneo_cuatro_circuitos.md` — Los cuatro circuitos del torneo y Abyss Run en la clásica: paletas, rutas, producción, verificación y créditos.
- `documentacion/Datos_circuitos.md` — **Fuente única** de longitudes, medallas, configuración del torneo, recuentos y resultados de tests.
- `documentacion/Capturas.md` — Galería de capturas propias del menú, los circuitos, los resultados y el torneo.
- `documentacion/Ideas_Mejora.md` — Banco de ideas para futuras iteraciones.
- `CONTRIBUTING.md` — Convención de commits, tests, hooks de lint y qué documentación actualizar con cada cambio.

El uso de inteligencia artificial está documentado en cada informe (`Primera_entrega.md` §5, `Segunda_iteracio.md` §7 y `Torneo_cuatro_circuitos.md` §11), no en un documento aparte.

## Créditos

- Autores: **Pol Arjona** e **Yazan Issa**
- Motor: [Godot Engine](https://godotengine.org) 4.7.2
- Pelota de playa: [beach ball](https://poly.pizza/m/4IwPTeOmq6c) de **the_ normalgamer**, licencia **CC-BY 3.0** (ver `proyecto/assets/props/README.md`).
- Referencias de mapa **ajenas**: [Pivot Push](https://sketchfab.com/3d-models/stumble-guys-pivot-push-map-c7abc0bdd0a8490d9f1e9c805e3c05cd) y [Spin Go Round](https://sketchfab.com/3d-models/stumble-guys-spin-go-round-map-71224cc13db44948b91b8bb43c635d5c) de **amogusstrikesback2**, **CC-BY 4.0**; usadas solo como referencia de composición y color, sin redistribuir sus mallas. Las capturas propias del proyecto están en [Capturas](documentacion/Capturas.md).
- Personajes 3D: [Ultimate Animated Character Pack](https://quaternius.com/packs/ultimatedanimatedcharacter.html) de [Quaternius](https://quaternius.com), licencia **CC0** (ver `proyecto/assets/characters/ultimate/LICENSE_Quaternius.txt`).
- Tipografía: [Baloo 2](https://fonts.google.com/specimen/Baloo+2) de Ek Type, licencia **SIL OFL 1.1** (ver `proyecto/ui/fonts/OFL-Baloo2.txt`).
- IA usada en el desarrollo (ver informe en `documentacion/`).
