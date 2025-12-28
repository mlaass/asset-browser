class_name AssetMeta
extends RefCounted

## Asset metadata model.

var id: int = -1
var project_id: int = -1
var file_path: String = ""
var file_hash: String = ""
var is_favorite: bool = false
var notes: String = ""
var thumbnail_path: String = ""
var last_modified: int = 0
var edits: Dictionary = {}

# Cached tags (loaded on demand)
var _tags: Array[Tag] = []
var _tags_loaded := false


static func from_row(row: Dictionary) -> AssetMeta:
	var asset := AssetMeta.new()
	asset.id = row.get("id", -1)
	asset.project_id = row.get("project_id", -1)
	asset.file_path = row.get("file_path", "")
	asset.file_hash = row.get("file_hash", "")
	asset.is_favorite = row.get("is_favorite", 0) == 1
	asset.notes = row.get("notes", "")
	asset.thumbnail_path = row.get("thumbnail_path", "")
	asset.last_modified = row.get("last_modified", 0)

	var edits_json: String = row.get("edits_json", "")
	if not edits_json.is_empty():
		var parsed = JSON.parse_string(edits_json)
		asset.edits = parsed if parsed is Dictionary else {}

	return asset


func to_dict() -> Dictionary:
	return {
		"id": id,
		"project_id": project_id,
		"file_path": file_path,
		"file_hash": file_hash,
		"is_favorite": 1 if is_favorite else 0,
		"notes": notes,
		"thumbnail_path": thumbnail_path,
		"last_modified": last_modified,
		"edits_json": JSON.stringify(edits) if not edits.is_empty() else "",
	}


