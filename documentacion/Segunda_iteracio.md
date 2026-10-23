# Informe de Seguiment — Segona Iteració

**Projecte:** Stumble Guys (Prototip)
**Autors:** Pol Arjona i Yazan Issa
**Motor:** Godot Engine 4.7.2 (Forward Plus, física Jolt)
**Llenguatge:** GDScript
**Data:** Octubre 2026

---

## 1. Objectiu de la Iteració

Sobre la base jugable de la primera entrega (curs lineal amb tres zones d'obstacles,
checkpoints, HUD, àudio i persistència), aquesta iteració s'ha centrat en dues línies:

1. **Ampliar el mapa i les seves funcions interactives** — més tipus d'obstacles, zones
   noves i un entorn més ric visualment.
2. **Millorar les físiques i els gràfics del personatge** — control del salt, resposta als
   impactes i representació visual (extremitats, cara, sombra i estela).

---

## 2. Mapa: noves zones i interacció

El curs s'ha allargat d'uns 60 m a uns 85 m i ara té **sis zones d'obstacles seqüencials**.
Cada zona nova és una escena pròpia amb el seu script, seguint la mateixa separació de
responsabilitats que les existents.

| Zona                 | Escena / script                                   | Interacció                                                                 |
| -------------------- | ------------------------------------------------- | -------------------------------------------------------------------------- |
| Cinta transportadora | `conveyor.tscn` / `conveyor.gd`                   | Empeny el jugador cap endavant mentre hi és a sobre                        |
| Pèndol oscil·lant    | `pendulum.tscn` / `pendulum.gd`                   | Martell que gira i llança el jugador en tocar-lo                           |
| Plataforma giratòria | `spinning_platform.tscn` / `spinning_platform.gd` | Gira sobre l'eix Y; el jugador ha de mantenir l'equilibri                  |
| **Corredor de pilotes** | `ball_dropper.tscn` + `ball.tscn`              | El dispensador deixa caure boles rígides que empenyen el jugador enrere    |
| **Trampolí**         | `bounce_pad.tscn` / `bounce_pad.gd`               | En trepitjar-lo llança el jugador cap amunt (fins a la plataforma elevada) |
| **Barra giratòria**  | `sweeper.tscn` / `sweeper.gd`                     | Barra que gira i fa fora el jugador del camí                               |
| **Plataforma mòbil** | `moving_platform.tscn` / `moving_platform.gd`     | Viatja d'anada i tornada; el jugador hi ha de pujar per creuar el buit     |

### Recorregut (eix −Z)

```
Inici (0) → Pont 1 (−8) → Cinta (−14/−18) → Plataforma central + Pèndol (−26)
→ Pont del pèndol (−34) → Aproximació (−40,5) → Plataforma giratòria (−46)
→ Corredor de pilotes + dispensador (−53) → Trampolí (−54,4)
→ Plataforma elevada (y=2,5; −59) + Barra giratòria (−58)
→ Plataforma mòbil (−66, recorregut 4 m) → Meta (−77/−79)
```

Els tres checkpoints es mantenen (un per zona crítica), però el tercer ara és a la
plataforma elevada, després de l'ascens amb el trampolí.

### Detalls d'implementació

- **Dispensador de pilotes:** les boles s'instancien amb un desfasament aleatori dins d'un
  radi, es reciclen quan baixen per sota del corredor (`despawn_below_y`) i es limita el
  nombre simultani (`max_balls`) per no degradar el rendiment.
- **Boles:** `RigidBody3D` amb `continuous_cd` activat per evitar que travessin el terra a
  gran velocitat. La capa de col·lisió és la d'obstacles i la màscara inclou món i jugador.
- **Empenta proporcional:** la força de retrocés de cada bola escala amb la seva velocitat
  de caiguda, amb un màxim perquè el cop sigui exigent però just.
- **Trampolí:** a més de l'`Area3D` de detecció, inclou un `StaticBody3D` fill que fa de
  terra físic, de manera que el jugador s'hi pot recolzar abans de ser llançat. La força
  està dimensionada perquè l'ascens (≈4,9 m) superi amb marge la plataforma elevada (2,75 m).
- **Plataforma mòbil:** `AnimatableBody3D` amb `sync_to_physics = true`; es mou entre dos
  punts amb una pausa a cada extrem i el jugador la cavalca gràcies a `move_and_slide`.
