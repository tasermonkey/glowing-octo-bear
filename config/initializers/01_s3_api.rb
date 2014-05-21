AWS::S3::Base.establish_connection!(
    :access_key_id     => Rails.application.secrets.aws_access_key_id,
    :secret_access_key => Rails.application.secrets.aws_secret_key
)