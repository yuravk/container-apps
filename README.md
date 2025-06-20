# AlmaLinux Containerised Applications

This project provides container images for various applications, built on AlmaLinux OS. The goal is to offer minimal, secure, and efficient containerized solutions.

Currently supported applications include:
*   Pico
*   Nginx
*   Apache with Lua module

## AlmaLinux Base Image

All application containers are built upon the official AlmaLinux OS images. The base setup is defined primarily in `9/Containerfile.00`.

Key aspects of the base image include:

*   **Minimal Core:** Installation of `coreutils-single` and `glibc-minimal-langpack` to provide essential utilities while keeping the image size small.
*   **Testing Utilities:** The `file` utility is included in the base, as it's required for the testing phase of the image build process.
*   **Multi-Architecture Support:** Images are built for several architectures, including `linux/amd64`, `linux/ppc64le`, `linux/s390x`, and `linux/arm64`.
*   **Legacy 386 Support:** For AlmaLinux 9, there's specific handling to enable `linux/386` builds by adjusting repository configurations to point to `vault.almalinux.org` and setting the architecture to `i686`.

## Application-Specific Configurations

Each application has a dedicated `Containerfile` segment that defines its specific setup. A common strategy is to install necessary packages and then aggressively remove unneeded dependencies and system components to create lean images.

### Pico (`pico/Containerfile.50`)

*   **Minimalist Approach:** The Pico application image focuses on extreme minimalism.
*   **Package Removal:** Key packages like `bash` and `gpg-pubkey` (potentially inherited from the base or earlier stages) are explicitly removed. The `dnf` cache is also cleaned.

### Nginx (`nginx/Containerfile.50`)

*   **Installation:** Installs the `nginx` web server.
*   **Aggressive Pruning:** Following the installation, a comprehensive list of packages (including `almalinux-repos`, `bash`, `coreutils-single`, `glibc-common`, various libraries, and system utilities) is removed to significantly reduce the image footprint.

### Apache with Lua (`apache_lua/Containerfile.50`)

*   **Installation:** Installs `httpd` (Apache web server) and `mod_lua` for Lua scripting capabilities.
*   **Aggressive Pruning:** Similar to the Nginx image, a long list of packages is uninstalled post-installation to minimize size. This includes many base system packages, development tools, and libraries not strictly required by Apache and Lua at runtime.

## Build Workflow

The container images are built using a GitHub Actions workflow defined in `.github/workflows/build-push.yml`.

Key features of the workflow include:

*   **Manual Trigger:** Builds are initiated manually via `workflow_dispatch`, allowing users to specify:
    *   `version_major`: The AlmaLinux major version (e.g., `9`).
    *   `application`: The name of the application to build (e.g., `pico`, `nginx`, `apache_lua`).
*   **Dynamic Dockerfile Generation:**
    *   The workflow does not use a static `Dockerfile`. Instead, as detailed in its "Generate Dockerfile" step, it dynamically constructs one by finding and concatenating various `Containerfile.NN` fragments.
    *   These fragments are sourced from three distinct locations:
        1.  The base AlmaLinux OS major version directory (e.g., `9/`).
        2.  The selected application's directory (e.g., `pico/`, `nginx/`, or `apache_lua/`).
        3.  The common `tests/` directory.
    *   The key to the construction is the ordering: all discovered `Containerfile.NN` files from these locations are sorted numerically based on the `NN` part of their filenames (e.g., `Containerfile.00` from the OS directory, followed by `Containerfile.50` from the application directory, and then `Containerfile.60` from the tests directory). The sorted files are then concatenated in this precise order to form the final `Dockerfile` used for the build.
*   **Multi-Platform Builds:** Images are built for the following platforms:
    *   `linux/amd64`
    *   `linux/ppc64le`
    *   `linux/s390x`
    *   `linux/arm64`
    *   `linux/386` (conditionally, for specific AlmaLinux versions like 9)
*   **Image Registry:** Built images are pushed to `quay.io/ykohut`.
*   **Tagging:** Images are tagged with `latest`, the major version, the full version (major.minor), and a version with a date stamp (e.g., `9.5-20231027`).

## Testing Process

The project incorporates a testing phase to ensure the integrity and usability of the binaries within the built container images. This is particularly important given the aggressive package removal strategies.

