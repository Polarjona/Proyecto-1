class_name RunnerTuning
extends RefCounted

## Valores compartidos por el jugador y los bots. Tenerlos duplicados fue lo que
## los hizo divergir (dos copias del mismo corredor, numeros distintos).

const GRAVITY_SCALE := 1.15
const RUN_CLIP_SPEED := 2.4
## Fotograma del andar que se congela en el aire (el pack no trae salto).
const JUMP_POSE_TIME := 0.42
const WALK_CLIP_SPEED := 1.0
