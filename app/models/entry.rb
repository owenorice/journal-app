class Entry < ApplicationRecord
  has_one :pin, dependent: :destroy
  has_one_attached :icon_image

  validates :watering_frequency, numericality: { greater_than: 0, allow_nil: true }

  ICON_EMOJIS = %w[🌱 🌿 🍀 🌵 🌴 🌳 🌲 🪴 🌻 🌺 🌸 🌷 🌹 🪻 🍃 🌾 🎋 🎍 🍂 🍁].freeze

  def display_icon
    icon.presence || "🌱"
  end

  def needs_watering?
    return false unless watering_frequency.present?

    last_watered = updated_at
    last_watered + watering_frequency.days <= Time.current
  end
end
