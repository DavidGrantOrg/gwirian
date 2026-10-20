module Folders
  # The feature header's Folder drop-down: Unfiled and every folder by its path, moving the
  # feature as soon as it changes. Editors only, and only once the project has a folder.
  class FeatureFolderSelectComponent < ApplicationComponent
    def initialize(feature:, project:, folders:)
      @feature = feature
      @project = project
      @folders = folders
    end

    def render?
      folders.any? && helpers.can?(:update, feature)
    end

    private

    attr_reader :feature, :project, :folders

    def choices
      [ [ "Unfiled", "" ] ] + folders.map { |folder| [ folder.path_label, folder.id ] }
    end
  end
end
