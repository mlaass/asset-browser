extends PanelContainer

## Navigation panel with quick access, file tree, and tag palette.

@onready var add_folder_button: Button = %AddFolderButton
@onready var watched_folders_list: VBoxContainer = %WatchedFoldersList
@onready var file_tree: Tree = %FileTree
@onready var add_tag_button: Button = %AddTagButton
@onready var tag_list: VBoxContainer = %TagList
@onready var add_folder_dialog: FileDialog = %AddFolderDialog

var _tree_root: TreeItem


func _ready() -> void:
	add_folder_button.pressed.connect(_on_add_folder_pressed)
	add_folder_dialog.dir_selected.connect(_on_folder_selected)
	add_tag_button.pressed.connect(_on_add_tag_pressed)
	file_tree.item_activated.connect(_on_file_tree_activated)

	EventBus.project_changed.connect(_on_project_changed)
	EventBus.watched_folder_added.connect(_on_watched_folder_added)
	EventBus.watched_folder_removed.connect(_on_watched_folder_removed)
	EventBus.tag_created.connect(_on_tag_created)
	EventBus.tag_deleted.connect(_on_tag_deleted)

	_setup_file_tree()
	_refresh_watched_folders()
	_refresh_tags()


func _setup_file_tree() -> void:
	file_tree.clear()
	_tree_root = file_tree.create_item()

	# Add root folders
	_add_tree_folder(_tree_root, OS.get_environment("HOME"), "Home")


func _add_tree_folder(parent: TreeItem, path: String, display_name: String = "") -> TreeItem:
	var item := file_tree.create_item(parent)
	item.set_text(0, display_name if not display_name.is_empty() else path.get_file())
	item.set_metadata(0, path)

	# Add placeholder child for lazy loading
	if DirAccess.dir_exists_absolute(path):
		var placeholder := file_tree.create_item(item)
		placeholder.set_text(0, "Loading...")
		placeholder.set_metadata(0, "__placeholder__")

	return item


func _load_tree_children(parent: TreeItem) -> void:
	var path: String = parent.get_metadata(0)
	if path.is_empty():
		return

	# Remove placeholder
	var child := parent.get_first_child()
	while child:
		var next := child.get_next()
		if child.get_metadata(0) == "__placeholder__":
			parent.remove_child(child)
		child = next

	# Load actual children
	var dir := DirAccess.open(path)
	if dir == null:
		return

	var folders: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			folders.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	folders.sort()
	for folder in folders:
		_add_tree_folder(parent, path.path_join(folder))


func _refresh_watched_folders() -> void:
	# Clear existing
	for child in watched_folders_list.get_children():
		child.queue_free()

	# Add watched folders
	var folders := ProjectManager.get_watched_folders()
	for folder in folders:
		_add_watched_folder_item(folder)

	if folders.is_empty():
		var label := Label.new()
		label.text = "No watched folders"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		watched_folders_list.add_child(label)


func _add_watched_folder_item(folder: WatchedFolder) -> void:
	var hbox := HBoxContainer.new()

	var button := Button.new()
	button.text = folder.path.get_file()
	button.tooltip_text = folder.path
	button.flat = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_on_watched_folder_clicked.bind(folder))
	hbox.add_child(button)

	var remove_btn := Button.new()
	remove_btn.text = "x"
	remove_btn.flat = true
	remove_btn.pressed.connect(_on_remove_folder_pressed.bind(folder.id))
	hbox.add_child(remove_btn)

	watched_folders_list.add_child(hbox)


func _refresh_tags() -> void:
	# Clear existing
	for child in tag_list.get_children():
		child.queue_free()

	# Add tags
	var tags := ProjectManager.get_tags()
	for tag in tags:
		_add_tag_item(tag)

	if tags.is_empty():
		var label := Label.new()
		label.text = "No tags"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		tag_list.add_child(label)


func _add_tag_item(tag: Tag) -> void:
	var hbox := HBoxContainer.new()

	var color_rect := ColorRect.new()
	color_rect.color = tag.get_color()
	color_rect.custom_minimum_size = Vector2(16, 16)
	hbox.add_child(color_rect)

	var button := Button.new()
	button.text = tag.name
	button.flat = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_on_tag_clicked.bind(tag))
	hbox.add_child(button)

	tag_list.add_child(hbox)


# Event handlers

func _on_add_folder_pressed() -> void:
	add_folder_dialog.popup_centered()


func _on_folder_selected(path: String) -> void:
	ProjectManager.add_watched_folder(path)


func _on_watched_folder_clicked(folder: WatchedFolder) -> void:
	EventBus.folder_selected.emit(folder.path)


func _on_remove_folder_pressed(folder_id: int) -> void:
	ProjectManager.remove_watched_folder(folder_id)


func _on_add_tag_pressed() -> void:
	# TODO: Show create tag dialog
	var tag_name := "Tag %d" % (ProjectManager.get_tags().size() + 1)
	var colors: Array[String] = ["#e74c3c", "#2ecc71", "#3498db", "#f1c40f", "#9b59b6", "#e67e22"]
	var color: String = colors[ProjectManager.get_tags().size() % colors.size()]
	ProjectManager.create_tag(tag_name, color)


func _on_tag_clicked(tag: Tag) -> void:
	EventBus.tag_filter_changed.emit([tag])


func _on_file_tree_activated() -> void:
	var selected := file_tree.get_selected()
	if selected == null:
		return

	var path: String = selected.get_metadata(0)
	if path == "__placeholder__":
		return

	# Load children if collapsed
	if selected.collapsed:
		_load_tree_children(selected)
		selected.collapsed = false
	else:
		selected.collapsed = true

	EventBus.folder_selected.emit(path)


func _on_project_changed(_project) -> void:
	_refresh_watched_folders()
	_refresh_tags()


func _on_watched_folder_added(_folder) -> void:
	_refresh_watched_folders()


func _on_watched_folder_removed(_folder_id: int) -> void:
	_refresh_watched_folders()


func _on_tag_created(_tag) -> void:
	_refresh_tags()


func _on_tag_deleted(_tag_id: int) -> void:
	_refresh_tags()
