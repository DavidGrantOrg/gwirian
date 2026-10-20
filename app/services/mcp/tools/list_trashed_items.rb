# frozen_string_literal: true

module Mcp
  module Tools
    class ListTrashedItems < BaseTool
      description "List a project's Trash: deleted features and scenarios, newest first, " \
        "each with the trashed_item_id restore_trashed_item takes"

      input_schema(
        {
          type: "object",
          properties: {
            project_id: {
              type: "integer",
              description: "The ID of the project"
            },
            limit: {
              type: "integer",
              description: "How many items to return (default 50, at most 200)"
            },
            offset: {
              type: "integer",
              description: "How many of the newest items to skip (default 0)"
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

      def self.call(project_id:, limit: 50, offset: 0, server_context:)
        handle_errors do
          current_user = server_context[:current_user]
          project = workspace_projects(server_context).find(project_id)
          authorize!(current_user, :read, TrashedItem.new(project: project))

          items = project.trashed_items.listing.includes(:trashed_by).order(created_at: :desc, id: :desc)
            .limit(limit.clamp(1, 200)).offset([ offset, 0 ].max)
          success_result({ total: project.trashed_items.count, items: items.map { |item| item_json(item) } })
        end
      end

      def self.item_json(item)
        {
          trashed_item_id: item.id,
          item_type: item.item_type,
          item_id: item.item_id,
          number: item.number,
          title: item.title,
          feature_id: item.feature_id,
          trashed_by: item.trashed_by&.email_address,
          trashed_at: item.created_at.iso8601,
          scenario_numbers: item.snapshot_scenario_ids.map { |id| "S#{id}" }
        }
      end
    end
  end
end
