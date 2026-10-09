module Features
  class HeaderComponent < ApplicationComponent
    def initialize(feature:, project:)
      @feature = feature
      @project = project
    end

    private

    attr_reader :feature, :project

    def can_execute?
      helpers.can?(:execute, feature)
    end

    def folders
      @folders ||= Folder.in_tree_order(project.folders)
    end

    def folder
      folders.find { |f| f.id == feature.folder_id }
    end
  end
end
