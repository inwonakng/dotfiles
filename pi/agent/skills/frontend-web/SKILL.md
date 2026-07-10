---
name: frontend-web
description: >-
  Use when designing, building, redesigning, or visually polishing frontend web UI: landing pages, marketing sites, dashboards, app screens, React/Vue/Svelte components, CSS/Tailwind styling, responsive layout, accessibility, animation, and requests like "make this look good" or "improve the visual design".
---

# Frontend Web

Use this skill when the work involves frontend web design or implementation where visual quality, interaction quality, responsive layout, or UI craft matters.

Approach frontend work as the design lead at a small studio known for giving every client a visual identity that could not be mistaken for anyone else's. The user is not asking for a templated AI mockup. Make deliberate, opinionated choices about palette, typography, layout, motion, and interaction that are specific to the brief, and take at least one real aesthetic risk you can justify.

## When This Skill Applies

Load and follow this skill for:

- creating a new web page, landing page, marketing page, portfolio, blog layout, dashboard, admin panel, app screen, or product UI
- redesigning or visually polishing an existing UI
- implementing frontend components where styling, layout, accessibility, or interaction behavior matters
- Tailwind, CSS, shadcn/ui, Radix, component library, theme, design token, responsive, animation, or accessibility work
- requests such as "make this look good," "improve the UI," "make it modern," "make it premium," "make it less generic," or "add visual polish"

If the request is mostly backend, CLI, data, or non-visual logic, do not load this skill just because the project happens to be a web app.

## Core Problem: Avoid Generic AI Aesthetics

You tend to converge toward generic, "on distribution" outputs. In frontend design, this creates what users call the "AI slop" aesthetic. Avoid this: make creative, distinctive frontends that surprise and delight.

Avoid generic AI-generated aesthetics:

- overused font families: Inter, Roboto, Arial, Open Sans, Lato, default system fonts
- clichéd color schemes, especially purple/blue gradients on white backgrounds
- predictable hero + three rounded cards + generic CTA patterns
- evenly distributed timid palettes where every color has the same visual weight
- flat white or gray backgrounds with no atmosphere
- generic numbered sections such as 01 / 02 / 03 when the content is not actually a sequence
- placeholder marketing copy such as "Built for modern teams" unless it is truly right for the product
- cookie-cutter component layouts that lack context-specific character

Interpret creatively and make unexpected choices that feel genuinely designed for the context. Vary between light and dark themes, different fonts, different aesthetics, and different layout structures. You may still converge on common fallback choices such as Space Grotesk; avoid this unless it is specifically appropriate.

## Ground the Design in the Subject

If the brief does not pin down what the product or subject is, pin it yourself before designing: name one concrete subject, its audience, and the page's single job, and state your choice before implementation.

Use the subject's own world, materials, instruments, artifacts, vocabulary, and vernacular as the source of distinctive choices. A finance dashboard, a botanical archive, a synth plugin, an emergency operations tool, and a ceramics portfolio should not share the same visual language.

Build with real content and subject matter throughout. Do not rely on lorem ipsum or abstract filler if you can invent concise, plausible domain-specific copy.

## Frontend Aesthetics Guidance

Focus on these four design dimensions.

### Typography

Typography instantly signals quality. Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial and Inter; opt instead for distinctive choices that elevate the frontend's aesthetics.

Never reach for these as the primary personality of a new design unless the existing project explicitly requires them:

- Inter
- Roboto
- Arial
- Open Sans
- Lato
- default system font stacks

Impact choices and directions:

- code / developer aesthetic: JetBrains Mono, Fira Code, IBM Plex Mono, Berkeley Mono-style choices where available
- editorial: Playfair Display, Crimson Pro, Fraunces, Newsreader, Cormorant
- startup / product: Satoshi, Cabinet Grotesk, Bricolage Grotesque, General Sans-style choices where available
- technical / institutional: IBM Plex family, Source Sans 3, Source Serif 4
- distinctive / crafted: Bricolage Grotesque, Obviously-style display faces, Newsreader, Fraunces

Pairing principle: high contrast is interesting. Display + monospace, serif + geometric sans, narrow utility + warm body, or variable font extremes often work better than one neutral family everywhere.

Use extremes deliberately:

- 100/200 weight vs 800/900, not only 400 vs 600
- size jumps of 3x+ for real hierarchy, not timid 1.25x or 1.5x steps
- tight display tracking and more generous body line-height where appropriate

Pick one distinctive typographic move and use it decisively. Make the type treatment itself a memorable part of the design, not a neutral delivery vehicle for content.

When adding external fonts, respect the project's conventions and performance constraints. If external network fonts are inappropriate, use locally available or existing project fonts and still create hierarchy through scale, spacing, weight, and rhythm.

### Color and Theme

