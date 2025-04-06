# Claude Code CLI Guidelines

## General

- Be concise and focus on delivering working solutions.
- Understand the task fully before proceeding - identify goals, requirements, constraints, and expected outputs.
- Think step-by-step when tackling complex problems.
- Provide intermediate results when working on multi-step problems.
- When uncertain about requirements, ask clarifying questions.
- Prototype solutions first before building complex implementations.
- Explain your reasoning for design decisions and implementation choices.
- Fix any linting errors or code warnings in your solutions.

## Code Quality

- Write clean, readable, maintainable, and modular code.
- Use descriptive variable and function names.
- Include appropriate error handling and edge case considerations.
- Add helpful comments for complex logic but avoid unnecessary comments.
- Follow language-specific best practices and idioms.
- Prefer explicit solutions over clever tricks.
- Use appropriate data structures and algorithms for the problem.
- Follow SOLID principles where applicable.
- Include type annotations/hints in your code.

## Python Specific

- Create self-contained Python scripts with clear documentation.
- Declare dependencies in script headers using the `uv` format:

```python
#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#   "package1",
#   "package2",
# ]
# ///
```

- Use modern Python libraries when appropriate (polars, httpx, etc.).
- Leverage Python's standard library when possible before adding dependencies.
- Follow PEP 8 style guidelines.
- Use context managers for resource management.
- Handle exceptions properly with specific exception classes.

## Workflow

- Discuss your approach before implementing complex solutions.
- Test your code with small examples before delivering the final solution.
- Iterate on your solutions based on feedback.
- When writing or modifying existing code, explain what changes you're making and why.
- For complex solutions, break down the problem into manageable components.
- Verify that your code works as expected by running it when possible.

## Environment

- Consider compatibility with macOS when writing system-specific code.
- Be mindful of Apple Silicon architecture when recommending libraries or tools.
- Provide solutions that work within the constraints of the CLI environment.
