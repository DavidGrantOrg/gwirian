require "rails_helper"

# Puma serves MCP requests on several threads at once. This spec pins the interleaving
# deterministically: Bob's whole request runs while Alice's is inside handle_json.
RSpec.describe "MCP identity across concurrent requests", type: :request do
  let(:workspace) { create(:workspace) }
  let(:alice) { create(:user) }
  let(:bob) { create(:user) }
  let!(:alice_member) { create(:workspace_member, :with_api_token, user: alice, workspace: workspace) }
  let!(:bob_member) { create(:workspace_member, :with_api_token, user: bob, workspace: workspace) }
  let!(:alice_project) { create(:project, workspace: workspace, name: "Alice's project") }
  let!(:bob_project) { create(:project, workspace: workspace, name: "Bob's project") }

  before do
    create(:project_member, project: alice_project, email: alice.email_address)
    create(:project_member, project: bob_project, email: bob.email_address)
  end

  def list_projects_body
    { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "list_projects", arguments: {} } }.to_json
  end

  def mcp_headers(member)
    api_headers(member.api_token).merge("Content-Type" => "application/json")
  end

  it "runs each request as its own user when another user's request runs in between" do
    bob_session = open_session
    interleaved = false
    allow_any_instance_of(MCP::Server).to receive(:handle_json).and_wrap_original do |original, *args, **kwargs|
      unless interleaved
        interleaved = true
        bob_session.post "/mcp", params: list_projects_body, headers: mcp_headers(bob_member)
      end
      original.call(*args, **kwargs)
    end

    post "/mcp", params: list_projects_body, headers: mcp_headers(alice_member)

    projects = JSON.parse(json_response.dig("result", "content", 0, "text"))
    expect(projects.map { |p| p["name"] }).to eq([ "Alice's project" ])
    bob_projects = JSON.parse(JSON.parse(bob_session.response.body).dig("result", "content", 0, "text"))
    expect(bob_projects.map { |p| p["name"] }).to eq([ "Bob's project" ])
  end
end
