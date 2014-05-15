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
      page = AWS::S3::Bucket.objects(@gallery_bucket, :marker => @last_recv, :max_keys => 20)
      puts "New page dog, of #{page.size} items!"
      until page.empty?
        page.each do |i|
          puts "New Item!!! "
          g.yield i
        end
        puts 'Acquiring next page!'
        page = AWS::S3::Bucket.objects(@gallery_bucket, :marker => page[-1].key, :max_keys => 20)
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

  def wrap_s3obj_with_api_meta
    lambda { |s3obj| {:s3obj => s3obj, :dirty => false } }
  end

  def wrap_filter_image_content_type
    lambda {|s3obj|
      s3obj = s3obj[:s3obj] if s3obj.instance_of? Hash
      s3obj.content_type.start_with?('image/')
    }
  end

  def wrap_add_image_size
    lambda { |s3objwithmeta|
      raise 'Expected wrap_s3obj_with_api_meta to be called before this' if s3objwithmeta.instance_of? AWS::S3::S3Object
      s3obj = s3objwithmeta[:s3obj]
      return s3objwithmeta unless s3obj.metadata[:exif].nil? or s3obj.metadata[:imgwidth].nil? or s3obj.metadata[:imgheight].nil?
      picdata = Image.from_blob(s3obj.value)[0]
      exif = Hash[picdata.get_exif_by_entry.group_by { |i| i[0]}.map { |k, v| [k, v.map {|x| x[1]}] }]
      s3obj.metadata[:exif] = JSON.generate(exif)
      if s3obj.metadata[:exif].size > 2048
        exif = Hash[exif.map { |k,v| [k, v.map {|x| x.slice(0, 128)}]}]
        s3obj.metadata[:exif] = JSON.generate(exif)
      end
      if s3obj.metadata[:exif].size > 2048
        exif = exif.select {|k,v| %w(DateTimeDigitized DateTime XResolution YResolution ApertureValue ShutterSpeedValue FocalLength ImageUniqueID Model MaxApertureValue).include? v}
        s3obj.metadata[:exif] = JSON.generate(exif)
      end
      if s3obj.metadata[:exif].size > 2048
        puts "To large of a exif information(>2048): #{s3obj.metadata[:exif]}"
        s3obj.metadata[:exif] = '{"error": "Unable to extract exif due to size of embedded exif"}'
      end
      s3obj.metadata[:imgwidth] = picdata.columns
      s3obj.metadata[:imgheight] = picdata.rows
      s3objwithmeta[:dirty] = true
      s3objwithmeta
    }
  end

  def wrap_store_if_dirty

    lambda { |s3objwithmeta|
      raise 'Expected wrap_s3obj_with_api_meta to be called before this' if s3objwithmeta.instance_of? AWS::S3::S3Object
      s3obj = s3objwithmeta[:s3obj]
      return s3objwithmeta unless s3objwithmeta[:dirty]
      s3obj.store
      s3objwithmeta[:dirty] = false
      s3objwithmeta
    }
  end

end