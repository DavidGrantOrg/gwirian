module Folders
  # The project's folder tree, with the project as its root. folders comes from
  # Folder.in_tree_order; selected is the folder being shown, or nil for the root.
  class TreeComponent < ApplicationComponent
    def initialize(project:, folders:, selected:)
      @project = project
      @folders = folders
      @selected = selected
    end

    private

    attr_reader :project, :folders, :selected

    def children_by_parent_id
      @children_by_parent_id ||= folders.group_by(&:parent_id)
    end

    def feature_counts
      @feature_counts ||= project.features.group(:folder_id).count
    end

    def open_ids
      @open_ids ||= selected ? selected.path.map(&:id) : []
    end

    def item(folder)
      TreeItemComponent.new(
        project: project, folder: folder, children_by_parent_id: children_by_parent_id,
        feature_counts: feature_counts, open_ids: open_ids, selected: selected
      )
    end
  end
end
