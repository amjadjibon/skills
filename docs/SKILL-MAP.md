# Skill Map

How the 29 skills and 4 agents fit together. `dev-loop` is the autonomous spine — everything
else is either a stage it calls, an overlay that governs how work is done, or a standalone
entry point that feeds it.

## The autonomous loop

```mermaid
flowchart TD
    task([Task])

    subgraph fog["Fog — only when the task is too undecided to phase"]
        wayfinder[dev-wayfinder<br/>MAP.md]
    end

    subgraph shape["Shape — optional, skipped when obvious"]
        brainstorm[brainstorming]
        research[dev-research]
        design[dev-design]
        apidesign[dev-api-design]
        openapi[openapi-spec]
        uidesign[dev-ui-design]
        proto[prototype]
        mermaid[mermaid-diagram]
    end

    subgraph plan["Plan"]
        create[dev-create-plan]
        planreview[dev-review-plan]
    end

    subgraph build["Build — per phase in full/ultra"]
        impl[dev-implement-plan]
        tdd[dev-tdd]
        debug[dev-debug]
        qa[dev-qa]
        e2e[dev-e2e-testing]
        smoke[dev-smoke-testing]
    end

    subgraph gate["Gate"]
        review[dev-code-review]
        ponyreview[dev-ponytail-review]
        perf[dev-perf]
        refactor[dev-refactor]
    end

    subgraph close["Close"]
        approval{{User approval}}
        cleanup[dev-clean-up]
        release[dev-release]
        actions[github-actions]
    end

    task -->|too foggy to plan| wayfinder
    wayfinder -->|Research ticket| research
    wayfinder -->|Prototype ticket| proto
    wayfinder -->|Grilling ticket| brainstorm
    wayfinder -->|fog cleared| design

    task --> brainstorm --> research --> design --> create
    task --> research
    task --> create
    design --> apidesign --> openapi
    design --> uidesign --> proto
    design -.-> mermaid

    create --> planreview --> impl
    impl --> tdd
    impl --> debug
    impl --> qa --> e2e
    qa --> smoke --> review
    qa --> review

    review -->|Approve / Low only| approval
    review -->|Medium| impl
    review -->|High| fixers[[dev-fixer agents<br/>parallel worktrees]] --> review
    review -->|Critical| blocked([Blocked — human])
    review -.-> ponyreview
    review -.->|perf finding| perf
    review -.->|structure only| refactor

    approval --> cleanup --> release --> actions

    classDef spine fill:#1d4ed8,stroke:#1e3a8a,color:#fff
    classDef stop fill:#b91c1c,stroke:#7f1d1d,color:#fff
    classDef agent fill:#047857,stroke:#064e3b,color:#fff
    class create,impl,qa,review spine
    class blocked stop
    class fixers agent
```

## Overlays — always on, never a stage

`dev-ponytail` (build the smallest thing) and `dev-caveman` (compress the talking) govern *how*
every stage above runs. They produce no artifact and appear nowhere in the flow.

```mermaid
flowchart LR
    pony[dev-ponytail<br/>how code gets written] --> all[Every build stage]
    cave[dev-caveman<br/>how output gets written] --> all
    all --> audit[dev-ponytail-audit<br/>repo-wide report]
    all --> debt[dev-ponytail-debt<br/>TODO ledger]
    git[git-safe<br/>commit + destructive-op rules] --> all

    classDef overlay fill:#7c3aed,stroke:#4c1d95,color:#fff
    class pony,cave,git overlay
```

## Agents

| Agent | Spawned by | Owns |
|-------|-----------|------|
| `dev-researcher` | dev-create-plan, dev-implement-plan, dev-loop | one scoped research question → `.spec/<feature>/research/<topic>.md` |
| `dev-implementer` | dev-implement-plan, dev-loop | one PLAN.md phase in its own worktree |
| `dev-fixer` | dev-loop after a failing review | one group of REVIEW.md findings |
| `dev-tester` | dev-qa (ultra), dev-loop | one module's coverage gaps |

Every spawn instruction says "when available, else general-purpose" — the skills work with the
plugin's agents absent.

## Artifacts

All under `.spec/<feature-name>/`, each written by exactly one skill and read by the next:

```mermaid
flowchart LR
    M[MAP.md] --> R[RESEARCH.md] --> D[DESIGN.md] --> P[PLAN.md]
    P --> PR[PLAN-REVIEW.md] --> P
    P --> Q[QA.md]
    P --> V[REVIEW.md] --> L[LOOP.md]
    Q --> L
    H[prototype.html] --> P
    D --> H
```

`LOOP.md` is the resume point: an interrupted loop reconstructs its position from that file
alone.
