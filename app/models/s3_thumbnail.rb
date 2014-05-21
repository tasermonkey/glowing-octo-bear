class S3Thumbnail
  # the underlining s3object for this S3Image
  attr_reader :s3obj

  # Decides if this object has changes that needs to be saved to S3.
  attr_accessor :dirty

  # creates a new S3Image object from a S3Object or a hash with :s3obj set on it
  def initialize(options = {})
    @org_date_time = nil
    @img_exif = nil
    @org_date_time = nil
    self.dirty = false
    if options.instance_of? Hash
      @s3obj = options[:s3obj] || nil
      self.dirty = options[:dirty]
    elsif options.instance_of? AWS::S3::S3Object
      @s3obj = options
    else
      raise ArgumentError.new 'S3Image requires to be created with a S3Object'
    end
  end

  # Get the S3 Key for this S3Object.
  def key
    @s3obj.key
  end

  # Get the S3 Key for this S3Object.
  def original_key
    @s3obj.metadata[:original_key]
  end

  def original_key=(value)
    self.dirty = true
    @s3obj.metadata[:original_key] = value
  end

  def original_guid
    @s3obj.metadata[:original_guid]
  end

  def original_guid=(value)
    self.dirty = true
    @s3obj.metadata[:original_guid] = value
  end

  def original_etag
    @s3obj.metadata[:original_etag]
  end

  def original_etag=(value)
    self.dirty = true
    @s3obj.metadata[:original_etag] = value
  end

  # Gets the width as defined by the metadata stored in S3
  def width
    @s3obj.metadata[:imgwidth]
  end

  # Set the metadata for width for the image.
  def width=(new_width)
    self.dirty = true
    @s3obj.metadata[:imgwidth] = new_width
  end

  # Gets the height as defined by the metadata stored in S3
  def height
    @s3obj.metadata[:imgheight]
  end

  # Set the metadata for height for the image.
  def height=(new_height)
    self.dirty = true
    @s3obj.metadata[:imgheight] = new_height
  end

  def url
    @s3obj.url
  end

  def etag
    @s3obj.about[:etag]
  end

  # Retrieves the raw data from S3 if needed, otherwise just returned the cached version
  # @return +S3Object::Value+
  def bytes
    @s3obj.value
  end

  # Sets the raw data to be saved to S3 when +save!+ is called.
  def bytes=(new_value)
    self.dirty = true
    @s3obj.value = new_value
  end

  # Retrieves the image from S3(if needed, as this is cached), then use RMagick to parse the image into an
  # +Image+
  # @return +Image+ of the S3Object
  def magick_image
    Image.from_blob(self.bytes)[0]
  end

  def dirty?
    self.dirty
  end

  # Saves any changes to the connected S3 file if this object is dirty.  To force a save, you will also have to set dirty to true.
  # @note If the image hasn't been downloaded yet, this will force a download, then a re-upload due to the nature of how S3 works.
  # @return undetermined
  def save!
    result = @s3obj.store
    self.dirty = false
    result
  end
end