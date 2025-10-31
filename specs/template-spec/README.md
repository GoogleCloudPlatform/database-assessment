# Template Workspace Structure

This directory serves as a template for new feature workspaces.

## Structure

```
specs/template-spec/
├── prd.md              # Product Requirements Document template
├── tasks.md            # Implementation checklist template
├── recovery.md         # Session resumability template
├── research/           # Research findings directory
│   └── plan.md         # Research plan and findings
└── tmp/                # Temporary working files
```

## Usage

When starting a new feature with `/prd "feature description"`, the Gemini agent will copy this template structure to `specs/active/[feature-slug]/` and populate it with feature-specific content.
