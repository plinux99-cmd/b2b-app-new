Troubleshooting Terraform apply issues

This file contains quick troubleshooting steps for common errors seen when applying the infra stack.

1) Error: EntityAlreadyExists (Role or Policy already exists)

Cause: The module is attempting to create an IAM Role or Policy that already exists in the AWS account (possibly created manually or by a previous run).

Options to resolve:

- Use an existing role instead of creating one
  - Set `create_aws_lb_controller_irsa = false` and provide `aws_lb_controller_role_arn` (and/or `lb_controller_role_name`) in `terraform.tfvars`.

- Import the existing role/policy into Terraform state
  - Find the module and resource address that would own the role (example):
    - If using the registry IRSA module the role resource can be imported with a command like:
      terraform import 'module.aws_lb_controller_irsa[0].aws_iam_role.this' <role-name-or-arn>
    - Import any associated policies similarly (example):
      terraform import 'module.aws_lb_controller_irsa[0].aws_iam_policy.this' <policy-arn>
  - After importing, run `terraform plan` to confirm no further diffs.

  Helpful tip: automate existence check + import (example)

  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  ROLE_NAME="aws-load-balancer-controller"
  # check if role exists
  if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    echo "Role $ROLE_NAME exists; importing into Terraform state..."
    terraform import "module.aws_lb_controller_irsa[0].aws_iam_role.this" "$ROLE_NAME"
    # import any attached policy ARNs if needed (inspect role)
  else
    echo "Role $ROLE_NAME not found; Terraform will create it when apply runs (if enabled)."
  fi
  ```

  Notes:
  - Terraform cannot automatically import resources during `plan`/`apply`; imports must be run as a separate CLI step (or you can set variables to point at existing ARNs so the module will not create the resource).
  - The pattern used in modules: prefer explicit variables like `aws_lb_controller_role_arn` or `cloudtrail_role_arn` to reference pre-existing resources; or run the import script above to reconcile existing resources into state.

  CloudTrail role: using an existing role

  If you already have a role to use for CloudTrail's CloudWatch Logs delivery, instead of creating a new role set the module variable when calling the module (e.g., in `terraform.tfvars`):

  ```hcl
  cloudtrail_role_arn = "arn:aws:iam::<account-id>:role/<your-cloudtrail-role>"
  ```

  If you prefer to *import* the existing role into Terraform state so the module still manages it, run a check & import similar to the LB Controller example above and then run `terraform plan`.

Notes: Import commands depend on exact resource names in the module. Use `terraform state list` to inspect current state and determine precise addresses.


2) Error: You can't create this secret because a secret with this name is already scheduled for deletion

Cause: A Secrets Manager secret with the same name was previously deleted and is in the scheduled-deletion state. AWS prevents creating a new secret with the exact same name until the previous secret is fully deleted or restored.

Options to resolve:

- Restore the deleted secret (if it's the same resource you still need):
  aws secretsmanager restore-secret --secret-id <secret-id-or-arn>

- Import the scheduled secret into Terraform state (so Terraform manages it):
  terraform import aws_secretsmanager_secret.<name> <secret-arn>

- Use an existing secret ARN instead of creating a new one:
  - Set `create_secrets = false` and pass `secret_arn = "arn:aws:secretsmanager:..."` to the RDS module.

- Choose a new unique name (e.g., set a different `project_name` temporarily or use a different suffix).


3) CloudTrail role creation failure: MalformedPolicyDocument: Policy has no statements

Cause: The IAM policy document passed to the role module was empty or malformed due to a templating issue or interpolation problem.

Action:

- Check `module.cloudtrail` policy input and ensure the policy block contains a valid JSON policy with at least one Statement (see `modules/cloudtrail/main.tf`).
- Confirm variables such as `var.kms_key_arn` or others (that may be used in policy) are set correctly.
- Re-run `terraform plan` and inspect the generated policy JSON (or use `terraform console` to evaluate interpolations).


4) General tips

- When applying to an environment with existing manual resources, prefer importing those resources into Terraform state instead of creating duplicates.
- Use `terraform plan -out=tfplan` and inspect `terraform show -json tfplan | jq .` if you need to programmatically examine changes.
- If an apply was interrupted (partial changes), wait for the AWS console to stabilize (some resources may be in pending / deleting state) before re-running apply.

5) Fast cleanup for stuck Kubernetes resources (jobs, hooks, namespaces)

Cause: Helm pre-delete hooks may create Jobs that block uninstall and leave the Kubernetes namespace in a Terminating state. This will often cause the Kubernetes provider to hit a timeout and make `terraform destroy` fail or hang.

Quick fix (manual):

- Delete the hook job and any pods it created:
  - `kubectl delete job tigera-operator-uninstall -n <namespace>`
  - `kubectl delete pods -n <namespace> -l job-name=tigera-operator-uninstall --grace-period=0 --force`
- If the namespace is stuck Terminating, remove finalizers:
  - `kubectl patch namespace <namespace> -p '{"metadata":{"finalizers":[]}}' --type=merge`

Automated helper: `terraform/infra/scripts/fast-cleanup.sh`

- Usage examples:
  - Default (mobileapp namespace, known Calico uninstall job):
    - `./scripts/fast-cleanup.sh`
  - Uninstall a Helm release and patch finalizers:
    - `./scripts/fast-cleanup.sh -n myns -r tigera --patch-finalizers`

Notes:
- The script tries `helm uninstall` first (if release name provided), then deletes jobs/pods and can remove namespace finalizers if requested.
- Use `-f` to force deletion of jobs/pods (adds `--grace-period=0 --force`).
- This script is a convenience for developers; confirm actions before running in production.


If you'd like, I can attempt the import commands for you (I can prepare exact `terraform import` commands once you point me to the exact existing role/policy/secret names or ARNs).