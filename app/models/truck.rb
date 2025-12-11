class Truck < ApplicationRecord
  has_many :monitorings, dependent: :destroy
end
