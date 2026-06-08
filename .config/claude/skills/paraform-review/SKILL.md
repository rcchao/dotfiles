# PR Review Patterns Guide

A running guide of review feedback patterns from senior engineers (anthnykr, batuhan-akcay-paraform, taneliang, ruibinch, owen-paraform, inni-e). Use this to self-review PRs before sending them out.

*Sourced from PRs across paraform-xyz/paraform. Scan ranges: #7812 to #11882 (last updated 2026-05-18).*

---

## 1. Extract shared display text into helper functions

**Pattern:** When the same user-facing string (or string with minor conditional variation) appears in 3+ components, extract a helper function.

**Why reviewers flag this:** Duplicated UI copy is easy to update in one place and forget the others. It's also a sign of copy-paste development.

**What to do:** Create a small helper function (not a full component unless the JSX is complex) and import it. Place it in a `utils.ts` file adjacent to the components that use it.

**Example:** `suggestedRolesDescription(hasCandidate: boolean)` returning conditional description text, used across CreateCuratedListModal, EditList, CopyListModal.

**Source:** PR #9882 (batuhan-akcay-paraform)

---

## 2. Repository methods belong in the right domain file

**Pattern:** A `findCandidateId(candidate_user_id)` method was placed in `candidate_user_preference.repository.ts` because the service that needed it lived in the preference domain.

**Why reviewers flag this:** The method queries `candidate_user`, not `candidate_user_preference`. Repository files should be organized by the table they query, not by which service calls them. Future developers looking for candidate_user queries won't find it in the preference repo.

**What to do:** Always place repository methods in the file matching the table being queried. If `candidate_user.repository.ts` exists, put candidate_user lookups there.

**Source:** PR #9882 (batuhan-akcay-paraform)

---

## 3. Variable names should match the domain concept, not your mental model

**Pattern:** A variable was named `recruiterPref` when it queried `candidate_user_preference_source.USER_INPUT`.

**Why reviewers flag this:** The code says USER_INPUT, the variable says recruiter. A reader has to reconcile two mental models. This is especially confusing when there are multiple preference sources.

**What to do:** Name variables after what the code actually does: `userInputPref` matches `USER_INPUT`, `applicantPref` matches `APPLICANT_USER`. Don't inject interpretation into variable names.

**Source:** PR #9882 (batuhan-akcay-paraform)

---

## 4. Replace nested ternaries with if/else for readability

**Pattern:** `const x = a !== undefined ? a === "" ? null : a : undefined` - nested ternary with three branches.

**Why reviewers flag this:** Nested ternaries require mental stack-tracing. Each `?` and `:` adds cognitive load. If a reviewer has to read it twice, it's too complex for a ternary.

**Rule of thumb:** One level of ternary is fine. Two levels - use if/else. Three levels - definitely refactor.

**Source:** PR #9882 (batuhan-akcay-paraform)

---

## 5. Don't apply SQL directly to the database

**Pattern:** Using `ALTER TABLE` or inserting into `_prisma_migrations` directly instead of going through Prisma migration files.

**Why this matters:** Causes schema drift that blocks `prisma migrate dev` and can require a full database reset. Also breaks other branches sharing the same dev database.

**What to do:** Always modify `prisma/schema.prisma` and run `npx prisma migrate dev --name <migration_name>`.

---

## 6. Use tRPC over raw REST endpoints

**Pattern:** Using `fetch("/api/...")` for mutations when the codebase has tRPC.

**Why reviewers flag this:** Raw fetch bypasses type safety, input validation (Zod), and auth checks that tRPC provides. It's also inconsistent with the rest of the codebase.

**What to do:** Always check if a tRPC mutation exists or can be added. Only use raw fetch for endpoints that genuinely need to be REST (webhooks, external integrations).

---

## 7. All Prisma calls belong in repositories, not services

**Pattern:** Adding `prisma.table.findFirst(...)` directly in a service method.

**Why reviewers flag this:** The codebase has a strict layered architecture: Routers -> Services -> Repositories -> Prisma. Services should never import or call prisma directly.

**What to do:** Create a repository method and call it from the service. Use `read_only_prisma` for read operations where appropriate.

---

## 8. Use `satisfies` over `as const` for Prisma select/where objects

**Pattern:** Using `as const` on a Prisma select or where object instead of `satisfies Prisma.SomeType`.

**Why reviewers flag this:** `as const` just freezes the literal type - it doesn't verify the object matches the Prisma schema. If you misspell a field or add one that doesn't exist, TypeScript won't catch it. `satisfies` validates structure while still narrowing the type.

**What to do:** Use `satisfies Prisma.SomeModelSelect` or `satisfies Prisma.SomeModelWhereInput` instead of `as const` for Prisma query objects.

**Source:** PR #8932 (anthnykr)

---

## 9. Don't wrap queries in unnecessary transactions

**Pattern:** Wrapping a series of read queries and a single write in a `prisma.$transaction()`.

**Why reviewers flag this:** Transactions hold database locks. If the block is just some `findFirst`/`findMany` calls and one `updateMany`, there's no atomicity requirement - the reads don't need to be consistent with each other in a transaction boundary. Unnecessary transactions add latency and lock contention.

**What to do:** Only use transactions when multiple writes need to succeed or fail together, or when reads must be consistent with subsequent writes (e.g., check-then-act patterns with race conditions).

**Source:** PR #8932 (anthnykr)

---

## 10. Don't create thin wrapper functions

**Pattern:** Creating a `normalizeEmail(email)` function that just calls `email.toLowerCase().trim()` or wraps a single existing utility.

**Why reviewers flag this:** A function that just delegates to another function with no added logic is noise. It adds indirection without value and makes the reader wonder what extra behavior the wrapper provides.

**What to do:** Call the underlying function directly. Only create a wrapper if it adds meaningful logic (validation, error handling, default args, etc.).

**Source:** PR #8924 (anthnykr)

---

## 11. Log all items when volume is low, not just a sample

**Pattern:** Logging only a sample of invalid/problematic items (e.g., `invalidEmails.slice(0, 5)`) in a cron or batch job that runs infrequently.

**Why reviewers flag this:** If the log only fires once a day or less, truncating it makes debugging harder. You end up re-running the job or adding temp logging to see the full list. Premature log optimization wastes more time than it saves.

**What to do:** Log the full list when the log isn't high-frequency. Only truncate for hot paths (request handlers, loops that fire thousands of times).

**Source:** PR #8924 (anthnykr)

---

## 12. Use enums or constants for fixed string values

**Pattern:** Passing string literals like `"active_recruiters"` or `"weekly_sync"` directly as function arguments when they represent a fixed set of known values.

**Why reviewers flag this:** String literals are easy to typo and impossible to autocomplete. If the set of valid values is known, an enum or const object provides type safety, discoverability, and refactorability.

**What to do:** Define an enum or `as const` object for fixed value sets, then use the enum member instead of the string literal.

**Source:** PR #8904 (anthnykr)

---

## 13. Remove unnecessary type assertions

**Pattern:** Adding `as Prisma.applicationWhereInput` or `as Prisma.candidate_user_roleWhereInput` to an object that TypeScript can already infer correctly.

**Why reviewers flag this:** Type assertions (`as`) bypass type checking. If the type is correct without the assertion, adding it just suppresses future type errors that could catch real bugs. It's also visual noise.

**What to do:** Try removing the `as` cast. If TypeScript doesn't complain, the assertion was unnecessary. If it does complain, fix the underlying type rather than casting.

**Source:** PR #7400 (anthnykr)

---

## 14. Reuse existing constants from shared modules

**Pattern:** Hardcoding a list of IDs or values in a component when a shared constant already exists (e.g., `RECRUITER_OWNER_IDS` from `globalUser.ts`).

**Why reviewers flag this:** Duplicated lists drift apart over time. When someone adds a new recruiter owner to the constant, your hardcoded list stays stale. It also signals you didn't check what utilities already exist.

**What to do:** Before defining any list of IDs, roles, or config values, search `globalUser.ts`, `constants/`, and `utils/` for existing definitions. Use them directly.

**Source:** PR #7231 (anthnykr)

---

## 15. Put reusable mappings in backend, not frontend

**Pattern:** Mapping a list of users/IDs in a frontend component (e.g., `SOL_GLOBAL_USERS.map(...)` in a React component) when the backend already has the shared data.

**Why reviewers flag this:** Frontend mappings can't be reused by other backend services, crons, or API endpoints. Putting it in the backend (e.g., extending the constant with `...SOL_GLOBAL_USERS.map(...)`) makes it available everywhere.

**What to do:** If a mapping is over shared domain data (users, roles, config), add it to the backend constant/utility and consume it from the frontend.

**Source:** PR #7231 (anthnykr)

---

## 16. Check for existing functions before writing new ones

**Pattern:** Writing a new repository query or utility function without checking if one already exists for the same purpose.

**Why reviewers flag this:** The codebase is large. There's a good chance a `findCandidateById`, `formatSalary`, or similar function already exists. Duplicate functions diverge over time and confuse future developers about which to use.

**What to do:** Before writing a new repo method or utility, search the codebase for similar function names and the table/model being queried. If something close exists, extend it rather than duplicating.

**Source:** PR #9882 (batuhan-akcay-paraform), PR #6932 (anthnykr)

---

## 17. Extract duplicate formatting/display logic

**Pattern:** Writing inline formatting logic (e.g., salary range formatting, date display) that looks similar to an existing utility like `getRoleOTE` or `formatCompactSalaryRange`.

**Why reviewers flag this:** Formatting logic with edge cases (null handling, currency symbols, compact notation) is error-prone to reimplement. If a utility already handles these cases, duplicating it means bugs get fixed in one place but not the other.

**What to do:** Search for existing formatting utilities in `lib/utils/` and component-level utils before writing formatting logic inline. If one is close but not exactly right, extend it with a parameter rather than creating a parallel implementation.

**Source:** PR #6932 (anthnykr)

---

## 18. Delete unused code after refactoring

**Pattern:** Leaving an old component, import, or function in the codebase after it's been replaced by new code.

**Why reviewers flag this:** Dead code confuses future developers who wonder if it's still needed. It also inflates bundle size and creates false positives in code searches. If you replaced it, remove it in the same PR.

**What to do:** After any refactor, search for references to the old code. If nothing imports/calls it, delete it. Don't leave "just in case" code.

**Source:** PR #9897 (anthnykr - "is this gonna be removed now that it's unused?", "u can just delete this if it isn't used anymore")

---

## 19. Use tRPC mutation callbacks for side effects

**Pattern:** Managing toast notifications, cache invalidation, or optimistic updates with separate `useEffect` or manual state checks after a tRPC mutation, instead of using the mutation's built-in callbacks.

**Why reviewers flag this:** tRPC (via React Query) provides `onSuccess`, `onMutate`, `onError`, and `onSettled` callbacks on mutations. Using these is cleaner, avoids race conditions, and keeps side-effect logic co-located with the mutation.

**What to do:** Put toast notifications in `onSuccess`/`onError`, optimistic updates in `onMutate`, and cache invalidation in `onSettled`. Don't manage mutation side effects with separate state.

**Source:** PR #9897 (anthnykr - "you can do all this in the upsertBoost mutation using onSuccess, onMutate, onError, etc")

---

## 20. Keep routers thin, move logic to services

**Pattern:** Putting business logic (data transformation, conditional checks, multi-step operations) directly in a tRPC router instead of a service.

**Why reviewers flag this:** Routers should only handle input validation and delegation. Business logic in routers can't be reused by crons, other routers, or tests without importing the router itself.

**What to do:** Create a service method (e.g., `FirstSubmissionBoostService.getBoostStats`) and call it from the router. The router should be a thin passthrough.

