module Features
  class BackgroundComponent < Shared::EditableComponent
    def initialize(feature:, project:)
      @feature = feature
      @project = project
    end

    def update_path
      helpers.project_feature_path(@project, @feature)
    end

    def field_name
      "background"
    end

    def resource_type
      "feature"
    end

    def resource_id
      @feature.id
    end

    def field_value
      @feature.background.to_s
    end

    private

    attr_reader :feature, :project
  end
end
