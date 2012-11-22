# -*- coding: utf-8 -*-
module Fluent
  class SuppressOutput < Output
    Fluent::Plugin.register_output('suppress', self)

    include Fluent::HandleTagNameMixin

    config_param :attr_keys,     :string,  :default => nil
    config_param :num,           :integer, :default => 3
    config_param :interval,      :integer, :default => 300

    def configure(conf)
      super

      unless @attr_keys
        raise ConfigError, "out_suppress: attr_keys is required."
      end

      if ( !@remove_tag_prefix and !@remove_tag_suffix and !@add_tag_prefix and !@add_tag_suffix )
        raise ConfigError, "out_suppress: Set remove_tag_prefix, remove_tag_suffix, add_tag_prefix or add_tag_suffix."
      end

      @keys  = @attr_keys.split(/ *, */)
      @slots = {}
    end

    def start
      super
    end

    def shutdown
      super
    end

    def emit(tag, es, chain)
      es.each do |time, record|
        key  = @keys.map{|k| record[k]}.join("\0")
        key  = tag + "\0" + key
        slot = @slots[key] ||= []

        # expire old records time
        expired = time.to_f - @interval
        while slot.first and slot.first <= expired
          slot.shift
        end

        if slot.length >= @num
          $log.debug "suppressed record: #{record.to_json}"
          next
        end

        slot.push(time.to_f)
        _tag = tag.clone
        filter_record(_tag, time, record)
        if tag != _tag
          Engine.emit(_tag, time, record)
        else
          $log.warn "Drop record #{record} tag '#{tag}' was not replaced. Can't emit record, cause infinity looping. Set remove_tag_prefix, remove_tag_suffix, add_tag_prefix or add_tag_suffix correctly."
        end
      end

      chain.next
    end
  end
end
