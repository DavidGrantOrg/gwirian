require "rails_helper"

RSpec.describe "Feature background on the feature page", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: "editor") }

  def feature_url(feature)
    "/#{workspace.slug}/projects/#{project.id}/features/#{feature.id}"
  end

  before { sign_in_as(user) }

  it "shows the background's steps" do
    feature = create(:feature, project: project, background: "the store is open\nthe shelf is empty")

    get feature_url(feature)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Background")
    field = Nokogiri::HTML(response.body).css("[contenteditable]").find { |node| node.text.include?("the store is open") }
    expect(field.children.map(&:text)).to eq([ "the store is open", "the shelf is empty" ])
  end

  it "offers to add a background when the feature has none" do
    feature = create(:feature, project: project, background: nil)

    get feature_url(feature)

    expect(response.body).to include("Add a background...")
  end

  it "saves a background edited on the page" do
    feature = create(:feature, project: project)

    patch feature_url(feature), params: { feature: { background: "the store is open" } }, headers: { "HX-Request" => "true" }
    expect(response).to have_http_status(:ok)

    get feature_url(feature)
    expect(response.body).to include("the store is open")
  end
end
