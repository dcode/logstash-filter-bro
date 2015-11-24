# encoding: utf-8
require 'spec_helper'
require "logstash/filters/bro"

describe LogStash::Filters::Bro do
  describe "Process the bro log stream" do
    let(:config) do <<-CONFIG
      filter {
        bro { }
      }
    CONFIG
    end
  end
end
