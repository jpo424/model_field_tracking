class FieldDefinition
  
  # priority should be in range 0-10
  attr_accessor :field_name, :weight, :max_age

  # init defaults for attributes
  def initialize
    @weight = 80
    @max_age = 365
  end

  # sets field weight
  def weight=(w)
    raise "Weight:#{w}, not in range(1..100)" unless (1..100).include?(w)
    @weight = w
  end

end
