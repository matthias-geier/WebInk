
class String
  def constantize
    return Module.const_get(self.to_s)
  end

  def camelize
    return self.to_s.split(/_/).map(&:capitalize).join
  end

  def camelize!
    self.replace(self.to_s.camelize)
  end

  def underscore
    return self.to_s.split(/([A-Z]?[^A-Z]*)/).reject(&:empty?).
      map(&:downcase).join('_')
  end

  def underscore!
    self.replace(self.to_s.underscore)
  end
end
