# frozen_string_literal: true

module Mcp
  module Tools
    class DeleteFolder < BaseTool
      description "Delete a folder. Its features and sub-folders are kept: they move up into its parent folder, " \
        "or to the top of the project"

      input_schema(
        {
          type: "object",
          properties: {
            folder_id: {
              type: "integer",
              description: "The ID of the folder to delete"
            }
          },
          required: [ "folder_id" ]
        }
      )

      annotations(
        read_only_hint: false,
        destructive_hint: true,
        idempotent_hint: false,
        open_world_hint: false
      )

      def self.call(folder_id:, server_context:)
        handle_errors do
          current_user = server_context[:current_user]
          folder = Folder.find_by(id: folder_id)
          authorize!(current_user, :destroy, folder)

          if folder.destroy
            success_result({ message: "Folder deleted successfully", id: folder_id })
          else
            error_result("Failed to delete folder: #{folder.errors.full_messages.join(', ')}", code: -32000)
          end
        end
      end
    end
  end
end
