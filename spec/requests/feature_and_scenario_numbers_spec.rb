require "rails_helper"

RSpec.describe "Feature and scenario numbers", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: "editor") }
  let(:base) { "/#{workspace.slug}/projects/#{project.id}" }
  let!(:feature) { create(:feature, project: project, title: "Suggested orders") }
  let!(:scenario) { create(:scenario, feature: feature, title: "Order a full case") }

  before { sign_in_as(user) }

  def page_at(path)
    get path
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  it "shows the feature's number on its card" do
    card = page_at("#{base}/features").css("a").find { |a| a.text.include?("Suggested orders") }.text.squish
    expect(card).to include("F#{feature.id} Suggested orders")
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