The testing mechanism involves several components:

1.  **Binary List Generation (`tests/binaries_list.sh`):**
    *   During the image build, as defined by `tests/Containerfile.60`, the `tests/binaries_list.sh` script is executed.
    *   This script scans all files installed by RPM packages within the image's staging root filesystem (`/mnt/sys-root`).
    *   It identifies all executable files and shared libraries based on their MIME types.
    *   A sorted, unique list of these binary and library file paths (relative to the image's root) is saved to `/tmp/binaries.list` within the image.

2.  **Workflow-Integrated Testing:**
    *   After an image is built, the GitHub Actions workflow (`build-push.yml`) performs tests before pushing the image.
    *   It extracts the `/tmp/binaries.list` file from the built image for each supported platform.
    *   For each executable and library in the list, it runs a check using the platform-specific dynamic linker (e.g., `/usr/lib64/ld-linux-x86-64.so.2 --list <path_to_binary>`).
    *   This check verifies that all necessary shared libraries for each binary are present and resolvable within the image.
    *   If any binary is found to have missing dependencies, the test fails, and the image is not pushed.

This testing process helps catch issues where essential libraries might have been inadvertently removed during the image minimization steps, ensuring that the applications and utilities within the containers are functional.

## How to Use / Build

The primary way to build these container images is by using the provided GitHub Actions workflow.

1.  **Navigate to the Actions Tab:** Go to the "Actions" tab of this GitHub repository.
2.  **Select the Workflow:** In the left sidebar, click on the "Build and push" workflow.
3.  **Run the Workflow:**
    *   Click the "Run workflow" dropdown button.
    *   You will be presented with options to select:
        *   **AlmaLinux major version:** Choose the desired AlmaLinux base version (e.g., `9`).
        *   **Application name:** Select the application you want to containerize (e.g., `pico`, `nginx`, `apache_lua`).
    *   Click the "Run workflow" button to start the build process.
4.  **Monitor and Retrieve Images:**
    *   The workflow will build the image, run tests, and if successful, push it to `quay.io/ykohut`.
    *   The image will be tagged with several tags, including:
        *   `latest` (for the latest successful build of that application on that AlmaLinux version)
        *   `<almalinux_major_version>` (e.g., `9`)
        *   `<almalinux_major_version>.<almalinux_minor_version>` (e.g., `9.5`)
        *   `<almalinux_major_version>.<almalinux_minor_version>-<date_stamp>` (e.g., `9.5-20231115`)
    *   You can then pull the image using `docker pull quay.io/ykohut/<almalinux_major_version>-<application_name>:<tag>`. For example:
        ```bash
        docker pull quay.io/ykohut/9-pico:latest
        docker pull quay.io/ykohut/9-nginx:9.5
        ```

The dynamic Dockerfile generation and testing are all handled by the workflow.

## Usage Examples

This section provides practical examples of how to run the containerized applications.

### Nginx Example

This example demonstrates how to run the Nginx container and serve a simple HTML page.

1.  **Prepare your web content:**

    Create a directory named `html` in your current working directory. Inside the `html` directory, create an `index.html` file with the following content:

    ```html
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <title>Nginx</title>
    </head>
    <body>
      <h2>Hello World from Nginx!</h2>
    </body>
    </html>
    ```

2.  **Run the Nginx container:**

    Use the following command to run the Nginx container. This command mounts your `html` directory into the container at `/usr/share/nginx/html` (the default Nginx web root) and maps port 80 on your host to port 80 in the container. Replace `9-nginx:latest` if you are using a different image name or tag.

    ```bash
    docker run -d --rm -v $(pwd)/html:/usr/share/nginx/html -p 80:80 quay.io/ykohut/9-nginx:latest
    ```
    *   `-d`: Run container in detached mode.
    *   `--rm`: Automatically remove the container when it exits.
    *   `-v $(pwd)/html:/usr/share/nginx/html`: Mounts the local `html` directory to `/usr/share/nginx/html` in the container.
    *   `-p 80:80`: Maps port 80 on the host to port 80 on the container.
    *   `quay.io/ykohut/9-nginx:latest`: The image to use. Adjust if your image name/tag is different (e.g., if you built it locally without pushing to this specific registry path).

3.  **Check if the container is running:**

    You can list your running Docker containers using:

    ```bash
    docker ps
    ```

    You should see output similar to this (the container ID and name will vary):

    ```
    CONTAINER ID   IMAGE                             COMMAND                  CREATED         STATUS         PORTS                NAMES
    236a60f35a13   quay.io/ykohut/9-nginx:latest   "/usr/sbin/nginx -g …"   5 seconds ago   Up 5 seconds   0.0.0.0:80->80/tcp   great_visvesvaraya
    ```

4.  **Verify Nginx is serving content:**

    You can test if Nginx is working by accessing `http://localhost:80` in your web browser, or by using a command-line tool like `lynx` or `curl`.

    Using `lynx`:
    ```bash
    lynx localhost:80
    ```

    Using `curl`:
    ```bash
    curl localhost:80
    ```

    Both commands should display the "Hello World from Nginx!" message from your `index.html` file.

### Apache + Lua Example

This example demonstrates how to run the Apache container with `mod_lua` and execute a simple Lua script.

1.  **Prepare your Lua script and HTML content directory:**

    Create a directory named `html` in your current working directory. Inside the `html` directory, create a `hello.lua` file with the following content. This script will be served by Apache.

    ```lua
    -- /var/www/lua/hello.lua -- (This comment indicates expected path inside container, actual local path is html/hello.lua)
    require "apache2"

    function handle(r)
        -- Set the content type for the response
        r.content_type = "text/html"
        r:puts("<h1>Hello World from Lua on Apache!</h1>")

        -- Return OK to indicate successful handling
        return apache2.OK
    end
    ```

2.  **Create Apache configuration for Lua:**

    Create a directory named `conf.d` in your current working directory. Inside `conf.d`, create a file named `lua_example.conf` with the following content. This tells Apache how to handle `.lua` files.

    ```apache
    <IfModule lua_module>
        AddHandler lua-script .lua
    </IfModule>
    ```

3.  **Run the Apache + Lua container:**

    Use the following command to run the `apache_lua` container. This command mounts:
    *   Your `html` directory to `/var/www/html` in the container (Apache's default document root).
    *   Your `lua_example.conf` to `/etc/httpd/conf.d/lua_example.conf` in the container.
    It also maps port 80 on your host to port 80 in the container. Replace `quay.io/ykohut/9-apache_lua:latest` if you are using a different image name or tag.

    ```bash
    docker run -d --rm -v $(pwd)/html:/var/www/html -v $(pwd)/conf.d/lua_example.conf:/etc/httpd/conf.d/lua_example.conf -p 80:80 quay.io/ykohut/9-apache_lua:latest
    ```
    *   `-d`: Run container in detached mode.
    *   `--rm`: Automatically remove the container when it exits.
    *   `-v $(pwd)/html:/var/www/html`: Mounts the local `html` directory.
    *   `-v $(pwd)/conf.d/lua_example.conf:/etc/httpd/conf.d/lua_example.conf`: Mounts the Lua Apache configuration.
    *   `-p 80:80`: Maps port 80 on the host to port 80 on the container.
    *   `quay.io/ykohut/9-apache_lua:latest`: The image to use. Adjust if different.

4.  **Check if the container is running:**

    You can list your running Docker containers using:

    ```bash
    docker ps
    ```

    You should see output similar to this (the container ID and name will vary):

    ```
    CONTAINER ID   IMAGE                                COMMAND                  CREATED         STATUS         PORTS                                 NAMES
    017138103cf4   quay.io/ykohut/9-apache_lua:latest   "/usr/sbin/httpd -DF…"   7 minutes ago   Up 7 minutes   0.0.0.0:80->80/tcp, [::]:80->80/tcp   focused_lichterman
    ```

5.  **Verify Apache + Lua is working:**

    You can test if Apache is serving the Lua script by accessing `http://127.0.0.1/hello.lua` (or `http://localhost/hello.lua`) using `curl`:

    ```bash
    curl http://127.0.0.1/hello.lua
    ```

6.  **Expected Output:**

    The output from the `curl` command should be:

    ```html
    <h1>Hello World from Lua on Apache!</h1>
    ```
