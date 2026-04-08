---
paths:
  - "**/*.py"
---

# Python Development Guidelines

## Context7 MCP — Use Before Writing Library Code

MANDATORY: Before writing Python code that uses external libraries, use Context7 MCP server to fetch current documentation.

1. Call `resolve-library-id` with the library name and your task description
2. Call `query-docs` with the resolved library ID and a specific question
3. Use the returned documentation to write correct, up-to-date code

Use when: installing/upgrading packages, writing imports, configuring libraries, debugging dependency issues, using library APIs you haven't verified recently.

## Coding Style

- snake_case for functions and variables
- Type hints in all function signatures
- 4 spaces indentation, 80 char line length
- Pydantic BaseModel for all data schemas
- Descriptive function and variable names
- All functions have 1-line docstring describing purpose

## Error Handling

- Specific exception types (no bare `except:`)
- Log errors with context (correlation IDs, function names)
- Return meaningful error messages to users

## Testing

- pytest with fixtures
- Test happy path and error scenarios
- >80% coverage on new code
- File naming: `test_*.py` or `*_test.py`

## Documentation

- Google-style docstrings: document Args, Returns, Raises
- Use type hints instead of documenting types in docstrings
