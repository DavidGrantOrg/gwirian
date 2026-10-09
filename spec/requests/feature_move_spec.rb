require "rails_helper"

RSpec.describe "Moving a feature between folders on the page", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace, name: "Liquor Lodge") }
  let(:role) { "editor" }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: role) }
  let(:base) { "/#{workspace.slug}/projects/#{project.id}" }
  let(:htmx) { { "HX-Request" => "true" } }

  before { sign_in_as(user) }

  def squish(node)
    node.text.squish
  end

  def feature_page(feature)
    get "#{base}/features/#{feature.id}"
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  def crumbs(doc)
    doc.at_css("nav[aria-label='Breadcrumb']")&.css("li")&.map { |li| squish(li) }
  end

  context "in a project with no folders" do
    let!(:feature) { create(:feature, project: project, title: "Sign in") }

    it "shows the feature page as before, with no breadcrumb or folder choice" do
      doc = feature_page(feature)
      expect(crumbs(doc)).to be_nil
      expect(doc.at_css("select[aria-label='Folder']")).to be_nil
    end

    it "offers no Move to… on the card" do
      get "#{base}/features"
      expect(Nokogiri::HTML(response.body).text).not_to include("Move to…")
    end
  end

  context "in a project with folders" do
    let!(:ordering) { create(:folder, project: project, name: "Ordering") }
    let!(:suggested) { create(:folder, project: project, parent: ordering, name: "Suggested orders") }
    let!(:catalog) { create(:folder, project: project, name: "Catalog") }
    let!(:feature) { create(:feature, project: project, title: "Reorder", folder: suggested) }

    describe "the move action" do
      it "moves a feature into a folder" do
        patch "#{base}/features/#{feature.id}/move", params: { folder_id: catalog.id }

        expect(response).to redirect_to("#{base}/features/#{feature.id}")
        expect(crumbs(feature_page(feature))).to eq([ "Liquor Lodge", "Catalog", "Reorder" ])
      end

      it "moves a feature to Unfiled when the folder is empty" do
        patch "#{base}/features/#{feature.id}/move", params: { folder_id: "" }

        expect(crumbs(feature_page(feature))).to eq([ "Liquor Lodge", "Reorder" ])
      end

      it "answers htmx with the header, its breadcrumb updated" do
        patch "#{base}/features/#{feature.id}/move", params: { folder_id: catalog.id }, headers: htmx

        expect(response).to have_http_status(:ok)
        expect(crumbs(Nokogiri::HTML(response.body))).to eq([ "Liquor Lodge", "Catalog", "Reorder" ])
      end

      it "refuses another project's folder" do
        other = create(:folder, project: create(:project, workspace: workspace))

        patch "#{base}/features/#{feature.id}/move", params: { folder_id: other.id }, headers: htmx

        expect(response).to have_http_status(:unprocessable_entity)
        expect(crumbs(feature_page(feature))).to eq([ "Liquor Lodge", "Ordering", "Suggested orders", "Reorder" ])
      end

      context "as a viewer" do
        let(:role) { "viewer" }

        it "is refused" do
          expect { patch "#{base}/features/#{feature.id}/move", params: { folder_id: "" } }.to raise_error(CanCan::AccessDenied)
        end
      end
    end

    describe "the feature page" do
      it "shows the breadcrumb ending in the feature's title" do
        expect(crumbs(feature_page(feature))).to eq([ "Liquor Lodge", "Ordering", "Suggested orders", "Reorder" ])
      end

      it "offers a Folder drop-down of Unfiled and every folder by its path, saving on change" do
        select = feature_page(feature).at_css("select[aria-label='Folder']")

        expect(select["name"]).to eq("folder_id")
        expect(select["hx-patch"]).to eq("#{base}/features/#{feature.id}/move")
        expect(select["hx-trigger"]).to eq("change")
        options = select.css("option").map { |o| [ squish(o), o["value"] ] }
        expect(options).to eq([
          [ "Unfiled", "" ], [ "Catalog", catalog.id.to_s ], [ "Ordering", ordering.id.to_s ],
          [ "Ordering › Suggested orders", suggested.id.to_s ]
        ])
        expect(squish(select.at_css("option[selected]"))).to eq("Ordering › Suggested orders")
      end

      it "steps to the next feature by title across folders" do
        after = create(:feature, project: project, title: "Sign in", folder: catalog)
        get "#{base}/features/#{feature.id}"
        expect(Nokogiri::HTML(response.body).at_css("body")["data-next-feature-url"]).to eq("#{base}/features/#{after.id}")
      end

      context "as a viewer" do
        let(:role) { "viewer" }

        it "shows the breadcrumb but no drop-down" do
          doc = feature_page(feature)
          expect(crumbs(doc)).to eq([ "Liquor Lodge", "Ordering", "Suggested orders", "Reorder" ])
          expect(doc.at_css("select[aria-label='Folder']")).to be_nil
        end
      end
    end

    describe "Move to… in a card's menu" do
      it "offers Unfiled and every other folder, and drops the card out once moved" do
        get "#{base}/features", params: { folder: suggested.id }
        card = Nokogiri::HTML(response.body).css("#features h3").find { |h| squish(h) == "Reorder" }.ancestors("[data-feature-card]").first
        menu = card.at_css("[role='menu'][aria-label='Move to']")

        choices = menu.css("button").map { |b| [ squish(b), JSON.parse(b["hx-vals"])["folder_id"] ] }
        expect(choices).to eq([ [ "Unfiled", "" ], [ "Catalog", catalog.id.to_s ], [ "Ordering", ordering.id.to_s ] ])
        button = menu.at_css("button")
        expect(button["hx-patch"]).to eq("#{base}/features/#{feature.id}/move")
        expect(button["hx-target"]).to eq("closest [data-feature-card]")
        expect(button["hx-swap"]).to eq("delete")
      end
    end
  end
end
