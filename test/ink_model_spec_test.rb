
describe Ink::Model do
  describe "initialize model" do
    before do
      @a = AppleTree.new
    end

    after do
      @a = nil
    end

    it "should create accessors for all fields" do
      AppleTree.fields.keys.each do |f|
        assert @a.respond_to?(f)
        assert @a.respond_to?("#{f}=")
      end
    end

    it "should create an accessor for the primary key" do
      assert @a.respond_to?("pk")
      assert @a.respond_to?("pk=")
    end

    it "should create accessors for all foreign assocs" do
      AppleTree.foreign.keys.each do |f|
        assert @a.respond_to?(f.underscore)
        assert @a.respond_to?("#{f.underscore}=")
        assert @a.respond_to?(f.constantize.foreign_key)
        assert @a.respond_to?("#{f.constantize.foreign_key}=")
      end
    end
  end

  describe "update fields" do
    before do
      @a = AppleTree.new
    end

    after do
      @a = nil
    end

    it "should take a full-field array as argument and set the fields" do
      w = Wig.new(1, 15)
      assert 1, w.pk
      assert 1, w.ref
      assert 15, w.length
    end

    it "should take a full-field array without pk and set the fields" do
      w = Wig.new(15)
      assert 15, w.length
    end

    it "should raise an error when too few or too many arguments are given" do
      assert_raises(LoadError){ Wig.new(1,2,3) }
      assert_raises(LoadError){ AppleTree.new(1,2) }
    end

    it "should take a hash with any key number and set the fields" do
      w = Wig.new(:ref => 1, :length => 15)
      assert 1, w.pk
      assert 1, w.ref
      assert 15, w.length

      a = AppleTree.new(:color => "blue")
      assert_nil a.pk
      assert_nil a.note
      assert "blue", a.color
    end

    it "should set foreign keys for both accessors" do
      @a.update_fields(:wig => 15, :color_spray_ref => [17])
      assert 15, @a.wig_ref
      assert [17], @a.color_spray
    end
  end

  describe "save and delete model" do
    it "should persist a new model to the database" do
      w = Wig.new(:length => 349)
      w.save
      assert Ink::Database.database.last_inserted_pk(Wig), w.pk
      w_persisted = Wig.find{ |s| s.where("#{Wig.primary_key}=#{w.pk}") }.first
      assert 349, w_persisted.length
      w.delete
      assert_nil Wig.find{ |s| s.where("#{Wig.primary_key}=#{w.pk}") }.first
    end

    it "should update an existing model in the database" do
      w = Wig.new(:length => 349)
      w.save
      w.length = 350
      w.save
      w_persisted = Wig.find{ |s| s.where("#{Wig.primary_key}=#{w.pk}") }.first
      assert 350, w_persisted.length
      w.delete
      assert_nil Wig.find{ |s| s.where("#{Wig.primary_key}=#{w.pk}") }.first
    end
  end

  describe "saved tree" do
    before do
      @apple_tree = AppleTree.new(:color => "yellow")
      @apple_tree.save
      @wig = Wig.new("length" => 15)
      @wig.apple_tree = @apple_tree
      @wig.save
      @green_tree = AppleTree.new("green", "comment", 6)
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
      @wig.delete
      @wig = nil
      @apple_tree.delete
      @apple_tree = nil
    end

    describe "one_many relationships" do
      before do
        @wig.apple_tree = nil
        @apple_tree.wig = nil
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
      end

      it "should find the tree as reference on the spray" do
        @spray.find_references(AppleTree)
        assert_equal @apple_tree.pk, @spray.apple_tree.first.pk
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

    it "should generate the correct table name for a model" do
      assert_equal "apple_tree", AppleTree.table_name
      assert_equal "wig", Wig.table_name
    end

    it "should calculate the correct last inserted primary key" do
      w = Wig.new(15)
      w.save
      assert_equal 1, Ink::Database.database.last_inserted_pk(Wig)
      w.delete
    end
  end
end