func save() -> bool:
	var edits_json := JSON.stringify(edits) if not edits.is_empty() else ""

	if id < 0:
		# Insert new asset
		var success := Database.execute(
			"""INSERT INTO asset_meta
			(project_id, file_path, file_hash, is_favorite, notes, thumbnail_path, last_modified, edits_json)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
			[project_id, file_path, file_hash, 1 if is_favorite else 0, notes, thumbnail_path, last_modified, edits_json]
		)
		if success:
			id = Database.get_last_insert_id()
		return success
	else:
		# Update existing asset
		return Database.execute(
			"""UPDATE asset_meta SET
			file_hash = ?, is_favorite = ?, notes = ?, thumbnail_path = ?, last_modified = ?, edits_json = ?
			WHERE id = ?""",
			[file_hash, 1 if is_favorite else 0, notes, thumbnail_path, last_modified, edits_json, id]
		)


func delete() -> bool:
	if id < 0:
		return false
	return Database.execute("DELETE FROM asset_meta WHERE id = ?", [id])


func get_filename() -> String:
	return file_path.get_file()


func get_extension() -> String:
	return file_path.get_extension().to_lower()


func file_exists() -> bool:
	return FileAccess.file_exists(file_path)


# Tag management
func get_tags() -> Array[Tag]:
	if not _tags_loaded:
		_load_tags()
	return _tags


func _load_tags() -> void:
	_tags.clear()
	if id < 0:
		_tags_loaded = true
		return

	var rows := Database.query(
		"""SELECT t.* FROM tags t
		INNER JOIN asset_tags at ON t.id = at.tag_id
		WHERE at.asset_id = ?
		ORDER BY t.sort_order, t.name""",
		[id]
	)
	for row in rows:
		_tags.append(Tag.from_row(row))
	_tags_loaded = true


func add_tag(tag: Tag) -> bool:
	if id < 0 or tag.id < 0:
		return false

	var success := Database.execute(
		"INSERT OR IGNORE INTO asset_tags (asset_id, tag_id) VALUES (?, ?)",
		[id, tag.id]
	)
	if success:
		_tags_loaded = false  # Invalidate cache
	return success


func remove_tag(tag: Tag) -> bool:
	if id < 0 or tag.id < 0:
		return false

	var success := Database.execute(
		"DELETE FROM asset_tags WHERE asset_id = ? AND tag_id = ?",
		[id, tag.id]
	)
	if success:
		_tags_loaded = false  # Invalidate cache
	return success


func has_tag(tag: Tag) -> bool:
	return get_tags().any(func(t: Tag) -> bool: return t.id == tag.id)


func set_favorite(favorite: bool) -> bool:
	is_favorite = favorite
	return Database.execute(
		"UPDATE asset_meta SET is_favorite = ? WHERE id = ?",
		[1 if is_favorite else 0, id]
	)


func set_notes(new_notes: String) -> bool:
	notes = new_notes
	return Database.execute(
		"UPDATE asset_meta SET notes = ? WHERE id = ?",
		[notes, id]
	)


# Static finders
static func find(asset_id: int) -> AssetMeta:
	var row = Database.query_one("SELECT * FROM asset_meta WHERE id = ?", [asset_id])
	if row == null:
		return null
	return from_row(row)


static func find_by_path(project_id: int, path: String) -> AssetMeta:
	var row = Database.query_one(
		"SELECT * FROM asset_meta WHERE project_id = ? AND file_path = ?",
		[project_id, path]
	)
	if row == null:
		return null
	return from_row(row)


static func for_project(project_id: int, limit: int = 0, offset: int = 0) -> Array[AssetMeta]:
	var sql := "SELECT * FROM asset_meta WHERE project_id = ? ORDER BY file_path"
	if limit > 0:
		sql += " LIMIT %d OFFSET %d" % [limit, offset]

	var rows := Database.query(sql, [project_id])
	var assets: Array[AssetMeta] = []
	for row in rows:
		assets.append(from_row(row))
	return assets


static func for_folder(project_id: int, folder_path: String) -> Array[AssetMeta]:
	# Match files in this folder (not recursively)
	var pattern := folder_path.rstrip("/") + "/%"
	var rows := Database.query(
		"""SELECT * FROM asset_meta
		WHERE project_id = ? AND file_path LIKE ? AND file_path NOT LIKE ?
		ORDER BY file_path""",
		[project_id, pattern, pattern + "/%"]
	)
	var assets: Array[AssetMeta] = []
	for row in rows:
		assets.append(from_row(row))
	return assets


static func favorites_for_project(project_id: int) -> Array[AssetMeta]:
	var rows := Database.query(
		"SELECT * FROM asset_meta WHERE project_id = ? AND is_favorite = 1 ORDER BY file_path",
		[project_id]
	)
	var assets: Array[AssetMeta] = []
	for row in rows:
		assets.append(from_row(row))
	return assets


static func with_tag(project_id: int, tag_id: int) -> Array[AssetMeta]:
	var rows := Database.query(
		"""SELECT am.* FROM asset_meta am
		INNER JOIN asset_tags at ON am.id = at.asset_id
		WHERE am.project_id = ? AND at.tag_id = ?
		ORDER BY am.file_path""",
		[project_id, tag_id]
	)
	var assets: Array[AssetMeta] = []
	for row in rows:
		assets.append(from_row(row))
	return assets


static func with_all_tags(project_id: int, tag_ids: Array) -> Array[AssetMeta]:
	if tag_ids.is_empty():
		return []

	# Build placeholders for IN clause
	var placeholders: Array[String] = []
	for _i in range(tag_ids.size()):
		placeholders.append("?")

	var params: Array = [project_id]
	params.append_array(tag_ids)
	params.append(tag_ids.size())

	var rows := Database.query(
		"""SELECT am.* FROM asset_meta am
		INNER JOIN asset_tags at ON am.id = at.asset_id
		WHERE am.project_id = ? AND at.tag_id IN (%s)
		GROUP BY am.id
		HAVING COUNT(DISTINCT at.tag_id) = ?
		ORDER BY am.file_path""" % ",".join(placeholders),
		params
	)
	var assets: Array[AssetMeta] = []
	for row in rows:
		assets.append(from_row(row))
	return assets


static func search(project_id: int, query: String) -> Array[AssetMeta]:
	var pattern := "%" + query + "%"
	var rows := Database.query(
		"SELECT * FROM asset_meta WHERE project_id = ? AND file_path LIKE ? ORDER BY file_path",
		[project_id, pattern]
	)
	var assets: Array[AssetMeta] = []
	for row in rows:
		assets.append(from_row(row))
	return assets


static func count_for_project(project_id: int) -> int:
	var result = Database.query_one(
		"SELECT COUNT(*) as count FROM asset_meta WHERE project_id = ?",
		[project_id]
	)
	if result == null:
		return 0
	return result["count"]
