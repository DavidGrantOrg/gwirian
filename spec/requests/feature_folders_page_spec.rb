require "rails_helper"

RSpec.describe "Folders on the features page", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace, name: "Liquor Lodge") }
  let(:role) { "editor" }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: role) }

  before { sign_in_as(user) }

  def features_page(params = {})
    get "/#{workspace.slug}/projects/#{project.id}/features", params: params
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  def squish(node)
    node.text.squish
  end

  def card_titles(page)
    page.css("#features h3").map { |h| squish(h) }
  end

  def tree(page)
    page.at_css("nav[aria-label='Folders']")
  end

  def tree_item(page, name)
    tree(page).css("[role='treeitem']").find { |item| squish(item.at_css("a")).start_with?(name) }
  end

  context "in a project with no folders" do
    let!(:checkout) { create(:feature, project: project, title: "Checkout") }
    let!(:login) { create(:feature, project: project, title: "Login") }

    it "lists every feature with no folder tree" do
      page = features_page
      expect(tree(page)).to be_nil
      expect(card_titles(page)).to eq([ "Checkout", "Login" ])
    end
  end

  context "in a project with folders" do
    let!(:ordering) { create(:folder, project: project, name: "Ordering") }
    let!(:suggested) { create(:folder, project: project, parent: ordering, name: "Suggested orders") }
    let!(:history) { create(:folder, project: project, parent: suggested, name: "History") }
    let!(:catalog) { create(:folder, project: project, name: "Catalog") }
    let!(:reorder) { create(:feature, project: project, title: "Reorder from history", folder: suggested) }
    let!(:sizes) { create(:feature, project: project, title: "Case sizes", folder: suggested) }
    let!(:prices) { create(:feature, project: project, title: "Prices", folder: catalog) }
    let!(:sign_in) { create(:feature, project: project, title: "Sign in") }

    it "shows the tree with the project as its root and folders by name, each with its own feature count" do
      nav = tree(features_page)

      root = nav.at_css("[role='tree'] > [role='treeitem']")
      expect(squish(root.at_css("a"))).to eq("Liquor Lodge")
      top = root.css("> [role='group'] > [role='treeitem']")
      expect(top.map { |item| squish(item.at_css("a")) }).to eq([ "Catalog 1", "Ordering 0" ])
      ordering_item = top[1]
      expect(ordering_item.css("[role='group'] [role='treeitem'] a").map { |a| squish(a) }).to eq([ "Suggested orders 2", "History 0" ])
    end

    it "opens the selected folder's parents and marks it as current" do
      page = features_page(folder: history.id)

      expect(tree_item(page, "Ordering")["aria-expanded"]).to eq("true")
      expect(tree_item(page, "Suggested orders")["aria-expanded"]).to eq("true")
      expect(tree_item(page, "History").at_css("a")["aria-current"]).to eq("page")
      expect(tree(page).css("[aria-current='page']").size).to eq(1)
    end

    it "starts other folders closed" do
      page = features_page(folder: catalog.id)
      expect(tree_item(page, "Ordering")["aria-expanded"]).to eq("false")
    end

    it "shows a folder's breadcrumb, name, sub-folders and then its features" do
      page = features_page(folder: suggested.id)

      crumbs = page.at_css("nav[aria-label='Breadcrumb']")
      expect(crumbs.css("li").map { |li| squish(li) }).to eq([ "Liquor Lodge", "Ordering", "Suggested orders" ])
      expect(squish(page.at_css("#features-container h2"))).to eq("Suggested orders")
      subfolders = page.at_css("[aria-label='Sub-folders']")
      expect(subfolders.css("a").map { |a| [ squish(a), a["href"] ] }).to eq([ [ "History", "/#{workspace.slug}/projects/#{project.id}/features?folder=#{history.id}" ] ])
      expect(card_titles(page)).to eq([ "Case sizes", "Reorder from history" ])
    end

    it "shows the top-level folders and then the unfiled features at the root" do
      page = features_page

      expect(squish(page.at_css("#features-container h2"))).to eq("Liquor Lodge")
      expect(page.at_css("[aria-label='Sub-folders']").css("a").map { |a| squish(a) }).to eq([ "Catalog", "Ordering" ])
      expect(page.text).to include("Unfiled")
      expect(card_titles(page)).to eq([ "Sign in" ])
    end

    it "searches the whole project from inside a folder and shows each result's folder", search_backend: :database do
      page = features_page(folder: catalog.id, q: "feature")

      cards = page.css("#features h3").to_h { |h3| [ squish(h3), h3.ancestors(".group").first ] }
      expect(cards.keys).to contain_exactly("Reorder from history", "Prices", "Case sizes", "Sign in")
      expect(squish(cards["Reorder from history"].at_css("[aria-label='Folder']"))).to eq("Ordering › Suggested orders")
      expect(squish(cards["Prices"].at_css("[aria-label='Folder']"))).to eq("Catalog")
      expect(cards["Sign in"].at_css("[aria-label='Folder']")).to be_nil
    end

    it "keeps the folder's own features in the list after a card is deleted" do
      delete "/#{workspace.slug}/projects/#{project.id}/features/#{sizes.id}", headers: { "HX-Request" => "true" }

      expect(card_titles(Nokogiri::HTML(response.body))).to eq([ "Reorder from history" ])
    end

    it "does not show another project's folder" do
      other = create(:folder, project: create(:project, workspace: workspace))
      get "/#{workspace.slug}/projects/#{project.id}/features", params: { folder: other.id }
      expect(response).to have_http_status(:not_found)
    end
  end
end
