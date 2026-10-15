---
name: review-request
description: Post a Slack review request for a Jira ticket.
argument-hint: "<TICKET>"
disable-model-invocation: true
---

# Review request

Post a polite Slack review request for the PRs on a Jira ticket. One channel message per destination that has selected PRs. Confirm every message with the user before sending.

## Process

### 1. Resolve the ticket

Take the ticket key from the user (e.g. `EDP-2875`). If missing, ask for it (one question).

Read the issue with the Jira MCP (`getJiraIssue`). Build the Jira browse URL: `https://ipsycorp.atlassian.net/browse/<KEY>`.

Write a **one-sentence** summary from the ticket title/description — what changed and why a reviewer should care. No multi-sentence blurbs.

**Done when:** you have the key, browse URL, and one-sentence summary.

### 2. Collect every linked PR

Find all GitHub PRs for the ticket. Exhaust every source below; de-dupe by URL:

1. Jira development/remote links and issue description/comments (PR URLs).
2. Atlassian graph/development tools if available on the issue.
3. `gh search prs "<KEY>" --owner myglam --limit 50` (and follow with `gh pr view` if you need title/repo).

For each PR record: repo name, number, title, URL, state. Skip closed/merged only if the user asked for open PRs; otherwise list them and mark state so the user can choose.

**Done when:** every discovered PR is listed with repo + URL, or you confirmed there are none.

### 3. Select PRs to post

Ask which PRs to include as a **set pick** (`multiSelect`, via the `questions` skill):

- One option per discovered PR — label `repo #n`, description = title + state.
- The checked set is the answer — leave recommendation unmarked.

If none were found, stop and say so.

If any selected PR is in `account`, ask which areas apply as a set pick (`multiSelect`): Dashboard, Subscriptions, Payment/Address, Order history. Map those answers through [mfe-owners.md](mfe-owners.md).

**Done when:** the selected PR set is final, and every `account` PR has at least one area tag.

### 4. Route and draft

Read [mfe-owners.md](mfe-owners.md). Classify each selected PR:

| Repo | Channel |
| --- | --- |
| `spa-common`, `edge-gateway-kong` (alias `egw`) | `#eng-experience-development-platform-internal` |
| Any repo in `mfe-owners.md` | `#micro-frontends-support` |
| Anything else | Ask which channel (do not guess) |

Draft **one message per channel** that has ≥1 selected PR. Use standard markdown (Slack MCP converts it).

**EDP channel body** (`#eng-experience-development-platform-internal`):

```markdown
Hi team — could you please take a look at this review when you have a moment?

<one-sentence summary>

- Jira: <browse URL>
- PRs:
  - <PR URL>
  - <PR URL>
```

**MFE channel body** (`#micro-frontends-support`) — same structure, but open by tagging every owning team for the selected MFE PRs (unique handles, space-separated):

```markdown
Hi @eng-membership-team @eng-acquisition-team — could you please take a look at this review when you have a moment?

<one-sentence summary>

- Jira: <browse URL>
- PRs:
  - <PR URL>
  - <PR URL>
```

Use the literal `@…` usergroup names from [mfe-owners.md](mfe-owners.md) (example above is illustrative). Include only PRs that belong in that channel. Keep the ask polite; do not @channel or @here.

Show each draft to the user and get explicit approval to send (channel + full text).

**Done when:** every destination message is approved, or the user cancelled.

### 5. Post

For each approved message:

1. Resolve the channel with Slack MCP search (`slack_search_channels` or equivalent).
2. Send with `slack_send_message` (or the current Slack MCP send tool).

If Slack MCP is unavailable or auth fails, hand the approved text + channel name to the user to paste — do not invent another delivery path.

**Done when:** every approved message is sent (URL/timestamp reported) or handed off for manual paste with a clear reason.

## Rules

- Never post without an approved draft.
- Never invent PR links or team handles — only [mfe-owners.md](mfe-owners.md) and the user's `account` area picks.
- One sentence for the summary. Links for Jira + every selected PR. Polite ask.
- Score questions with the `questions` skill before asking; the PR picker and `account` area picker are set picks (one option per member).
