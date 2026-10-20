# frozen_string_literal: true

module Mcp
  module Tools
    class RestoreTrashedItem < BaseTool
      description "Bring a deleted feature or scenario back from the Trash under its old number. " \
        "A scenario whose feature is also in the Trash is refused until the feature is restored"

      input_schema(
        {
          type: "object",
          properties: {
            trashed_item_id: {
              type: "integer",
              description: "The trashed_item_id from delete_feature, delete_scenario or list_trashed_items"
            }
          },
          required: [ "trashed_item_id" ]
        }
      )

      annotations(
        read_only_hint: false,
        destructive_hint: false,
        idempotent_hint: false,
        open_world_hint: false
      )

      def self.call(trashed_item_id:, server_context:)
        handle_errors do
          current_user = server_context[:current_user]
          item = TrashedItem.where(project: workspace_projects(server_context)).find(trashed_item_id)
          authorize!(current_user, :restore, item)

          restored = Trash.restore!(item)
          success_result({
            item_type: restored.item_type,
            item_id: restored.item_id,
            number: restored.number,
            project_id: restored.project_id,
            feature_id: restored.feature_id,
            message: restored.message,
            url: url_for(restored, server_context)
          })
        rescue Trash::Refused => e
          trash_refused_result(e, server_context)
        end
      end

      def self.url_for(restored, server_context)
        url = "#{server_context[:base_url]}/#{server_context[:current_workspace].slug}" \
          "/projects/#{restored.project_id}/features/#{restored.feature_id}"
        restored.item_type == "Scenario" ? "#{url}#scenario-wrapper-#{restored.item_id}" : url
      end
    end
  end
end
