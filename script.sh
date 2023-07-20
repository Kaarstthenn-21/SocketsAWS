#!/bin/bash

#TODO: Se debe realizar el cambio antes del despliegue

# CONFIG_FILE=${2:-config.ini}
# . $CONFIG_FILE

source ./config.ini

PARAMETERS="ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME \
            ParameterKey=ENV,ParameterValue=$ENV \
            ParameterKey=MN,ParameterValue=$MN \
            ParameterKey=Bucket,ParameterValue=$BUCKET \
            ParameterKey=DatabaseName,ParameterValue=$DATABASE_NAME \
            ParameterKey=RetentionInDays,ParameterValue=$RETENTION_INDAYS"

sync_templates() {
  aws s3 sync ./ s3://$BUCKET/templates/ --exclude ".git/*" --exclude "*.ini" --exclude ".sh" --delete
}

show_help() {
  echo "Usage: chmod +x script.sh"
  echo "  ./script -h     display this help message"
  echo "  ./script sync   Sync files"
  echo "  ./script create Create the stack"
  echo "  ./script update Update the stack"
  echo "  ./script cs     Create a change set"
}

create_arch() {
  TEST=$(aws s3 ls | grep "$BUCKET$" | wc -l)
  if [ "$TEST" == "0" ]; then
    aws s3 mb s3://$BUCKET || exit 0
  fi
  aws s3 mb s3://$BUCKET
  aws s3api put-bucket-cors --bucket $BUCKET --cors-configuration '{"CORSRules" : [{"AllowedHeaders":["*"],"AllowedMethods":["GET","PUT", "POST", "DELETE", "HEAD"],"AllowedOrigins":["*"],"ExposeHeaders":["ETag"]}]}'
  sync_templates
  aws cloudformation create-stack --stack-name $STACK_NAME --template-body file://main.cf.yaml --capabilities CAPABILITY_NAMED_IAM --parameters $PARAMETERS
}

update_arch() {
  aws s3api put-bucket-cors --bucket $BUCKET --cors-configuration '{"CORSRules" : [{"AllowedHeaders":["*"],"AllowedMethods":["GET","PUT", "POST", "DELETE", "HEAD"],"AllowedOrigins":["*"],"ExposeHeaders":["ETag"]}]}'
  sync_templates
  aws cloudformation update-stack --stack-name $STACK_NAME --template-body file://main.cf.yaml --capabilities CAPABILITY_NAMED_IAM --parameters $PARAMETERS
}

create_change_set() {
  sync_templates
  aws cloudformation create-change-set --change-set-name update --stack-name $STACK_NAME --template-body file://main.cf.yaml --capabilities CAPABILITY_NAMED_IAM --parameters $PARAMETERS
}

delete_arch() {
  sync_templates
  # aws s3 rm s3://$BUCKET --recursive
  aws cloudformation delete-stack --stack-name $STACK_NAME
}

case ${1} in
"-h" | "--help") show_help ;;
"sync") sync_templates ;;
"create") create_arch ;;
"update") update_arch ;;
"delete") delete_arch ;;
"cs") create_change_set ;;
esac
