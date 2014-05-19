require 'aws/s3'
require 'rmagick'
include Magick

# This Class manages an Image on the S3 'File Store'.
# Whenever you make a change to this class, you will need to call +save!+ if you want the changes to persist.
# The actual image isn't downloaded unless its required.  Storing any changes to this object requires downloading
# the actual image first.
class S3Image
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

  # Get the S3Object guid for this image as set in its metadata
  # If a guid hasn't been set on this object before, it will create a new guid and set the dirty flag
  def guid!
    guid = self.guid
    if guid.nil?
      guid = create_new_guid
    end
    guid
  end

  # Get the S3Object guid for this image as set in its metadata
  # If a guid hasn't been set on this object before, it will be nil
  def guid
    @s3obj.metadata[:guid]
  end

  # Assign a new guid for this S3Object.
  def guid=(new_guid)
    self.dirty = true
    @s3obj.metadata[:guid] = new_guid
  end

  # Generates a new GUID for this S3Object, and returns it
  def create_new_guid
    self.guid = SecureRandom.uuid
  end

  # Gets the filename, the last portion of the S3 Key for this S3Object.  This will include the extension
  # returns for example: IMG_0001.jpg
  def filename
    File.basename(self.key)
  end

  # gets the metadata as stored in s3
  def s3metadata
    @s3obj.metadata
  end

  # Gets the content_type as stored in S3
  def content_type
    @s3obj.content_type
  end

  # Returns the exif information as stored in S3
  def exif
    return @img_exif unless @img_exif.nil?
    return nil if @s3obj.metadata[:exif].nil?
    @img_exif = JSON.parse(@s3obj.metadata[:exif])
  end

  # Attempts to store the exif information as metadata on this S3Object.  If the exif information is too large (>2048)
  # it will first attempt to shorten each field to 128 characters.  Then if that still don't work, select only a small
  # subset of fields from the exif information.  Then if it still some how too large (>2048), it will throw an ArgumentError.
  # After that it stores it in the S3Object metadata as a JSON encoded object.
  # @return exif information as will be store in S3
  def exif=(new_exif)
    if new_exif.instance_of? String
      str_exif = new_exif
      new_exif = JSON.parse(str_exif)
    else
      str_exif = JSON.generate(new_exif)
    end

    if str_exif.size > 2048
      new_exif = Hash[new_exif.map { |k,v| [k, v.map {|x| x.slice(0, 128)}]}]
      str_exif = JSON.generate(exif)
    end
    if str_exif.size > 2048
      new_exif = new_exif.select {|k,v| %w(DateTimeDigitized DateTime XResolution YResolution ApertureValue ShutterSpeedValue FocalLength ImageUniqueID Model MaxApertureValue).include? v}
      str_exif = JSON.generate(exif)
    end
    raise ArgumentError.new "Tried to set to large of a exif information(>2048) on #{self.key}" if str_exif.size > 2048
    # only reset this, and set our dirty bit, if its actually different
    return self.exif if self.exif == new_exif
    self.dirty = true
    @s3obj.metadata[:exif] = str_exif
    @img_exif = new_exif
  end

  # Downloads if needed the Image from S3, then extracts the exif information and assigns it to the metadata stored in
  # this object.
  # @return the exif information as stored in this object.
  def generate_exif_from_s3img
    the_image = self.magick_image
    self.exif = Hash[the_image.get_exif_by_entry.group_by { |i| i[0]}.map { |k, v| [k, v.map {|x| x[1]}] }]
  end

  # Gets the DateTimeOriginal field from the Image's exif information.  If the field is not set, or unparsable will
  # return DateTime.now
  def original_date_time
    return @org_date_time unless @org_date_time.nil?
    begin
      @org_date_time = DateTime.strptime(self.exif["DateTimeOriginal"].first,  '%Y:%m:%d %H:%M:%S')
    rescue ArgumentError
      begin
        unless self.exif["DateTimeOriginal"].nil?
          puts "WARNING: invalid date detected for #{s3obj.key}: #{exif["DateTimeOriginal"].first}"
        end
        @org_date_time  = DateTime.parse(s3obj.about["last-modified"])
      rescue ArgumentError
        @org_date_time = DateTime.now
      end
    end
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