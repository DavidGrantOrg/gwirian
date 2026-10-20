module Features
  class CardComponent < ApplicationComponent
    # folder_path: the feature's folder, shown in search results, where the card can come
    # from anywhere in the project. folders: offers Move to… in the card's menu.
    def initialize(feature:, project:, stagger_index: 0, folder_path: nil, folders: nil)
      @feature = feature
      @project = project
      @stagger_index = stagger_index
      @folder_path = folder_path
      @folders = folders
    end

    private

    attr_reader :feature, :project, :stagger_index, :folder_path, :folders

    # Out of the backlog only.
    def scenarios_count
      execution_stats[:total]
    end

    def execution_stats
      @execution_stats ||= begin
        statuses = feature.scenarios.includes(:scenario_executions).map(&:current_status)
        backlog = statuses.count("backlog")

        {
          passed: statuses.count("passed"),
          failed: statuses.count("failed"),
          pending: statuses.count("pending"),
          backlog: backlog,
          total: statuses.size - backlog
        }
      end
    end

    def passed_percentage
      return 0 if execution_stats[:total].zero?
      (execution_stats[:passed].to_f / execution_stats[:total] * 100).round
    end

    def failed_percentage
      return 0 if execution_stats[:total].zero?
      (execution_stats[:failed].to_f / execution_stats[:total] * 100).round
    end

    def pending_percentage
      return 0 if execution_stats[:total].zero?
      100 - passed_percentage - failed_percentage
    end

    def has_scenarios?
      scenarios_count > 0 || execution_stats[:backlog] > 0
    end
  end
end
