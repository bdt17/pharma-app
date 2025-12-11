class User < ApplicationRecord
  # Devise modules already here, for example:
  # devise :database_authenticatable, :registerable,
  #        :recoverable, :rememberable, :validatable

  has_many :trucks, dependent: :destroy
end