Commit to a cohesive aesthetic. Use CSS variables or the project's design token system for consistency. Dominant colors with sharp accents outperform timid, evenly distributed palettes. Draw from IDE themes, cultural aesthetics, physical materials, art movements, historical references, product domains, and brand context for inspiration.

Before coding a new visual direction, name 4-6 color tokens with hex values or project-native token names:

- background / surface
- foreground / text
- primary or dominant color
- accent or signal color
- muted / border / secondary surface
- optional danger / success / data colors where relevant

Do not hardcode random colors throughout components. Define a small palette and derive the UI from it.

Theme examples you can adapt when appropriate:

- Cyberpunk: neon on dark, monospace type, glitch effects, scan lines, saturated accents
- Editorial: serif headlines, magazine grid, muted palette, pull quotes, fine rules
- SaaS minimal: one accent color, lots of air, strong product screenshots, restrained motion
- Dark OLED luxury: true black, warm metal accents, cream text, thin elegant type
- Brutalist: visible borders, raw spacing, large type, few or no rounded corners, loud contrast
- Retro-futuristic: gradient meshes, chrome, geometric shapes, purple/teal only if justified
- Organic / natural: earth tones, rounded shapes, warm shadows, fiber/paper/grain textures
- Art deco: gold + black, geometric motifs, symmetry, high-contrast serif display
- Solarpunk: warm optimistic greens/golds/earth tones, organic shapes plus technical diagrams
- Industrial / toolroom: stamped labels, measurement ticks, steel/graphite surfaces, utilitarian spacing

Where the user or existing product has a brand direction, follow it. Where the brief leaves an axis free, do not spend that freedom on the same generic defaults every model produces.

### Motion

Use animations for effects and micro-interactions, but use them deliberately. One well-orchestrated page-load or state-change moment usually creates more delight than scattered random hover effects.

Good uses of motion:

- staggered reveals on initial load
- a hero interaction that embodies the product idea
- hover/focus feedback that clarifies clickability
- transitions that explain state changes
- subtle ambient motion when it supports the theme

Implementation guidance:

- Prefer CSS-only solutions for plain HTML/CSS work.
- Use the project's existing animation utilities when available.
- For React, use Motion / Framer Motion only when it is already available or appropriate to add.
- Respect `prefers-reduced-motion`; disable or simplify non-essential motion.
- Keep performance in mind: transform and opacity usually animate better than layout-affecting properties.

Sometimes less is more. Extra animation can make a design feel more AI-generated. Match motion complexity to the vision.

### Backgrounds and Atmosphere

Create atmosphere and depth rather than defaulting to solid colors. Backgrounds should support the page's world.

Useful techniques:

- layered radial or linear gradients
- subtle geometric patterns
- contextual effects: grids, map lines, paper grain, scanlines, aurora, star fields, topographic lines, blueprint rules, material textures
- depth from overlapping panels, shadows, blur, translucency, or fine borders
- theme-specific environmental cues

Avoid flat white/gray backgrounds unless the design's precision and spacing are strong enough to carry the page.

## Design Principles

For web designs, the hero is a thesis. Open with the most characteristic thing in the subject's world, in whatever form makes sense: a headline, image, animation, live demo, product surface, interactive moment, data visualization, artifact, or strong typographic composition.

A big number with a small label, supporting stats, and a gradient accent is the template answer. Only use it if it is truly the best expression of this brief.

Structure is information. Structural devices such as numbering, eyebrows, dividers, labels, tabs, side rails, and cards should encode something true about the content, not merely decorate it. Numbered markers are appropriate if the content is actually a sequence, process, ranking, or timeline where order matters. Otherwise, question them.

Match complexity to the vision:

- Maximalist directions need elaborate execution and strong editorial control.
- Minimal directions need precision in spacing, type, alignment, contrast, and detail.
- Elegance is executing the chosen vision well, not making everything sparse.

Spend boldness in one place. Let the signature element be the one memorable thing, keep everything around it disciplined, and cut decoration that does not serve the brief. Not taking a risk can also be a risk.

## Required Process for New or Significant Visual Work

For any new page, substantial redesign, or visual-polish task, work in two passes.

### Pass 1: Brainstorm and Design Plan

Before writing code, create a compact design plan based on the user's brief. Keep it short but concrete.

Include:

1. **Subject, audience, and page job**
   - What this UI is specifically about
   - Who it is for
   - The one primary job the page/screen must accomplish

2. **Aesthetic direction**
   - A named direction, e.g. "industrial field console," "editorial botanical index," "dark OLED luxury," "solar punk operations room"
   - Why it fits the subject

3. **Color tokens**
   - 4-6 named colors as hex values or existing project tokens
   - Explain dominant color and sharp accent

