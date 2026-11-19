# Linear API Operations

Used by `intents/linear.md`. The shared request command is `CMD_LINEAR_GRAPHQL` in `references/common-commands.md`.

## Authentication and config

Linear uses Zenith's existing global/repo configuration split. Store the personal API key in `~/.zenith/.global-config`:

```ini
[linear]
linear_api_key = "your-personal-api-key"
```

Read the nonempty saved key first, then fall back to the agent's `LINEAR_API_KEY` environment variable. `CMD_LINEAR_GRAPHQL` implements this resolution on every request, including in a new shell. An environment-only key works without being copied to disk. Personal keys use `Authorization: <key>` without a Bearer prefix. Never print or dump credentials, put them in request JSON or shell arguments, enable shell tracing around them, or store them in `.agent-config`.

Store non-secret repo defaults in `.agent-config`:

```ini
[linear]
linear_team = "ENG"
linear_project = ""
```

`linear_team` accepts a team key, name, or UUID. `linear_project` accepts a project name or UUID; an empty saved value means no default project. Read only the `[linear]` section as data, preserving spaces and punctuation inside quoted values. Do not execute or source either config file. Explicit request values override defaults for that request. A project default is used only with its configured team; when the user selects a different team, omit that project's default unless explicitly requested.

## Guided first-time setup

Run the ordinary first-time repo setup from `ZENITH.md` first when `.agent-config` is absent. Then run these independent Linear setup steps before the original issue operation. Existing Git and Jira users receive Linear setup on their first Linear request; do not reinitialize their files or invoke Jira setup. PR-only linking with supplied IDs does not need this setup.

1. **Credentials:** Reuse a saved key or environment fallback unless the user explicitly asks to replace it. When a key is missing or replacement is requested, explain that it will be saved once for all repos and start hidden local entry with:

   ```bash
   bash "$HOME/.zenith/scripts/setup.sh" --linear
   ```

   Use a user-controlled terminal, not an agent terminal whose only input path is chat. If the client cannot accept hidden terminal input, show that command for the user to run in their local Terminal, wait for them to finish, then resume. Do not ask them to paste the key into chat or edit their shell profile. The script prompts for the key, updates only `[linear].linear_api_key`, preserves GitHub/Jira settings, and saves the global config with mode `600`. Empty or cancelled input leaves the file unchanged. The normal installer and daily updates never run this prompt.

2. **Validation:** Execute `LinearViewer` with `CMD_LINEAR_GRAPHQL`. On an authentication failure, stop the original operation and offer the same local setup command to replace the key. Do not silently fall back from a rejected saved key to a different environment credential, and never fall back to Jira.

3. **Repo defaults:** If `linear_team` is missing or empty, fetch `LinearTeams` and ask the user to select the repo's default team. Prefill a team from the request or a fetched issue when available, but do not silently persist a per-request override. If the `linear_project` key is absent, fetch the selected team's projects and offer an optional default; Enter means none. A present empty project value is already configured. Resolve all selections and pagination before saving; cancellation or invalid scope must not write partial defaults or execute the original mutation.

   ```text
   linear repo setup
   | default team:
   | default project [Enter for none]:
   ```

4. **Save and continue:** Add or update only the selected `[linear]` keys in `.agent-config`, preserving existing repo/user/Jira settings and comments. Keep one `[linear]` section and one entry per key. Escape quotes and backslashes when storing names, and decode them on read. Keep the config ignored by Git. Report the team/project, then continue the original request in the same workflow; setup itself does not create issues, move statuses, or perform Git synchronization.

Run setup again only for missing settings or when explicitly requested through `linear setup`. For a requested team-default change, also select or clear the default project so a project from the old team is not retained. Once onboarding is complete, normal issue operations use the saved configuration without prompting again; explicit one-off overrides are not persisted.

For creating and listing issues, resolve the requested or configured team with `LinearTeams`. Match UUIDs and keys exactly, names case-insensitively. Ask on multiple matches. An invalid configured value is an error, not permission to choose another team; offer guided setup to correct it. Resolve a requested project using `LinearProjects` within that team. Reject absent or ambiguous project matches rather than dropping the filter or creating a project. Existing-issue operations use the fetched issue's team and project, independent of defaults.

## Requests and responses

