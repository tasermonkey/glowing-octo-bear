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
      raise 'Expected s3obj_to_s3_image to be called before this' unless s3img.instance_of? S3Image
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
    np = p.find_all(&@gap.wrap_filter_image_content_type)
    pipeline = np.map(&@gap.s3obj_to_s3_image)
                 .map(&@gap.wrap_add_guid)
                 .map(&@gap.wrap_add_image_size)
                 .map(&self.wrap_insert_into_db)
                 .map(&@gap.wrap_store_if_dirty)
    counter = 0
    start_time = DateTime.now
    seconds_in_day = 1.days.seconds
    pipeline.each { |s3img|
      counter+=1
      if counter % 100 == 0
        puts "Ingested #{counter} items (#{((DateTime.now - start_time) * seconds_in_day) / counter} seconds/item"
      end
    }
    puts "Completed ingesting #{counter} items in #{ActionView::Helpers::DateHelper.distance_of_time_in_words_to_now(start_time)}"
  end
end