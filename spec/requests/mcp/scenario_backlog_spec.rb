require "rails_helper"

RSpec.describe "MCP scenario backlog", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, :with_api_token, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let(:feature) { create(:feature, project: project) }

  before { create(:project_member, project: project, email: user.email_address, role: "editor") }

  around do |example|
    previous = ENV["NEW_SCENARIOS"]
    ENV["NEW_SCENARIOS"] = "backlog"
    example.run
  ensure
    ENV["NEW_SCENARIOS"] = previous
  end

  def call_tool(name, arguments)
    body = { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: name, arguments: arguments } }.to_json
    post "/mcp", params: body, headers: api_headers(workspace_member.api_token).merge("Content-Type" => "application/json")
    expect(json_response["error"]).to be_nil
    JSON.parse(json_response.dig("result", "content", 0, "text"))
  end

  def backlog_of(scenario_id)
    call_tool("get_scenario", { scenario_id: scenario_id })["backlog"]
  end

  it "creates a scenario in the backlog when NEW_SCENARIOS is backlog" do
    created = call_tool("create_scenario", { feature_id: feature.id, title: "Order a full case" })
    expect(created["backlog"]).to be(true)
    expect(backlog_of(created["id"])).to be(true)
  end

  it "creates a scenario out of the backlog when asked" do
    created = call_tool("create_scenario", { feature_id: feature.id, title: "Order a full case", backlog: false })
    expect(backlog_of(created["id"])).to be(false)
  end

  it "takes a scenario out of the backlog, and puts it back" do
    scenario = create(:scenario, :backlog, feature: feature)

    expect(call_tool("update_scenario", { scenario_id: scenario.id, backlog: false })["backlog"]).to be(false)
    expect(backlog_of(scenario.id)).to be(false)

    call_tool("update_scenario", { scenario_id: scenario.id, backlog: true })
    expect(backlog_of(scenario.id)).to be(true)
  end

  it "leaves the backlog alone when an update does not mention it" do
    scenario = create(:scenario, :backlog, feature: feature)
    call_tool("update_scenario", { scenario_id: scenario.id, title: "Order singles" })
    expect(backlog_of(scenario.id)).to be(true)
  end

  it "lists each scenario's backlog" do
    create(:scenario, :backlog, feature: feature)
    listed = call_tool("list_scenarios", { feature_id: feature.id })
    expect(listed.map { |scenario| scenario["backlog"] }).to eq([ true ])
  end
end
