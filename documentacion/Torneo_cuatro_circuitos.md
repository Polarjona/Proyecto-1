# Torneo de cuatro circuitos

**Proyecto:** Tumble Rush
**Autores:** Pol Arjona e Yazan Issa
**Motor:** Godot Engine 4.7.2 (Forward Plus, Jolt)
**Fecha:** Noviembre 2026

---

## 1. Objetivo

El modo torneo recorre **cuatro circuitos**, uno por ronda, unidos por `GameSession`. El quinto circuito, **Abyss Run**, queda para la carrera clásica.

| Ronda | Escena                                   | Nombre         | Longitud | Checkpoints | Oro / Plata / Bronce |
| --- | --- | --- | --- | --- | --- |
| 1 | `scenes/main.tscn`                       | Pivot Push     | 368 m | 11 | 130 / 170 / 215 s |
| 2 | `scenes/levels/spin_go_round.tscn`       | Spin Go Round  | 339 m | 12 | 115 / 145 / 185 s |
| 3 | `scenes/levels/glacier_gallop.tscn`      | Glacier Gallop | 367 m | 9  | 145 / 180 / 225 s |
| 4 | `scenes/levels/lava_vortex.tscn`         | Lava Vortex    | 509 m | 0  | 84 / 100 / 116 s |
| — | `scenes/levels/abyss_run.tscn`           | Abyss Run      | 428 m | 6  | 112 / 138 / 172 s |

Cada nivel lleva un `LevelInfo` con id, ronda, tiempos de medalla, récord propio, ruta de bots y anchos de carril. `RaceManager`, `RaceDirector` y el HUD leen esos datos, así que el mismo jugador y el mismo bot funcionan en todos los mapas.

**Pivot Panic se retiró.** Su escena ya no existe y su constructor está desactivado en `tools/build_levels.gd`; el torneo se cierra con los cuatro circuitos de la tabla.

## 2. Referencias y paletas

La composición y el color de los dos primeros circuitos se inspiraron en dos mapas de Stumble Guys de Sketchfab (CC-BY 4.0, autor **amogusstrikesback2**):

