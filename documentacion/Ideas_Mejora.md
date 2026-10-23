# Banco de ideas — de prototipo a juego "perfecto"

**Proyecto:** Stumble Guys (Godot 4.7, Forward+, Jolt, GDScript)
**Fecha:** Octubre 2026
**Cómo usar este documento:** cada idea tiene un **ID**. Responde con la lista de IDs que quieres aplicar (por ejemplo `M3, M7, G2, G9, P1`) y se implementan en ese orden. Las etiquetas de coste son orientativas: **S** ≈ media sesión, **M** ≈ una sesión larga, **L** ≈ varias sesiones.

---

## 0. Auditoría: dónde está el juego hoy

**Lo que ya está bien resuelto** (no hace falta rehacerlo):

- `scripts/player.gd` (555 líneas): inercia, coyote time, jump buffer, salto variable, apex hang, dive/prone, herencia de momento de plataformas, stun por impacto, animación procedural, cámara SpringArm con FOV kick y shake.
- `scripts/race_manager.gd`: cronómetro, checkpoints, splits vs. récord, penalización por caída, medallas, persistencia.
- `scripts/save_manager.gd`: perfil JSON versionado, ajustes, monedas, coronas, medallas, migración de saves antiguos.
- `scripts/race_director.gd` + `bot_racer.gd`: bots con waypoints, clasificación en vivo, cualificación por rondas.
- 12 obstáculos instanciables, shader de postproceso, cielo con nubes, multitud, 4 suites de test headless.

**Los cinco techos actuales** (esto es lo que impide el "x100"):

1. **Un solo circuito, hecho a mano en `main.tscn`** (369 líneas de CSG). No hay formato de nivel ni reutilización: cada circuito nuevo sería copiar-pegar una escena enorme.
2. **Los bots siguen una lista de 15 waypoints con `match _index` para saltar.** No ven el mundo, no reaccionan a obstáculos, no compiten entre ellos. Solo funcionan en *este* circuito.
3. **Falta el verbo central de Fall Guys: agarrar/empujar a otros.** Ahora mismo los jugadores no pueden interactuar entre sí, así que no hay comedia social, que es el 50 % del género.
4. **La cámara es de eje fijo** (pivot con yaw del mundo) y no hay controles táctiles ni remapeo: un solo esquema de control, una sola forma de jugar.
5. **Todo el arte es `CSGBox`/`CSGCylinder` con colores planos.** Funciona para leer el nivel, pero no genera identidad visual ni "capturas de pantalla que apetezca compartir".

**Y el techo más grande de todos:** el juego no tiene **bucle de progresión**. Se corre, se ve un tiempo, se vuelve al menú. Un juego "perfecto" necesita una razón para la partida número 50.

---

## 1. Principios de diseño (el filtro para todo lo demás)

Cinco reglas que deberían gobernar cada decisión, sacadas de por qué funciona el género:

1. **La física es el chiste.** El jugador debe poder perder por algo divertido que él mismo provocó. Cualquier mecánica que reduzca el caos controlado (movimiento demasiado preciso, frenadas instantáneas) va en contra.
2. **Readable chaos.** Mucho movimiento en pantalla, pero el jugador siempre sabe qué le ha matado. Regla práctica: todo peligro avisa con color + sonido + movimiento antes de golpear.
3. **Reintento en menos de 2 segundos.** Respawn instantáneo, sin pantallas. La fricción para volver a intentarlo debe ser cero.
4. **Rondas de 60-120 s, decisión constante.** Si en 5 segundos el jugador no ha tenido que decidir nada, el tramo es demasiado fácil.
5. **Escalada visible.** El jugador debe sentir que el circuito empeora (y que él mejora) — no solo "más largo".

---

## 2. MECÁNICAS — física y control

