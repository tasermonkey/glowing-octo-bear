require 's3gallery/s3_gallery_api'

class GalleryDbIndexer
  def initialize(options = {})
    @gap = options[:s3api] || S3GalleryApi.new(options)
  end

  def _new_photo_from_s3_image(s3img)
    Photo.new(
        :original_filename => s3img.filename,
        :name => File.basename(s3img.filename, '.*'),
        :guid => s3img.guid,
        :s3key => s3img.key,
        :date_time_original => s3img.original_date_time,
        :width => s3img.width,
        :height => s3img.height
    )
  end

  def wrap_insert_into_db
    lambda { |s3img|
      raise 'Expected wrap_s3obj_with_api_meta to be called before this' unless s3img.instance_of? S3Image
      if s3img.exif.nil?
        s3img.generate_exif_from_s3img
      end
      photo = self._new_photo_from_s3_image s3img
      begin
        photo.save
      rescue ActiveRecord::RecordNotUnique
        puts "INFO: This image already exists within the Photo database: (#{s3img.guid}): #{s3img.key}"
      end
      s3img
    }
  end

  def do_full_index
    p = @gap.enumerate_bucket
    np = p.find_all(&@gap.wrap_filter_image_content_type())
    pipeline = np.map(&gap.wrap_s3obj_with_api_meta())
                 .map(&gap.wrap_add_guid())
                 .map(&gap.wrap_add_image_size())
                 .map(&gdi.wrap_insert_into_db())
                 .map(&gap.wrap_store_if_dirty())

  end
end