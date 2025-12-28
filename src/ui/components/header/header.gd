extends PanelContainer

## Header component with project dropdown and settings button.

@onready var project_dropdown: OptionButton = %ProjectDropdown
@onready var settings_button: Button = %SettingsButton

var _projects: Array[Project] = []


func _ready() -> void:
	project_dropdown.item_selected.connect(_on_project_selected)
	settings_button.pressed.connect(_on_settings_pressed)

	EventBus.project_changed.connect(_on_project_changed)
	EventBus.project_created.connect(_on_project_created)
	EventBus.project_deleted.connect(_on_project_deleted)

	_refresh_projects()


func _refresh_projects() -> void:
	project_dropdown.clear()
	_projects = ProjectManager.get_all_projects()

	var current_idx := 0
	for i in range(_projects.size()):
		var project := _projects[i]
		project_dropdown.add_item(project.name, project.id)
		if ProjectManager.current_project and project.id == ProjectManager.current_project.id:
			current_idx = i

	if not _projects.is_empty():
		project_dropdown.select(current_idx)


func _on_project_selected(index: int) -> void:
	if index < 0 or index >= _projects.size():
		return

	var project := _projects[index]
	if ProjectManager.current_project == null or project.id != ProjectManager.current_project.id:
		ProjectManager.switch_project(project.id)


func _on_settings_pressed() -> void:
	# TODO: Open settings dialog
	print("Settings button pressed")


func _on_project_changed(_project) -> void:
	_refresh_projects()


func _on_project_created(_project) -> void:
	_refresh_projects()


func _on_project_deleted(_project_id: int) -> void:
	_refresh_projects()