| ID | Idea | Qué aporta | Coste |
|----|------|-----------|-------|
| **M1** | **Agarre (grab)**: mantener un botón cerca de otro jugador/borde y agarrarlo; arrastrarlo, frenarlo en una cinta, empujarlo al vacío. Con `Area3D` + `apply_push` ya existente. | El verbo más importante del género. Convierte la carrera en interacción social. | M |
| **M2** | **Empujón / placaje**: dash corto que empuja y stunea; si se usa en el aire, se convierte en placaje volador con recuperación lenta (riesgo/recompensa). | Da agencia contra los bots y contra otros jugadores. | S |
| **M3** | **Escalada de borde (ledge grab + mantle)**: detectar borde con 3 raycasts, colgarse, subir con animación. Permite diseñar niveles verticales y perdona errores de salto. | Cambia por completo el diseño de niveles: se pueden hacer muros, fosas y atajos. | M |
| **M4** | **Ragdoll real al caer/golpe fuerte**: cambiar a un `Ragdoll` (PhysicalBone o cubos con `RigidBody3D` unidos por `PinJoint3D`) durante 0,8 s y volver a `CharacterBody3D`. | La firma visual del género. Cada muerte se vuelve memorable. | L |
| **M5** | **Salto con carga + salto de pared (wall jump opcional)**: mantener salto para cargar (más altura, aterrizaje con *squash*), y un único rebote en pared para corregir saltos. | Profundidad sin complejidad: más expresión con los mismos botones. | S |
| **M6** | **Aterrizaje deslizado (slide)**: al llegar al suelo desde mucha altura, deslizarse 0,5 s conservando inercia; si hay pendiente, la velocidad se convierte en diversión. | Encadena saltos largos y hace que las cuestas importen. | S |
| **M7** | **Física de choque entre jugadores**: colisión real (cápsula con masa) para que los choques se sientan; hoy los bots se atraviesan en la práctica. | Sin esto, el caos se ve pero no se siente. | M |
| **M8** | **Plataformas que te llevan de verdad**: `AnimatableBody3D` + `platform_on_leave = ADD_VELOCITY` en todos los obstáculos móviles y comprobación de que la velocidad heredada se conserva al saltar. | Arregla una clase de bugs y hace los obstáculos móviles justos. | S |
| **M9** | **Suelo resbaladizo / hielo, barro que frena, agua que empuja**: variantes de superficie con un multiplicador de fricción y aceleración aplicado en `player.gd`. | Cinco niveles de sensación distintos con una variable. | S |
| **M10** | **Impulso de rampa y *launch* dirigido**: las rampas convierten velocidad horizontal en vertical; permite muñecos volando por los aires. | Momento cómico garantizado y atajos arriesgados. | S |
| **M11** | **Objetos físicos lanzables** (pelotas, conos, huevos): coger con M1 y lanzar con el dive; `RigidBody3D` con `apply_central_impulse`. | Armas sociales, y los obstáculos ganan vida. | M |
| **M12** | **Barra de resistencia al sprint** (o sprint con *stamina* que se recupera al correr cuesta abajo). | Añade gestión de recursos y ritmo a las rectas largas. | S |
| **M13** | **Superficies con rebote** (trampolines ya existen, pero también suelos elásticos que devuelven el 80 % de la velocidad vertical). | Movilidad vertical barata y muy vistosa. | S |
| **M14** | **Muerte no binaria**: en vez de "caer = respawn", caer en lodo te devuelve al último checkpoint con la ropa manchada; caer al vacío respawn normal. | Menos castigo, más variedad de riesgo. | S |
| **M15** | **Personalización de stats por cosmético** (zapatillas = +aceleración, guantes = +agarre, casco = menos stun), todo suave y sin P2W: ±8 %. | Da sentido a los cosméticos y variedad de builds. | M |

---

## 3. MECÁNICAS — modos de juego y estructura

Los modos están ordenados por **relación diversión/esfuerzo** en este proyecto concreto.

