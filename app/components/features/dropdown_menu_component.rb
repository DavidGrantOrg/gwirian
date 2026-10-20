module Features
  class DropdownMenuComponent < Shared::DropdownMenuComponent
    # folders, from Folder.in_tree_order, adds Move to…; nil leaves the menu as Delete only.
    def initialize(feature:, project:, folders: nil)
      @feature = feature
      @project = project
      @folders = folders
    end

    # [ label, folder_id ] for Unfiled and every folder by its path, but the card's own.
    def move_choices
      return [] if @folders.blank?

      choices = [ [ "Unfiled", nil ] ] + @folders.map { |folder| [ folder.path_label, folder.id ] }
      choices.reject { |_label, folder_id| folder_id == @feature.folder_id }
    end

    def move_path
      helpers.move_project_feature_path(@project, @feature)
    end

    def delete_path
      helpers.project_feature_path(@project, @feature)
    end

    def delete_target
      "#features"
    end

    def confirmation_message
      count = @feature.scenarios.size
      subject = count.zero? ? "F#{@feature.id}" : "F#{@feature.id} and its #{helpers.pluralize(count, 'scenario')}"
      "Move #{subject} to the Trash?"
    end

    private

    attr_reader :feature, :project
  end
end
