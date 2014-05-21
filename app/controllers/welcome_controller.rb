class WelcomeController < ApplicationController
  def index
    @photos = Photo.all.take(25)
  end
end