| ID | Modo | Reglas | Por qué encaja aquí | Coste |
|----|------|--------|---------------------|-------|
| **M20** | **Carrera clásica (mejorada)** | 8-16 corredores, los N primeros pasan | Ya existe la base; solo falta completarla | S |
| **M21** | **Hex-a-Gone / Suelo que cae** | Suelo de hexágonos que desaparecen al pisarlos; último en pie | Reutiliza el sistema de tiles; tremendo en 3D con cámara cenital | L |
| **M22** | **Tail Tag / Pilla-pilla** | Uno lleva una cola; si te pillan, la pierdes; sobrevive con cola al final | Usa M1/M2 y el `apply_push` existente | M |
| **M23** | **Jump Club / Roll Out** | Plataforma giratoria con barra que hay que saltar; el que cae, fuera | Ya existen `sweeper` y `spinning_platform` | S |
| **M24** | **Tip Toe / Suelo falso** | Camino de tiles donde algunos son falsos; hay que memorizar la ruta | Reutiliza `crown`/`checkpoint` y una matriz de tiles | M |
| **M25** | **Block Party / Muro que barre** | Muros que empujan hacia el vacío por franjas; hay que colocarse en el hueco | Ya existe `wall.tscn`, solo falta el patrón | S |
| **M26** | **Egg Scramble / Roba huevos** | Dos equipos recogen huevos de un nido central | Necesita equipos + agarre | L |
| **M27** | **Fall Ball / Fútbol con muñecos** | Dos equipos, pelota gigante, porterías | Muy divertido, pero exige física de equipo estable | L |
| **M28** | **Final: corona** | 3-5 clasificados, carrera corta final; el ganador se lleva la corona | Cierra el torneo con tensión máxima | M |
| **M29** | **Modo práctica / contrarreloj** | Sin bots, sin muerte, splits y ghosts | Ideal para aprender el circuito y para los tests | S |
| **M30** | **Torneo real de 4-5 rondas** | Eliminación progresiva, mapa distinto por ronda, 1 final | Es lo que convierte "un prototipo" en "un juego" | L |
| **M31** | **Eventos aleatorios de ronda** (*mutators*) | "Gravedad baja", "todos resbalan", "lluvia de bolas", "sin saltar" | Rejugabilidad casi gratis, gran gancho para clips | M |
| **M32** | **Modo espectador / bots de relleno** | Si caes, ves a los demás terminar con cámara libre | Evita el "he perdido, cierro el juego" | S |
| **M33** | **Replay del fantasma del récord** | Grabar posiciones cada 0,1 s y reproducir un personaje translúcido | Objetivo personal claro, muy motivador | M |
| **M34** | **Split-screen local 2-4** | `SubViewport` + cámara por jugador | El proyecto ya tiene input por jugador a medias; gran valor social sin red | L |
| **M35** | **Multijugador online (ENet / Steam)** | Servidor autoritativo, interpolación, predicción | El mayor salto de valor, pero es un proyecto en sí mismo | L |
| **M36** | **Desafíos diarios/semanales** | "Termina sin caer", "recoge 3 coronas", "gana una ronda" | Retención diaria con muy poco contenido nuevo | M |

---

## 4. MECÁNICAS — obstáculos nuevos (kit de piezas)

Cada uno debería ser una escena instanciable con `_ready`/`_physics_process` propio, como los 12 actuales.

| ID | Obstáculo | Comportamiento |
|----|-----------|----------------|
| **M40** | **Suelo que se desmorona** | Tile que se agrieta al pisar y cae a los 0,6 s; reaparece a los 4 s |
| **M41** | **Puertas sorpresa** | 5 puertas, solo 1-2 se abren; las falsas rebotan |
| **M42** | **Molino de aspas** | Aspas giratorias en horizontal y vertical; empujan con `apply_push` |
| **M43** | **Guante de boxeo** | Pistón que sale y empuja; timing legible |
| **M44** | **Bola gigante rodante** | `RigidBody3D` que persigue por la pendiente y aplasta |
| **M45** | **Ventilador vertical** | Columna de aire que te mantiene flotando (variante del `wind_tunnel` actual) |
| **M46** | **Rampa de hielo con giro** | Curva helada que hay que tomar con inercia; fuera = vacío |
| **M47** | **Cinta transportadora reversible** | Cinta que cambia de dirección con aviso sonoro/luminoso |
| **M48** | **Prensa / techo que baja** | Trampa de tiempo: hay que pasar en la ventana |
| **M49** | **Cañón de confeti y bolas** | Dispara proyectiles en abanico; ya hay `launcher` y `ball_dropper` |
| **M50** | **Plataforma que se hunde** | Flota y se hunde al pisarla; hay que no pararse |
| **M51** | **Charco de lodo / arena movediza** | Frena y luego succiona; salir requiere saltos repetidos |
| **M52** | **Riel con vagoneta** | Riel curvo con vagón que hay que saltar entre tramos |
| **M53** | **Trampolín de pared (wall spring)** | Rebote lateral para *wall jumps* encadenados |
| **M54** | **Suelo magnético / gravedad invertida local** | Zona con gravedad a 0,3; flotas y planas |
| **M55** | **Láseres intermitentes** | Rejilla de haces que se encienden por franjas |
| **M56** | **Puerta giratoria con hueco** | Túnel con aspas que dejan un hueco de 90° |

