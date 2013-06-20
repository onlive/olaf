# Copyright (C) 2013 OL2, Inc.  All Rights Reserved.


#
#
# UNTESTED!  Ready for more testing, but not ready to actually use!
#
#

require 'minitest/autorun'

# We include Nodule for the Cassandra setup, but we don't create a
# Nodule Topology for testing.
require 'nodule/cassandra'

require 'olaf'
require 'olaf/cassandra_model.rb'

TEST_UUID = "d9a78617-ae38-4fef-84a3-8a5b27c44f3a"

class CassTestModel
  include Olaf::CassandraProperties

  property :foo, String, :consistency => {
    :read => Olaf::Consistency::ONE, :write => Olaf::Consistency::QUORUM }
  property :baz, String, :consistency => {
    :read => Olaf::Consistency::ONE, :write => Olaf::Consistency::QUORUM }
  property :woo, String, :consistency => {
    :read => Olaf::Consistency::ONE, :write => Olaf::Consistency::QUORUM }

  # Properties with different consistency -- ensure they're read and
  # written separately.
  property :other_a, String, :consistency => {
    :read => Olaf::Consistency::TWO, :write => Olaf::Consistency::ONE }
  property :other_b, String, :consistency => {
    :read => Olaf::Consistency::TWO, :write => Olaf::Consistency::ONE }

  self.column_family = 'CassTestModel'
end

class TestCassandraModels < MiniTest::Unit::TestCase
  # This is a pretty phenomenally slow operation.  We create new
  # config files and settings for Cassandra, download it if necessary
  # and run it locally.  Some of our dirty testing (all code in one
  # test, etc.) is because of this -- setup is just very, very slow.
  #
  def setup
    @cass = Nodule::Cassandra.new :keyspace => 'IntTestKeyspace', :verbose => true
    raise "Can't create Nodule::Cassandra!" unless @cass
    @cass.run
    @cass.create_keyspace

    Olaf::Cassandra.client_setup @cass.client
    @client = @cass.client

    # Delete all data in IntTestKeyspace
    #@client.clear_keyspace!

    #cfdef = CassandraThrift::CfDef.new :name => "foo", :keyspace => KEYSPACE
    #refute_nil cass.client.add_column_family cfdef
  end

  def teardown
    @cass.stop
  end

  def test_create
    tm = CassTestModel.create(:uuid => TEST_UUID, :foo => 'bar',
                              :baz => 'quux', :other_a => 'yeah')
    assert_equal 'bar', tm.foo
    assert_equal, 'quux', tm.baz
    assert_equal 'yeah', tm.other_a
    assert_equal nil, tm.woo

    @client.clear_keyspace!

    ### test_find

    CassTestModel.create(:uuid => TEST_UUID, :foo => 'bar',
                         :baz => 'quux', :other_a => 'yeah')
    tm = CassTestModel.find(TEST_UUID)

    assert_equal 'bar', tm.foo
    assert_equal, 'quux', tm.baz
    assert_equal 'yeah', tm.other_a
    assert_equal nil, tm.woo

    @client.clear_keyspace!

    ### test_update

    tm = CassTestModel.create(:uuid => TEST_UUID, :foo => 'bar',
                         :baz => 'quux', :other_a => 'yeah')
    tm.foo = 'bobo'
    tm.other_b = 'nope'
    tm.save

    tm = CassTestModel.find(TEST_UUID)

    assert_equal 'bobo', tm.foo
    assert_equal, 'quux', tm.baz
    assert_equal 'yeah', tm.other_a
    assert_equal 'nope', tm.other_b
    assert_equal nil, tm.woo
  end
end
