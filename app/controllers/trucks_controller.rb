class TrucksController < ApplicationController
  before_action :authenticate_user!

  def index
    @trucks = current_user.trucks
  end

  def new
    @truck = current_user.trucks.build
  end

  def create
    @truck = current_user.trucks.build(truck_params)
    if @truck.save
      redirect_to trucks_path, notice: "Truck added."
    else
      render :new
    end
  end

  private

  def truck_params
    params.require(:truck).permit(:name, :status)
  end
end
