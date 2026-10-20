# frozen_string_literal: true

module Mcp
  module Tools
    class DeleteFeature < BaseTool
      description "Move a feature, with its scenarios, steps and runs, to the project's Trash; " \
        "restore_trashed_item with the trashed_item_id it returns brings it back"

      input_schema(
        {
          type: "object",
          properties: {
            feature_id: {
              type: "integer",
              description: "The ID of the feature to move to the Trash"
            }
          },
          required: [ "feature_id" ]
        }
      )

      annotations(
        read_only_hint: false,
        destructive_hint: true,
        idempotent_hint: false,
        open_world_hint: false
      )

      def self.call(feature_id:, server_context:)
        handle_errors do
          current_user = server_context[:current_user]
          feature = Feature.where(project: workspace_projects(server_context)).find(feature_id)
          authorize!(current_user, :destroy, feature)

          item = Trash.move!(feature, by: current_user)
          success_result({ message: "Feature deleted successfully", id: feature_id, trashed_item_id: item.id })
        end
      end
    end
  end
end
