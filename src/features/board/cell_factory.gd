extends RefCounted
## Única fábrica "kind (String) -> instancia de nodo" para bloques/íconos del tablero.
## Tanto BoardManager (Modo Infinito, wave_scaling.gd) como Modo Nivel (level_loader.gd)
## pasan por aquí — es el único lugar que hay que tocar para agregar un kind nuevo
## (power-up, bonus, easter egg) a futuro: una constante en wave_scaling.gd + un caso
## acá + su clase de bloque/ícono, y ambos modos lo heredan gratis.
## Uso: const CellFactoryGd := preload("res://src/features/board/cell_factory.gd")

const WaveScalingGd := preload("res://src/features/board/wave_scaling.gd")
const TotopoBlockGd := preload("res://src/features/blocks/totopo_block.gd")
const QuesoBlockGd := preload("res://src/features/blocks/queso_block.gd")
const SalsaJarBlockGd := preload("res://src/features/blocks/salsa_jar_block.gd")
const StoneBlockGd := preload("res://src/features/blocks/stone_block.gd")
const TriangleBlockGd := preload("res://src/features/blocks/triangle_block.gd")
const LemonIconGd := preload("res://src/features/powerups/lemon_icon.gd")
const SeedExtraIconGd := preload("res://src/features/powerups/seed_extra_icon.gd")
const LaserIconGd := preload("res://src/features/powerups/laser_icon.gd")

const KNOWN_KINDS: Array = [
	WaveScalingGd.KIND_TOTOPO,
	WaveScalingGd.KIND_QUESO,
	WaveScalingGd.KIND_SALSA,
	WaveScalingGd.KIND_STONE,
	WaveScalingGd.KIND_TRIANGLE,
	WaveScalingGd.KIND_LEMON,
	WaveScalingGd.KIND_SEED_EXTRA,
	WaveScalingGd.KIND_LASER,
]


## Sin add_child/posición/setup — eso lo decide el llamador, que es quien sabe si el
## hp/corner viene de wave_scaling.gd (Infinito) o de un JSON de nivel (Modo Nivel).
## null para "empty" o cualquier kind desconocido.
static func create_kind_instance(kind: String) -> Node:
	match kind:
		WaveScalingGd.KIND_TOTOPO:
			return TotopoBlockGd.new()
		WaveScalingGd.KIND_QUESO:
			return QuesoBlockGd.new()
		WaveScalingGd.KIND_SALSA:
			return SalsaJarBlockGd.new()
		WaveScalingGd.KIND_STONE:
			return StoneBlockGd.new()
		WaveScalingGd.KIND_TRIANGLE:
			return TriangleBlockGd.new()
		WaveScalingGd.KIND_LEMON:
			return LemonIconGd.new()
		WaveScalingGd.KIND_SEED_EXTRA:
			return SeedExtraIconGd.new()
		WaveScalingGd.KIND_LASER:
			return LaserIconGd.new()
		_:
			return null


static func is_icon_kind(kind: String) -> bool:
	return kind in [
		WaveScalingGd.KIND_LEMON, WaveScalingGd.KIND_SEED_EXTRA, WaveScalingGd.KIND_LASER
	]


static func is_known_kind(kind: String) -> bool:
	return kind in KNOWN_KINDS
