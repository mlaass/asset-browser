## 1. Overview

### 1.1 Product Name
**Asset Browser** (working title)

### 1.2 Vision
A lightweight, cross-platform desktop application for creative professionals to browse, organize, tag, and perform light edits on creative assets across their filesystem. Unlike traditional DAMs that require importing files into a managed library, Asset Browser works with files in-place, storing metadata and organization in a local database.

### 1.3 Core Value Proposition
- Browse assets across multiple locations without copying/moving files
- Project-scoped organization (same file can be tagged differently per project)
- Quick preview and light editing without opening heavy applications
- Copy Assistant for structured export with optional format conversion

### 1.4 Technology Stack
- **Engine**: Godot 4.5 (cross-platform, themable UI, native file format support)
- **Database**: SQLite (portable, single-file, zero-config)
- **Target Platforms**: Linux, macOS, Windows

---

## 2. Information Architecture

### 2.1 Data Model

```
┌─────────────────┐       ┌─────────────────┐
│     Project     │       │  WatchedFolder  │
├─────────────────┤       ├─────────────────┤
│ id (PK)         │       │ id (PK)         │
│ name            │       │ path            │
│ created_at      │       │ project_id (FK) │
│ last_opened     │       │ recursive       │
│ settings_json   │       │ last_indexed    │
└────────┬────────┘       └─────────────────┘
         │
         │ 1:many
         ▼
┌─────────────────┐       ┌─────────────────┐
│   AssetMeta     │       │      Tag        │
├─────────────────┤       ├─────────────────┤
│ id (PK)         │       │ id (PK)         │
│ project_id (FK) │◄─────►│ project_id (FK) │
│ file_path       │ many  │ name            │
│ file_hash       │ :many │ color           │
│ is_favorite     │       │ sort_order      │
│ notes           │       └─────────────────┘
│ thumbnail_path  │
│ last_modified   │       ┌─────────────────┐
│ edits_json      │       │   AssetTag      │
└─────────────────┘       ├─────────────────┤
                          │ asset_id (FK)   │
                          │ tag_id (FK)     │
                          └─────────────────┘
```

### 2.2 Key Design Decisions

**File Identity**: Files are identified by `(project_id, file_path, file_hash)`. The hash allows detecting when a file has changed externally.

**Edit Storage**: `edits_json` stores a stack of non-destructive edits that can be applied on export. For v1, edits are destructive (save/save-as), but the schema supports future non-destructive workflows.

**Thumbnail Cache**: Stored in `~/.cache/asset-browser/thumbnails/` with hash-based filenames for deduplication.

---

## 3. User Interface

### 3.1 Layout Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  [Project: ▼ My Game Project]                    [⚙ Settings]       │
├───────────────┬─────────────────────────────────────────────────────┤
│               │ [🏠 Watched] [🏷 Tags ▼] [⭐ Favorites]  [🔍 Search] │
│  NAVIGATION   │ [View: ▦ ▤] [Sort: Name ▼] [Filter: All Types ▼]   │
│               ├─────────────────────────────────────────────────────┤
│ ★ Quick Access│                                                     │
│   📁 Sprites  │   ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐              │
│   📁 SFX      │   │      │ │      │ │      │ │      │              │
│               │   │ thumb│ │ thumb│ │ thumb│ │ thumb│              │
│ 📂 File Tree  │   │      │ │      │ │      │ │      │              │
│ ├─📁 home     │   │name  │ │name  │ │name  │ │name  │              │
│ │ └─📁 assets │   └──────┘ └──────┘ └──────┘ └──────┘              │
│ └─📁 projects │                                                     │
│               │   ASSET GRID                                        │
│ [+ Add Folder]│                                                     │
│               ├─────────────────────────────────────────────────────┤
│               │  PREVIEW / EDITOR PANEL              [⬆ Popout]     │
│  TAG PALETTE  │  ┌─────────────────────────────────┐ [Save][SaveAs] │
│               │  │                                 │                │
│  🔴 Character │  │    [Preview Content]            │                │
│  🟢 Environment│  │    Type-specific controls       │                │
│  🔵 UI        │  │                                 │                │
│  🟡 Audio     │  └─────────────────────────────────┘                │
│               │  [Tags: 🔴 Character] [⭐ Favorite] [📝 Notes]      │
│ [+ New Tag]   │                                                     │
└───────────────┴─────────────────────────────────────────────────────┘

