# frozen_string_literal: true

module Dashboard
  class FailingTestsComponent < ApplicationComponent
    include ActionView::Helpers::DateHelper

    def initialize(project:, limit: 5)
      @project = project
      @limit = limit
    end

    private

    attr_reader :project, :limit

    def failing_scenarios
      @failing_scenarios ||= ScenarioExecution.latest_for(project.scenarios.where(backlog: false))
        .failed.latest_first.limit(limit).includes(scenario: :feature)
        .map { |execution| execution.scenario.tap { |scenario| scenario.latest_execution = execution } }
    end

    def has_failures?
      failing_scenarios.any?
    end

    def scenario_link(scenario)
      helpers.project_feature_path(project, scenario.feature, anchor: "scenario-#{scenario.id}")
    end

    def last_execution_time(scenario)
      scenario.latest_execution&.executed_at
    end
  end
end
