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
        return self.client.run_service(service_name, input=input_data, async_call=True)

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