1. Build a JSON object with `query`, `operationName`, and `variables`. All titles, descriptions, identifiers, names, filters, and update inputs belong in variables. Use a file-writing tool or an available JSON serializer; never concatenate user content into GraphQL or shell source. No additional package is required.
2. Create a private temporary directory with `mktemp -d`. Write the payload as `request.json` inside it and set `linear_request_file`, `linear_response_file`, and `linear_headers_file` to paths in that directory. Keep temporary payloads outside the repo and remove them after inspecting the result.
3. Run `CMD_LINEAR_GRAPHQL` once. Check curl's exit status before reading `linear_http_code`. On transport failure or timeout, stop and report whether a mutation's outcome is unknown.
4. Require an HTTP 2xx response and valid JSON. Inspect the top-level `errors` array even on HTTP 200. If nonempty, report the error messages and codes and stop; partial data does not establish success. Do not parse JSON with grep or assume that the first `name` field is the requested value.
5. For queries, require the requested data object. For mutations, also require the corresponding payload's `success` to be `true`; create/update must return the expected issue and URL. An empty result, malformed response, `success: false`, or inaccessible issue must never be reported as success.

For 401/403 or authentication/permission GraphQL errors, report the access failure without exposing request headers. For 429 or `RATELIMITED`, report the returned retry/reset information and stop. Do not automatically repeat mutations after any error: a create may have succeeded before the response was lost. Reconcile through a read before offering a retry, and ask the user when the result remains uncertain. Never silently switch to Jira.

Every connection below includes `pageInfo`. Pass `endCursor` as `after` until `hasNextPage` is false when resolving names or fulfilling an explicit request for all results. A failed later page leaves the result incomplete. Do not choose a match or claim absence from a partial lookup. Issue listings may stop at the requested limit if they clearly state more results exist.

## Queries

Use the operation name shown in each block. Start pagination with `after: null`.

```graphql
query LinearViewer {
  viewer { id name email }
}
```

```graphql
query LinearTeams($after: String) {
  teams(first: 50, after: $after) {
    nodes { id key name }
    pageInfo { hasNextPage endCursor }
  }
}
```

```graphql
query LinearProjects($teamId: String!, $after: String) {
  team(id: $teamId) {
    projects(first: 50, after: $after) {
      nodes { id name url }
      pageInfo { hasNextPage endCursor }
    }
  }
}
```

Pass an issue UUID or identifier such as `ENG-123` as `id`. For a `linear.app` issue URL, extract its `/issue/` identifier; do not send API credentials to the supplied URL.

```graphql
query LinearIssue($id: String!) {
  issue(id: $id) {
    id identifier title description url branchName priority archivedAt trashed
    state { id name type }
    assignee { id name email }
    team { id key name }
    project { id name }
    parent { id identifier }
  }
}
```

```graphql
query LinearIssues($filter: IssueFilter!, $after: String, $first: Int!) {
  issues(filter: $filter, first: $first, after: $after, orderBy: updatedAt) {
    nodes {
      id identifier title url
      state { id name type }
      assignee { id name }
      project { id name }
    }
    pageInfo { hasNextPage endCursor }
  }
}
```

For the default open issues list, build the filter with `team.id.eq` set to the resolved team UUID, `assignee.id.eq` to the viewer UUID, and `state.type.nin` to `["completed", "canceled", "duplicate"]`. Add `project.id.eq` only for a resolved project filter. Set `first` to 20, or a smaller requested limit; page for larger requests.

```graphql
query LinearStates($teamId: String!, $after: String) {
  team(id: $teamId) {
    states(first: 50, after: $after) {
      nodes { id name type }
      pageInfo { hasNextPage endCursor }
    }
  }
}
```

```graphql
query LinearUsers($after: String) {
  users(first: 50, after: $after, filter: { active: { eq: true } }) {
    nodes { id name email }
    pageInfo { hasNextPage endCursor }
  }
}
```

## Mutations

Resolve names to UUIDs before filling input fields. Omit unspecified fields. A `null` update clears a nullable relationship only when requested by the user.

```graphql
mutation LinearCreateIssue($input: IssueCreateInput!) {
  issueCreate(input: $input) {
    success
    issue { id identifier title url }
  }
}
```

```graphql
mutation LinearUpdateIssue($id: String!, $input: IssueUpdateInput!) {
  issueUpdate(id: $id, input: $input) {
    success
    issue {
      id identifier title description url priority
      state { id name type }
      assignee { id name }
      project { id name }
      parent { id identifier }
    }
  }
}
```

```graphql
mutation LinearDeleteIssue($id: String!) {
  issueDelete(id: $id, permanentlyDelete: false) { success }
}
```

## Sources

API operations checked on 2026-11-05 against Linear's [published schema](https://github.com/linear/linear/blob/master/packages/sdk/src/schema.graphql). See the official [authentication and error handling guide](https://linear.app/developers/graphql), [filters](https://linear.app/developers/filtering), [pagination](https://linear.app/developers/pagination), [rate limits](https://linear.app/developers/rate-limiting), and [deletion behavior](https://linear.app/docs/delete-archive-issues).

Assignment follows [Linear's workspace-member rules](https://linear.app/docs/assigning-issues). Parent and child issues may belong to different [teams](https://linear.app/docs/teams).
