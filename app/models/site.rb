class Site < ApplicationRecord
  belongs_to :region
  has_many :trucks, dependent: :nullify
end
