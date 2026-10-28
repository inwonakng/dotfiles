---
name: pixi
description: Use when a project requires using pixi the python package manager. 
---

### Commands

- Install dependencies: `pixi install`
- Activate environment: `pixi shell`
- Add PyPI package: `pixi add --pypi PACKAGE_NAME`
- Add conda package: `pixi add PACKAGE_NAME` (without `--pypi`)
- Run any command in the pixi environment: `pixi run COMMAND`
- Python version: 3.11+
- Supports platforms: `osx-arm64`, `linux-64`

### Rules

- Only use pixi to edit project dependencies. Do not use pip or conda directly in the project environment.
