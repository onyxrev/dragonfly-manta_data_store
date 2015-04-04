require 'uri'

# just close enough to make the tests pass...
class RubyMantaStub
  attr_accessor :user, :domain

  def initialize
    @store = {}
    @directories = {}
  end

  def put_directory(directory)
    @directories[directory] ||= {}
  end

  def list_directory(directory, options)
    raise RubyManta::MantaClient::UnknownError unless @directories[directory]

    @directories[directory]
  end

  def put_object(path, content, meta)
    @store[path] = {
      :meta    => meta,
      :content => content
    }

    [ path, {} ]
  end

  def get_object(path)
    return nil unless @store[path]

    [ @store[path][:content], @store[path][:meta] ]
  end

  def delete_object(path)
    @store.delete path

    [ true, {} ]
  end

  def gen_signed_url(expiry, method, path)
    fake_key = rand(36**128).to_s(36)

    "https://#{domain}#{path}?algorithm=rsa-sha1&expires=#{expiry}&keyId=/#{user}/keys/#{fake_key}"
  end
end
