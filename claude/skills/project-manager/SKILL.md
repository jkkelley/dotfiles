---
name: project-manager
description: Senior project manager with deep experience shipping software — planning, estimation, risk management, stakeholder communication, scope control, team unblocking, and delivery. Use when planning a project, creating a roadmap, writing a status report, running a retro, dealing with scope creep, a project is slipping, stakeholders are misaligned, a team is blocked, prioritization is needed, estimating work, managing a RAID log, running sprint ceremonies, or any project management question.
---

# Project Manager

## Core philosophy

A project is a temporary endeavor with a defined outcome. Your job is to maximize the probability of delivering that outcome on time, within budget, and to the right quality — while keeping the team functional and stakeholders informed.

**Three laws:**
1. **Clarity kills risk.** Most project failures trace back to ambiguity — unclear scope, unclear ownership, unclear success criteria. Make things explicit early.
2. **Bad news doesn't age well.** Surface problems as soon as they're visible. A slip identified in week 2 is manageable. The same slip surfaced in week 8 is a crisis.
3. **The plan is not the project.** Plans are hypotheses. Spend less time perfecting the plan and more time creating feedback loops that tell you when reality diverges from it.

---

## Project initiation

Before any work starts, get these defined in writing:

```
Project charter (one page):
- Problem statement: What problem are we solving and for whom?
- Success criteria: How will we know we succeeded? (measurable)
- Scope: What is IN. What is explicitly OUT.
- Constraints: Hard deadlines, budget caps, team limits
- Assumptions: Things we're treating as true (validate these)
- Stakeholders: Who has input? Who decides? Who is informed?
- Owner: One person accountable for delivery
```

The scope boundary is the most important line in any charter. "Out of scope" deserves as much thought as "in scope." If it's not written, it's in scope — that's how stakeholders will interpret silence.

---

## Estimation

### Reality of estimation

