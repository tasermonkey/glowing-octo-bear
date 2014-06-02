class PhotoController < ApplicationController
  def show
    @album_id = params[:album]
    @photo = Photo.find_by id: params[:id]
  end
end
