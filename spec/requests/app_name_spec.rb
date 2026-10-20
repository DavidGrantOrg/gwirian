require "rails_helper"

RSpec.describe "App name", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }

  before { sign_in_as(user) }

  def navbar_label
    Nokogiri::HTML(response.body).at_css("nav a:has(img[src='/logo.svg']) span").text
  end

  it "shows Gwirian in the navbar when APP_NAME is unset" do
    get "/#{workspace.slug}/projects"

    expect(navbar_label).to eq("Gwirian")
  end

  it "shows APP_NAME in the navbar when it is set", env: { "APP_NAME" => "Playbook" } do
    get "/#{workspace.slug}/projects"

    expect(navbar_label).to eq("Playbook")
  end
end
