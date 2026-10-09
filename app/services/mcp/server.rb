# frozen_string_literal: true

module Mcp
  class Server
    SERVER_NAME = "Gwirian MCP Server"
    SERVER_VERSION = "1.0.0"

    # A server per request: MCP::Server reads server_context when a tool runs, so a shared
    # instance lets one request's user leak into another request handled at the same time.
    def self.build(server_context:)
      ::MCP::Server.new(
        name: SERVER_NAME,
        version: SERVER_VERSION,
        server_context: server_context,
        tools: [
          Mcp::Tools::ListProjects,
          Mcp::Tools::GetProject,
          Mcp::Tools::SearchProject,
          Mcp::Tools::ListFeatures,
          Mcp::Tools::GetFeature,
          Mcp::Tools::CreateFeature,
          Mcp::Tools::UpdateFeature,
          Mcp::Tools::DeleteFeature,
          Mcp::Tools::ListFolders,
          Mcp::Tools::CreateFolder,
          Mcp::Tools::UpdateFolder,
          Mcp::Tools::DeleteFolder,
          Mcp::Tools::ListScenarios,
          Mcp::Tools::GetScenario,
          Mcp::Tools::CreateScenario,
          Mcp::Tools::UpdateScenario,
          Mcp::Tools::DeleteScenario,
          Mcp::Tools::ListScenarioExecutions,
          Mcp::Tools::GetScenarioExecution,
          Mcp::Tools::CreateScenarioExecution,
          Mcp::Tools::UpdateScenarioExecution,
          Mcp::Tools::DeleteScenarioExecution
        ]
      )
    end
  end
end
