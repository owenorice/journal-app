class Entry < ApplicationRecord
  has_one :pin, dependent: :destroy

  validates :watering_frequency, numericality: { greater_than: 0, allow_nil: true }

  def needs_watering?
    return false unless watering_frequency.present?

    last_watered = updated_at
    last_watered + watering_frequency.days <= Time.current
  end
end
