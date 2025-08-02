import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import hudson.util.Secret
import org.jenkinsci.plugins.plaincredentials.impl.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*
import jenkins.model.*

def store = SystemCredentialsProvider.getInstance().getStore()

// GitHub PAT Credentials
def githubCreds = new UsernamePasswordCredentialsImpl(
    CredentialsScope.GLOBAL,
    "github-pat",
    "GitHub Personal Access Token",
    "${GIT_USERNAME}",
    "${GIT_PASSWORD}"
)

// Docker Hub Credentials  
def dockerCreds = new UsernamePasswordCredentialsImpl(
    CredentialsScope.GLOBAL,
    "dockerhub-creds",
    "Docker Hub Credentials",
    "${DOCKER_USERNAME}",
    "${DOCKER_PASSWORD}"
)

// AWS Access Key
def awsAccessKey = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    "aws-access-key",
    "AWS Access Key",
    Secret.fromString("${AWS_ACCESS_KEY}")
)

// AWS Secret Key
def awsSecretKey = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    "aws-secret-key", 
    "AWS Secret Key",
    Secret.fromString("${AWS_SECRET_KEY}")
)

// Backup Bucket
def backupBucket = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    "backup-bucket",
    "Backup Bucket Name",
    Secret.fromString("${BACKUP_BUCKET}")
)

// Backup Bucket Region
def backupBucketRegion = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    "backup-bucket-region",
    "Backup Bucket Region", 
    Secret.fromString("${BACKUP_BUCKET_REGION}")
)

// SSH Key for K8s cluster
def sshKey = new BasicSSHUserPrivateKey(
    CredentialsScope.GLOBAL,
    "k8s-ssh-key",
    "ec2-user",
    new BasicSSHUserPrivateKey.DirectEntryPrivateKeySource("${SSH_PRIVATE_KEY}"),
    "",
    "SSH Key for K8s Cluster Access"
)

// Add all credentials
[githubCreds, dockerCreds, awsAccessKey, awsSecretKey, backupBucket, backupBucketRegion, sshKey].each { cred ->
    try {
        store.addCredentials(Domain.global(), cred)
        println("✅ Added credential: ${cred.id}")
    } catch (Exception e) {
        println("⚠️  Credential ${cred.id} already exists or error: ${e.message}")
    }
}

println("🎉 Credential setup completed!")