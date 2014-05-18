require 'aws/s3'
require 'RMagick'
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
  ##    api.enumerate_bucket().map(&api.wrap_s3obj_with_api_meta(i))
  ##                          .filter(&api.wrap_filter_image_content_type)
  ##                          .map { |i| wrap_store_if_dirty(wrap_add_image_size(i)) }
  #####

  def s3obj_to_s3_image
    lambda { |s3obj| S3Image.new s3obj }
  end

  def wrap_filter_image_content_type
    lambda {|s3obj|
      s3obj.content_type.start_with?('image/')
    }
  end

  def wrap_add_guid
    lambda { |s3objwithmeta|
      raise 'Expected wrap_s3obj_with_api_meta to be called before this' unless s3objwithmeta.instance_of? S3Image
      s3objwithmeta.guid
      s3objwithmeta
    }
  end

  def wrap_add_image_size
    lambda { |s3objwithmeta|
      raise 'Expected wrap_s3obj_with_api_meta to be called before this' unless s3objwithmeta.instance_of? S3Image
      return s3objwithmeta unless s3objwithmeta.exif.nil? or s3objwithmeta.width.nil? or s3objwithmeta.height.nil?
      picdata = s3objwithmeta.magick_image
      if s3objwithmeta.exif.nil?
        s3objwithmeta.generate_exif_from_s3img
      end

      s3objwithmeta.width = picdata.columns
      s3objwithmeta.height = picdata.rows
      s3objwithmeta
    }
  end

  def wrap_store_if_dirty
    lambda { |s3objwithmeta|
      raise 'Expected wrap_s3obj_with_api_meta to be called before this' unless s3objwithmeta.instance_of? S3Image
      s3obj = s3objwithmeta[:s3obj]
      return s3objwithmeta unless s3objwithmeta[:dirty]
      s3obj.store
      s3objwithmeta[:dirty] = false
      s3objwithmeta
    }
  end

end