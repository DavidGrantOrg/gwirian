require "rails_helper"

RSpec.describe Mcp::Server do
  describe ".server_name" do
    it "is Gwirian MCP Server when APP_NAME is unset", env: { "APP_NAME" => nil } do
      expect(Mcp::Server.server_name).to eq("Gwirian MCP Server")
    end

    it "names APP_NAME when it is set", env: { "APP_NAME" => "Playbook" } do
      expect(Mcp::Server.server_name).to eq("Playbook MCP Server")
    end
  end
end
