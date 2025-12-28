extends MenuBar

## Application menu bar with File, Edit, View, Project, Help menus.

# Menu item IDs
enum FileMenu { NEW_PROJECT, OPEN_PROJECT, SEP1, ADD_FOLDER, SEP2, SETTINGS, SEP3, QUIT }
enum EditMenu { SELECT_ALL, DESELECT_ALL, SEP1, DELETE_SELECTED }
enum ViewMenu { GRID_VIEW, LIST_VIEW, SEP1, SHOW_PREVIEW, SHOW_NAVIGATION, SEP2, REFRESH }
enum ProjectMenu { RENAME_PROJECT, DELETE_PROJECT, SEP1, REINDEX_ALL }
enum HelpMenu { ABOUT }

@onready var file_menu: PopupMenu = $File
@onready var edit_menu: PopupMenu = $Edit
@onready var view_menu: PopupMenu = $View
@onready var project_menu: PopupMenu = $Project
@onready var help_menu: PopupMenu = $Help


func _ready() -> void:
	_setup_file_menu()
	_setup_edit_menu()
	_setup_view_menu()
	_setup_project_menu()
	_setup_help_menu()

	file_menu.id_pressed.connect(_on_file_menu_pressed)
	edit_menu.id_pressed.connect(_on_edit_menu_pressed)
	view_menu.id_pressed.connect(_on_view_menu_pressed)
	project_menu.id_pressed.connect(_on_project_menu_pressed)
	help_menu.id_pressed.connect(_on_help_menu_pressed)


func _setup_file_menu() -> void:
	file_menu.add_item("New Project...", FileMenu.NEW_PROJECT)
	file_menu.add_item("Open Project...", FileMenu.OPEN_PROJECT)
	file_menu.add_separator()
	file_menu.add_item("Add Watched Folder...", FileMenu.ADD_FOLDER)
	file_menu.add_separator()
	file_menu.add_item("Settings...", FileMenu.SETTINGS)
	file_menu.add_separator()
	file_menu.add_item("Quit", FileMenu.QUIT)

	# Shortcuts
	file_menu.set_item_shortcut(file_menu.get_item_index(FileMenu.NEW_PROJECT),
		_create_shortcut(KEY_N, true, true))
	file_menu.set_item_shortcut(file_menu.get_item_index(FileMenu.QUIT),
		_create_shortcut(KEY_Q, true))


func _setup_edit_menu() -> void:
	edit_menu.add_item("Select All", EditMenu.SELECT_ALL)
	edit_menu.add_item("Deselect All", EditMenu.DESELECT_ALL)
	edit_menu.add_separator()
	edit_menu.add_item("Remove from Index", EditMenu.DELETE_SELECTED)

	# Shortcuts
	edit_menu.set_item_shortcut(edit_menu.get_item_index(EditMenu.SELECT_ALL),
		_create_shortcut(KEY_A, true))


func _setup_view_menu() -> void:
	view_menu.add_radio_check_item("Grid View", ViewMenu.GRID_VIEW)
	view_menu.add_radio_check_item("List View", ViewMenu.LIST_VIEW)
	view_menu.add_separator()
	view_menu.add_check_item("Show Preview Panel", ViewMenu.SHOW_PREVIEW)
	view_menu.add_check_item("Show Navigation Panel", ViewMenu.SHOW_NAVIGATION)
	view_menu.add_separator()
	view_menu.add_item("Refresh", ViewMenu.REFRESH)

	# Set defaults
	view_menu.set_item_checked(view_menu.get_item_index(ViewMenu.GRID_VIEW), true)
	view_menu.set_item_checked(view_menu.get_item_index(ViewMenu.SHOW_PREVIEW), true)
	view_menu.set_item_checked(view_menu.get_item_index(ViewMenu.SHOW_NAVIGATION), true)

	# Shortcuts
	view_menu.set_item_shortcut(view_menu.get_item_index(ViewMenu.REFRESH),
		_create_shortcut(KEY_F5))


func _setup_project_menu() -> void:
	project_menu.add_item("Rename Project...", ProjectMenu.RENAME_PROJECT)
	project_menu.add_item("Delete Project", ProjectMenu.DELETE_PROJECT)
	project_menu.add_separator()
	project_menu.add_item("Reindex All Folders", ProjectMenu.REINDEX_ALL)


func _setup_help_menu() -> void:
	help_menu.add_item("About Asset Browser", HelpMenu.ABOUT)


func _create_shortcut(key: Key, ctrl: bool = false, shift: bool = false) -> Shortcut:
	var shortcut := Shortcut.new()
	var event := InputEventKey.new()
	event.keycode = key
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	shortcut.events = [event]
	return shortcut


