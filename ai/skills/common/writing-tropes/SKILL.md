---
name: writing-tropes
description: >
  Catalogs the tropes that make prose read as AI-generated and explains how to
  avoid or fix them. Use when writing or reviewing prose that people will read,
  including documentation, READMEs, commit messages, release notes, PR and
  issue text, UI copy, emails, and blog posts. Also use when asked to humanize
  or deslopify text, make it sound less like AI, or review it for AI tells such
  as "delve", negative parallelism ("it's not X, it's Y"), stacked tricolons,
  bold-first bullets, and em-dash pivots.
---

# Writing tropes

This skill lists the tropes that mark text as AI-generated. Use it in one of two modes.

## Writing mode

Avoid the tropes while drafting. Before delivering, scan the draft against the checklist below and rewrite any matches. Don't announce that you did this. Deliver the clean text.

## Review mode

Use this mode when asked to review, humanize, or deslopify existing text. Read `references/catalog.md`, then work through the text one category at a time. For each match, quote the passage, name the trope, and suggest a rewrite. Finish with a density report that says how many tropes matched, which ones repeat, and where they cluster.

## Calibration

One instance of a trope is usually fine. The failure is clustering and repetition, such as several tropes in one paragraph or one trope used throughout a piece. Avoiding tropes mechanically produces its own stilted style, so fix the passages that read as AI and leave natural ones alone. Good prose is specific, and its sentence length varies.

## Orwell's six rules

From George Orwell, "Politics and the English Language" (1946):

1. Never use a metaphor, simile, or other figure of speech which you are used to seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, always cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word, or a jargon word if you can think of an everyday English equivalent.
6. Break any of these rules sooner than say anything outright barbarous.

## Checklist

Each line names one catalog category and the tropes in it, with a short cue where the name alone isn't enough.

- Word choice: "quietly" and other magic adverbs (deeply, fundamentally), "delve" and friends (leverage, robust, crucial), "tapestry" and "landscape" (ornate nouns for any field), promotional puffery (vibrant, testament to), the "serves as" dodge (serves as, stands as, boasts), abstract metaphor nouns (substrate, north star, flywheel), synonym cycling (new name for the same thing each time), filler phrases (in order to, due to the fact that).
- Sentence structure: negative parallelism (it's not X, it's Y), "Not X. Not Y. Just Z.", "The X? A Y." (self-answered question), anaphora abuse (same opening repeated), tricolon abuse (stacked groups of three), "it's worth noting" (notably, importantly), superficial analyses (trailing "highlighting its importance"), false ranges (from X to Y with no scale), gerund fragment litany (Fixing bugs. Writing features.).
- Paragraph structure: short punchy fragments (one-line paragraphs for emphasis), listicle in a trench coat (The first... The second...).
- Tone: "here's the kicker" (here's the thing), "think of it as..." (patronizing analogy), "imagine a world where...", false vulnerability (and yes, I'll admit), "the truth is simple" (asserting clarity instead of proving it), grandiose stakes inflation (will reshape everything), "let's break this down" (let's dive in), vague attributions (experts say), invented concept labels (the X paradox, trap, or creep), excessive hedging (could potentially), feelings instead of mechanisms (name the mechanism or number), chatbot phrases (I hope this helps!), sycophantic tone (great question!), cutoff disclaimers (while details are limited).
- Formatting: em-dash addiction, double-hyphen dash (-- as an em dash), colon overuse (mid-sentence colon reveals), bold-first bullets (**Label**: restated line), title-case headings, unicode decoration (→, curly quotes in plain text, emojis).
- Composition: fractal summaries (summary at every level), the dead metaphor (one metaphor repeated throughout), historical analogy stacking (Apple didn't build Uber...), one-point dilution (one thesis restated at length), content duplication, the signposted conclusion (in conclusion), generic conclusions (the future looks bright), "despite its challenges..." (problems raised only to be dismissed).

## Full catalog

In review mode, always read `references/catalog.md`. In writing mode, read it when a checklist cue is unclear or you can't tell whether a phrase is a trope. Each entry there describes one trope, explains the plain alternative, and gives examples to avoid. The catalog is based on [tropes.fyi](https://tropes.fyi).
