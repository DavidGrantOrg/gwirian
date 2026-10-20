require "rails_helper"

RSpec.describe "MCP list_features", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, :with_api_token, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address) }

  def call_list_features(arguments)
    post "/mcp",
      params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "list_features", arguments: arguments } }.to_json,
      headers: api_headers(workspace_member.api_token).merge("Content-Type" => "application/json")
    JSON.parse(json_response.dig("result", "content", 0, "text"))
  end

  describe "with a search term", :elasticsearch do
    before { Feature.__elasticsearch__.create_index!(force: true) }

    let!(:checkout) { create(:feature, project: project, title: "Checkout", description: "Pay for the basket") }
    let!(:login) { create(:feature, project: project, title: "Login", description: "Sign in with a code") }

    before { Feature.__elasticsearch__.refresh_index! }

    it "returns the matching features' fields" do
      features = call_list_features(project_id: project.id, search: "checkout")

      expect(features).to eq([
        {
          "id" => checkout.id,
          "title" => "Checkout",
          "description" => "Pay for the basket",
          "project_id" => project.id,
          "created_at" => checkout.created_at.as_json,
          "updated_at" => checkout.updated_at.as_json,
          "folder_id" => nil,
          "folder_path" => nil
        }
      ])
    end
  end
end
