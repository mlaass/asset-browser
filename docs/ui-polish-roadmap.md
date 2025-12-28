# Future: UI Polish to Match Godot Editor Style

Reference: Godot editor using same `godot-minimal-theme`

## Prerequisites (implement first)

1. **Settings System** - need UI for customization before polish
   - Settings dialog accessible via File > Settings
   - Persist settings to config file
   - Required settings: accent color, font size, icon theme

## Visual Differences to Address

Comparing Asset Browser to Godot editor (same theme):

### 1. Section Headers
- **Godot**: Distinct header bars (e.g., "FileSystem" with background, icon, menu dots)
- **Ours**: Plain labels
- **Fix**: Create styled section header component with icon + title + optional menu

### 2. Icons Throughout
- **Godot**: Folder icons, file type icons, action icons in buttons
- **Ours**: Text-only buttons, no file type indicators
- **Fix**: Integrate FontAwesome icons, add file type icons to tree/grid

### 3. Tree View Styling
- **Godot**: Proper indentation, expand arrows, icons for each item type
- **Ours**: Basic Tree with minimal styling
- **Fix**: Custom tree item rendering with icons

### 4. Filter/Search Boxes
- **Godot**: Search icon inside input, filter icon buttons
- **Ours**: Plain LineEdit with placeholder
- **Fix**: Add icons to search inputs

### 5. Accent Colors
- **Godot**: Blue selection highlights, colored icons
- **Ours**: Default theme colors
- **Fix**: Settings for accent color, apply via theme overrides

### 6. Font Hierarchy
- **Godot**: Different sizes for headers vs content
- **Ours**: Uniform font sizes
- **Fix**: Font size settings, apply to section headers

### 7. Panel Separators
- **Godot**: Subtle, thin separators
- **Ours**: Default HSeparator/VSeparator
- **Fix**: Theme override for separator styling

## Implementation Order

1. Build Settings dialog with basic preferences
2. Add accent color picker → apply to theme
3. Add font size settings → apply to labels
4. Create reusable SectionHeader component
5. Add icons to navigation tree (folders, files)
6. Add icons to toolbar buttons
7. Style search/filter inputs with icons
8. Polish panel separators and spacing

## Files to Create/Modify

| File | Purpose |
|------|---------|
| `src/ui/dialogs/settings_dialog.tscn/.gd` | Settings UI |
| `src/autoloads/settings.gd` | Persist/load settings |
| `src/ui/components/section_header.tscn/.gd` | Reusable styled header |
| Theme overrides in various `.tscn` files | Apply accent colors, fonts |

## Settings Schema (draft)

```gdscript
var settings = {
    "ui/accent_color": Color("#3498db"),
    "ui/font_size": 14,
    "ui/icon_theme": "fontawesome",  # or "simple"
    "ui/show_file_extensions": true,
    "thumbnails/size": 128,
    "thumbnails/quality": 0.8
}
```
