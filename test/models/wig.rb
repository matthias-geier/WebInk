class Wig < Ink::Model
  def self.fields
    {
      :ref => "PRIMARY KEY",
      :length => [ "INTEGER" ],
    }
  end

  def self.foreign
    {
      "AppleTree" => "one_many",
      "ColorSpray" => "one_one",
    }
  end
end
