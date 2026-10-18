---
name: frontend-web
description: >-
  Use when designing, building, redesigning, or visually polishing frontend web UI: landing pages, marketing sites, dashboards, app screens, React/Vue/Svelte components, CSS/Tailwind styling, responsive layout, accessibility, animation, and requests like "make this look good" or "improve the visual design".
---

# Frontend web

Make visual and interaction choices specific to the subject, audience, and task. Give the design a recognizable identity and take an aesthetic risk supported by the brief. Preserve an existing brand and project conventions.

Use this skill for visual web work, including pages, dashboards, product screens, styled components, themes, responsive layouts, animation, and accessibility. A web app's backend, CLI, or non-visual logic alone does not need it.

## Ground the design

Establish a concrete subject, audience, and primary page job before designing. If the brief leaves the subject open, choose one and state that assumption briefly before implementation.

Draw from the subject's materials, tools, artifacts, and vocabulary. Use real content or concise, plausible domain-specific copy rather than lorem ipsum or abstract filler.

Avoid defaulting to:

- Inter, Roboto, Arial, Open Sans, Lato, or system fonts as a new design's primary identity
- purple/blue gradients on white without a subject-specific reason
- a hero followed by rounded cards and a generic CTA
- palettes with no dominant color or clear accent
- flat white/gray surfaces without intentional spacing and hierarchy
- numbered sections whose content has no meaningful order
- placeholder claims such as "Built for modern teams"
- interchangeable component layouts

Vary themes, fonts, and layout structures to fit the subject. Treat common alternatives such as Space Grotesk as choices requiring a reason, not automatic replacements.

## Typography

Choose a distinctive type treatment and use it consistently. Existing project font requirements take precedence over the avoidance list.

Possible directions:

- Code/developer: JetBrains Mono, Fira Code, IBM Plex Mono, or available Berkeley Mono-style faces.
- Editorial: Playfair Display, Crimson Pro, Fraunces, Newsreader, or Cormorant.
- Product: Satoshi, Cabinet Grotesk, Bricolage Grotesque, or available General Sans-style faces.
- Technical/institutional: IBM Plex, Source Sans 3, or Source Serif 4.
- Crafted/display: Bricolage Grotesque, Newsreader, Fraunces, or available Obviously-style faces.

Use contrasting roles where appropriate: display and monospace, serif and geometric sans, or narrow utility and warmer body type. Consider weight contrasts such as 100/200 against 800/900 and size jumps of 3x or more when they clarify hierarchy. Use display tracking and body line height deliberately.

Respect font-loading conventions and performance limits. If network fonts are inappropriate, use local or existing fonts and create hierarchy through scale, spacing, weight, and rhythm.

## Color and theme

Define 4-6 tokens before coding a new visual direction, using hex values or existing project token names:

- background/surface
- foreground/text
- primary or dominant color
- accent or signal color
- muted/border/secondary surface
- optional danger, success, or data colors

Use CSS variables or project design tokens rather than scattered hardcoded colors. Give the dominant color and accent different visual weight.

Choose a direction suited to the subject. Examples include cyberpunk with neon and scanlines; editorial with serif type and fine rules; minimal SaaS with one accent and product imagery; dark OLED with warm metal accents; brutalist with visible borders and large type; retro-futuristic with chrome and geometric forms; organic with earth tones and grain; art deco with gold/black and symmetry; solarpunk with greens/golds and technical diagrams; or industrial with stamped labels and measurement ticks.

Keep the user's brand direction. Use unspecified parts of the brief for choices grounded in the subject rather than generic defaults.

## Motion

Concentrate motion on a coherent page-load or state-change moment rather than scattered hover effects. Useful choices include staggered reveals, a product-specific hero interaction, focus/hover feedback, state transitions, or ambient motion that supports the theme.

- Prefer CSS for plain HTML/CSS work and existing project utilities when available.
- Use Motion/Framer Motion in React only when already available or appropriate to add within project constraints.
- Respect `prefers-reduced-motion`; simplify or disable non-essential motion.
- Prefer transform and opacity over layout-affecting animation.
- Match animation complexity to the design; omit effects that add distraction.

## Backgrounds and layout

