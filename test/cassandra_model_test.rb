# Copyright (C) 2013 OL2, Inc.  All Rights Reserved.

require 'minitest/autorun'

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

  self.column_family = 'CassTestModel'
end

class TestCassandraModels < MiniTest::Unit::TestCase
  def setup
    # This should only actually be mocked the first time
    client = Object.new
    stub(::Cassandra).new('Keyspace', '127.0.0.1:9160', {}) { client }

    unless Olaf::Cassandra.client?
      Olaf::Cassandra.client_setup
    end
    @client = Olaf::Cassandra.client
  end

  def test_find
    mock(@client).get('CassTestModel', TEST_UUID, ['foo'],
                      :consistency => Olaf::Consistency::ONE) {
      { 'foo' => 'bar' }
    }

    tm = CassTestModel.find(TEST_UUID)
    assert_equal 'bar', tm.foo
  end

  def test_create
    mock(@client).insert('CassTestModel', TEST_UUID,
                         { 'foo' => 'bar' },
                         :consistency => Olaf::Consistency::QUORUM)

    tm = CassTestModel.create(:uuid => TEST_UUID, :foo => 'bar')
    assert_equal 'bar', tm.foo
    assert_equal TEST_UUID, tm.uuid
  end

  def test_update
    mock(@client).insert('CassTestModel', TEST_UUID,
                         { 'foo' => 'bar', 'baz' => 'quux' },
                         :consistency => Olaf::Consistency::QUORUM)
    mock(@client).insert('CassTestModel', TEST_UUID,
                         { 'foo' => 'baz', 'baz' => 'quux', 'woo' => 'ha' },
                         :consistency => Olaf::Consistency::QUORUM)

    # First insert
    tm = CassTestModel.create(:uuid => TEST_UUID, 'foo' => 'bar', :baz => 'quux')

    # Now update
    tm.foo = 'baz'
    tm.woo = 'ha'
    tm.save
  end
end
