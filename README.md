# Dragonfly::MantaDataStore

[![Build Status](https://travis-ci.org/onyxrev/dragonfly-manta_data_store.svg?branch=master)](https://travis-ci.org/onyxrev/dragonfly-manta_data_store)

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
    key: 'actual ASCII ssh key (load from file or ENV)',
    durability_level: 2
  # ...
end
```

### Available configuration options

```ruby
:directory         # base directory within your public directory
:url               # defaults to "https://us-east.manta.joyent.com"
:user              # your joyent user
:key               # SSH ASCII key
:durability_level  # defaults to 2
:region            # defaults to 'us-east'
:url_scheme        # defaults to 'http'
:url_host          # maybe useful for a CDN?
:root_path         # another base directory on top of :directory (mostly to match the S3 store)
:storage_headers   # headers to include for all stored objects
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