**Source:** PR #9897 (anthnykr - "nit (non-blocking): move this to a FirstSubmissionBoostService.getBoostStats service")

---

## 21. Schema design: relations, indexes, defaults, and naming

**Pattern:** Creating a new Prisma model with missing foreign key relations, no indexes on FKs, unclear column names, or dangerous default values.

**Why reviewers flag this:** Multiple issues compound:
- **Missing FK relations:** `boosted_by_user_id` without a `@relation` to `User` means no referential integrity and no Prisma relation queries.
- **Missing indexes:** Foreign key columns without `@@index` cause slow joins at scale.
- **Unclear names:** `subs_per_week` vs `expected_subs_per_week` - the prefix makes intent clear.
- **Dangerous defaults:** `default: true` on a new boolean column silently changes behavior for all existing rows. Ask: should existing rows really have this enabled?
- **Redundant columns:** If `boost_reasons` is already a string array, a separate `other_reason` column may be unnecessary.
- **Indirect relations:** Link to the primary entity (`Role`) not a settings table, to avoid traversals like `Role -> role_settings -> first_submission_boost`.

**What to do:** For every new model/column, check: FK relation defined? Index on FK? Name self-documenting? Default value safe for existing rows? No redundant columns?

**Source:** PR #9897 (anthnykr), PR #9857 (batuhan-akcay-paraform - "Do we really want this to be default true?", "Should we make this an enum?")

---

## 22. Chunk Promise.all for unbounded arrays

**Pattern:** Using `Promise.all(items.map(async item => prisma.something.findFirst(...)))` where `items` could be any size.

**Why reviewers flag this:** Prisma has a connection pool (default 5-10 connections). If `items` has 100 entries, you fire 100 concurrent DB queries, exhausting the pool and causing timeouts or deadlocks.

**What to do:** Chunk the array into batches of ~5 and process each batch with `Promise.all` sequentially. Use a utility like `chunk()` from lodash or write a simple loop.

**Source:** PR #9842 (anthnykr - "we generally don't wanna do a promise.all with an unbounded array size, it's gonna hit prisma's connection pool limit. chunk it, e.g. in chunks of 5")

---

## 23. Add comments for complex algorithms

**Pattern:** Writing a multi-step scoring algorithm, quality calculation, or raw SQL query with no comments explaining the approach.

**Why reviewers flag this:** Complex algorithms (especially raw SQL with multiple JOINs, CASE statements, or scoring weights) are opaque without explanation. Future maintainers (including you) won't remember why specific thresholds or weights were chosen.

**What to do:** Add a block comment above complex algorithms explaining: what it does, what the major components/signals are, and why key thresholds were chosen. For raw SQL, explain the query strategy.

**Source:** PR #9857 (batuhan-akcay-paraform - "Can we add general comments on this sql algorithm for quality scoring? How does it operate, what are major components it looks at")

---

## 24. Prefer Prisma over raw SQL

**Pattern:** Writing raw SQL queries in repositories when the same query could be expressed with Prisma's query builder.

**Why reviewers flag this:** Raw SQL bypasses Prisma's type safety, is harder to maintain, and doesn't benefit from schema changes/migrations. It also creates a mental context switch for developers reading the code.

**What to do:** Default to Prisma query builder. Only use raw SQL (`prisma.$queryRaw`) when the query genuinely can't be expressed in Prisma (complex aggregations, window functions, recursive CTEs). If you do use raw SQL, add a comment explaining why Prisma wasn't sufficient.

**Source:** PR #9857 (batuhan-akcay-paraform - "Do you think it would be better to convert this raw SQL query to more standard prisma logic + typescript code?")

---

## 25. Always use design system components, never legacy or custom

**Pattern:** Using `<ButtonLegacy>`, creating custom styled buttons with inline styles, or building ad-hoc input components instead of the design system equivalents.

**Why reviewers flag this:** The team has invested in a design system (`/lib/components/ui`). Using legacy or custom components:
- Creates visual inconsistency
- Misses future design system upgrades (new DS work is underway)
- Adds maintenance burden for one-off styles
- Often gets the interaction patterns wrong (focus states, a11y, variants)

**What to do:**
- `<ButtonLegacy>` -> `<Button>` from design system
- Custom styled buttons -> `<Button variant="secondary">` or `<Button variant="destructive">`
- Don't make everything `primary` - only one primary action per screen
- Custom inputs -> `<Input>` from design system
- Use `<Button block>` for full-width buttons

**Source:** PR #9767 (taneliang - "Shouldn't use ButtonLegacy", "Shouldn't create custom buttons - strongly prefer design system components", "We have a design system Input too", "this shouldn't be primary so that we don't have multiple primary actions on the same screen")

---

## 26. Prefer early returns for invalid/edge cases

**Pattern:** Nesting valid-case logic inside `if (condition)` blocks instead of returning early for the invalid case.

**Why reviewers flag this:** Deep nesting makes it harder to follow the "happy path." Early returns for edge cases (null checks, invalid states, empty arrays) flatten the code and make the main logic more readable.

**What to do:** Flip the condition, return early, then write the main logic at the top indentation level. Example: `if (!valid) return null;` then proceed with the happy path un-nested.

**Source:** PR #9746 (ruibinch - "Early return for the invalid case is neater to read")

---

## 27. Right-size LLM output token limits

**Pattern:** Setting `max_tokens: 512` (or higher) for an LLM call that only needs a short JSON response with a category and a one-line explanation.

**Why reviewers flag this:** Over-allocated token limits waste money on every API call and can cause the model to pad responses with unnecessary text. If your expected output is ~50 tokens, setting 512 is 10x over.

**What to do:** Estimate the expected output size and set `max_tokens` to ~2x that estimate. For structured JSON responses, count the fields and typical value lengths.

**Source:** PR #9810 (owen-paraform - "512 seems like an unnecessary number of output tokens for a json with a one word explanation and a short string")

---

## 28. Don't add redundant checks handled by called functions

**Pattern:** Adding a null/existence check before calling a function that already handles that check internally.

**Why reviewers flag this:** Redundant guards add noise and can mask the actual contract of the called function. If `messageSlackChannel` already checks if the channel exists before sending, adding the same check before calling it is wasted code.

**What to do:** Read the implementation of functions you call. If they handle edge cases internally, trust the abstraction and don't duplicate the check at the call site.

**Source:** PR #9739 (anthnykr - "nit: don't need this channel check, it's already done in messageSlackChannel")

---

## 29. Follow existing codebase patterns for common operations

**Pattern:** Updating a field like `crons_last_synced` with a direct Prisma update instead of using the established helper function that other crons use.

**Why reviewers flag this:** The codebase often has specific patterns for common operations (e.g., `updateRoleLastSynced` keeps `updatedAt` stable while updating sync timestamps). Using a different approach creates inconsistency and may break assumptions other code relies on.

**What to do:** Before writing a common operation (updating timestamps, sending notifications, formatting Slack messages), search for how existing code does it. Use the same pattern/helper function.

**Source:** PR #9773 (anthnykr - "when crons_last_synced is updated in the codebase, it usually keeps the updatedAt field stable. function - updateRoleLastSynced")

---

## 30. Use data-driven patterns over manual switch/mapping

**Pattern:** Writing a manual switch statement or chained if/else to map values to sort orders or categories when the same thing could be a list with `indexOf`.

**Why reviewers flag this:** Manual mappings are verbose, error-prone when new values are added, and don't self-document the ordering. A data-driven approach (define the ordered list, use `indexOf`) is shorter, easier to maintain, and makes the ordering explicit.

**What to do:** Define values in an ordered array/object, then use `indexOf` for sort comparisons or object lookup for mappings. Only use switch/if-else when the logic per case is truly different.

**Source:** PR #9746 (ruibinch - suggested defining propensity values in a list and using indexOf for ordering)

---

## 31. Consider query efficiency with early returns

**Pattern:** Always running an expensive multi-table query (e.g., application quality scoring with multiple JOINs) before checking a cheap condition (e.g., `reviewed_count < 3`).

**Why reviewers flag this:** If the cheap check would short-circuit the expensive query, you're wasting DB resources on every invocation. This is especially impactful in crons that run frequently.

**What to do:** Order your checks from cheapest to most expensive. Run simple count queries or field checks first, and only proceed to complex queries if the cheap checks pass.

**Source:** PR #9857 (batuhan-akcay-paraform - "Would the application quality query be more efficient if we first check the reviewed count and if less than 3 early return rather than always running the complex query?")

---

## 32. Use enums for categorical schema fields

**Pattern:** Storing categorical data (quality levels like "HIGH"/"LOW", status values) as plain strings in the database instead of Prisma enums.

**Why reviewers flag this:** Plain strings allow typos, have no autocomplete, and require magic string comparisons everywhere. Enums enforce valid values at the database level and provide TypeScript type safety.

**What to do:** For any field with a known, finite set of values, define a Prisma enum and use it as the column type. Migrate existing string columns to enums when practical.

**Source:** PR #9857 (batuhan-akcay-paraform - "Should we make this an enum? LOW, HIGH etc.?"), PR #9857 ("might want to use constants here for 'HIGH' and 3")

---

## 33. Parallelize independent async operations

**Pattern:** Awaiting independent async calls sequentially (`const a = await getA(); const b = await getB();`) when they don't depend on each other.

**Why reviewers flag this:** Sequential awaits add unnecessary latency. If `getA()` takes 200ms and `getB()` takes 300ms, sequential is 500ms but parallel is 300ms.

**What to do:** Use `const [a, b] = await Promise.all([getA(), getB()])` for independent operations. But remember pattern #22 - chunk if the array is unbounded.

**Source:** PR #9810 (owen-paraform - "nit: no reason not to promise.all this")

---

## 34. Use camelCase for all new variables

**Pattern:** Declaring new variables with snake_case (`const role_id = ...`) instead of camelCase.

**Why reviewers flag this:** The team has been moving away from snake_case variables. Mixing conventions in the same file creates inconsistency and makes grep/refactoring harder. New code should follow the newer convention.

**What to do:** Use camelCase for all new variable declarations. Don't rename existing snake_case vars in unrelated code (that's a separate cleanup PR), but don't add new ones either.

**Source:** PR #8235 (taneliang - "We've been moving away from snake case vars, please use camel case for all new variables instead")

---

## 35. Remove AI-generated comments from code

**Pattern:** Leaving comments auto-generated by Cursor, Copilot, or other AI tools in the submitted code (e.g., `// This function handles...` boilerplate explanations).

**Why reviewers flag this:** AI-generated comments are often generic, redundant with the code itself, or outright wrong. They signal the code wasn't reviewed after generation. Reviewers shouldn't have to wonder which comments are intentional and which are AI artifacts.

**What to do:** Review all comments in your diff before submitting. Delete any that were auto-generated and don't add value. If a comment is useful, rewrite it in your own words to be specific.

**Source:** PR #8133 (taneliang - "remove Cursor comment")

---

## 36. Don't pass functions directly as array method callbacks

**Pattern:** Writing `.map(parseInt)` or `.filter(isValid)` instead of `.map(x => parseInt(x))` or `.filter(x => isValid(x))`.

**Why reviewers flag this:** Array methods pass extra arguments (index, array) to callbacks. If the passed function accepts optional parameters, it silently receives the index as a second arg. `["1","2","3"].map(parseInt)` returns `[1, NaN, NaN]` because `parseInt` gets called with `(value, index)`. TypeScript won't catch this.

**What to do:** Always wrap in an arrow function: `.map(x => parseInt(x))`. This makes the argument passing explicit and safe.

**Source:** PR #8350 (taneliang - "passing reusable functions as callback arguments is unsafe - if the function is changed to accept a number as a second argument, it'll start receiving the index")

---

