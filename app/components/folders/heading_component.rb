module Folders
  # The open folder's breadcrumb and name, with, for editors, the name edited in place
  # (as Features::TitleComponent does), Move to… and Delete folder.
  class HeadingComponent < ApplicationComponent
    def initialize(project:, folder:, folders:, error: nil, focus: false)
      @project = project
      @folder = folder
      @folders = folders
      @error = error
      @focus = focus
    end

    private

    attr_reader :project, :folder, :folders, :error, :focus

    def editable?
      helpers.can?(:update, folder)
    end

    def update_path
      helpers.project_folder_path(project, folder)
    end

    def form_id
      "folder-name-form-#{folder.id}"
    end

    # [ label, parent_id, depth ] for each place the folder can move to: the top of the
    # project, then every folder outside the folder's own subtree.
    def move_targets
      inside = folders.select { |f| f.path.any? { |ancestor| ancestor.id == folder.id } }
      [ [ project.name, nil, 0 ] ] + (folders - inside).map { |f| [ f.name, f.id, f.path.size ] }
    end

    def delete_confirmation
      destination = folder.parent ? folder.parent.name : project.name
      "Delete #{folder.name}? Its features and sub-folders will move to #{destination}."
    end
  end
end
