#!/bin/bash
set -eo pipefail

# Validate required environment variables
echo "Validating Environment Variables"
if [[ -z "${AWS_DEFAULT_REGION}" ]]; then echo "ERROR: Missing required 'AWS_DEFAULT_REGION' environment variable"; fi
if [[ -z "${AWS_ACCESS_KEY_ID}" ]]; then echo "ERROR: Missing required 'AWS_ACCESS_KEY_ID' environment variable"; fi
if [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then echo "ERROR: Missing required 'AWS_SECRET_ACCESS_KEY' environment variable"; fi
if [[ -z "${DESTINATION_BUCKET}" ]]; then echo "ERROR: Missing required 'DESTINATION_BUCKET' environment variable"; fi
if [[ -z "${GITHUB_SHA}" ]]; then echo "ERROR: Missing required 'GITHUB_SHA' environment variable"; fi
if [[ -z "${SOURCE_PATH}" ]]; then echo "ERROR: Missing required 'SOURCE_PATH' environment variable"; fi

# If an environment file was specified, make sure it exists before we start
if [[ -n "${ENVIRONMENT_SOURCE_FILENAME}" && ! -f "${ENVIRONMENT_SOURCE_FILENAME}" ]]; then echo "ERROR: The specified environment file (${ENVIRONMENT_SOURCE_FILENAME}) could not be found"; exit 1; fi

# Sync files to S3 bucket
echo "Syncing To S3 Bucket"
aws s3 sync "${SOURCE_PATH}" "s3://${DESTINATION_BUCKET}" --acl "${ACL}" --metadata "Commit=${GITHUB_SHA}" --delete;

# Copy environment file
if [[ -n "${ENVIRONMENT_SOURCE_FILENAME}" ]]; then
  if [[ -z "${ENVIRONMENT_TARGET_FILENAME}" ]]; then
    export ENVIRONMENT_TARGET_FILENAME='env.js'
  fi
  echo "Creating Environment File: s3://${DESTINATION_BUCKET}/${ENVIRONMENT_TARGET_FILENAME}"
  aws s3 cp "${ENVIRONMENT_SOURCE_FILENAME}" "s3://${DESTINATION_BUCKET}/${ENVIRONMENT_TARGET_FILENAME}"
fi

# Fix the mime types that AWS seems intent on screwing up
if [[ -z "${ACL}" ]]; then export ACL="public-read"; fi
echo "Rewriting MIME Types: text/css"
aws s3 cp "s3://${DESTINATION_BUCKET}/" "s3://${DESTINATION_BUCKET}/" --exclude "*" --recursive --metadata-directive "REPLACE" --acl "${ACL}" --include "*.css" --content-type "text/css"
echo "Rewriting MIME Types: text/javascript"
aws s3 cp "s3://${DESTINATION_BUCKET}/" "s3://${DESTINATION_BUCKET}/" --exclude "*" --recursive --metadata-directive "REPLACE" --acl "${ACL}" --include "*.js" --content-type "text/javascript"
echo "Rewriting MIME Types: text/html"
aws s3 cp "s3://${DESTINATION_BUCKET}/" "s3://${DESTINATION_BUCKET}/" --exclude "*" --recursive --metadata-directive "REPLACE" --acl "${ACL}" --include "*.html" --content-type "text/html"
echo "Rewriting MIME Types: application/json"
aws s3 cp "s3://${DESTINATION_BUCKET}/" "s3://${DESTINATION_BUCKET}/" --exclude "*" --recursive --metadata-directive "REPLACE" --acl "${ACL}" --include "*.json" --content-type "application/json"
echo "S3 Deployment Completed"

# Invalidate the distribution
if [[ -n "${INVALIDATE_CLOUDFRONT_VERSION}" ]]; then
  echo "Invalidating CloudFront Distributions"
  for dist in $(aws cloudfront list-distributions | jq -r ".DistributionList.Items[].ARN")
  do
    if [[ $(aws cloudfront list-tags-for-resource --resource "${dist}" | jq '.Tags.Items[] | select(.Key==Version") | .Value=="${INVALIDATE_CLOUDFRONT_VERSION}"') == "true" ]]; then
      cloudfront_id=$(cut -d '/' -f2 <<< "${dist}")
      echo -e "Invalidating: ${cloudfront_id}\n"
      aws cloudfront create-invalidation --distribution-id "${cloudfront_id}" --paths "/*" --region "us-east-1" &
    fi
  done
  echo "CloudFront Invalidation Completed"
fi
