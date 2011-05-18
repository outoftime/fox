require './fox'

class User
  include Fox::Document

  string :name
  list :favorite_snacks
  integer :awesome_points
end

def user
  @user ||= User[4]
end
