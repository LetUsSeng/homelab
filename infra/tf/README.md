# Terraform/OpenTofu

## How it works

I'm using a AWS s3 bucket to manage my state file for now.

### Get it working
```bash
export AWS_PROFILE=<YOUR AWS PROFILE>
export AWS_REGION=<THE REGION OF YOUR BUCKET>
```

## Set up ssh agent for vm
```bash
eval "$(ssh-agent -s)"
ssh-add
```
