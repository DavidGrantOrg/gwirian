# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Search with the database backend", type: :request, search_backend: :database do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, :with_api_token, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address) }
  let!(:checkout) { create(:feature, project: project, title: "Checkout", description: "Pay for the basket") }
  let!(:login) { create(:feature, project: project, title: "Login", description: "Sign in with a code") }
  let!(:pay_by_card) { create(:scenario, feature: checkout, title: "Pay by card", given: "a full basket") }

  def call_mcp_tool(name, arguments)
    post "/mcp",
      params: { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: name, arguments: arguments } }.to_json,
      headers: api_headers(workspace_member.api_token).merge("Content-Type" => "application/json")
    JSON.parse(json_response.dig("result", "content", 0, "text"))
  end

  it "filters the features page" do
    sign_in_as(user)
    get "/#{workspace.slug}/projects/#{project.id}/features", params: { q: "basket" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Checkout")
    expect(response.body).not_to include("Login")
  end

  it "filters the project history" do
    create(:scenario_execution, scenario: pay_by_card, user: user, notes: "Visa accepted")
    create(:scenario_execution, scenario: create(:scenario, feature: login, title: "Sign in"), user: user, notes: "Code expired")
    sign_in_as(user)
    get "/#{workspace.slug}/projects/#{project.id}/history", params: { q: "visa" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pay by card")
    expect(response.body).not_to include("Sign in")
  end

  it "answers the command palette" do
    sign_in_as(user)
    get "/#{workspace.slug}/projects/#{project.id}/search.json", params: { q: "basket" }

    expect(json_response["results"].map { |r| [ r["type"], r["title"] ] }).to eq([ [ "feature", "Checkout" ], [ "scenario", "Pay by card" ] ])
  end

  it "answers the API's project search" do
    get "/api/v1/projects/#{project.id}/search", params: { q: "basket" }, headers: api_headers(workspace_member.api_token)

    expect(json_response["results"].map { |r| [ r["type"], r["id"] ] }).to eq([ [ "feature", checkout.id ], [ "scenario", pay_by_card.id ] ])
  end

  it "answers MCP search_project" do
    results = call_mcp_tool("search_project", project_id: project.id, query: "basket")["results"]

    expect(results.map { |r| [ r["type"], r["id"] ] }).to eq([ [ "feature", checkout.id ], [ "scenario", pay_by_card.id ] ])
  end

  it "answers MCP list_features with a search term" do
    features = call_mcp_tool("list_features", project_id: project.id, search: "basket")

    expect(features.map { |f| f["title"] }).to eq([ "Checkout" ])
  end
end
