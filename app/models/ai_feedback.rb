class AiFeedback < ApplicationRecord
  belongs_to :ai_insight

  FEEDBACK_TYPES = %w[accurate inaccurate helpful not_helpful].freeze

  validates :feedback_type, presence: true, inclusion: { in: FEEDBACK_TYPES }
  validates :rating, numericality: { in: 1..5 }, allow_nil: true

  scope :positive, -> { where(feedback_type: %w[accurate helpful]) }
  scope :negative, -> { where(feedback_type: %w[inaccurate not_helpful]) }
  scope :unused, -> { where(used_for_training: false) }

  def positive?
    %w[accurate helpful].include?(feedback_type)
  end

  def negative?
    %w[inaccurate not_helpful].include?(feedback_type)
  end

  def mark_used_for_training!
    update!(used_for_training: true)
  end
end
