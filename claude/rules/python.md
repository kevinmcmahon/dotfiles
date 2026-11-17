---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/uv.lock"
---

# Python Development

- **Version**: Python 3.11+ with type annotations
- **Package Management**: Use `uv` exclusively (no poetry, pip, or easy_install)
- **Project Setup**: Ensure `pyproject.toml` exists (create with `uv init` if missing)
- **Import Order**: Standard library → Third-party → Local (alphabetically)
- **Error Handling**: Use custom exceptions with specific types
- **Naming Conventions**:
  - `snake_case` for variables and functions
  - `PascalCase` for classes
- **Documentation**: Clear docstrings with parameter descriptions
- **Type Hints**: Extensive typing with TypedDict for structured data
- **Formatting**:
  - 4 spaces for indentation
  - `ruff format` for code formatting
- **Linting**:
  - `ruff check` for linting, with ruff's `I` rule sorting imports
- **Type checking**: `uvx ty check` (ty runs through uvx, not as a project dependency)
