require 'aws/s3'
require 'rmagick'
include Magick

class S3GalleryApi
  def initialize(options = {:gallery_bucket => 'storage.photos.spstapleton.com'})
    @gallery_bucket = 'storage.photos.spstapleton.com'

    @thumbnail_size = options[:thumbnail_size] || {:width => 320, :height => 240}
    @thumbnail_dir = options[:thumbnail_dir] || '/tmp/s3gallery/thumbs'

    @last_recv = nil
  end

  def enumerate_bucket
    tmp = Enumerator.new do |g|
      puts "Entering in enumerator"
      page = AWS::S3::Bucket.objects(@gallery_bucket, :marker => @last_recv, :max_keys => 100)
      puts "New page dog, of #{page.size} items!"
      counter = 0
      until page.empty?
        page.each do |i|
          counter+=1
          puts "#{counter}: New Item!!!"
          g.yield i
        end
        puts 'Acquiring next page!'
        page = AWS::S3::Bucket.objects(@gallery_bucket, :marker => page[-1].key, :max_keys => 100)
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

  def wrap_store_if_dirty
    lambda { |s3img|
      raise 'Expected s3obj_to_s3_image to be called before this' unless s3img.instance_of? S3Image
      return s3img unless s3img.dirty?
      s3img.save!
      s3img
    }
  end

end