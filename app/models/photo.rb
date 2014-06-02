class Photo < ActiveRecord::Base
  has_many :album_items
  has_many :albums, through: :album_items

  def thumbnail
    bucket = Rails.application.config.app["gallery.s3bucket"]
    thumbnail_dir = Rails.application.config.app["gallery.thumbnails.dir"]
    thumbnail_size = Rails.application.config.app["gallery.thumbnails.size"]
    AWS::S3::S3Object.url_for "#{thumbnail_dir}/#{thumbnail_size}/#{guid}.jpg", bucket, authenticated: false
  end

  def webView
    bucket = Rails.application.config.app["gallery.s3bucket"]
    thumbnail_dir = Rails.application.config.app["gallery.webview.dir"]
    thumbnail_size = Rails.application.config.app["gallery.webview.size"]
    AWS::S3::S3Object.url_for "#{thumbnail_dir}/#{thumbnail_size}/#{guid}.jpg", bucket, authenticated: false
  end

  def url
    AWS::S3::S3Object.url_for s3key, Rails.application.config.app["gallery.s3bucket"], authenticated: false
  end
end
