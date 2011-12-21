# include this module into any model whose field values we want to track
module ModelFieldTracking
  
  module FieldTracker
  
    # Constants
    # field to be ignored by field tracker 
    IGNORE_FIELDS = ['id', 'updated_at', 'created_at', 'health']
    # default confidence for any change unless source specfies otherwise
    DEFAULT_CONFIDENCE = 100
  
    def self.included(base)
    
      # Add class level code
      base.instance_eval do
      
        def self.definitions
          @definitions ||= []
          @definitions
        end
      
        def self.define_field(column)
          field_def = FieldDefinition.new
          # add column to field def 
          field_def.field_name = column.to_s
          yield field_def if block_given?
          # save field def to field definitions registry
          definitions << field_def
        end
     
        def self.tracked?
          true
        end
 
      end # instance_eval
    
      # Add instance level code
      base.class_eval do
      
        # Relations
        has_many :field_changes, :order => 'changed_at DESC', :as => 'model', :dependent => :destroy
      
        # CallBacks
        before_save :update_health
        after_save :save_change

        # add attributes to model so they can blend in with native columns
        # ex: model.update_attributes(:city=>'nyc', :source => @admin_user)
        # the data has been sourced if applicable
        attr_accessor :source
      
        # return all FieldChanges on a column 
        def changes_for(column)
          unless self.new_record?
            FieldChange.for_model_and_field(self,column.to_s).latest
          else
            []
          end
        end
     
        # considering that we will audit STI classes
        def class_name
          self[:type] || self.class.to_s
        end

        # gets field def for a column
        def field_def_for(column)
          self.class.definitions.find{|fd| fd.field_name == column.to_s}
        end
      
        # returns an array of all fields under tracking
        def field_def_names
          self.class.definitions.collect{|f| f.field_name}
        end
      
        # returns lates field_change entry for a column 
        def latest_change_for(column)
          unless self.new_record?
            changes_for(column)[0] rescue nil
          else
            nil
          end
        end
      
        # calculates field freshness percentage for a column 
        # field freshness is measure of how recent a field
        # has been edited based on its defined max age 
        def freshness_for(column)
          # a short circuit to return 0 if no val
          value = self[column]
          return 0 if value.blank? unless value.is_a?(FalseClass)
          field_def = field_def_for(column)
          last_change = latest_change_for(column)
          # short circuit if there are no changes
          return 0 if last_change.nil?
          changed_time = last_change.changed_at
          # difference in days(float)
          days = (Time.now - changed_time) / (60 * 60 *24)
          freshness_percentage = 100 - ((days/field_def.max_age) * 100)
          freshness_percentage = 0 if freshness_percentage < 0 
          freshness_percentage.to_i
        end
        
        # facade for getting confidence value from source model
        def source_confidence(src)
          src.confidence rescue DEFAULT_CONFIDENCE
        end
        
        # field confidence is an evaluation 
        # of a field's value based on its source/
        # who edited it
        def confidence_for(column)
          last_change = latest_change_for(column)
          return 0 if last_change.nil? 
          src = last_change.source
          conf = source_confidence(src)
          conf = 0 if conf.nil?
          conf
        end
      
        # field health is a consideration
        # of both a field's freshness & confidence
        # or short circuit to 0 val for high weight/
        # low freshness
        def health_for(column)
          f = freshness_for(column) 
          c = confidence_for(column)
          w = field_def_for(column).weight rescue 0
          # short circuit for stale, high weight fields
          return 0 if (f <= 10 && w >= 80) 
          (f + c) / 2
        end
      
        # calculates the overall freshness of this object
        # object freshness is the average of all field freshnesses
        def freshness
          ratings = self.class.definitions.collect{|f| freshness_for(f.field_name)}
          sum = ratings.reduce(:+) 
          # average freshness of all fields
          sum / (ratings.size)
        end
      
        # calcs overall importance/weight of this model object 
        # object importance is the average of all field weights
        # as defined in their field defs
        def importance
          weights = self.class.definitions.collect{|f| f.weight }
          sum = weights.reduce(:+)
          sum / (weights.size)
        end
      
        # confidence in the data source of this object 
        # average of all field confidences
        def confidence
          confidences = self.class.definitions.collect{|f| confidence_for(f.field_name) }
          sum = confidences.reduce(:+)
          sum / (confidences.size)
        end
      
        # determines the overall health of this object
        # low value means this model needs attention 
        def overall_health
         (confidence * freshness) / importance
        end 
      
        # health of this object 
        def health
          (self[:health].blank? || self[:health] == 0) ? overall_health : self[:health]
        end 
      
        # keep the current value of the given attribute
        # and create a new FieldChange entry accordingly
        def confirm_field(column, src=nil)
          field = column.to_s
          val = self.send(field)
          FieldChange.create( :field_name => field, :new_value => val, 
                              :changed_at => Time.now, :model => self, 
                              :source => src, :confidence => source_confidence(src)) 
        end
      
        # confirms all fields of an object
        def confirm_all_fields(src=nil)
          self.field_def_names.each do |field_name|
            self.confirm_field(field_name,src)
          end
        end
      
        # for after save 
        def update_health
          self[:health] = overall_health
        end

        def update_health_and_save
          update_health
          save(false)
        end
      
        # validates a single attribute and adas it to object errors obj
        def valid_attribute?(attribute)
          # trigger validation to create errors
          self.valid?
          if self.errors.include?(attribute)
            # collect the error mesasage
            error_msg = self.errors[attribute]
            self.errors.clear
            # add the message to the fresh errors object
            self.errors.add(attribute,error_msg)
            false
          else
            # clear out other errors as we dont care right now
            self.errors.clear
            true
          end
        end
      
        # updates a single attribute, performs validations
        def update_single_attribute(attribute,new_value,source=nil)
          self.source = source
          self.send("#{attribute}=",new_value)
          updated = self.valid_attribute?(attribute)
          updated = self.save(:validate => false) if updated
          updated
        end
      
        private
      
        # for after save to store new FieldChange records 
        def save_change
          changeset = self.changes.delete_if{|k,v| IGNORE_FIELDS.include? k.to_s }
          # save an entry for each change
          changeset.each do |field, vals|
            FieldChange.create( :field_name => field, :new_value => vals[1], :changed_at => self.updated_at, :model => self, 
                                :source => self.source, :confidence => source_confidence(self.source)) if field_def_names.include?(field)
          end
        end
      
      end # class_eval
    end
  end  
  
  # module included into models authroized to change values(admin_user,member,etc)
  module SourceConfidence
    def self.included(base)
      base.class_eval do
        # overrite this with a value that is appropriate
        def confidence
          100
        end
      end
    end
  end
  
end

