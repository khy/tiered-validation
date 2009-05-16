require 'tiered_validation/validation_tier'
require 'tiered_validation/callback_chain_extensions'
require 'tiered_validation/record_invalid_for_tier'

module TieredValidation    
  def self.included(base) #:nodoc:
    base.extend(ClassMethods)
  end

  VALIDATION_TIERS = {}

  module ClassMethods
    # Defines a validation tier (i.e. a group of validations to be run as a unit)
    # with the specified name, based upon those called in the supplied block.
    #
    # ==== Examples
    #
    #   class Post < ActiveRecord::Base
    #     validates_presence_of :title, :content
    #
    #     validation_tier :user do
    #       validates_acceptance_of :terms_of_service
    #     end
    #
    #     validation_tier :guest, :includes => :user do
    #       validates_presence_of :email
    #     end
    #   end
    #
    #   >> post = Post.new(:title => "My Vacation", :content => "I went to Ireland...", :email => "khy@jah.com")
    #   => #<Post id: nil, title: "My Vacation", content: "I went to Ireland...", email: "khy@jah.com", created_at: nil, updated_at: nil>
    #   >> post.valid?
    #   => true
    #   >> post.valid_for_user?
    #   => false
    #   >> post.valid_for_guest?
    #   => false
    #
    # ==== Options
    #
    # * <tt>:exclusive</tt>
    #       When <tt>true</tt>, the validations included in the block will only
    #       be used by the validation tier. When <tt>false</tt>, the validations
    #       will be used by both the validation tier and the default, underlying
    #       validation. Defaults to <tt>true</tt>.
    # * <tt>:includes</tt>
    #       Specifies the name or names of the tiers that the tier should include. Along
    #       with the validations included in the supplied block, a tier will run all
    #       of the validations for any tiers specified in this option.
    #
    # ==== Added Convenience Methods
    #
    # * <tt>.create_with_[tier]_validation!</tt>
    #       Like <tt>#create!</tt>, except uses <tt>tier</tt>'s validation.
    # * <tt>#save_with_[tier]_validation</tt>
    #       Like <tt>#save</tt>, except uses <tt>tier</tt>'s validations.
    # * <tt>#save_with_[tier]_validation!</tt>
    #       Like <tt>#save!</tt>, except uses <tt>tier</tt>'s validations.
    # * <tt>#valid_for_[tier]?</tt>
    #       <tt>true</tt> if validations for <tt>tier</tt> pass; <tt>false</tt> otherwise.
    # * <tt>#invalid_for_[tier]?</tt>
    #       <tt>false</tt> if validations for <tt>tier</tt> pass; <tt>true</tt> otherwise.
    def validation_tier(name, options = {}, &block)
      options = {:includes => [], :exclusive => true}.merge(options)
      tier = ValidationTier.new(name, self, options[:includes], options[:exclusive])
      VALIDATION_TIERS[name] = tier

      tier.setup_alias_methods
      class_eval &block
      tier.teardown_alias_methods
      
      tier.add_convenience_methods
    end
    
    # Identical to <tt>.create!</tt>, except uses <tt>tier</tt>'s validation
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

  # Returns <tt>true</tt> if the record is valid for <tt>tier</tt>
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
  
  # Identical to <tt>#save</tt>, except uses <tt>tier</tt>'s validation
  def save_with_tier_validation(tier)
    if valid_for_tier?(tier) and valid?
      save
    else
      false
    end
  end
  
  # Identical to <tt>#save!</tt>, except uses <tt>tier</tt>'s validation.
  # Also, if the tier validation fails, a <tt>RecordInvalidForTier</tt> error is thrown,
  # while if the standard validation fails, the normal <tt>RecordInvalid</tt> is thrown.
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
