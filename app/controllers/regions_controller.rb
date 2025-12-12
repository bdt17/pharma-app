class RegionsController < ApplicationController
  def index
    @regions = Region.all.includes(:sites)
  end

  def show
    @region = Region.includes(sites: :trucks).find(params[:id])
  end

  def new
    @region = Region.new
  end

  def create
    @region = Region.new(region_params)
    if @region.save
      redirect_to regions_path, notice: "Region created."
    else
      render :new
    end
  end

  def edit
    @region = Region.find(params[:id])
  end

  def update
    @region = Region.find(params[:id])
    if @region.update(region_params)
      redirect_to @region, notice: "Region updated."
    else
      render :edit
    end
  end

  def destroy
    @region = Region.find(params[:id])
    @region.destroy
    redirect_to regions_path, notice: "Region deleted."
  end

  private

  def region_params
    params.require(:region).permit(:name)
  end
end
