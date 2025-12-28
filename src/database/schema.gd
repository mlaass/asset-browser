extends RefCounted

## Database schema definitions and migrations.

const SCHEMA_VERSION := 1

const CREATE_TABLES := [
	# Schema version tracking
	"""
	CREATE TABLE IF NOT EXISTS schema_version (
		version INTEGER NOT NULL
	)
	""",

	# Projects table
	"""
	CREATE TABLE IF NOT EXISTS projects (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		created_at INTEGER NOT NULL,
		last_opened INTEGER NOT NULL,
		settings_json TEXT DEFAULT '{}'
	)
	""",

	# Watched folders table
	"""
	CREATE TABLE IF NOT EXISTS watched_folders (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		path TEXT NOT NULL,
		project_id INTEGER NOT NULL,
		recursive INTEGER NOT NULL DEFAULT 1,
		last_indexed INTEGER,
		FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
	)
	""",

	# Asset metadata table
	"""
	CREATE TABLE IF NOT EXISTS asset_meta (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		project_id INTEGER NOT NULL,
		file_path TEXT NOT NULL,
		file_hash TEXT,
		is_favorite INTEGER NOT NULL DEFAULT 0,
		notes TEXT,
		thumbnail_path TEXT,
		last_modified INTEGER,
		edits_json TEXT,
		FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
	)
	""",

	# Tags table
	"""
	CREATE TABLE IF NOT EXISTS tags (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		project_id INTEGER NOT NULL,
		name TEXT NOT NULL,
		color TEXT NOT NULL DEFAULT '#808080',
		sort_order INTEGER NOT NULL DEFAULT 0,
		FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
	)
	""",

	# Asset-Tag junction table
	"""
	CREATE TABLE IF NOT EXISTS asset_tags (
		asset_id INTEGER NOT NULL,
		tag_id INTEGER NOT NULL,
		PRIMARY KEY (asset_id, tag_id),
		FOREIGN KEY (asset_id) REFERENCES asset_meta(id) ON DELETE CASCADE,
		FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
	)
	""",
]

const CREATE_INDEXES := [
	"CREATE INDEX IF NOT EXISTS idx_asset_meta_project ON asset_meta(project_id)",
	"CREATE INDEX IF NOT EXISTS idx_asset_meta_path ON asset_meta(file_path)",
	"CREATE INDEX IF NOT EXISTS idx_asset_meta_hash ON asset_meta(file_hash)",
	"CREATE INDEX IF NOT EXISTS idx_watched_folders_project ON watched_folders(project_id)",
	"CREATE INDEX IF NOT EXISTS idx_tags_project ON tags(project_id)",
	"CREATE INDEX IF NOT EXISTS idx_asset_tags_asset ON asset_tags(asset_id)",
	"CREATE INDEX IF NOT EXISTS idx_asset_tags_tag ON asset_tags(tag_id)",
]

# Migration scripts keyed by target version
const MIGRATIONS := {
	# Example for future migrations:
	# 2: [
	#     "ALTER TABLE projects ADD COLUMN description TEXT",
	# ],
}
