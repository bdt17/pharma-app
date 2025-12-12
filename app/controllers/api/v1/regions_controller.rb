class Api::V1::RegionsController < Api::BaseController
  def index
    regions = Region.all.includes(:sites)
    render json: regions.map { |r| serialize_region(r) }
  end

  def show
    region = Region.includes(sites: :trucks).find(params[:id])
    render json: serialize_region(region, include_sites: true)
  end

  private

  def serialize_region(region, include_sites: false)
    data = {
      id: region.id,
      name: region.name,
      sites_count: region.sites.count,
      trucks_count: region.sites.sum { |s| s.trucks.count }
    }

    if include_sites
      data[:sites] = region.sites.map do |site|
        {
          id: site.id,
          name: site.name,
          trucks_count: site.trucks.count
        }
      end
    end

    data
  end
end
