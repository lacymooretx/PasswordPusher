# frozen_string_literal: true

require "aws-sdk-s3"

module ActiveStorage
  class MultipartUploadsController < ApplicationController
    before_action :authenticate_user!, if: -> { Settings.enable_logins }
    before_action :ensure_s3_service

    def create
      blob = ActiveStorage::Blob.create_before_direct_upload!(
        filename: params[:filename],
        byte_size: params[:byte_size].to_i,
        checksum: params[:checksum],
        content_type: params[:content_type] || "application/octet-stream",
        service_name: ActiveStorage::Blob.service.name
      )

      response = s3_client.create_multipart_upload(
        bucket: bucket_name,
        key: blob.key,
        content_type: blob.content_type
      )

      render json: {
        upload_id: response.upload_id,
        key: blob.key,
        signed_id: blob.signed_id
      }
    end

    def part_url
      blob = ActiveStorage::Blob.find_by!(key: params[:key])

      presigner = Aws::S3::Presigner.new(client: s3_client_for(blob))
      url = presigner.presigned_url(
        :upload_part,
        bucket: bucket_name_for(blob),
        key: blob.key,
        upload_id: params[:upload_id],
        part_number: params[:part_number].to_i,
        expires_in: 3600
      )

      render json: {url: url}
    end

    def complete
      blob = ActiveStorage::Blob.find_by!(key: params[:key])

      s3_client_for(blob).complete_multipart_upload(
        bucket: bucket_name_for(blob),
        key: blob.key,
        upload_id: params[:upload_id],
        multipart_upload: {
          parts: params[:parts].map { |p|
            {etag: p[:etag], part_number: p[:part_number].to_i}
          }
        }
      )

      render json: {signed_id: blob.signed_id}
    end

    def abort_upload
      blob = ActiveStorage::Blob.find_by!(key: params[:key])

      s3_client_for(blob).abort_multipart_upload(
        bucket: bucket_name_for(blob),
        key: blob.key,
        upload_id: params[:upload_id]
      )

      blob.purge
      head :ok
    end

    private

    # ActiveStorage S3Service stores an Aws::S3::Resource as :client
    # We need the underlying Aws::S3::Client for multipart operations
    def s3_client
      ActiveStorage::Blob.service.send(:client).client
    end

    def bucket_name
      ActiveStorage::Blob.service.send(:bucket).name
    end

    def s3_client_for(blob)
      blob.service.send(:client).client
    end

    def bucket_name_for(blob)
      blob.service.send(:bucket).name
    end

    def ensure_s3_service
      unless ActiveStorage::Blob.service.is_a?(ActiveStorage::Service::S3Service)
        head :not_implemented
      end
    end
  end
end
