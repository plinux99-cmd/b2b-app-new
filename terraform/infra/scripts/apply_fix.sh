#!/bin/bash
set -e

cd /Users/pramod.kumarnavikenz.com/test9-few-thing-left/terraform/infra

echo "=== Formatting Terraform code ==="
terraform fmt -recursive

echo ""
echo "=== Validating Terraform code ==="
terraform validate

echo ""
echo "=== Running Terraform Plan ==="
terraform plan -out=tfplan_fix

echo ""
echo "=== Applying Terraform Changes ==="
terraform apply -auto-approve tfplan_fix

echo ""
echo "=== Terraform Apply Complete ==="
echo ""
echo "API Endpoint:"
terraform output -raw api_endpoint
echo ""
echo ""
echo "Testing /app-version/check endpoint:"
curl -s https://$(terraform output -raw api_endpoint)/app-version/check
echo ""
echo ""
echo "Testing /assetservice/ endpoint with auth header:"
curl -s -w "\nStatus: %{http_code}\n" -H "Authorization: Bearer test-token" https://$(terraform output -raw api_endpoint)/assetservice/
