class Photo
  include Mongoid::Document
  include Mongoid::Timestamps::Updated 

  field :file
  field :title, :type => String
  field :date, :type => Date
  
end
