class_name Project
extends RefCounted

## Project data model.

var id: int = -1
var name: String = ""
var created_at: int = 0
var last_opened: int = 0
var settings: Dictionary = {}


static func from_row(row: Dictionary) -> Project:
	var project := Project.new()
	project.id = row.get("id", -1)
	project.name = row.get("name", "")
	project.created_at = row.get("created_at", 0)
	project.last_opened = row.get("last_opened", 0)

	var settings_json: String = row.get("settings_json", "{}")
	if settings_json.is_empty():
		settings_json = "{}"
	var parsed = JSON.parse_string(settings_json)
	project.settings = parsed if parsed is Dictionary else {}

	return project


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"created_at": created_at,
		"last_opened": last_opened,
		"settings_json": JSON.stringify(settings),
	}


func save() -> bool:
	var now := int(Time.get_unix_time_from_system())

	if id < 0:
		# Insert new project
		created_at = now
		last_opened = now
		var success := Database.execute(
			"INSERT INTO projects (name, created_at, last_opened, settings_json) VALUES (?, ?, ?, ?)",
			[name, created_at, last_opened, JSON.stringify(settings)]
		)
		if success:
			id = Database.get_last_insert_id()
		return success
	else:
		# Update existing project
		return Database.execute(
			"UPDATE projects SET name = ?, last_opened = ?, settings_json = ? WHERE id = ?",
			[name, last_opened, JSON.stringify(settings), id]
		)


func delete() -> bool:
	if id < 0:
		return false
	return Database.execute("DELETE FROM projects WHERE id = ?", [id])


static func find(project_id: int) -> Project:
	var row = Database.query_one("SELECT * FROM projects WHERE id = ?", [project_id])
	if row == null:
		return null
	return from_row(row)


static func all() -> Array[Project]:
	var rows := Database.query("SELECT * FROM projects ORDER BY last_opened DESC")
	var projects: Array[Project] = []
	for row in rows:
		projects.append(from_row(row))
	return projects


static func count() -> int:
	var result = Database.query_one("SELECT COUNT(*) as count FROM projects")
	if result == null:
		return 0
	return result["count"]
