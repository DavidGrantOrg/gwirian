require "rails_helper"

RSpec.describe "Folder actions on the features page", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace, name: "Liquor Lodge") }
  let(:role) { "editor" }
  let!(:project_member) { create(:project_member, project: project, email: user.email_address, role: role) }
  let(:features_path) { "/#{workspace.slug}/projects/#{project.id}/features" }
  let(:folders_path) { "/#{workspace.slug}/projects/#{project.id}/folders" }
  let(:htmx) { { "HX-Request" => "true" } }

  before { sign_in_as(user) }

  def page(params = {})
    get features_path, params: params
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  def squish(node)
    node.text.squish
  end

  def heading(doc)
    doc.at_css("#features-container h2")
  end

  def form_for_button(doc, label)
    doc.css("form").find { |form| form.css("button, input[type='submit']").any? { |b| squish(b) == label || b["value"] == label } }
  end

  def hidden(form, name)
    form.at_css("input[name='#{name}']")&.[]("value")
  end

  describe "New folder" do
    it "is offered beside New feature in a project with no folders, creating at the top" do
      form = form_for_button(page, "New folder")
      expect(form["action"]).to eq(folders_path)
      expect(hidden(form, "folder[parent_id]")).to eq("")
      expect(form_for_button(page, "New feature")).to be_present
    end

    it "creates inside the folder being shown" do
      ordering = create(:folder, project: project, name: "Ordering")
      form = form_for_button(page(folder: ordering.id), "New folder")
      expect(hidden(form, "folder[parent_id]")).to eq(ordering.id.to_s)
    end

    it "opens the new folder named New folder, with the cursor in its heading" do
      ordering = create(:folder, project: project, name: "Ordering")

      post folders_path, params: { folder: { parent_id: ordering.id } }

      created = Folder.find_by!(name: "New folder")
      expect(response).to redirect_to("#{features_path}?folder=#{created.id}")
      follow_redirect!
      doc = Nokogiri::HTML(response.body)
      expect(squish(heading(doc))).to eq("New folder")
      expect(heading(doc)["autofocus"]).not_to be_nil
      expect(doc.at_css("nav[aria-label='Breadcrumb']").css("li").map { |li| squish(li) }).to eq([ "Liquor Lodge", "Ordering", "New folder" ])
    end

    it "numbers a second new folder beside the first" do
      create(:folder, project: project, name: "New folder")
      post folders_path, params: { folder: { parent_id: "" } }
      follow_redirect!
      expect(squish(heading(Nokogiri::HTML(response.body)))).to eq("New folder 2")
    end

    it "only focuses the heading on the visit that created it" do
      post folders_path, params: { folder: { parent_id: "" } }
      follow_redirect!
      get request.fullpath
      expect(heading(Nokogiri::HTML(response.body))["autofocus"]).to be_nil
    end
  end

  context "with a folder open" do
    let!(:ordering) { create(:folder, project: project, name: "Ordering") }
    let!(:suggested) { create(:folder, project: project, parent: ordering, name: "Suggested orders") }
    let!(:history) { create(:folder, project: project, parent: suggested, name: "History") }
    let!(:catalog) { create(:folder, project: project, name: "Catalog") }

    describe "renaming in place" do
      it "makes the heading editable, saving the name to the folder" do
        h2 = heading(page(folder: suggested.id))
        expect(h2["contenteditable"]).to eq("true")
        form = h2.parent.at_css("form")
        expect(form.at_css("input[name='folder[name]']")).to be_present
      end

      it "saves, updating the heading and the tree together" do
        patch "#{folders_path}/#{suggested.id}", params: { folder: { name: "Suggestions" } }, headers: htmx

        expect(response).to have_http_status(:ok)
        doc = Nokogiri::HTML(response.body)
        expect(squish(doc.at_css("h2"))).to eq("Suggestions")
        tree = doc.at_css("[hx-swap-oob] nav[aria-label='Folders']")
        expect(tree.css("[role='treeitem'] a").map { |a| squish(a) }).to include("Suggestions 0")

        expect(squish(heading(page(folder: suggested.id)))).to eq("Suggestions")
      end

      it "keeps the old name and says why when the new one is taken" do
        patch "#{folders_path}/#{catalog.id}", params: { folder: { name: "ordering" } }, headers: htmx

        doc = Nokogiri::HTML(response.body)
        expect(squish(doc.at_css("h2"))).to eq("Catalog")
        expect(squish(doc.at_css("[role='alert']"))).to eq("Name is already used by another folder here")
        expect(doc.at_css("[hx-swap-oob]")).to be_nil
        expect(squish(heading(page(folder: catalog.id)))).to eq("Catalog")
      end
    end

    describe "Move to…" do
      def move_menu(doc)
        doc.at_css("[role='menu'][aria-label='Move to']")
      end

      it "lists the top level and every folder but the folder itself and its sub-folders" do
        menu = move_menu(page(folder: suggested.id))

        choices = menu.css("form").map { |form| [ squish(form.at_css("button")), hidden(form, "folder[parent_id]") ] }
        expect(choices).to eq([ [ "Liquor Lodge", "" ], [ "Catalog", catalog.id.to_s ], [ "Ordering", ordering.id.to_s ] ])
        expect(menu.css("form").map { |form| form["action"] }.uniq).to eq([ "#{folders_path}/#{suggested.id}" ])
      end

      it "moves the folder and opens it in its new place" do
        patch "#{folders_path}/#{suggested.id}", params: { folder: { parent_id: catalog.id } }

        expect(response).to redirect_to("#{features_path}?folder=#{suggested.id}")
        follow_redirect!
        crumbs = Nokogiri::HTML(response.body).at_css("nav[aria-label='Breadcrumb']").css("li").map { |li| squish(li) }
        expect(crumbs).to eq([ "Liquor Lodge", "Catalog", "Suggested orders" ])
      end

      it "moves the folder to the top level" do
        patch "#{folders_path}/#{suggested.id}", params: { folder: { parent_id: "" } }
        follow_redirect!
        crumbs = Nokogiri::HTML(response.body).at_css("nav[aria-label='Breadcrumb']").css("li").map { |li| squish(li) }
        expect(crumbs).to eq([ "Liquor Lodge", "Suggested orders" ])
      end

      it "refuses a move inside its own sub-folder and says why" do
        patch "#{folders_path}/#{ordering.id}", params: { folder: { parent_id: history.id } }

        expect(response).to redirect_to("#{features_path}?folder=#{ordering.id}")
        expect(flash[:alert]).to eq("Parent can't be the folder itself or one of its sub-folders")
      end
    end

    describe "Delete folder" do
      def delete_button(doc)
        doc.css("button").find { |b| squish(b) == "Delete folder" }
      end

      it "asks first, saying where the contents go" do
        button = delete_button(page(folder: suggested.id))
        expect(button["hx-delete"]).to eq("#{folders_path}/#{suggested.id}")
        expect(button["x-on:click.prevent"]).to include("Delete Suggested orders? Its features and sub-folders will move to Ordering.")
      end

      it "names the project when the contents go to the top" do
        button = delete_button(page(folder: ordering.id))
        expect(button["x-on:click.prevent"]).to include("Delete Ordering? Its features and sub-folders will move to Liquor Lodge.")
      end

      it "deletes the folder and opens its parent, which now holds its contents" do
        create(:feature, project: project, title: "Reorder", folder: suggested)

        delete "#{folders_path}/#{suggested.id}", headers: htmx

        expect(response.headers["HX-Redirect"]).to eq("#{features_path}?folder=#{ordering.id}")
        doc = page(folder: ordering.id)
        expect(doc.at_css("[aria-label='Sub-folders']").css("a").map { |a| squish(a) }).to eq([ "History" ])
        expect(doc.css("#features h3").map { |h| squish(h) }).to eq([ "Reorder" ])
      end

      it "opens the top level after deleting a top-level folder" do
        delete "#{folders_path}/#{catalog.id}", headers: htmx
        expect(response.headers["HX-Redirect"]).to eq(features_path)
      end

      it "stays on the folder and says why when the delete is refused" do
        create(:folder, project: project, parent: ordering, name: "History")

        delete "#{folders_path}/#{suggested.id}", headers: htmx

        expect(response.headers["HX-Redirect"]).to eq("#{features_path}?folder=#{suggested.id}")
        expect(flash[:alert]).to eq("Can't delete Suggested orders: Ordering already has a folder named History")
      end
    end

    context "as a viewer" do
      let(:role) { "viewer" }

      it "shows no folder actions" do
        doc = page(folder: suggested.id)
        expect(heading(doc)["contenteditable"]).to be_nil
        expect(doc.at_css("[role='menu'][aria-label='Move to']")).to be_nil
        expect(doc.css("button").map { |b| squish(b) }).not_to include("Delete folder", "Move to…", "New folder")
      end

      it "may not create, change or delete a folder" do
        expect { post folders_path, params: { folder: { parent_id: "" } } }.to raise_error(CanCan::AccessDenied)
        expect { patch "#{folders_path}/#{ordering.id}", params: { folder: { name: "X" } } }.to raise_error(CanCan::AccessDenied)
        expect { delete "#{folders_path}/#{ordering.id}" }.to raise_error(CanCan::AccessDenied)
      end
    end
  end
end
