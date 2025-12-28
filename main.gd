extends Control

## Main application entry point.


func _ready() -> void:
  # Wait for autoloads to initialize
  await get_tree().process_frame
  await get_tree().process_frame

  print("Asset Browser started")
  print("  Data path: ", AppConfig.get_data_path())
  print("  Database: ", "Connected" if Database.is_open() else "FAILED")
  print("  Project: ", ProjectManager.current_project.name if ProjectManager.current_project else "None")
