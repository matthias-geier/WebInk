
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
      @a.update_fields(:wig => 15, :color_spray_gnu => [17])
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

  describe "find instances" do
    before do
      @wig1 = Wig.new(25)
      @wig1.save
      @wig2 = Wig.new(26)
      @wig2.save
    end

    after do
      @wig1.delete
      @wig2.delete
      @wig1 = @wig2 = nil
    end

    it "should find both wigs when just calling find" do
      wigs = Wig.find.map(&:pk)
      assert wigs.include?(@wig1.pk)
      assert wigs.include?(@wig2.pk)
    end

    it "should find only one wig when find is filtered" do
      wig = Wig.find{ |s| s.where('length=25') }.first
      assert_equal @wig1.pk, wig.pk
    end
  end
end
