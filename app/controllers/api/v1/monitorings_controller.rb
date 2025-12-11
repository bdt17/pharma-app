class Api::V1::MonitoringsController < Api::BaseController
  def create
    truck = Truck.find(params[:truck_id])
    monitoring = truck.monitorings.create!(monitoring_params)
    render json: monitoring, status: :created
  end

  private

  def monitoring_params
    params.require(:monitoring).permit(:temperature, :power_status, :recorded_at)
  end
end
