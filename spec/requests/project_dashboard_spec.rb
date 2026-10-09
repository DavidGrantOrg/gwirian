require "rails_helper"

RSpec.describe "Project dashboard", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace, name: "Liquor Lodge") }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: "editor") }

  let!(:ordering) { create(:folder, project: project, name: "Ordering") }
  let!(:suggested) { create(:folder, project: project, parent: ordering, name: "Suggested orders") }
  let!(:catalog) { create(:folder, project: project, name: "Catalog") }
  let!(:reorder) { create(:feature, project: project, title: "Reorder from history", folder: suggested) }
  let!(:sizes) { create(:feature, project: project, title: "Case sizes", folder: suggested) }
  let!(:prices) { create(:feature, project: project, title: "Prices", folder: catalog) }
  let!(:sign_in) { create(:feature, project: project, title: "Sign in") }
  let!(:scenarios) { [ reorder, sizes, prices, sign_in ].map { |feature| create(:scenario, feature: feature) } }

  before { sign_in_as(user) }

  def dashboard
    get "/#{workspace.slug}/projects/#{project.id}"
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  def main_text(page)
    page.at_css("main").text.squish
  end

  def coverage(page)
    page.css("h3").find { |h| h.text.squish == "Feature Coverage" }.ancestors("div.rounded-xl").first
  end

  def coverage_entries(page)
    coverage(page).css("h4, a").map { |node| node.name == "h4" ? "## #{node.text.squish}" : node.text.squish }
  end

  context "before any run is recorded" do
    it "says no runs are recorded instead of showing a pass rate" do
      text = main_text(dashboard)
      expect(text).to include("No runs recorded yet")
      expect(text).not_to include("Pass Rate")
      expect(text).not_to include("0%")
    end

    it "leaves out the panels that only report runs" do
      text = main_text(dashboard)
      expect(text).not_to include("Failing Tests")
      expect(text).not_to include("All tests are passing!")
      expect(text).not_to include("Execution Trends")
      expect(text).not_to include("Recent Executions")
    end

    it "lists features under their folders in tree order, with no run counts" do
      expect(coverage_entries(dashboard)).to eq([
        "Sign in 1 scenarios",
        "## Catalog",
        "Prices 1 scenarios",
        "## Ordering › Suggested orders",
        "Case sizes 1 scenarios",
        "Reorder from history 1 scenarios"
      ])
    end
  end

  context "once a run is recorded" do
    before { create(:scenario_execution, scenario: scenarios.first, user: user, status: "passed") }

    it "shows the pass rate and the panels that report runs" do
      text = main_text(dashboard)
      expect(text).to include("Pass Rate")
      expect(text).not_to include("No runs recorded yet")
      expect(text).to include("Failing Tests")
      expect(text).to include("Execution Trends")
      expect(text).to include("Recent Executions")
    end

    it "still lists features under their folders, now with each one's run counts" do
      expect(coverage_entries(dashboard)).to eq([
        "Sign in 1 scenarios 1 pending",
        "## Catalog",
        "Prices 1 scenarios 1 pending",
        "## Ordering › Suggested orders",
        "Case sizes 1 scenarios 1 pending",
        "Reorder from history 1 scenarios 1 passed"
      ])
    end
  end
end
