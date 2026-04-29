class_name WorldGrid
extends Node

signal block_placed(cell: Vector3i, block: Resource)
signal block_broken(cell: Vector3i, block: Resource)

@export var grid_map: GridMap
@export var player: CharacterBody3D
@export var grid_min: Vector3i = Vector3i(-10, 0, -10)
@export var grid_max: Vector3i = Vector3i(10, 16, 10)

const CELL_SIZE := 1.0

func _ready() -> void:
	seed_start_blocks()

func world_to_grid(world_pos: Vector3) -> Vector3i:
	if grid_map != null:
		return grid_map.local_to_map(grid_map.to_local(world_pos))
	return Vector3i(floori(world_pos.x / CELL_SIZE), floori(world_pos.y / CELL_SIZE), floori(world_pos.z / CELL_SIZE))

func grid_to_world(cell: Vector3i) -> Vector3:
	if grid_map != null:
		return grid_map.to_global(grid_map.map_to_local(cell))
	return Vector3(cell) * CELL_SIZE + Vector3.ONE * (CELL_SIZE * 0.5)

func is_in_bounds(cell: Vector3i) -> bool:
	return cell.x >= grid_min.x and cell.x <= grid_max.x and cell.y >= grid_min.y and cell.y <= grid_max.y and cell.z >= grid_min.z and cell.z <= grid_max.z

func get_block_at(cell: Vector3i) -> Resource:
	if grid_map == null or not is_in_bounds(cell):
		return null
	var item := grid_map.get_cell_item(cell)
	if item == GridMap.INVALID_CELL_ITEM:
		return null
	return BlockDB.get_block_by_grid_item_id(item)

func is_cell_empty(cell: Vector3i) -> bool:
	return grid_map != null and is_in_bounds(cell) and grid_map.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM

func can_place_block(cell: Vector3i) -> bool:
	return is_cell_empty(cell) and not cell_overlaps_player(cell)

func place_block(cell: Vector3i, block: Resource) -> bool:
	if block == null or not can_place_block(cell):
		return false
	grid_map.set_cell_item(cell, block.grid_item_id)
	block_placed.emit(cell, block)
	return true

func break_block(cell: Vector3i) -> Resource:
	var block := get_block_at(cell)
	if block == null or not block.is_breakable:
		return null
	grid_map.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
	block_broken.emit(cell, block)
	return block

func cell_overlaps_player(cell: Vector3i) -> bool:
	if player == null:
		return false
	var center := grid_to_world(cell)
	var cell_aabb := AABB(center - Vector3.ONE * 0.5, Vector3.ONE)
	var player_aabb := AABB(player.global_position + Vector3(-0.35, 0.0, -0.35), Vector3(0.7, 1.8, 0.7))
	return cell_aabb.intersects(player_aabb)

func seed_start_blocks() -> void:
	if grid_map == null or grid_map.get_used_cells().size() > 0:
		return
	for x in range(-3, 4):
		for z in range(-3, 4):
			grid_map.set_cell_item(Vector3i(x, 0, z), 2 if abs(x) <= 1 and abs(z) <= 1 else 1)
	# Eye-level test wall directly in front of the spawn so highlight/break works immediately.
	grid_map.set_cell_item(Vector3i(-1, 1, 2), 0)
	grid_map.set_cell_item(Vector3i(0, 1, 2), 3)
	grid_map.set_cell_item(Vector3i(1, 1, 2), 4)
	grid_map.set_cell_item(Vector3i(-1, 2, 2), 1)
	grid_map.set_cell_item(Vector3i(0, 2, 2), 2)
	grid_map.set_cell_item(Vector3i(1, 2, 2), 0)
