# PM Playbooks — Situational Responses

## Playbook: Project is slipping

**Trigger:** Sprint velocity is below target, milestone at risk, or delivery date no longer achievable.

### Immediate actions (days 1–2)
1. **Get the real number.** Talk to engineers 1:1. Ask: "If you had to bet your own money, when does this actually ship?" Group settings produce optimistic consensus. 1:1s produce truth.
2. **Quantify the slip.** X weeks behind, Y stories incomplete, Z blockers outstanding.
3. **Freeze scope.** No new work enters the backlog until you have a recovery plan.
4. **Identify the critical path.** What absolutely must ship? What can move to v1.1?

### Recovery options (pick one or combine)
| Option | Trade-off |
|--------|-----------|
| Reduce scope | Protect date, cut features |
| Extend timeline | Protect scope, slip date |
| Add resources | Rarely works mid-project (Brooks' Law) — only for well-defined, parallelizable work |
| Increase risk tolerance | Ship with known defects, mitigated by feature flags or limited rollout |

### Communication
- Brief sponsor immediately, before they hear it elsewhere
- Present options, not just problems: "We have three paths. Here's my recommendation."
- Update RAG to Amber/Red in next status report with recovery plan attached

### Brooks' Law reminder
Adding engineers to a late project makes it later — onboarding cost + communication overhead exceeds output gain until week 3–4 at earliest. Only add headcount if the work is clearly parallelizable and the new person is already context-loaded.

---

## Playbook: Scope creep battle

**Trigger:** Stakeholders requesting additions mid-project, "small" asks accumulating, team adding unscoped work.

### The conversation
Never say "no." Say "yes, and here's what it costs":
> "We can absolutely add [X]. Based on the team's estimate, that's about [Y] story points / [Z] days. To keep the current delivery date, we'd need to drop [specific feature] or push [other feature] to v1.1. Alternatively, we can extend the timeline by [N] weeks. Which would you prefer?"

Force a trade-off decision. Stakeholders who understand the cost usually reprioritize.

### When "small" asks are actually medium
Engineers notoriously underestimate integration work. A "small" UI change that touches the auth layer is not small. Before accepting any estimate of "a day or two," ask: what does it touch? what needs testing? what's the rollback?

### Scope creep from engineers
Sometimes the team gold-plates or refactors beyond the story. Set a clear Definition of Done and hold sprint reviews that compare delivered work to accepted criteria, not to an idealized version.

### Hard no (when you must)
If accepting the change would sink the project:
> "I understand this feels important. Given where we are, accepting this would put [milestone/date] at serious risk. I'd recommend we log it for v1.1 with high priority and revisit it in [date]. Does that work for you?"

Log it. Follow up. Don't let "not now" become "forgotten."

---

## Playbook: Stakeholder conflict

**Trigger:** Two or more stakeholders want conflicting things, or a stakeholder is undermining decisions.

### Types and responses

**Priority conflict** (stakeholder A wants X, stakeholder B wants Y)
- Don't pick sides. Escalate to the single accountable sponsor.
- Facilitate a structured trade-off conversation with both parties. Use the RICE score or MoSCoW to depersonalize.
- Get a written decision from the sponsor. Document it.

**Scope conflict** (stakeholder demanding more than was chartered)
- Return to the charter. "Per our signed scope, X is out of scope for this release. A change request would need to go through the sponsor."
- If the charter wasn't specific enough, fix it now — add detail, get sign-off, use it as the reference going forward.

**Undermining decisions** (stakeholder going around the PM to engineers directly)
- Address privately with the stakeholder first: "I want to make sure the team has a single point of coordination so we can protect their focus. Can all scope requests come through me?"
- If it continues, escalate to sponsor.
- Never let engineers absorb conflicting direction from multiple stakeholders. It destroys velocity and morale.

---

## Playbook: Team is blocked or underperforming

**Trigger:** Sprint goals consistently missed, team seems stuck, velocity declining, low morale visible.

### Diagnose first — don't treat before you know the cause

Ask in 1:1s (not group):
- What's the biggest thing slowing you down right now?
- Is there anything unclear about what we're trying to build?
- Are there any dependencies or decisions you're waiting on?
- Is the workload manageable?

Common root causes and responses:

| Root cause | Response |
|------------|----------|
| External dependency blocked | PM escalates immediately, finds workaround or resequences |
| Unclear requirements | PM and product owner do emergency refinement session |
| Technical debt / wrong architecture | Create spike story, protect time for it |
| Team member conflict | 1:1 with each party, facilitate resolution, escalate if needed |
| Scope too large for sprint | Replan, break stories smaller, set realistic goals |
| Burnout / morale | Protect the team from overcommitment, remove interruptions, celebrate wins |
| Skills gap | Pair programming, bring in a specialist, adjust assignment |

### The PM's role when team is underperforming
Remove blockers. Clarify direction. Protect focus (say no on behalf of the team to low-priority interrupts). Create the conditions for velocity — don't add process.

---

## Playbook: Critical dependency not delivered

**Trigger:** An external team, vendor, or system has not delivered something your project depends on.

### Day 1
1. Quantify the impact: how long before this blocks your critical path?
2. Contact the dependency owner directly. Not email — call or message.
3. Get a revised date in writing. "By EOD today" is not a date.

### If it's going to slip your project
1. Identify workarounds: can you build a stub/mock and integrate the real thing later?
2. Can you resequence work to stay productive while waiting?
3. Escalate to your sponsor — give them the option to apply pressure if needed.
4. Log it as a Red item in RAID log.

### Prevention
- Dependencies should be in the RAID log from day 1
- Get written commitments (not verbal) with dates and named owners
- Follow up every week — a dependency you're not actively managing will slip

---

## Playbook: Executive asks "how's the project going?" (without warning)

Always be ready with:
1. **Status:** Green/Amber/Red — one word
2. **Where we are:** "We're in week 6 of 12. [X] of [Y] features are complete."
3. **Biggest risk:** "The one thing I'm watching is [Z]. We're mitigating by [action]."
4. **What I need from you:** Either nothing ("all good") or one specific ask

If you don't know the answer to something, say "I don't have that number with me — I'll send it to you by EOD." Never guess in front of an executive.
