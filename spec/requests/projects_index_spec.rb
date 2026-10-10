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

    it "shows the success rate" do
      expect(card_text).to include("25% success rate")
    end

    it "counts passed, failed and pending scenarios" do
      expect(card_text).to include("success rate 1 1 2")
      expect(card_text).to include("4 scenarios")
      expect(card_text).to include("1 failed")
    end
  end
end
