class_name ThumbnailGenerator
extends RefCounted

## Generates thumbnails for assets using background threads.

const FileHasher := preload("res://src/services/file_hasher.gd")

const THUMBNAIL_SIZE := Vector2i(256, 256)
const MAX_CONCURRENT_TASKS := 10

signal thumbnail_generated(asset_id: int, thumbnail_path: String)
signal generation_failed(asset_id: int, error: String)

var _pending_queue: Array[Dictionary] = []
var _active_count := 0
var _mutex := Mutex.new()


## Queues an asset for thumbnail generation.
## Emits thumbnail_generated when complete.
func queue(asset: AssetMeta) -> void:
	if asset.id < 0 or asset.file_path.is_empty():
		return

	_mutex.lock()
	_pending_queue.append({
		"asset_id": asset.id,
		"file_path": asset.file_path,
		"file_hash": asset.file_hash,
	})
	_mutex.unlock()

	_process_queue()


## Queues multiple assets for thumbnail generation.
func queue_batch(assets: Array[AssetMeta]) -> void:
	_mutex.lock()
	for asset in assets:
		if asset.id >= 0 and not asset.file_path.is_empty():
			_pending_queue.append({
				"asset_id": asset.id,
				"file_path": asset.file_path,
				"file_hash": asset.file_hash,
			})
	_mutex.unlock()

	_process_queue()


## Clears all pending generation requests.
func clear_queue() -> void:
	_mutex.lock()
	_pending_queue.clear()
	_mutex.unlock()


func _process_queue() -> void:
	_mutex.lock()
	while _active_count < MAX_CONCURRENT_TASKS and not _pending_queue.is_empty():
		var item: Dictionary = _pending_queue.pop_front()
		_active_count += 1
		WorkerThreadPool.add_task(_generate_thumbnail.bind(item))
	_mutex.unlock()


func _generate_thumbnail(item: Dictionary) -> void:
	var asset_id: int = item["asset_id"]
	var file_path: String = item["file_path"]
	var file_hash: String = item["file_hash"]

	# Compute hash if not provided
	if file_hash.is_empty():
		file_hash = FileHasher.hash_file(file_path)
		if file_hash.is_empty():
			_on_generation_complete(asset_id, "", "Failed to compute file hash")
			return

	# Get thumbnail path
	var thumbnail_path := _get_thumbnail_path(file_hash)

	# Check if thumbnail already exists
	if FileAccess.file_exists(thumbnail_path):
		_on_generation_complete(asset_id, thumbnail_path, "")
		return

	# Get handler for this file type
	var handler = AssetRegistry.get_handler_for_file(file_path)
	if handler == null:
		_on_generation_complete(asset_id, "", "No handler for file type")
		return

	# Generate thumbnail
	var image: Image = handler.generate_thumbnail(file_path, THUMBNAIL_SIZE)
	if image == null:
		_on_generation_complete(asset_id, "", "Failed to generate thumbnail")
		return

	# Ensure directory exists
	var dir := thumbnail_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)

	# Save as WebP
	var error: Error = image.save_webp(thumbnail_path)
	if error != OK:
		_on_generation_complete(asset_id, "", "Failed to save thumbnail: " + str(error))
		return

	_on_generation_complete(asset_id, thumbnail_path, "")


func _on_generation_complete(asset_id: int, thumbnail_path: String, error: String) -> void:
	_mutex.lock()
	_active_count -= 1
	_mutex.unlock()

	# Emit signals on main thread
	if error.is_empty():
		call_deferred("_emit_success", asset_id, thumbnail_path)
	else:
		call_deferred("_emit_failure", asset_id, error)

	# Process more items
	call_deferred("_process_queue")


func _emit_success(asset_id: int, thumbnail_path: String) -> void:
	thumbnail_generated.emit(asset_id, thumbnail_path)


func _emit_failure(asset_id: int, error: String) -> void:
	generation_failed.emit(asset_id, error)


func _get_thumbnail_path(file_hash: String) -> String:
	# Use first 2 characters as subdirectory for better filesystem distribution
	var subdir := file_hash.substr(0, 2)
	return AppConfig.get_thumbnail_path().path_join(subdir).path_join(file_hash + ".webp")


## Gets the expected thumbnail path for a file hash.
## Does not check if the thumbnail exists.
static func get_thumbnail_path_for_hash(file_hash: String) -> String:
	var subdir := file_hash.substr(0, 2)
	return AppConfig.get_thumbnail_path().path_join(subdir).path_join(file_hash + ".webp")


## Checks if a thumbnail exists for a file hash.
static func thumbnail_exists(file_hash: String) -> bool:
	return FileAccess.file_exists(get_thumbnail_path_for_hash(file_hash))