# Menu handlers

func _on_file_menu_pressed(id: int) -> void:
	match id:
		FileMenu.NEW_PROJECT:
			_show_new_project_dialog()
		FileMenu.OPEN_PROJECT:
			_show_open_project_dialog()
		FileMenu.ADD_FOLDER:
			_show_add_folder_dialog()
		FileMenu.SETTINGS:
			_show_settings_dialog()
		FileMenu.QUIT:
			get_tree().quit()


func _on_edit_menu_pressed(id: int) -> void:
	match id:
		EditMenu.SELECT_ALL:
			EventBus.selection_cleared.emit()  # TODO: Implement select all
		EditMenu.DESELECT_ALL:
			EventBus.selection_cleared.emit()
		EditMenu.DELETE_SELECTED:
			pass  # TODO: Implement delete selected


func _on_view_menu_pressed(id: int) -> void:
	match id:
		ViewMenu.GRID_VIEW:
			view_menu.set_item_checked(view_menu.get_item_index(ViewMenu.GRID_VIEW), true)
			view_menu.set_item_checked(view_menu.get_item_index(ViewMenu.LIST_VIEW), false)
			EventBus.view_mode_changed.emit("grid")
		ViewMenu.LIST_VIEW:
			view_menu.set_item_checked(view_menu.get_item_index(ViewMenu.GRID_VIEW), false)
			view_menu.set_item_checked(view_menu.get_item_index(ViewMenu.LIST_VIEW), true)
			EventBus.view_mode_changed.emit("list")
		ViewMenu.SHOW_PREVIEW:
			var checked := not view_menu.is_item_checked(view_menu.get_item_index(ViewMenu.SHOW_PREVIEW))
			view_menu.set_item_checked(view_menu.get_item_index(ViewMenu.SHOW_PREVIEW), checked)
			# TODO: Toggle preview panel visibility
		ViewMenu.SHOW_NAVIGATION:
			var checked := not view_menu.is_item_checked(view_menu.get_item_index(ViewMenu.SHOW_NAVIGATION))
			view_menu.set_item_checked(view_menu.get_item_index(ViewMenu.SHOW_NAVIGATION), checked)
			# TODO: Toggle navigation panel visibility
		ViewMenu.REFRESH:
			pass  # TODO: Implement refresh


func _on_project_menu_pressed(id: int) -> void:
	match id:
		ProjectMenu.RENAME_PROJECT:
			_show_rename_project_dialog()
		ProjectMenu.DELETE_PROJECT:
			_confirm_delete_project()
		ProjectMenu.REINDEX_ALL:
			_reindex_all_folders()


func _on_help_menu_pressed(id: int) -> void:
	match id:
		HelpMenu.ABOUT:
			_show_about_dialog()


# Dialog stubs (to be implemented with proper dialogs)

func _show_new_project_dialog() -> void:
	# Simple implementation for now
	var project_name := "Project %d" % (ProjectManager.get_all_projects().size() + 1)
	var project = ProjectManager.create_project(project_name)
	if project:
		ProjectManager.switch_project(project.id)


func _show_open_project_dialog() -> void:
	# Projects are switched via the header dropdown for now
	pass


func _show_add_folder_dialog() -> void:
	# Trigger the navigation panel's add folder dialog
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.title = "Select Folder to Watch"
	dialog.dir_selected.connect(func(path: String):
		ProjectManager.add_watched_folder(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	get_tree().root.add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))


func _show_settings_dialog() -> void:
	# TODO: Implement settings dialog
	print("Settings dialog not implemented yet")


func _show_rename_project_dialog() -> void:
	# TODO: Implement rename dialog
	print("Rename project dialog not implemented yet")


func _confirm_delete_project() -> void:
	if ProjectManager.current_project == null:
		return

	var projects := ProjectManager.get_all_projects()
	if projects.size() <= 1:
		# Can't delete the only project
		print("Cannot delete the only project")
		return

	# TODO: Show confirmation dialog
	var project_id: int = ProjectManager.current_project.id
	ProjectManager.delete_project(project_id)


func _reindex_all_folders() -> void:
	if ProjectManager.current_project == null:
		return

	var folders := ProjectManager.get_watched_folders()
	for folder in folders:
		var indexer = load("res://src/services/indexer.gd").new()
		indexer.index_folder(folder)
		EventBus.indexing_started.emit(folder.path)


func _show_about_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "About Asset Browser"
	dialog.dialog_text = "Asset Browser\n\nA cross-platform desktop application for browsing, organizing, and managing creative assets.\n\nBuilt with Godot 4.5"
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
