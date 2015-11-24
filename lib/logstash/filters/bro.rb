# encoding: utf-8
# *NOTE*: I only somwhat know what I'm doing and this is _slightly_ tested.
#         Use at your own risk (though I welcome assistance)

require "logstash/filters/base"
require "logstash/namespace"
require "logstash/timestamp"

require "csv"
require "bigdecimal"

# The Bro filter takes an event field containing Bro log data, parses it,
# and stores it as individual fields with the names parsed from the header.
class LogStash::Filters::Bro < LogStash::Filters::Base
  config_name "bro"
  milestone 1

  # The CSV data in the value of the `source` field will be expanded into a
  # data structure.
  config :source, :validate => :string, :default => "message"

  # Define a list of column names (in the order they appear in the CSV,
  # as if it were a header line). If `columns` is not configured, or there
  # are not enough columns specified, the default column names are
  # "column1", "column2", etc. In the case that there are more columns
  # in the data than specified in this column list, extra columns will be auto-numbered:
  # (e.g. "user_defined_1", "user_defined_2", "column3", "column4", etc.)
  #config :columns, :validate => :array, :default => []

  # Define the column separator value. If this is not specified, the default
  # is a tab '	'.
  # Optional.
  config :separator, :validate => :string, :default => '	'

  # Define the set separator value. If this is not specified, the default
  # is a comma ','.
  # Optional.
  config :set_separator, :validate => :string, :default => ','

  # Define target field for placing the data.
  # Defaults to writing to the root of the event.
  config :target, :validate => :string

  public
  def register

    @meta = { "path" => {} }

  end # def register

  public
  def filter(event)
    return unless filter?(event)

    @logger.debug? and @logger.debug("Running bro filter", :event => event)

    matches = 0

    if !event.include?("path")
      @logger.error("The bro filter requires a \"path\" field typically added by the \"file\" input in the input section of the logstash config!")
    else
      path_ = event["path"]
      if !@meta.has_key?(path_)
        @meta[path_] = {}
      end
    end

    if event[@source]
      if event[@source].is_a?(String)
        event[@source] = [event[@source]]
      end

      if event[@source].length > 1
        @logger.warn("bro filter only works on fields of length 1",
                     :source => @source, :value => event[@source],
                     :event => event)
        return
      end

      raw = event[@source].first

      if @meta[path_]["header_done"] == false or raw.start_with?("#separator")
        if raw.start_with?("#separator")
                @meta[path_]["header_done"] = false # This will reparse the header if we encounter a new one
        	@meta[path_]["separator"]   = raw.partition(/\s/)[2]
        elsif raw.start_with?("#set_separator")
		sep = @meta[path_]["separator"]
        	@meta[path_]["set_separator"] = raw.partition(/#{sep}/)[2]
        elsif raw.start_with?("#empty_field")
		sep = @meta[path_]["separator"]
        	@meta[path_]["empty_field"]   = raw.partition(/#{sep}/)[2]
        elsif raw.start_with?("#unset_field")
		sep = @meta[path_]["separator"]
        	@meta[path_]["unset_field"]   = raw.partition(/#{sep}/)[2]
        elsif raw.start_with?("#path")
		sep = @meta[path_]["separator"]
        	@meta[path_]["path"]  = raw.partition(/#{sep}/)[2]
        elsif raw.start_with?("#fields")
		sep = @meta[path_]["separator"]
        	@meta[path_]["columns"] = raw.partition(/#{sep}/)[2].split(/#{sep}/)
        elsif raw.start_with?("#types")
		sep = @meta[path_]["separator"]
        	@meta[path_]["types"]  = raw.partition(/#{sep}/)[2].split(/#{sep}/)
        	# Map the Bro types to ES types
        	@meta[path_]["types"].each_index do |i|
        		case @meta[path_]["types"][i]
        		when "count"
        			@meta[path_]["types"][i] = "int"
        		when "double"
        			@meta[path_]["types"][i] = "float"
        		when "interval"
        			@meta[path_]["types"][i] = "float"
        		when "time"
        			@meta[path_]["types"][i] = "time"
        		else
        			@meta[path_]["types"][i] = "string"
        		end
        	end
        	@meta[path_]["header_done"] = true
        end

        if @logger.info? and @meta[path_]["header_done"] == true
            @logger.info("separator: \"#{@meta[path_]["separator"]}\"")
            @logger.info("path:      \"#{path_}\"")
            @logger.info("columns:   \"#{@meta[path_]["columns"]}\"")
            @logger.info("types:     \"#{@meta[path_]["types"]}\"")
        end

        event.cancel
        return

      end # End header_done == false

      begin
        sep = @meta[path_]["separator"]
        #values = CSV.parse_line(raw, :col_sep => sep)
        values = raw.split(/#{sep}/)

        if @target.nil?
          # Default is to write to the root of the event.
          dest = event
        else
          dest = event[@target] ||= {}
        end

	cols  = @meta[path_]["columns"]
	types = @meta[path_]["types"]

        values.each_index do |i|
          field_name = cols[i] || "column#{i+1}"
          field_type = types[i] || "string"

          case field_type
          when "int"
          	values[i] = values[i].to_i
          when "float"
          	values[i] = values[i].to_f
          when "time" # Create an actual timestamp
          	# Truncate timestamp to millisecond precision
          	secs = BigDecimal.new(values[i])
          	dest["#{field_name}_secs"] = secs.to_f
          	msec  = secs * 1000 # convert to whole number of milliseconds
          	msec  = msec.to_i
          	values[i] = Time.at(msec / 1000, (msec % 1000) * 1000)
          end

          dest[field_name] = values[i]
        end

        # Add some additional data
        dest["@timestamp"]  = LogStash::Timestamp.new(dest["ts"])
        dest["ts_end"]      = LogStash::Timestamp.new(dest["ts"] + dest["duration"]) if not dest["duration"].nil?
        dest["ts"]          = LogStash::Timestamp.new(dest["ts"])
        dest["bro_logtype"] = @meta[path_]["path"]

        filter_matched(event)
      rescue => e
        event.tag "_broparsefailure"
        @logger.warn("Trouble parsing bro", :source => @source, :raw => raw,
                      :exception => e)
        return
      end # begin
    end # if event

    @logger.debug("Event after bro filter", :event => event)

  end # def filter

end # class LogStash::Filters::Bro# encoding: utf-8

