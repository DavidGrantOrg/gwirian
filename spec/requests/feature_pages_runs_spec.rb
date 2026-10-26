require "rails_helper"

RSpec.describe "Feature pages as runs are recorded", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: "editor") }
  let(:base) { "/#{workspace.slug}/projects/#{project.id}" }
  let!(:feature) { create(:feature, project: project) }
  let!(:scenarios) { create_list(:scenario, 2, feature: feature) }

  before { sign_in_as(user) }

  def record_runs
    scenarios.each { |scenario| create_list(:scenario_execution, 3, scenario: scenario, user: user, status: "passed") }
  end

  def runs_read_by_get(path)
    records_instantiated("ScenarioExecution") do
      get path
      expect(response).to have_http_status(:ok)
    end
  end

  it "reads no more runs on the features page" do
    record_runs
    before = runs_read_by_get("#{base}/features")
    record_runs
    expect(runs_read_by_get("#{base}/features")).to eq(before)
  end

  it "reads no more runs re-listing the features after one is trashed from its card" do
    trash_one = lambda do
      records_instantiated("ScenarioExecution") do
        delete "#{base}/features/#{create(:feature, project: project).id}", headers: { "HX-Request" => "true" }
        expect(response).to have_http_status(:ok)
      end
    end
    record_runs
    before = trash_one.call
    record_runs
    expect(trash_one.call).to eq(before)
  end
end
