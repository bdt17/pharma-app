class Api::V1::SitesController < Api::BaseController
  def index
    sites = Site.all.includes(:region, :trucks)
    render json: sites.map { |s| serialize_site(s) }
  end

  def show
    site = Site.includes(:region, trucks: :monitorings).find(params[:id])
    render json: serialize_site(site, include_trucks: true)
  end

  private

  def serialize_site(site, include_trucks: false)
    data = {
      id: site.id,
      name: site.name,
      region_id: site.region_id,
      region_name: site.region.name,
      trucks_count: site.trucks.count
    }

    if include_trucks
      data[:trucks] = site.trucks.map do |truck|
        last = truck.monitorings.order(recorded_at: :desc).first
        {
          id: truck.id,
          name: truck.name,
          status: truck.status,
          risk_level: truck.risk_level,
          risk_score: truck.risk_score,
          last_temperature: last&.temperature,
          last_recorded_at: last&.recorded_at
        }
      end
    end

    data
  end
end
