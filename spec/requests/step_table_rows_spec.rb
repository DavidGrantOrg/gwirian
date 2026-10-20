require "rails_helper"

# A field saves its innerText, so any text node between the line blocks would end up
# in the saved step.
RSpec.describe "Table rows in step fields", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: "editor") }
  let(:steps) { "price changes list\n| SKU    | Change |\n\n| 100234 | +$1.50 |" }

  before { sign_in_as(user) }

  def field_containing(feature, text)
    get "/#{workspace.slug}/projects/#{project.id}/features/#{feature.id}"
    Nokogiri::HTML(response.body).css("[contenteditable]").find { |node| node.text.include?(text) }
  end

  def lines_of(field)
    field.children.map { |line| [ line.name, line.text, line["class"].to_s.split.include?("font-mono") ] }
  end

  it "draws a scenario step one line per block, table rows in a fixed-width font" do
    feature = create(:feature, project: project)
    create(:scenario, feature: feature, given: steps)

    expect(lines_of(field_containing(feature, "price changes list"))).to eq([
      [ "div", "price changes list", false ],
      [ "div", "| SKU    | Change |", true ],
      [ "div", "", false ],
      [ "div", "| 100234 | +$1.50 |", true ]
    ])
  end

  it "draws a background the same way" do
    feature = create(:feature, project: project, background: steps)

    expect(lines_of(field_containing(feature, "price changes list"))).to eq([
      [ "div", "price changes list", false ],
      [ "div", "| SKU    | Change |", true ],
      [ "div", "", false ],
      [ "div", "| 100234 | +$1.50 |", true ]
    ])
  end

  it "keeps a blank line's height so it survives the next save" do
    feature = create(:feature, project: project)
    create(:scenario, feature: feature, given: steps)

    blank = field_containing(feature, "price changes list").children[2]
    expect(blank.children.map(&:name)).to eq([ "br" ])
  end
end
