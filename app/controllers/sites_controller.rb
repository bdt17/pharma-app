class SitesController < ApplicationController
  def index
    @sites = Site.all.includes(:region, :trucks)
  end

  def show
    @site = Site.includes(:region, trucks: :monitorings).find(params[:id])
  end

  def new
    @site = Site.new
    @regions = Region.all
  end

  def create
    @site = Site.new(site_params)
    if @site.save
      redirect_to sites_path, notice: "Site created."
    else
      @regions = Region.all
      render :new
    end
  end

  def edit
    @site = Site.find(params[:id])
    @regions = Region.all
  end

  def update
    @site = Site.find(params[:id])
    if @site.update(site_params)
      redirect_to @site, notice: "Site updated."
    else
      @regions = Region.all
      render :edit
    end
  end

  def destroy
    @site = Site.find(params[:id])
    @site.destroy
    redirect_to sites_path, notice: "Site deleted."
  end

  private

  def site_params
    params.require(:site).permit(:name, :region_id)
  end
end
