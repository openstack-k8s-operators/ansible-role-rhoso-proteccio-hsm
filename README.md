# rhoso-proteccio-hsm Role

In order to use Eviden [Proteccio Network HSMs](https://eviden.com/solutions/digital-security/data-encryption/trustway-proteccio-nethsm/) as a PKCS#11 backend, the Barbican
images need to be customized to include the Proteccio HSM Client software.

The purpose of this role is to:
* Generate new images for the barbican-api and barbican-worker containing the Proteccio Client.
* Upload those images to a private repository for use in a RHOSO deployment.
* Create any required config to be mounted by the Barbican images for connecting to the HSMs.

We expect some preparatory steps to be completed prior to execution in order for the role to complete successfully:
* The Proteccio Client ISO file has been obtained from Eviden.
* The location of the Proteccio Client ISO file should be made available at `proteccio_client_src`.
* All of the certificates and keys needed to communicate with the HSM(s) must be copied to the `proteccio_crt_src` directory.
  * These include the server certificates, which typically have the format `<ip_address>.crt`.
  * These also include the client certificate and key, which typically have the format `<client_name>.crt` and `<client_name>.key`.
  * All these files will ultimately be referenced in your proteccio.rc file.
* The proteccio.rc is available at `proteccio_conf_src`.
* The certs and proteccio.rc will be retrieved from the given locations and stored in a secret (proteccio_data_secret).
* The PIN (password) to log into the HSM will be stored in a secret (login_secret).

A minimal (one that takes the defaults) invocation of this role is shown below.  In this case, the Proteccio Client
software and required certificates and configuration files are stored locally under `/opt/proteccio`.

    ---
    - hosts: localhost
      vars:
        barbican_dest_image_namespace: "{{ your quay.io account name }}"
        proteccio_client_iso: "Proteccio3.06.05.iso"
        proteccio_client_src: "file:///opt/proteccio/{{ proteccio_client_iso }}"
        proteccio_password: "{{ PIN to log into proteccio }}"
        kubeconfig_path: "/path/to/.kube/config"
        oc_dir: "/path/to/oc/bin/dir/"
      roles:
        - rhoso_proteccio_hsm

You can also do the steps separately.

    ---
    - hosts: localhost
      vars:
        barbican_dest_image_namespace: "{{ your quay.io account name }}"
        proteccio_client_iso: "Proteccio3.06.05.iso"
        proteccio_client_src: "file:///opt/proteccio/{{ proteccio_client_iso }}"
       tasks:
       - name: Create new Barbican images with the Proteccio Client
         ansible.builtin.include_role:
           name: rhoso_proteccio_hsm
           tasks_from: create_image

    ---
    - hosts: localhost
      vars:
        proteccio_password: "{{ PIN to log into proteccio }}"
        kubeconfig_path: "/path/to/.kube/config"
        oc_dir: "/path/to/oc/bin/dir/"
      tasks:
      - name: Create secrets containing certificates and password
        ansible.builtin.include_role:
          name: rhoso_proteccio_hsm
          tasks_from: create_secrets

## Role Variables

### Role Parameters
| Variable      | Type    | Default Value               | Description                                                     |
| ------------- | ------- | --------------------------- | --------------------------------------------------------------- |
| `cleanup`     | boolean | `false`                     | Delete all resources created by the role at the end of the run. |
| `working_dir` | string  | `/tmp/hsm-prep-working-dir` | Working directory to store artifacts.                           |

### Image Generation Variables
| Variable                          | Type    | Default Value                                | Description                                      |
| -------------------------------   | ------- | ---------------------------------------------| ------------------------------------------------ |
| `proteccio_client_iso`            | string  | `Proteccio3.06.05.iso`                       | File name of the Proteccio Client ISO file       |
| `proteccio_client_src`            | string  | `file:///opt/proteccio/Proteccio3.06.05.iso` | Location of the Proteccio Client ISO file        |
| `barbican_src_image_registry`     | string  | `quay.io`                                    | Registry used to pull down the Barbican images   |
| `barbican_src_image_namespace`    | string  | `podified-antelope-centos9`                  | Registry namespace for the Barbican images       |
| `barbican_src_api_image_name`     | string  | `openstack-barbican-api`                     | Name of the Barbican API image to be pulled      |
| `barbican_src_worker_image_name`  | string  | `openstack-barbican-worker`                  | Name of the Barbican Worker image to be pulled   |
| `barbican_src_image_tag`          | string  | `current-podified`                           | Tag used to identify the source images           |
| `barbican_dest_image_registry`    | string  | `quay.io`                                    | Registry used to push the modified images        |
| `barbican_dest_image_namespace`   | string  | `podified-antelope-centos9`                  | Registry namespace for the modified images       |
| `barbican_dest_api_image_name`    | string  | `openstack-barbican-api`                     | Name of the Barbican API image to be pushed      |
| `barbican_dest_worker_image_name` | string  | `openstack-barbican-worker`                  | Name of the Barbican Worker image to be pushed   |
| `barbican_dest_image_tag`         | string  | `current-podified-proteccio`                 | Tag used to identify the modified images         |
| `image_registry_verify_tls`       | boolean | `true`                                       | Use TLS verification when pushing/pulling images |

### Secret Generation Variables
| Variable                          | Type   | Default Value                                   | Description                                                                                   |
| --------------------------------- | ------ | ----------------------------------------------  | --------------------------------------------------------------------------------------------- |
| `kubeconfig_path`                 | string | None                                            | Full path to kubeconfig file. e.g. `/home/user/.kube/config`                                  |
| `oc_dir`                          | string | None                                            | Full path to the directory containing the `oc` command binary. e.g. `/home/user/.crc/bin/oc/` |
| `proteccio_password`              | string | None                                            | Password (SO PIN) used to log into the HSM                                                    |
| `proteccio_conf_src`              | string | `file:///opt/proteccio/proteccio.rc`            | Full path to the proteccio.rc file                                                            |
| `proteccio_client_crt_src`        | string | `file:///opt/proteccio/certs/client.crt`        | Full path to the TLS Client certificate file                                                  |
| `proteccio_client_key_src`        | string | `file:///opt/proteccio/certs/client.key`        | Full path to the private key file associated with the Client certificate file                 |
| `proteccio_server_crt_src`        | list   | `["file:///opt/proteccio/certs/proteccio.crt"]` | List of full paths to the TLS Server Certificates                                             |
| `proteccio_data_secret`           | string | `proteccio-data`                                | Name of the secret used to store client and server certificates                               |
| `proteccio_data_secret_namespace` | string | `openstack`                                     | Namespace to be used when creating `proteccio_data_secret`                                    |
| `login_secret`                    | string | `hsm-login`                                     | Name of the secret used to store the password to log into the HSM                             |
| `login_secret_field`              | string | `PKCS11Pin`                                     | Secret key used to store the `proteccio_password` data in `login_secret`                      |

## The `proteccio.rc` configuration file

The Eviden Trustway Proteccio HSM client software reads the configuration file located at `/etc/proteccio/proteccio.rc`.  This file needs to be created at `/opt/proteccio/proteccio.rc` and customized before executing this role.  Details on how to do this are provided in the Eviden documentation on the client software ISO.  An annotated example file is provided below.

```
[PROTECCIO]
IPaddr=<IP address of your first HSM device>
SSL=1
SrvCert=<name of the crt file corresponding to this HSM's digital certificate>
# The HSM certificate file lies in the same directory as the proteccio.rc file.

# This second section is only applicable if you have a second HSM device that will work in high availability with the first one.
[PROTECCIO]
IPaddr=<IP address of your second HSM device>
SSL=1
SrvCert=<name of the crt file corresponding to this HSM's digital certificate>
# The HSM certificate file lies in the same directory as the proteccio.rc file.

[CLIENT]
Mode=2 # If you have two or more devices, this needs to be 2.  Otherwise, put a 0 here.
LoggingLevel=4
LogFile=/var/log/barbican/proteccio.log
StatusFile=/var/log/barbican/HSM_Status.log
ClntKey=<Name of the client's key file>
ClntCert=<Name of the client's crt file>
# The client certificate and key files lie in the same directory as the proteccio.rc file.
```

You can know more about the configuration file on the Trustway Administration Guide, located inside the client software ISO image.

## Sidenode

While running this role, you might face a problem with the `podman` utility while it tries to upload the customized image to your specified repository.  This happens because the authentication credentials
Ansible uses are not exactly the same ones you use while invoke `podman` in the command line.

To solve this, locate the lines that start with `podman push` inside of the `files/image_add_proteccio_client.sh` file and change them to include the following parameter:

```
--authfile=<location of the auth.json file>
```

The `podman` utility stores the credentials in the `auth.json` file when you authenticate using `podman login`.  The file is usually located under `/run/user/<user id>/containers/auth.json`, but it may change depending on the system.

