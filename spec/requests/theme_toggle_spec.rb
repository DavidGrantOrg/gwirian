require "rails_helper"

RSpec.describe "Theme toggle", type: :request do
  let(:user) { create(:user) }

  it "offers System, Light and Dark in the user menu" do
    sign_in_as(user)

    get "/"

    menu = Nokogiri::HTML(response.body).at_css("nav [role=menu]")
    choices = menu.css("[role=radiogroup][aria-label=Theme] [role=radio]").map { |radio| radio.text.strip }
    expect(choices).to eq([ "System", "Light", "Dark" ])
  end

  [ [ "a signed-in page", "/" ], [ "the sign-in page", "/session/new" ] ].each do |page_name, path|
    it "applies the saved theme on #{page_name} before the stylesheet loads" do
      sign_in_as(user) if path == "/"

      get path

      nodes = Nokogiri::HTML(response.body).at_css("head").element_children
      theme_script = nodes.index { |node| node.name == "script" && node.text.include?("dataset.theme") }
      stylesheet = nodes.index { |node| node.name == "link" && node["rel"] == "stylesheet" && node["href"].start_with?("/assets/") }
      expect(theme_script).to be < stylesheet
    end
  end
end
