
describe Ink::Model do
  describe "saved tree" do
    before do
      @apple_tree = AppleTree.new(:color => "yellow")
      @apple_tree.save
      tmp1 = Wig.new("length" => 16)
      tmp1.save
      tmp2 = Wig.new("length" => 17)
      tmp2.save
      @wig = Wig.new("length" => 15)
      @wig.apple_tree = @apple_tree
      @wig.save
      @green_tree = AppleTree.new("green", "comment", 6)
      @green_tree.save
      @spray = ColorSpray.new("color" => "blue")
      @spray.apple_tree = [@apple_tree]
      @spray.wig = @wig
      @spray.save
    end

    after do
      @green_tree.delete
      @green_tree = nil
      @spray.delete
      @spray = nil
      @wig.delete
      @wig = nil
      @apple_tree.delete
      @apple_tree = nil
    end

    describe "one_one relationships" do
      before do
        @wig.color_spray = nil
        @spray.wig = nil
      end

      it "should assign from opposite side too" do
        @spray.wig = []
        @spray.save
        @wig.color_spray = @spray
        @wig.save
        @spray.find_references(Wig){ |s| s._("ref=#{@wig.pk}") }
        assert @wig.pk, @spray.wig.pk
        @wig.color_spray = []
        @wig.save
      end

      it "should find the wig as reference on the spray" do
        @spray.find_references(Wig)
        assert_equal @wig.pk, @spray.wig.pk
        assert_equal @wig.pk, @spray.wig_ref
      end

      it "should find the spray as a single reference on the wig" do
        @wig.find_references(ColorSpray)
        assert_equal @spray.pk, @wig.color_spray.pk
        assert_equal @spray.pk, @wig.color_spray_gnu
      end

      it "should unset the wig when emptying the assoc on the spray" do
        @spray.wig = []
        @spray.save
        @wig.find_references(ColorSpray)
        assert_nil @wig.color_spray
        @wig.color_spray = @spray
        @wig.save
      end
    end

    describe "one_many relationships" do
      before do
        @wig.apple_tree = nil
        @apple_tree.wig = nil
      end

      it "should find the wig as reference on the tree" do
        @apple_tree.find_references(Wig)
        assert_equal @wig.pk, @apple_tree.wig.first.pk
        assert_equal @wig.pk, @apple_tree.wig_ref.first
      end

      it "should find the tree as a single reference on the wig" do
        @wig.find_references(AppleTree)
        assert_equal @apple_tree.pk, @wig.apple_tree.pk
        assert_equal @apple_tree.pk, @wig.apple_tree_id
      end

      it "should unset the wig when emptying the assoc on the tree" do
        @apple_tree.wig = []
        @apple_tree.save
        @wig.find_references(AppleTree)
        assert_nil @wig.apple_tree
        @wig.apple_tree = @apple_tree
        @wig.save
      end
    end

    describe "many_many relationships" do
      before do
        @apple_tree.color_spray = nil
        @spray.apple_tree = nil
      end

      it "should find the spray as reference on the tree" do
        @apple_tree.find_references(ColorSpray)
        assert_equal @spray.pk, @apple_tree.color_spray.first.pk
        assert_equal @spray.pk, @apple_tree.color_spray_gnu.first
      end

      it "should find the tree as reference on the spray" do
        @spray.find_references(AppleTree)
        assert_equal @apple_tree.pk, @spray.apple_tree.first.pk
        assert_equal @apple_tree.pk, @spray.apple_tree_id.first
      end

      it "should find both trees when assigned" do
        @green_tree.color_spray = [@spray]
        @green_tree.save
        @spray.find_references(AppleTree)
        assert @spray.apple_tree.map(&:pk).include?(@green_tree.pk)
        assert @spray.apple_tree.map(&:pk).include?(@apple_tree.pk)
      end
    end
  end
end
