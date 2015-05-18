require 'bento_search/results'
require 'active_support/concern'
require 'json'

# 
# 
# * Works by getting and setting instance variables directly, ignores getters/setters
# * This means decorated values are NOT included in serialization, the raw
#   values are what is serialized. This is intended, we serialize internal
#   state, not decoration which can be recreated. You should make sure the decorators you
#   want are applied after de-serialization. 
# * preserves html_safety status in serialization, by adding extra `_attr_htmlsafe: true` key/value
module BentoSearch::Results::Serialization
  extend ActiveSupport::Concern

  included do
    class_attribute :_serializable_attrs, :_serializable_attr_options
    self._serializable_attrs = []
    self._serializable_attr_options = {}
  end

  class_methods do
    # Just a macro to mark a property name serializable
    def serializable_attr(symbol, options = nil)
      symbol = symbol.to_s
      self._serializable_attrs << symbol
      if options 
        self._serializable_attr_options[symbol] = options
      end
    end

    # convenience macro to do attr_accessor AND mark it
    # serializable
    def serializable_attr_accessor(symbol)
      self.send(:attr_accessor, symbol)
      self.serializable_attr symbol
    end

    def from_serializable_hash(hash)
      o = self.new
      hash.each_pair do |key, value|
        key = key.to_s

        next if key =~ /\A_.*_htmlsafe\Z/

        if hash["_#{key}_htmlsafe"] == true && value.respond_to?(:html_safe)
          value = value.html_safe
        end

        o.instance_variable_set("@#{key}", value)
      end

      return o
    end

    def from_json(json_str)
      self.from_serializable_hash( JSON.parse! json_str )
    end

  end

  def serializable_hash
    hash = {}
    self._serializable_attrs.each do |accessor|
      accessor = accessor.to_s
      value = self.instance_variable_get("@#{accessor}")

      if value.respond_to?(:to_ary)
        value = value.to_ary.collect do |item|
          item.respond_to?(:serializable_hash) ? item.serializable_hash : item
        end
      end

      hash[accessor] = value unless value.nil?

      if value.respond_to?(:html_safe?) && value.html_safe?
        hash["_#{accessor}_htmlsafe"] = true
      end
    end
    return hash
  end

  def dump_to_json
    JSON.dump self.serializable_hash
  end

end