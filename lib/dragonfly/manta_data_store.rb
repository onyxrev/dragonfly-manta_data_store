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
      @root_path        = options[:root_path]
      @storage_headers  = options[:storage_headers] || {}
    end

    attr_accessor :directory, :url, :user, :key, :durability_level, :region, :url_scheme, :url_host, :root_path, :storage_headers

    def write(content, options = {})
      ensure_configured
      ensure_directory
      store_content(content, options)
    end

    def read(uid)
      ensure_configured
      response, headers = storage.get_object(full_path(uid))

      [ response, headers_to_meta(headers) ]
    rescue RubyManta::MantaClient::ResourceNotFound => e
      nil
    end

    def destroy(uid)
      storage.delete_object(full_path(uid))
    rescue => e
      Dragonfly.warn("#{self.class.name} destroy error: #{e}")
    end

    def url_for(uid, options = {})
      scheme = options[:scheme] || url_scheme

      if options[:expires]
        url_without_scheme = storage.gen_signed_url(options[:expires], :get, full_path(uid))
      else
        host = options[:host] || url_host || region_host

        url_without_scheme = "#{host}#{full_path(uid)}"
      end

      "#{scheme}://#{url_without_scheme}"
    end

    def storage
      @storage ||= begin
        RubyManta::MantaClient.new(url, user, key)
      end
    end

    def directory_exists?
      storage.list_directory(public_directory, :head => true)
      true
    rescue RubyManta::MantaClient::UnknownError => e
      false
    end

    def domain
      REGIONS[get_region]
    end

    private

    def headers_to_meta(headers)
      begin
        JSON.parse(headers["m-dragonfly"])
      rescue => e
        nil
      end
    end

    def meta_to_header(meta = {})
      { :m_dragonfly => JSON.dump(meta) }
    end

    def store_content(content, options = {})
      uid = options[:path] || generate_uid(content.name || 'file')

      headers = {
        :content_type => content.mime_type
      }

      headers.merge!(meta_to_header(content.meta))
      headers.merge!(options[:headers]) if options[:headers]

      path = full_path(uid)
      mkdir_for_file_path(path)

      content.file do |file|
        storage.put_object(
          path,
          file.read,
          full_storage_headers(headers)
        )
      end

      uid
    end

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
        mkdir(public_directory) unless directory_exists?

        @directory_created = true
      end
    end

    def public_directory
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

    def full_storage_headers(options = {})
      {
        "durability_level" => durability_level
      }.merge(storage_headers).merge(options)
    end

    def full_path(uid)
      File.join *[public_directory, root_path, uid].compact
    end

    def valid_regions
      REGIONS.keys
    end

    def mkdir_for_file_path(file_with_path)
      mkdir_with_intermediates file_with_path.split("/")[0..-2].join("/")
    end

    def mkdir_with_intermediates(path)
      path_components = path.split("/")

      path_components.length.times do |index|
        path_to_make = path_components[0..index].join("/")

        if path_to_make.start_with?(public_directory) and not path_to_make.empty?
          mkdir path_to_make
        end
      end
    end

    def mkdir(path)
      storage.put_directory(path)
    end
  end
end
