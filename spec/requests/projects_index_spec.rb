require "rails_helper"

RSpec.describe "Projects index", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace, name: "Liquor Lodge") }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: "editor") }
  let!(:scenarios) { create_list(:scenario, 4, feature: create(:feature, project: project)) }

  before { sign_in_as(user) }

  def card_text
    get "/#{workspace.slug}/projects"
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body).at_css(".project-card").text.squish
  end

  context "with one scenario passed and one failed" do
    before do
      create(:scenario_execution, scenario: scenarios.first, user: user, status: "passed")
      create(:scenario_execution, scenario: scenarios.second, user: user, status: "failed")
    end

    it "shows the success rate of the tested scenarios" do
      expect(card_text).to include("50% success rate")
    end

    it "counts passed, failed and pending scenarios" do
      expect(card_text).to include("success rate 1 1 2")
      expect(card_text).to include("4 scenarios")
      expect(card_text).to include("1 failed")
    end
  end

  context "with a scenario in the backlog" do
    before do
      create(:scenario_execution, scenario: scenarios.first, user: user, status: "passed")
      create(:scenario_execution, scenario: scenarios.second, user: user, status: "failed")
      scenarios.third.update!(backlog: true)
      create(:scenario_execution, scenario: scenarios.third, user: user, status: "failed")
    end

    it "leaves it out of the rate and the counts, and says how many are in the backlog" do
      text = card_text
      expect(text).to include("50% success rate 1 in backlog 1 1 1")
      expect(text).to include("3 scenarios")
      expect(text).to include("1 failed")
    end
  end

  context "with an empty backlog" do
    it "says nothing about a backlog" do
      create(:scenario_execution, scenario: scenarios.first, user: user, status: "passed")
      expect(card_text).not_to include("in backlog")
    end
  end

  context "before any scenario has passed or failed" do
    before { create(:scenario_execution, scenario: scenarios.first, user: user, status: "pending") }

    it "shows no success rate" do
      expect(card_text).to include("No executions yet")
      expect(card_text).not_to include("%")
    end
  end
end