All dividers (─┬─ ─┼─ ─┴─) are draggable for resizing.
```

### 3.2 Panel Descriptions

**Navigation Panel (Left)**
- **Quick Access**: Watched folders for current project, one-click access
- **File Tree**: Full filesystem browser starting from configured roots
- **Tag Palette**: Color-coded tags for current project, drag to apply

**Asset Browser (Main)**
- **Toolbar**: View toggle (grid/list), sort options, type filter, search
- **Asset Grid/List**: Thumbnails or list rows, multi-select, drag-and-drop
- **Context Menu**: Tag, favorite, open in editor, copy to project, reveal in file manager

**Preview/Editor Panel (Bottom, dockable)**
- **Preview Area**: Type-specific preview with basic interaction
- **Metadata Bar**: Applied tags, favorite toggle, notes field
- **Editor Controls**: Type-specific editing tools (when in edit mode)
- **Save Actions**: Save (overwrite) and Save As buttons, appear when edits made

### 3.3 View Modes

**Grid View**
- Configurable thumbnail size (small/medium/large)
- Shows: thumbnail, filename, type icon
- Hover: shows tags as colored dots

**List View**
- Columns: Icon, Name, Type, Size, Date Modified, Tags
- Sortable columns
- Inline tag display as colored pills

---

## 4. Feature Specifications

### 4.1 Project Management

| Feature | Description |
|---------|-------------|
| Create Project | New project with name, optional watched folders |
| Switch Project | Dropdown in header, recent projects listed first |
| Project Settings | Watched folders, default export path, tag palette |
| Delete Project | Removes project and all metadata (not files) |

### 4.2 File Navigation

| Feature | Description |
|---------|-------------|
| Watched Folders | Per-project list of indexed folders |
| File Tree | System file browser, can navigate anywhere |
| Add to Watched | Right-click folder → "Watch in this project" |
| Quick Access | One-click to watched folders |
| Indexing | Background scan of watched folders, generates thumbnails |

### 4.3 Asset Organization

| Feature | Description |
|---------|-------------|
| Tags | Color-coded labels, project-scoped |
| Apply Tag | Drag tag to asset, or right-click → Tag |
| Bulk Tag | Multi-select assets, apply tag to all |
| Favorites | Per-project favorite flag |
| Notes | Free-text notes per asset per project |
| Filter by Tag | Click tag in palette to filter view |
| Smart Search | Search by name, tags, type, date range |

### 4.4 Preview System

Type-specific preview capabilities:

| Type | Preview Features |
|------|------------------|
| **Images** | Pan, zoom, actual-size toggle, checkerboard background for transparency |
| **Audio** | Waveform OR spectral view (configurable), playback with scrubbing, loop toggle |
| **3D Models** | Orbit camera, zoom, view modes (textured/solid/wireframe), ground plane toggle |
| **Godot Scenes** | Tree view of nodes, basic property display |
| **Text/Code** | Syntax-highlighted read-only view |

### 4.5 Editors (v1)

#### Image Editor
- Rotate (90° CW/CCW, 180°, arbitrary)
- Flip (horizontal, vertical)
- Crop (drag selection)
- Resize (with aspect lock option)
- Canvas Resize (anchor point selection)

#### Audio Editor
- Waveform display with selection
- Cut/Delete selection
- Trim to selection
- Fade In (linear/exponential curve)
- Fade Out (linear/exponential curve)
- Normalize
- Volume adjustment (simple gain)

#### 3D Editor
- View only for v1 (no editing)
- Future: transform adjustments, material preview

### 4.6 Copy Assistant

A dialog for structured export of assets to a project directory:

```
┌─────────────────────────────────────────────────────────┐
│  Copy Assistant                                    [X]  │
├─────────────────────────────────────────────────────────┤
│  Source: 12 selected assets                             │
│                                                         │
│  Destination: [~/projects/mygame/assets    ] [Browse]   │
│                                                         │
│  Organization:                                          │
│  ○ Flat (all files in destination)                      │
│  ● By Tag (create subfolders per tag)                   │
│  ○ By Type (images/, audio/, models/)                   │
│  ○ Custom pattern: [{tag}/{type}/{name}]                │
│                                                         │
│  Conversions:                                           │
│  ☑ Images → WebP (quality: 85)                         │
│  ☐ Audio → OGG (quality: 6)                            │
│  ☐ Downscale images > 2048px                           │
│                                                         │
│  Naming:                                                │
│  ○ Keep original names                                  │
│  ● Lowercase with underscores                           │
│  ○ Custom pattern: [{tag}_{name}]                       │
│                                                         │
│  Preview:                                               │
│  └─ assets/                                             │
│     ├─ character/                                       │
│     │  ├─ player_idle.webp                             │
│     │  └─ player_run.webp                              │
│     └─ environment/                                     │
│        └─ grass_tile.webp                              │
│                                                         │
│                              [Cancel]  [Copy 12 Files]  │
└─────────────────────────────────────────────────────────┘
```

---

## 5. Plugin Architecture

To support easy addition of new asset types without scattered code changes:

### 5.1 Asset Handler Interface

```gdscript
class_name AssetHandler
extends RefCounted

