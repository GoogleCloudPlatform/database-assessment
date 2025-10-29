# Project Documentation Guides

This directory is the **canonical source of truth** for all technical patterns, architectural decisions, and best practices in the **dma** project.

**Maintenance**: These guides are actively maintained by the **Expert agent** during the implementation workflow. They are not static; they evolve with the codebase.

## Core Technologies

- **Language**: `Python`
- **Framework**: `Litestar`
- **Database**: `PostgreSQL, MySQL, Oracle, SQLServer`
- **Testing**: `pytest`

---

## Guide Template (for new guides)

When creating a new guide, follow this structure:

```markdown
# [Feature or Concept Name]

**Objective**: A one-sentence description of what this document explains.

## 1. Core Concept

A brief, high-level explanation of the concept for someone unfamiliar with it.

## 2. Project-Specific Implementation

This is the most important section. Explain how this concept is implemented **in this project**.

### Pattern

Describe the design pattern used.

### Code Example

Provide a clean, commented code snippet from the actual codebase.

```Python
# [Code example here]
```
```

## 3. How to Use

Provide instructions for other developers (or agents) on how to use this feature or pattern.

## 4. Troubleshooting

List common errors or edge cases and how to resolve them.

---


## Index of Guides
- [CLI Architecture](./cli_architecture.md)
- [Collector Architecture](./collector_architecture.md)
- [Database Connection Management](./database_connection_management.md)
- [Error Handling](./error_handling.md)
- [Oracle Collection Scripts](./collection_scripts_oracle.md)
- [MySQL Collection Scripts](./collection_scripts_mysql.md)
- [PostgreSQL Collection Scripts](./collection_scripts_postgres.md)
- [SQL Server Collection Scripts](./collection_scripts_sqlserver.md)
- [Collection Masker Script](./collection_masker.md)
