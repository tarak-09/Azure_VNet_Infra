# Edit, then from environments/dev: terraform plan -out tfplan, review, terraform apply tfplan.

resource_group_name = "Test-RG"
environment         = "dev"
workload            = "core"

# Test-RG already has TestVnet on 10.0.0.0/27; keep ranges distinct.
address_space     = ["10.10.0.0/16"]
app_subnet_prefix = "10.10.1.0/24"

cost_center = "cc-dev"
owner       = "tarak"
