extends Node

## Caches and manages thumbnails for assets.
## Handles loading from disk and queuing generation for missing thumbnails.

const ThumbnailGeneratorClass := preload("res://src/services/thumbnail_generator.gd")
const AssetMetaClass := preload("res://src/database/models/asset_meta.gd")

const MAX_CACHE_SIZE := 500  # Maximum number of textures to cache in memory
const PLACEHOLDER_COLOR := Color(0.2, 0.2, 0.2, 1.0)

# In-memory texture cache: file_hash -> Texture2D
var _cache: Dictionary = {}

# LRU tracking: Array of file hashes, most recently used at the end
var _lru: Array[String] = []

# Pending requests: asset_id -> callback
var _pending: Dictionary = {}

# Generator instance
var _generator

# Placeholder texture for missing thumbnails
var _placeholder: Texture2D


func _ready() -> void:
	_generator = ThumbnailGeneratorClass.new()
	_generator.thumbnail_generated.connect(_on_thumbnail_generated)
	_generator.generation_failed.connect(_on_generation_failed)
	_create_placeholder()


func _create_placeholder() -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(PLACEHOLDER_COLOR)
	_placeholder = ImageTexture.create_from_image(image)


## Gets a thumbnail texture for an asset.
## Returns the cached texture immediately if available.
## Returns placeholder and queues generation if not cached.
func get_thumbnail(asset) -> Texture2D:
	if asset.file_hash.is_empty():
		return _placeholder

	# Check memory cache
	if _cache.has(asset.file_hash):
		_touch_lru(asset.file_hash)
		return _cache[asset.file_hash]

	# Check disk cache
	var thumbnail_path := ThumbnailGeneratorClass.get_thumbnail_path_for_hash(asset.file_hash)
	if FileAccess.file_exists(thumbnail_path):
		var texture := _load_thumbnail(thumbnail_path)
		if texture:
			_add_to_cache(asset.file_hash, texture)
			return texture

	# Queue generation
	_generator.queue(asset)
	return _placeholder


## Gets a thumbnail texture asynchronously.
## Calls the callback when the thumbnail is ready: callback(texture: Texture2D)
func get_thumbnail_async(asset, callback: Callable) -> void:
	if asset.file_hash.is_empty():
		callback.call(_placeholder)
		return

	# Check memory cache
	if _cache.has(asset.file_hash):
		_touch_lru(asset.file_hash)
		callback.call(_cache[asset.file_hash])
		return

	# Check disk cache
	var thumbnail_path := ThumbnailGeneratorClass.get_thumbnail_path_for_hash(asset.file_hash)
	if FileAccess.file_exists(thumbnail_path):
		var texture := _load_thumbnail(thumbnail_path)
		if texture:
			_add_to_cache(asset.file_hash, texture)
			callback.call(texture)
			return

	# Queue generation and store callback
	_pending[asset.id] = callback
	_generator.queue(asset)


## Preloads thumbnails for a list of assets.
## Does not block; thumbnails are cached as they're generated.
func preload_thumbnails(assets: Array) -> void:
	var to_generate: Array = []

	for asset in assets:
		if asset.file_hash.is_empty():
			continue

		# Skip if already in memory cache
		if _cache.has(asset.file_hash):
			continue

		# Try to load from disk
		var thumbnail_path := ThumbnailGeneratorClass.get_thumbnail_path_for_hash(asset.file_hash)
		if FileAccess.file_exists(thumbnail_path):
			var texture := _load_thumbnail(thumbnail_path)
			if texture:
				_add_to_cache(asset.file_hash, texture)
				continue

		# Needs generation
		to_generate.append(asset)

	if not to_generate.is_empty():
		_generator.queue_batch(to_generate)


## Clears the memory cache.
func clear_memory_cache() -> void:
	_cache.clear()
	_lru.clear()


## Clears the disk cache (thumbnails folder).
func clear_disk_cache() -> void:
	var thumbnail_path := AppConfig.get_thumbnail_path()
	var dir := DirAccess.open(thumbnail_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## Clears both memory and disk cache.
func clear_all_cache() -> void:
	clear_memory_cache()
	clear_disk_cache()


## Gets the disk cache size in bytes.
func get_disk_cache_size() -> int:
	var thumbnail_path := AppConfig.get_thumbnail_path()
	var dir := DirAccess.open(thumbnail_path)
	if dir == null:
		return 0

	var total_size := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			var file_path := thumbnail_path.path_join(file_name)
			var file := FileAccess.open(file_path, FileAccess.READ)
			if file:
				total_size += file.get_length()
				file.close()
		file_name = dir.get_next()
	dir.list_dir_end()

	return total_size


## Gets the disk cache file count.
func get_disk_cache_count() -> int:
	var thumbnail_path := AppConfig.get_thumbnail_path()
	var dir := DirAccess.open(thumbnail_path)
	if dir == null:
		return 0

	var count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	return count


## Clears pending generation requests.
func clear_pending() -> void:
	_pending.clear()
	_generator.clear_queue()


## Returns the placeholder texture.
func get_placeholder() -> Texture2D:
	return _placeholder


## Returns cache statistics.
func get_stats() -> Dictionary:
	return {
		"cached_count": _cache.size(),
		"max_size": MAX_CACHE_SIZE,
		"pending_count": _pending.size(),
	}


func _load_thumbnail(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


func _add_to_cache(file_hash: String, texture: Texture2D) -> void:
	# Evict oldest entries if cache is full
	while _cache.size() >= MAX_CACHE_SIZE and not _lru.is_empty():
		var oldest: String = _lru.pop_front()
		_cache.erase(oldest)

	_cache[file_hash] = texture
	_lru.append(file_hash)


func _touch_lru(file_hash: String) -> void:
	var idx := _lru.find(file_hash)
	if idx >= 0:
		_lru.remove_at(idx)
		_lru.append(file_hash)


func _on_thumbnail_generated(asset_id: int, thumbnail_path: String) -> void:
	var texture := _load_thumbnail(thumbnail_path)
	if texture == null:
		_on_generation_failed(asset_id, "Failed to load generated thumbnail")
		return

	# Get the asset to find its hash
	var asset = AssetMetaClass.find(asset_id)
	if asset and not asset.file_hash.is_empty():
		_add_to_cache(asset.file_hash, texture)

	# Call pending callback
	if _pending.has(asset_id):
		var callback: Callable = _pending[asset_id]
		_pending.erase(asset_id)
		callback.call(texture)

	# Emit global event
	EventBus.thumbnail_ready.emit(asset_id, texture)


func _on_generation_failed(asset_id: int, error: String) -> void:
	push_warning("Thumbnail generation failed for asset ", asset_id, ": ", error)

	# Call pending callback with placeholder
	if _pending.has(asset_id):
		var callback: Callable = _pending[asset_id]
		_pending.erase(asset_id)
		callback.call(_placeholder)

	EventBus.thumbnail_generation_failed.emit(asset_id, error)
