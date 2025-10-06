#!/bin/bash

# Make all AWS scripts executable
echo "Making AWS scripts executable..."

chmod +x aws/scripts/setup-infrastructure.sh
chmod +x aws/scripts/deploy.sh
chmod +x aws/terraform/jenkins/jenkins-userdata.sh

echo "✅ All AWS scripts are now executable"

# Display helpful information
echo ""
echo "🚀 Nash PiSharp AWS Infrastructure Ready!"
echo "========================================"
echo ""
echo "📁 Key Files Created:"
echo "---------------------"
echo "• aws/terraform/              - Terraform infrastructure modules"
echo "• aws/charts/nash-pisharp-app/ - Helm chart for application"
echo "• aws/jenkins/Jenkinsfile      - CI/CD pipeline definition"
echo "• aws/scripts/                 - Deployment automation scripts"
echo ""
echo "📋 Quick Start Commands:"
echo "------------------------"
echo "1. Setup complete infrastructure:"
echo "   ./aws/scripts/setup-infrastructure.sh setup"
echo ""
echo "2. Deploy application only:"
echo "   ./aws/scripts/deploy.sh deploy"
echo ""
echo "3. Check deployment status:"
echo "   ./aws/scripts/setup-infrastructure.sh info"
echo ""
echo "📚 Documentation:"
echo "-----------------"
echo "• README-AWS.md           - Comprehensive AWS guide"
echo "• DEPLOYMENT_GUIDE_AWS.md - Step-by-step deployment"
echo "• ARCHITECTURE_AWS.md     - Architecture overview"
echo ""
echo "🎯 Next Steps:"
echo "--------------"
echo "1. Review and customize terraform.tfvars"
echo "2. Ensure AWS CLI is configured"
echo "3. Run the setup script to deploy infrastructure"
echo "4. Configure Jenkins and deploy your application"
echo ""
echo "🤝 Need Help?"
echo "-------------"
echo "• Check the troubleshooting sections in the guides"
echo "• Review AWS CloudWatch logs for detailed errors"
echo "• Ensure proper IAM permissions are configured"
echo ""