---

## 5. BOTS E IA

| ID | Idea | Detalle | Coste |
|----|------|---------|-------|
| **M60** | **Waypoints por nivel, no por código** | Los waypoints pasan a ser un `Curve3D`/`Path3D` dentro de la escena del nivel, con `jump_hint` por punto. Elimina el `match _index` de `bot_racer.gd`. | M |
| **M61** | **Navegación con `NavigationRegion3D`** | En vez de seguir puntos ciegos, calcular ruta con A* sobre navmesh. Permite mapas nuevos sin tocar IA. | L |
| **M62** | **Detección de peligros** | 3 raycasts delante + estado del obstáculo: el bot frena, salta o se aparta. | M |
| **M63** | **Separación / *steering*** | Los bots no se apelotonan: fuerza de repulsión entre ellos (ya hay `_knockback`). | S |
| **M64** | **Personalidades de bot** | "Rápido y torpe", "lento y seguro", "tramposo que empuja": `0-1` de agresividad, precisión y resistencia al stun. | S |
| **M65** | **Dificultad dinámica** | Si el jugador va muy por delante, los bots aceleran hasta un techo; si va último, aflojan un poco. Nunca descarado. | S |
| **M66** | **Bots que empujan, agarran y esperan** | Usan M1/M2 contra el jugador en puntos estrechos. | M |
| **M67** | **Bots con ragdoll y tropiezos** | Al recibir un golpe fuerte, ruedan por el suelo (M4) en vez de solo inclinarse. | M |
| **M68** | **Nombres y colores por torneo** | Nombres generados, colores asignados sin repetición, tabla de posiciones. | S |
| **M69** | **Rival designado** | Un bot concreto que te persigue toda la ronda y te insulta en el HUD ("¡Tebo te ha empujado!"). | S |

---

## 6. PROGRESIÓN, ECONOMÍA Y META

| ID | Idea | Detalle | Coste |
|----|------|---------|-------|
| **M70** | **Pase de temporada simple** | 20 niveles de XP, recompensas fijas (colores, sombreros, bailes). Sin monetización real. | M |
| **M71** | **Tienda con monedas** | Ya hay monedas en `save_manager.gd`; falta una pantalla que gaste. | M |
| **M72** | **Cosméticos: sombreros, colores, patrones, bailes, sonidos de muerte** | Cargados desde un `.tres` de catálogo; se ven también en bots. | L |
| **M73** | **Bailes / emotes en la meta** | 4 animaciones procedurales y un botón; al terminar, el personaje baila. | S |
| **M74** | **Logros y estadísticas** | "Sin caer", "10 coronas", "sub-40 s"; pantalla de perfil con gráfico de tiempos. | M |
| **M75** | **Récords por circuito y por modo** | Hoy el récord es global; separar por mapa y por modo. | S |
| **M76** | **Árbol de insignias / rangos** | Bronce→Plata→Oro→Corona según medallas acumuladas, visible en el menú. | S |
| **M77** | **Pantalla de resultados "de verdad"** | Podio, confeti, tiempo, medalla, posición, XP ganado, botón "siguiente ronda" con cuenta atrás. | S |
| **M78** | **Contadores de sesión** | "Llevas 3 victorias seguidas", racha diaria. | S |

---

## 7. GRÁFICOS — identidad visual

**7.1 Paleta, materiales y luz**

