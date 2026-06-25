# Issue Labels

Recommended repository labels:

| Label | Purpose |
|---|---|
| `agent-friendly` | Bounded task with explicit acceptance criteria and automated validation |
| `good first issue` | Small, low-risk contribution with clear code location |
| `human-review-required` | Timing, persistence, security, licensing, or visual snapshot risk |
| `architecture-sensitive` | May change subsystem contracts or ADR-level decisions |
| `needs-design` | User behavior or UI specification is incomplete |
| `needs-fixture` | Work is blocked on a public, synthetic reproduction |
| `needs-triage` | Maintainer has not confirmed scope or priority |
| `visual-change` | Requires screenshots and visual snapshot review |
| `performance` | Requires a repeatable benchmark or profiling artifact |

An `agent-friendly` issue should state:

- exact in-scope and out-of-scope behavior;
- relevant subsystem and documentation;
- acceptance criteria;
- validation commands;
- whether project compatibility, undo/redo, or visuals are affected;
- all required fixtures using public or synthetic data.
