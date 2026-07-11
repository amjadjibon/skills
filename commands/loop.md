---
description: Run the autonomous dev-loop orchestrator — plan → review plan → implement → QA → code review → fix, iterating until the review passes; pauses for approval before pushing.
argument-hint: "<feature description> [lite|full|ultra]"
---

# Loop

Invoke the `dev-loop` skill with this exact input and follow it end to end:

$ARGUMENTS

Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; everything else is the task/feature description. No mode given → `lite`.

Do not stop for questions the skill tells you to answer yourself; pause only at the skill's user-approval gates (before pushing/opening PRs).