| ID | Idea | Detalle | Coste |
|----|------|---------|-------|
| **G1** | **Paleta maestra y guía de color** | 8 colores base (ya hay 7 `.tres`) + reglas: suelo saturado y claro, peligro en naranja/rojo, meta en dorado, fondo desaturado. Aplicarlo en un `Theme` 3D y en los materiales. | S |
| **G2** | **Material "toon suave"** | Shader con rampa de 3 tonos + rim light + `smoothstep` de Fresnel; aplicado a jugadores y obstáculos. Cambia la lectura del juego entero sin tocar geometría. | M |
| **G3** | **Detalle de superficie por shader (triplanar)** | Ruido sutil en el albedo + normales falsas en cajas grandes; rompe la sensación de "bloques de color". | S |
| **G4** | **Iluminación física creíble** | SSAO + SSIL, `DirectionalLight3D` con sombras suaves (ya hay `soft_shadow_filter_quality=3`), luz de relleno azulada y `Environment` con `glow` selectivo. | S |
| **G5** | **Niebla volumétrica y rayos de sol** | `FogVolume`/fog de entorno + god rays en la cámara de meta; da profundidad al fondo y oculta el corte del mapa. | M |
| **G6** | **Cielo con sol, nubes en capas y paralaje** | Ampliar `sky_clouds.gdshader` con dos capas de nubes a distinta velocidad y un disco solar con bloom. | S |
| **G7** | **Fondo con siluetas lejanas** | Montañas/torres en `MultiMeshInstance3D` con material plano, sin colisión: elimina el "vacío" al final del circuito. | S |
| **G8** | **Props de ambientación** | Banderas, vallas, focos de estadio, globos, carteles con el logo; 8-10 props reutilizables. | M |
| **G9** | **Postproceso con *look* propio** | Ya hay aberración/viñeta/grano: añadir color grading (LUT o `Environment.adjustment`), bloom en highlights, *outline* suave en personajes, dithering contra bandas. | M |
| **G10** | **Outline de personajes** | Un `MeshInstance3D` duplicado con `grow` y material `cull_front`; hace que los jugadores se lean contra cualquier fondo. | S |

**7.2 Personajes y animación**

| ID | Idea | Detalle | Coste |
|----|------|---------|-------|
| **G11** | **Rig real + `AnimationTree`** | Esqueleto humanoide simple + `BlendSpace1D` (idle/run/jump/fall/prone). Sustituye la animación procedural actual donde haga falta. | L |
| **G12** | **Shader "gelatina" (squash & stretch + jiggle)** | Deformación por vértice en `vertex()` según velocidad vertical y golpes. Un solo shader da vida a todos los muñecos. | M |
| **G13** | **IK de pies y mirada** | `SkeletonIK3D`/`LookAtModifier` para que miren al rival y pisen bien las rampas. | M |
| **G14** | **Ojos y boca expresivos** | Estado de ánimo (normal, asustado, mareado, celebración) con blendshapes o cambio de malla; hoy ya hay ojos/boca estáticos. | S |
| **G15** | **Trapos/accesorios con física** | Bufanda, gorro o mochila con `SpringArm`/huesos secundarios: dan lectura de velocidad. | M |
| **G16** | **Estela y sombra de contacto** | Sombra blob ya existe; añadir estela de polvo al correr y salpicaduras al caer. | S |

**7.3 VFX y *juice***

| ID | Idea | Detalle | Coste |
|----|------|---------|-------|
| **G17** | **Impacto de golpe legible** | Hitstop corto (ya existe `GameFeel`), *flash* blanco de 2 frames en el muñeco, anillo de ondas y partículas de estrellas. | S |
| **G18** | **Partículas por superficie** | Polvo seco en el barro, chispas en metal, confeti en la meta, hojas en zonas verdes. | M |
| **G19** | **Confeti y fuegos artificiales de victoria** | Ampliar `finish_line.tscn`: confeti continuo + fuegos artificiales + lluvia de coronas. | S |
| **G20** | **Destrucción de props** | Cajas y barriles que se rompen con `RigidBody3D` + fragmentos; puro espectáculo. | M |
| **G21** | **Cámaras de muerte y de meta** | Al caer, cámara que sigue al muñeco 1 s; al ganar, órbita lenta alrededor del personaje. | M |
| **G22** | **Motion trails en el dive** | Rastro de estela + líneas de velocidad en los bordes (ya hay `speed` en el shader de postproceso). | S |
| **G23** | **Marcadores de jugador en el mundo** | Flecha/nombre sobre los rivales cercanos, con distancia y color. | S |

**7.4 UI y presentación**

