require 's3gallery/gallery_db_indexer'
require 's3gallery/s3_gallery_api'
# require 'ruby-progressbar'


namespace :ingest do
  task :build_thumbnails => :environment do
    gap = S3GalleryApi.new
    p = gap.enumerate_bucket.find_all(&gap.wrap_filter_image_content_type)
    pipeline = [gap.s3obj_to_s3_image,
                gap.wrap_generate_thumbnail]
    counter = 0
    # progressbar = ProgressBar.create(:starting_at => 0, :total => nil)
    p.each { |s3obj|
      s3img = s3obj
      pipeline.each { |f| s3img = f.call s3img }
      counter+=1
      # progressbar.increment
    }
    puts "Ingested  #{counter} items."
  end

end