- **Barra giratòria:** el braç és un cos sòlid (bloqueja) i el seu `Area3D` afegeix el
  retrocés en entrar-hi en contacte, igual que el patró ja usat pel pèndol.

### Decoració i entorn

- Node `Decor` amb **arc de sortida**, **valles**, **columnes** i **pilars de fons**.
  És decoració purament visual (sense col·lisió) per no afectar el joc ni els tests.
- **Cel procedural** (`ProceduralSkyMaterial` + `Sky`) en substitució del color pla, amb
  boira i ambient provinents del cel. Això dóna profunditat al fons i separa visualment
  les zones.

---

## 3. Personatge: física i gràfics

### Física

| Millora                      | Com funciona                                                                                                        |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **Altura de salt variable**  | Si el jugador deixa anar el botó mentre puja, la velocitat vertical es retalla a `min_jump_velocity`. Salt curt a l'instant. |
| **Aturdiment / tambaleo**    | Els cops horitzontals per sobre de `stun_push_threshold` activen un temporitzador durant el qual el control queda reduït a `stun_control`, de manera que l'empenta no es pot cancel·lar a l'instant. |
| **Bounce**                   | Nou mètode `bounce(strength)` per als trampolins; ignora la regla del salt curt i encadena l'animació d'estirament. |
| **Salt ajustat**             | `jump_velocity` passa de 3,5 a 5,0 i l'acceleració/fricció de la cursa s'apugen lleugerament perquè el control sigui més àgil sense perdre la inèrcia característica de l'estil *Stumble*. |
| **Respawn net**              | `respawn_at()` reinicia també l'aturdiment, l'estirament i la inclinació del cos.                                    |

### Gràfics

- **Extremitats animades:** bessons `ArmPivotLeft/Right` i `LegPivotLeft/Right` amb braços i
  cames en fase oposada (carrera, idle, salt i aturdiment).
- **Cara:** cap amb dos ulls i pupil·les, orientats amb la rotació del cos.
- **Estat d'aturdiment:** el cos s'inclina lateralment de manera oscil·lant mentre dura el
  temporitzador, amb una amplitud que decreix.
- **Sombra projectada:** un disc pla que fa un *raycast* cap avall cada frame físic
  (màscara = capa `world`), s'enganxa al terra i s'escala i s'aclareix segons l'altura.
  S'amaga si no hi ha terra a sota.
- **Estela de polvo:** `CPUParticles3D` que s'activa en córrer per sobre d'un llindar de
  velocitat i emet una ràfega curta a cada aterratge.

---

## 4. Verificació

S'ha mantingut i ampliat el joc de proves headless del projecte. Tots quatre passen:

```bash
cd proyecto
godot --headless -s res://tools/check_scenes.gd    # 17/17 escenes OK
godot --headless -s res://tools/smoke_test.gd      # SMOKE OK
godot --headless -s res://tools/flow_test.gd       # RESULT: TODO OK
godot --headless -s res://tools/features_test.gd   # RESULT: TODO OK
```

**`check_scenes.gd`** valida l'arranjament sintàctic de les 17 escenes del projecte
(les 12 anteriors més `bounce_pad`, `sweeper`, `moving_platform`, `ball` i `ball_dropper`).

**`flow_test.gd`** continua recorrent el flux real de joc (menú → carrera → moviment → salt
→ checkpoint → meta → caiguda amb penalització) sense regressions.

**`features_test.gd`** (nou) comprova 31 punts sobre les funcions afegides:

- Presència al mapa dels quatre obstacles nous i de la decoració, i que l'entorn fa servir
  un cel procedural.
- **Càlcul d'abast del trampolí** contra l'altura real de la plataforma elevada.
- **Llançament real:** es deixa caure el jugador sobre el trampolí i es comprova que la
  velocitat vertical arriba a la força configurada.
- Rotació de la barra giratòria i desplaçament de la plataforma mòbil.
- El dispensador genera boles i una bola en caiguda **atura i aturdeix** el jugador.
- Recuperació i reactivació de l'aturdiment.
- **Altura de salt variable** mesurada com a àpex real (1,16 m mantenint el botó enfront
  de 0,50 m deixant-lo anar).
