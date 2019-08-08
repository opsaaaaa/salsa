require 'aws-sdk-s3'

module FileHelper
  Aws.config[:credentials] = Aws::Credentials.new(ENV['AWS_ACCESS_KEY'], ENV['AWS_SECRET_ACCESS_KEY'])

  def self.upload_file(remote_path, local_path)
    validate_aws_env
    s3 = Aws::S3::Resource.new(region: ENV['AWS_REGION'])
    obj = s3.bucket(ENV['AWS_BUCKET']).object(remote_path)
    obj.upload_file(local_path)
  end

  def self.remote_file_exists(file_path)
    bucket_name = ENV['AWS_BUCKET']

    unless bucket_name
      return false
    end

    s3 = Aws::S3::Resource.new(region: ENV['AWS_REGION'])
    bucket =  s3.bucket(bucket_name)

    if bucket.object(file_path).exists?
      return true
    else
      return false
    end
  end

  def self.presigned_url(remote_path)
    validate_aws_env
    signer = Aws::S3::Presigner.new
    signer.presigned_url(:get_object, bucket: ENV['AWS_BUCKET'], key: remote_path, expires_in: 60)
  end

  def self.should_use_aws_s3?
    # raise "#{ENV['AWS_ACCESS_KEY']} #{ENV['AWS_SECRET_ACCESS_KEY']} #{ENV['AWS_BUCKET']} #{ENV['AWS_REGION']}"
    ( (
      ENV['AWS_ACCESS_KEY'].present? || 
      ENV['AWS_SECRET_ACCESS_KEY'].present? ) &&
      ENV['AWS_BUCKET'].present? &&
      ENV['AWS_REGION'].present? 
    )
  end

  private
  
  def self.validate_aws_env
    raise "can't use Amazon s3, AWS ENV's are missing." unless should_use_aws_s3?
  end

end
