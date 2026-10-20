require "rails_helper"

RSpec.describe "MCP error responses", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, :with_api_token, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let!(:feature) { create(:feature, project: project) }

  before { create(:project_member, project: project, email: user.email_address, role: "viewer") }

  it "flags a refused call as an error, so the client knows it failed" do
    body = { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "update_feature", arguments: { feature_id: feature.id, title: "Renamed" } } }.to_json
    post "/mcp", params: body, headers: api_headers(workspace_member.api_token).merge("Content-Type" => "application/json")

    expect(json_response.dig("result", "isError")).to be(true)
    expect(JSON.parse(json_response.dig("result", "content", 0, "text")).dig("error", "code")).to eq(-32001)
  end
end
