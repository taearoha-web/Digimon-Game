# PROJECT STATUS — Digimon Adventure RPG Prototype

> **Continuity rule:** any agent/session continuing this project must read
> `PROJECT_STATUS.md`, `DEVELOPMENT_PLAN.md`, `TODO.md` and `CHANGELOG.md`
> first, inspect the repository, and continue from the current implementation.
> Never restart the project or delete working features to rewrite them.

## Current phase

**Phase 1 — Project foundation and architecture (in progress)**

## Completed systems

- Repository initialised, folder structure created
- Continuity documents created

## Incomplete systems

Everything else (see `DEVELOPMENT_PLAN.md`).

## Current known bugs

- None recorded yet.

## Next development task

Create `project.godot`, autoload managers and core data classes.

## Important architecture decisions

- **Engine:** Godot 4.x, GDScript. Target 4.3+ (validated on 4.3 and 4.6 headless).
- **Renderer:** `gl_compatibility` (GLES3) on every platform — widest Android
  device support, cheapest for a low-poly stylised game.
- **Landscape only**, base viewport 1280x720, stretch `canvas_items` + `expand`.

## File locations

See `README.md` → *Project architecture*.

## Test results

- None yet.
