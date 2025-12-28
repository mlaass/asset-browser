extends Node

## Manages the current project and project-related operations.

const ProjectClass := preload("res://src/database/models/project.gd")
const WatchedFolderClass := preload("res://src/database/models/watched_folder.gd")
const TagClass := preload("res://src/database/models/tag.gd")

var current_project = null  # ProjectClass instance


func _ready() -> void:
	# Wait for database to be ready
	await get_tree().process_frame

	_load_or_create_initial_project()


func _load_or_create_initial_project() -> void:
	var projects := get_all_projects()

	if projects.is_empty():
		# Create default project
		var project = create_project("Default Project")
		if project:
			switch_project(project.id)
	else:
		# Load most recently opened project
		switch_project(projects[0].id)


# Project CRUD

func create_project(project_name: String):
	var project = ProjectClass.new()
	project.name = project_name

	if project.save():
		EventBus.project_created.emit(project)
		return project

	push_error("Failed to create project: " + project_name)
	return null


func get_all_projects() -> Array:
	return ProjectClass.all()


func get_project(project_id: int):
	return ProjectClass.find(project_id)


func update_project(project) -> bool:
	return project.save()


func delete_project(project_id: int) -> bool:
	var project = ProjectClass.find(project_id)
	if project == null:
		return false

	if project.delete():
		EventBus.project_deleted.emit(project_id)

		# If we deleted the current project, switch to another
		if current_project and current_project.id == project_id:
			var projects := get_all_projects()
			if not projects.is_empty():
				switch_project(projects[0].id)
			else:
				current_project = null
				EventBus.project_changed.emit(null)

		return true

	return false


# Project switching

func switch_project(project_id: int) -> bool:
	var project = ProjectClass.find(project_id)
	if project == null:
		push_error("Project not found: ", project_id)
		return false

	# Update last_opened timestamp
	project.last_opened = int(Time.get_unix_time_from_system())
	project.save()

	current_project = project
	EventBus.project_changed.emit(project)
	print("Switched to project: ", project.name)
	return true


# Watched folders

func get_watched_folders() -> Array:
	if current_project == null:
		return []
	return WatchedFolderClass.for_project(current_project.id)


func add_watched_folder(folder_path: String, recursive: bool = true):
	if current_project == null:
		push_error("No current project")
		return null

	# Check if already watching this folder
	if WatchedFolderClass.exists_for_project(current_project.id, folder_path):
		push_warning("Folder already watched: ", folder_path)
		return null

	var folder = WatchedFolderClass.new()
	folder.path = folder_path
	folder.project_id = current_project.id
	folder.recursive = recursive

	if folder.save():
		EventBus.watched_folder_added.emit(folder)
		return folder

	push_error("Failed to add watched folder: ", folder_path)
	return null


func remove_watched_folder(folder_id: int) -> bool:
	var folder = WatchedFolderClass.find(folder_id)
	if folder == null:
		return false

	if folder.delete():
		EventBus.watched_folder_removed.emit(folder_id)
		return true

	return false


# Tags

func get_tags() -> Array:
	if current_project == null:
		return []
	return TagClass.for_project(current_project.id)


func create_tag(tag_name: String, tag_color: String = "#808080"):
	if current_project == null:
		push_error("No current project")
		return null

	var tag = TagClass.new()
	tag.project_id = current_project.id
	tag.name = tag_name
	tag.color = tag_color
	tag.sort_order = TagClass.get_next_sort_order(current_project.id)

	if tag.save():
		EventBus.tag_created.emit(tag)
		return tag

	push_error("Failed to create tag: ", tag_name)
	return null


func update_tag(tag) -> bool:
	if tag.save():
		EventBus.tag_updated.emit(tag)
		return true
	return false


func delete_tag(tag_id: int) -> bool:
	var tag = TagClass.find(tag_id)
	if tag == null:
		return false

	if tag.delete():
		EventBus.tag_deleted.emit(tag_id)
		return true

	return false
