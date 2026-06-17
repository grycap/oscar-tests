from oscar_python.client import Client
from robot.api.deco import keyword


class OscarLibrary:
    def __init__(self):
        self.client = None

    @keyword("Connect With Basic Auth")
    def connect_with_basic_auth(self, cluster_id, endpoint, access_token, ssl="True"):
        options = {
            "cluster_id": cluster_id,
            "endpoint": endpoint,
            "oidc_token": access_token,
            "ssl": ssl,
        }
        self.client = Client(options=options)

    # Cluster methods

    @keyword("Get Cluster Info")
    def get_cluster_info(self):
        # Returns an HTTP response or an HTTPError
        return self.client.get_cluster_info()

    @keyword("Get Cluster Config")
    # Returns an HTTP response or an HTTPError
    def get_cluster_config(self):
        return self.client.get_cluster_config()

    # Service methods

    @keyword("List Services")
    def list_services(self):
        # Returns an HTTP response or an HTTPError
        return self.client.list_services()

    @keyword("Create Service")
    def create_service(self, path_to_fdl):
        # Returns nothing if the service is created or an error if something goes wrong
        return self.client.create_service(path_to_fdl)

    @keyword("Get Service")
    def get_service(self, service_name):
        # Returns an HTTP response or an HTTPError
        return self.client.get_service(service_name)

    @keyword("Run Service Synchronously")
    def run_service_sync(self, service_name, input_data="", output="", timeout=None):
        # Returns an HTTP response
        return self.client.run_service(
            service_name, input=input_data, output=output, timeout=timeout
        )

    @keyword("Update Service")
    def update_service(self, service_name, path_to_fdl):
        # Returns nothing if the service is created or an error if something goes wrong
        return self.client.update_service(service_name, path_to_fdl)

    @keyword("Run Service Asynchronously")
    def run_service_async(self, service_name, input_data=""):
        # Returns an HTTP response
        return self.client.run_service(service_name, input=input_data,  async_call=True)

    @keyword("Remove Service")
    def remove_service(self, service_name):
        # Returns an HTTP response
        return self.client.remove_service(service_name)

    # Log methods

    @keyword("Get Job Logs")
    def get_job_logs(self, service_name, job_id):
        # Returns an HTTP response
        return self.client.get_job_logs(service_name, job_id)

    @keyword("List Jobs")
    def list_jobs(self, service_name):
        # Returns an HTTP response
        return self.client.list_jobs(service_name)

    @keyword("Remove Job")
    def remove_job(self, service_name, job_id):
        # Returns an HTTP response
        return self.client.remove_job(service_name, job_id)

    @keyword("Remove All Jobs")
    def remove_all_jobs(self, service_name):
        # Returns an HTTP response
        return self.client.remove_all_jobs(service_name)

    # Health

    @keyword("Health Check")
    def health_check(self):
        return self.client.health_check()

    # Deployment

    @keyword("Get Deployment Status")
    def get_deployment_status(self, service_name):
        return self.client.get_deployment_status(service_name)

    @keyword("Get Deployment Logs")
    def get_deployment_logs(self, service_name):
        return self.client.get_deployment_logs(service_name)

    # Buckets

    @keyword("Create Bucket")
    def create_bucket(self, bucket_name, visibility="private", allowed_users=None):
        if allowed_users is None:
            allowed_users = []
        return self.client.create_bucket(bucket_name, visibility, allowed_users)

    @keyword("List Buckets")
    def list_buckets(self):
        return self.client.list_buckets()

    @keyword("Get Bucket")
    def get_bucket(self, bucket_name):
        return self.client.get_bucket(bucket_name)

    @keyword("Delete Bucket")
    def delete_bucket(self, bucket_name):
        return self.client.delete_bucket(bucket_name)

    @keyword("Presign Bucket")
    def presign_bucket(self, bucket_name, object_key, operation="download", expires=0, content_type=""):
        return self.client.presign_bucket(bucket_name, object_key, operation, expires, content_type)

    # Volumes

    @keyword("List Volumes")
    def list_volumes(self):
        return self.client.list_volumes()

    @keyword("Create Volume")
    def create_volume(self, name, size):
        return self.client.create_volume(name, size)

    @keyword("Get Volume")
    def get_volume(self, name):
        return self.client.get_volume(name)

    @keyword("Delete Volume")
    def delete_volume(self, name):
        return self.client.delete_volume(name)

    # Metrics

    @keyword("Get Metrics Summary")
    def get_metrics_summary(self):
        return self.client.get_metrics_summary()

    @keyword("Get Metrics Breakdown")
    def get_metrics_breakdown(self, group_by=None):
        return self.client.get_metrics_breakdown(group_by)

    @keyword("Get Service Metrics")
    def get_service_metrics(self, service_name):
        return self.client.get_service_metrics(service_name)

    # Quotas

    @keyword("Get Own Quota")
    def get_own_quota(self):
        return self.client.get_own_quota()

    @keyword("Get User Quota")
    def get_user_quota(self, user_id):
        return self.client.get_user_quota(user_id)

    # System Logs

    @keyword("Get System Logs")
    def get_system_logs(self, timestamps=False, previous=False):
        return self.client.get_system_logs(timestamps, previous)

    # Storage methods

    @keyword("Create Storage Client")
    def create_storage_client(self, service_name):
        # Returns a storage object
        self.storage_service = self.client.create_storage_client(service_name)

    @keyword("List Files From Path")
    def list_files_from_path(self, storage_provider, remote_path):
        # Returns json
        return self.storage_service.list_files_from_path(storage_provider, remote_path)

    @keyword("Upload File To Storage")
    def upload_file_to_storage(self, storage_provider, local_path, remote_path):
        return self.storage_service.upload_file(
            storage_provider, local_path, remote_path
        )

    @keyword("Download File From Storage")
    def download_file_from_storage(self, storage_provider, local_path, remote_path):
        return self.storage_service.download_file(
            storage_provider, local_path, remote_path
        )
