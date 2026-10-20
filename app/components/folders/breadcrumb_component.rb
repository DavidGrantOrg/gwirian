module Folders
  # Project › folder › … , ending in current (a feature's title) when given, or else in
  # the folder itself.
  class BreadcrumbComponent < ApplicationComponent
    def initialize(project:, folder:, current: nil)
      @project = project
      @folder = folder
      @current = current
    end

    private

    attr_reader :project, :folder, :current

    # [ label, path ], with a nil path for the last crumb.
    def crumbs
      links = [ [ project.name, helpers.project_features_path(project) ] ]
      links += folder.path.map { |f| [ f.name, helpers.project_features_path(project, folder: f.id) ] } if folder
      links << [ current, nil ] if current
      links[-1] = [ links[-1][0], nil ]
      links
    end
  end
end
