# Standard Operating Procedure: Review Workflow

This workflow begins with `/prompt review`. It is a sequential, stateful process. **Step 1: Doc Verification.** **Step 2: Quality Gate.** **Step 3: Cleanup.** A failure at any step halts the entire process. The agent must not proceed to cleanup if verification or the quality gate fails.
