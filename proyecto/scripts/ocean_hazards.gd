extends Node

## Registro de los obstáculos marinos de Abyss Run.
##
## Cada obstáculo vive en su propio script (`scripts/ocean/`) porque los
## scripts anidados no se pueden guardar dentro de una escena: así el nivel
## se puede hornear en el `.tscn` y editar en Godot.
##
## Se instancian como `OCEAN_HAZARDS.Urchin.new()` desde `level_builder.gd`.

const Urchin := preload("res://scripts/ocean/urchin.gd")
const KelpWhip := preload("res://scripts/ocean/kelp_whip.gd")
const BubbleMine := preload("res://scripts/ocean/bubble_mine.gd")
const CurrentRibbon := preload("res://scripts/ocean/current_ribbon.gd")
const Jellyfish := preload("res://scripts/ocean/jellyfish.gd")
const AnglerLure := preload("res://scripts/ocean/angler_lure.gd")
const Whirlpool := preload("res://scripts/ocean/whirlpool.gd")
const Pufferfish := preload("res://scripts/ocean/pufferfish.gd")
const ClamSnap := preload("res://scripts/ocean/clam_snap.gd")
const CoralFan := preload("res://scripts/ocean/coral_fan.gd")
const ThermalVent := preload("res://scripts/ocean/thermal_vent.gd")
const DriftIce := preload("res://scripts/ocean/drift_ice.gd")
const InkCloud := preload("res://scripts/ocean/ink_cloud.gd")
const MineChain := preload("res://scripts/ocean/mine_chain.gd")
const StarfishSpinner := preload("res://scripts/ocean/starfish_spinner.gd")
const BoostRing := preload("res://scripts/ocean/boost_ring.gd")
const Updraft := preload("res://scripts/ocean/updraft.gd")
