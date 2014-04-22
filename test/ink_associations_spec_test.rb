
describe Ink::Model do
  describe "saved tree" do
    before do
      @apple_tree = AppleTree.new(:color => "yellow")
      @apple_tree.save
      tmp1 = User.new("length" => 16)
      tmp1.save
      tmp2 = User.new("length" => 17)
      tmp2.save
      @user = User.new("length" => 15)
      @user.apple_tree = @apple_tree
      @user.save
      @green_tree = AppleTree.new("green", "comment", 6)
      @green_tree.save
      @spray = ColorSpray.new("color" => "blue")
      @spray.apple_tree = [@apple_tree]
      @spray.user = @user
      @spray.save
    end

    after do
      @green_tree.delete
      @green_tree = nil
      @spray.delete
      @spray = nil
      @user.delete
      @user = nil
      @apple_tree.delete
      @apple_tree = nil
    end

    describe "one_one relationships" do
      before do
        @user.color_spray = nil
        @spray.user = nil
      end

      it "should assign from opposite side too" do
        @spray.user = []
        @spray.save
        @user.color_spray = @spray
        @user.save
        @spray.find_references(User){ |s| s.and!("ref=#{@user.pk}") }
        assert @user.pk, @spray.user.pk
        @user.color_spray = []
        @user.save
      end

      it "should find the user as reference on the spray" do
        @spray.find_references(User)
        assert_equal @user.pk, @spray.user.pk
        assert_equal @user.pk, @spray.user_ref
      end

      it "should find the spray as a single reference on the user" do
        @user.find_references(ColorSpray)
        assert_equal @spray.pk, @user.color_spray.pk
        assert_equal @spray.pk, @user.color_spray_gnu
      end

      it "should unset the user when emptying the assoc on the spray" do
        @spray.user = []
        @spray.save
        @user.find_references(ColorSpray)
        assert_nil @user.color_spray
        @user.color_spray = @spray
        @user.save
      end
    end

    describe "one_many relationships" do
      before do
        @user.apple_tree = nil
        @apple_tree.user = nil
      end

      it "should find the user as reference on the tree" do
        @apple_tree.find_references(User)
        assert_equal @user.pk, @apple_tree.user.first.pk
        assert_equal @user.pk, @apple_tree.user_ref.first
      end

      it "should find the tree as a single reference on the user" do
        @user.find_references(AppleTree)
        assert_equal @apple_tree.pk, @user.apple_tree.pk
        assert_equal @apple_tree.pk, @user.apple_tree_id
      end

      it "should unset the user when emptying the assoc on the tree" do
        @apple_tree.user = []
        @apple_tree.save
        @user.find_references(AppleTree)
        assert_nil @user.apple_tree
        @user.apple_tree = @apple_tree
        @user.save
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