- Existència d'ulls, pupil·les, braços i cames, i que les extremitats es mouen en córrer.
- **Sombra** visible sobre terra i invisible al buit.
- **Geometria del curs:** es deixa caure el jugador sobre cada plataforma nova i es
  comprova l'altura exacta d'aterratge (0,00 / 0,20 / 0,00 / 2,75 / 0,00).
- **Plataforma mòbil cavalcable:** el jugador s'hi recolza i avança amb ella.

---

## 5. Incidències i Decisions

- **El test del salt donava àpex 0:** el jugador encara era a l'aire quan es polsava el
  botó, perquè l'espera de "assentament" era de 15 frames i la caiguda durava més. Solucionat
  esperant que `is_on_floor()` sigui cert abans de saltar. També es va corregir la mesura per
  incloure el pic durant la fase en què es manté el botó (abans es mesurava només la baixada).
- **Àrea d'activació del trampolí:** un `Area3D` no és sòlid, així que el jugador el
  travessaria. S'hi ha afegit un `StaticBody3D` fill que fa de superfície física.
- **Capçalera de columnes del dispensador:** les columnes visuals penjaven cap amunt; s'han
  recol·locat perquè baixin fins al nivell del corredor.
- **Sostres de plataforma:** totes les plataformes de terra s'han unificat a la cara superior
  `y = 0`, i la zona elevada a `y = 2,75`, per evitar escales invisibles entre trams.
- **Travessa de boles:** amb caigudes de 6,5 m una bola ràpida podia travessar el terra;
  resolt amb `continuous_cd` al `RigidBody3D`.
- **Decoració sense col·lisió:** es va decidir que la decoració no generi col·lisió perquè no
  interfereixi amb el joc ni amb les proves automàtiques.
- **Recorregut de la plataforma mòbil:** l'escena tenia un recorregut per defecte de 6 m i, amb
  l'origen a z = −66, l'extrem final s'encavalcava 2 m amb la plataforma de meta. S'ha fixat el
  recorregut a 4 m a la instància de `main.tscn`, de manera que l'extrem final toca exactament
  la vora de la meta.
- **Test inestable per les pilotes:** el `features_test` fallava d'una manera intermitent en
  comprovar les altures d'aterratge, perquè les pilotes del dispensador empenyien el jugador
  fora del punt de caiguda (de z = −51 fins a la plataforma giratòria, a z ≈ −49). No era un
  error del joc sinó del test: ara les comprovacions de geometria **aturen el dispensador i
  netegen les pilotes** abans de mesurar. Detectat executant el test 12 vegades seguides.
- **Mesura de la plataforma mòbil:** com que la plataforma fa pauses als extrems, mesurar el
  desplaçament final donava valors enganyosos. Ara el test acumula el **recorregut** del
  jugador durant una finestra prou llarga, cosa que el fa independent de la fase de la pausa.

---

## 6. Ús d'Intel·ligència Artificial

En aquesta iteració la IA (Freebuff, de Codebuff) s'ha fet servir per a:

- Disseny de les noves zones del mapa i càlcul de l'abast del trampolí en funció de l'altura
  de la plataforma destí.
- Implementació dels quatre obstacles nous i del seu desacoblament (senyals, grups i
  interfícies ja existents com `apply_push()`).
- Implementació de les millores de física (salt variable, aturdiment) i de gràfics
  (extremitats, cara, sombra, pols).
- Ampliació de les proves headless i diagnòstic de per què fallava la mesura del salt.

Tot el codi s'ha revisat i validat executant la bateria de proves completa.

---

## Checklist de la Iteració

| Punt                                                   | Estat |
| ------------------------------------------------------ | ----- |
| Mapa ampliat amb zones noves                           | ✅    |
| Trampolí interactiu i funcional                        | ✅    |
| Plataforma mòbil cavalcable                            | ✅    |
| Barra giratòria que empeny                             | ✅    |
| Dispensador de boles que tiren el jugador enrere       | ✅    |
| Decoració i cel procedural                             | ✅    |
| Salt d'altura variable                                 | ✅    |
| Aturdiment / tambaleo amb pèrdua de control            | ✅    |
| Extremitats i cara animades                            | ✅    |
| Sombra projectada i estela de pols                     | ✅    |
| Sense regressions (`flow_test`)                        | ✅    |
| Proves noves (`features_test`)                         | ✅    |
| README i documentació actualitzats                     | ✅    |
