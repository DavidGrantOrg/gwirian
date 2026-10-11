class Api::V1::ScenariosController < Api::V1::ApiController
  FIELDS = [ :id, :title, :given, :when, :then, :position, :backlog, :feature_id, :created_at, :updated_at ].freeze

  before_action :set_feature
  before_action :set_scenario, only: [ :show, :update, :destroy ]

  def index
    @scenarios = @feature.scenarios.order(:position)
    authorize! :read, Scenario.new(feature: @feature)
    render json: @scenarios.as_json(only: FIELDS)
  end

  def show
    authorize! :read, @scenario
    render json: @scenario.as_json(only: FIELDS)
  end

  def create
    @scenario = @feature.scenarios.new(scenario_params)
    authorize! :create, @scenario

    if @scenario.save
      render json: @scenario.as_json(only: FIELDS), status: :created
    else
      render json: { errors: @scenario.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    authorize! :update, @scenario

    if @scenario.update(scenario_params)
      render json: @scenario.as_json(only: FIELDS)
    else
      render json: { errors: @scenario.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @scenario

    if @scenario.destroy
      render json: { message: "Scenario deleted successfully" }, status: :ok
    else
      render json: { errors: @scenario.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_feature
    @feature = @project.features.find(params[:feature_id])
  end

  def set_scenario
    @scenario = @feature.scenarios.find(params[:id])
  end

  def scenario_params
    params.require(:scenario).permit(:title, :given, :when, :then, :position, :backlog)
  end
end
