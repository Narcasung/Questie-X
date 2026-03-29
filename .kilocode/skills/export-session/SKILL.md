---
name: export-session
description: Export session artifacts (markdown files, notes, research) to a documentation folder for review or archival. Use this when you need to save session work, create research documentation, or export artifacts from a development session.
---

# Export Session Skill

Exports session artifacts to a documentation/research folder for later review.

## Instructions

1. **When to use**: After completing a significant coding session, bug fix, or feature implementation
2. **Required parameters**:
   - `project`: Project name (e.g., "Questie-X")
   - `session`: Descriptive session name (e.g., "Keybind-Fix", "1.5.2-Release")
   - `source`: Source directory containing artifacts (typically the brain/artifact directory)
   - `target`: Target base directory for exports

## Usage

Run the export script from `.kilocode/skills/export-session/scripts/export_session.py`:

```bash
python .kilocode/skills/export-session/scripts/export_session.py <project> "<session>" --source <source_dir> --target <target_dir> [--extensions .md .lua] [--clean]
```

### Examples

Export markdown files from a session:
```bash
python .kilocode/skills/export-session/scripts/export_session.py Questie-X "Keybind-Fix" --source C:\Brain\session123 --target C:\Research --extensions .md
```

Export all files from current directory:
```bash
python .kilocode/skills/export-session/scripts/export_session.py MyProject "BugFix-123" --source . --target ~/research
```

## Output

Creates a folder at: `<target>/<project>/<session>/` containing:
- All copied artifacts from source
- A summary markdown file with session details

## Notes

- Use `--clean` to overwrite existing sessions
- Use `--extensions` to filter file types (default: all files)
- Use `--no-summary` to skip summary file creation
