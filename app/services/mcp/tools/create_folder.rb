# frozen_string_literal: true

module Mcp
  module Tools
    class CreateFolder < BaseTool
      description "Create a folder in a project, at the top or inside another folder"

      input_schema(
        {
          type: "object",
          properties: {
            project_id: {
              type: "integer",
              description: "The ID of the project"
            },
            name: {
              type: "string",
              description: "The folder's name, unique among the folders beside it"
            },
            parent_id: {
              type: [ "integer", "null" ],
              description: "The ID of the folder to create it in; leave out or null for the top of the project"
            }
          },
          required: [ "project_id", "name" ]
        }
      )

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false,
        open_world_hint: false
      )

      def self.call(project_id:, name:, parent_id: nil, server_context:)
        handle_errors do
          current_user = server_context[:current_user]
          project = current_user.projects.find_by(id: project_id)
          authorize!(current_user, :read, project)

          folder = project.folders.new(name: name, parent_id: parent_id)
          authorize!(current_user, :create, folder)

          if folder.save
            success_result(folder_json(folder))
          else
            error_result("Validation failed: #{folder.errors.full_messages.join(', ')}", code: -32003)
          end
        end
      end
    end
  end
end
