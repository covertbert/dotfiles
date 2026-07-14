---
name: considered-writing
description: Use when the user asks to draft, rewrite, edit, polish, structure, summarise, or turn material into a document or message. Includes briefs, proposals, strategy notes, decisions, feedback, emails, and Slack updates. Do not use for ordinary questions, explanations, research, brainstorming, or code. `notion:` or an explicit request to save, create, or update something in Notion means publish there. Otherwise respond in chat.
---

# Considered Writing

## Activation and output

Use for producing or revising a written artifact, not merely because a response may be long.

- `write:` explicitly activates considered writing in chat.
- `notion:` explicitly activates considered writing and saves it to Notion.
- Without either prefix, infer intent from the request.
- Ordinary questions should receive normal chat answers.

Only write to Notion when explicitly requested. Unless another parent is given, use Scratchpad:

`f16fb79f-5960-4b77-987e-151727dbed1b`

After writing, return page title and URL. Do not repeat full content in chat unless requested.

## Purpose

Write in Bertie's natural style across different document types: strategy notes, internal comms, technical documents, summaries, appraisals, planning documents, incident notes, Slack updates, and longer-form analysis.

The goal is not to make everything sound academic. The goal is to make writing clear, grounded, measured, and useful.

## Core style

Write with:

- Clear structure
- Direct phrasing
- Evidence-aware claims
- Practical judgement
- Minimal fluff
- Calm confidence
- Sensible caveats
- Plain English
- Bias towards usefulness over polish

Writing should feel like a capable engineering leader thinking clearly in public.

## Default tone

Use a tone that is:

- Professional
- Analytical
- Matter-of-fact
- Slightly sceptical where appropriate
- Pragmatic
- Concise
- Low-drama

Avoid:

- Hype
- Marketing language
- Forced enthusiasm
- Overly polished corporate phrasing
- Vague positivity
- AI assistant phrasing
- Dramatic or emotional framing

## Claims

Prefer claims that are specific and appropriately qualified.

Use:

- "This suggests..."
- "This is likely to..."
- "The risk is..."
- "The main issue is..."
- "This matters because..."
- "The practical impact is..."
- "It is worth separating..."
- "This does not necessarily mean..."
- "The evidence points to..."

Avoid:

- "This proves..."
- "This is transformational..."
- "This unlocks huge value..."
- "Clearly, everyone should..."
- "It goes without saying..."

Do not overstate certainty. If evidence is partial, say so.

## Structure

Use structure to make the document easy to scan.

Prefer:

- Short headings
- Short paragraphs
- Bullets where they genuinely improve readability
- Clear opening that states the point
- Clear ending that states the implication, decision, or next step

Do not over-format. Avoid unnecessary tables, excessive bolding, and ornamental structure.

## Sentence style

Use plain, controlled sentences.

Preferred patterns:

- "The issue is not X. It is Y."
- "This is useful, but only if X."
- "The concern is less about X and more about Y."
- "There are two separate points here."
- "The trade-off is..."
- "This is probably acceptable in the short term, but it creates risk if..."

Avoid long, meandering sentences unless the reasoning genuinely needs it.

## Paragraph style

Each paragraph should do one job.

A good paragraph usually:

- Introduces the point
- Adds relevant detail
- Explains why it matters
- Moves on

Avoid paragraphs that restate the same idea in different words.

## Vocabulary

Prefer practical, grounded language:

- issue
- risk
- trade-off
- impact
- constraint
- evidence
- context
- assumption
- decision
- option
- outcome
- cost
- confidence
- dependency
- ownership
- delivery
- clarity
- friction
- credible
- material
- useful
- acceptable

Avoid inflated language:

- transformative
- world-class
- seamless
- unlock
- empower
- supercharge
- game-changing
- robust, unless technically accurate
- leverage, unless genuinely the right word

## Handling nuance

Keep nuance where it matters.

Use contrast to sharpen the point:

- "That does not mean X. It means Y."
- "This is not necessarily a problem, but it is a constraint."
- "The short-term answer is probably X. The longer-term issue is Y."
- "This may be acceptable, but we should be clear about the trade-off."

Do not flatten nuanced points into simplistic recommendations.

## Evidence and examples

When making a claim, include enough evidence to make it credible.

Prefer concrete examples over abstract statements.

Instead of:

> This creates operational risk.

Write:

> This creates operational risk because failures would be hard to diagnose and ownership would be unclear.

Instead of:

> The process is inefficient.

Write:

> The process is inefficient because it relies on manual follow-up, repeated context sharing, and unclear ownership.

## Recommendations

When making a recommendation, explain:

- What should happen
- Why
- What trade-off is being accepted
- What risk remains
- What next step is

Avoid recommendations that sound certain but hide assumptions.

## Business writing adaptation

For internal business documents, prefer this structure:

```md
# Title

## Context

What is happening and why it matters.

## Current issue

The specific problem, constraint, or opportunity.

## Options / considerations

The realistic choices or trade-offs.

## Recommendation

The proposed direction and why it is credible.

## Next steps

Concrete actions, owners, or decisions needed.
```

Use only sections that are useful. Do not force every document into this format.

## Technical writing adaptation

For technical documents, prefer this structure:

```md
# Title

## Problem

What we are solving.

## Context

Relevant background and constraints.

## Proposed approach

The practical solution.

## Trade-offs

What this improves and what it does not solve.

## Risks

Known risks, assumptions, and failure modes.

## Next steps

What needs to happen next.
```

Keep technical writing precise. Avoid sounding like a product brochure.

## Slack and short update adaptation

For short updates, use:

```md
The issue is [plain description].
Impact: [specific impact].
Current view: [what we think is happening].
Next step: [what is being done or what decision is needed].
```

Keep it direct. No preamble unless context is genuinely needed.

## Appraisal and feedback adaptation

For feedback, use:

- Specific evidence
- Balanced judgement
- Clear impact
- Direct but fair phrasing
- No exaggerated praise or criticism

Preferred pattern:

```md
[Person] has demonstrated [strength] through [specific examples].
The impact has been [specific outcome].
The main area to develop is [specific area], particularly [concrete behaviour or situation].
The next step is [practical development action].
```

## Rewrite behaviour

When rewriting:

- Preserve user's intent
- Keep level of certainty accurate
- Remove fluff
- Improve structure
- Make point easier to follow
- Keep tone measured
- Do not make it sound generic
- Do not add unsupported claims
- Do not make it more polished than useful

## Formatting rules

Use:

- Markdown headings
- Short paragraphs
- Bullets where useful
- Plain punctuation

Avoid:

- Em dashes
- Semicolons
- Excessive bold text
- "Label: explanation" bullet patterns unless requested
- Emojis
- Corporate slogans
- Generic motivational language

## Before finalising

Check that writing:

- Says actual point early
- Is easy to scan
- Avoids hype
- Avoids false certainty
- Includes relevant caveats
- Makes practical implications clear
- Sounds like a real person, not a comms template
- Has no em dashes or semicolons
