#!/bin/bash

# TrainTally Backend Deployment Script
# This script automates the deployment of the TrainTally AWS infrastructure

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="${STACK_NAME:-traintally-backend}"
REGION="${AWS_REGION:-us-east-1}"
STAGE="${STAGE:-dev}"
PROFILE="${AWS_PROFILE:-default}"

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}TrainTally Backend Deployment${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Stage: $STAGE"
echo "AWS Profile: $PROFILE"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Install with: brew install awscli"
    exit 1
fi

# Check SAM CLI
if ! command -v sam &> /dev/null; then
    echo -e "${RED}Error: SAM CLI is not installed${NC}"
    echo "Install with: brew install aws-sam-cli"
    exit 1
fi

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Verify AWS credentials
echo -e "${YELLOW}Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity --profile "$PROFILE" &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured for profile '$PROFILE'${NC}"
    echo "Run: aws configure --profile $PROFILE"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
echo -e "${GREEN}✓ Authenticated as account: $ACCOUNT_ID${NC}"
echo ""

# Build application
echo -e "${YELLOW}Building SAM application...${NC}"
sam build --parallel --cached
echo -e "${GREEN}✓ Build complete${NC}"
echo ""

# Deploy
echo -e "${YELLOW}Deploying to AWS...${NC}"
if [ "$1" == "--guided" ]; then
    # First-time deployment with prompts
    sam deploy --guided \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --parameter-overrides "Stage=$STAGE" \
        --capabilities CAPABILITY_IAM
else
    # Subsequent deployments use saved config
    sam deploy \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --parameter-overrides "Stage=$STAGE" \
        --capabilities CAPABILITY_IAM \
        --no-confirm-changeset
fi

echo -e "${GREEN}✓ Deployment complete${NC}"
echo ""

# Get outputs
echo -e "${YELLOW}Fetching stack outputs...${NC}"
API_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
    --output text)

USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
    --output text)

USER_POOL_CLIENT_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
    --output text)

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Deployment Successful!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "📍 API Endpoint:"
echo "   $API_URL"
echo ""
echo "🔐 Cognito User Pool ID:"
echo "   $USER_POOL_ID"
echo ""
echo "📱 Cognito Client ID:"
echo "   $USER_POOL_CLIENT_ID"
echo ""
echo "🌍 Region:"
echo "   $REGION"
echo ""

# Save to config file for iOS app
echo -e "${YELLOW}Saving configuration for iOS app...${NC}"
cat > aws-config.json << EOF
{
  "apiUrl": "$API_URL",
  "region": "$REGION",
  "userPoolId": "$USER_POOL_ID",
  "userPoolClientId": "$USER_POOL_CLIENT_ID",
  "stage": "$STAGE"
}
EOF

echo -e "${GREEN}✓ Configuration saved to aws-config.json${NC}"
echo ""

# Test API
echo -e "${YELLOW}Testing API health...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/")
if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 404 ]; then
    echo -e "${GREEN}✓ API is responding${NC}"
else
    echo -e "${YELLOW}⚠ API returned HTTP $HTTP_CODE (this may be expected if no root endpoint is defined)${NC}"
fi
echo ""

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "1. Copy the configuration values above to your iOS app"
echo "2. Create a test Cognito user:"
echo "   aws cognito-idp admin-create-user \\"
echo "     --user-pool-id $USER_POOL_ID \\"
echo "     --username testuser \\"
echo "     --temporary-password 'TempPass123!' \\"
echo "     --user-attributes Name=email,Value=test@example.com Name=email_verified,Value=true \\"
echo "     --profile $PROFILE"
echo ""
echo "3. Set permanent password:"
echo "   aws cognito-idp admin-set-user-password \\"
echo "     --user-pool-id $USER_POOL_ID \\"
echo "     --username testuser \\"
echo "     --password 'MySecurePass123!' \\"
echo "     --permanent \\"
echo "     --profile $PROFILE"
echo ""
echo "4. Test an endpoint:"
echo "   curl -X GET \"$API_URL/games\" \\"
echo "     -H \"Authorization: Bearer <JWT_TOKEN>\""
echo ""
echo "5. Monitor logs:"
echo "   sam logs -n SubmitGameFunction --tail --profile $PROFILE"
echo ""
echo -e "${GREEN}Happy coding! 🚂${NC}"
