class FoldersController < ApplicationController
  NEW_FOLDER_NAME = "New folder"

  before_action :require_workspace
  before_action :set_project
  before_action :set_folder, only: [ :update, :destroy ]

  def create
    parent_id = params.dig(:folder, :parent_id).presence
    parent = parent_id && @project.folders.find(parent_id)
    folder = @project.folders.new(parent: parent, name: unused_new_folder_name(parent))
    authorize! :create, folder

    folder.save!
    flash[:new_folder] = folder.id
    redirect_to project_features_path(@project, folder: folder.id)
  end

  # From the heading (htmx), a rename: answers with the heading and, out of band, the tree.
  # From Move to… (a plain form), a move: opens the folder in its new place.
  def update
    authorize! :update, @folder

    saved = @folder.update(folder_params)
    error = saved ? nil : @folder.errors.full_messages.to_sentence
    if htmx_request?
      @folder.restore_attributes unless saved
      # 200 even when refused, so htmx swaps the heading and its error in like any response.
      render :update, layout: false, locals: { folders: Folder.in_tree_order(@project.folders), error: error, saved: saved }
    else
      redirect_to project_features_path(@project, folder: @folder.id), alert: error
    end
  end

  def destroy
    authorize! :destroy, @folder

    if @folder.destroy
      target = project_features_path(@project, folder: @folder.parent_id)
    else
      flash[:alert] = @folder.errors.full_messages.to_sentence
      target = project_features_path(@project, folder: @folder.id)
    end

    if htmx_request?
      response.headers["HX-Redirect"] = target
      head :ok
    else
      redirect_to target
    end
  end

  private

  def set_project
    @project = workspace_projects.find(params[:project_id])
  end

  def set_folder
    @folder = @project.folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name, :parent_id)
  end

  def unused_new_folder_name(parent)
    taken = @project.folders.where(parent: parent).pluck(:name).map(&:downcase)
    (1..).lazy
      .map { |n| n == 1 ? NEW_FOLDER_NAME : "#{NEW_FOLDER_NAME} #{n}" }
      .find { |name| !taken.include?(name.downcase) }
  end
end
