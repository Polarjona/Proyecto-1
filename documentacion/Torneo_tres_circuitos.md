# Torneo de tres circuitos

**Proyecto:** Tumble Rush
**Autores:** Pol Arjona e Yazan Issa
**Motor:** Godot Engine 4.7.2 (Forward Plus, Jolt)
**Fecha:** Octubre 2026

---

## 1. Objetivo

El modo torneo tenía una sola carrera larga (`main.tscn`). Ahora tiene **tres
rondas con tres circuitos distintos**, unidos por `GameSession`:

| Ronda | Escena | Nombre | Longitud | Checkpoints |
| --- | --- | --- | --- | --- |
| 1 | `scenes/main.tscn` | Pivot Push | ~211 m | 5 |
| 2 | `scenes/levels/spin_go_round.tscn` | Spin Go Round | ~85 m | 3 |
| 3 | `scenes/levels/pivot_panic.tscn` | Pivot Panic | ~150 m | 5 |

Cada nivel lleva un `LevelInfo` con id, ronda, tiempos de medalla, récord
propio y la ruta de los bots. `RaceManager` y `RaceDirector` leen esos datos,
así que el mismo jugador y el mismo bot funcionan en las tres rondas.

## 2. Referencias y paletas

La composición y el color se inspiraron en dos mapas de Stumble Guys de
Sketchfab (CC-BY 4.0, autor **amogusstrikesback2**):

- [Pivot Push](https://sketchfab.com/3d-models/stumble-guys-pivot-push-map-c7abc0bdd0a8490d9f1e9c805e3c05cd)
- [Spin Go Round](https://sketchfab.com/3d-models/stumble-guys-spin-go-round-map-71224cc13db44948b91b8bb43c635d5c)

No se descargaron sus mallas: la API de descarga de Sketchfab exige una cuenta
autenticada. Se usaron sus vistas previas para estudiar layout, familias de
color y siluetas, y se construyeron circuitos originales con CSG, mallas y
materiales del proyecto. Las dos vistas previas quedan en
`documentacion/referencias/` con la misma atribución CC-BY 4.0.

| Circuito | Base | Acentos | Cielo / mar |
| --- | --- | --- | --- |
| Pivot Push | azul real, magenta y rosa claro | oro, crema | azul profundo con islas pastel |
| Spin Go Round | cian y azul | naranja, magenta, lima, oro | turquesa luminoso con mar de nubes |
| Pivot Panic | magenta intenso y rosa | azul real, oro, crema | crema rosado y mar magenta |

Materiales nuevos: `pivot_floor`, `pivot_floor_alt`, `pivot_blue`,
`pivot_gold`, `pivot_wall`, `pivot_rail`, `pivot_cream`, `spin_floor`,
`spin_blue`, `spin_orange`, `spin_magenta`, `spin_lime`, `spin_gold`,
`spin_wall` y `spin_hazard` (rayas de peligro con shader propio).

## 3. Pivot Push (ronda 1)

Es el circuito original, retematizado de azul/cian/lima a **azul real,
magenta y oro**. Se conservan los tramos y se añadió un **balancín** en el
hueco entre las cintas y la avenida de martillos, con su base, rampa y landing.
La cámara, los 5 checkpoints y los 7 bots siguen usando la misma ruta de
siempre; `LevelInfo` ahora la expone también en el inspector.

## 4. Spin Go Round (ronda 2)

Circuito corto y circular, pensado como respiro entre las dos rondas largas:

- salida con arco y **dos barridos** en una arena ancha;
- pasarela estrecha y **plataforma móvil** sobre el vacío;
- **tramo de peonzas**: barrido, disco giratorio y lluvia de bolas;
- meta con arco a cuadros, aro dorado y bolas de playa de atrezo.

Los bots esperan la plataforma móvil y la cruzan; el tramo se validó con
`tools/levels_bots_test.gd` (27 s, 0 rescates).

## 5. Pivot Panic (ronda 3)

La final mezcla los obstáculos que mejor encajan con Pivot Push:

1. barrido de entrada y balancín central con **gran bastidor dorado**;
2. rampa de salida y **avenida de cuatro péndulos** con marcos dorados;
3. plataforma móvil y **puente del viento** con dos túneles opuestos;
4. **cañón** que cruza el vacío hasta la plataforma del cañón;
5. recta final con barrido, péndulo y **trampolín** que sube a la meta 4 m.

Tiene 5 checkpoints para que una caída en la final no obligue a repetir el
circuito entero. El bot de prueba termina en 45 s con 2 rescates; el jugador
tiene margen para repetir el tramo del cañón o el péndulo.

## 6. Récords y medallas

Cada circuito guarda su propio récord y sus splits en
`user://profile.json` (`best_times` y `best_splits_by_level`). Los tiempos de
medalla son:

| Circuito | Oro | Plata | Bronce |
| --- | --- | --- | --- |
| Pivot Push | 70 s | 95 s | 130 s |
| Spin Go Round | 42 s | 58 s | 78 s |
| Pivot Panic | 62 s | 84 s | 112 s |

El HUD muestra la medalla de oro del circuito cargado y el panel de resultados
indica la ronda y el puesto. Al clasificarse, «Siguiente ronda» avanza a la
escena correspondiente; en la final el torneo se cierra.

## 7. Cómo se generan las escenas

Las dos escenas nuevas se generan con:

```bash
cd proyecto
godot --headless --path . res://tools/build_levels.tscn
```

`tools/build_levels.gd` comparte el entorno (cielo, luces, postproceso, HUD,
RaceManager, KillPlane, RaceDirector, jugador y pausa), construye cada
plataforma y obstáculo, asigna `LevelInfo` y empaqueta el resultado en
`scenes/levels/`. Así los tres mapas usan exactamente el mismo contrato de
carrera y se pueden regenerar tras ajustar la paleta o la ruta.

## 8. Verificación

- `tools/check_scenes.gd`: **24/24 escenas OK**.
- `tools/levels_test.gd`: tres circuitos cargan, `LevelInfo`, checkpoints,
  metas, rutas de bots y decoración; flujo de tres rondas del torneo.
- `tools/levels_bots_test.gd`: un bot completa Spin Go Round y Pivot Panic.
- `smoke_test`, `flow_test`, `features_test`, `iteration3_test`,
  `iteration4_test` e `iteration5_test`: **TODO OK**.
- `bots_test`: los 7 bots terminan el circuito original; conserva el aviso
  conocido del primer waypoint y el presupuesto de rescates (máx. 4 en la
  última ejecución) porque el test es más estricto que el juego.

## 9. Atrezo descargado

`assets/props/beach_ball.glb` es una **pelota de playa CC-BY 3.0** de
**the_ normalgamer**, descargada de
[Poly Pizza](https://poly.pizza/m/4IwPTeOmq6c). Se usa como decoración en
Spin Go Round y Pivot Panic; la atribución completa está en
`assets/props/README.md`.

## 10. Limitaciones

- Las plataformas siguen siendo `CSGBox3D` en runtime. El siguiente paso es
  hornear mallas y colisión trimesh para reducir draw calls.
- La descarga directa de los modelos de Sketchfab requiere autenticación; por
  eso se usaron como referencia y se incorporó un modelo CC-BY equivalente.
- La geometría de los tres mapas está pensada para el control actual (sin
  cámara libre); si se añade multijugador habrá que revisar los carriles.
