---
name: pixi
description: >-
  Use when working with pixi the python package manager. Provides best practices for using pixi effectively
---

### Commands

- Install dependencies: `pixi install`
- Activate environment: `pixi shell`
- Add PyPI package: `pixi add --pypi PACKAGE_NAME`
- Add conda package: `pixi add PACKAGE_NAME` (without `--pypi`)
- always prefer pypi if possible. conda is for packages that require compiled binaries not already available on the system
- Run any command in the pixi environment: `pixi run COMMAND`
- Supports platforms: `osx-arm64`, `linux-64`
- if intializing, use `pixi init . --format pyproject` to use `pyproject.toml`

### Rules

- Only use pixi to edit project dependencies. Do not use pip or conda directly in the project environment.
