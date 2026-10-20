# frozen_string_literal: true

module Mcp
  module Tools
    class DeleteScenario < BaseTool
      description "Move a scenario, with its steps and runs, to the project's Trash; " \
        "restore_trashed_item with the trashed_item_id it returns brings it back"

      input_schema(
        {
          type: "object",
          properties: {
            scenario_id: {
              type: "integer",
              description: "The ID of the scenario to move to the Trash"
            }
          },
          required: [ "scenario_id" ]
        }
      )

      annotations(
        read_only_hint: false,
        destructive_hint: true,
        idempotent_hint: false,
        open_world_hint: false
      )

      def self.call(scenario_id:, server_context:)
        handle_errors do
          current_user = server_context[:current_user]
          scenario = Scenario.where(feature: Feature.where(project: workspace_projects(server_context))).find(scenario_id)
          authorize!(current_user, :destroy, scenario)

          item = Trash.move!(scenario, by: current_user)
          success_result({ message: "Scenario deleted successfully", id: scenario_id, trashed_item_id: item.id })
        rescue ActiveRecord::RecordNotDestroyed => e
          error_result("Failed to delete scenario: #{e.record.errors.full_messages.join(', ')}", code: -32000)
        end
      end
    end
  end
end
