require "rails_helper"

RSpec.describe "The Trash", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user, email_address: "david@example.com") }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let(:role) { "editor" }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: role) }
  let(:base) { "/#{workspace.slug}/projects/#{project.id}" }
  let(:htmx) { { "HX-Request" => "true" } }

  # The decoy gives features and scenarios different ids, so a number taken from the wrong record shows.
  let!(:decoy) { create(:feature, project: project, title: "Stellar sync") }
  let!(:decoy_scenarios) { create_list(:scenario, 2, feature: decoy) }
  let!(:feature) { create(:feature, project: project, title: "Suggested orders", tag_list: "P1, ordering") }
  let!(:first) { create(:scenario, feature: feature, title: "Order a full case") }
  let!(:second) { create(:scenario, feature: feature, title: "Order singles") }
  let!(:third) { create(:scenario, feature: feature, title: "Order a mixed case") }
  let!(:run) { create(:scenario_execution, scenario: second, user: user, status: "passed", tag_list: "nightly") }

  before { sign_in_as(user) }

  def page_at(path)
    get path
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  def trash_rows
    page_at("#{base}/trash").css("[data-trash-row]")
  end

  def trash_row(number)
    trash_rows.find { |row| row.text.squish.include?(number) }
  end

  def scenario_order(feature)
    page_at("#{base}/features/#{feature.id}").css("[id^='scenario-wrapper-']").map { |node| node["id"].delete_prefix("scenario-wrapper-").to_i }
  end

  def item_id(row)
    row["data-trash-row"].to_i
  end

  describe "deleting a feature and restoring it" do
    it "says the feature moved to the Trash, and lists it there with who trashed it" do
      delete "#{base}/features/#{feature.id}", headers: htmx

      expect(response.body).to include("Moved to Trash.")
      expect(trash_row("F#{feature.id}").text.squish).to include("Feature", "F#{feature.id}", "Suggested orders", "david@example.com")
    end

    it "brings the feature back under its number, with its scenarios in order, its tags and its runs" do
      delete "#{base}/features/#{feature.id}", headers: htmx
      row = trash_row("F#{feature.id}")

      post "#{base}/trash/#{item_id(row)}/restore"

      expect(response).to redirect_to("#{base}/features/#{feature.id}")
      follow_redirect!
      expect(response.body).to include("Restored F#{feature.id}.")
      expect(scenario_order(feature)).to eq([ first.id, second.id, third.id ])
      expect(page_at("#{base}/features/#{feature.id}").at_css("[data-feature-header]").text).to include("P1", "ordering")
      expect(page_at("#{base}/history").text.squish).to include("Order singles", "nightly")
      expect(trash_rows).to be_empty
    end

    # The confirm text sits in an Alpine @click attribute, which Nokogiri does not parse, so these read the raw page.
    it "asks before moving it, naming the feature and how many scenarios go with it" do
      get "#{base}/features"
      expect(response.body).to include("Move F#{feature.id} and its 3 scenarios to the Trash?", "Move F#{decoy.id} and its 2 scenarios to the Trash?")
    end
  end

  describe "deleting a scenario and restoring it" do
    it "puts it back at its old position" do
      delete "#{base}/features/#{feature.id}/scenarios/#{second.id}", headers: htmx
      expect(response).to have_http_status(:ok)
      expect(scenario_order(feature)).to eq([ first.id, third.id ])

      post "#{base}/trash/#{item_id(trash_row("S#{second.id}"))}/restore"

      expect(response).to redirect_to("#{base}/features/#{feature.id}")
      follow_redirect!
      expect(response.body).to include("Restored S#{second.id}.")
      expect(scenario_order(feature)).to eq([ first.id, second.id, third.id ])
    end

    it "asks before moving it, naming the scenario" do
      get "#{base}/features/#{feature.id}"
      expect(response.body).to include("Move S#{second.id} to the Trash?")
    end

    it "refuses while its feature is in the Trash, naming the feature's trash item" do
      delete "#{base}/features/#{feature.id}/scenarios/#{second.id}", headers: htmx
      delete "#{base}/features/#{feature.id}", headers: htmx
      feature_item = item_id(trash_row("F#{feature.id}"))

      post "#{base}/trash/#{item_id(trash_row("S#{second.id}"))}/restore"

      expect(response).to redirect_to("#{base}/trash")
      follow_redirect!
      expect(response.body).to include(
        "S#{second.id}&#39;s feature F#{feature.id} is in the Trash; restore it first: restore_trashed_item(trashed_item_id: #{feature_item})"
      )
    end
  end

  it "brings a feature back unfiled when its folder has gone, and says so" do
    folder = create(:folder, project: project, name: "Ordering")
    feature.update!(folder: folder)
    delete "#{base}/features/#{feature.id}", headers: htmx
    folder.destroy!

    post "#{base}/trash/#{item_id(trash_row("F#{feature.id}"))}/restore"
    follow_redirect!

    expect(response.body).to include("Restored F#{feature.id} unfiled; its folder no longer exists.")
    expect(page_at("#{base}/features").css("[data-feature-card]").map { |c| c.at_css("h3").text.squish }).to include("Suggested orders")
  end

  describe "deleting forever" do
    before do
      delete "#{base}/features/#{feature.id}/scenarios/#{third.id}", headers: htmx
      delete "#{base}/features/#{feature.id}", headers: htmx
    end

    it "asks first, counting the scenarios that go with the feature" do
      get "#{base}/trash"
      expect(response.body).to include("Delete F#{feature.id} and its 3 scenarios forever? This cannot be undone.")
    end

    it "removes the feature and its trashed scenarios from the Trash" do
      delete "#{base}/trash/#{item_id(trash_row("F#{feature.id}"))}"

      expect(response).to redirect_to("#{base}/trash")
      expect(trash_rows).to be_empty
      expect(page_at("#{base}/trash").text).to include("Nothing in the Trash.")
    end
  end

  it "answers 404 for an item no longer in the Trash" do
    delete "#{base}/features/#{feature.id}", headers: htmx
    id = item_id(trash_row("F#{feature.id}"))
    post "#{base}/trash/#{id}/restore"

    post "#{base}/trash/#{id}/restore"

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("That item is no longer in the Trash.")
  end

  it "downloads an item's snapshot as JSON" do
    delete "#{base}/features/#{feature.id}", headers: htmx

    get "#{base}/trash/#{item_id(trash_row("F#{feature.id}"))}/download"

    expect(response.media_type).to eq("application/json")
    snapshot = JSON.parse(response.body)
    expect(snapshot["features"].map { |f| f["title"] }).to eq([ "Suggested orders" ])
    expect(snapshot["scenarios"].map { |s| s["id"] }).to eq([ first.id, second.id, third.id ])
  end

  it "has a Trash link in the project navigation" do
    link = page_at("#{base}/features").css("#project-nav-bar a").find { |a| a.text.squish == "Trash" }
    expect(link["href"]).to eq("#{base}/trash")
  end

  context "as a viewer" do
    let(:role) { "viewer" }
    let!(:item) { Trash.move!(feature, by: user) }

    it "sees the Trash" do
      expect(trash_row("F#{feature.id}")).not_to be_nil
    end

    it "may not restore, delete forever or download" do
      post "#{base}/trash/#{item.id}/restore"
      expect(response).to have_http_status(:forbidden)
      delete "#{base}/trash/#{item.id}"
      expect(response).to have_http_status(:forbidden)
      get "#{base}/trash/#{item.id}/download"
      expect(response).to have_http_status(:forbidden)
    end
  end

  it "is not found for someone outside the project" do
    other = create(:project, workspace: workspace)

    get "/#{workspace.slug}/projects/#{other.id}/trash"

    expect(response).to have_http_status(:not_found)
  end
end
