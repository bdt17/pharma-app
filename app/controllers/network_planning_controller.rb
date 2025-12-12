class NetworkPlanningController < ApplicationController
  def index
    @demand_analysis = NetworkPlanner.analyze_demand_vs_capacity
    @lane_suggestions = NetworkPlanner.suggest_shipments_per_lane
    @capacity_upgrades = NetworkPlanner.identify_capacity_upgrades
    @regional_summary = NetworkPlanner.regional_summary
    @capacity_plans = CapacityPlan.active.order(created_at: :desc).limit(10)
  end

  def show
    @plan = CapacityPlan.find(params[:id])
    @lane_items = @plan.capacity_plan_items.by_type('lane').order(utilization_percent: :desc)
    @node_items = @plan.capacity_plan_items.by_type('node').order(utilization_percent: :desc)
    @region_items = @plan.capacity_plan_items.by_type('region')
  end

  def new
    @plan = CapacityPlan.new
  end

  def create
    @plan = NetworkPlanner.generate_plan(
      name: params[:name],
      start_date: Date.parse(params[:start_date]),
      end_date: Date.parse(params[:end_date]),
      created_by: current_user&.email || 'system'
    )
    redirect_to network_planning_path(@plan), notice: 'Capacity plan generated successfully.'
  rescue => e
    flash[:alert] = "Error generating plan: #{e.message}"
    redirect_to network_planning_index_path
  end

  def approve
    @plan = CapacityPlan.find(params[:id])
    @plan.approve!(current_user&.email || 'system')
    redirect_to network_planning_path(@plan), notice: 'Plan approved.'
  end

  def reject
    @plan = CapacityPlan.find(params[:id])
    @plan.reject!(current_user&.email || 'system')
    redirect_to network_planning_path(@plan), notice: 'Plan rejected.'
  end

  def demand_analysis
    @analysis = NetworkPlanner.analyze_demand_vs_capacity(
      region_id: params[:region_id],
      site_id: params[:site_id],
      start_date: params[:start_date]&.to_date,
      end_date: params[:end_date]&.to_date
    )
    render json: @analysis
  end

  def lane_suggestions
    @suggestions = NetworkPlanner.suggest_shipments_per_lane(
      start_date: params[:start_date]&.to_date,
      end_date: params[:end_date]&.to_date
    )
    render json: @suggestions
  end

  def capacity_upgrades
    @upgrades = NetworkPlanner.identify_capacity_upgrades
    render json: @upgrades
  end

  def additional_carriers
    @carriers = NetworkPlanner.identify_additional_carriers
    render json: @carriers
  end

  def regional_summary
    @summary = NetworkPlanner.regional_summary
    render json: @summary
  end
end
