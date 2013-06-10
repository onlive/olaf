require 'uuidtools'

module UUIDTools
  class UUID
    def as_json(*args)
      self.to_s.as_json(*args)
    end
  end
end