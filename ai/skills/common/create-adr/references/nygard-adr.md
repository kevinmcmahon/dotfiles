# Nygard ADR Source Notes

Use this file only when the ADR task needs source-grounded details or a sharper
review checklist.

## Canonical References

- adr.github.io overview: https://adr.github.io/
- adr.github.io templates: https://adr.github.io/adr-templates/
- Michael Nygard, "Documenting Architecture Decisions": https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions

## Source-Grounded Rules

- An ADR captures a single architectural decision and its rationale.
- A decision is architecturally significant when it affects structure,
  non-functional characteristics, dependencies, interfaces, or construction
  techniques.
- Nygard ADRs use title, status, context, decision, and consequences.
- Number ADRs sequentially and monotonically. Do not reuse numbers.
- Keep old decisions visible. When a later ADR changes a decision, mark the older
  one deprecated or superseded and link to the replacement.
- Context describes forces at play in neutral language. Include technological,
  social, project-local, political, operational, and constraint forces when they
  matter.
- Decision describes the response to those forces in full sentences and active
  voice.
- Consequences describe the new resulting context. Include positive, negative,
  and neutral consequences.
- Keep ADRs short, usually one or two pages.

## Drafting Prompts

Ask only for missing information that changes the decision:

- What decision are we recording?
- What local forces or constraints made this decision necessary?
- What alternatives were seriously considered?
- What downside are we consciously accepting?
- Is this proposed, accepted, or superseding an older ADR?

## Review Checklist

- The title names the decision, not the topic area.
- Status is explicit.
- Context is not selling the decision before the Decision section.
- Decision says what will be done.
- Consequences include future costs and operational effects.
- The ADR can stand alone for a future reader who did not hear the conversation.
