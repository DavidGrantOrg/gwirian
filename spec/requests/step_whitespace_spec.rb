require "rails_helper"

# The fields save their innerText, which follows CSS white-space: without pre-wrap the
# browser shows a stored line break as a space and the next blur saves it that way.
RSpec.describe "Line breaks and spaces in editable feature fields", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: "editor") }
  let(:feature) { create(:feature, project: project, description: "first line\nsecond line") }

  before do
    sign_in_as(user)
    create(:scenario, feature: feature, given: "given one\ngiven two", when: "when one\nwhen two", then: "then one\nthen two")
  end

  def field_containing(text)
    get "/#{workspace.slug}/projects/#{project.id}/features/#{feature.id}"
    Nokogiri::HTML(response.body).css("[contenteditable]").find { |node| node.text.include?(text) }
  end

  [ "first line", "given one", "when one", "then one" ].each do |text|
    it "keeps line breaks and spaces in the field showing #{text.inspect}" do
      expect(field_containing(text)["class"].split).to include("whitespace-pre-wrap")
    end
  end
end
