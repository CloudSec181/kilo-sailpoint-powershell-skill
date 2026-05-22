# Contributing

Thanks for considering a contribution. This document covers the workflow.

## What kind of changes are welcome

**Always welcome:**
- Typo and grammar fixes.
- Corrections to API references (cmdlet names, endpoint paths, parameter shapes).
- New code examples that illustrate a pattern already covered.
- Tightening or broadening the `description:` field in `SKILL.md` based on real triggering behavior.

**Discuss first (open an issue):**
- New reference files covering a new pattern or domain.
- Changes to the team coding standards (the standards are opinionated by design — changes affect everyone using the skill).
- Significant restructuring of `SKILL.md`.

**Out of scope:**
- Skill content for other identity platforms (Okta, Entra ID, etc.). Fork the repo for those.
- Content for SailPoint IdentityIQ (on-prem). The skill is scoped to ISC; an IIQ variant is a separate skill.

## Development workflow

1. **Fork and clone.**
2. **Create a branch** named for what you're changing (`fix-pagination-example`, `add-workflow-patterns`).
3. **Edit the relevant files.** Most changes will touch one or more of:
   - `sailpoint-powershell/SKILL.md` — only when changing the core checklist or triggering description.
   - `sailpoint-powershell/references/*.md` — for pattern, auth, SDK/REST, or standards updates.
   - `sailpoint-powershell/templates/*.ps1` — for changes to the starter scripts.
4. **Test the skill locally.** See [Testing your changes](#testing-your-changes) below.
5. **Open a PR** with a clear description of what changed and why.

## Testing your changes

Skills are tested by installing them into a Kilo workspace and running prompts that should trigger them.

1. **Install your edited copy** into a sandbox project:
   ```bash
   mkdir -p /path/to/sandbox/.kilo/skills
   cp -r sailpoint-powershell /path/to/sandbox/.kilo/skills/
   ```
2. **Start a new Kilo session** in that workspace.
3. **Confirm the skill loads:**
   > Do you have access to the `sailpoint-powershell` skill?
4. **Run the test prompts** from the README's Usage examples section. Confirm the agent:
   - Loads the skill (look for the `skill` tool call).
   - Loads the relevant reference file when needed.
   - Produces code matching the updated guidance.

For changes to the triggering description, also test prompts that *shouldn't* trigger the skill (generic PowerShell questions, non-SailPoint identity questions) to make sure you didn't over-broaden.

## Style for skill content

- **Imperative voice for instructions.** "Use `Invoke-Paginate`" beats "You should use `Invoke-Paginate`."
- **Explain why, not just what.** A rule with a reason gets followed; a rule without one gets argued with or ignored.
- **Show examples.** Real code beats abstract guidance.
- **Keep `SKILL.md` under 500 lines.** Anything longer goes in `references/` and gets pulled in on demand.
- **No emoji in skill content.** Agents handle them inconsistently and they don't render well in some terminals.

## Style for PowerShell examples

All PowerShell in the skill (templates, snippets in reference files) follows the rules in `sailpoint-powershell/references/coding-standards.md`. If you're adding examples, match those conventions. If you think the conventions are wrong, open an issue rather than working around them in your example.

## Commit messages

Conventional Commits style, lightly enforced:

```
fix(patterns): correct Retry-After header parsing
docs(readme): add troubleshooting section for sparse checkout
feat(references): add workflow-execution patterns reference
```

## Code of conduct

Be kind. Disagree on technical points freely; don't disagree on people.
