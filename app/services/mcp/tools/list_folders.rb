# frozen_string_literal: true

module Mcp
  module Tools
    class ListFolders < BaseTool
      description "List a project's folders as a tree: each folder, then its sub-folders. " \
        "parent_id null means the folder is at the top of the project; path is the folder's full path."

      input_schema(
        {
          type: "object",
          properties: {
            project_id: {
              type: "integer",
              description: "The ID of the project"
            }
          },
          required: [ "project_id" ]
        }
      )

      annotations(
        read_only_hint: true,
        destructive_hint: false,
        idempotent_hint: true,
        open_world_hint: false
      )

      def self.call(project_id:, server_context:)
        handle_errors do
          current_user = server_context[:current_user]
          project = current_user.projects.find_by(id: project_id)
          authorize!(current_user, :read, project)

          success_result(Folder.in_tree_order(project.folders).map { |folder| folder_json(folder) })
        end
      end
    end
  end
end
