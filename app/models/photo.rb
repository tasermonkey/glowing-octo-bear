class Photo < ActiveRecord::Base
  def thumbnail
    bucket = Rails.application.config.app["gallery.s3bucket"]
    thumbnail_dir = Rails.application.config.app["gallery.thumbnails.dir"]
    thumbnail_size = Rails.application.config.app["gallery.thumbnails.size"]
    AWS::S3::S3Object.url_for "#{thumbnail_dir}/#{thumbnail_size}/#{guid}.jpg", bucket
  end
  def url
    AWS::S3::S3Object.url_for s3key, Rails.application.config.app["gallery.s3bucket"]
  end
end
