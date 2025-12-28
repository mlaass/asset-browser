class_name Indexer
extends RefCounted

## Background indexer for scanning folders and creating asset metadata.

const FileHasher := preload("res://src/services/file_hasher.gd")

signal progress(folder_path: String, current: int, total: int)
signal completed(folder_path: String, count: int)
signal cancelled(folder_path: String)

var _is_cancelled := false
var _mutex := Mutex.new()


## Indexes a watched folder, creating AssetMeta records for all supported files.
## Runs on a background thread.
func index_folder(watched_folder: WatchedFolder) -> void:
	_is_cancelled = false
	WorkerThreadPool.add_task(_index_folder_task.bind(watched_folder))


## Cancels the current indexing operation.
func cancel() -> void:
	_mutex.lock()
	_is_cancelled = true
	_mutex.unlock()


func _index_folder_task(watched_folder: WatchedFolder) -> void:
	var path := watched_folder.path
	var project_id := watched_folder.project_id
	var recursive := watched_folder.recursive

	# Collect all files first
	var files := _collect_files(path, recursive)
	var total := files.size()

	call_deferred("_emit_progress", path, 0, total)

	var count := 0
	for i in range(files.size()):
		_mutex.lock()
		var should_cancel := _is_cancelled
		_mutex.unlock()

		if should_cancel:
			call_deferred("_emit_cancelled", path)
			return

		var file_path: String = files[i]
		_index_file(file_path, project_id)
		count += 1

		# Emit progress every 10 files
		if count % 10 == 0 or count == total:
			call_deferred("_emit_progress", path, count, total)

	# Update last indexed timestamp
	watched_folder.update_last_indexed()

	call_deferred("_emit_completed", path, count)


func _collect_files(path: String, recursive: bool) -> Array[String]:
	var files: Array[String] = []
	_collect_files_recursive(path, recursive, files)
	return files


func _collect_files_recursive(path: String, recursive: bool, files: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			if recursive and not file_name.begins_with("."):
				_collect_files_recursive(full_path, true, files)
		else:
			if AssetRegistry.is_supported(file_name):
				files.append(full_path)

		file_name = dir.get_next()
	dir.list_dir_end()


func _index_file(file_path: String, project_id: int) -> void:
	# Check if already indexed
	var existing := AssetMeta.find_by_path(project_id, file_path)
	if existing:
		# Check if file has changed
		var current_modified := FileHasher.get_modification_time(file_path)
		if existing.last_modified == current_modified:
			return  # No change

		# File changed, update hash
		existing.file_hash = FileHasher.hash_file(file_path)
		existing.last_modified = current_modified
		existing.thumbnail_path = ""  # Clear thumbnail to regenerate
		existing.save()
		return

	# Create new asset meta
	var asset := AssetMeta.new()
	asset.project_id = project_id
	asset.file_path = file_path
	asset.file_hash = FileHasher.hash_file(file_path)
	asset.last_modified = FileHasher.get_modification_time(file_path)
	asset.save()


func _emit_progress(folder_path: String, current: int, total: int) -> void:
	progress.emit(folder_path, current, total)
	EventBus.indexing_progress.emit(folder_path, current, total)


func _emit_completed(folder_path: String, count: int) -> void:
	completed.emit(folder_path, count)
	EventBus.indexing_completed.emit(folder_path, count)


func _emit_cancelled(folder_path: String) -> void:
	cancelled.emit(folder_path)
	EventBus.indexing_cancelled.emit(folder_path)


## Indexes all watched folders for a project.
static func index_project(project: Project) -> void:
	var folders := WatchedFolder.for_project(project.id)
	for folder in folders:
		var indexer := Indexer.new()
		indexer.index_folder(folder)


## Re-indexes a single file, updating its metadata.
static func reindex_file(asset: AssetMeta) -> void:
	if not FileAccess.file_exists(asset.file_path):
		return

	asset.file_hash = FileHasher.hash_file(asset.file_path)
	asset.last_modified = FileHasher.get_modification_time(asset.file_path)
	asset.thumbnail_path = ""
	asset.save()
