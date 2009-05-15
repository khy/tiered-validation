class CreateAccounts < ActiveRecord::Migration  
  def self.up  
    create_table :accounts do |t|
      t.float :balance
      t.string :number
      t.date :expiration_date
      t.boolean :preferred
      
      t.timestamps
    end  
  end  
  
  def self.down  
    drop_table :accounts
  end  
end