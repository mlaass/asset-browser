extends Node

## Global event bus for decoupling UI components.
## All cross-component communication goes through these signals.

# Project events
signal project_changed(project)
signal project_created(project)
signal project_deleted(project_id: int)

# Navigation events
signal folder_selected(path: String)
signal watched_folder_added(watched_folder)
signal watched_folder_removed(watched_folder_id: int)

# Asset selection events
signal asset_selected(asset)
signal assets_selected(assets: Array)
signal asset_deselected(asset)
signal selection_cleared()

# Tag events
signal tag_created(tag)
signal tag_updated(tag)
signal tag_deleted(tag_id: int)
signal tag_filter_changed(tags: Array)

# Indexing events
signal indexing_started(folder_path: String)
signal indexing_progress(folder_path: String, current: int, total: int)
signal indexing_completed(folder_path: String, count: int)
signal indexing_cancelled(folder_path: String)

# Thumbnail events
signal thumbnail_ready(asset_id: int, texture: Texture2D)
signal thumbnail_generation_failed(asset_id: int, error: String)

# Asset metadata events
signal asset_favorited(asset_id: int, is_favorite: bool)
signal asset_tagged(asset_id: int, tag_id: int)
signal asset_untagged(asset_id: int, tag_id: int)
signal asset_notes_updated(asset_id: int, notes: String)

# UI state events
signal preview_requested(asset)
signal view_mode_changed(mode: String)  # "grid" or "list"
signal sort_changed(field: String, ascending: bool)
signal search_changed(query: String)
signal panel_visibility_changed(panel_name: String, visible: bool)
signal refresh_requested()
signal select_all_requested()
signal deselect_all_requested()
signal settings_changed()
