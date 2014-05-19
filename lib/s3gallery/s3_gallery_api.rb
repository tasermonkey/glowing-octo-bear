require 'aws/s3'

class S3GalleryApi
  def initialize(options = {})
    @gallery_bucket = options[:gallery_bucket] || 'storage.photos.spstapleton.com'
    @gallery_dir = options[:gallery_dir] || 'galleries'
    @gallery_dir.slice! 0 if @gallery_dir.start_with? '/'
    @thumbnail_size = options[:thumbnail_size] || [{width: 256, height: 256, style: :resize_to_fill}, {width: 800, height: 600, style: :resize_to_fit}]
    @thumbnail_dir = options[:thumbnail_dir] || 'thumbnails'

    @last_recv = nil
  end

  def enumerate_bucket
    tmp = Enumerator.new do |g|
      puts "Entering in enumerator"
      page = AWS::S3::Bucket.objects(@gallery_bucket, :prefix => @gallery_dir, :marker => @last_recv, :max_keys => 1000)
      puts "New page dog, of #{page.size} items!"
      counter = 0
      until page.empty?
        page.each do |i|
          counter+=1
          puts "#{counter}: New Item!!!"
          g.yield i
        end
        puts 'Acquiring next page!'
        page = AWS::S3::Bucket.objects(@gallery_bucket, :prefix => @gallery_dir, :marker => page[-1].key, :max_keys => 1000)
      end
    end
    tmp.lazy
  end

  #####
  ## The following function family (wrap_*) is designed to be used in a function composition manner to be applied
  ## to each item returned by enumerate_bucket.  The first function wrap_s3obj_with_api_meta should be the inner most
  ## function (called first), whereas the wrap_store_if_dirty should be the outer most function(called last).
  ##
  ## Example:
  ##    api.enumerate_bucket().map(&api.s3obj_to_s3_image)
  ##                          .filter(&api.wrap_filter_image_content_type)
  ##                          .map(&api.wrap_add_guid)
  ##                          .map(&api.wrap_add_image_size)
  ##                          .map(&api.wrap_store_if_dirty)
  #####

  def s3obj_to_s3_image
    lambda { |s3obj| S3Image.new s3obj }
  end

  def wrap_filter_image_content_type
    lambda {|s3obj|
      # this works for both S3Image and S3Object
      s3obj.content_type.start_with?('image/')
    }
  end

  def wrap_add_guid
    lambda { |s3img|
      raise 'Expected s3obj_to_s3_image to be called before this' unless s3img.instance_of? S3Image
      s3img.guid!  # this will create a guid if it does not currently exist
      s3img
    }
  end

  def wrap_add_image_size
    lambda { |s3img|
      raise 'Expected s3obj_to_s3_image to be called before this' unless s3img.instance_of? S3Image
      return s3img unless s3img.exif.nil? or s3img.width.nil? or s3img.height.nil?
      picdata = s3img.magick_image
      if s3img.exif.nil?
        s3img.generate_exif_from_s3img
      end

      s3img.width = picdata.columns
      s3img.height = picdata.rows
      s3img
    }
  end

  def safe_s3_get(thumbnail_filename)
    begin
      AWS::S3::S3Object.find thumbnail_filename, @gallery_bucket
    rescue
      nil
    end
  end

  def safe_s3_exists?(thumbnail_filename)
    begin
      AWS::S3::S3Object.exists? thumbnail_filename, @gallery_bucket
    rescue
      false
    end
  end

  def create_thumbnail(picdata, tn)
    begin
      thumbnail_image = nil
      if tn[:style] == :resize_to_fill
        thumbnail_image = picdata.resize_to_fill tn[:width], tn[:height]
      else
        thumbnail_image = picdata.resize_to_fill tn[:width], tn[:height]
      end
      thumbnail_image
    rescue Exception => e
      puts "ERROR: #{e.message}"
      nil
    end
  end

  def wrap_generate_thumbnail
    lambda { |s3img|
      raise 'Expected s3obj_to_s3_image to be called before this' unless s3img.instance_of? S3Image
      picdata = s3img.magick_image

      original_etag = s3img.etag
      original_guid = s3img.guid
      original_key = s3img.key

      @thumbnail_size.each { |tn|
        thumbnail_filename = "#{@thumbnail_dir}/#{tn[:width]}x#{tn[:height]}/#{s3img.guid}.jpg"
        next unless safe_s3_exists? thumbnail_filename  # Already generated
        thumbnail_image = create_thumbnail picdata, tn
        next if thumbnail_image.nil?
        # first do an empty store due to the fact that we will have to "download" it again in order to change the
        # metadata.
        response = S3Object.store thumbnail_filename, '', @gallery_bucket
        if response.error?
          puts "Error creating thumbnail: #{response.error}"
          next
        end
        next unless response.success?
        thumbnail_s3obj = safe_s3_get thumbnail_filename
        if thumbnail_s3obj.nil?
          puts "Error creating thumbnail: couldn't find object after touching"
          next
        end
        thumbnail_s3img = S3Thumbnail.new thumbnail_s3obj
        thumbnail_s3img.original_etag = original_etag
        thumbnail_s3img.original_guid = original_guid
        thumbnail_s3img.original_key = original_key
        thumbnail_s3img.width = thumbnail_image.columns
        thumbnail_s3img.height = thumbnail_image.rows
        thumbnail_s3img.bytes = thumbnail_image.to_blob
        thumbnail_s3img.save!
      }
      s3img
    }
  end


  def wrap_store_if_dirty
    lambda { |s3img|
      raise 'Expected s3obj_to_s3_image to be called before this' unless s3img.instance_of? S3Image
      return s3img unless s3img.dirty?
      s3img.save!
      s3img
    }
  end

end