4. **Type system**
   - Typefaces for at least two roles: display and body
   - Optional utility/mono face for captions/data
   - Weight, scale, and spacing decisions

5. **Layout concept**
   - One-sentence description of the layout
   - Use an ASCII wireframe when helpful to compare options

6. **Signature element**
   - The single unique element this page will be remembered by
   - It must embody the brief rather than being generic ornament

7. **Motion / interaction**
   - The one or two motion ideas that matter
   - Mention reduced-motion behavior when implementing animation

### Pass 2: Self-Critique Before Coding

Review the plan against the brief before building.

Ask:

- Does any part read like the generic default I would produce for any similar page?
- Did I choose typography, color, layout, and copy specifically for this subject?
- Did I accidentally choose Inter/system fonts, purple gradients, generic rounded cards, or meaningless numbered sections?
- Is the signature element meaningful or just decoration?
- Is the design distinctive without becoming noisy?
- Are accessibility, responsive behavior, keyboard focus, and reduced motion preserved?

If any part is generic, revise that part and say what changed and why. Only after confirming the relative uniqueness of the design plan should you write code.

For small edits to an existing UI, you may compress this process, but still make one or two deliberate design decisions before editing.

## Implementation Rules

Follow the existing project's stack and conventions. Do not introduce a new framework, styling system, component library, font pipeline, or animation library unless the user asked for it or the project already supports it.

Prefer project-native building blocks:

- use existing components before hand-rolling new ones
- use the project's design tokens, CSS variables, Tailwind theme, or component variants
- respect existing directory structure and naming conventions
- do not fight the framework's idioms

When using Tailwind:

- prefer tokens and theme variables over arbitrary one-off values when the project has tokens
- use responsive utilities intentionally, not as afterthoughts
- avoid massive unreadable class strings when a component abstraction or CSS layer is the project norm

When using CSS:

- define variables for repeated colors, spacing, radii, and shadows
- be careful with selector specificity; generated CSS classes can easily cancel each other out
- avoid broad element selectors that unexpectedly override component styles
- test layout at mobile and desktop widths where possible

When using component libraries such as shadcn/ui, Radix, Chakra, Mantine, etc.:

- use existing primitives and variants where they exist
- do not hand-roll a Button, Dialog, Form, Select, Tabs, or Tooltip if the project already has one
- preserve accessibility behavior from primitives
- style through supported variants, className hooks, theme tokens, or wrappers according to project norms

## Accessibility and Responsive Quality Floor

Build to this quality floor without making a big announcement about it:

- responsive down to mobile
- visible keyboard focus
- semantic HTML where possible
- accessible names for controls and icon-only buttons
- adequate contrast
- form labels and error text connected correctly
- reduced-motion respected
- no hover-only essential interactions
- hit targets large enough for touch when applicable

Visual ambition does not excuse inaccessible UI. Strong design and accessibility should reinforce each other.

## Writing and Interface Copy

Words are design material, not decoration. Copy can make a design feel as templated as the visuals.

Before writing anything, ask what the design needs to say and how it can best help the user navigate the experience. Write from the end user's side of the screen.

Guidance:

- Name things by what people control and recognize, not by how the system is built.
- A person manages notifications, not webhook config, unless the audience is explicitly developers configuring webhooks.
- Describe what something does in plain terms rather than selling it.
- Specific is better than clever.
- Use active voice by default.
- A control should say exactly what happens: "Save changes," not "Submit."
- Keep action names consistent: the button that says "Publish" should produce feedback that says "Published."
- Treat failure and empty states as moments for direction, not mood.
- Errors should explain what happened and how to fix it; they do not need to apologize.
- Empty states should invite action.
- Use sentence case unless the brand or component system says otherwise.
- Let each element do exactly one job: a label labels, an example demonstrates, a helper text helps.

## Visual References and Screenshot Loop

If the user provides a screenshot, mockup, Figma frame, brand guide, or visual reference, use it. Text prompts produce text-shaped output; visual references help anchor spacing, hierarchy, and style.

When the environment supports screenshots or browser preview:

1. Implement the UI.
2. Run the app or open the page.
3. Capture or inspect a screenshot.
4. Critique the actual rendered result, not just the code.
5. Fix obvious issues in spacing, overflow, contrast, hierarchy, and responsive layout.

A screenshot is often worth more than another paragraph of reasoning. If visual verification is not possible, say what was verified and what remains unverified.

## Verification

For frontend changes, choose the smallest relevant verification first:

- typecheck or build if available and relevant
- targeted component/story/page rendering command if the project has one
- lint when styling conventions or accessibility rules are covered by lint
- browser/screenshot check when possible
- manual inspection of generated CSS/markup for small static changes

Before claiming the work is done, use the `verify` skill. Report what was checked and what was not checked.
