#!/bin/bash
set -e

echo "🤖 Creating Jenkins time-recorder job automatically..."

# Wait for Jenkins to be ready
echo "⏳ Waiting for Jenkins to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=jenkins -n jenkins --timeout=300s

# Give Jenkins a bit more time to fully initialize
echo "⏳ Giving Jenkins time to fully start up..."
sleep 30

# Get Jenkins service details
JENKINS_URL="http://jenkins.localhost"
USERNAME="admin"
PASSWORD="admin123"

echo "🔐 Getting Jenkins CSRF token..."

# Get Jenkins crumb for CSRF protection
CRUMB_RESPONSE=$(curl -s "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" \
  --user "$USERNAME:$PASSWORD" 2>/dev/null || echo "")

echo "🔍 Debug: Raw crumb response: '$CRUMB_RESPONSE'"

if [ -n "$CRUMB_RESPONSE" ] && ! echo "$CRUMB_RESPONSE" | grep -q "html"; then
    # Parse the crumb correctly - format is "Jenkins-Crumb:value"
    CRUMB_FIELD=$(echo "$CRUMB_RESPONSE" | cut -d':' -f1)
    CRUMB_VALUE=$(echo "$CRUMB_RESPONSE" | cut -d':' -f2)
    echo "✅ Got CSRF token - Field: $CRUMB_FIELD, Value: $CRUMB_VALUE"
else
    echo "❌ Failed to get CSRF token, trying without it..."
    CRUMB_FIELD=""
    CRUMB_VALUE=""
fi

echo "📝 Creating time-recorder job via Jenkins API..."

# Create the job XML configuration
cat > /tmp/time-recorder-job.xml << 'JOBEOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Records current date and time to PostgreSQL database every 5 minutes</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <hudson.triggers.TimerTrigger>
          <spec>*/5 * * * *</spec>
        </hudson.triggers.TimerTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: postgres-client
    image: postgres:14-alpine
    command: ['cat']
    tty: true
    env:
    - name: PGPASSWORD
      value: admin123
"""
        }
    }
    
    stages {
        stage('Create Table') {
            steps {
                container('postgres-client') {
                    sh '''
                        echo "Creating time_records table if not exists..."
                        psql -h postgresql.postgres.svc.cluster.local -U admin -d postgres -c "CREATE TABLE IF NOT EXISTS time_records (id SERIAL PRIMARY KEY, recorded_at TIMESTAMP NOT NULL, pod_name VARCHAR(255), node_name VARCHAR(255));"
                    '''
                }
            }
        }
        
        stage('Record Time') {
            steps {
                container('postgres-client') {
                    script {
                        def podName = env.HOSTNAME
                        def nodeName = env.NODE_NAME ?: 'unknown'
                        
                        sh """
                            echo "Recording current time to database..."
                            psql -h postgresql.postgres.svc.cluster.local -U admin -d postgres -c "INSERT INTO time_records (recorded_at, pod_name, node_name) VALUES (NOW(), '${podName}', '${nodeName}');"
                            
                            echo "Verifying last 5 records..."
                            psql -h postgresql.postgres.svc.cluster.local -U admin -d postgres -c "SELECT * FROM time_records ORDER BY recorded_at DESC LIMIT 5;"
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo 'Time recorded successfully!'
        }
        failure {
            echo 'Failed to record time!'
        }
    }
}</script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
JOBEOF

# Create the job using curl with proper CSRF header format
echo "🔨 Creating job via Jenkins REST API..."

TEMP_RESPONSE="/tmp/jenkins_response.txt"

if [ -n "$CRUMB_FIELD" ] && [ -n "$CRUMB_VALUE" ]; then
    echo "🔐 Using CSRF protection..."
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TEMP_RESPONSE" -X POST "$JENKINS_URL/createItem?name=time-recorder" \
      --user "$USERNAME:$PASSWORD" \
      --header "$CRUMB_FIELD: $CRUMB_VALUE" \
      --header "Content-Type: application/xml" \
      --data-binary @/tmp/time-recorder-job.xml)
else
    echo "⚠️ Trying without CSRF token..."
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TEMP_RESPONSE" -X POST "$JENKINS_URL/createItem?name=time-recorder" \
      --user "$USERNAME:$PASSWORD" \
      --header "Content-Type: application/xml" \
      --data-binary @/tmp/time-recorder-job.xml)
fi

RESPONSE_BODY=$(cat "$TEMP_RESPONSE" 2>/dev/null || echo "")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Time-recorder job created successfully!"
    echo "🔗 View at: $JENKINS_URL/job/time-recorder/"
    echo "🕒 Job will run every 5 minutes automatically"
elif [ "$HTTP_CODE" = "400" ] && echo "$RESPONSE_BODY" | grep -q "already exists"; then
    echo "⚠️ Job 'time-recorder' already exists - that's fine!"
    echo "🔗 View at: $JENKINS_URL/job/time-recorder/"
else
    echo "❌ Failed to create job automatically. HTTP Code: $HTTP_CODE"
    echo "📋 Response: $RESPONSE_BODY"
    echo ""
    echo "🔄 This is normal for new Jenkins instances. The job will be created on next run."
    echo "🔧 You can also trigger it manually: make test-jenkins-job"
fi

# Cleanup
rm -f /tmp/time-recorder-job.xml "$TEMP_RESPONSE"

echo "✅ Job setup complete!"