class TrashController < ApplicationController
  before_action :require_workspace
  before_action :set_project
  before_action :set_item, only: [ :restore, :destroy, :download ]

  rescue_from CanCan::AccessDenied do
    head :forbidden
  end

  def index
    authorize! :read, TrashedItem.new(project: @project)
    @pagy, @items = pagy(@project.trashed_items.listing.includes(:trashed_by).order(created_at: :desc, id: :desc), limit: 50)
    feature_ids = @items.select { |item| item.item_type == "Feature" }.map(&:item_id)
    @trashed_scenario_counts = @project.trashed_items.where(item_type: "Scenario", feature_id: feature_ids).group(:feature_id).count
  end

  def restore
    authorize! :restore, @item

    restored = Trash.restore!(@item)
    redirect_to project_feature_path(@project, restored.feature_id), notice: restored.message
  rescue Trash::Gone
    render_gone
  rescue Trash::Refused => e
    # Shown on the page rather than as a toast, since it says what to do next.
    redirect_to project_trashed_items_path(@project), flash: { trash_refusal: e.message }
  end

  def destroy
    authorize! :destroy, @item

    Trash.purge!(@item)
    redirect_to project_trashed_items_path(@project), notice: "Deleted #{@item.number} forever."
  rescue Trash::Gone
    render_gone
  end

  def download
    authorize! :download, @item

    send_data JSON.pretty_generate(@item.payload), type: "application/json",
      filename: "#{@item.number}-trashed-item-#{@item.id}.json"
  end

  private

  def set_project
    @project = workspace_projects.find(params[:project_id])
  end

  def set_item
    @item = @project.trashed_items.find_by(id: params[:id])
    render_gone unless @item
  end

  def render_gone
    render :gone, status: :not_found
  end
end