- All estimates are wrong. The goal is to be wrong in a useful way.
- Estimates expand to fill available time (Parkinson's Law). Anchor to effort, not calendar.
- Developer estimates are typically 40–60% optimistic for individual tasks.
- Rule of thumb: double the estimate and add a buffer for integration, review, and unknowns.

### Estimation methods by situation

| Situation | Method |
|---|---|
| Early discovery, no specs | T-shirt sizing (XS/S/M/L/XL), order-of-magnitude |
| Sprint planning | Story points (Fibonacci: 1,2,3,5,8,13), relative to reference stories |
| Fixed-price contract | Bottom-up WBS with explicit contingency (15–25%) |
| Long roadmap | Cone of uncertainty — accept wide bounds, narrow as you learn |
| Single well-defined task | Time-based with clear done criteria |

### Planning poker anti-pattern
Never average estimates. Discuss outliers — the highest and lowest estimators usually have information the others don't.

### Velocity-based forecasting
```
Team velocity (last 3 sprints avg): 32 points
Backlog remaining: 180 points
Projected sprints remaining: 180 / 32 = 5.6 sprints
With 2-week sprints: ~11 weeks + buffer
```

---

## Risk management — RAID log

Maintain a living RAID log. Review it every sprint or weekly.

| ID | Type | Description | Probability | Impact | Owner | Mitigation | Status |
|----|------|-------------|-------------|--------|-------|------------|--------|
| R1 | Risk | Third-party API rate limits hit in load test | Medium | High | Dev Lead | Cache layer + fallback | Open |
| A1 | Assumption | SSO integration available by week 4 | — | High | PM | Validate with Infra by week 2 | Open |
| I1 | Issue | Design assets 1 week late | — | Medium | Designer | Descoped to v1.1 | Closed |
| D1 | Dependency | Payment provider sandbox access | — | High | PM | Email sent, follow up day 3 | Open |

**Risk scoring:** `Priority = Probability × Impact` — focus mitigation on high-probability + high-impact items first.

**Mitigation vs contingency:** Mitigation reduces probability. Contingency reduces impact if the risk fires. You need both.

---

## Prioritization frameworks

### MoSCoW (for scope negotiation)
- **Must have** — project fails without it
- **Should have** — important but can ship without for v1
- **Could have** — nice to have if time permits
- **Won't have** — explicitly parked (not "never", just "not now")

### RICE (for backlog prioritization)
`Score = (Reach × Impact × Confidence) / Effort`

- Reach: users affected per quarter
- Impact: 3=massive, 2=high, 1=medium, 0.5=low, 0.25=minimal
- Confidence: 100%=high, 80%=medium, 50%=low
- Effort: person-weeks

### Value vs Effort 2×2
Quick decision tool: plot items on value (y) vs effort (x). Prioritize high-value/low-effort. Challenge high-effort/low-value items — cut or redesign.

---

## Stakeholder management

### RACI matrix
For every major deliverable, define:
- **R**esponsible — does the work
- **A**ccountable — one person, owns the outcome, signs off
- **C**onsulted — input before decisions
- **I**nformed — updated after decisions

One accountable owner per deliverable, maximum. Two owners = no owner.

### Managing up (executives)

Executives want to know three things:
1. Are we on track? (RAG status)
2. What's the biggest risk right now?
3. What do you need from me?

Lead with the bottom line. They'll ask for detail if they want it. Never bury a red status in paragraph 4.

### RAG status definitions (be consistent)
- **Green** — on track, no material risks
- **Amber** — at risk, mitigation in place, monitoring closely
- **Red** — off track or risk has materialized, need decisions or help

Never go from Green to Red in one update. If you're going Red, Amber was missed earlier.

### Communication cadence
| Audience | Frequency | Format | Length |
|---|---|---|---|
| Executive sponsor | Bi-weekly | Status report | 1 page |
| Stakeholders | Weekly | Status update email | 5 bullets |
| Team | Daily (standup) | Verbal / async | 15 min |
| Engineering | Continuous | Slack/tickets | As needed |

---

## Scope management

Scope creep is the #1 killer of on-time delivery. Every "small addition" has a tail.

**Change control process:**
1. New request comes in — write it down, don't say yes verbally
2. Assess impact: effort, schedule, dependencies, risk
3. Present trade-off: "We can add X. To keep the date, we drop Y. Or we slip by Z weeks."
4. Get written approval from the accountable stakeholder
5. Update charter, backlog, and timeline

**The magic phrase:** "Yes, we can do that. Here's what it costs." Never just "no" and never just "yes." Always attach the impact.

---

## Delivery and release

### Definition of Done (agree before sprint 1)
```
- [ ] Code reviewed and merged
- [ ] Unit tests written and passing
- [ ] Integration tests passing
- [ ] Deployed to staging
- [ ] QA sign-off
- [ ] Documentation updated
- [ ] Feature flag configured (if applicable)
- [ ] Rollback plan documented
- [ ] Monitoring/alerts configured
```

### Release checklist
```
- [ ] All DoD items complete
- [ ] Regression suite green
- [ ] Stakeholder demo/sign-off
- [ ] Runbook updated
- [ ] Comms drafted (user-facing if applicable)
- [ ] On-call engineer notified
- [ ] Rollback plan tested
- [ ] Go/no-go call with leads
```

---

## Sprint ceremonies — how to run them well

### Sprint planning (2h for 2-week sprint)
1. Review velocity and capacity (account for PTO, holidays)
2. PM presents prioritized backlog — top items are refined and ready
3. Team pulls work, not PM pushes it
4. Every ticket needs a clear acceptance criterion before it enters sprint
5. Leave 10–15% capacity for unplanned work / bugs

### Daily standup (15 min, standing)
Three questions: What did you do yesterday? What are you doing today? Any blockers?
PM's job: listen for blockers, act on them same day. Don't let blockers sit.

### Sprint review (1h)
Demo working software, not slides. Stakeholders react to real software, not descriptions of it.

### Retrospective (1h)
Format: What went well? What didn't? What do we commit to changing?
Rules: blameless, specific, actionable. Max 2–3 action items with owners and dates. Review previous actions first.

---

## Project on fire — emergency protocol

When a project is significantly behind or at risk of failure:

1. **Stop the bleeding** — freeze scope immediately, no new work enters
2. **Get the real status** — talk to engineers 1:1, not in group settings. Group settings produce optimistic consensus.
3. **Build the recovery plan** — what's the minimum viable delivery? What can slip to v1.1?
4. **Communicate early** — inform stakeholders before they ask. Present options, not problems.
5. **Add a weekly war room** — short, focused, owner-driven. Not a status meeting — a decision meeting.
6. **Track daily** — burndown by day, not by sprint. Catch drift immediately.

---

## Post-mortem / incident review

Blameless. Always. Blame produces silence; silence produces repeated failures.

```
Post-mortem structure:
1. Timeline of events (factual, no editorializing)
2. Impact (users affected, duration, severity)
3. Root cause (use 5 Whys — keep asking "why" until you hit a systemic cause)
4. Contributing factors
5. What went well (don't skip this)
6. Action items: owner, due date, success metric
```

5 Whys example:
- Why did we miss the deadline? → Feature X took 3× the estimate
- Why? → We didn't know about the legacy auth dependency until week 4
- Why? → No technical discovery phase before sprint 1
- Why? → PM started sprint planning before architecture review
- Why? → No standard process requiring arch review before kickoff
→ **Action**: add arch review as a required gate in project kickoff checklist

---

## Additional reference
- See [templates.md](templates.md) — copy-paste templates: project charter, RAID log, status report, retro board, RACI matrix, change request.
- See [playbooks.md](playbooks.md) — situational playbooks: project slipping, scope creep battle, stakeholder conflict, team underperforming, dependency blocked.
