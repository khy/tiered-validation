require File.dirname(__FILE__) + '/spec_helper'

class Login < ActiveRecord::Base
  belongs_to :account
  validates_presence_of :username
end

class Account < ActiveRecord::Base
  has_one :login
  
  attr_accessor :eula, :number_confirmation
  
  validation_tier :admin do
    validates_acceptance_of :eula, :accept => true
    validates_associated :login
    validates_confirmation_of :number
    validates_each :number do |record, attr, value|
      record.errors.add attr, 'is all ones.' if value == '111111'
    end
    validates_exclusion_of :number, :in => %w(123581)
    validates_format_of :number, :with => /^1\d{3}/
    validates_inclusion_of :balance, :in => 0..100
    validates_length_of :number, :is => 6
    validates_numericality_of :number
    validates_presence_of :balance
    validates_uniqueness_of :number
  end
  
  validation_tier :user do
    validates_presence_of :expiration_date
  end
  
  validation_tier :monkey, :exclusive => false do
    validates_format_of :number, :with => /^1\d/, :allow_nil => true
  end
  
  validation_tier :cowboy, :includes => :user do
    validates_each :preferred do |record, attr, value|
      record.errors.add attr, 'is false.' unless value
    end
  end
  
  validation_tier :pirate do
    validates_format_of :number, :with => /^123/
    validates_format_of :number, :with => /^1234/, :on => :create
    validates_format_of :number, :with => /^1235/, :on => :update
  end
  
  def after_initialize
    build_login
  end
end

describe 'Validation tier convenience methods' do
  describe '.create_with_[tier]_validation' do
    it 'should create an instance using the specified tier validation' do
      Account.create_with_user_validation!(:expiration_date => Time.now).should be_a_kind_of(Account)
    end
  
    it 'should raise a RecordInvalidForTier error if tier validation fails' do
      lambda{Account.create_with_user_validation!}.should raise_error(ActiveRecord::RecordInvalidForTier)
    end
  end

  describe '#save_with_[tier]_validation' do
    it 'should return true if instance is saved with tier validation' do
      Account.new(:expiration_date => Time.now).save_with_user_validation.should be_true
    end
  
    it 'should return false if tier validation fails' do
      Account.new.save_with_user_validation.should be_false
    end
  end
  
  describe '#save_with_[tier]_validation!' do
    it 'should return true if instance is saved with tier validation' do
      Account.new(:expiration_date => Time.now).save_with_user_validation!.should be_true
    end
  
    it 'should raise a RecordInvalidForTier error if tier validation fails' do
      lambda{Account.new.save_with_user_validation!}.should raise_error(ActiveRecord::RecordInvalidForTier)
    end
  end
  
  describe '#valid_for_[tier]?' do
    it 'should return false if tier validation fails' do
      Account.new(:expiration_date => Time.now).valid_for_user?.should be_true
    end
  
    it 'should return false if tier validation fails' do
      Account.new.valid_for_user?.should be_false
    end
  end
  
  describe '#invalid_for_[tier]?' do
    it 'should return false if tier validation passes' do
      Account.new(:expiration_date => Time.now).invalid_for_user?.should be_false
    end
  
    it 'should return true if tier validation fails' do
      Account.new.invalid_for_user?.should be_true
    end
  end
end

describe 'Exclusive validation tier' do
  it 'should not share validations with the standard validation chain' do
    account = Account.new
    account.should_not be_valid_for_user
    account.should be_valid
  end
end

describe 'Non-exclusive validation tier' do
  it 'should share validations with the standard validation chain' do
    account = Account.new(:number => 'AAAAAA')
    account.should_not be_valid_for_monkey
    account.should_not be_valid
  end
end

describe 'Validation tier with included tier' do
  it 'should use included tier validations' do
    account = Account.new(:preferred => true)
    account.should_not be_valid_for_cowboy
  end
end

describe 'Validation tier' do
  it 'should use on create option' do
    account = Account.new(:number => '1238')
    account.should_not be_valid_for_pirate
    account.number = '1235'
    account.should_not be_valid_for_pirate
    account.number = '1234'
    account.should be_valid_for_pirate
  end

  it 'should use on update option' do
    account = Account.new(:number => '1234')
    account.save
    account.should_not be_valid_for_pirate
  end
  
  it 'should include any default validations' do
    account = Account.new(:number => '1ab', :expiration_date => 2.days.from_now)
    account.should_not be_valid_for_user
  end
end

describe 'Validation tier' do
  def build_account
    account = Account.new(:balance => 50, :eula => true, :number => '123456',
      :number_confirmation => '123456')
    account.login.username = 'jah123'
    account
  end

  before(:all) do
    Account.delete_all
  end

  before(:each) do
    @account = build_account
    @account.should be_valid_for_admin
  end

  it 'should appropriately apply validates_acceptance_of' do
    @account.eula = false
    @account.should_not be_valid_for_admin
    @account.errors.on(:eula).should_not be_nil
  end

  it 'should appropriately apply validates_associated' do
    @account.login.username = nil
    @account.should_not be_valid_for_admin
    @account.errors.on(:login).should_not be_nil
  end

  it 'should appropriately apply validates_confirmation_of' do
    @account.number_confirmation = '135791'
    @account.should_not be_valid_for_admin
    @account.errors.on(:number).should_not be_nil
  end

  it 'should appropriately apply validates_each' do
    @account.number = '111111'
    @account.number_confirmation = '111111'
    @account.should_not be_valid_for_admin
    @account.errors.on(:number).should_not be_nil
  end

  it 'should appropriately apply validates_exclusion_of' do
    @account.number = '123581'
    @account.number_confirmation = '123581'
    @account.should_not be_valid_for_admin
    @account.errors.on(:number).should_not be_nil
  end

  it 'should appropriately apply validates_format_of' do
    @account.number = '234567'
    @account.number_confirmation = '234567'
    @account.should_not be_valid_for_admin
    @account.errors.on(:number).should_not be_nil
  end

  it 'should appropriately apply validates_inclusion_of' do
    @account.balance = -5
    @account.should_not be_valid_for_admin
    @account.errors.on(:balance).should_not be_nil
  end

  it 'should appropriately apply validates_length_of' do
    @account.number = '1234567'
    @account.number_confirmation = '1234567'
    @account.should_not be_valid_for_admin
    @account.errors.on(:number).should_not be_nil
  end

  it 'should appropriately apply validates_numericality_of' do
    @account.number = '123ABC'
    @account.number_confirmation = '123ABC'
    @account.should_not be_valid_for_admin
    @account.errors.on(:number).should_not be_nil
  end

  it 'should appropriately apply validates_presence_of' do
    @account.balance = nil
    @account.should_not be_valid_for_admin
    @account.errors.on(:balance).should_not be_nil
  end

  it 'should appropriately apply validates_presence_of' do
    @account.save
    new_account = build_account
    new_account.should_not be_valid_for_admin
    new_account.errors.on(:number).should_not be_nil
  end
end
