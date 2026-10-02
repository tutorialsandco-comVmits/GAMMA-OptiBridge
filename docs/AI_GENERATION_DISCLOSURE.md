# AI generation / vibe-coding disclosure

This project was **almost entirely vibe-coded with OpenAI GPT-5.6 Sol**.

The original project owner does **not** have a coding, software-engineering, graphics-programming, or C++ background. The owner provided the goal, described desired behaviour, ran builds, tested the game, supplied logs/videos/screenshots, compared visual results, and made product/quality decisions. The implementation work, debugging proposals, patch scripts, build workflows, documentation, configuration changes and most technical reasoning were generated with GPT-5.6 Sol through an iterative ChatGPT conversation.

In practical terms: the owner was acting primarily as the tester/operator and direction-setter, not as a developer capable of independently reviewing the generated code.

## What this means for anyone continuing the project

Do **not** assume that code in this repository is correct, idiomatic, safe, optimal, or well-designed simply because it compiled or appeared to work in the tested scenarios.

There has been no independent professional code review or security review. The original owner cannot personally vouch for the implementation quality because they do not have the programming knowledge required to audit it.

Some parts were validated empirically through repeated in-game testing, hashes, logs, controlled A/B comparisons and CI builds, but that is not a substitute for an experienced graphics/engine programmer reviewing the implementation.

A future maintainer should therefore:

1. treat the repository as an experimental prototype and investigation record;
2. independently review every engine patch before relying on it;
3. verify assumptions about X-Ray rendering, FSR2 inputs, motion vectors, jitter, resource lifetimes and shader interception;
4. audit the PowerShell/build/install scripts before distributing them;
5. reproduce the important results rather than trusting the original interpretation;
6. expect that some solutions may be overly complicated, technically incorrect, fragile, or merely sufficient for the original test environment;
7. feel free to rewrite large parts of the project if a cleaner implementation is apparent.

## Attribution

Project direction and hands-on testing: **original repository owner**.

Code generation, debugging assistance, implementation proposals, build/patch scripting and most technical documentation: **OpenAI GPT-5.6 Sol**, used interactively through ChatGPT.

This disclosure is intentionally prominent so the provenance and uncertainty of the code are clear to anyone who finds or forks the repository later.
