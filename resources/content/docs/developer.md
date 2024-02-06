---
title: Developer Documentation
description: Usage information for DMA Developers.
---

Developer guidelines and utilities for working with Database Migration Assessment

## Installation

The included `Makefile` will automatically configure a working development environment for most environments.

```bash
make install
```

This will install and configure:

* `pdm` Internal Package Manager.  The development environment is installed to `.venv` in the root of the project.
* `nodeenv` Integrated node build to integrate with the virtual environment.

:::note
If you do not have PDM available on the current path, `make install` will try to install it using the public install script.

If for some reason you need to install PDM some other way, please manually install PDM before running `make install` if you would like to customize this installation.   The install process will skip installation if found.

:::
