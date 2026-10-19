# Writing tropes catalog

Each entry describes one trope and gives examples to avoid. Entries are grouped into six categories.

## Contents

- [Word choice](#word-choice): magic adverbs, "delve" and friends, "tapestry" and "landscape", promotional puffery, the "serves as" dodge, abstract metaphor nouns, synonym cycling, filler phrases
- [Sentence structure](#sentence-structure): negative parallelism, "Not X. Not Y. Just Z.", "The X? A Y.", anaphora abuse, tricolon abuse, "it's worth noting", superficial analyses, false ranges, gerund fragment litany
- [Paragraph structure](#paragraph-structure): short punchy fragments, listicle in a trench coat
- [Tone](#tone): "here's the kicker", "think of it as...", "imagine a world where...", false vulnerability, "the truth is simple", grandiose stakes inflation, "let's break this down", vague attributions, invented concept labels, excessive hedging, feelings instead of mechanisms, chatbot phrases, sycophantic tone, cutoff disclaimers
- [Formatting](#formatting): em-dash addiction, double-hyphen dash, colon overuse, bold-first bullets, title-case headings, unicode decoration
- [Composition](#composition): fractal summaries, the dead metaphor, historical analogy stacking, one-point dilution, content duplication, the signposted conclusion, generic conclusions, "despite its challenges..."

---

## Word choice

### "Quietly" and other magic adverbs

Overuse of "quietly" and similar adverbs to convey subtle importance or understated power. AI reaches for these adverbs to make mundane descriptions feel significant. Also includes: "deeply", "fundamentally", "remarkably", "arguably". An adverb propping up a weak verb usually means the verb is wrong: "runs quickly" becomes "is fast" or the measured number, and "significantly improves" becomes the measured change.

**Avoid patterns like:**
- "quietly orchestrating workflows, decisions, and interactions"
- "the one that quietly suffocates everything else"
- "a quiet intelligence behind it"

### "Delve" and friends

"Delve" is an uncommon English word that appears at a high rate in AI-generated text. It belongs to a family of overused AI vocabulary: "certainly", "utilize", "leverage" (as a verb), "robust", "streamline", "additionally", "crucial", "enduring", "enhance", "garner", "interplay", "intricate", "pivotal", "underscore". Prefer the plain word: "utilize" and "leverage" become "use", "facilitate" becomes "help", "numerous" becomes "many".

**Avoid patterns like:**
- "Let's delve into the details..."
- "Delving deeper into this topic..."
- "We certainly need to leverage these robust frameworks..."

### "Tapestry" and "landscape"

Overuse of ornate or grandiose nouns where simpler words would do. "Tapestry" is used to describe anything interconnected. "Landscape" is used to describe any field or domain. Other offenders: "synergy", "ecosystem", "framework". Keep a word when it is the field's established term, as in "web framework", and flag it only when it is used as a metaphor.

**Avoid patterns like:**
- "The rich tapestry of human experience..."
- "Navigating the complex landscape of modern AI..."
- "The ever-evolving landscape of technology..."

### Promotional puffery

Travel-brochure adjectives and legacy phrases that praise a subject instead of describing it. Words like "nestled", "vibrant", "breathtaking", "groundbreaking", "renowned", "stunning", and "must-visit" sell rather than inform. Phrases like "a testament to", "left an indelible mark", "setting the stage for", and "deeply rooted" assign significance without evidence. Use neutral descriptions and state what happened.

**Avoid patterns like:**
- "Nestled in the heart of the valley, this vibrant town boasts breathtaking views."
- "The project stands as a testament to the team's dedication."
- "Her work left an indelible mark on the field, setting the stage for decades of research."

### The "serves as" dodge

Replacing simple "is" or "are" with pompous alternatives like "serves as", "stands as", "marks", or "represents". The same dodge replaces "has" with "boasts" or "features". Just say "is" or "has".

**Avoid patterns like:**
- "The building serves as a reminder of the city's heritage."
- "Gallery 825 serves as LAAA's exhibition space for contemporary art."
- "The station marks a pivotal moment in the evolution of regional transit."

### Abstract metaphor nouns

Nouns borrowed as metaphors that sound technical but usually have a plainer concrete word. Offenders include "substrate", "wedge", "vector", "locus", "vantage", "nexus", "primitive" (as a noun), "harness" (as a metaphor), "surface" (as in "API surface"), "bedrock", "scaffolding" (as a metaphor), "modality", "paradigm", "gold-plating", "ratchet" (as a metaphor), "evacuate" (for moving code), "endgame", "north star", and "flywheel". Pick the concrete word. "Substrate" becomes "base". "Wedge in" becomes "add". "Vector" becomes "way" or "method". "Gold-plating" becomes "more than the job needs". "Ratchet" becomes the mechanism's real name or "a limit that only tightens". "Evacuate" becomes "move out". "Endgame" becomes "the last phase". Keep a word when it is the field's established term, as in "attack surface", "synchronization primitive", "attack vector", "test harness", or "programming paradigm", and flag it only when it is used as a metaphor.

**Avoid patterns like:**
- "The config file is the substrate for every plugin."
- "Latency is our north star, and caching is the flywheel."
- "Pricing is our wedge into enterprise."

### Synonym cycling

Rotating through synonyms for the same thing to avoid repeating a word. The reader has to work out whether "the protagonist", "the main character", "the central figure", and "the hero" are one person or four. In technical writing, a changed term implies a changed meaning. Pick one term and repeat it.

**Avoid patterns like:**
- "The protagonist... the main character... the central figure... our hero..."
- "The service... the daemon... the backend process... the worker..."
- "Run the tool. The utility will then... Once the program finishes..."

### Filler phrases

Wordy constructions with a short equivalent. "In order to" becomes "to". "Due to the fact that" becomes "because". "In the event that" becomes "if". "At this point in time" becomes "now".

**Avoid patterns like:**
- "In order to install the package, run the following command."
- "The build failed due to the fact that the cache was stale."
- "In the event that the request times out, retry it."

---

## Sentence structure

### Negative parallelism

The "It's not X — it's Y" pattern, often with an em dash, and widely cited as an AI writing tell. AI uses it to create false profundity by framing everything as a surprising reframe. One in a piece can be effective, but ten in a blog post insult the reader. Includes the causal variant "not because X, but because Y", where every explanation is framed as a surprise reveal; the em-dash dismissal "X — not Y"; the additive "not just X, but Y"; and the cross-sentence reframe where the same noun is negated then repositioned, as in "The question isn't X. The question is Y." State the point directly instead.

**Avoid patterns like:**
- "It's not bold. It's backwards."
- "Feeding isn't nutrition. It's dialysis."
- "Half the bugs you chase aren't in your code. They're in your head."

### "Not X. Not Y. Just Z."

The dramatic countdown pattern. AI builds tension by negating two or more things before revealing the actual point. Creates a false sense of narrowing down to the truth.

**Avoid patterns like:**
- "Not a bug. Not a feature. A fundamental design flaw."
- "Not ten. Not fifty. Five hundred and twenty-three lint violations across 67 files."
- "not recklessly, not completely, but enough"

### "The X? A Y."

Self-posed rhetorical questions answered immediately in the next sentence or clause. AI asks a question nobody was asking, then answers it for dramatic effect.

**Avoid patterns like:**
- "The result? Devastating."
- "The worst part? Nobody saw it coming."
- "The scary part? This attack vector is perfect for developers."

### Anaphora abuse

Repeating the same sentence opening multiple times in quick succession.

**Avoid patterns like:**
- "They assume that users will pay... They assume that developers will build... They assume that ecosystems will emerge..."
- "They could expose... They could offer... They could provide... They could create..."
- "They have built engines, but not vehicles. They have built power, but not leverage. They have built walls, but not doors."

### Tricolon abuse

Overuse of the rule-of-three pattern, often extended to four or five. A single tricolon can work. Several in a row read as a template. Use the number of items the content actually has.

**Avoid patterns like:**
- "Products impress people; platforms empower them. Products solve problems; platforms create worlds. Products scale linearly; platforms scale exponentially."
- "identity, payments, compute, distribution" (a four-item list stacked after other triads)
- "workflows, decisions, and interactions" (one more triad in a paragraph already full of them)

### "It's worth noting"

Filler transitions that signal nothing. AI uses these phrases to introduce new points without connecting them to the previous argument. Also includes: "It bears mentioning", "It is important to note that", "Importantly", "Interestingly", "Notably". Usually the sentence works with the phrase deleted.

**Avoid patterns like:**
- "It's worth noting that this approach has limitations."
- "Importantly, we must consider the broader implications."
- "Interestingly, this pattern repeats across industries."

### Superficial analyses

Tacking a present participle ("-ing") phrase onto the end of a sentence to inject shallow analysis that says nothing. AI attaches significance, legacy, or broader meaning to mundane facts using phrases like "highlighting its importance", "reflecting broader trends", "ensuring...", "showcasing...", "fostering...", or "contributing to the development of...". Delete the phrase, or replace it with a claim backed by a source.

**Avoid patterns like:**
- "contributing to the region's rich cultural heritage"
- "This etymology highlights the enduring legacy of the community's resistance and the transformative power of unity in shaping its identity."
- "underscoring its role as a dynamic hub of activity and culture"

### False ranges

Using "from X to Y" constructions where X and Y aren't on any real scale. In legitimate use, "from X to Y" implies a spectrum with a meaningful middle. AI uses it as a fancy way to list two loosely related things. List the topics directly.

**Avoid patterns like:**
- "From innovation to implementation to cultural transformation."
- "From the singularity of the Big Bang to the grand cosmic web."
- "From problem-solving and tool-making to scientific discovery, artistic expression, and technological innovation."

### Gerund fragment litany

After making a claim, AI illustrates it with a stream of verbless gerund fragments, each a standalone sentence with no grammatical subject. The first sentence already said everything. The fragments add word count and a recognizable AI cadence.

**Avoid patterns like:**
- "Fixing small bugs. Writing straightforward features. Implementing well-defined tickets."
- "Reviewing pull requests. Debugging edge cases. Attending architecture meetings."
- "Shipping faster. Moving quicker. Delivering more."

---

## Paragraph structure

### Short punchy fragments

Excessive use of very short sentences or sentence fragments as standalone paragraphs for manufactured emphasis. Each fragment holds one idea and leaves the reader to join them. Use a fragment for emphasis once, not as the paragraph's rhythm.

**Avoid patterns like:**
- "He published this. Openly. In a book. As a priest."
- "These weren't just products. And the software side matched. Then it professionalised. But I adapted."
- "Platforms do."

### Listicle in a trench coat

Numbered or labeled points dressed up as continuous prose. AI writes what is essentially a listicle but wraps each point in a paragraph that starts with "The first... The second... The third..." to disguise the format.

**Avoid patterns like:**
- "The first wall is the absence of a free, scoped API... The second wall is the lack of delegated access... The third wall is the absence of scoped permissions..."
- "The second takeaway is that... The third takeaway is that... The fourth takeaway is that..."

---

## Tone

### "Here's the kicker"

False suspense transitions that promise a revelation but deliver a point that did not need the buildup. Also includes: "Here's the thing", "Here's where it gets interesting", "Here's what most people miss", "Here's the starting point", "Here's the deal".

**Avoid patterns like:**
- "Here's the kicker."
- "Here's the thing about AI adoption."
- "Here's where it gets interesting."

### "Think of it as..."

The patronizing analogy. AI constantly reaches for "Think of it as..." or "It's like a..." to simplify concepts. It defaults to teacher mode and assumes the reader needs a metaphor to understand anything. The analogy is often less clear than the original concept.

**Avoid patterns like:**
- "Think of it like a highway system for data."
- "Think of it as a Swiss Army knife for your workflow."
- "It's like asking someone to buy a car they're only allowed to sit in while it's parked."

### "Imagine a world where..."

The AI invitation to futurism. To sell the argument, it begins with "Imagine" followed by a list of wonderful things that will happen if the reader agrees with the premise.

**Avoid patterns like:**
- "Imagine a world where every tool you use — your calendar, your inbox, your documents, your CRM, your code editor — has a quiet intelligence behind it..."
- "In that world, workflows stop being collections of manual steps and start becoming orchestrations."

### False vulnerability

Simulated self-awareness or honesty that reads as performative. AI pretends to break the fourth wall or admit a bias, creating a false sense of authenticity. The admission is polished and costs the writer nothing, which is what gives it away.

**Avoid patterns like:**
- "And yes, I'm openly in love with the platform model"
- "And yes, since we're being honest: I'm looking at you, OpenAI, Google, Anthropic, Meta"
- "This is not a rant; it's a diagnosis"

### "The truth is simple"

Asserting that something is obvious, clear, or simple instead of proving it. If you have to tell the reader your point is clear, it very likely isn't. Also includes the dramatic reveal variant, "but none of them is the real story. The real story is...", which claims privileged insight while waving away everything before it.

**Avoid patterns like:**
- "The reality is simpler and less flattering"
- "History is unambiguous on this point"
- "History is clear, the metrics are clear, the examples are clear"

### Grandiose stakes inflation

Everything is the most important thing ever. AI inflates the stakes of every argument to world-historical significance. A blog post about API pricing becomes a meditation on the fate of civilization.

**Avoid patterns like:**
- "This will fundamentally reshape how we think about everything."
- "will define the next era of computing"
- "something entirely new"

### "Let's break this down"

The pedagogical voice that assumes the reader needs hand-holding. AI defaults to a teacher-student dynamic even when writing for expert audiences. Also includes: "Let's unpack this", "Let's explore", "Let's dive in".

**Avoid patterns like:**
- "Let's break this down step by step."
- "Let's unpack what this really means."
- "Let's explore this idea further."

### Vague attributions

Attributing claims to unnamed authorities instead of being specific. AI invokes "experts", "observers", "some critics", "industry reports", and "several publications" without naming anyone. It also inflates the quantity of sources. It presents what one person said as a widely held view, or writes "several publications have cited" when it means two. A related form lists media outlets that covered something without saying what any of them said. Pick one and report what it said. If you can't name the expert, you don't have a source.

**Avoid patterns like:**
- "Experts argue that this approach has significant drawbacks."
- "Industry reports suggest that adoption is accelerating."
- "Observers have cited the initiative as a turning point."

### Invented concept labels

AI clusters invented compound labels that sound analytical without being grounded. It appends abstract problem-nouns (paradox, trap, creep, divide, vacuum, inversion) to domain words and uses them as if they're established, rigorously defined terms. The label stands in for an argument the text never makes. Several such labels in the same piece strongly signal AI-generated text.

**Avoid patterns like:**
- "the supervision paradox"
- "the acceleration trap"
- "workload creep"

### Excessive hedging

Stacking qualifiers until the claim disappears. One hedge is enough when the uncertainty is real, and none is needed when it isn't. "Could potentially possibly be argued that it might" becomes "may".

**Avoid patterns like:**
- "This could potentially help in some cases."
- "It might arguably be possible to say that the results seem promising."
- "There may perhaps be some room for improvement."

### Feelings instead of mechanisms

Sentences that name how a product feels instead of what it does. The fix names the mechanism or a number. Ask what the sentence tells the reader to do or know, then write that. If it can't be restated as a concrete instruction, fact, or number, cut it. If the sentence could appear unchanged in another project's docs, it says nothing about this one.

**Avoid patterns like:**
- "the database stays close at hand" (instead: "`.toSQL()` returns the exact string sent to the database")
- "SQL you can read"
- "types that follow your schema" (instead: "a column rename fails the build")

### Chatbot phrases

Conversational residue from a chat interface that leaks into finished text. Delete it.

**Avoid patterns like:**
- "I hope this helps!"
- "Certainly! Here's the updated version."
- "Let me know if you'd like any changes."
- "Of course!" or "Found the smoking gun!"

### Sycophantic tone

Praising the question or agreeing with the reader before answering. Respond directly.

**Avoid patterns like:**
- "Great question!"
- "You're absolutely right!"
- "What a fascinating idea."

### Cutoff disclaimers

Apologizing for missing information instead of finding it. Find a source, or remove the claim the disclaimer was propping up.

**Avoid patterns like:**
- "While specific details are limited..."
- "As of my last update..."
- "Information on this topic is not widely available, but..."

---

## Formatting

### Em-dash addiction

Compulsive overuse of em dashes for dramatic pauses, parenthetical asides, and pivot points. A human writer might use two or three per piece; AI will use twenty or more.

**Avoid patterns like:**
- "The problem — and this is the part nobody talks about — is systemic."
- "The tinkerer spirit didn't die of natural causes — it was bought out."
- "Not recklessly, not completely — but enough — enough to matter."

### Double-hyphen dash

The em dash replaced by a double hyphen. Writers who know that em dashes signal AI text sometimes swap the character, but the compulsive mid-sentence pivot survives the substitution, and that pivot is the tell. Writers who use double hyphens out of typographic habit do so once or twice, rarely fifteen times in one post. Flag at five or more per thousand words.

**Avoid patterns like:**
- "The migration -- the one we kept postponing -- finally landed."
- "It's not a rewrite -- it's a reckoning."
- "We shipped it fast -- maybe too fast -- and paid for it later."

### Colon overuse

Colons used as mid-sentence connectors instead of before a list or example. The colon sets up a comparison or reveal that the sentence doesn't need. Rewrite so the point stands on its own. "If you're coming from traditional automation: instead of registering event handlers, you describe conditions" becomes "Instead of registering event handlers, you describe the conditions."

**Avoid patterns like:**
- "If you're coming from traditional automation: instead of registering event handlers, you describe conditions."
- "The answer is simple: caching."
- "Here's what changed: everything."

### Bold-first bullets

Every bullet point or list item starts with a bolded phrase or sentence. AI markdown output does this constantly, and people writing lists by hand rarely do. It shows up most in generated documentation and README files, often alongside emojis. The clearest tell is a bold label and colon that restates the line, like "**Performance:** Performance improved...". Convert those to prose. A bold lead-in that ends in a period, names the item, and is followed by new detail is fine. A related habit is bolding every proper noun or acronym in running text.

**Avoid patterns like:**
- "Every single bullet point begins with a bold keyword."
- "**Security**: Environment-based configuration with..."
- "**Performance**: Lazy loading of expensive resources..."

### Title-case headings

Capitalizing every major word in headings. AI output defaults to title case where technical style guides, including Google's and Microsoft's, call for sentence case. Use sentence case.

**Avoid patterns like:**
- "## Getting Started With The Configuration File"
- "### Why This Matters For Your Team"
- "## Key Benefits And Use Cases"

### Unicode decoration

Unicode arrows, smart or curly quotes, and other characters that can't be easily typed on a standard keyboard. Real writers typing in a text editor produce straight quotes and -> or =>. Word processors and publishing tools often convert straight quotes to curly ones automatically, so flag curly quotes only in plain-text contexts such as code, commit messages, and terminal output. Decorative emojis in headings and bullets belong to the same habit; remove them.

**Avoid patterns like:**
- "Input → Processing → Output"
- "This leads to better outcomes → which means higher engagement"
- "Smart quotes instead of the straight quotes you'd actually type"
- "## 🚀 Getting started" or "- ✅ Fast builds"

---

## Composition

### Fractal summaries

"What I'm going to tell you; what I'm telling you; what I just told you" applied at every level of the document. Every subsection gets a summary. Every section gets a summary. The document itself gets a summary.

**Avoid patterns like:**
- "In this section, we'll explore... [3000 words later] ...as we've seen in this section."
- "A conclusion that restates every point already made in the previous 3000 words"
- "And so we return to where we began."

### The dead metaphor

Latching onto a single metaphor and beating it into the ground across the entire piece. A human writer would introduce a metaphor, use it, then move on. AI will repeat the same metaphor five to ten times.

**Avoid patterns like:**
- "The ecosystem needs ecosystems to build ecosystem value."
- "Walls and doors used 30+ times in the same article"
- "Every paragraph finds a way to say 'primitives' again"

### Historical analogy stacking

Rapid-fire listing of historical companies or tech revolutions to build false authority. Especially common in technical writing.

**Avoid patterns like:**
- "Apple didn't build Uber. Facebook didn't build Spotify. Stripe didn't build Shopify. AWS didn't build Airbnb."
- "Every major technological shift — the web, mobile, social, cloud — followed the same pattern."
- "Take Spotify... Or consider Uber... Airbnb followed a similar path... Shopify is another example... Even Discord..."

### One-point dilution

Making a single argument and restating it in ten different ways across thousands of words. AI pads a simple thesis to feel "comprehensive" by rephrasing the same idea with different metaphors, examples, and framings. An 800-word argument becomes 4000 words of circular repetition.

**Avoid patterns like:**
- "The same point, restated eight ways across 4000 words."
- "Each section rephrases the thesis with a different metaphor but adds nothing new"

### Content duplication

Repeating entire sections or paragraphs verbatim within the same piece. This happens when AI loses track of what it has already written, especially in longer pieces. It usually means nobody edited the output.

**Avoid patterns like:**
- "The same section appeared twice, word-for-word identical."
- "Paragraph 3 and paragraph 17 are the same sentence reworded"

### The signposted conclusion

Explicitly announcing the conclusion with "In conclusion", "To sum up", or "In summary". Competent writing doesn't announce that it is concluding, because the structure already shows it. AI signals its structural moves because it's following a template.

**Avoid patterns like:**
- "In conclusion, the future of AI depends on..."
- "To sum up, we've explored three key themes..."
- "In summary, the evidence suggests..."

### Generic conclusions

Ending on an upbeat line that could close any piece on any topic. End with a specific plan, fact, or next step instead, or stop when the content ends.

**Avoid patterns like:**
- "The future looks bright."
- "Only time will tell."
- "Exciting times lie ahead for the project."

### "Despite its challenges..."

The rigid formula where AI acknowledges problems only to immediately dismiss them. It follows the same beat: "Despite its [positive words], [subject] faces challenges..." then ends with "Despite these challenges, [optimistic conclusion]." Replace it with the specific problems and what is being done about them.

**Avoid patterns like:**
- "Despite these challenges, the initiative continues to thrive."
- "Despite its industrial and residential prosperity, Korattur faces challenges typical of urban areas."
- "Despite their promising applications, pyroelectric materials face several challenges that must be addressed for broader adoption."

---

The base catalog is adapted from [tropes.fyi](https://tropes.fyi) by [ossama.is](https://ossama.is).
