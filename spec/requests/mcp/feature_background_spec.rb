require "rails_helper"

RSpec.describe "MCP feature background", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, :with_api_token, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }

  before { create(:project_member, project: project, email: user.email_address, role: "editor") }

  def call_tool(name, arguments)
    body = { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: name, arguments: arguments } }.to_json
    post "/mcp", params: body, headers: api_headers(workspace_member.api_token).merge("Content-Type" => "application/json")
    expect(json_response["error"]).to be_nil
    JSON.parse(json_response.dig("result", "content", 0, "text"))
  end

  it "creates a feature with a background that get_feature returns" do
    created = call_tool("create_feature", { project_id: project.id, title: "Ordering", background: "the store is open\nthe shelf is empty" })

    fetched = call_tool("get_feature", { feature_id: created["id"] })
    expect(fetched["background"]).to eq("the store is open\nthe shelf is empty")
  end

  it "replaces a background through update_feature" do
    feature = create(:feature, project: project, background: "the store is open")

    call_tool("update_feature", { feature_id: feature.id, background: "the store is closed" })

    fetched = call_tool("get_feature", { feature_id: feature.id })
    expect(fetched["background"]).to eq("the store is closed")
  end

  it "clears a background when update_feature is given an empty one" do
    feature = create(:feature, project: project, background: "the store is open")

    call_tool("update_feature", { feature_id: feature.id, background: "" })

    fetched = call_tool("get_feature", { feature_id: feature.id })
    expect(fetched["background"]).to eq("")
  end

  it "keeps the background when update_feature is not given one" do
    feature = create(:feature, project: project, background: "the store is open")

    call_tool("update_feature", { feature_id: feature.id, title: "Renamed" })

    fetched = call_tool("get_feature", { feature_id: feature.id })
    expect(fetched["background"]).to eq("the store is open")
  end
end
