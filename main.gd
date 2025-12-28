extends Control

## Main application entry point.

const SCREENSHOT_DIR := "res://screenshots"


func _ready() -> void:
	# Wait for autoloads to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	print("Asset Browser started")
	print("  Data path: ", AppConfig.get_data_path())
	print("  Database: ", "Connected" if Database.is_open() else "FAILED")
	print("  Project: ", ProjectManager.current_project.name if ProjectManager.current_project else "None")

	# Check for --screenshot command line argument
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--screenshot" in args:
		await _auto_screenshot()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		await _take_screenshot()


func _auto_screenshot() -> void:
	# Wait a few frames for UI to fully render
	for i in range(5):
		await get_tree().process_frame
	await _take_screenshot()
	get_tree().quit()


func _take_screenshot() -> void:
	await RenderingServer.frame_post_draw

	# Ensure screenshot directory exists
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")

	# Generate timestamped filename
	var datetime := Time.get_datetime_dict_from_system()
	var filename := "screenshot_%04d%02d%02d_%02d%02d%02d.png" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	var path := SCREENSHOT_DIR.path_join(filename)

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(path))

	if error == OK:
		print("Screenshot saved: ", path)
	else:
		print("Screenshot failed: ", error)
