require 'spec_helper'
require 'ruby_manta_stub'
require 'dragonfly/spec/data_store_examples'
require 'yaml'
require 'dragonfly/manta_data_store'
require 'pry'

describe Dragonfly::MantaDataStore do
  # To run these tests, put a file ".manta_spec.yml" in the dragonfly root dir, like this:
  # user: XXXXXXXXXX
  # enabled: true
  #
  # and load your SSH key as the 'DRAGONFLY_MANTA_STORE_SSH_KEY' ENV variable
  if File.exist?(file = File.expand_path('../../.manta_spec.yml', __FILE__))
    binding.pry
    config = YAML.load_file(file)
    KEY = ENV['DRAGONFLY_MANTA_STORE_SSH_KEY']
    enabled = config['enabled']
  else
    enabled = false
  end

  if enabled
    # Make sure it's a new directory name
    DIRECTORY = "dragonfly-test-#{Time.now.to_i.to_s(36)}"

    before(:each) do
      @data_store = Dragonfly::MantaDataStore.new(
        :directory => DIRECTORY,
        :user      => config['user'],
        :url       => "https://us-east.manta.joyent.com",
        :key       => KEY
      )
    end
  else
    DIRECTORY = 'test-directory'

    let!(:fake_client){ RubyMantaStub.new }

    before(:each) do
      RubyManta::MantaClient.stub(:new).and_return(fake_client)

      @data_store = Dragonfly::MantaDataStore.new(
        :directory => DIRECTORY,
        :user      => 'XXXXXXXXX',
        :url       => "XXXXXXXXX",
        :key       => 'XXXXXXXXX'
      )

      fake_client.user   = @data_store.user
      fake_client.domain = @data_store.domain
    end
  end

  it_should_behave_like 'data_store'

  let (:app) { Dragonfly.app }
  let (:content) { Dragonfly::Content.new(app, "eggheads") }
  let (:new_content) { Dragonfly::Content.new(app) }

  describe "registering with a symbol" do
    it "registers a symbol for configuring" do
      app.configure do
        datastore :manta
      end
      app.datastore.should be_a(Dragonfly::MantaDataStore)
    end
  end

  describe "write" do
    it "should use the name from the content if set" do
      content.name = 'doobie.doo'
      uid = @data_store.write(content)
      uid.should =~ /doobie\.doo$/
      new_content.update(*@data_store.read(uid))
      new_content.data.should == 'eggheads'
    end

    it "should work ok with files with funny names" do
      content.name = "A Picture with many spaces in its name (at 20:00 pm).png"
      uid = @data_store.write(content)
      uid.should =~ /A_Picture_with_many_spaces_in_its_name_at_20_00_pm_\.png$/
      new_content.update(*@data_store.read(uid))
      new_content.data.should == 'eggheads'
    end

    it "should allow for setting the path manually" do
      uid = @data_store.write(content, :path => 'hello/there')
      uid.should == 'hello/there'
      new_content.update(*@data_store.read(uid))
      new_content.data.should == 'eggheads'
    end
  end

  describe "domain" do
    it "should default to the us-east" do
      @data_store.domain.should == 'us-east.manta.joyent.com'
    end

    it "should return the correct domain" do
      @data_store.region = 'us-east'
      @data_store.domain.should == 'us-east.manta.joyent.com'
    end

    it "does raise an error if an unknown region is given" do
      @data_store.region = 'latvia-central'
      lambda{
        @data_store.domain
      }.should raise_error
    end
  end

  describe "not configuring stuff properly" do
    it "should require a directory name on write" do
      @data_store.directory = nil
      proc{ @data_store.write(content) }.should raise_error(Dragonfly::MantaDataStore::NotConfigured)
    end

    it "should require a key on write" do
      @data_store.key = nil
      proc{ @data_store.write(content) }.should raise_error(Dragonfly::MantaDataStore::NotConfigured)
    end

    it "should require a url on write" do
      @data_store.url = nil
      proc{ @data_store.write(content) }.should raise_error(Dragonfly::MantaDataStore::NotConfigured)
    end

    it "should require a directory on read" do
      @data_store.directory = nil
      proc{ @data_store.read('asdf') }.should raise_error(Dragonfly::MantaDataStore::NotConfigured)
    end

    it "should require a key on read" do
      @data_store.key = nil
      proc{ @data_store.read('asdf') }.should raise_error(Dragonfly::MantaDataStore::NotConfigured)
    end

    it "should require a url on read" do
      @data_store.url = nil
      proc{ @data_store.read('asdf') }.should raise_error(Dragonfly::MantaDataStore::NotConfigured)
    end
  end

  describe "root_path" do
    before do
      content.name = "something.png"
      @data_store.root_path = "some/path"
    end

    it "stores files in the provided sub directory" do
      @data_store.storage.should_receive(:put_object).with(/^\/#{@data_store.user}\/public\/#{DIRECTORY}\/some\/path\/.*_something\.png$/, anything, anything)
      @data_store.write(content)
    end

    it "finds files in the provided sub directory" do
      mock_response = double("response", body: "", headers: {})
      uid = @data_store.write(content)
      @data_store.storage.should_receive(:get_object).with(/^\/#{@data_store.user}\/public\/#{DIRECTORY}\/some\/path\/.*_something\.png$/).and_return(mock_response)
      @data_store.read(uid)
    end

    it "does not alter the uid" do
      uid = @data_store.write(content)
      uid.should include("something.png")
      uid.should_not include("some/path")
    end

    it "destroys files in the provided sub directory" do
      uid = @data_store.write(content)
      @data_store.storage.should_receive(:delete_object).with(/^\/#{@data_store.user}\/public\/#{DIRECTORY}\/some\/path\/.*_something\.png$/)
      @data_store.destroy(uid)
    end

    describe "url_for" do
      before do
        @uid = @data_store.write(content)
      end

      it "returns the uid prefixed with the root_path" do
        @data_store.url_for(@uid).should =~ /some\/path\/.*_something\.png/
      end

      it "gives an expiring url" do
        expires = 1301476942
        @data_store.url_for(@uid, :expires => expires).should =~ /\/some\/path\/.*_something\.png\?algorithm=rsa-sha1&expires=#{expires}&keyId=\/#{@data_store.user}\/keys\//
      end
    end

    describe "autocreating the directory" do
      it "should create the directory on write if it doesn't exist" do
        @data_store.directory = "dragonfly-test-blah-blah-#{rand(100000000)}"
        @data_store.write(content)
      end

      it "should not try to create the directory on read if it doesn't exist" do
        @data_store.directory = "dragonfly-test-blah-blah-#{rand(100000000)}"
        @data_store.send(:storage).should_not_receive(:put_directory)
        @data_store.read("gungle").should be_nil
      end
    end
  end

  describe "headers" do
    before(:each) do
      @data_store.storage_headers = {'x-zomg' => 'biscuithead'}
    end

    it "should allow configuring globally" do
      @data_store.storage.should_receive(:put_object).with(anything, anything,
        hash_including('x-zomg' => 'biscuithead')
      )
      @data_store.write(content)
    end

    it "should allow adding per-store" do
      @data_store.storage.should_receive(:put_object).with(anything, anything,
        hash_including('x-zomg' => 'biscuithead', 'hello' => 'there')
      )
      @data_store.write(content, :headers => {'hello' => 'there'})
    end

    it "should let the per-store one take precedence" do
      @data_store.storage.should_receive(:put_object).with(anything, anything,
        hash_including('x-zomg' => 'override!')
      )
      @data_store.write(content, :headers => {'x-zomg' => 'override!'})
    end

    it "should write setting the content type" do
      @data_store.storage.should_receive(:put_object) do |_, __, headers|
        headers[:content_type].should == 'image/png'
      end
      content.name = 'egg.png'
      @data_store.write(content)
    end

    it "allow overriding the content type" do
      @data_store.storage.should_receive(:put_object) do |_, __, headers|
        headers[:content_type].should == 'text/plain'
      end
      content.name = 'egg.png'
      @data_store.write(content, :headers => {:content_type => 'text/plain'})
    end
  end

  describe "urls for serving directly" do
    before(:each) do
      @uid = 'some/path/on/manta'
    end

    it "should give an expiring url" do
      expires = 1301476942

      @data_store.url_for(@uid, :expires => expires).should =~
      %r{^https://#{@data_store.domain}/#{@data_store.user}/public/#{DIRECTORY}/some/path/on/manta\?algorithm=rsa-sha1&expires=#{expires}&keyId=/#{@data_store.user}/keys\.*}
    end

    it "should allow for using https" do
      @data_store.url_for(@uid, :scheme => 'https').should =~ /^https:\/\//
    end

    it "should allow for always using https" do
      @data_store.url_scheme = 'https'
      @data_store.url_for(@uid).should =~ /^https:\/\//
    end

    it "should allow for customizing the host" do
      @data_store.url_for(@uid, :host => 'customised.domain.com').should == "http://customised.domain.com/#{@data_store.user}/public/#{DIRECTORY}/some/path/on/manta"
    end

    it "should allow the url_host to be customised permanently" do
      url_host = 'customised.domain.com/and/path'
      @data_store.url_host = url_host
      @data_store.url_for(@uid).should == "http://#{url_host}/#{@data_store.user}/public/#{DIRECTORY}/some/path/on/manta"
    end
  end
end
