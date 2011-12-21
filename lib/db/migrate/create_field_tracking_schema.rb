class CreateFieldTrackingSchema < ActiveRecord::Migration
  
  def self.up
    create_table :field_changes do |t|
      t.references :model, :polymorphic => true, :null => false
      t.references :source, :polymorphic => true
      t.string :field_name, :null => false
      t.integer :confidence, :null => false
      t.text :new_value
      t.timestamp :changed_at, :null => false
    end
    
  end

  def self.down
    drop_table :field_changes
  end 
   
end
