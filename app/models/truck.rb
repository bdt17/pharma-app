class Truck < ApplicationRecord
  belongs_to :site, optional: true
  has_many :monitorings, dependent: :destroy
  has_many :routes, dependent: :nullify

  delegate :region, to: :site, allow_nil: true

  def out_of_range?(temperature)
    return false if temperature.nil?
    return false if min_temp.nil? && max_temp.nil?

    (min_temp.present? && temperature < min_temp) ||
      (max_temp.present? && temperature > max_temp)
  end
end
