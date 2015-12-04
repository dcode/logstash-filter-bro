# Logstash Plugin

This is a plugin for [Logstash](https://github.com/elastic/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Install

You can install/upgrade the binary version of this plugin by following these instructions.

~~~~~~~~~~

# Download gem
cd /tmp
curl -L 'https://app.box.com/shared/static/5wf3k4daxmny6o9kfzacihsyrs2tzv0s.gem' -o logstash-filter-bro-0.9.5.gem

# Install plugin
/opt/logstash/bin/plugin install ./logstash-filter-bro-0.9.5.gem

# Restart logstash
service logstash restart
~~~~~~~~~~

### Example config

This is how I setup this filter. I of course change the output to my preferred location (which is not usually stdout)
~~~~~~~~~~
# /etc/logstash/config.d/bro-logs.conf
input {
  file {
    path => "/opt/bro/logs/current/*.log"
    exclude => [
                "/opt/bro/logs/current/stderr.log",
                "/opt/bro/logs/current/stdout.log",
                "/opt/bro/logs/current/communication.log",
                "/opt/bro/logs/current/loaded_scripts.log"
                ]
    start_position => "beginning"
    sincedb_path => "/dev/null"
    add_field => { "[@metadata][stage]" => "bro_raw" }
  }
}

filter {
  if [@metadata][stage] == "bro_raw" {
    bro { }

    if [path] =~ /^\/.*\.log/ {
      mutate { remove_field => ["path"] }
    }
  }
}

output {
  if [@metadata][stage] == "bro_raw" {
    stdout { codec => rubydebug }
  }
}
~~~~~~~~~~

## Documentation

Logstash provides infrastructure to automatically generate documentation for this plugin. We use the asciidoc format to write documentation so any comments in the source code will be first converted into asciidoc and then into html. All plugin documentation are placed under one [central location](http://www.elastic.co/guide/en/logstash/current/).

- For formatting code or config example, you can use the asciidoc `[source,ruby]` directive
- For more asciidoc formatting tips, see the excellent reference here https://github.com/elastic/docs#asciidoc-guide

## Need Help?

Need help? Try #logstash on freenode IRC or the https://discuss.elastic.co/c/logstash discussion forum.

## Developing

### 1. Plugin Developement and Testing

#### Code
- To get started, you'll need JRuby with the Bundler gem installed.

- Create a new plugin or clone and existing from the GitHub [logstash-plugins](https://github.com/logstash-plugins) organization. We also provide [example plugins](https://github.com/logstash-plugins?query=example).

- Install dependencies
```sh
bundle install
```

#### Test

- Update your dependencies

```sh
bundle install
```

- Run tests

```sh
bundle exec rspec
```

### 2. Running your unpublished Plugin in Logstash

#### 2.1 Run in a local Logstash clone

- Edit Logstash `Gemfile` and add the local plugin path, for example:
```ruby
gem "logstash-filter-awesome", :path => "/your/local/logstash-filter-awesome"
```
- Install plugin
```sh
bin/plugin install --no-verify
```
- Run Logstash with your plugin
```sh
bin/logstash -e 'filter {awesome {}}'
```
At this point any modifications to the plugin code will be applied to this local Logstash setup. After modifying the plugin, simply rerun Logstash.

#### 2.2 Run in an installed Logstash

You can use the same **2.1** method to run your plugin in an installed Logstash by editing its `Gemfile` and pointing the `:path` to your local plugin development directory or you can build the gem and install it using:

- Build your plugin gem
```sh
gem build logstash-filter-awesome.gemspec
```
- Install the plugin from the Logstash home
```sh
bin/plugin install /your/local/plugin/logstash-filter-awesome.gem
```
- Start Logstash and proceed to test the plugin

## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elastic/logstash/blob/master/CONTRIBUTING.md) file.
