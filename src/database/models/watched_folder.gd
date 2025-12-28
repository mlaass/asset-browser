class_name WatchedFolder
extends RefCounted

## WatchedFolder data model.

var id: int = -1
var path: String = ""
var project_id: int = -1
var recursive: bool = true
var last_indexed: int = 0


static func from_row(row: Dictionary) -> WatchedFolder:
	var folder := WatchedFolder.new()
	folder.id = row.get("id", -1)
	folder.path = row.get("path", "")
	folder.project_id = row.get("project_id", -1)
	folder.recursive = row.get("recursive", 1) == 1
	folder.last_indexed = row.get("last_indexed", 0)
	return folder


func to_dict() -> Dictionary:
	return {
		"id": id,
		"path": path,
		"project_id": project_id,
		"recursive": 1 if recursive else 0,
		"last_indexed": last_indexed,
	}


func save() -> bool:
	if id < 0:
		# Insert new watched folder
		var success := Database.execute(
			"INSERT INTO watched_folders (path, project_id, recursive, last_indexed) VALUES (?, ?, ?, ?)",
			[path, project_id, 1 if recursive else 0, last_indexed]
		)
		if success:
			id = Database.get_last_insert_id()
		return success
	else:
		# Update existing watched folder
		return Database.execute(
			"UPDATE watched_folders SET path = ?, recursive = ?, last_indexed = ? WHERE id = ?",
			[path, 1 if recursive else 0, last_indexed, id]
		)


func delete() -> bool:
	if id < 0:
		return false
	return Database.execute("DELETE FROM watched_folders WHERE id = ?", [id])


func update_last_indexed() -> bool:
	last_indexed = int(Time.get_unix_time_from_system())
	return Database.execute(
		"UPDATE watched_folders SET last_indexed = ? WHERE id = ?",
		[last_indexed, id]
	)


static func find(folder_id: int) -> WatchedFolder:
	var row = Database.query_one("SELECT * FROM watched_folders WHERE id = ?", [folder_id])
	if row == null:
		return null
	return from_row(row)


static func for_project(project_id: int) -> Array[WatchedFolder]:
	var rows := Database.query(
		"SELECT * FROM watched_folders WHERE project_id = ? ORDER BY path",
		[project_id]
	)
	var folders: Array[WatchedFolder] = []
	for row in rows:
		folders.append(from_row(row))
	return folders


static func exists_for_project(project_id: int, folder_path: String) -> bool:
	var result = Database.query_one(
		"SELECT id FROM watched_folders WHERE project_id = ? AND path = ?",
		[project_id, folder_path]
	)
	return result != null
