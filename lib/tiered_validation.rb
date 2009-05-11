require 'tiered_validation/validation_tier'
require 'tiered_validation/callback_chain_extensions'
require 'tiered_validation/record_invalid_for_tier'

module TieredValidation    
  def self.included(base)
    base.extend(ClassMethods)
  end

  VALIDATION_TIERS = {}

  module ClassMethods
    def validation_tier(name, options = {}, &block)
      options = {:includes => [], :exclusive => true}.merge(options)
      tier = ValidationTier.new(name, self, options[:includes], options[:exclusive])
      VALIDATION_TIERS[name] = tier

      tier.setup_alias_methods
      class_eval &block
      tier.teardown_alias_methods
      
      tier.add_convenience_methods
    end
    
    def create_with_tier_validation!(tier, attributes = nil, &block)
      if attributes.is_a?(Array)
        attributes.collect { |attr| create_with_tier_validation!(tier, attr, &block) }
      else
        object = new(attributes)
        yield(object) if block_given?
        object.save_with_tier_validation!(tier)
        object
      end
    end
  end

  def valid_for_tier?(tier)
    tier = VALIDATION_TIERS[tier]
    errors.clear

    tier.run_callbacks(:save, self)
    validate
    
    if new_record?
      tier.run_callbacks(:create, self)
      validate_on_create
    else
      tier.run_callbacks(:update, self)
      validate_on_update
    end
    
    errors.empty?
  end
  
  def save_with_tier_validation(tier)
    if valid_for_tier?(tier) and valid?
      save
    else
      false
    end
  end
  
  def save_with_tier_validation!(tier)
    if valid_for_tier?(tier)
      if valid?
        save!
      else
        raise ActiveRecord::RecordInvalid.new(self)
      end
    else
      raise ActiveRecord::RecordInvalidForTier.new(tier, self)
    end
  end
end
