class AnalyticsController < ApplicationController
  def index
    @service = AnalyticsService.new(filter_params)
    @summary = @service.summary
    @by_region = @service.by_region
    @by_site = @service.by_site
    @top_sites = @service.top_excursion_sites(5)
    @excursions_over_time = @service.excursions_over_time(:day)
    @excursions_by_region = @service.excursions_by_region_over_time(:day)
    @regions = Region.all
    @sites = Site.includes(:region).all
  end

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

  def excursions_over_time
    service = AnalyticsService.new(filter_params)
    interval = params[:interval]&.to_sym || :day
    render json: {
      interval: interval,
      data: service.excursions_over_time(interval)
    }
  end

  def excursions_by_region
    service = AnalyticsService.new(filter_params)
    interval = params[:interval]&.to_sym || :day
    render json: {
      interval: interval,
      data: service.excursions_by_region_over_time(interval)
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
