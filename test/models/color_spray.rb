class ColorSpray < Ink::Model
  def self.fields
    {
      :color => [ "VARCHAR(255)", "NOT NULL" ],
      :gnu => "PRIMARY KEY",
    }
  end
  def self.foreign
    {
      "AppleTree" => "many_many",
      "User" => "one_one",
    }
  end
end