| ID | Idea | Detalle | Coste |
|----|------|---------|-------|
| **G24** | **Tema de UI completo** | Ya existe `ui/theme.tres`: añadir tipografía redondeada, iconos propios, estados *hover/pressed/disabled*, `StyleBox` con borde grueso y sombra. | S |
| **G25** | **Animaciones de UI** | `Tween` en botones (escala 1.05, rebote), paneles que entran con *overshoot*, contadores que cuentan hacia arriba. | S |
| **G26** | **HUD más limpio y con jerarquía** | Tiempo grande y centrado, récord pequeño, posición a la izquierda, coronas con icono, barra de progreso con avatares de los rivales. | M |
| **G27** | **Menú principal como escena viva** | El personaje del jugador en 3D girando en el menú con su cosmético equipado; fondo animado. | M |
| **G28** | **Pantalla de carga / transición con logo** | Ya hay `TransitionManager`: añadir logo animado, *tips* y barra. | S |
| **G29** | **Subtítulos y avisos accesibles** | Texto para sonidos clave ("¡Te han empujado!") y avisos de peligro con icono. | S |

---

## 8. AUDIO

| ID | Idea | Detalle | Coste |
|----|------|---------|-------|
| **A1** | **Música por capas según tensión** | 3 pistas (calma / carrera / último tramo) que se mezclan por volumen; el audio ya está generado con `tools/generate_audio.py`. | M |
| **A2** | **Variación de SFX** | Aleatorizar *pitch* ±10 % y volumen ±3 dB en cada reproducción: evita el "metralleta" de pasos y saltos. | S |
| **A3** | **Ambiente de estadio** | Murmullo del público en bucle, que sube al pasar cerca de la multitud y al terminar. | S |
| **A4** | **Sonidos de muerte y de golpe propios** | 6 onomatopeyas distintas (caída, golpe, bola, viento, trampolín, lodo). | S |
| **A5** | **Ducking y mezcla** | Bajar música 6 dB durante el *slow motion* y en la pantalla de resultados. | S |
| **A6** | **Voces/gorjeos del personaje** | 4-5 "¡ay!" sintéticos para saltos y golpes; refuerza la comedia. | M |

---

## 9. NIVELES Y CONTENIDO

| ID | Idea | Detalle | Coste |
|----|------|---------|-------|
| **P1** | **Formato de nivel reutilizable** | Separar `main.tscn` en `scenes/levels/*.tscn` que solo contienen el curso + un `LevelData` (nombre, z de meta, waypoints, medallas). | M |
| **P2** | **Kit modular de piezas** | 15-20 piezas de geometría (recto, curva, rampa, hueco, túnel, meta) combinables; el nivel se monta, no se esculpe. | L |
| **P3** | **Editor interno de niveles** | Colocar piezas con teclado/ratón y guardar JSON: multiplica el contenido sin escribir escenas a mano. | L |
| **P4** | **Cuatro circuitos temáticos** | "Ciudad" (azoteas), "Fábrica" (cintas y prensas), "Hielo" (resbaladizo), "Jungla" (lodo y lianas), cada uno con paleta y obstáculos propios. | L |
| **P5** | **Curvas de dificultad** | Cada circuito con 3 tramos: enseñanza (1 obstáculo), combinación (2), examen (3 juntos). | S |
| **P6** | **Atajos con riesgo** | Rutas alternativas más cortas y más peligrosas (cuerda floja, saltos sobre vacío) recompensadas con coronas. | M |
| **P7** | **Secretos** | 1 corona escondida por nivel fuera de la ruta principal. | S |
| **P8** | **Zonas de descanso** | Plataformas seguras entre tramos: dan respiro y sirven de checkpoint natural. | S |

---

## 10. TÉCNICA, RENDIMIENTO Y CALIDAD

