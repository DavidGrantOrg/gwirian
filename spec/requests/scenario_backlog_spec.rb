require "rails_helper"

RSpec.describe "Scenarios in the backlog", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: "editor") }
  let(:base) { "/#{workspace.slug}/projects/#{project.id}" }
  let!(:feature) { create(:feature, project: project, title: "Suggested orders") }
  let!(:built) { create(:scenario, feature: feature, title: "Order a full case") }
  let!(:unbuilt) { create(:scenario, :backlog, feature: feature, title: "Order singles from a pack") }

  before { sign_in_as(user) }

  def page_at(path)
    get path
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  def row_text(page, scenario)
    page.at_css("#scenario-wrapper-#{scenario.id}").text.squish
  end

  describe "the feature page" do
    it "shows a Backlog badge on a backlog scenario's row only" do
      page = page_at("#{base}/features/#{feature.id}")
      expect(row_text(page, unbuilt)).to include("Backlog")
      expect(row_text(page, built)).not_to include("Backlog")
    end

    context "when NEW_SCENARIOS is backlog" do
      around do |example|
        previous = ENV["NEW_SCENARIOS"]
        ENV["NEW_SCENARIOS"] = "backlog"
        example.run
      ensure
        ENV["NEW_SCENARIOS"] = previous
      end

      it "puts a scenario added on the page in the backlog" do
        post "#{base}/features/#{feature.id}/scenarios"
        added = feature.scenarios.order(:id).last
        expect(row_text(page_at("#{base}/features/#{feature.id}"), added)).to include("Backlog")
      end
    end
  end

  describe "the feature card" do
    it "counts the scenarios out of the backlog, and lists the backlog apart" do
      card = page_at("#{base}/features").css("a").find { |a| a.text.include?("Suggested orders") }.text.squish
      expect(card).to include("1 scenario 1 Pending 1 Backlog")
    end

    it "lists only the backlog for a feature whose scenarios are all in it" do
      built.update!(backlog: true)
      card = page_at("#{base}/features").css("a").find { |a| a.text.include?("Suggested orders") }.text.squish
      expect(card).to include("2 Backlog")
      expect(card).not_to include("scenario")
    end
  end

  describe "a manual run" do
    it "offers only the scenarios out of the backlog" do
      text = page_at("#{base}/features/#{feature.id}/select_scenarios").at_css("main").text
      expect(text).to include("Order a full case")
      expect(text).not_to include("Order singles from a pack")
    end

    it "drops a backlog scenario submitted for the run" do
      post "#{base}/features/#{feature.id}/select_scenarios", params: { scenario_ids: [ built.id, unbuilt.id ] }
      text = page_at("#{base}/features/#{feature.id}/execute_scenarios").at_css("main").text
      expect(text).to include("Order a full case")
      expect(text).not_to include("Order singles from a pack")
    end

    it "records no result for a backlog scenario" do
      post "#{base}/features/#{feature.id}/execute_scenarios",
        params: { executions: { built.id => { status: "passed" }, unbuilt.id => { status: "passed" } } }
      # No page lists a backlog scenario's runs apart from its feature's, so this reads the rows.
      expect(ScenarioExecution.where(scenario: [ built, unbuilt ]).pluck(:scenario_id)).to eq([ built.id ])
    end
  end
end
