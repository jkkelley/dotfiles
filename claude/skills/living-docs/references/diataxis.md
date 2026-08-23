# The four modes, and how to choose

Diataxis mode: **explanation**.
Last reviewed: 2026-08-23.

Diataxis splits documentation by what the reader is doing, not by what the software is.
The split matters because the four kinds have incompatible obligations, and a document trying to meet two of them meets neither.

## The grid

|  | Serves study | Serves work |
| --- | --- | --- |
| **Practical** | tutorial | how-to |
| **Theoretical** | explanation | reference |

## What each one owes the reader

**Tutorial.** A beginner, no goal of their own yet, learning by doing.
It owes them a guaranteed first success.
It may not branch, may not explain alternatives, and may not assume anything.
If the reader has to make a decision, the tutorial has failed.

**How-to.** Someone competent with a goal already in mind.
It owes them the shortest correct path to that goal.
It may assume knowledge and may branch, because the reader knows which branch they are on.
An SOP is a how-to with an operational audience.

**Reference.** Someone who needs a fact.
It owes them accuracy and completeness, structured to mirror the machinery.
No narrative, no opinion, no teaching. Dry is correct here.

**Explanation.** Someone trying to understand.
It owes them context, alternatives considered, and trade-offs.
This is the only mode allowed to argue.
An ADR is explanation with a decision attached.

## Choosing when a document wants to be two

The pull is almost always the same one: a how-to that keeps stopping to explain why.

**Split it.** The how-to links to the explanation, and neither is diluted.
The reader following a procedure at 3am does not want the reasoning, and the reader trying to understand the design does not want step 7 of 12.

Two tests that settle most cases:

1. **Would a reader in a hurry skip this paragraph?** If yes and it is still worth keeping, it belongs in explanation.
2. **Does removing the narrative break the document?** If no, it was reference all along.

## What this skill enforces

`docs.sh verify` checks that a mode is declared, not that it is the right one.
Choosing correctly is a judgment call and stays with the author.
Declaring at all is mechanical, so the script owns it.
