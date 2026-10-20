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

  it "names the navbar logo and gives the label its full name as a title", env: { "APP_NAME" => "Playbook" } do
    get "/#{workspace.slug}/projects"

    link = Nokogiri::HTML(response.body).at_css("nav a:has(img[src='/logo.svg'])")
    expect(link.at_css("img")["alt"]).to eq("Playbook Logo")
    expect(link.at_css("span")["title"]).to eq("Playbook")
  end

  it "welcomes a new user to APP_NAME on the projects page", env: { "APP_NAME" => "Playbook" } do
    workspace_member.update!(role: "administrator")

    get "/#{workspace.slug}/projects"

    expect(response.body).to include("New to Playbook?")
  end

  describe "the sign-in page" do
    before { Current.session = nil }

    it "says Gwirian when APP_NAME is unset" do
      get "/session/new"

      expect(Nokogiri::HTML(response.body).at_css("title").text).to eq("Gwirian")
    end

    it "says APP_NAME in its title and logos, and never Gwirian, when it is set", env: { "APP_NAME" => "Playbook" } do
      get "/session/new"

      page = Nokogiri::HTML(response.body)
      expect(page.at_css("title").text).to eq("Playbook")
      expect(page.css(".hidden.lg\\:block span, .auth-logo-section span").map(&:text)).to eq([ "Playbook", "Playbook" ])
      expect(response.body).not_to include("Gwirian")
    end
  end
end
