\# AI Instructions



\## General Rules



Modify the minimum number of files required.



Do not inspect the entire repository.



Inspect only files relevant to the requested task.



Before creating new files:

\- Check whether existing files, widgets, pages, services, or utilities can be reused.

\- Extend existing functionality whenever possible.



Reuse existing widgets.



Reuse existing pages.



Do not create duplicate screens.



Do not redesign existing UI unless explicitly requested.



Fix all introduced errors.



Do not automatically build APKs unless explicitly requested.



Always preserve the existing architecture.





\## Project Context



Always use these files for project understanding:



PROJECT.md

\- Understand the app purpose, features, requirements, and goals.



DESIGN.md

\- Understand the visual identity and design system.



ARCHITECTURE.md

\- Understand the technical structure, code organization, and implementation decisions.





\## Flutter Development Rules



When modifying Flutter code:



\- Follow the existing folder structure.

\- Reuse existing widgets and components.

\- Keep widgets small and reusable.

\- Avoid creating unnecessary dependencies.

\- Maintain null safety.

\- Preserve the existing state management approach.

\- Preserve existing navigation flow.

\- Avoid large monolithic widgets.

\- Do not refactor unrelated code.





\## Code Quality Rules



Before completing a task:



\- Verify no unnecessary files were changed.

\- Verify no duplicate components were created.

\- Verify existing functionality was preserved.

\- Fix any errors introduced by your changes.

\- Keep code consistent with the existing project style.





\## Task Scope



Only make changes directly related to the requested task.



Do not:

\- add extra features without permission

\- rewrite working code unnecessarily

\- change architecture without approval

\- replace existing solutions with new ones unless required



\# Model Behavior



For complex development tasks, architectural decisions, debugging, and major changes:



Read and apply:



.agents/prompts/gemini-king-mode.md



Use King Mode principles when:

\- designing new features

\- solving complex bugs

\- making architecture decisions

\- optimizing performance

\- planning large refactors



Do not use it for simple edits, formatting, or small changes.



\# Repository Intelligence



A Graphify code graph exists for this project.



Location:

graphify-out/



Use:

.agents/skills/graphify/SKILL.md



Before making large changes:

\- consult Graphify information

\- understand related files

\- trace dependencies



Use Graphify for:

\- architecture understanding

\- feature tracing

\- multi-file changes

\- refactoring decisions



Do not use Graphify for simple edits.



\## Documentation Rules



Before major changes:



\- Update CHANGELOG.md with a summary of the changes.

\- Include added features, changed behavior, and bug fixes.

\- Keep entries concise and relevant.



Do not update CHANGELOG.md for:

\- minor UI tweaks

\- formatting changes

\- simple typo fixes

\- small one-line fixes



\## Testing Rules



After code changes:



\- Run relevant Flutter analysis.

\- Fix introduced errors.

\- Do not ignore analyzer warnings.

\- Do not modify tests unless required.



\## Formatting



Before completing Flutter code changes:



\- Keep Dart formatting consistent.

\- Use dart format.

\- Avoid unnecessary formatting changes.

