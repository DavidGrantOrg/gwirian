# MCP Client Configuration Guide

This guide explains how to configure an MCP client to connect to the Gwirian MCP Server.

## Prerequisites

1. **Get Your API Token**
   - Log in to your Gwirian account
   - Navigate to your workspace settings (or workspace members page)
   - Generate an API token for the workspace (if you don't have one)
   - Copy the API token - you'll need it for client configuration
   - **Important**: API tokens are workspace-scoped. Each workspace has its own API token, and the token determines which workspace context the MCP tools will operate in. You can have different tokens for different workspaces.

2. **Server URL**
   - Development: `http://localhost:3000/mcp`
   - Production: `https://your-domain.com/mcp`

## Example configuration for Cursor

*Note: This is an example configuration for Cursor. For specific configuration details, please refer to your tool's documentation.*

To configure the Gwirian MCP server in Cursor, add it to your Cursor MCP settings:

1. Open Cursor Settings
2. Navigate to **Features** → **Model Context Protocol**
3. Click **Add Server** or edit your MCP settings file

**Configuration file location**: `~/.cursor/mcp.json` (or in Cursor settings)

```json
{
  "mcpServers": {
    "gwirian": {
      "url": "http://localhost:3000/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_API_TOKEN_HERE"
      }
    }
  }
}
```

**For production**, replace the URL with your production server:
```json
{
  "mcpServers": {
    "gwirian": {
      "url": "https://your-domain.com/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_API_TOKEN_HERE"
      }
    }
  }
}
```

**Note**: Make sure to replace `YOUR_API_TOKEN_HERE` with your actual API token from your workspace settings. Remember that API tokens are workspace-scoped, so the token you use will determine which workspace the MCP tools access.

## Authentication

The MCP server uses workspace-scoped API token authentication. The API token is associated with a specific workspace membership, and all MCP tool operations will be performed within that workspace's context.

Include the token in the `Authorization` header:

```
Authorization: Bearer YOUR_API_TOKEN_HERE
```

Alternatively, you can pass it as a query parameter (though header is preferred):

```
?api_token=YOUR_API_TOKEN_HERE
```

**Workspace Context**: When you authenticate with an API token, the MCP server automatically sets the workspace context based on the workspace associated with that token. All project operations will be scoped to that workspace. If you need to access multiple workspaces, you'll need to use different API tokens for each workspace.

## Available Tools

Once connected, you can use the following tools. All operations are scoped to the workspace associated with your API token:

### Projects (Read-only)
- `list_projects` - List all accessible projects in the workspace
- `get_project` - Get project details with executions, team members and folders

Project payloads include an optional `context` field (text) for test context: environments and URLs, test accounts and logins, and other hints for scenario execution.

### Features (Full CRUD)
- `list_features` - List features for a project
- `get_feature` - Get feature details with executions
- `create_feature` - Create a new feature
- `update_feature` - Update an existing feature
- `delete_feature` - Move a feature, with its scenarios, steps and runs, to the project's Trash

`create_feature` and `update_feature` accept `folder_id`; `null` puts the feature in Unfiled, and leaving `folder_id` out of `update_feature` leaves the feature where it is. `get_feature` and `list_features` return `folder_id` and `folder_path` (`"Ordering › Suggested orders"`, or `null` when Unfiled).

### Folders (Full CRUD)
- `list_folders` - List a project's folders depth first, each with `id`, `name`, `parent_id` and `path`
- `create_folder` - Create a folder at the top of the project, or inside `parent_id`
- `update_folder` - Rename a folder, or move it with `parent_id`; `null` moves it to the top, and leaving `parent_id` out leaves it where it is
- `delete_folder` - Delete a folder; its features and sub-folders move up into its parent

A folder's name is unique among the folders beside it, and a folder can't be moved inside itself or one of its sub-folders. `get_project` includes the same folder list as `list_folders`.

### Scenarios (Full CRUD)
- `list_scenarios` - List scenarios for a feature
- `get_scenario` - Get scenario details with executions
- `create_scenario` - Create a new scenario
- `update_scenario` - Update a scenario
- `delete_scenario` - Move a scenario, with its steps and runs, to the project's Trash

`create_scenario` and `update_scenario` accept a boolean `backlog`: a backlog scenario is written but not built, and is left out of every count and pass rate. Leaving it out of `create_scenario` follows the server's `NEW_SCENARIOS` setting, and leaving it out of `update_scenario` leaves it as it is. Every scenario tool returns it.

### Scenario Executions (Full CRUD)
- `list_scenario_executions` - List executions for a scenario
- `get_scenario_execution` - Get execution details
- `create_scenario_execution` - Create a new execution
- `update_scenario_execution` - Update an execution
- `delete_scenario_execution` - Delete an execution

Executions support an optional `tag_list` (comma-separated string) for test type (e.g. e2e, smoke), version, bugfix info, or other metadata. Create and update tools accept `tag_list`; list and get include `tag_list` in each execution.

### Trash
- `list_trashed_items` - List a project's Trash, newest first: `project_id`, with `limit` (default 50, at most 200) and `offset` (default 0)
- `restore_trashed_item` - Bring a deleted feature or scenario back under its old number: `trashed_item_id`

Nothing in the Trash expires. Emptying it is done on the project's Trash page (Delete forever); no tool does it. A deleted execution, folder, project or workspace does not go to the Trash.

## Recovering a delete

`delete_feature` and `delete_scenario` answer as before, plus the `trashed_item_id` that brings the item back:

```json
{"message": "Scenario deleted successfully", "id": 112, "trashed_item_id": 42}
```

Restore it with that id:

```json
{"name": "restore_trashed_item", "arguments": {"trashed_item_id": 42}}
```

```json
{"item_type": "Scenario", "item_id": 112, "number": "S112", "project_id": 1, "feature_id": 19,
 "message": "Restored S112.", "url": "https://your-domain.com/your-workspace/projects/1/features/19#scenario-112"}
```

A restored feature comes back with its number, its scenarios in their order, their steps, its tags, and every run with its tags. A scenario goes back to its old place among its feature's scenarios, or last when the list is now shorter. A feature whose folder has gone comes back unfiled, and `message` says so.

Without the id, find it in the Trash:

```json
{"name": "list_trashed_items", "arguments": {"project_id": 1}}
```

```json
{"total": 2, "items": [
  {"trashed_item_id": 43, "item_type": "Feature", "item_id": 19, "number": "F19", "title": "Suggested orders",
   "feature_id": null, "trashed_by": "david@example.com", "trashed_at": "2026-10-19T14:02:11Z", "scenario_numbers": ["S110", "S111"]},
  {"trashed_item_id": 42, "item_type": "Scenario", "item_id": 112, "number": "S112", "title": "Order singles",
   "feature_id": 19, "trashed_by": "david@example.com", "trashed_at": "2026-10-19T14:01:52Z", "scenario_numbers": []}
]}
```

A refused restore comes back with `isError: true`, a `reason` that stays the same, and the request id to look for in the server's log. Here the scenario's feature went to the Trash after it, so the feature comes back first:

```json
{"error": {"code": -32005, "reason": "trash.feature_in_trash", "request_id": "6f1c…",
 "message": "S112's feature F19 is in the Trash; restore it first: restore_trashed_item(trashed_item_id: 43)"}}
```

| `reason` | Why | What to do |
|----------|-----|------------|
| `trash.feature_in_trash` | The scenario's feature is in the Trash too. | Restore the feature with the call in the message, then the scenario. |
| `trash.feature_gone` | The scenario's feature was deleted forever. | Download the scenario's snapshot from the Trash page. |
| `trash.schema_incompatible` | The item was trashed before a migration that changed its tables. | Download its snapshot from the Trash page, or restore from a backup. |
| `trash.gone` | Another restore or a Delete forever took the item first. | Nothing to restore; `list_trashed_items` shows what is left. |

A `trashed_item_id` from another workspace, or one that never existed, gives `Record not found`.

## Testing the Connection

You can test the connection using curl. Replace `YOUR_API_TOKEN` with your actual API token:

```bash
# Health check (requires Bearer token authentication)
curl http://localhost:3000/mcp/health \
  -H "Authorization: Bearer YOUR_API_TOKEN"

# Initialize (requires Bearer token authentication)
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {}
  }'

# List tools (requires Bearer token authentication)
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/list",
    "params": {}
  }'

# Call a tool (requires Bearer token authentication)
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
      "name": "list_projects",
      "arguments": {}
    }
  }'
```

**Note**: You can also use an environment variable for the token:
```bash
export API_TOKEN="your_actual_token_here"
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}'
```

## Troubleshooting

### Authentication Errors
- Ensure your API token is valid and not expired
- Check that the token is included in the `Authorization` header with the `Bearer ` prefix
- Verify the token hasn't been revoked
- Confirm that the API token belongs to a valid workspace membership
- If you're a member of multiple workspaces, make sure you're using the correct token for the workspace you want to access

### Connection Errors
- Verify the server URL is correct
- Check that the Rails server is running
- Ensure CORS is properly configured if accessing from a browser

### Tool Not Found Errors
- Use `tools/list` to see all available tools
- Verify the tool name is spelled correctly
- Check that you have the necessary permissions for the operation

