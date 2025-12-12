class DemandForecast < ApplicationRecord
  belongs_to :region, optional: true
  belongs_to :site, optional: true

  PERIOD_TYPES = %w[daily weekly monthly quarterly].freeze

  validates :product_code, presence: true
  validates :forecast_date, presence: true
  validates :forecast_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :period_type, inclusion: { in: PERIOD_TYPES }

  scope :for_product, ->(code) { where(product_code: code) }
  scope :for_region, ->(region_id) { where(region_id: region_id) }
  scope :for_site, ->(site_id) { where(site_id: site_id) }
  scope :for_date_range, ->(start_date, end_date) { where(forecast_date: start_date..end_date) }
  scope :future, -> { where('forecast_date >= ?', Date.current) }

  def forecast_accuracy
    return nil unless actual_quantity && forecast_quantity.positive?
    ((1 - (actual_quantity - forecast_quantity).abs.to_f / forecast_quantity) * 100).round(2)
  end

  def variance
    return nil unless actual_quantity
    actual_quantity - forecast_quantity
  end

  def variance_percent
    return nil unless actual_quantity && forecast_quantity.positive?
    ((actual_quantity - forecast_quantity).to_f / forecast_quantity * 100).round(2)
  end
end
