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
    *   The workflow does not use a static `Dockerfile`. Instead, it dynamically constructs one by concatenating various `Containerfile.*` fragments.
    *   The fragments are sourced from the base OS version directory (e.g., `9/`), the selected application's directory (e.g., `pico/`), and the `tests/` directory.
    *   Files are concatenated in lexicographical order of their names (e.g., `Containerfile.00`, `Containerfile.50`, `Containerfile.60`).
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
