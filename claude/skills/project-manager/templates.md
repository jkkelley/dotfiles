# PM Templates

## Project Charter

```markdown
# Project Charter: [Project Name]

**Date:** YYYY-MM-DD  
**Owner:** [Name]  
**Sponsor:** [Name]  
**Target delivery:** [Date or Quarter]

## Problem statement
[1–2 sentences: what problem, for whom, why now]

## Success criteria
- [ ] [Measurable outcome 1]
- [ ] [Measurable outcome 2]
- [ ] [Measurable outcome 3]

## Scope
**In scope:**
- [Item 1]
- [Item 2]

**Out of scope:**
- [Item 1]
- [Item 2]

## Constraints
- Budget: $X
- Hard deadline: [Date + reason]
- Team: [Names / headcount]

## Assumptions
- [Assumption 1 — validate by: date/person]
- [Assumption 2 — validate by: date/person]

## Stakeholders
| Name | Role | RACI |
|------|------|------|
| | Sponsor | A |
| | Engineering Lead | R |
| | Product | C |
| | Legal/Compliance | C |
| | Business stakeholder | I |

## Risks (top 3 at kickoff)
1. [Risk] — Mitigation: [action]
2. [Risk] — Mitigation: [action]
3. [Risk] — Mitigation: [action]

## Sign-off
- [ ] Sponsor approved
- [ ] Engineering Lead approved
- [ ] PM approved
```

---

## Weekly Status Report

```markdown
# [Project Name] — Status Update [YYYY-MM-DD]

**Overall status:** 🟢 Green / 🟡 Amber / 🔴 Red

## Summary
[2–3 sentences: where we are, what's notable this week]

## Progress this week
- [Completed item 1]
- [Completed item 2]

## Planned next week
- [Item 1 — owner]
- [Item 2 — owner]

## Risks / Issues
| | Item | Owner | Action |
|-|------|-------|--------|
| 🔴 | [Issue] | [Name] | [Action by date] |
| 🟡 | [Risk] | [Name] | [Monitoring] |

## Decisions needed
- [Decision 1 — needed by: date — from: person]

## Metrics
- Sprint velocity: X pts (target: Y)
- Scope: X stories complete / Y total
- Budget: $X spent / $Y total (Z% consumed, Z% timeline elapsed)
```

---

## RAID Log

```markdown
# RAID Log — [Project Name]

Last updated: YYYY-MM-DD

## Risks
| ID | Description | P | I | Score | Owner | Mitigation | Due | Status |
|----|-------------|---|---|-------|-------|------------|-----|--------|
| R1 | | H/M/L | H/M/L | | | | | Open |

## Assumptions
| ID | Assumption | Owner | Validate by | Status |
|----|------------|-------|-------------|--------|
| A1 | | | | Open |

## Issues (risks that fired)
| ID | Description | Owner | Resolution | Due | Status |
|----|-------------|-------|------------|-----|--------|
| I1 | | | | | Open |

## Dependencies
| ID | Dependency | On team/person | Owner | Need by | Status |
|----|------------|----------------|-------|---------|--------|
| D1 | | | | | Pending |
```

---

## RACI Matrix

```markdown
# RACI Matrix — [Project Name]

R = Responsible (does the work)
A = Accountable (one person, owns outcome)
C = Consulted (input before decision)
I = Informed (notified after decision)

| Deliverable | PM | Eng Lead | Design | QA | Sponsor | Legal |
|-------------|----|---------:|-------:|---:|--------:|------:|
| Project charter | A/R | C | C | I | A | C |
| Technical design | I | A/R | C | C | I | I |
| UI design | C | I | A/R | C | I | I |
| Test plan | C | C | I | A/R | I | I |
| Go/no-go decision | R | C | I | C | A | C |
| Release comms | A/R | C | C | I | I | C |
```

---

## Change Request

```markdown
# Change Request — [CR-XXX]

**Date:** YYYY-MM-DD  
**Requested by:** [Name]  
**Project:** [Project Name]

## Request
[Clear description of what is being requested]

## Justification
[Why is this needed? What's the business case?]

## Impact assessment
| Area | Impact |
|------|--------|
| Scope | [Added/removed work: X story points / X days] |
| Schedule | [+/- X days / No impact] |
| Budget | [+/- $X / No impact] |
| Risk | [New risk introduced, or none] |
| Dependencies | [Any new dependencies created] |

## Options
1. **Accept as-is** — [impact]
2. **Accept with trade-off** — drop [Y] to accommodate [X], keep date
3. **Defer to v1.1** — no impact to current delivery
4. **Reject** — [reason]

## Recommendation
[PM recommendation with rationale]

## Decision
- [ ] Approved — option ___
- [ ] Rejected
- [ ] Deferred

**Approved by:** [Name] **Date:** [Date]
```

---

## Retrospective Board

```markdown
# Sprint [N] Retrospective — [Date]

## What went well 🟢
- 
- 
- 

## What didn't go well 🔴
- 
- 
- 

## What puzzled us / questions 🟡
- 
- 

## Action items
| # | Action | Owner | Due | Done? |
|---|--------|-------|-----|-------|
| 1 | | | | [ ] |
| 2 | | | | [ ] |
| 3 | | | | [ ] |

## Previous actions review
| Action | Owner | Status |
|--------|-------|--------|
| [from last retro] | | Done / Dropped / Carry |
```

---

## Kickoff Meeting Agenda

```markdown
# Project Kickoff — [Project Name]
**Date/Time:** [Date] [Time]  
**Attendees:** [List]

## Agenda (60 min)

1. **Why we're here** (5 min) — sponsor sets context and business case
2. **Scope walk-through** (15 min) — PM walks the charter, in/out scope
3. **Success criteria** (10 min) — align on what "done" looks like
4. **Roles and responsibilities** (10 min) — RACI walk-through
5. **Timeline and milestones** (10 min) — high-level roadmap
6. **Risks and assumptions** (5 min) — top 3, ask team to add
7. **Ways of working** (5 min) — ceremonies, tools, comms channels
8. **Q&A and next steps** (10 min)

## Pre-reads (send 48h before)
- [ ] Project charter
- [ ] High-level roadmap
- [ ] RACI matrix
```
