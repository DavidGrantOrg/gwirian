require "rails_helper"

RSpec.describe "Api::V1::Folders", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, :with_api_token, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let(:headers) { api_headers(workspace_member.api_token) }
  let(:base) { "/api/v1/projects/#{project.id}/folders" }

  def as(role)
    create(:project_member, project: project, email: user.email_address, role: role)
  end

  describe "GET index" do
    it "is refused without a token" do
      get base
      expect(response).to have_http_status(:unauthorized)
    end

    it "lists the project's folders with their parents" do
      as("viewer")
      ordering = create(:folder, project: project, name: "Ordering")
      child = create(:folder, project: project, parent: ordering, name: "Suggested orders")
      create(:folder, project: create(:project, workspace: workspace), name: "Elsewhere")

      get base, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.map { |f| f.slice("id", "name", "parent_id", "project_id") }).to contain_exactly(
        { "id" => ordering.id, "name" => "Ordering", "parent_id" => nil, "project_id" => project.id },
        { "id" => child.id, "name" => "Suggested orders", "parent_id" => ordering.id, "project_id" => project.id }
      )
      expect(json_response.first).to include("created_at", "updated_at")
    end
  end

  describe "GET show" do
    it "returns one folder" do
      as("viewer")
      folder = create(:folder, project: project, name: "Ordering")
      get "#{base}/#{folder.id}", headers: headers
      expect(json_response).to include("id" => folder.id, "name" => "Ordering", "parent_id" => nil)
    end

    it "does not find another project's folder" do
      as("viewer")
      other = create(:folder, project: create(:project, workspace: workspace))
      get "#{base}/#{other.id}", headers: headers
      expect(response).to have_http_status(:not_found)
      expect(json_response["error"]).to eq("Folder not found")
    end
  end

  describe "POST create" do
    it "is refused to a viewer" do
      as("viewer")
      post base, params: { folder: { name: "Ordering" } }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it "creates a top-level folder" do
      as("editor")
      post base, params: { folder: { name: "Ordering" } }, headers: headers
      expect(response).to have_http_status(:created)
      get "#{base}/#{json_response["id"]}", headers: headers
      expect(json_response).to include("name" => "Ordering", "parent_id" => nil)
    end

    it "creates a folder inside another" do
      as("editor")
      parent = create(:folder, project: project)
      post base, params: { folder: { name: "Suggested orders", parent_id: parent.id } }, headers: headers
      expect(response).to have_http_status(:created)
      expect(json_response["parent_id"]).to eq(parent.id)
    end

    it "refuses a parent in another project" do
      as("editor")
      other = create(:folder, project: create(:project, workspace: workspace))
      post base, params: { folder: { name: "Ordering", parent_id: other.id } }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to eq([ "Parent must be in the same project" ])
    end

    it "refuses a parent that does not exist" do
      as("editor")
      post base, params: { folder: { name: "Ordering", parent_id: 999_999 } }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to eq([ "Parent must exist" ])
    end

    it "refuses a name already used beside it" do
      as("editor")
      create(:folder, project: project, name: "Ordering")
      post base, params: { folder: { name: "ordering" } }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to eq([ "Name is already used by another folder here" ])
    end
  end

  describe "PATCH update" do
    let!(:ordering) { create(:folder, project: project, name: "Ordering") }
    let!(:catalog) { create(:folder, project: project, name: "Catalog") }

    it "is refused to a viewer" do
      as("viewer")
      patch "#{base}/#{ordering.id}", params: { folder: { name: "Orders" } }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it "renames a folder" do
      as("editor")
      patch "#{base}/#{ordering.id}", params: { folder: { name: "Orders" } }, headers: headers
      expect(response).to have_http_status(:ok)
      get "#{base}/#{ordering.id}", headers: headers
      expect(json_response["name"]).to eq("Orders")
    end

    it "moves a folder under another and back to the top" do
      as("editor")
      patch "#{base}/#{ordering.id}", params: { folder: { parent_id: catalog.id } }, headers: headers, as: :json
      expect(json_response["parent_id"]).to eq(catalog.id)

      patch "#{base}/#{ordering.id}", params: { folder: { parent_id: nil } }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      get "#{base}/#{ordering.id}", headers: headers
      expect(json_response["parent_id"]).to be_nil
    end

    it "leaves the parent alone when only the name is given" do
      as("editor")
      ordering.update!(parent: catalog)
      patch "#{base}/#{ordering.id}", params: { folder: { name: "Orders" } }, headers: headers, as: :json
      expect(json_response["parent_id"]).to eq(catalog.id)
    end

    it "refuses a move inside one of its own sub-folders" do
      as("editor")
      child = create(:folder, project: project, parent: ordering)
      patch "#{base}/#{ordering.id}", params: { folder: { parent_id: child.id } }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to eq([ "Parent can't be the folder itself or one of its sub-folders" ])
    end
  end

  describe "DELETE destroy" do
    it "is refused to a viewer" do
      as("viewer")
      folder = create(:folder, project: project)
      delete "#{base}/#{folder.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it "deletes a folder and moves its features up" do
      as("editor")
      folder = create(:folder, project: project)
      feature = create(:feature, project: project, folder: folder)

      delete "#{base}/#{folder.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["message"]).to eq("Folder deleted successfully")
      get "/api/v1/projects/#{project.id}/features/#{feature.id}", headers: headers
      expect(json_response["folder_id"]).to be_nil
    end

    it "is refused when a sub-folder's name is taken in the parent" do
      as("editor")
      folder = create(:folder, project: project, name: "Ordering")
      create(:folder, project: project, parent: folder, name: "Imports")
      create(:folder, project: project, name: "Imports")

      delete "#{base}/#{folder.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to eq([ "Can't delete Ordering: the top level already has a folder named Imports" ])
    end
  end
end
