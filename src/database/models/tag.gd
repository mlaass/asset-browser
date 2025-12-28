class_name Tag
extends RefCounted

## Tag data model.

var id: int = -1
var project_id: int = -1
var name: String = ""
var color: String = "#808080"
var sort_order: int = 0


static func from_row(row: Dictionary) -> Tag:
	var tag := Tag.new()
	tag.id = row.get("id", -1)
	tag.project_id = row.get("project_id", -1)
	tag.name = row.get("name", "")
	tag.color = row.get("color", "#808080")
	tag.sort_order = row.get("sort_order", 0)
	return tag


func to_dict() -> Dictionary:
	return {
		"id": id,
		"project_id": project_id,
		"name": name,
		"color": color,
		"sort_order": sort_order,
	}


func get_color() -> Color:
	return Color.from_string(color, Color.GRAY)


func save() -> bool:
	if id < 0:
		# Insert new tag
		var success := Database.execute(
			"INSERT INTO tags (project_id, name, color, sort_order) VALUES (?, ?, ?, ?)",
			[project_id, name, color, sort_order]
		)
		if success:
			id = Database.get_last_insert_id()
		return success
	else:
		# Update existing tag
		return Database.execute(
			"UPDATE tags SET name = ?, color = ?, sort_order = ? WHERE id = ?",
			[name, color, sort_order, id]
		)


func delete() -> bool:
	if id < 0:
		return false
	# asset_tags will be deleted by CASCADE
	return Database.execute("DELETE FROM tags WHERE id = ?", [id])


func get_asset_count() -> int:
	var result = Database.query_one(
		"SELECT COUNT(*) as count FROM asset_tags WHERE tag_id = ?",
		[id]
	)
	if result == null:
		return 0
	return result["count"]


static func find(tag_id: int) -> Tag:
	var row = Database.query_one("SELECT * FROM tags WHERE id = ?", [tag_id])
	if row == null:
		return null
	return from_row(row)


static func for_project(project_id: int) -> Array[Tag]:
	var rows := Database.query(
		"SELECT * FROM tags WHERE project_id = ? ORDER BY sort_order, name",
		[project_id]
	)
	var tags: Array[Tag] = []
	for row in rows:
		tags.append(from_row(row))
	return tags


static func find_by_name(project_id: int, tag_name: String) -> Tag:
	var row = Database.query_one(
		"SELECT * FROM tags WHERE project_id = ? AND name = ?",
		[project_id, tag_name]
	)
	if row == null:
		return null
	return from_row(row)


static func get_next_sort_order(project_id: int) -> int:
	var result = Database.query_one(
		"SELECT MAX(sort_order) as max_order FROM tags WHERE project_id = ?",
		[project_id]
	)
	if result == null or result["max_order"] == null:
		return 0
	return result["max_order"] + 1
