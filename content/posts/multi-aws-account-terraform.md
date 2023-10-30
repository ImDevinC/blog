+++
title = "Using Terraform to manage 100+ AWS Accounts"
date = "2023-10-30T14:57:06Z"
author = "ImDevinC"
authorTwitter = "ImDevinC" #do not include @
cover = ""
tags = ["terraform", "aws"]
keywords = ["terraform", "aws"]
description = "Can you use Terraform to easily setup 100+ AWS accounts?"
showFullContent = false
readingTime = true
hideComments = false
color = "" #color from the theme settings
+++
# The Issue
While browsing [/r/terraform](https://reddit.com/r/terraform) the other day, I stumbled upon a post from someon asking how to use Terraform to [manage AWS multi-account deployments at scale](https://www.reddit.com/r/Terraform/comments/17iz4ph/aws_multiaccount_deployments_at_scale/). The actual question (copied here in case it goes away) was:
> Say you have 500 AWS accounts and you need to provision and update their landing zone infrastructure (VPC, logging, IAM, etc.) using Terraform. How would you do it so that changes are deployed parallel to the accounts to speed up deployments? There would need to be one central deployment account which assumes a trust role in target accounts and has account spesific state files in central S3 as well.  
> 
> Is it doable with terraform without any 3rd party tooling? CI/CD platform capable of doing parallel processing is of course in use.
> 
At the time the majority of the feedback was _"don't do this"_, _"use a different tool"_, etc. While these answers are probably great for someone who is starting fresh, but I figured we should address the original question and see what we can solve.

# Can It Be Done?
The first thought was, can this actually be done? After reading over the question, I figured it was worth breaking into two distinct items:

1. How to configure Terraform to manage a large amount of accounts using the same baseline configuration
2. How to parallelize deploys to deploy to multiple accounts at once

When you break it down in this manner, I think it becomes much easier to solve and realize this can be done.

## Setting up the Terraform
Normally, configuring terraform handle different accounts is pretty easy, but the issue comes from the S3 remote backend. A typical remote backend looks like this:
```
terraform {
  backend "s3" {
    bucket         = "my-tf-state-bucket"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    key            = "my-project.tfstate"
  }
}
```
The `key` value here is what needs to be unique per project, as that's the location in S3 where the state file is actually stored.
In most Terraform resource blocks, you can use something like `key = "${var.account_id}/landing-zone.tfstate"` to variablize this field, however in the case of a backend block, variables aren't allowed.

However, Terraform _does_ allow you to pass in backend config values from the CLI. So if we instead change our backend block to something like this:
```
terraform {
  backend "s3" {
    bucket         = "my-tf-state-bucket"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    # key            = "will be set by the CLI"
  }
}
```
We can then call `terraform init` with a `-backend-config` option like the following:
`terraform init -backend-config "key=${ACCOUNT_ID}/landing-zone.tf"`. This now gives us a unique key (since we're using the account ID) and separates our environments.

The only caveat is that your deploy process needs to set the `ACCOUNT_ID` variable to the proper value (it doesn't have to be an account, you just want something unique per account). That leads us into our deploy process.

## Deploying Your Terraform
There are many different deploy pipelines out there, but in this example, let's use GitHub Actions.
The idea here is to make a job that can deploy to a single account, and parameterize it in such a way that you can allow the account ID to be passed in. An example might look like the following:
> Do note that you'll need to configure your GitHub Runner to login to AWS. In the example below, I'm using https://github.com/aws-actions/configure-aws-credentials to login to my account. Checkout their GitHub for details on configuring this.

```
name: Deploy Terraform

on:
  workflow_dispatch:
  push:
    branches:
    - main
    
jobs:
  strategy:
    matrix:
      max-parallel: 2 # Don't want to overload the runners
      accounts: # Example account ID's
        - "291208203782"
        - "152997539387"
        - "865463704016"
        - "538025373561"
        - "070712171214"
  terraform_apply:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::${matrix.accounts}:role/github-actions
        aws-region: ${env.REGION}

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v1

    - name: Terraform Init
      working-directory: terraform
      run: terraform init -backend-config "key=${{ matrix.accounts }}"

    - name: Terraform apply
      if: ${{ github.ref == 'refs/heads/main' }}
      working-directory: terraform
      run: terraform apply -auto-approve
```

In this example, we setup a few key things:
1. The most important piece is here the `jobs.strategy.matrix` block. In GitHub Actions, a matrix allows you to run a job for each value you specify. So in this case, we have a list of accounts, each with a unique account ID, and we will run our deploy job for each one.
   1. I also set a `max-parallel` value here. This controls how many jobs can run at once. If you're talking about a few hundred accounts, you want to be careful to not overload the runners and either a.) use all of your alloted GitHub Action minutes or b.) if you're using self-hosted runners, spin up too many and overwhelm your system.
2. Then for the `aws-actions/configure-aws-credentials@v4` step, we provide the account ID when we assume role. This allows us to easily assume into whatever account we plan on deploying to, and the next few commands will all inherit that login information.
3. When we run `terraform init -backend-config "key=${{ matrix.accounts }}"` you can see we pass in the account from the earlier matrix, which then gets passed into our backend configuration.

# Conclusion
While many of the commentors in the original post are correct about using other tools to handle this in a better fashion, this definitely _can_ be done using raw Terraform and some type of deploy pipeline.
Hopefully this helps someone else in the future, and if you do have to manage a few hundred Terraform accounts in this fashion, good luck!