# Registration
static func get_supported_extensions() -> Array[String]:
    return []

static func get_type_name() -> String:
    return "Unknown"

static func get_type_icon() -> Texture2D:
    return null

# Thumbnail generation
func generate_thumbnail(path: String, size: Vector2i) -> Image:
    return null

# Preview scene (instantiated in preview panel)
func create_preview() -> Control:
    return null

# Editor scene (instantiated in editor panel)
func create_editor() -> Control:
    return null

# For Copy Assistant
func get_conversion_options() -> Array[ConversionOption]:
    return []

func convert(source: String, dest: String, option: ConversionOption) -> Error:
    return OK
```

### 5.2 Built-in Handlers

- `ImageHandler` - png, jpg, jpeg, webp, svg, tga, bmp
- `AudioHandler` - wav, ogg, mp3
- `Model3DHandler` - glb, gltf, obj
- `GodotSceneHandler` - tscn, tres
- `TextHandler` - txt, md, json, gdshader, gd

### 5.3 Handler Registration

```gdscript
# In main.gd or autoload
func _ready():
    AssetHandlerRegistry.register(ImageHandler.new())
    AssetHandlerRegistry.register(AudioHandler.new())
    AssetHandlerRegistry.register(Model3DHandler.new())
    # etc.
```

This allows adding new types by:
1. Create new handler class extending `AssetHandler`
2. Register it at startup
3. Done - thumbnails, preview, editor all work

---

## 6. Configuration

### 6.1 Database Location

**Default**:
- Linux: `~/.local/share/asset-browser/data.db`
- macOS: `~/Library/Application Support/AssetBrowser/data.db`
- Windows: `%APPDATA%\AssetBrowser\data.db`

**Override**: Settings → Database Location

### 6.2 Cache Location

**Default**:
- Linux: `~/.cache/asset-browser/`
- macOS: `~/Library/Caches/AssetBrowser/`
- Windows: `%LOCALAPPDATA%\AssetBrowser\Cache\`

Contains:
- `thumbnails/` - Generated thumbnails by file hash
- `previews/` - Cached preview data (e.g., audio waveforms)

### 6.3 Settings Schema

```json
{
  "ui": {
    "theme": "dark",
    "thumbnail_size": "medium",
    "default_view": "grid",
    "audio_visualization": "waveform",
    "preview_panel_position": "bottom",
    "panel_sizes": {
      "navigation": 250,
      "preview": 300
    }
  },
  "indexing": {
    "recursive_default": true,
    "ignore_patterns": [".*", "node_modules", "__pycache__"],
    "max_thumbnail_size": 512
  },
  "copy_assistant": {
    "last_destination": "",
    "default_organization": "by_tag",
    "image_conversion": "webp",
    "image_quality": 85
  }
}
```

---

## 7. Implementation Phases

### Phase 1: Foundation (MVP)
- [ ] Project creation/switching
- [ ] SQLite database setup with schema
- [ ] File tree navigation
- [ ] Watched folders with basic indexing
- [ ] Grid view with thumbnails (images only)
- [ ] Basic tag system (create, apply, filter)
- [ ] Favorites
- [ ] Image preview (pan/zoom)

### Phase 2: Core Features
- [ ] List view
- [ ] Audio thumbnails (waveform)
- [ ] Audio preview with playback
- [ ] 3D model preview
- [ ] Search functionality
- [ ] Multi-select operations
- [ ] Panel resizing and persistence

### Phase 3: Editing
- [ ] Image editor (rotate, flip, crop, resize)
- [ ] Audio editor (cut, trim, fade, normalize)
- [ ] Save/Save As workflow
- [ ] Undo/Redo within editors

### Phase 4: Copy Assistant
- [ ] Basic copy with organization options
- [ ] Image format conversion (via Godot's Image class)
- [ ] Audio format conversion (via Godot's AudioStream export)
- [ ] Custom naming patterns
- [ ] Preview tree

### Phase 5: Polish
- [ ] Keyboard shortcuts
- [ ] Drag-drop from external file managers
- [ ] Drag-drop to external applications
- [ ] Spectral audio view
- [ ] Godot scene preview
- [ ] Theme customization
- [ ] Performance optimization for large folders

---

## 8. Technical Notes

### 8.1 Godot-Specific Considerations

**Thumbnail Generation**: Use `Image.load()` and `Image.resize()` for images. For audio, render waveform to Image. For 3D, use `SubViewport` with `MeshInstance3D`.

**Audio Editing**: Godot's `AudioStreamWAV` supports raw sample access. For MP3/OGG, may need to decode to WAV for editing, then re-encode on save.

**File System Access**: Use `DirAccess` and `FileAccess` classes. Note Godot 4's new resource UID system - avoid conflicts.

**Threading**: Use `Thread` or `WorkerThreadPool` for:
- Thumbnail generation
- Folder indexing
- File copying/conversion

### 8.2 Performance Targets

- Thumbnail generation: < 100ms per image
- Folder indexing: > 1000 files/second
- UI responsiveness: < 16ms frame time during scrolling
- Preview load: < 500ms for any supported file

### 8.3 Database Considerations

- Use WAL mode for better concurrent read/write
- Index on `file_path`, `project_id`, `file_hash`
- Batch thumbnail checks on startup
- Lazy-load metadata (don't query all assets on folder open)

---

## 9. Future Considerations (Not in v1)

- **Asset packs**: Bundle tagged assets as distributable packs
- **Team sync**: Shared database via cloud sync or git
- **AI tagging**: Auto-suggest tags based on content analysis
- **Asset store integration**: Browse/download from stores directly
- **Version tracking**: Track which version of an asset is in which project
- **Non-destructive editing**: Full edit stack stored in DB, apply on export
- **Custom metadata fields**: User-defined properties per asset type
- **Batch operations**: Resize all, convert all, etc.
- **Duplicate detection**: Find similar/identical assets by hash or visual similarity

