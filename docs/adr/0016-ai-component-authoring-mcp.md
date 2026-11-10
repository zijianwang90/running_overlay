# ADR 0016: AI Component Authoring Through a Local MCP Server

Date: 2026-11-09

## Status

Accepted by the maintainer. Requires human review: it adds an external
integration surface (MCP) and a privacy boundary for AI previews.

## Context

Components are declarative JSON (ADR 0013), and the authoring guide, skill and
CLI already let an AI author one inside the repository. App users have no such
path: they would need the repository docs, a terminal CLI and a manual import
for every iteration, and the AI cannot see what it drew.

Options considered:

1. Call an LLM API from the app. This needs API keys, billing, a chat UI and
   privacy disclosures, and it duplicates the AI tools users already have.
2. Copy a prompt into any chat app and paste the JSON back. This has no setup,
   but the model works blind and each iteration is manual.
3. Ship a local MCP server that existing clients (Claude Code, Codex, Claude
   Desktop) start, and show its output live in the app.

## Decision

1. The app executable doubles as an MCP server: `RunningOverlay --mcp` speaks
   newline-delimited JSON-RPC 2.0 over stdio and creates no window. There is no
   separate helper binary, socket or port.
2. Tools: bundled authoring guides (workflow, guide, specification, schema),
   examples, metric ids, validation with JSON-pointer diagnostics, PNG previews
   from the app's own renderer, and saving, listing and reading drafts.
3. Drafts live in `Application Support/RunningOverlay/ComponentDrafts`. The
   server and the app are the same signed executable, so a sandboxed build
   resolves the same container path in both processes without file pickers,
   app groups or extra entitlements.
4. The app polls the drafts folder once per second and lists drafts under
   Overlay Pool › Components › Drafts. Adding a draft embeds its definition
   like an import, so a project never depends on the folder. When a draft file
   changes while the app runs, every non-bundled instance with the same
   component id switches to the new definition as one undo point. Parameter
   values and placement are kept. Changes made while the app was closed are
   not applied to existing instances.
5. Previews never use the user's projects or activities. They render a
   synthetic 12-minute interval workout with a fictional route and fixed
   sample weather, and the server makes no network requests.
6. The Overlay Pool's Components tab offers "Create with AI…", a sheet that
   gives a one-time connection command per client and an example request. For
   chat apps without MCP it copies a self-contained authoring prompt and saves
   pasted JSON as a draft.
7. Bundled guide copies under `Resources/Authoring/` must match the canonical
   documents in `docs/overlay-components/`; a test enforces this, so the server
   always describes the protocol the build validates.

## Consequences

- Authoring works with whichever AI client the user already has, and the model
  can iterate on a rendered image before saving.
- The MCP tools are a compatibility surface: renaming or removing a tool
  breaks client prompts and configurations.
- Draft ids reuse the component id, so editing a draft whose id matches an
  imported component also updates that component's instances. Ids in the
  reserved `studio.` namespace are refused.
- Previews show synthetic values, not the user's data. Checking a component
  against a real activity still happens in the app.
- Reading live project data (for example the playhead's values) from the AI is
  out of scope. It would need communication with the running app and explicit
  user consent.

## References

- [ADR 0013](0013-declarative-overlay-components.md)
- [Authoring Overlay Components](../overlay-components/authoring.md)
