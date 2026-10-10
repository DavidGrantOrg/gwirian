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

    it "shows a feature whose scenarios are all in the backlog as Backlog" do
      scenarios.last.update!(backlog: true)
      expect(coverage_entries(dashboard).first).to eq("Sign in Backlog")
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

    context "with one scenario passed and one failed" do
      before { create(:scenario_execution, scenario: scenarios.second, user: user, status: "failed") }

      it "shows the pass rate of the tested scenarios, and how many were tested" do
        expect(main_text(dashboard)).to include("Pass Rate 50% of 2 tested scenarios")
      end

      it "counts every scenario in the legend" do
        expect(main_text(dashboard)).to include("1 passed 1 failed 2 Untested")
      end
    end

    context "with a scenario whose latest run is pending" do
      before { create(:scenario_execution, scenario: scenarios.second, user: user, status: "pending") }

      it "counts it as untested" do
        expect(main_text(dashboard)).to include("1 passed 0 failed 3 Untested")
      end
    end
  end

  context "when the only run recorded is pending" do
    before { create(:scenario_execution, scenario: scenarios.first, user: user, status: "pending") }

    it "says no scenario has passed or failed instead of showing a rate" do
      page = dashboard
      health = page.css("span").find { |span| span.text.squish == "Pass Rate" }.ancestors("div.rounded-xl").first
      expect(main_text(page)).to include("Pass Rate No scenario has passed or failed yet")
      expect(health.text).not_to include("%")
    end
  end

  context "with a scenario that passed the week before" do
    before do
      scenarios.first.update!(created_at: 20.days.ago)
      create(:scenario_execution, scenario: scenarios.first, user: user, status: "passed", executed_at: 10.days.ago)
      create(:scenario_execution, scenario: scenarios.second, user: user, status: "failed")
    end

    it "compares this week's rate of tested scenarios with last week's" do
      text = main_text(dashboard)
      expect(text).to include("-50%")
      expect(text).to include("was 100%")
    end

    it "leaves backlog scenarios out of last week's rate" do
      in_backlog = create(:scenario, :backlog, feature: prices, created_at: 20.days.ago)
      create(:scenario_execution, scenario: in_backlog, user: user, status: "failed", executed_at: 10.days.ago)
      expect(main_text(dashboard)).to include("was 100%")
    end
  end

  context "with scenarios in the backlog" do
    before do
      create(:scenario_execution, scenario: scenarios.first, user: user, status: "passed")
      create(:scenario_execution, scenario: create(:scenario, :backlog, feature: prices), user: user, status: "failed")
      scenarios.last.update!(backlog: true)
    end

    it "rates only the scenarios out of the backlog, and says how many are in it" do
      text = main_text(dashboard)
      expect(text).to include("Pass Rate 100% of 1 tested scenario")
      expect(text).to include("2 in backlog")
    end

    it "leaves them out of the legend and the scenario count" do
      text = main_text(dashboard)
      expect(text).to include("1 passed 0 failed 2 Untested")
      expect(text).to include("3 scenarios across 4 features")
    end

    it "leaves a failed backlog scenario out of Failing Tests" do
      expect(main_text(dashboard)).to include("All tests are passing!")
    end

    it "shows a feature with only backlog scenarios as Backlog, and counts the rest" do
      expect(coverage_entries(dashboard)).to eq([
        "Sign in Backlog",
        "## Catalog",
        "Prices 1 scenarios 1 pending 1 in backlog",
        "## Ordering › Suggested orders",
        "Case sizes 1 scenarios 1 pending",
        "Reorder from history 1 scenarios 1 passed"
      ])
    end
  end

  context "with every scenario in the backlog" do
    before do
      create(:scenario_execution, scenario: scenarios.first, user: user, status: "passed")
      scenarios.each { |scenario| scenario.update!(backlog: true) }
    end

    it "says no scenario has passed or failed, and how many are in the backlog" do
      text = main_text(dashboard)
      expect(text).to include("Pass Rate No scenario has passed or failed yet")
      expect(text).to include("4 in backlog")
    end
  end

  context "with an empty backlog" do
    before { create(:scenario_execution, scenario: scenarios.first, user: user, status: "passed") }

    it "says nothing about a backlog" do
      expect(main_text(dashboard)).not_to include("in backlog")
    end
  end
end
