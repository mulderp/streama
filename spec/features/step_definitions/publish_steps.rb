When /^Sylvie made a photo$/ do
  @sylvie = User.create(:full_name => "Sylvie")
  @photo = Photo.create(:title => "My cat", :date => Date.today)
end

When /^she publishes the photo to Patrick$/ do
  @patrick = User.create(:full_name => "Patrick")
  @activity = Activity.publish(:new_photo, {:actor => @sylvie, :object => @photo, :object_target => @album})
end

Then /^Patrick sees the photo in the ActivityStream$/ do
#  @patrick.activity_stream.to_a.first.object.should == @photo
  @patrick.activity_stream.to_a.first.object["type"].should == "Photo"
end