Use backgrounds to support the subject: layered gradients, geometric patterns, grids, map lines, grain, scanlines, star fields, topographic lines, blueprint rules, or material textures. Create depth through overlap, shadows, blur, translucency, or fine borders where appropriate. Flat white/gray can work when precision and spacing carry the design.

Open with the subject's most characteristic content, whether a headline, image, demo, product surface, artifact, visualization, or typographic composition. Use a large statistic with supporting numbers and a gradient only when it fits the brief.

Give structural devices meaning. Numbering should indicate a sequence, process, ranking, or timeline. Labels, tabs, dividers, side rails, and cards should convey content structure rather than add decoration.

Match execution to the chosen direction: maximalist layouts need editorial control; minimal layouts need precise alignment, spacing, type, and contrast. Concentrate boldness in a signature element and keep surrounding elements disciplined. Remove decoration that does not support the brief.

## Design before coding

For new pages, substantial redesigns, or visual polish, develop a compact design plan before implementation:

- subject, audience, and primary job
- aesthetic direction and its fit
- 4-6 color tokens with a dominant color and accent
- display and body type roles, optional utility face, weights, scale, and spacing
- layout concept, with an ASCII wireframe when it helps compare options
- a signature element grounded in the brief
- the important motion or interaction ideas and reduced-motion behavior

Then critique the plan internally. Check for interchangeable typography, colors, layout, or copy; default fonts and gradients; generic cards; meaningless numbering; and ornamental signature elements. Confirm the design is distinctive without noise and preserves accessibility, responsive behavior, keyboard focus, and reduced motion. Revise generic choices before coding.

Keep planning and self-critique internal unless the user requests a design proposal. Surface assumptions or decisions that need approval without narrating routine deliberation. For small changes, compress the process while still making deliberate design choices before editing.

## Implement within the project

Follow the existing stack, directory structure, naming, and component conventions. Do not introduce a framework, styling system, component library, font pipeline, or animation library unless requested or already supported by the project.

Reuse components, tokens, CSS variables, Tailwind themes, and variants before making replacements.

For Tailwind, prefer established tokens over one-off values, apply responsive utilities deliberately, and follow project conventions for extracting unreadable class strings.

For CSS, define variables for repeated colors, spacing, radii, and shadows. Check specificity and generated-class collisions. Avoid broad selectors that override components unexpectedly. Check mobile and desktop widths where possible.

For component libraries such as shadcn/ui, Radix, Chakra, or Mantine, reuse available primitives and variants. Do not recreate existing buttons, dialogs, forms, selects, tabs, or tooltips. Preserve primitive accessibility and style through supported variants, hooks, tokens, or project-standard wrappers.

## Preserve accessibility

Provide mobile-responsive layouts, visible keyboard focus, semantic HTML, accessible control names, adequate contrast, correctly connected form labels and errors, reduced-motion behavior, and touch-sized hit targets where applicable. Essential interactions must work without hover.

## Write interface copy

Write from the end user's perspective. Use names for what people control rather than internal implementation, unless the audience needs those technical terms.

Use plain, specific language and active voice. Controls should name the action, such as "Save changes" rather than "Submit." Keep action names consistent in feedback: "Publish" leads to "Published."

Errors should say what happened and how to fix it without unnecessary apologies. Empty states should direct the next action. Use sentence case unless the brand or component system requires otherwise. Give each label, example, and helper text a distinct job; avoid promotional copy and repetition.

## Inspect the rendered result

Use supplied screenshots, mockups, Figma frames, brand guides, and visual references to anchor spacing, hierarchy, and style.

When preview or screenshots are available:

1. Implement and run the app or page.
2. Capture or inspect the rendered result.
3. Fix spacing, overflow, contrast, hierarchy, and responsive-layout issues.

Judge the rendered UI rather than relying on code inspection alone.

## Verify and report

Start with the smallest relevant check: typecheck/build, targeted component/story/page rendering, applicable lint, browser/screenshot inspection, or generated markup/CSS inspection for small static changes.

Use `verify` before claiming completion. Report the changed result and checks concisely. If visual verification was unavailable, state what was checked and leave rendered behavior explicitly unverified.