| ID | Idea | Detalle | Coste |
|----|------|---------|-------|
| **T1** | **Sustituir CSG por mallas** | CSG recalcula en runtime; convertir a `ArrayMesh`/`.glb` baja coste y evita *hitches*. | M |
| **T2** | **`MultiMesh` para decorado y multitud** | Ya hay `crowd.gd`; extenderlo a vallas, banderas y árboles: cientos de objetos a coste de uno. | S |
| **T3** | **Oclusión y LOD** | `OccluderInstance3D` + LOD automático en props lejanos; mantener 60 fps en portátiles. | M |
| **T4** | **Object pooling** | Bolas, partículas y confeti reutilizados en vez de instanciar/destruir. | S |
| **T5** | **Precompilación de shaders** | Evitar el tirón del primer obstáculo que aparece (`shader_compile` en carga). | S |
| **T6** | **Tests de escena obligatorios** | Ampliar `tools/check_scenes.gd` + `iteration3_test.gd`: cada obstáculo nuevo debe tener un test headless que verifique su señal. | S |
| **T7** | **CI con Godot headless** | GitHub Action que importa el proyecto y corre las 4 suites en cada push. | M |
| **T8** | **Instrumentación de rendimiento** | Medir tiempo de frame en el circuito completo y fijar presupuesto (< 8 ms de CPU). | S |
| **T9** | **Desacoplar con señales y grupos** | Menos `get_node` directos entre sistemas; estados de juego en una máquina de estados (`GameState`). | M |
| **T10** | **Modo "sin UI / capturas"** | Tecla F12 que oculta HUD y sube calidad para hacer capturas de prensa. | S |
| **T11** | **Ajustes reales** | Ya hay ajustes: añadir FOV, sensibilidad de cámara (cuando exista), calidad gráfica, *vsync*, idioma. | M |
| **T12** | **Idiomas ES/CA/EN** | `tr()` + CSV de traducciones; el proyecto ya está en español, el salto es barato. | M |

---

## 11. ACCESIBILIDAD Y UX

| ID | Idea | Detalle | Coste |
|----|------|---------|-------|
| **U1** | **Remapeo de controles** | Pantalla de controles con `InputMap` editable y guardado en el perfil. | M |
| **U2** | **Modo daltónico** | Paleta alternativa + iconos además de color en peligros. | S |
| **U3** | **Reducir flash / shake / movimiento** | Ya hay ajuste de *shake*: ampliar a flashes, *motion blur* y velocidad de cámara. | S |
| **U4** | **Dificultad asistida** | Más tiempo de coyote, menos penalización, bots más lentos, checkpoints más frecuentes. | S |
| **U5** | **Cámara con control de eje** | Permitir arrastrar con el ratón/stick derecho para orbitar ±60° (hoy el yaw está fijo). | M |
| **U6** | **Controles táctiles** | Joystick virtual + botones, útil para la versión móvil/HTML. | L |
| **U7** | **Tutorial jugable** | Hoy es un panel de texto: convertirlo en un tramo guiado con flechas en el mundo. | M |
| **U8** | **Reanudar partida / modo pausa completo** | Ya existe `pause_menu`: añadir reinicio rápido (R), ajustes en pausa y "volver al último checkpoint". | S |

---

## 12. Los tres paquetes recomendados

Si quieres el máximo "x100" por esfuerzo, estos son los caminos que yo elegiría:

### Paquete A — "Se siente como un juego de verdad" (10-12 h de trabajo)
`M1` agarre · `M2` empujón · `M7` choque entre jugadores · `M4` ragdoll · `G2` toon · `G9` postproceso · `G5` niebla/rayos · `G12` gelatina · `G17` impacto · `A2` variación SFX · `G24` tema UI · `M77` resultados con podio
→ El juego pasa de "prototipo bonito" a "clip que apetece compartir".

### Paquete B — "Hay un juego, no un nivel" (15-20 h)
`P1` formato de nivel · `P2` kit modular · `M30` torneo de 4 rondas · `M33` fantasma · `M21`/`M23`/`M25` tres modos · `M60`/`M64`/`M65` IA por nivel · `M70`/`M76` progresión
→ Contenido y rejugabilidad: la razón para abrir el juego una segunda vez.

### Paquete C — "Escaparate técnico" (10-14 h)
`G11` rig + AnimationTree · `G13` IK · `G7`/`G8` fondo y props · `G18` partículas · `A1` música por capas · `T1`/`T2`/`T3` rendimiento · `U5` cámara orbital · `U7` tutorial jugable
→ Es el paquete que hace que las capturas y el tráiler impresionen.

---

## 13. Qué NO haría (y por qué)

- **Multijugador online como primer paso** (`M35`): sin niveles ni modos, el online solo multiplica un prototipo vacío. Va después del paquete B.
- **Rig completo antes que el *juice*** (`G11`): la animación procedural actual ya es simpática; el retorno se dispara antes con shaders y partículas.
- **Editor de niveles interno** (`P3`): solo tiene sentido cuando existan `P1` y `P2`; antes es una herramienta para hacer contenido que aún no existe.
- **Física de equipo compleja** (`M27`): Fall Ball exige un `RigidBody` de pelota muy estable; es el modo que más bugs arrastra por diversión obtenida.
