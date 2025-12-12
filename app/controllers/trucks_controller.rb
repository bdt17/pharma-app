class TrucksController < ApplicationController
  def index
    @trucks = Truck.includes(:site).all
  end

  def show
    @truck = Truck.find(params[:id])
    @temperature_data = @truck.monitorings
                              .order(:recorded_at)
                              .pluck(:recorded_at, :temperature)
                              .map { |time, temp| [time.strftime("%Y-%m-%d %H:%M"), temp] }
  end

  def new
    @truck = Truck.new
    @sites = Site.includes(:region).all
  end

  def create
    @truck = Truck.new(truck_params)
    if @truck.save
      redirect_to trucks_path, notice: "Truck added."
    else
      @sites = Site.includes(:region).all
      render :new
    end
  end

  def edit
    @truck = Truck.find(params[:id])
    @sites = Site.includes(:region).all
  end

  def update
    @truck = Truck.find(params[:id])
    if @truck.update(truck_params)
      redirect_to @truck, notice: "Truck updated."
    else
      @sites = Site.includes(:region).all
      render :edit
    end
  end

  def send_test_alert
    @truck = Truck.find(params[:id])
    AlertMailer.truck_out_of_range(User.first, @truck, nil).deliver_later
    redirect_to trucks_path, notice: "Test alert sent for #{@truck.name}."
  end

  def destroy
    @truck = Truck.find(params[:id])
    @truck.destroy
    redirect_to trucks_path, notice: "Truck deleted."
  end

  private

  def truck_params
    params.require(:truck).permit(:name, :status, :site_id, :min_temp, :max_temp)
  end
end
