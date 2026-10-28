import boto3
from botocore.exceptions import BotoCoreError, ClientError
from robot.api.deco import keyword


class MinioS3:
    """Robot Framework library for S3-compatible storage (MinIO) via boto3."""


    def _client(self, endpoint, access_key, secret_key, region, verify):
        return boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region or "us-east-1",
            verify=verify,
        )


    @keyword("Upload Object To MinIO Bucket")
    def upload_object_to_minio_bucket(
        self,
        bucket,
        key,
        local_file,
        endpoint,
        access_key,
        secret_key,
        region="",
        verify=True,
    ):
        """Upload a local file to a MinIO bucket with an exact object key.

        Returns a dictionary with ``ok`` (bool), ``code`` and ``message``
        (error details when the upload is rejected). It never raises, so
        tests can assert the expected failure of MinIO quota enforcement.
        """
        try:
            with open(local_file, "rb") as file_obj:
                body = file_obj.read()
            client = self._client(endpoint, access_key, secret_key, region, verify)
            client.put_object(Bucket=bucket, Key=key, Body=body)
        except ClientError as exc:
            error = exc.response.get("Error", {})
            return {
                "ok": False,
                "code": error.get("Code", ""),
                "message": error.get("Message", str(exc)),
            }
        except BotoCoreError as exc:
            return {"ok": False, "code": "", "message": str(exc)}
        return {"ok": True, "code": "", "message": ""}


    @keyword("List MinIO Object Keys")
    def list_minio_object_keys(
        self,
        bucket,
        prefix,
        endpoint,
        access_key,
        secret_key,
        region="",
        verify=True,
    ):
        """List object keys under a prefix in a MinIO bucket via the S3 API.

        Returns a (possibly empty) list of object keys.
        """
        client = self._client(endpoint, access_key, secret_key, region, verify)
        listing = client.list_objects_v2(Bucket=bucket, Prefix=prefix)
        return [obj.get("Key", "") for obj in listing.get("Contents", [])]


    @keyword("Get MinIO Bucket Notification")
    def get_minio_bucket_notification(
        self,
        bucket,
        endpoint,
        access_key,
        secret_key,
        region="",
        verify=True,
    ):
        """Return the bucket notification configuration (diagnostic use)."""
        client = self._client(endpoint, access_key, secret_key, region, verify)
        return client.get_bucket_notification_configuration(Bucket=bucket)


# Alias so Robot Framework resolves this class when the library is imported
# by file path (it looks for an attribute named like the module file).
minio_s3 = MinioS3
