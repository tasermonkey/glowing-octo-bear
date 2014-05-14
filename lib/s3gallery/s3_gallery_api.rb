require 'aws/s3'

class S3GalleryApi
  def initialize(options = {:gallery_bucket => 'storage.photos.spstapleton.com'})
    @gallery_bucket = 'storage.photos.spstapleton.com'

    @thumbnail_size = options[:thumbnail_size] || {:width => 320, :height => 240}
    @thumbnail_dir = options[:thumbnail_dir] || '/tmp/s3gallery/thumbs'

    @last_recv = nil
  end

  def get_next_page
    raise 'No more items to page through' if @last_recv.is_a?(Symbol) and @last_recv == :end
    page = AWS::S3::Bucket.objects(@gallery_bucket, :marker => @last_recv, :max_keys => 1000)
    @last_recv = page.size > 0 ?  page[-1].key : :end
    page
  end

  def reset
    @last_recv = nil
  end


end