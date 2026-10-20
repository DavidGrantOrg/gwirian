require "rails_helper"

RSpec.describe "Feature and scenario numbers", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: "editor") }
  let(:base) { "/#{workspace.slug}/projects/#{project.id}" }
  # The decoys give the feature and the scenario different ids, so a number taken from the wrong record shows.
  let!(:decoy) { create(:feature, project: project, title: "Stellar sync") }
  let!(:feature) { create(:feature, project: project, title: "Suggested orders") }
  let!(:decoy_scenarios) { create_list(:scenario, 2, feature: decoy) }
  let!(:scenario) { create(:scenario, feature: feature, title: "Order a full case") }

  before do
    expect(scenario.id).not_to eq(feature.id)
    sign_in_as(user)
  end

  def page_at(path)
    get path
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  it "shows the feature's number on its card" do
    card = page_at("#{base}/features").css("[data-feature-card]").find { |c| c.at_css("h3").text.squish == "Suggested orders" }
    expect(card).not_to be_nil
    expect(card.text.squish).to include("F#{feature.id} Suggested orders")
  end

  describe "the feature page" do
    let(:page) { page_at("#{base}/features/#{feature.id}") }

    it "shows the feature's number beside its title" do
      expect(page.at_css("[data-feature-header]").text.squish).to include("F#{feature.id} Suggested orders")
    end

    it "shows each scenario's number beside its title" do
      expect(page.at_css("#scenario-wrapper-#{scenario.id}").text.squish).to include("S#{scenario.id} Order a full case")
    end

    # An edited title is saved from its heading's text, so a number inside it would be saved too.
    it "keeps the numbers out of the editable titles" do
      expect(page.css("[contenteditable]").map { |e| e.text.strip }).to include("Suggested orders", "Order a full case")
    end
  end
end
