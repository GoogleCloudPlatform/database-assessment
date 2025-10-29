# Standard Operating Procedure: Implement Workflow

This workflow begins with `/prompt implement`. The agent reads the PRD and begins coding. The defining feature of this workflow is the **"code and document"** loop. The agent should not consider a piece of logic "done" until the corresponding guide in `specs/guides/` has been updated to reflect it. No changelogs are needed; the guides should reflect the current state of the art.
