# Linear API Operations

Used by `intents/linear.md`. The shared request command is `CMD_LINEAR_GRAPHQL` in `references/common-commands.md`.

## Authentication and config

Use a personal API key from the agent process's `LINEAR_API_KEY` environment variable. Personal keys use `Authorization: <key>` without a Bearer prefix. Never print the key, put it in request JSON, enable shell tracing, or store it in `.agent-config`. If absent, direct the user to [Linear Security & access](https://linear.app/settings/account/security) and ask them to expose the key to their agent locally before retrying.

Repo defaults are optional, non-secret values:

```ini
[linear]
linear_team = "ENG"
linear_project = ""
```

`linear_team` accepts a team key, name, or UUID. `linear_project` accepts a project name or UUID; empty means no default project. Read the `[linear]` section as data, preserving spaces and punctuation inside quoted values. Do not execute or source the config. Do not write it automatically; show a snippet if the user wants to save selected defaults. Explicit request values override defaults. A project default is used only with its configured team; when the user selects a different team, omit that project default unless explicitly requested.

For creating and listing issues, resolve the team first with `LinearTeams`. Match UUIDs and keys exactly, names case-insensitively. Ask on multiple matches or missing defaults when several teams are available. An invalid configured value is an error, not permission to choose another team. Resolve a requested project using `LinearProjects` within that team. Reject absent or ambiguous project matches rather than dropping the filter or creating a project. Existing-issue operations use the fetched issue's team and project, independent of defaults.

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
