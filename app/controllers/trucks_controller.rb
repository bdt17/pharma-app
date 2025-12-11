class TrucksController < ApplicationController
  def index
    @trucks = Truck.all
  end

  def new
    @truck = Truck.new
  end

  def create
    @truck = Truck.new(truck_params)
    if @truck.save
      redirect_to trucks_path, notice: "Truck added."
    else
      render :new
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
    params.require(:truck).permit(:name, :status)
  end
end
