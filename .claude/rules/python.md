---
paths:
  - "**/*.py"
---

# Python (non-default conventions)

- Before writing code against an external library, verify its current API via
  Context7 MCP (`resolve-library-id` → `query-docs`). Applies to installs,
  upgrades, imports, and APIs you haven't checked recently.
- Data schemas: Pydantic `BaseModel`, not dicts/dataclasses.
- Line length 80 (not the Ruff/Black default of 88).
- New code carries >80% test coverage (pytest).
- No bare `except:` — catch specific types, fail loudly.
