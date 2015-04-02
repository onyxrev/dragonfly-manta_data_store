# Dragonfly::MantaDataStore

Joyent Manta data store for use with the [Dragonfly](http://github.com/markevans/dragonfly) gem. Inspired by the [S3 Dragonfly gem](https://github.com/markevans/dragonfly-s3_data_store).

## Gemfile

```ruby
gem 'dragonfly-manta_data_store'
```

## Usage
Configuration (remember the require)

```ruby
require 'dragonfly/manta_data_store'

Dragonfly.app.configure do
  # ...

  datastore :manta,
    directory: 'my_images',
    url: 'https://us-east.manta.joyent.com',
    user: 'myuser,
    key_id: '00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00',
    key: 'ssh key...',
    durability_level: 2
  # ...
end
```

### Available configuration options

```ruby
```

### Serving directly from Manta

You can get the Manta url using

```ruby
Dragonfly.app.remote_url_for('some/uid')
```

or

```ruby
my_model.attachment.remote_url
```

or with an expiring url:

```ruby
my_model.attachment.remote_url(expires: 3.days.from_now)
```

or with an https url:

```ruby
my_model.attachment.remote_url(scheme: 'https')   # also configurable for all urls with 'url_scheme'
```

or with a custom host:

```ruby
my_model.attachment.remote_url(host: 'custom.domain')   # also configurable for all urls with 'url_host'
```
