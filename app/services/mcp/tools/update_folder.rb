# frozen_string_literal: true

module Mcp
  module Tools
    class UpdateFolder < BaseTool
      description "Rename a folder, or move it into another folder or to the top of the project"

      input_schema(
        {
          type: "object",
          properties: {
            folder_id: {
              type: "integer",
              description: "The ID of the folder to update"
            },
            name: {
              type: "string",
              description: "The folder's new name"
            },
            parent_id: {
              type: [ "integer", "null" ],
              description: "The ID of the folder to move it into; null moves it to the top of the project, " \
                "and leaving it out leaves the folder where it is"
            }
          },
          required: [ "folder_id" ]
        }
      )

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: true,
        open_world_hint: false
      )

      def self.call(folder_id:, name: nil, parent_id: NOT_GIVEN, server_context:)
        handle_errors do
          current_user = server_context[:current_user]
          folder = Folder.find_by(id: folder_id)
          authorize!(current_user, :update, folder)

          update_params = {}
          update_params[:name] = name if name.present?
          update_params[:parent_id] = parent_id unless parent_id.equal?(NOT_GIVEN)

          if folder.update(update_params)
            success_result(folder_json(folder))
          else
            error_result("Validation failed: #{folder.errors.full_messages.join(', ')}", code: -32003)
          end
        end
      end
    end
  end
end
