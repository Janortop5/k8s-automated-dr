import json
import urllib3
import base64
from urllib.parse import urlencode
import os
JENKINS_URL = os.environ['JENKINS_URL']
JENKINS_USER = os.environ['JENKINS_USER'] 
JENKINS_API_TOKEN = os.environ['JENKINS_API_TOKEN']

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def lambda_handler(event, context):
    """
    AWS Lambda function to trigger Jenkins multibranch pipeline builds with parameters
    """
    
    # Pipeline configuration
    PIPELINE_NAME = "Pipeline"  # multibranch pipeline name
    BRANCH_NAME = "main"        # Branch to trigger
    
    try:
        # Extract parameters from Lambda event
        parameters = {}
        
        if 'body' in event:
            # If called via API Gateway
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
            parameters = body.get('parameters', {})
        else:
            # If called directly
            parameters = event.get('parameters', {})
        
        # Default parameters for your pipeline
        build_params = {
            'DEPLOY_STANDBY_ONLY': parameters.get('deploy_standby_only', 'false'),
            'DESTROY_AFTER_APPLY': parameters.get('destroy_after_apply', 'false'),
            'SKIP_TESTS': parameters.get('skip_tests', 'false')
        }
        
        # Create authentication header
        credentials = f"{JENKINS_USER}:{JENKINS_API_TOKEN}"
        encoded_credentials = base64.b64encode(credentials.encode()).decode()
        headers = {
            'Authorization': f'Basic {encoded_credentials}',
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        
        # Build Jenkins URL for parameterized build
        jenkins_build_url = f"{JENKINS_URL}/job/{PIPELINE_NAME}/job/{BRANCH_NAME}/buildWithParameters"
        
        # Create HTTP client (disable SSL verification for self-signed certificates)
        http = urllib3.PoolManager(cert_reqs='CERT_NONE')
        
        # Prepare form data
        form_data = urlencode(build_params)
        
        # Trigger the build
        response = http.request(
            'POST',
            jenkins_build_url,
            body=form_data,
            headers=headers
        )
        
        if response.status == 201:
            # Build queued successfully
            queue_location = response.headers.get('Location', '')
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Build triggered successfully',
                    'jenkins_url': jenkins_build_url,
                    'parameters': build_params,
                    'queue_location': queue_location
                })
            }
        else:
            return {
                'statusCode': response.status,
                'body': json.dumps({
                    'error': f'Failed to trigger build. Status: {response.status}',
                    'response': response.data.decode() if response.data else ''
                })
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'Lambda execution failed: {str(e)}'
            })
        }
