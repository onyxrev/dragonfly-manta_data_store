require 'ruby-manta'
require 'dragonfly'

Dragonfly::App.register_datastore(:manta){ Dragonfly::MantaDataStore }

module Dragonfly
  class MantaDataStore

    # Exceptions
    class NotConfigured < RuntimeError; end

    REGIONS = {
      # default (and only as of now)
      'us-east' => 'us-east.manta.joyent.com'
    }

    def initialize(options = {})
      @directory        = options[:directory]
      @url              = options[:url]
      @user             = options[:user]
      @key              = options[:key]
      @durability_level = options[:durability_level] || 2
      @region           = options[:region] || REGIONS.keys.first
      @url_scheme       = options[:url_scheme] || 'http'
      @url_host         = options[:url_host]
    end

    attr_accessor :directory, :url, :user, :key, :durability_level, :region, :url_scheme, :url_host

    def write(content, options = {})
      ensure_configured
      ensure_directory
      store_content(content)
    end

    def read(uid)
      ensure_configured
      storage.get_object(full_path(uid))
    rescue => e
      # FIXME
      puts "error reading file #{e.inspect}"
      nil
    end

    def destroy(uid)
      storage.delete_object(full_path(uid))
    rescue => e
      Dragonfly.warn("#{self.class.name} destroy error: #{e}")
    end

    def url_for(uid, options = {})
      if options[:expires]
        storage.gen_signed_url(options[:expires], full_path(uid), :get)
      else
        scheme = options[:scheme] || url_scheme
        host   = options[:host]   || url_host || region_host

        "#{scheme}://#{host}#{full_path(uid)}"
      end
    end

    def store_content(content)
      uid = generate_uid(content.name || 'file')

      content.file do |file|
        binding.pry
        storage.put_object(
          full_path(uid),
          file.read,
          metadata({
            :content_type => content.mime_type
          })
        )
      end

      uid
    end

    def storage
      @storage ||= begin
        RubyManta::MantaClient.new(url, user, key)
      end
    end

    def directory_exists?
      storage.list_directory(full_directory, :head => true)
      true
    rescue RubyManta::MantaClient::UnknownError => e
      false
    end

    private

    def ensure_configured
      unless @configured
        [:directory, :url, :user, :key].each do |attr|
          raise NotConfigured, "You need to configure #{self.class.name} with #{attr}" if send(attr).nil?
        end

        @configured = true
      end
    end

    def ensure_directory
      unless @directory_created
        storage.put_directory(full_directory) unless directory_exists?

        @directory_created = true
      end
    end

    def full_directory
      "/#{@user}/public/#{@directory}"
    end

    def region_host
      REGIONS[get_region]
    end

    def get_region
      raise "Invalid region #{region} - should be one of #{valid_regions.join(', ')}" unless valid_regions.include?(region)
      region
    end

    def generate_uid(name)
      # S3 was using subdirectories but Manta is ZFS and it can handle up to
      # 281,474,976,710,656 files in a directory
      "#{Time.now.strftime '%Y_%m_%d_%H_%M_%S'}_#{rand(1000)}_#{name.gsub(/[^\w.]+/, '_')}"
    end

    def metadata(options = {})
      { :durability_level => durability_level }.merge options
    end

    def full_path(uid)
      File.join *[full_directory, uid].compact
    end

    def valid_regions
      REGIONS.keys
    end
  end
end
