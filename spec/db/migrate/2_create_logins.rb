class CreateLogins < ActiveRecord::Migration  
  def self.up  
    create_table :logins do |t|
      t.belongs_to :account
      t.string :username
      t.string :password_hash
      
      t.timestamps
    end  
  end  
  
  def self.down  
    drop_table :logins
  end  
end