require "rails_helper"

RSpec.describe "MCP and the Trash", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, :with_api_token, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let(:role) { "editor" }
  # The decoys give features, scenarios and trash items different ids, so an id taken from the wrong record shows.
  let!(:decoy) { create(:feature, project: project, title: "Stellar sync") }
  let!(:decoy_scenarios) { create_list(:scenario, 2, feature: decoy) }
  let!(:feature) { create(:feature, project: project, title: "Suggested orders") }
  let!(:scenario) { create(:scenario, feature: feature, title: "Order singles") }

  before { create(:project_member, project: project, email: user.email_address, role: role) }

  def call(name, arguments)
    body = { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: name, arguments: arguments } }.to_json
    post "/mcp", params: body, headers: api_headers(workspace_member.api_token).merge("Content-Type" => "application/json")
    expect(json_response["error"]).to be_nil
    json_response["result"]
  end

  def call_tool(name, arguments)
    JSON.parse(call(name, arguments).dig("content", 0, "text"))
  end

  describe "delete_feature" do
    it "keeps its message and id, and gives the trash item" do
      Trash.move!(decoy, by: user)

      result = call_tool("delete_feature", { feature_id: feature.id })

      expect(result).to eq(
        "message" => "Feature deleted successfully", "id" => feature.id,
        "trashed_item_id" => TrashedItem.find_by!(item_type: "Feature", item_id: feature.id).id
      )
    end
  end

  describe "delete_scenario and restore_trashed_item" do
    it "puts a deleted scenario back with one call, and says what came back" do
      deleted = call_tool("delete_scenario", { scenario_id: scenario.id })
      expect(deleted.slice("message", "id")).to eq("message" => "Scenario deleted successfully", "id" => scenario.id)

      restored = call_tool("restore_trashed_item", { trashed_item_id: deleted["trashed_item_id"] })

      expect(restored).to eq(
        "item_type" => "Scenario", "item_id" => scenario.id, "number" => "S#{scenario.id}",
        "project_id" => project.id, "feature_id" => feature.id, "message" => "Restored S#{scenario.id}.",
        "url" => "http://www.example.com/#{workspace.slug}/projects/#{project.id}/features/#{feature.id}#scenario-#{scenario.id}"
      )
      expect(call_tool("get_scenario", { scenario_id: scenario.id })["title"]).to eq("Order singles")
    end
  end

  describe "a refused restore" do
    it "is flagged as an error, names the call that comes first, and carries a code and the request id" do
      scenario_item = call_tool("delete_scenario", { scenario_id: scenario.id })["trashed_item_id"]
      feature_item = call_tool("delete_feature", { feature_id: feature.id })["trashed_item_id"]

      result = call("restore_trashed_item", { trashed_item_id: scenario_item })

      expect(result["isError"]).to be(true)
      error = JSON.parse(result.dig("content", 0, "text"))["error"]
      expect(error.except("request_id")).to eq(
        "code" => -32005, "reason" => "trash.feature_in_trash",
        "message" => "S#{scenario.id}'s feature F#{feature.id} is in the Trash; restore it first: restore_trashed_item(trashed_item_id: #{feature_item})"
      )
      expect(error["request_id"]).to eq(response.request.request_id)
    end
  end

  describe "list_trashed_items" do
    let(:full_case) { create(:scenario, feature: feature, title: "Order a full case") }
    let!(:items) { [ decoy_scenarios.first, scenario, full_case, decoy, feature ].map { |record| Trash.move!(record, by: user) } }

    it "lists newest first with a total, and a feature's scenarios by number" do
      result = call_tool("list_trashed_items", { project_id: project.id, limit: 2 })

      expect(result["total"]).to eq(5)
      expect(result["items"].map { |item| item.except("trashed_at") }).to eq([
        { "trashed_item_id" => items[4].id, "item_type" => "Feature", "item_id" => feature.id, "number" => "F#{feature.id}",
          "title" => "Suggested orders", "feature_id" => nil, "trashed_by" => user.email_address, "scenario_numbers" => [] },
        { "trashed_item_id" => items[3].id, "item_type" => "Feature", "item_id" => decoy.id, "number" => "F#{decoy.id}",
          "title" => "Stellar sync", "feature_id" => nil, "trashed_by" => user.email_address,
          "scenario_numbers" => [ "S#{decoy_scenarios.second.id}" ] }
      ])
      expect(result["items"].first["trashed_at"]).to eq(items[4].created_at.iso8601)
    end

    it "pages with an offset, naming each scenario's feature" do
      result = call_tool("list_trashed_items", { project_id: project.id, limit: 2, offset: 2 })

      expect(result["items"].map { |item| item.slice("number", "feature_id") }).to eq([
        { "number" => "S#{full_case.id}", "feature_id" => feature.id },
        { "number" => "S#{scenario.id}", "feature_id" => feature.id }
      ])
    end
  end

  context "as a viewer" do
    let(:role) { "viewer" }

    it "may list but not restore" do
      item = Trash.move!(scenario, by: user)

      expect(call_tool("list_trashed_items", { project_id: project.id })["total"]).to eq(1)
      expect(call_tool("restore_trashed_item", { trashed_item_id: item.id }).dig("error", "code")).to eq(-32001)
    end
  end

  context "with a token for another workspace the user is also in" do
    let(:other_workspace) { create(:workspace) }
    let(:other_project) { create(:project, workspace: other_workspace) }
    let!(:other_feature) { create(:feature, project: other_project) }
    let!(:other_item) { Trash.move!(create(:scenario, feature: other_feature), by: user) }

    before do
      create(:workspace_member, user: user, workspace: other_workspace)
      create(:project_member, project: other_project, email: user.email_address, role: "editor")
    end

    it "does not find that workspace's feature to delete" do
      expect(call_tool("delete_feature", { feature_id: other_feature.id }).dig("error", "message")).to start_with("Record not found")
      expect(Feature.exists?(other_feature.id)).to be(true)
    end

    it "does not find that workspace's scenario to delete" do
      other_scenario = other_feature.scenarios.create!(title: "Elsewhere")
      expect(call_tool("delete_scenario", { scenario_id: other_scenario.id }).dig("error", "message")).to start_with("Record not found")
    end

    it "does not find that workspace's Trash to list" do
      expect(call_tool("list_trashed_items", { project_id: other_project.id }).dig("error", "message")).to start_with("Record not found")
    end

    it "does not find that workspace's trash item to restore" do
      expect(call_tool("restore_trashed_item", { trashed_item_id: other_item.id }).dig("error", "message")).to start_with("Record not found")
    end
  end

  it "says a trash item that does not exist is not found" do
    expect(call_tool("restore_trashed_item", { trashed_item_id: 999_999 }).dig("error", "message")).to start_with("Record not found")
  end
end
