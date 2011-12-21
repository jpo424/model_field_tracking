class FieldChange < ActiveRecord::Base
  
  # Relations
  belongs_to :model, :polymorphic => true
  belongs_to :source, :polymorphic => true

  # Scopes
  scope :for_model_and_field, lambda {|model,field| where("field_name = '#{field}' and model_id = #{model.id} and model_type = '#{model.class_name}'")}
  scope :latest, :order => 'changed_at desc'
  
  # Validations
  validates_presence_of [:field_name, :changed_at, :confidence, :model_type, :model_id]
  
end

