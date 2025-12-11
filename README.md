# Baseline Terraform Repository

This repository provides a starting point for new Terraform projects, structured to support multiple environments like `dev` and `prod`.

⚠️ **All commands are run using [OpenTofu](https://opentofu.org/), not Terraform.** 

## Directory Structure

-   `environments/`: Contains the configuration for each environment.
    -   `dev/`: Configuration for the Development environment.
    -   `prod/`: Configuration for the Production environment.
-   `environments/`: Contains the configuration for each environment.
    -   `dev/`: Configuration for the Development environment.
    -   `prod/`: Configuration for the Production environment.
-   `.gitignore`: Standard Terraform ignores.
-   `README.md`: This file.

## Naming and Tagging with Cloud Posse's `label` module

This repository uses modules from [Cloud Posse](https://cloudposse.com/), which internally use the [`cloudposse/label/null`](https://registry.terraform.io/modules/cloudposse/label/null/latest) module to ensure consistent naming and tagging for all resources.

### How it Works

The `label` module is a utility that centralizes resource naming logic. Instead of manually creating resource names and tag maps, you provide it with standardized inputs, and it generates the final name and tags as outputs.

-   **Inputs**: You provide context components like `namespace`, `tenant`, `stage`, `name`, and `attributes`.
-   **Outputs**:
    -   `id`: A formatted string used for resource names, following the pattern `namespace-tenant-stage-name-attributes`. For example: `eg-internal-dev-storage`.
    -   `tags`: A map of tags that includes the input components as well as any additional custom tags you provide.

### How We Use It

1.  **Indirectly (via other Cloud Posse modules)**: The `cloudposse/s3-bucket/aws` module we use for our storage bucket handles this for us. We provide the `namespace`, `stage`, etc., directly to the S3 module, and it passes them to its own internal `label` module. This is the most common and convenient way to use it.

2.  **Directly (for standalone resources)**: When creating a resource that doesn't have a high-level Cloud Posse module (like a simple `aws_sns_topic`), we can use the `label` module directly in our environment configuration. You can see an example of this in `environments/dev/main.tf` and `environments/prod/main.tf`.

This approach guarantees that every single resource, whether from a high-level module or created as a standalone resource, follows the exact same naming and tagging convention defined in the SOP.

It also applies a standard set of tags to all resources as defined in the AWS SOP, including:
- `Billback`
- `Billable`
- `client`
- `DataClassification`
- `ComplianceRequirement`

## How to Use

1.  **Initialize Terraform:**
    This will download the necessary providers and modules.
    ```sh
    terraform init
    ```

2.  **Review the plan:**
    This will show you what resources Terraform will create.
    ```sh
    terraform plan -var-file='./tfvars/dev.tfvars'

    ```

3.  **Apply the changes:**
    This will create the resources in your AWS account.

    ⚠️ **Applies should not be done locally.** Use the GitHub Actions workflow to apply changes to any environment.

    ```sh
    terraform apply -var-file='./tfvars/dev.tfvars'
    ```

To deploy to the production environment, you would navigate to `environments/prod` and run the same commands.

## GitHub Actions Workflow

This repository is configured with a GitHub Actions workflow to automate `plan`, `apply`, and `destroy` operations for each environment.

### How it Works

The workflow is triggered manually via the `workflow_dispatch` event. You can run the workflow from the "Actions" tab in the GitHub repository.

When you trigger the workflow, you will be prompted to select:
1.  **Action**: The Terraform action to perform (`plan`, `apply`, or `destroy`).
2.  **Environment**: The target environment (`dev` or `prod`).

The workflow uses GitHub Environments to protect `prod`. The `prod` environment may require manual approval before the `apply` or `destroy` jobs can run.

### Workflow Steps

1.  **Plan**: This job always runs. It generates a Terraform plan for the selected environment. This allows you to review the proposed changes before applying or destroying.
2.  **Apply**: This job runs only when you select the `apply` action. It applies the Terraform configuration to the selected environment. It requires the `plan` job to complete successfully.
3.  **Destroy**: This job runs only when you select the `destroy` action. It destroys all resources managed by the Terraform configuration in the selected environment. It requires the `plan` job to complete successfully.

### How to Use

1.  Go to the **Actions** tab of the repository.
2.  Select the **Example Service Release** workflow in the left sidebar.
3.  Click the **Run workflow** dropdown on the right.
4.  Choose the desired **Action** (`plan`, `apply`, or `destroy`).
5.  Choose the **Environment** (`dev` or `prod`).
6.  Click the **Run workflow** button.


## AWS SSO and CLI Sessions with Leapp

[Leapp](https://www.leapp.cloud/) is a cross-platform desktop application for managing access to cloud providers. It is particularly useful for handling temporary AWS credentials when using AWS Single Sign-On (SSO).

Instead of manually logging in via the AWS CLI and exporting credentials, Leapp provides a GUI to manage and generate temporary sessions for your terminal.

-   **Setup Guide**: [Configuring AWS Single Sign-On Integration with Leapp](https://docs.leapp.cloud/latest/configuring-integration/configure-aws-single-sign-on-integration/)
