
describe AppleTree do
  describe "unsaved tree" do
    before do
      @apple_tree = AppleTree.new(["red", nil, 5])
    end

    after do
      @apple_tree = nil
    end

    it "should respond to pk" do
      assert @apple_tree.respond_to?(:pk)
    end

    it "should initially have a pk of nil" do
      assert_nil @apple_tree.pk
    end
  end

  describe "saved tree" do
    before do
      @apple_tree = AppleTree.new(["red", nil, 5])
      @apple_tree.save
    end

    after do
      @apple_tree.delete
      @apple_tree = nil
    end

    it "should be found when searching for the last inserted primary key" do
      assert_equal @apple_tree.pk, Ink::Database.database.find(AppleTree,
        Ink::R.where("#{AppleTree.primary_key}=" +
        "#{Ink::Database.database.last_inserted_pk(AppleTree)}")).first.pk
    end

    describe "load save tree from database" do
      before do
        @db_tree = Ink::Database.database.find(AppleTree).first
      end

      after do
        @db_tree = nil
      end

      it "should have the correct attributes" do
        assert_equal @apple_tree.color, @db_tree.color
        assert_equal @apple_tree.note, @db_tree.note
        assert_equal @apple_tree.height, @db_tree.height
      end
    end

    describe "one_many relationships" do
      before do
        @wig = Wig.new("length" => 15)
        @wig.apple_tree = @apple_tree
        @wig.save
      end

      after do
        @wig.delete
        @wig = nil
      end

      it "should find the wig as reference on the tree" do
        @apple_tree.find_references(Wig)
        assert_equal @wig.pk, @apple_tree.wig.first.pk
      end

      it "should find the tree as a single reference on the wig" do
        @wig.find_references(AppleTree)
        assert_equal @apple_tree.pk, @wig.apple_tree.pk
      end

      it "should unset the wig when emptying the assoc on the tree" do
        @apple_tree.wig = []
        @apple_tree.save
        @wig.find_references(AppleTree)
        assert_nil @wig.apple_tree
      end
    end

    describe "many_many relationships" do
      before do
        @green_tree = AppleTree.new(["green", "comment", 6])
        @green_tree.save
        @spray = ColorSpray.new("color" => "blue")
        @spray.apple_tree = [@apple_tree]
        @spray.save
      end

      after do
        @green_tree.delete
        @green_tree = nil
        @spray.delete
        @spray = nil
      end

      it "should find the spray as reference on the tree" do
        @apple_tree.find_references(ColorSpray)
        assert_equal @spray.pk, @apple_tree.color_spray.first.pk
      end

      it "should find the tree as reference on the spray" do
        @spray.find_references(AppleTree)
        assert_equal @apple_tree.pk, @spray.apple_tree.first.pk
      end

      it "should find both trees when assigned" do
        @green_tree.find_references(ColorSpray)
        @green_tree.color_spray << @spray
        @green_tree.save
        @spray.find_references(AppleTree)
        assert @spray.apple_tree.map(&:pk).include?(@green_tree.pk)
        assert @spray.apple_tree.map(&:pk).include?(@apple_tree.pk)
      end
    end
  end

  describe "static declarations" do
    it "should own the proper foreign keys" do
      assert_equal "INTEGER", AppleTree.foreign_key_type
      assert_equal "apple_tree_id", AppleTree.foreign_key
      assert_equal "wig_ref", Wig.foreign_key
    end

    it "should own the proper primary keys" do
      assert_equal "INTEGER", AppleTree.primary_key_type
      assert_equal :id, AppleTree.primary_key
      assert_equal :ref, Wig.primary_key
    end

    it "should translate the proper class names from a table name" do
      assert_equal AppleTree, Ink::Model.classname("apple_tree")
      assert_equal Wig, Ink::Model.classname("wig")
    end

    it "should translate the proper table name for a camelized string" do
      assert_equal "apple_tree", Ink::Model.str_to_tablename("AppleTree")
      assert_equal "wig", Ink::Model.str_to_tablename("Wig")
    end

    it "should translate the proper class name from a table name" do
      assert_equal "AppleTree", Ink::Model.str_to_classname("apple_tree")
      assert_equal "Wig", Ink::Model.str_to_classname("wig")
    end

    it "should generate the correct table name for a model" do
      assert_equal "apple_tree", AppleTree.table_name
      assert_equal "wig", Wig.table_name
    end

    it "should stringify the class name for a model" do
      assert_equal "AppleTree", AppleTree.class_name
    end

    it "should calculate the correct last inserted primary key" do
      w = Wig.new([15])
      w.save
      assert_equal 1, Ink::Database.database.last_inserted_pk(Wig)
      w.delete
    end
  end
end
