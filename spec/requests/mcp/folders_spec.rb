require "rails_helper"

RSpec.describe "MCP folders", type: :request do
  let(:workspace) { create(:workspace) }
  let(:user) { create(:user) }
  let!(:workspace_member) { create(:workspace_member, :with_api_token, user: user, workspace: workspace) }
  let(:project) { create(:project, workspace: workspace) }
  let(:role) { "editor" }

  before { create(:project_member, project: project, email: user.email_address, role: role) }

  def call_tool(name, arguments)
    body = { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: name, arguments: arguments } }.to_json
    post "/mcp", params: body, headers: api_headers(workspace_member.api_token).merge("Content-Type" => "application/json")
    expect(json_response["error"]).to be_nil
    JSON.parse(json_response.dig("result", "content", 0, "text"))
  end

  describe "create_folder and list_folders" do
    it "builds a tree that list_folders reads back with each folder's path" do
      ordering = call_tool("create_folder", { project_id: project.id, name: "Ordering" })
      suggested = call_tool("create_folder", { project_id: project.id, name: "Suggested orders", parent_id: ordering["id"] })

      folders = call_tool("list_folders", { project_id: project.id })

      expect(folders.map { |f| f.slice("id", "name", "parent_id", "path") }).to eq([
        { "id" => ordering["id"], "name" => "Ordering", "parent_id" => nil, "path" => "Ordering" },
        { "id" => suggested["id"], "name" => "Suggested orders", "parent_id" => ordering["id"], "path" => "Ordering › Suggested orders" }
      ])
    end

    it "reports a refused name" do
      create(:folder, project: project, name: "Ordering")
      result = call_tool("create_folder", { project_id: project.id, name: "ordering" })
      expect(result.dig("error", "message")).to eq("Validation failed: Name is already used by another folder here")
    end

    context "as a viewer" do
      let(:role) { "viewer" }

      it "may list but not create" do
        create(:folder, project: project, name: "Ordering")
        expect(call_tool("list_folders", { project_id: project.id }).map { |f| f["name"] }).to eq([ "Ordering" ])
        expect(call_tool("create_folder", { project_id: project.id, name: "Catalog" }).dig("error", "code")).to eq(-32001)
      end
    end
  end

  describe "update_folder" do
    let!(:ordering) { create(:folder, project: project, name: "Ordering") }
    let!(:catalog) { create(:folder, project: project, name: "Catalog") }

    it "renames a folder" do
      call_tool("update_folder", { folder_id: ordering.id, name: "Orders" })
      expect(call_tool("list_folders", { project_id: project.id }).map { |f| f["name"] }).to contain_exactly("Catalog", "Orders")
    end

    it "moves a folder under another, and to the top when parent_id is null" do
      moved = call_tool("update_folder", { folder_id: ordering.id, parent_id: catalog.id })
      expect(moved["path"]).to eq("Catalog › Ordering")

      back = call_tool("update_folder", { folder_id: ordering.id, parent_id: nil })
      expect(back).to include("parent_id" => nil, "path" => "Ordering")
    end

    it "leaves the parent alone when parent_id is not given" do
      ordering.update!(parent: catalog)
      renamed = call_tool("update_folder", { folder_id: ordering.id, name: "Orders" })
      expect(renamed).to include("parent_id" => catalog.id, "path" => "Catalog › Orders")
    end

    it "refuses a move inside one of its own sub-folders" do
      child = create(:folder, project: project, parent: ordering, name: "History")
      result = call_tool("update_folder", { folder_id: ordering.id, parent_id: child.id })
      expect(result.dig("error", "message")).to eq("Validation failed: Parent can't be the folder itself or one of its sub-folders")
    end
  end

  describe "delete_folder" do
    it "deletes a folder and moves its features up" do
      folder = create(:folder, project: project, name: "Ordering")
      feature = create(:feature, project: project, folder: folder)

      result = call_tool("delete_folder", { folder_id: folder.id })

      expect(result["message"]).to eq("Folder deleted successfully")
      expect(call_tool("get_feature", { feature_id: feature.id })).to include("folder_id" => nil, "folder_path" => nil)
    end

    it "reports a delete refused because a sub-folder's name is taken" do
      folder = create(:folder, project: project, name: "Ordering")
      create(:folder, project: project, parent: folder, name: "Imports")
      create(:folder, project: project, name: "Imports")

      result = call_tool("delete_folder", { folder_id: folder.id })

      expect(result.dig("error", "message")).to eq("Failed to delete folder: Can't delete Ordering: the top level already has a folder named Imports")
    end
  end

  describe "a feature's folder" do
    let!(:ordering) { create(:folder, project: project, name: "Ordering") }
    let!(:suggested) { create(:folder, project: project, parent: ordering, name: "Suggested orders") }

    it "is set by create_feature and read back by get_feature with its path" do
      created = call_tool("create_feature", { project_id: project.id, title: "Reorder", folder_id: suggested.id })

      fetched = call_tool("get_feature", { feature_id: created["id"] })

      expect(fetched).to include("folder_id" => suggested.id, "folder_path" => "Ordering › Suggested orders")
    end

    it "moves with update_feature, to Unfiled when folder_id is null" do
      feature = create(:feature, project: project)

      call_tool("update_feature", { feature_id: feature.id, folder_id: ordering.id })
      expect(call_tool("get_feature", { feature_id: feature.id })).to include("folder_id" => ordering.id, "folder_path" => "Ordering")

      call_tool("update_feature", { feature_id: feature.id, folder_id: nil })
      expect(call_tool("get_feature", { feature_id: feature.id })).to include("folder_id" => nil, "folder_path" => nil)
    end

    it "stays put when update_feature is not given a folder_id" do
      feature = create(:feature, project: project, folder: ordering)
      call_tool("update_feature", { feature_id: feature.id, title: "Renamed" })
      expect(call_tool("get_feature", { feature_id: feature.id })["folder_id"]).to eq(ordering.id)
    end

    it "refuses another project's folder" do
      feature = create(:feature, project: project)
      other = create(:folder, project: create(:project, workspace: workspace))
      result = call_tool("update_feature", { feature_id: feature.id, folder_id: other.id })
      expect(result.dig("error", "message")).to eq("Validation failed: Folder must be in the same project")
    end

    it "is listed by list_features" do
      create(:feature, project: project, title: "Reorder", folder: suggested)
      create(:feature, project: project, title: "Sign in")

      features = call_tool("list_features", { project_id: project.id })

      expect(features.map { |f| f.slice("title", "folder_id", "folder_path") }).to eq([
        { "title" => "Reorder", "folder_id" => suggested.id, "folder_path" => "Ordering › Suggested orders" },
        { "title" => "Sign in", "folder_id" => nil, "folder_path" => nil }
      ])
    end
  end

  it "get_project includes the folders" do
    ordering = create(:folder, project: project, name: "Ordering")

    result = call_tool("get_project", { project_id: project.id })

    expect(result["folders"]).to eq([ { "id" => ordering.id, "name" => "Ordering", "parent_id" => nil, "path" => "Ordering" } ])
  end
end
