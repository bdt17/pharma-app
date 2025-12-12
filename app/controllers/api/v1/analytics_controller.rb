class Api::V1::AnalyticsController < Api::BaseController
  def summary
    service = AnalyticsService.new(filter_params)
    render json: service.summary
  end

  def regions
    service = AnalyticsService.new(filter_params)
    render json: {
      period: { start_date: filter_params[:start_date], end_date: filter_params[:end_date] },
      regions: service.by_region
    }
  end

  def sites
    service = AnalyticsService.new(filter_params)
    render json: {
      period: { start_date: filter_params[:start_date], end_date: filter_params[:end_date] },
      sites: service.by_site
    }
  end

  def routes
    service = AnalyticsService.new(filter_params)
    render json: {
      period: { start_date: filter_params[:start_date], end_date: filter_params[:end_date] },
      routes: service.by_route
    }
  end

  private

  def filter_params
    {
      region_id: params[:region_id],
      site_id: params[:site_id],
      start_date: params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago,
      end_date: params[:end_date].present? ? Date.parse(params[:end_date]) : Time.current
    }
  end
end
