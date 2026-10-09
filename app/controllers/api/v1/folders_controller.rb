class Api::V1::FoldersController < Api::V1::ApiController
  JSON_FIELDS = [ :id, :name, :parent_id, :project_id, :created_at, :updated_at ].freeze

  before_action :set_folder, only: [ :show, :update, :destroy ]

  def index
    authorize! :read, Folder.new(project: @project)
    render json: @project.folders.order(:name).as_json(only: JSON_FIELDS)
  end

  def show
    authorize! :read, @folder
    render json: @folder.as_json(only: JSON_FIELDS)
  end

  def create
    @folder = @project.folders.new(folder_params)
    authorize! :create, @folder

    if @folder.save
      render json: @folder.as_json(only: JSON_FIELDS), status: :created
    else
      render json: { errors: @folder.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize! :update, @folder

    if @folder.update(folder_params)
      render json: @folder.as_json(only: JSON_FIELDS)
    else
      render json: { errors: @folder.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @folder

    if @folder.destroy
      render json: { message: "Folder deleted successfully" }, status: :ok
    else
      render json: { errors: @folder.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_folder
    @folder = @project.folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name, :parent_id)
  end
end
