---
name: writing-tropes
description: >
  Catalogs the tropes that make prose read as AI-generated and explains how to
  avoid or fix them. Use when writing or reviewing prose that people will read,
  including documentation, READMEs, commit messages, release notes, PR and
  issue text, UI copy, emails, and blog posts. Also use when asked to humanize
  or deslopify text, make it sound less like AI, or review it for AI tells such
  as "delve", negative parallelism ("it's not X, it's Y"), stacked tricolons,
  bold-first bullets, and em-dash pivots. Sets the sentence structure for
  technical prose (80% ASD-STE100) and strict mode for step-by-step procedures.
---

# Writing tropes

This skill lists the tropes that mark text as AI-generated, and the sentence structure technical prose follows. Use it in one of two modes.

## Writing mode

Avoid the tropes while drafting. For technical prose, also follow the Structure rules below. Before delivering, scan the draft against the checklist below and rewrite any matches. Don't announce that you did this. Deliver the clean text.

## Review mode

Use this mode when asked to review, humanize, or deslopify existing text. Read `references/catalog.md`, then work through the text one category at a time. For each match, quote the passage, name the trope, and suggest a rewrite. Finish with a density report that says how many tropes matched, which ones repeat, and where they cluster. For technical prose, also flag breaks of the Structure rules.

## Calibration

One instance of a trope is usually fine. The failure is clustering and repetition, such as several tropes in one paragraph or one trope used throughout a piece. Avoiding tropes mechanically produces its own stilted style, so fix the passages that read as AI and leave natural ones alone. Good prose is specific, and its sentence length varies. In technical prose, it varies under the 25-word ceiling the Structure section sets.

Three tie-breaks settle where the Structure rules and the rules below pull apart:

- Short sentences stay whole sentences. Join related ideas with "because", "so", "if", or "but" rather than splitting them into punchy fragments. A clause joined this way counts as part of the same idea.
- Orwell's rule 5 yields to the precise technical term when no everyday word means the same thing.
- Orwell's rule 6 covers the 80% Structure limits. Strict mode takes no exceptions, because step-by-step procedures need predictable steps.

## Orwell's six rules

From George Orwell, "Politics and the English Language" (1946):

1. Never use a metaphor, simile, or other figure of speech which you are used to seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, always cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word, or a jargon word if you can think of an everyday English equivalent.
6. Break any of these rules sooner than say anything outright barbarous.

## Structure: 80% ASD-STE100

Technical prose follows about 80% of ASD-STE100 (Simplified Technical English). It takes the structure rules and leaves out the controlled vocabulary. Technical prose means chat replies, explanations, plans, status updates, reviews, docs, ADRs, READMEs, commit message bodies, and issue or PR text. Agent instruction files (AGENTS.md, CLAUDE.md, SKILL.md) count as technical prose too.

Text with its own voice or format keeps it. The Structure rules stay out of these kinds of text:

- UI copy and other user-facing app text, emails, blog posts, and user-facing release notes.
- Marketing and store copy, and legal text.
- Code, code comments, log messages, LLM prompt strings in code, commit subject lines, and any required format.

The tropes and Orwell's rules still apply to the prose among them. Technical prose follows these rules:

- Keep each sentence to 25 words or fewer. Vary length under that ceiling.
- Write in the active voice, and name who or what acts.
- Put one idea in each sentence and one topic in each paragraph, with at most 6 sentences per paragraph.
- Use one word for one meaning, as the synonym cycling entry describes.
- Use the precise technical noun (API, cache, actor). Define a term the reader may not know where it first appears.
- Join clauses with periods, commas, and conjunctions. Semicolons stay out.
- Keep every fact, number, condition, caveat, and statement of uncertainty. Split a long sentence rather than cut content from it.
- Put a warning or precondition before the step it applies to.

When rewriting existing text into this style, list its facts, numbers, conditions, and caveats first, and confirm each one survives in the rewrite.

Runbooks, step-by-step checklists, manual test procedures, and release steps use strict mode. Read `references/ste-strict.md` before writing or editing one.

## Checklist

Each line names one catalog category and the tropes in it, with a short cue where the name alone isn't enough. The last line covers the Structure rules.

- Word choice: "quietly" and other magic adverbs (deeply, fundamentally), "delve" and friends (leverage, robust, crucial), "tapestry" and "landscape" (ornate nouns for any field), promotional puffery (vibrant, testament to), the "serves as" dodge (serves as, stands as, boasts), abstract metaphor nouns (substrate, north star, flywheel), synonym cycling (new name for the same thing each time), filler phrases (in order to, due to the fact that).
- Sentence structure: negative parallelism (it's not X, it's Y), "Not X. Not Y. Just Z.", "The X? A Y." (self-answered question), anaphora abuse (same opening repeated), tricolon abuse (stacked groups of three), "it's worth noting" (notably, importantly), superficial analyses (trailing "highlighting its importance"), false ranges (from X to Y with no scale), gerund fragment litany (Fixing bugs. Writing features.).
- Paragraph structure: short punchy fragments (one-line paragraphs for emphasis), listicle in a trench coat (The first... The second...).
- Tone: "here's the kicker" (here's the thing), "think of it as..." (patronizing analogy), "imagine a world where...", false vulnerability (and yes, I'll admit), "the truth is simple" (asserting clarity instead of proving it), grandiose stakes inflation (will reshape everything), "let's break this down" (let's dive in), vague attributions (experts say), invented concept labels (the X paradox, trap, or creep), excessive hedging (could potentially), feelings instead of mechanisms (name the mechanism or number), chatbot phrases (I hope this helps!), sycophantic tone (great question!), cutoff disclaimers (while details are limited).
- Formatting: em-dash addiction, double-hyphen dash (-- as an em dash), colon overuse (mid-sentence colon reveals), bold-first bullets (**Label**: restated line), title-case headings, unicode decoration (→, curly quotes in plain text, emojis).
- Composition: fractal summaries (summary at every level), the dead metaphor (one metaphor repeated throughout), historical analogy stacking (Apple didn't build Uber...), one-point dilution (one thesis restated at length), content duplication, the signposted conclusion (in conclusion), generic conclusions (the future looks bright), "despite its challenges..." (problems raised only to be dismissed).
- Structure, for technical prose only: sentences over 25 words, passive voice, two ideas in one sentence, semicolons, paragraphs over 6 sentences, a warning placed after its step.

## Full catalog

In review mode, always read `references/catalog.md`. In writing mode, read it when a checklist cue is unclear or you can't tell whether a phrase is a trope. Each entry there describes one trope, explains the plain alternative, and gives examples to avoid. The catalog is based on [tropes.fyi](https://tropes.fyi).
