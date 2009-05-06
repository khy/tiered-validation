require 'tiered_validation'

ActiveRecord::Base.class_eval do
  include TieredValidation
end