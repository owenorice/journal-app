class Entry < ApplicationRecord
  has_one :pin, dependent: :destroy
end
