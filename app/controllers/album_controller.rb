class AlbumController < ApplicationController
  before_action :authenticate_user!

  def index
    @roots = Album.roots
    if @roots.size == 1
      @album = @root[0]
      render :show
    end
  end

  def show
    @roots = Album.roots
    @album = Album.find_by id: params[:id]
  end
end
