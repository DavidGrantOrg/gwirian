# frozen_string_literal: true

module Mcp
  module Tools
    class BaseTool < MCP::Tool
      # The default for an argument where an explicit null means something (the project's
      # top level), so leaving the argument out can mean "leave it as it is".
      NOT_GIVEN = Object.new.freeze

      def self.folder_json(folder)
        { id: folder.id, name: folder.name, parent_id: folder.parent_id, path: folder.path_label }
      end

      # folders_by_id, from Folder.in_tree_order, saves a lookup per feature in a list.
      def self.feature_folder_fields(feature, folders_by_id = nil)
        folder = folders_by_id ? folders_by_id[feature.folder_id] : feature.folder
        { "folder_id" => feature.folder_id, "folder_path" => folder&.path_label }
      end

      # The token's workspace; a record in another workspace is not found, even for a user in both.
      def self.workspace_projects(server_context)
        Project.where(workspace: server_context[:current_workspace])
      end

      # A refused restore keeps its reason code stable, and gives the request id to find in the logs.
      def self.trash_refused_result(error, server_context)
        message = error.next_call ? "#{error.message.delete_suffix('.')}: #{error.next_call}" : error.message
        error_result(message, code: -32005, reason: error.code, request_id: server_context[:request_id])
      end

      def self.authorize!(user, action, subject)
        ability = Ability.new(user)
        ability.authorize!(action, subject)
      end

      def self.can?(user, action, subject)
        ability = Ability.new(user)
        ability.can?(action, subject)
      end

      def self.success_result(content)
        text = if content.is_a?(String)
          content
        elsif content.respond_to?(:to_json)
          content.to_json
        else
          JSON.generate(content)
        end

        MCP::Tool::Response.new([ {
          type: "text",
          text: text
        } ])
      end

      def self.error_result(message, code: -32000, **details)
        error_data = {
          error: {
            code: code,
            message: message,
            **details
          }
        }

        MCP::Tool::Response.new([ {
          type: "text",
          text: error_data.to_json
        } ], error: true)
      end

      def self.safe_user_email(user)
        user&.email_address || "unknown"
      end

      def self.handle_errors(&block)
        block.call
      rescue CanCan::AccessDenied => e
        error_result("Access denied: #{e.message}", code: -32001)
      rescue ActiveRecord::RecordNotFound => e
        # Not e.message: on a scoped lookup Rails appends the query's WHERE clause.
        error_result([ "Record not found", [ e.model, e.id ].compact.join(" ").presence ].compact.join(": "), code: -32002)
      rescue ActiveRecord::RecordInvalid => e
        error_result("Validation failed: #{e.record.errors.full_messages.join(', ')}", code: -32003)
      rescue ArgumentError => e
        error_result("Invalid argument: #{e.message}", code: -32004)
      rescue StandardError => e
        Rails.logger.error("MCP Tool Error: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
        error_result("Internal error: #{e.message}", code: -32000)
      end
    end
  end
end