## 37. Keep PRs focused - separate unrelated changes

**Pattern:** Including eslint config changes, unrelated refactors, or test infrastructure updates in a feature PR.

**Why reviewers flag this:** Mixed PRs are harder to review, harder to revert, and pollute git blame. If the eslint change causes a problem, you'd have to revert the feature too. Reviewers also have to context-switch between unrelated changes.

**What to do:** Split unrelated changes into separate PRs. If you notice a lint issue while working on a feature, fix it in a follow-up PR. Keep each PR doing one thing.

**Source:** PR #8185 (naveengovind - "nit: would good to separate the es-lint changes into a separate PR", "good to move all these changes related to removing it from eslint into a separate pr")

---

## 38. Use object params when function signatures grow

**Pattern:** A function with 4+ positional parameters: `function createRole(name, type, ownerId, settings, isLegal, companyId)`.

**Why reviewers flag this:** Positional params are easy to mix up (is `ownerId` the 3rd or 4th arg?), impossible to read at the call site without checking the definition, and painful to extend (adding a new param means updating every call site's argument order).

**What to do:** When a function has 3+ params, switch to a single object parameter: `function createRole({ name, type, ownerId, settings }: CreateRoleParams)`. This is self-documenting at the call site and order-independent.

**Source:** PR #9013 (minhpg - "too many params can we use an object here?")

---

## 39. Don't use fragile string matching for conditional logic

**Pattern:** Checking if a paragraph ends with `'here'` or `'feedback form'` to decide which URL to append, instead of passing the URL as a parameter.

**Why reviewers flag this:** String content checks break silently when copy is edited. If someone tweaks the email template text, the URL logic breaks. This is invisible to the editor because the logic is decoupled from the template.

**What to do:** Pass values explicitly as parameters or config. Never branch on string content that could be edited by non-engineers (email copy, UI text, notification messages).

**Source:** PR #8991 (anthnykr - "this logic doesn't feel that robust by checking a paragraph ending with 'here' or 'feedback form' - this can easily break if a template is edited")

---

## 40. Use findUnique when you have a unique key

**Pattern:** Using `prisma.table.findFirst({ where: { id: someId } })` when `id` is a unique/primary key.

**Why reviewers flag this:** `findFirst` implies the query might match multiple rows. `findUnique` signals intent (exactly one row), enables Prisma to optimize the query, and produces a clearer error if the constraint is violated.

**What to do:** Use `findUnique` whenever the where clause matches a unique constraint (primary key, `@@unique` fields). Only use `findFirst` when multiple rows could match and you want the first one.

**Source:** PR #8865 (owen-paraform - "this should be a findunique")

---

## 41. Check blast radius before modifying shared components

**Pattern:** Changing a shared component's props, behavior, or styling without checking what else uses it.

**Why reviewers flag this:** Shared components (modals, date pickers, tables, form inputs) can be imported by dozens of pages. A change that fixes your use case might break others. Reviewers will ask "will this affect anything else?" if you don't address it proactively.

**What to do:** Before modifying a shared component, search for all imports/usages. Note the impact in your PR description. If the change is risky, add a prop to opt-in to the new behavior instead of changing the default.

**Source:** PR #8271 (anthnykr - "just confirming will this affect anything else? this might be used in a few places")

---

## 42. Include screenshots for UI changes

**Pattern:** Submitting a PR with frontend/styling changes but no screenshot or screen recording in the PR description.

**Why reviewers flag this:** Reviewers can't verify visual changes from code alone. CSS changes especially can have unexpected effects. Without a screenshot, the reviewer has to check out your branch and navigate to the page manually.

**What to do:** For any PR that changes UI (layout, styling, new components, copy changes), include before/after screenshots or a short screen recording in the PR description.

**Source:** PR #8235 (taneliang - "The styling changes in this file look pretty gnarly, were these tested? Didn't see a screenshot/screen recording in the PR")

---

## 43. Use tRPC RouterInputs/RouterOutputs types for component props

**Pattern:** Manually defining a TypeScript type for props that mirror a tRPC query response, instead of deriving it from the router.

**Why reviewers flag this:** Manual types drift from the actual API response when the router changes. tRPC provides `RouterInputs` and `RouterOutputs` utility types that stay in sync automatically.

**What to do:** Import and use `RouterOutputs['routerName']['procedureName']` for component props that represent API data. This ensures type safety end-to-end.

**Source:** PR #8221 (anthnykr - "you can simplify reminder using trpc types from RecruiterRouterOutputs")

---

## 44. Add safety nets for scripts and backfills

**Pattern:** Writing a backfill script or data migration loop with no error handling or max-iteration guard.

**Why reviewers flag this:** Scripts run against production data. A bug in the loop condition can cause infinite iteration, an unhandled error can leave data in a partial state, and without logging you won't know what happened.

**What to do:** Add try/catch around the main loop body, log progress at regular intervals, set a max-iteration safety cap, and consider batching with `take`/`skip` for large datasets.

**Source:** PR #8858 (owen-paraform - "nice to have an error catch in case this goes crazy and keeps looping somehow")

---

## 45. Match test/benchmark settings to production

**Pattern:** Using `temperature: 1` in an LLM benchmark script when production uses `temperature: 0` (or vice versa).

**Why reviewers flag this:** Benchmark results are meaningless if settings don't match production. Different temperature, model, or prompt versions will produce different accuracy numbers that don't reflect real-world performance.

**What to do:** Always mirror production LLM settings (model, temperature, max_tokens, system prompt) in benchmarks. If you intentionally diverge, document why.

**Source:** PR #8835 (owen-paraform - "is there a reason we're using temperature 1 here? afaik we don't do that in production")

---

## 46. Don't mix concerns in validation/eligibility checks

**Pattern:** Adding ParaMatch rejection logic inside the core application eligibility check function that handles standard submission validation.

**Why reviewers flag this:** Eligibility checks are critical path code. Mixing in unrelated domain logic (matching, scoring, AI calibration) makes the checks harder to reason about, test, and maintain. Each concern should be a separate check.

**What to do:** Keep each validation check focused on one concern. If you need a new check, create a new eligibility check function rather than bolting it onto an existing one.

**Source:** PR #8185 (naveengovind - "would be best not to modify the core logic in the application submission check by adding in extra checks", "think we should separate any logic to do with paramatch outside this core eligibility check")

---

## 47. Don't prop-drill mutate functions - use SWR mutate or useUtils at the point of use

**Pattern:** Passing a `mutate` or `refetch` callback down through 3+ component layers as a prop so a deeply nested child can trigger a cache invalidation.

**Why reviewers flag this:** Prop drilling mutate functions creates tight coupling between parent and child components, makes the prop chain fragile, and clutters every intermediate component's props with passthrough values. SWR and tRPC both provide hooks to invalidate/refetch from any component.

**What to do:**
- **SWR:** Call `useSWR` with the same key in the child, or use `mutate` from `swr` with the key directly
- **tRPC:** Use `api.useUtils()` (or the SWR equivalent) in the child component to get the query client and call `.invalidate()` or `.refetch()` directly
- Only pass data down as props, not refetch/mutate functions

**Source:** PR #9922 (anthnykr - "just checking is there a cleaner way than passing this down 3 components?", "don't need to pass mutateCandidateInfo down, you can just do the SWR equivalent of api.useUtils()")

---

## 48. Flag unintended behavior changes in refactors

**Pattern:** Refactoring a function and accidentally changing its behavior (e.g., `handleResetFilters` no longer calling `handleResetView`) without noting it in the PR.

**Why reviewers flag this:** In a refactor PR, reviewers assume behavior is preserved unless stated otherwise. If a side effect is removed or a call chain is broken, the reviewer needs to know if it's intentional or a regression. Silent behavior changes are the hardest bugs to catch in review.

**What to do:** If your refactor changes any observable behavior, call it out explicitly in the PR description. If it's unintentional, fix it before requesting review. Diff your function's call graph before and after.

**Source:** PR #9922 (anthnykr - "handleResetFilters no longer calls handleResetView, is this intended?")

---

## 49. Use `isLoading` from useQuery, not data presence

**Pattern:** Checking `if (!data)` or `if (data === undefined)` to determine loading state instead of `isLoading` from the query result.

**Why reviewers flag this:** Data-presence checks conflate loading, error, and empty-result states. `isLoading` is the canonical loading boolean from React Query and disambiguates "still fetching" from "fetched and empty." This also avoids flicker on refetch.

**What to do:** Destructure `isLoading` (or `isPending` for tRPC v11) from the query and gate UI on that. Use `data` checks only for the rendered content.

**Source:** PR #11037 (anthnykr: "just check isLoading from the usequery", "check isLoading")

---

## 50. Use `assertNever` in switch defaults for exhaustiveness

**Pattern:** A `switch` over an enum/union with a silent `default:` branch (or no default) instead of `default: assertNever(value)`.

**Why reviewers flag this:** When you add a new variant to the enum/union, the switch will silently fall through. `assertNever` makes TypeScript fail the build at every switch that hasn't been updated, turning a silent runtime bug into a compile error.

**What to do:** For any switch over a finite union, end with `default: return assertNever(value);` (or throw via the helper). Same applies to `if/else if` chains over discriminated unions.

**Source:** PR #10323 (anthnykr: "consider using an assertNever in the default for switch statements generally. the reason is because if you add a new status and forget to update this switch, the missing case will be swallowed silently")

---

## 51. Don't add fallbacks for fields that are always present

**Pattern:** Writing `boost.amount ?? 0`, `application.user_id ?? ""`, `role?.name ?? ""`, or `(boost.amount as number)` for Prisma fields that are non-nullable in the schema, or for query results where the field is guaranteed by an earlier check.

**Why reviewers flag this:** Defensive fallbacks for impossible-null cases hide bugs. If the value ever IS null, it silently becomes 0 or empty string or falsy and downstream logic misbehaves. They also mislead the next reader into thinking the field can be null when it can't.

**What to do:** Check the Prisma schema. If the column is non-nullable, drop the fallback. If a where-clause guarantees the value, drop the fallback. Use `!` only as a last resort, and prefer an `assert` helper that throws loudly if the invariant breaks.

**Source:** PR #10322 (anthnykr, repeated 8+ times: "amount is always a number", "boost.amount always exists", "slots always exists"), PR #10284 (anthnykr: "user_id always exists on application records", "applicationIdToRoleRow keys are already strings, no need for a filter")

---

## 52. `take` without `orderBy` is non-deterministic

**Pattern:** `prisma.x.findMany({ where, take: 1 })` (or any other limit) with no `orderBy`.

**Why reviewers flag this:** Without `orderBy`, Postgres can return rows in any order, and the row you get back can change between runs as the table grows or vacuums. If you're taking 1 to find "the latest" or "the earliest," missing the orderBy gives you a random row that often happens to be correct in testing.

**What to do:** Always pair `take` with an `orderBy`. Even `take: 1` needs it. Pick the column that defines what "the one you want" means (usually `created_at desc` or a status timestamp).

**Source:** PR #10063 (anthnykr, flagged 7+ times in the same PR: "orderby", "if you're taking 1, don't you need to order it?", "same as other comment, dont you need an orderBy here if using take")

---

## 53. Move filtering, counting, and sorting to the backend

**Pattern:** Fetching a full list from a tRPC endpoint and then doing `.filter()` / `.reduce()` / `.sort()` in the component to compute tab counts, badge text, or derived state.

**Why reviewers flag this:** The client iterates the full list on every render, ships data the user never sees, and duplicates logic the backend already has. It also means the front end has to import enums and types that should be backend-only. As the dataset grows the page slows down for no reason.

**What to do:** Return the computed counts/groups/sort order from the backend. The frontend should consume display-ready data. Reasonable client-side work: trivial conditional styling, formatting a date. Anything that touches every row of an array belongs server-side.

**Source:** PR #11017 (owen-paraform: "this shit sucks and it should definitely be in the backend", "all the filtering, counting, and sorting is client-side... iterating the full list once per stage chip on every render, which is terrible"), PR #11088 (owen: "the endpoint should filter them so that the front end doesn't have to"), PR #10711 (owen: "this is the kind of thing that should ideally be calculated in the backend")

---

## 54. Don't create a new endpoint when the data fits an existing response

**Pattern:** Adding a new tRPC procedure to fetch a single derived field (e.g., a limit, a count, an availability boolean) that could be appended to the existing endpoint's response.

**Why reviewers flag this:** Each new endpoint adds a network round-trip and another auth/validation surface to maintain. If the data is always fetched alongside another query (same screen, same user, same role), the existing endpoint should return it.

**What to do:** Before adding a procedure, check whether the component that needs the data already calls a related endpoint. If yes, extend that endpoint's response shape. Reserve new endpoints for genuinely independent data.

**Source:** PR #10908 (owen-paraform: "this shouldn't be its own API call, it should just be returned on the getNextRoleClientMatch response", "as I said in the component comment, no need for this to be a new endpoint", "the front end doesn't need to know about the limit")

---

## 55. Throw tRPC errors in the router, not in the service

**Pattern:** Throwing `new TRPCError({ code: "FORBIDDEN", ... })` from inside a service method.

**Why reviewers flag this:** Services should be transport-agnostic so they can be reused by crons, queues, scripts, and other routers. Throwing tRPC errors couples the service to the HTTP/tRPC layer. The service should return a status (enum, discriminated result, or throw a domain error) and the router translates it to the right tRPC code.

**What to do:** Have the service return data with a status field, an enum, or throw a plain domain `Error`. The tRPC procedure inspects the result and throws the appropriate `TRPCError`. Also: do auth checks in the procedure (via `assertTrpcGuardianChecks` or similar), not buried in service code.

**Source:** PR #10890 (naveengovind: "best to avoid throwing TRPC errors directly from the service... having validateRecruiterInSameAgency return enums or some form of invalid status that the router can consume"), PR #10322 (anthnykr: "we usually do auth checks in the trpc procedure instead of the service files")

---

## 56. Don't `useMemo` cheap computations

**Pattern:** Wrapping `arr.length`, a simple `arr.filter(x => x.active)`, or a single arithmetic expression in `useMemo`.

**Why reviewers flag this:** `useMemo` has its own cost (dependency comparison, cache slot, hook bookkeeping). For cheap synchronous work, it's slower than just recomputing. It also signals the author cargo-culted memoization without measuring.

**What to do:** Only `useMemo` when the computation is genuinely expensive (loops over large arrays, deep object construction passed to memoized children) or when reference equality matters for a dependency. Otherwise just a `const` in the render body.

**Source:** PR #9946 (anthnykr: "no need for a usememo here, not an expensive calculation", "unnecessary useMemo here, this can just be a const"), PR #10172 (anthnykr: "does this need a useMemo? could just be a variable")

---

## 57. New services should be classes

**Pattern:** Creating a new `*.service.ts` file as a collection of exported functions or a plain `const xService = { foo, bar }` object.

**Why reviewers flag this:** The team is standardizing on class-based services (with private helpers as methods, shared state as fields). Class form makes the public surface explicit, enables private helpers without polluting module exports, and keeps related types/methods grouped.

**What to do:** Write new services as `export class FooService { ... }`. Move helper functions that are only used by the service into private methods. Put shared types next to the class in a colocated `types.ts` once there are enough of them.

**Source:** PR #11024 (owen-paraform: "would be nice if this was a class, as I think we should prefer that going forward", "this could be a nice private method instead of a floating helper"), PR #11173 (owen: "it's much nicer when these are classes, if you could convert it"), PR #11017 (owen: "try not to have helper functions that live outside the service object unless you can't avoid it")

---

## 58. Use the versioned JSON system for evolving JSON fields

**Pattern:** Storing a new shape inside an existing `json` Prisma column (or adding a second version of one) without going through `lib/versioned/`.

**Why reviewers flag this:** Once a JSON column has more than one historical shape, readers need a way to know which version a row is and migrate on read. The codebase has a versioning system in `lib/versioned/` precisely for this. Adding new keys ad-hoc creates undocumented mixed-shape rows that are painful to reason about.

**What to do:** For any JSON column expected to evolve, define versioned types under `lib/versioned/<Field>/` with a `version` discriminator and reader functions that handle each version. For columns unlikely to change, still type the shape via Zod inline.

**Source:** PR #11529 (anthnykr: "now that there's more than 1 version of the json field it'd be good to use the versioning system in the codebase, lib/versioned/..."), PR #11226 (anthnykr: "if you expect this json field to change quite often then it may be worth using the json versioning system, lib/versioned")

---

## 59. Don't use `updated_at` as a proxy for a state-change date

**Pattern:** Treating `updated_at` on a row as "the date this row reached status X" (e.g., querying `application.updated_at` to find hire date, paused date, etc.).

**Why reviewers flag this:** `updated_at` bumps on ANY field change: notes, tags, ATS sync, internal flags. A row that was hired last month can re-enter a "hired this week" window just because someone touched an unrelated field. The number is silently wrong.

**What to do:** Use the audit/history table that records the state transition explicitly (e.g., `application_audit` with `status = HIRED`, take the earliest `created_at`). The existing `first_reach` CTE pattern in pacing queries is the canonical approach.

**Source:** PR #11270 (HARI-PRMD: "windowHires uses updated_at on application as a proxy for hire date, but updated_at bumps on any field change... Use application_audit to find the first row with status=HIRED"), PR #10014 (naveengovind: "probably shouldn't use updated_at for this as the expiration cut off since there is multiple places that could update this")

---

## 60. Don't import tRPC client error types into frontend components

**Pattern:** `import { TRPCClientError } from "@trpc/client"` in a component to check `if (err instanceof TRPCClientError && err.data?.code === "...")`.

**Why reviewers flag this:** Pulling tRPC internals into UI code couples component code to the transport layer and adds bundle weight for a check that's usually doable by inspecting the error message. If you really need a stable signal, expose it as a string constant both ends share.

**What to do:** Filter on the error message string, or define a shared constant for the error message in a constants file that both the procedure and the component import. Don't reach into tRPC's class hierarchy from the frontend.

**Source:** PR #10908 (owen-paraform: "don't import trpc client error into the front end, it's good enough to filter on the message. if you really want to prevent drift you can establish the message as a constant")

---

## 61. Set cron timezone in the cron config, not in the handler

**Pattern:** Reading the current time in UTC inside a cron handler and calling `.tz("America/Los_Angeles")` to convert before doing PST-based date math.

**Why reviewers flag this:** Cron schedulers (GCP Cloud Scheduler, Vercel cron) accept a timezone in the cron definition. Setting it there means `dayjs()` inside the handler already starts in the right zone, the schedule firing time is unambiguous, and there's one source of truth for "what timezone does this cron run in."

**What to do:** Configure the cron entry to run in the target timezone and remove the manual conversion inside the handler. `now.year()`, `now.startOf('day')`, etc. then work correctly without extra `.tz()` calls.

**Source:** PR #11090 (anthnykr: "small cleanup, the cron timezone can just be set to PST already, don't need to manually convert timezones", "similar to other comment above, pst can be set in the cron timezone")

---

## 62. Run schema migrations in a separate PR before the code change

**Pattern:** Shipping a Prisma migration that adds/renames columns in the same PR as the code that reads/writes those columns.

**Why reviewers flag this:** During deployment, the migration and the new code don't land atomically. There's a window where either the old code is running against the new schema or the new code is running against the old schema, which can cause production errors for a few minutes. Splitting the migration first lets prod settle on the new schema before behavior changes.

**What to do:** Open a PR with just the migration (additive changes only: new columns nullable, new tables, new indexes). Merge and deploy. Then open the follow-up PR with the code that uses the new columns. For destructive changes, reverse: ship code that no longer references the column, then a separate PR to drop it.

**Source:** PR #11435 (inni-e: "I think doing migrations in tandem with code changes using the new columns causes downtime in prod for a few minutes. May be best to do your migrations first in a separate PR and then do this code change")

---

## 63. Search for built-in utilities before reimplementing string helpers

**Pattern:** Writing inline `s.charAt(0).toUpperCase() + s.slice(1)`, `count === 1 ? "match" : "matches"`, `name.split(" ")[0]`, or `s.toLowerCase().trim()`.

**Why reviewers flag this:** The codebase ships `capitalize`, `capitalizeAllWords`, `pluralize`, `parseFirstName`, `validHttpUrl`, `validLinkedinUrl`, and `getSlackErrorMessage` (among others). Reimplementing them inline guarantees inconsistent edge cases (Unicode capitalization, hyphenated names, irregular plurals) and means bug fixes in one place don't propagate.

**What to do:** Before writing a string transform, grep `lib/utils/` for a likely name (`pluralize`, `capitalize`, `parseFirstName`, `formatX`). Use the existing helper.

**Source:** PR #10011 (anthnykr: "some useful util functions for the future: capitalize capitalizeAllWords pluralize"), PR #10284 (anthnykr: "for future reference you can use our parseFirstName function", "hari made a getSlackErrorMessage function to use"), PR #11364 (anthnykr: "for the future you can use pluralize(...)"), PR #11525 (anthnykr: "i think there's functions for this already, search something like validHttpUrl, validLinkedinUrl")

---

## 64. Use Bedrock Anthropic, not the Vercel AI SDK wrapper

**Pattern:** Importing `anthropic` from `@ai-sdk/anthropic` (Vercel) or calling raw `streamText`/`generateObject` from `ai` directly inside a service.

**Why reviewers flag this:** The codebase has a `para-ai` service that wraps the Bedrock Anthropic client with retry, logging, and model routing. Bypassing it means missing those guarantees and creating two parallel ways to call Claude.

**What to do:** Always go through the `para-ai` service methods. If you genuinely need a new capability, add it inside `para-ai` rather than reaching for the raw Vercel function.

**Source:** PR #11646 (owen-paraform: "please use bedrock anthropic, not the vercel one", "please do not use these raw vercel functions; please use the methods defined in para-ai service")

---

## 65. Use `findUnique` on composite unique indexes too

**Pattern:** Using `findFirst({ where: { application_id, payment_type } })` when `payment` has a `@@unique([application_id, payment_type])` composite index.

**Why reviewers flag this:** Composite unique constraints support `findUnique` via the generated `{ application_id_payment_type: { ... } }` key. Using `findFirst` discards that guarantee and skips Prisma's optimization.

**What to do:** Check the schema for `@@unique([...])` on the model. If your where matches it, use `findUnique` with the composite key shape.

**Source:** PR #11090 (anthnykr: "payment has a unique composite index so you can findunique on application_id + payment_type")

---

## 66. Use Statsig `guardian.isOn` for feature flags, not legacy flag systems

**Pattern:** Checking a feature flag via the old custom system, or reading flag config out of a settings object, instead of `guardian.isOn("flagName", { companyId })`.

**Why reviewers flag this:** The team is migrating to Statsig. Guardian's `isOn` is the standard interface, supports targeting attributes (company, user), and is the path forward. New flag checks should use it.

**What to do:** For any new feature flag check, use `guardian.isOn("flagName", { companyId })` (or relevant attributes). Don't add new usages of the legacy flag system.

**Source:** PR #11090 (anthnykr: "should be able to check if a flag is enabled by just doing guardian.isOn(\"flag\", { companyId } )"), PR #10793 (charan-karthik-paraform: "we'll be moving to statsig for feature flags so this may need to be updated")

---

## 67. Don't read localStorage synchronously in render; use `useClientState`

**Pattern:** Calling `localStorage.getItem(...)` directly in a component body or initial state to bootstrap UI state.

**Why reviewers flag this:** Synchronous localStorage reads break SSR (no `window` on the server) and cause hydration mismatches. The codebase ships `useClientState` which initializes the value lazily on the client and avoids both problems.

**What to do:** Use `const [val, setVal] = useClientState(defaultValue, () => readFromStorage(...))` instead of touching `localStorage` directly in render or `useState` initializers.

**Source:** PR #11088 (owen-paraform: "reading localstorage synchronously", "should use useClientState, e.g `const [dismissed, setDismissed] = useClientState(false, () => isDismissed(roleId, userId));`")

---

## 68. Use `dayjs` for all date math, not native `Date`

**Pattern:** `new Date()`, `Date.now()`, manual ms arithmetic, or `someDate.toISOString()` in business logic.

**Why reviewers flag this:** The codebase standardizes on dayjs for timezone handling, formatting, and arithmetic. Mixing native `Date` and dayjs leads to subtle bugs (timezone defaults, off-by-one days) and inconsistency.

**What to do:** Use `dayjs()` / `dayjs.utc()` / `dayjs.tz()` for all date construction and manipulation. Convert to ISO strings via `.toISOString()` on a dayjs object only at the boundaries.

**Source:** PR #11088 (owen-paraform: "Native Date, use dayjs")

---

## 69. Frontend-only utilities belong in a client utils file

**Pattern:** Adding a function used only by the frontend (e.g., `isValidImageSrc`) to `lib/utils/utils.ts` (which is shared with the server).

**Why reviewers flag this:** Shared utils bundles get pulled into both server and client builds. Functions only used in the frontend should live in a client-side utils file so the server bundle stays lean and the import graph reflects actual usage.

**What to do:** If a util is only consumed by React components, put it in a client-side utils file (the codebase has several). Reserve `lib/utils/utils.ts` for genuinely cross-cutting helpers.

**Source:** PR #11088 (owen-paraform: "this thing is only used in the front end, should be written in a client side utils file (there are many)")

---

## 70. Colocate a `types.ts` file when a service or component dir grows

**Pattern:** Defining 5+ types inline across `foo.service.ts`, `foo.service.test.ts`, and the component file that consumes them.

**Why reviewers flag this:** Once types are shared across enough files, scattering them creates circular imports and forces every consumer to drill into the service file. A colocated `types.ts` keeps them discoverable.

**What to do:** When a service/feature folder has enough types to clutter the main file, move them to `<feature>/types.ts` and import from there. Standard layout: `submission_request.service.ts`, `submission_request.service.test.ts`, `types.ts`.

**Source:** PR #11017 (owen-paraform: "there are enough of these that there should probably be a types file"), PR #10959 (owen: "might be worth adding an exception flagger/types.ts file for all of this stuff now that there's so much")

---

## 71. Avoid hex literals in className strings; centralize design tokens

**Pattern:** Tailwind arbitrary-value classes with raw hex codes: `border-[#fcd5b9]`, `bg-[#fff1e6]`, `text-[#b14f1c]`.

**Why reviewers flag this:** Hex literals duplicated across components drift from the design system, can't be themed, and aren't auditable. Reviewers will repeat the same comment in follow-up rounds until they're centralized.

**What to do:** Define color tokens in the Tailwind config or a shared constants file and reference them by name. If a one-off color is truly needed, extract it to a named constant near the component.

**Source:** PR #11017 (owen-paraform: "STATUS_STYLES and all the badge inline class strings still use raw hex literals... These should be defined somewhere not inline")

---

## 72. Pass an object to functions that need extensible mode/variant args

**Pattern:** A function like `runMatchingCheck(candidate, role, true)` where the boolean toggles between "display" and "generation" modes.

**Why reviewers flag this:** Positional booleans are unreadable at the call site and don't scale when a third mode appears. An object with a discriminated mode field (`{ mode: "hmDisplay" }` vs `{ mode: "generation" }`) is self-documenting and extensible.

**What to do:** When a function has a mode/variant parameter, use an object parameter with a named field (often a union literal). Add new modes by extending the union, not by adding more positional booleans.

**Source:** PR #11088 (owen-paraform: "this should definitely take an object as arguments, and it should be possible to specify which kind of check you want to run, e.g. hmDisplay, generation, etc.")

---

## 73. Trim whitespace on all user-input string fields in Zod schemas

**Pattern:** `z.string().min(1)` on a tRPC input without `.trim()`, allowing strings like `"   "` to pass validation.

**Why reviewers flag this:** Untrimmed input lets leading/trailing whitespace into the database, breaks equality checks, and creates "invisible" duplicates. Recruiter signup and similar flows have hit this repeatedly.

**What to do:** Default to `z.string().trim().min(1)` for any string the user types. Only skip `.trim()` when leading/trailing whitespace is semantically meaningful.

**Source:** PR #11539 (michaelchang-paraform: "internal_user_id: z.string().trim().min(1).optional()... I've seen a few places like in the initial recruiter signup flow where we aren't taking whitespace into consideration")

---

## 74. Extract magic numbers shared across UI, toast, and logger into a constant

**Pattern:** Repeating the same numeric threshold (e.g., 20000) inline in the input validation, the toast error message, and the logger call.

**Why reviewers flag this:** When the threshold changes, you have to find every copy. Diverging copies create user-visible inconsistencies ("must be below 20000" vs an error logged with 30000).

**What to do:** Define the threshold once as a named constant (`MAX_MANUAL_PAYMENT_AMOUNT`) and reference it from every site. Bonus: it becomes greppable and documents intent.

**Source:** PR #11539 (michaelchang-paraform: "given magic number, seems like we can turn 20000 into a constant shared across this and the toast error as well as the logger error")

---

## 75. Use Zod `nativeEnum` for Prisma enums in tRPC input schemas

**Pattern:** `z.enum(["a", "b", "c"])` in a tRPC input when those values are already a Prisma enum.

**Why reviewers flag this:** Redefining the enum in Zod drifts from the schema. `z.nativeEnum(SomeEnum)` references the Prisma-generated enum directly, so adding a value in the schema flows through automatically.

**What to do:** For tRPC inputs that take a Prisma enum value, import the enum and use `z.nativeEnum(SomeEnum)`. Same for client-side `as const` enums.

**Source:** PR #9980 (minhpg: "use z.nativeEnum", "and add enum this looks like an enum")

---

## 76. Don't filter by status when checking existence; use `count > 0`

**Pattern:** `prisma.application.findFirst({ where: { role_id, user_id, status: { in: [...] } } })` to check "has the user ever submitted to this role."

**Why reviewers flag this:** Filtering by status when the question is "does any record exist" adds unnecessary index work and risks missing edge-case statuses. A plain `count` (or `findFirst` without the status filter) is faster and more correct.

**What to do:** For existence checks, use `prisma.x.count({ where: { ... } })` and compare `> 0`, or `findFirst` without the status filter. Only filter by status if the business question genuinely cares about it.

**Source:** PR #9980 (anthnykr: "u dont gotta filter by status since you're just checking if an application exists at all. you can just do count = prisma.application.count(...) and check count > 0"), PR #10151 (anthnykr: "don't need to filter by status to check if a submission exists")

---

## 77. Use `assert` helpers instead of silent `if (!x) continue/return`

**Pattern:** Loops with `if (!row) continue;` or `if (!user) return;` to skip rows that should always be present given the earlier logic.

**Why reviewers flag this:** A silent skip hides real bugs. If the upstream logic is correct, the value is always present, and the guard is dead. If it's incorrect, you want to know loudly, not silently drop data.

**What to do:** Use an `assert` helper (e.g., `assert(row, "row should exist for ...")`) that throws if the invariant breaks. Reserve silent skips for cases where the missing value is genuinely expected.

**Source:** PR #10284 (anthnykr: "might be good to use assert helper functions instead for row, because if `if (!row)` somehow triggers then it means some of the logic above it was wrong and you want it to fail instead of silently skip it")

---

## 78. Don't catch and rethrow tRPC errors without adding context

**Pattern:** Wrapping a service call in `try { ... } catch (e) { throw e }` or catching all errors and rethrowing as `FORBIDDEN`.

**Why reviewers flag this:** A bare rethrow is dead code. A blanket catch-and-rethrow-as-FORBIDDEN swallows non-auth errors (DB failures, validation bugs) and reports them as permission problems, making prod debugging much harder.

**What to do:** Only catch when you actually transform the error or add context. Let everything else propagate. If you need to map service errors to tRPC codes, switch on the error type, don't catch-all.

**Source:** PR #10011 (anthnykr: "nit: this part doesn't seem necessary, just rethrowing the error"), PR #10322 (anthnykr: "won't non-auth related errors also be caught by this and thrown as FORBIDDEN?")

---

## 79. Use `assertTrpcGuardianChecks` for auth, not ad-hoc checks

**Pattern:** Doing `if (!ctx.user) throw new TRPCError(...)` or hand-rolling a global-user check at the top of a procedure.

**Why reviewers flag this:** The codebase has `assertTrpcGuardianChecks({ type: "isGlobalUser" })` (and variants) that produce consistent error codes, logging, and audit trail. Ad-hoc auth checks drift from the standard and miss telemetry.

**What to do:** Use `assertTrpcGuardianChecks({ type: "..." })` at the top of any procedure that needs auth. Don't read `ctx.userId` and branch manually.

**Source:** PR #9980 (minhpg: "assertTrpcGuardianChecks({ type: \"isGlobalUser\" });"), PR #11170 (taneliang: "Would it be better to extend isGlobalUser to allow an optional memberOfTeam param instead?")

---

## 80. Map snake_case Prisma rows to camelCase at the repository boundary

**Pattern:** A raw SQL repository query returns rows with `hiring_count`, `feature_flags`, etc. and the service consumes them as-is.

**Why reviewers flag this:** Per the codebase convention (CLAUDE.md), repository results should be mapped via `mapToCamelCase<T>()` so snake_case never leaks past the data layer. Mixing conventions in service code creates inconsistency and surprises consumers.

**What to do:** Wrap raw query results with `mapToCamelCase<T>(rows)` before returning from the repository. The service and downstream layers should only ever see camelCase.

**Source:** PR #11270 (HARI-PRMD self-call: "Per CLAUDE.md, repository results should be mapped to camelCase via mapToCamelCase<T>(). This leaks hiring_count, hiring_count_max, hiring_urgency, and feature_flags as snake_case into the service layer")

---

## 81. Match PG `date_trunc('week')` with `startOf('isoWeek')` in dayjs

**Pattern:** SQL aggregates with `date_trunc('week', ...)` paired with JS bucketing via `dayjs(d).startOf('week')`.

**Why reviewers flag this:** Postgres `date_trunc('week')` returns Monday-start ISO weeks. `dayjs.startOf('week')` defaults to Sunday-start. Sunday events fall into different buckets on each side, silently shifting counts by a day.

**What to do:** When mixing SQL week truncation with JS, extend dayjs with the `isoWeek` plugin and use `startOf('isoWeek')`. Alternatively, change the SQL to Sunday-start. Pick one and apply it everywhere.

**Source:** PR #11270 (HARI-PRMD self-call: "Week-bucket mismatch: postgres date_trunc('week', ...) returns Monday-start ISO weeks, but dayjs.startOf('week') defaults to Sunday-start")

---

## 82. Parse plain date strings as UTC, not local

**Pattern:** `dayjs(targetDate).startOf('day').toISOString()` when `targetDate` is a `YYYY-MM-DD` string from a date picker.

**Why reviewers flag this:** `dayjs("2026-06-15")` parses in local time. HMs in positive UTC offsets save June 15 as `2026-06-14T15:00Z`, which renders as June 14 for negative-offset viewers. The displayed date silently shifts by a day.

**What to do:** Use `dayjs.utc(targetDate).startOf('day').toISOString()` for plain date strings. Reserve local parsing for timestamps that include a timezone.

**Source:** PR #11270 (HARI-PRMD self-call: "dayjs(targetDate).startOf('day').toISOString() parses YYYY-MM-DD as local time... Use dayjs.utc(targetDate).startOf('day').toISOString()")

---

## 83. Type Record keys with the enum, not `string`

**Pattern:** `const URGENCY_TO_DAYS: Record<string, number> = { high: 30, medium: 60 }`.

**Why reviewers flag this:** `Record<string, number>` accepts any string key, so a typo or a newly added enum variant compiles fine and silently falls back to `undefined`. Typing with the actual enum forces every case to be handled.

**What to do:** Type with the enum: `Record<hiring_urgency, number>`. Add `satisfies` or `Record<Enum, T>` so missing variants become compile errors.

**Source:** PR #11270 (HARI-PRMD self-call: "URGENCY_TO_DAYS uses Record<string, number>, so a typo or new hiring_urgency variant won't be caught at compile time... Type as Record<hiring_urgency, number>")

---

## 84. Validate date inputs with Zod refinements against today

**Pattern:** A Zod schema like `target_hire_date: z.string()` that only validates format, not whether the date is in the past.

**Why reviewers flag this:** Stale forms, replay attacks, and direct API calls can submit past dates. Downstream math (weeks remaining, weekly target) breaks when the denominator clamps to 1 and the whole goal collapses into one week.

**What to do:** Add a `.refine(d => dayjs(d).isAfter(dayjs()), { message: "must be in the future" })` to date inputs that represent future goals. Validate semantically, not just structurally.

**Source:** PR #11270 (HARI-PRMD self-call: "target_hire_date only validates the string format. A stale form or direct API call can submit a past date... Add a Zod refinement to reject dates before today")

---

## 85. Add indexes for columns used in raw query filters

**Pattern:** A raw SQL query filtering by `role_id` against `application_audit`, which is only indexed on `[application_id, created_at]`.

**Why reviewers flag this:** Without a covering index, the query scans the full table. For a dashboard query that runs on every page load, this gets expensive fast and won't show up until production scale.

**What to do:** When writing or modifying raw SQL (or even Prisma queries), check the filtered columns against `@@index` definitions on the model. Add `@@index([role_id, furthest_stage_reached])` (or similar) if the column isn't covered. Pair the new index with the migration.

**Source:** PR #11270 (HARI-PRMD self-call: "application_audit only indexes [application_id, created_at] no index on role_id... Add @@index([role_id, furthest_stage_reached]) on application_audit")

---

## 86. Drop unused return fields from utility helpers

**Pattern:** A `STATUS_TONE` lookup that returns `{ headline, barClass, chipClass }` but the caller only reads `headline`.

**Why reviewers flag this:** Unused fields suggest the helper is over-designed and confuse future readers about which fields are actually load-bearing. They also accumulate as code evolves and become dead weight.

**What to do:** Trim helper return shapes to what's actually used. If a future caller needs more fields, add them at that point.

**Source:** PR #11270 (HARI-PRMD self-call: "STATUS_TONE returns barClass and chipClass but only headline is read. paceTone returns text and label but only fill is used. Drop the unused fields")

---

## 87. Don't disable buttons for missing input; show an error toast on click

**Pattern:** Disabling a submit/post button until all required fields are filled.

**Why reviewers flag this:** Disabled buttons give users no feedback about what's missing, especially on long forms. The Paraform UX convention is to keep the button enabled and toast a specific error on click ("Add a note to continue").

**What to do:** Keep the button enabled, validate on click, and surface the missing field by name in a toast. Reserve disabled states for genuinely impossible actions (no permission, no data loaded yet).

**Source:** PR #11198 (anthnykr: "for better UX we usually don't wanna disable buttons due to missing inputs, it's better to show an error toast saying what's missing")

---

## 88. Convert newlines to `<br>` after `escapeHtmlText` for multi-line HTML

**Pattern:** Passing multi-line `TextArea` content through `escapeHtmlText(body)` and rendering as HTML without converting `\n` to `<br>`.

**Why reviewers flag this:** Raw `\n` collapses to whitespace in HTML, so multi-line notes render as one line. The codebase already has `formatReminderBody` doing this correctly with `.replace(/\n/g, "<br>")` after escaping.

**What to do:** For any text destined for HTML rendering, escape first, then replace newlines with `<br>`. Use or mirror `formatReminderBody`'s pattern.

**Source:** PR #11198 (Cursor bugbot via anthnykr, kept as a legitimate flag: "notesBody from the multi-line TextArea is passed through escapeHtmlText() but newlines are not converted to <br> tags... The sibling formatReminderBody function correctly applies .replace(/\n/g, '<br>')")

---

## 89. Use `RecruiterImage` (and similar typed image components) instead of generic image rendering

**Pattern:** Rendering a recruiter avatar with a raw `<img src={imageSrc} />` or a generic `Avatar` component.

**Why reviewers flag this:** The codebase has typed image components (`RecruiterImage`, etc.) that handle fallbacks, validation, sizing, and rounded styling consistently. Generic `<img>` misses those defaults and produces visual drift.

**What to do:** When rendering a known entity (recruiter, candidate, role, company), use the dedicated image component. Reserve raw `<img>` for genuinely arbitrary images.

**Source:** PR #9946 (anthnykr: "u can look into the `RecruiterImage` component here instead"), PR #10232 (anthnykr: "if imageSrc is always recruiter this could probs be RecruiterImage to simplify it")

---

## 90. Use TipTap for rich text input to recruiters/HMs

**Pattern:** Building a custom textarea or markdown box for a message that will be sent to recruiters or hiring managers, then manually converting to HTML.

**Why reviewers flag this:** Recruiter and HM messages flow through TipTap, which already produces the markdown/HTML the downstream pipeline expects. Rolling your own means duplicating escaping, formatting, and toolbar logic and getting it subtly different.

**What to do:** Use the TipTap component for any composer surface that targets recruiters or HMs. Skip the manual HTML conversion at the call site.

**Source:** PR #9980 (anthnykr: "this should be a TipTap component which already creates the markdown, so then in sendRecruiterBoostMessage you dont need to do the const messageHtml thing"), PR #9946 (anthnykr: "we use markdown via a markdown editor called TipTap for messages to recruiters")

---

## 91. Use Slack helper option defaults; expose only meaningful overrides

**Pattern:** A Slack helper signature with options like `ignore_user_stored_slack_channel`, `skip_existing_channel_lookup_by_name`, `persist_slack_channel_on_user`, `retry_on_channel_name_taken`.

**Why reviewers flag this:** Most of those should be the default behavior (use existing + store, always retry on taken name). Exposing them as toggles invites callers to misuse them, and the parameter list balloons. Rename anything that IS an override so its purpose is obvious (e.g., `customSlackUserIdsToInvite` reads as an override of the default invite list).

**What to do:** Bake sensible defaults into the helper. Only expose flags that represent a real, intentional deviation. Rename override params with a `custom*` or `override*` prefix.

**Source:** PR #10284 (anthnykr: "i don't think a few of these are needed... the logic should be using existing + storing when possible. retry_on_channel_name_taken should always do this. slack_user_ids_to_invite rename to customSlackUserIdsToInvite to make it clear that it's an override")

---

## 92. Use `getSlackErrorMessage` for Slack API error handling

**Pattern:** Custom string parsing or generic error stringification when a Slack API call fails inside a service.

**Why reviewers flag this:** There's a shared `getSlackErrorMessage` helper that normalizes the various error shapes Slack returns. Reimplementing it inline yields inconsistent error logs across services.

**What to do:** For any Slack call in a try/catch, pass the caught error to `getSlackErrorMessage(err)` and log/return that. Don't inline `err?.data?.error || err?.message`.

**Source:** PR #10284 (anthnykr: "for this (and if there's other error handling in the PR) hari made a getSlackErrorMessage function to use")

---

## 93. Don't fire-and-forget critical setup flows; keep them sync and visible

**Pattern:** Wrapping candidate enrichment, resume parsing, or initial data ingestion in a fire-and-forget async call after creating the candidate record.

**Why reviewers flag this:** If the background job fails, the user sees a "created" success but the candidate is in a partial state. There's no error surface and no retry signal. For setup that's required for the entity to function, the failure should fail the create.

**What to do:** Keep critical setup synchronous so a failure blocks (and surfaces) the create. Use background jobs for genuinely optional enrichment, and add observable error tracking when you do.

**Source:** PR #10873 (naveengovind: "should make it fail the creation if the enrichment or resume parse fails so the user also knows there was a issue with ingesting rather than having a half created candidate", "wondering if this should still be a sync job rather than an async fire and forget")

---

## 94. Set `thinking: minimal` for short LLM tasks prone to looping

**Pattern:** Calling an LLM with default thinking config for a small classification or extraction task.

**Why reviewers flag this:** Some short tasks have caused the model to "think forever and get stuck" in production. For simple classification, `thinking: minimal` is the safer default.

**What to do:** For short, well-bounded LLM calls (classify, extract, yes/no), pass `thinking: "minimal"` (or the equivalent). Reserve higher thinking budgets for genuinely open-ended reasoning.

**Source:** PR #10873 (naveengovind: "should set thinking to minimal here since we had those issues before it would just think forever and get stuck should be a simple task")

---

## 95. Squash generated/incidental migration files before merge

**Pattern:** A PR containing multiple migration files like `20260413235355_npx_prisma_generate` that were created during local iteration.

**Why reviewers flag this:** Spurious migrations pollute the history, slow down `prisma migrate deploy`, and confuse rollback. The intended change should land as one migration.

**What to do:** Before requesting review, squash incidental migrations into the single intended migration. Delete any that came from running `prisma generate` or playing with schema locally.

**Source:** PR #10353 (owen-paraform: "can you just squash these lmao")

---

## 96. Avoid `LIKE` / `startsWith` on large tables without indexes

**Pattern:** `prisma.linkedin_connections.findMany({ where: { url: { startsWith: "..." } } })` on a table with millions of rows.

**Why reviewers flag this:** `startsWith` translates to `LIKE 'prefix%'`, which only uses an index if the column has a `text_pattern_ops` index. On large tables it does a full scan and times out.

**What to do:** Avoid `startsWith` on large tables. If a prefix lookup is genuinely needed, add a `text_pattern_ops` index or store the prefix as a separate column. Otherwise restructure the query (e.g., exact match on a normalized column).

**Source:** PR #11176 (minhpg: "use startWith this will likely be very slow")

---

## 97. Don't suppress new lint rules; fix the underlying pattern

**Pattern:** Adding an `eslint-disable-next-line` for a newly introduced lint rule (e.g., the design-system button rule) rather than fixing the offending code.

**Why reviewers flag this:** Suppression files become a dumping ground. The rule was introduced to enforce a real convention; each new suppression weakens it. The eslint config should be shrinking, not growing.

**What to do:** When you encounter a new lint violation, fix the code (use the design system component, refactor the import, etc.). Only suppress when there's a documented, exceptional reason, and remove from the suppression list when possible.

**Source:** PR #11435 (taneliang: "I only added this line when introducing this lint rule so that I didn't have to fix every place that we did this. If we're introducing a new button we shouldn't suppress the lint rule"), PR #10615 (anthnykr: "we don't wanna be adding to this list - should be removing only")

---

## 98. Don't manually convert timezones when querying recent UTC data

**Pattern:** Inside a router/service, converting "now" to PST before computing `thirty days ago` for a DB query against a timestamp stored in UTC.

**Why reviewers flag this:** Postgres stores timestamps as UTC by default. "30 days ago" computed in UTC equals "30 days ago" computed in PST for the purpose of an inequality filter. The conversion adds complexity without changing the result.

**What to do:** For relative-time DB filters, do the math in UTC. Reserve timezone conversion for user-facing display or when bucketing by local-day boundaries.

**Source:** PR #11350 (anthnykr: "don't need to do timezone conversion. the stored date is already converted by the database to UTC by default, so querying thirty days ago will already work perfectly")

---

## 99. Use FontAwesome icons from the existing centralized set

**Pattern:** Inlining a new SVG icon component or pulling from a random icon library for a one-off UI need.

**Why reviewers flag this:** The team standardizes on a defined FontAwesome set. One-off SVGs drift visually, bloat the bundle, and bypass the central icon system.

**What to do:** Use the existing FontAwesome icons. If you genuinely need a new icon, add it to the central set rather than inlining at the call site. Coordinate with design (kinnara10, taneliang) on additions.

**Source:** PR #10017 (batuhan-akcay-paraform: "we should use fontawesome icons that we have access to and not create new icons", "ideally we should have a set list of icons defined somewhere else in code in a centralized place")

---

## 100. Reference Prisma schema types via `Pick<Model, ...>` instead of redefining

**Pattern:** Defining `type OnboardingRoleRow = { id: string; name: string; description: string; ... }` by hand to type a raw query result.

**Why reviewers flag this:** Hand-rolled row types drift when columns are renamed or removed, and you lose compile-time errors that would otherwise catch a schema change. `Pick<Role, "id" | "name" | ...>` stays in sync with the schema.

**What to do:** When typing a raw query subset, import the Prisma-generated model and `Pick` the columns you select. Same applies to `Omit` for excluded columns.

**Source:** PR #10006 (ruibinch: "Preferable to reference the existing schema types instead of defining the raw types again if possible so that any potential schema changes will throw type errors. import { Role } from \"@/lib/generated/prisma/client\"; export type OnboardingRoleRow = Pick<Role, ...>")

---

## 101. Centralize related constants instead of cloning them per cron/service

**Pattern:** Defining `CANDIDATE_EXPIRY_DAYS = 40` in one cron and a separate `AGENCY_CANDIDATE_EXPIRY_DAYS = 40` in another.

**Why reviewers flag this:** When the business rule changes (e.g., expire after 30 days), you have to find every copy. Two crons drifting out of sync silently produce inconsistent product behavior.

**What to do:** Define shared business rules once in a central constants file and import from both consumers. When two values are intentionally separate, name them to make the distinction visible.

**Source:** PR #10014 (naveengovind: "can you make it inherit the constant for expiring regular candidates for inactivity should also be set to 40 would like to set both of these in the same place")

---

## 102. Use `useUtils` mutation invalidation that doesn't clobber optimistic state

**Pattern:** An optimistic update on a Kanban drag, followed by an `invalidate()` in `onSettled` that refetches before a second drag can settle.

**Why reviewers flag this:** If `invalidate` re-fetches synchronously, it overwrites the second optimistic update's state, which feels laggy and undoes the optimism. For chained drags, you want the backend write to be silent on success.

**What to do:** For rapid-fire optimistic UIs, skip the post-write invalidate (or scope it tighter). Trust the optimistic state until the user navigates away, then refetch.

**Source:** PR #10767 (anthnykr: "this kinda defeats the purpose of having optimistic updates if further drags are blocked by the backend update. a random idea i have is making the backend update not invalidate the frontend so that it doesnt overwrite the second optimistic update's state")

---

## 103. Don't build computed UI props the parent can derive itself

**Pattern:** A child component receiving derived state (`isDisabled`, `reasonText`, `boostDisabledAt`) as 4 separate props from the parent.

**Why reviewers flag this:** If the child can compute these from the entity it already receives, the parent-child contract bloats and the props can disagree with the source. Computed state should live where it's used.

**What to do:** Pass the entity (or minimal data) to the child and compute derived display state inside the child via a `const` (no need for `useMemo` on cheap math). Reserve props for genuinely external data.

**Source:** PR #10063 (anthnykr: "this doesn't seem like it needs to be passed in as a prop it can just be calculated in the component"), PR #11370 (anthnykr: "can this be done in the page rather than adding a new prop here? since it's only used 1 time in the entire /new/ dashboard")

---

## 104. Watch for long Prisma transactions on user-facing endpoints

**Pattern:** Wrapping a multi-step flow (create, update, send email, audit) in a single `prisma.$transaction(...)` on a route the user hits synchronously.

**Why reviewers flag this:** Transactions hold locks for their full duration. If any step is slow (an external call, a queue enqueue), the lock window grows and other requests stall. There's also a transaction timeout to consider.

**What to do:** Keep transaction bodies tight: only the DB writes that must be atomic. Move emails, queue pushes, Slack notifications, etc. outside the transaction. Bump the timeout only when the work genuinely needs it.

**Source:** PR #11357 (anthnykr: "this seems like a decently long transaction so just verifying there's no time out risk. either increasing transaction timeout or moving unnecessary stuff out of it could be good")

---

## 105. Keep JSX for rendering; move computation out of the render tree

**Pattern:** An IIFE (`(() => { ... })()`) or chained filter/map/spread expression embedded inline inside JSX props (e.g., `options={(() => { const techGroup = ...; return ...; })()}`).

**Why reviewers flag this:** JSX is harder to scan when the markup is interleaved with branching logic and array construction. The component reads as one giant render rather than "compute, then render."

**What to do:** Hoist the computation to a `const` at the top of the component, or extract it into a helper in an adjacent `utils.ts`. If the parent component is already large, the right follow-up is to split it into smaller components so the JSX stays focused on layout.

**Source:** PR #11882 (inni-e: "Ideally JSX shouldn't be computing this much, and should be computed in a library function or at the top of the component... Would be good to have a follow up PR to break down this component into smaller ones and keep JSX responsible for rendering w/o any compute")

---

## 106. Spreading complementary filters back into one array is a no-op (or a bug)

**Pattern:** `[...ARR.filter(x => x.label !== "Tech"), ...ARR.filter(x => x.label === "Tech")]` — two complementary filters reassembled into one list.

**Why reviewers flag this:** If the goal is reordering, this only works when "Tech" is at a specific position in `ARR`; otherwise it's just `ARR` reshuffled in a non-obvious way. Often it ends up logically equivalent to the original array, making the code dead weight. Either way, the intent is hidden.

**What to do:** If you're reordering, do it explicitly — pull the target item out and place it where you want (`const tech = ARR.find(...); const rest = ARR.filter(...); return legalOnly ? [...rest, tech] : [tech, ...rest]`). If the two halves are unrelated, give each its own named variable instead of spreading.

**Source:** PR #11882 (inni-e: "looks sus, from looking at the calculation it looks like this array just ends up containing `GROUPED_ROLE_TYPE_OPTIONS` since you're spreading complementary filters into the same array")

---

## 107. When a `.map()` callback grows, extract a component (and use a lookup object for branching)

**Pattern:** A `.map()` inside JSX where the callback body spans 20+ lines, contains nested `if`/ternary chains keyed on a discriminator field (e.g., `field.snapshotKey === "practiceAreaPreferences" ? ... : ...`), and accesses the same property repeatedly.

**Why reviewers flag this:** Long map callbacks blur the boundary between "iterating" and "rendering." Repeated discriminator checks compound: each call site that adds a new case has to remember to update every conditional. Repeated `field.snapshotKey` access also signals the conditional is doing key-based dispatch in disguise.

**What to do:** Two complementary moves: (1) lift the iteration body into its own component (`<PreferenceField field={field} ... />`); (2) replace the if/ternary dispatch with a single config object keyed by the discriminator:

```ts
const fieldConfig = {
  practiceAreaPreferences: { value: ..., onChange: ... },
  firmSegmentPreferences: { value: ..., onChange: ... },
} as const;

const { value, onChange } = fieldConfig[field.snapshotKey];
```

Adding a new case becomes a one-line config edit instead of edits at every branch.

**Source:** PR #11882 (inni-e: "Ideally when a `.map()` function starts to look like this usually is a good indicator to move to it's own component... another consideration to half the access of `field.snapshotKey` twice in each loop iteration is to use this pattern... Lessens the logic inside the map function")

---

## 108. Extract repeated `value/label` object shapes into a `toOption` helper

**Pattern:** The same `value => ({ value: LABEL[value], label: LABEL[value] })` (or similar `{label, value}` shape) appearing in multiple `.map(...)` calls within one file.

**Why reviewers flag this:** The mapping is identical, just repeated. A reader has to verify each instance is the same and a future edit (e.g., adding a `key` field) means hunting down every copy. It also bloats `.map()` bodies that could be one-liners.

**What to do:** Define a small named helper at the top of the file:

```ts
const toOption = (v: ROLE_TYPE) => ({ value: ROLE_TYPE_TO_LABEL[v], label: ROLE_TYPE_TO_LABEL[v] });
```

Then `options: Array.from(vc.roleTypes).map(toOption)` reads as data plumbing instead of object construction. Also: prefer `Set` over `Array` when the upstream data may contain duplicates you want to dedupe.

**Source:** PR #11882 (inni-e: "could further abstract the map function to reduce LOC into smth like a `toOption` function... Also consider using a Set() instead to deduplicate")

---

## 109. `useMemo` derived data that's recomputed every render with non-trivial work

**Pattern:** A top-of-component `const` that builds arrays through filter + map + spread + `Array.from(set)` and is recomputed on every render, even when the inputs rarely change.

**Why reviewers flag this:** Unlike trivial computations (see #56), array construction over `VERTICAL_REGISTRY` with nested `.filter().map()` and set conversion is the kind of work that does add up — especially in a component that re-renders on every keystroke. The output is also referentially unstable, which breaks downstream memoization.

**What to do:** Wrap in `useMemo` with the actual dependencies (e.g., `[legalOnly]`). The bar is: non-trivial work OR reference equality matters for a child / dependency array. If neither applies, a plain `const` is still right (#56).

**Source:** PR #11882 (inni-e: "Use `useMemo()` for this since this is getting calculated rn on every render")

---

## 110. Design the type so the lookup doesn't need a cast

**Pattern:** `verticalFieldConfig[field.snapshotKey as keyof typeof verticalFieldConfig]` — a type assertion bridging a wider union (`field.snapshotKey: string`) to a narrower lookup key.

**Why reviewers flag this:** The cast says "trust me, this key is in the config," but offers no guarantee. If a new `snapshotKey` is added to the field type without a matching config entry, TypeScript stays silent and you get an `undefined` at runtime.

**What to do:** Narrow the source instead of widening the lookup. Type `snapshotKey` as `keyof typeof verticalFieldConfig` at its declaration, or model the config as a `Record<SnapshotKey, ...>` so TS forces exhaustive coverage. Failing that, validate the key at the boundary (`if (!(key in config)) return null`) so the runtime failure mode is explicit.

**Source:** PR #11882 (inni-e: "wondering if there's a cleaner way to handle this rather than typecasting it")

---

## Pre-Submit Checklist

Before requesting review, scan your diff for:

### Architecture & Structure
- [ ] Repository methods in the wrong domain file (query table != file name)
- [ ] Direct Prisma calls outside repository files
- [ ] Raw fetch() where tRPC could be used
- [ ] Direct SQL against the database instead of Prisma migrations
- [ ] Reusable mappings in frontend that belong in backend constants
- [ ] Business logic in routers that should be in services
- [ ] Raw SQL that could be Prisma query builder instead
- [ ] Mixed concerns in validation/eligibility functions - keep each check focused
- [ ] Prop-drilling mutate/refetch functions - use SWR mutate or useUtils instead
- [ ] tRPC errors thrown from services (should be returned as status, thrown in router)
- [ ] Auth checks buried in services (belong in the tRPC procedure)
- [ ] New endpoint for data that fits an existing response - extend instead
- [ ] Prisma migration shipped together with code that uses it - split into two PRs
- [ ] New services written as functions/objects - use classes

### Schema Design
- [ ] Missing `@relation` on foreign key columns
- [ ] Missing `@@index` on foreign key columns
- [ ] Unclear column names - would a new developer understand this?
- [ ] `default: true` on new columns - safe for existing rows?
- [ ] Redundant columns (can existing columns serve the same purpose?)
- [ ] String columns that should be enums
- [ ] Linking to settings tables instead of primary entities

### Type Safety
- [ ] `as const` on Prisma objects - should it be `satisfies Prisma.*`?
- [ ] Unnecessary `as Prisma.*WhereInput` type assertions - try removing them
- [ ] String literals for fixed value sets - should be enums/constants
- [ ] Manual prop types that should use `RouterOutputs`/`RouterInputs` from tRPC
- [ ] `findFirst` where `findUnique` is correct (querying by unique/PK fields)
- [ ] Fallbacks (`?? 0`, `?? ""`, `!`) on Prisma fields that are non-nullable
- [ ] `switch` over a union without `assertNever` default for exhaustiveness
- [ ] Evolving JSON column without `lib/versioned/` system

### Code Quality
- [ ] Duplicated strings/logic across 3+ files - extract helper
- [ ] Formatting logic that duplicates an existing utility
- [ ] New repo methods/utilities that might already exist - search first
- [ ] Thin wrapper functions that just delegate to another function
- [ ] Nested ternaries (2+ levels) - convert to if/else
- [ ] Hardcoded ID lists when shared constants exist
- [ ] Dead/unused code left after refactoring - delete it
- [ ] Manual switch/mapping that could be data-driven (list + indexOf)
- [ ] Custom/legacy UI components instead of design system (`<Button>`, `<Input>`)
- [ ] Multiple primary buttons on one screen - use secondary/destructive variants
- [ ] Redundant null/existence checks already handled by called functions
- [ ] Not following established patterns for common operations (check how others do it)
- [ ] AI-generated comments (Cursor, Copilot) left in code - remove them
- [ ] Functions passed directly as callbacks (`.map(fn)`) - wrap in arrow function
- [ ] Fragile string matching for conditional logic - pass values as params instead
- [ ] Functions with 4+ positional params - switch to object param
- [ ] Frontend filter/sort/count over arrays that backend could return ready-made
- [ ] `useMemo` around cheap computations - just use a const
- [ ] tRPC client error types (`TRPCClientError`) imported into frontend
- [ ] Inline reimplementation of `capitalize`/`pluralize`/`parseFirstName`/`validHttpUrl` - search utils first
- [ ] Inline IIFE or long compute embedded in JSX props - hoist to a `const` or helper
- [ ] Complementary `arr.filter(...)` spreads reassembled into one array - usually a no-op or a hidden reorder bug
- [ ] `.map()` callback with 20+ lines or nested discriminator branching - extract a component and dispatch via a config object
- [ ] Repeated `{ value, label }` object shapes across `.map()` calls - extract a `toOption` helper
- [ ] Non-trivial filter/map/Array.from chains recomputed every render - wrap in `useMemo` (still skip for cheap math, see #56)
- [ ] `as keyof typeof ...` cast on a lookup key - narrow the source type or model the config as a `Record<Key, ...>`

### Naming & Readability
- [ ] Variable names that don't match the code's actual behavior
- [ ] Complex algorithms with no explanatory comments
- [ ] Deeply nested conditionals that could use early returns
- [ ] New variables using snake_case - use camelCase instead

### Performance & Logging
- [ ] Unnecessary transactions wrapping read-only or single-write operations
- [ ] Truncated logs in low-frequency jobs - log the full list instead
- [ ] `Promise.all` on unbounded arrays - chunk into batches of ~5
- [ ] Sequential awaits on independent operations - use `Promise.all`
- [ ] Expensive queries before cheap guard checks - reorder cheapest first
- [ ] Over-allocated LLM token limits for simple responses
- [ ] `take` without `orderBy` - results are non-deterministic
- [ ] `updated_at` used as a proxy for a state-change timestamp - use audit table
- [ ] Manual timezone conversion in cron handler - set timezone in cron config

### PR Hygiene
- [ ] Unrelated changes mixed in (eslint, refactors) - split into separate PRs
- [ ] UI changes with no screenshot/recording in PR description
- [ ] Shared component modified without checking all usages
- [ ] Scripts/backfills missing error handling and safety guards
- [ ] Benchmark/test settings that don't match production

### tRPC & React Query
- [ ] Manual state management for mutation side effects - use onSuccess/onError/onSettled instead
- [ ] Data-presence check (`!data`) used as loading state - use `isLoading`/`isPending`
- [ ] Zod input strings missing `.trim()` - whitespace will leak into the DB
- [ ] Auth handled by hand-rolled `ctx.user` checks - use `assertTrpcGuardianChecks` instead
- [ ] Hand-coded Zod enum for a Prisma enum - use `z.nativeEnum(...)`
- [ ] Bare `try { ... } catch (e) { throw e }` or catch-all-as-FORBIDDEN - remove or narrow
- [ ] `findFirst` against a composite unique index - use `findUnique` with the composite key
- [ ] Existence check filtered by status - use plain `count > 0` or unfiltered `findFirst`
- [ ] `Promise.all` invalidation that clobbers rapid optimistic updates - skip invalidate or scope tighter

### Domain Conventions
- [ ] Vercel `@ai-sdk/anthropic` import - go through `para-ai` service / Bedrock
- [ ] Native `Date` arithmetic - use dayjs (or `dayjs.utc` for plain date strings)
- [ ] Legacy feature flag system - use `guardian.isOn("flag", { companyId })`
- [ ] Synchronous `localStorage` reads in render - use `useClientState`
- [ ] Custom Slack error stringification - use `getSlackErrorMessage`
- [ ] Custom recruiter/HM rich text input - use TipTap
- [ ] Custom recruiter avatar rendering - use `RecruiterImage`
- [ ] Inline SVG icons - use the FontAwesome set
- [ ] Frontend-only util added to shared `lib/utils/utils.ts` - move to client utils
- [ ] Hand-typed query row shape - use `Pick<PrismaModel, ...>`
- [ ] Raw SQL repository result returned as snake_case - run through `mapToCamelCase<T>()`

### Schema, Migrations & Indexes
- [ ] Incidental migration files from `prisma generate` - squash before review
- [ ] Raw SQL filter column without a covering `@@index`
- [ ] `LIKE`/`startsWith` on a large table without a `text_pattern_ops` index
- [ ] `eslint-disable` added for a newly introduced rule - fix the code instead

### Time, Dates & Timezones
- [ ] PG `date_trunc('week')` paired with dayjs `startOf('week')` - use `startOf('isoWeek')`
- [ ] `dayjs(yyyymmdd)` for date-only strings - use `dayjs.utc(...)`
- [ ] Manual UTC-to-PST conversion for a relative-time DB filter - do the math in UTC
- [ ] Zod date schema missing a `.refine` against today - past dates can break downstream math

### UX & Display Polish
- [ ] Disabled submit/post button for missing input - keep enabled, toast the missing field
- [ ] Multi-line text rendered as HTML without `\n` -> `<br>` after escape
- [ ] Hex literals in className strings - use design tokens / shared constants
- [ ] Magic numbers duplicated across UI, toast, and logger - extract a constant
- [ ] Critical setup (enrichment, resume parse) done fire-and-forget - keep sync so failures surface
- [ ] Short LLM tasks with default thinking - set `thinking: minimal` to avoid loops
- [ ] Bare rethrows / no-op try/catch - remove
- [ ] Silent `if (!x) continue` on values that should always exist - use `assert(...)`
- [ ] Helper return shape with fields no caller reads - trim it
- [ ] Long Prisma `$transaction` blocks holding locks across external calls - shrink the body
- [ ] Sister business-rule constants duplicated across crons - centralize

---

## Risk Assessment (final step)

After completing the checklist above, run the diff through this risk assessment — the same framework used by the CI bot in `.github/workflows/risk_assessment.yml`. If the result is above **Low**, identify what's driving the score up and suggest concrete code changes to bring it down.

### Step 1: Determine Likelihood (1–5)

How likely is this change to cause a bug or unintended behavior?

| Score | Level | Description |
|-------|-------|-------------|
| 1 | Very unlikely | No realistic way this breaks anything. Mechanical, purely additive, or fully constrained by types. |
| 2 | Unlikely | Straightforward change following established patterns. Simple logic with few branches. |
| 3 | Somewhat likely | Introduces or modifies conditional logic, business rules, or data transformations. Some implicit dependencies or edge cases. |
| 4 | Likely | Complex logic with multiple interacting code paths, state transitions, or race conditions. |
| 5 | Very likely | Highly complex with subtle correctness requirements. Concurrent/distributed logic or shared abstractions where callers may silently break. |

Consider: Does it modify existing behavior or add new? How complex is the logic? Are there implicit dependencies? Does the type system catch mistakes? Does it follow established patterns?

Do NOT treat diff size or absence of tests as likelihood signals.

### Step 2: Determine Impact (1–5)

If something goes wrong in production, what are the actual consequences? Reason about what would actually go wrong, not which files are touched.

| Score | Level | Description |
|-------|-------|-------------|
| 1 | Very low | Cosmetic issue, no user-facing or operational impact. |
| 2 | Low | Minor degradation but primary functions still work. Narrow set of users/workflows affected. |
| 3 | Medium | Significant degradation of a user-facing capability. Moderate financial or reputational damage. |
| 4 | High | Loss of a primary function, major financial loss, data integrity issues, or regulatory exposure. |
| 5 | Very high | Widespread data breach, large-scale financial loss, complete service outage, or existential legal/regulatory consequences. |

Ask: Could this cause financial loss? Expose sensitive data? Corrupt or lose data? How many users affected? How reversible is the damage? Could it break a critical workflow?

### Step 3: Calculate Risk Level

Multiply Likelihood × Impact:

| Risk Level | Score Range | Meaning |
|------------|-------------|---------|
| **Low** | 1–4 | Safe to merge. |
| **Medium** | 5–12 | Benefits from human review. |
| **High** | 13–20 | Requires human review. |
| **Critical** | 21–25 | Requires senior human review. |

### Step 4: If above Low, reduce it

For each risk factor driving the score above Low, suggest a **concrete code change** that would lower the Likelihood or Impact. Examples:

- **Auth before data fetch** → split the query so auth runs first, no data is loaded for unauthorized users
- **PII sent to external API** → confirm the pattern is already established in the codebase (cite existing examples) to lower novelty-based likelihood
- **No rate limiting** → add `staleTime`, query key invalidation, or a server-side cache to cap LLM spend
- **Missing input validation** → add a Zod filter or type guard to prevent malformed data reaching the LLM
- **Unfiltered system messages** → add a `type` filter on the DB query to exclude boilerplate

Present the assessment as:

```
**Risk Level: <Level>** (Likelihood: <score>/<name>, Impact: <score>/<name>, Score: <N>)

**What changed:** <1-2 sentence summary>

**Assessment:**
- <Risk factor and why>
- <Mitigating factor>

**To reduce to Low:**
- <Concrete change 1>
- <Concrete change 2>
```

If already Low: `**Risk Level: Low** — No action needed.`
