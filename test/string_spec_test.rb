
class WigWam < Ink::Model
end

module Apache
end

describe String do
  describe "underscore transformation" do
    it "should transform camelcase to snakecase" do
      assert_equal "wig_wam", "WigWam".underscore
    end

    it "should inline transform camelcase to snakecase" do
      s = "WigWam"
      s.underscore!
      assert_equal "wig_wam", s
    end
  end

  describe "camelcase transformation" do
    it "should transform snakecase to camelcase" do
      assert_equal "WigWam", "wig_wam".camelize
    end

    it "should inline transform snakecase to camelcase" do
      s = "wig_wam"
      s.camelize!
      assert_equal "WigWam", s
    end
  end

  describe "transform string to constant" do
    it "should find classes" do
      assert_equal WigWam, "WigWam".constantize
    end

    it "should find modules" do
      assert_equal Apache, "Apache".constantize
    end

    it "should raise errors for bogus strings" do
      assert_raises(NameError){ "foo".constantize }
    end
  end
end
