require 'cgi'

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

  def put_object(path, content, headers)
    @store[path] = {
      :headers => headers,
      :content => content
    }

    [ path, {} ]
  end

  def get_object(path)
    raise RubyManta::MantaClient::ResourceNotFound unless @store[path]

    headers = @store[path][:headers].dup
    headers["m-dragonfly"] = headers.delete :m_dragonfly

    [ @store[path][:content], headers ]
  end

  def delete_object(path)
    @store.delete path

    [ true, {} ]
  end

  def gen_signed_url(expiry, method, path)
    fake_key = rand(36**128).to_s(36)

    key_id = CGI.escape("/#{user}/keys/#{fake_key}")

    "#{domain}#{path}?algorithm=rsa-sha1&expires=#{expiry}&keyId=#{key_id}"
  end
end
