class Region < ApplicationRecord
  has_many :sites, dependent: :destroy
  has_many :trucks, through: :sites
end