- [Pivot Push](https://sketchfab.com/3d-models/stumble-guys-pivot-push-map-c7abc0bdd0a8490d9f1e9c805e3c05cd)
- [Spin Go Round](https://sketchfab.com/3d-models/stumble-guys-spin-go-round-map-71224cc13db44948b91b8bb43c635d5c)

No se descargaron sus mallas: se usaron sus vistas previas para estudiar layout, familias de color y siluetas, y se construyeron circuitos originales con CSG, mallas y materiales del proyecto. Las dos vistas previas quedan en `documentacion/referencias/` con la misma atribución CC-BY 4.0.

| Circuito | Base | Acentos | Cielo / mar |
| --- | --- | --- | --- |
| Pivot Push | azul real, magenta y rosa claro | oro, crema | azul profundo con islas pastel |
| Spin Go Round | cian y azul | naranja, magenta, lima, oro | turquesa luminoso con mar de nubes |
| Glacier Gallop | hielo, blanco y cian | azul profundo, oro | cielo gélido con niebla y nieve |
| Lava Vortex | negro volcánico y rojo | naranja, ámbar, ceniza | cielo rojizo con humo y meteoros |
| Abyss Run | turquesa y azul profundo | arena, coral, verde | fondo marino con niebla y luz de superficie |

Materiales nuevos: `pivot_floor`, `pivot_floor_alt`, `pivot_blue`, `pivot_gold`, `pivot_wall`, `pivot_rail`, `pivot_cream`, `spin_floor`, `spin_blue`, `spin_orange`, `spin_magenta`, `spin_lime`, `spin_gold`, `spin_wall` y `spin_hazard` (rayas de peligro con shader propio). El glaciar, el volcán y el abismo generan sus materiales en `level_builder.gd`.

## 3. Pivot Push (ronda 1)

Es el circuito original, retematizado de azul/cian/lima a **azul real, magenta y oro**. Conserva los tramos y el balancín entre las cintas y la avenida de martillos. Los 11 checkpoints y los bots siguen usando la misma ruta, expuesta en `LevelInfo`.

**Acto 3 — la forja:** rampa de bajada al **pasillo de las rocas** (rocas persecutorias y cinta en contra), **terraza de pinchos**, **puente de las aspas** con tres brazos giratorios, **subida larga** hasta la cima con barrido y **dos péndulos**, y **bajada final** con dos barridos, cinta en contra y pinchos antes de la meta.

## 4. Spin Go Round (ronda 2)

Tres actos que alternan altura, persecuciones y obstáculos de suelo:

- **Acto 1 — arena y peonzas:** salida con arco y dos barridos en una arena con pasillos cerrados; pasarela estrecha y **plataforma móvil** sobre el vacío; tramo de peonzas con barrido, disco giratorio y lluvia de bolas.
- **Acto 2 — altura:** rampa de subida, **dos pistones** alternos con luz de aviso, **puente de 12 losas frágiles** y rampa de bajada.
- **Acto 3 — descenso y mirador:** **tres rocas persecutorias** en carriles desfasados, **galería de 16 pinchos** en 4 × 4, **puente de tres aspas**, cinta en contra, **subida al mirador** (24 m, +5,4 m) con lluvia de bolas, dos péndulos en la cima y bajada final con bolas y dos barridos.

## 5. Glacier Gallop (ronda 3)

El circuito de hielo. La primera mitad encadena barridos, **arena giratoria**, **ascensor de hielo**, galería de pistones y **puente de placas frágiles**. La segunda suma el **puente del vendaval** con viento cruzado, el **pasillo de rocas** y la **terraza de pinchos** antes de la recta final.

Sus dos rasgos exclusivos son los **muros de témpanos** (tres carriles que emergen y bajan con aviso, siempre queda uno abierto) y un **salto recortado** (impulso 5,02 en vez de 6,0) para que el hielo pese. La escena añade nieve, niebla, una catedral de hielo y decoración propia.

## 6. Lava Vortex (ronda 4)

La final es una **espiral de cuatro vueltas** alrededor de una montaña, con 116 tramos y tres saltos sobre la lava.

- **Lava que sube** desde la base hasta la cima: el circuito se corre de una tirada.
- **Géiseres**, **lluvia de meteoros** con aviso, **vórtices de ceniza** y **cortinas de magma**.
- **Sin checkpoints**: una caída devuelve a la salida.
- La cámara puede seguir la espiral por muelle; el control actual es con ratón.

## 7. Abyss Run (carrera clásica)

El quinto circuito no entra en el torneo: se elige en la carrera clásica. Es un **túnel submarino de 428 m** con islas secas, tramos de agua y seis checkpoints.

- **Nado:** flotabilidad, arrastre, inclinación del cuerpo y descenso con `Shift`/`Ctrl` o gatillo derecho.
- **Hazards marinos:** erizos, medusas, minas de burbujas, estrellas giratorias y aros de impulso.
- **Tramos:** islas, ascensores, pasos estrechos y paredes de roca con repisas.

## 8. Récords y medallas

Cada circuito guarda su propio récord y sus splits en `user://profile.json` (`best_times` y `best_splits_by_level`). Los tiempos de medalla son los de la tabla de la sección 1.

El HUD muestra la medalla de oro del circuito cargado y el panel de resultados indica la ronda y el puesto. Al clasificarse, «Siguiente ronda» avanza a la escena correspondiente; en la final el torneo se cierra.

## 9. Cómo se generan las escenas

- **Pivot Push:** construido a mano en `scenes/main.tscn`.
- **Spin Go Round:** `tools/build_levels.gd` comparte el entorno (cielo, luces, postproceso, HUD, RaceManager, KillPlane, RaceDirector, jugador y pausa), construye cada plataforma y obstáculo y empaqueta el resultado en `scenes/levels/spin_go_round.tscn`.
- **Glacier Gallop, Lava Vortex y Abyss Run:** `scripts/level_builder.gd` (modo `@tool`) genera el mapa al abrir la escena y lo hornea al guardar. Abyss Run se genera en runtime porque su escena solo contiene el constructor.

```bash
cd proyecto
godot --headless --path . res://tools/build_levels.tscn   # regenera Spin Go Round
```

## 10. Verificación

Resultados reales de la batería con Godot 4.7.2:

- `tools/check_scenes.gd`: **30/30 escenas OK**.
- `tools/levels_test.gd`: los cinco circuitos cargan, `LevelInfo`, checkpoints, meta, plataformas y rutas; **4 comprobaciones desfasadas** sobre pinchos/rocas/bolas que los mapas ya no tienen en ese punto.
- `tools/levels_bots_test.gd`: no termina dentro de 280 s en esta máquina y deja avisos de RIDs de `NavMesh` al salir; no se considera verde.
- `tools/bots_test.gd`: no re-ejecutado en esta pasada.

## 11. Créditos

- Referencias de composición: Pivot Push y Spin Go Round de **amogusstrikesback2** en Sketchfab, **CC-BY 4.0** (vistas previas en `documentacion/referencias/`).
- Pelota de playa: [beach ball](https://poly.pizza/m/4IwPTeOmq6c) de **the_ normalgamer**, **CC-BY 3.0** (ver `proyecto/assets/props/README.md`).
- Personajes: [Ultimate Animated Character Pack](https://quaternius.com/packs/ultimatedanimatedcharacter.html) de **Quaternius**, **CC0**.
- Tipografía: **Baloo 2** de Ek Type, **SIL OFL 1.1**.
