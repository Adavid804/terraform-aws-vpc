#!/bin/bash
terraform plan -out=tfplan -var="vpc_name=test-vpc" -var="cidr_block=10.0.0.0/16" -var="azs=[\"us-east-1a\",\"us-east-1b\"]"
