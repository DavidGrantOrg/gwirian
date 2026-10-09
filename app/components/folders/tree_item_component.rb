module Folders
  # One folder in the tree, rendering its own sub-folders below it.
  class TreeItemComponent < ApplicationComponent
    def initialize(project:, folder:, children_by_parent_id:, feature_counts:, open_ids:, selected:)
      @project = project
      @folder = folder
      @children_by_parent_id = children_by_parent_id
      @feature_counts = feature_counts
      @open_ids = open_ids
      @selected = selected
    end

    private

    attr_reader :project, :folder, :children_by_parent_id, :feature_counts, :open_ids, :selected

    def children
      children_by_parent_id[folder.id] || []
    end

    def open?
      open_ids.include?(folder.id)
    end

    def selected?
      selected&.id == folder.id
    end

    def feature_count
      feature_counts[folder.id] || 0
    end

    def link
      link_to helpers.project_features_path(project, folder: folder.id),
        class: "flex flex-1 min-w-0 items-center justify-between gap-2 px-2 py-1.5 rounded-md text-stone-700 dark:text-white/80 " \
          "hover:bg-stone-100 dark:hover:bg-white/5 #{selected? ? 'bg-stone-100 dark:bg-white/10 font-medium' : ''}",
        aria: { current: selected? ? "page" : nil } do
        safe_join([
          tag.span(folder.name, class: "truncate"),
          tag.span(feature_count, class: "text-xs tabular-nums text-stone-400 dark:text-white/40")
        ], " ")
      end
    end

    def child(child_folder)
      self.class.new(
        project: project, folder: child_folder, children_by_parent_id: children_by_parent_id,
        feature_counts: feature_counts, open_ids: open_ids, selected: selected
      )
    end
  end
end
