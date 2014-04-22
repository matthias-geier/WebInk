
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
      u = User.new(1, 15)
      assert 1, u.pk
      assert 1, u.ref
      assert 15, u.length
    end

    it "should take a full-field array without pk and set the fields" do
      u = User.new(15)
      assert 15, u.length
    end

    it "should raise an error when too few or too many arguments are given" do
      assert_raises(LoadError){ User.new(1,2,3) }
      assert_raises(LoadError){ AppleTree.new(1,2) }
    end

    it "should take a hash with any key number and set the fields" do
      u = User.new(:ref => 1, :length => 15)
      assert 1, u.pk
      assert 1, u.ref
      assert 15, u.length

      a = AppleTree.new(:color => "blue")
      assert_nil a.pk
      assert_nil a.note
      assert "blue", a.color
    end

    it "should set foreign keys for both accessors" do
      @a.update_fields(:user => 15, :color_spray_gnu => [17])
      assert 15, @a.user_ref
      assert [17], @a.color_spray
    end
  end

  describe "save and delete model" do
    it "should persist a new model to the database" do
      u = User.new(:length => 349)
      u.save
      assert Ink::Database.database.last_inserted_pk(User), u.pk
      u_per = User.find{ |s| s.where("#{User.primary_key}=#{u.pk}") }.first
      assert 349, u_per.length
      u.delete
      assert_nil User.find{ |s| s.where("#{User.primary_key}=#{u.pk}") }.first
    end

    it "should update an existing model in the database" do
      u = User.new(:length => 349)
      u.save
      u.length = 350
      u.save
      u_per = User.find{ |s| s.where("#{User.primary_key}=#{u.pk}") }.first
      assert 350, u_per.length
      u.delete
      assert_nil User.find{ |s| s.where("#{User.primary_key}=#{u.pk}") }.first
    end
  end

  describe "static declarations" do
    it "should own the proper foreign keys" do
      assert_equal "INTEGER", AppleTree.foreign_key_type
      assert_equal "apple_tree_id", AppleTree.foreign_key
      assert_equal "user_ref", User.foreign_key
    end

    it "should own the proper primary keys" do
      assert_equal "INTEGER", AppleTree.primary_key_type
      assert_equal :id, AppleTree.primary_key
      assert_equal :ref, User.primary_key
    end

    it "should generate the correct table name for a model" do
      assert_equal "apple_tree", AppleTree.table_name
      assert_equal "user", User.table_name
    end

    it "should generate the correct sanitized table name for a model" do
      assert_equal "`apple_tree`", AppleTree.table_name!
      assert_equal "`user`", User.sanitized_table_name
    end

    it "should calculate the correct last inserted primary key" do
      u = User.new(15)
      u.save
      assert_equal 1, Ink::Database.database.last_inserted_pk(User)
      u.delete
    end
  end

  describe "find instances" do
    before do
      @user1 = User.new(25)
      @user1.save
      @user2 = User.new(26)
      @user2.save
    end

    after do
      @user1.delete
      @user2.delete
      @user1 = @user2 = nil
    end

    it "should find both users when just calling find" do
      users = User.find.map(&:pk)
      assert users.include?(@user1.pk)
      assert users.include?(@user2.pk)
    end

    it "should find only one user when find is filtered" do
      user = User.find{ |s| s.where('length=25') }.first
      assert_equal @user1.pk, user.pk
    end
  end
end
