import jenkins.model.*
import org.csanchez.jenkins.plugins.kubernetes.*
import org.csanchez.jenkins.plugins.kubernetes.pod.retention.*
import org.csanchez.jenkins.plugins.kubernetes.volumes.*
import org.csanchez.jenkins.plugins.kubernetes.model.*
import com.cloudbees.plugins.credentials.*

def jenkins = Jenkins.getInstance()

// Remove existing Kubernetes cloud if present
def existingCloud = jenkins.clouds.find { it.name == "${CLOUD_NAME}" }
if (existingCloud) {
    jenkins.clouds.remove(existingCloud)
    println("🗑️  Removed existing Kubernetes cloud: ${CLOUD_NAME}")
}

// Create new Kubernetes cloud configuration
def kubernetesCloud = new KubernetesCloud("${CLOUD_NAME}")

// Basic configuration
kubernetesCloud.setServerUrl("${K8S_SERVER_URL}")
kubernetesCloud.setNamespace("${K8S_NAMESPACE}")
kubernetesCloud.setJenkinsUrl("${JENKINS_URL}")
kubernetesCloud.setJenkinsTunnel("${JENKINS_TUNNEL}")
kubernetesCloud.setCredentialsId("${CREDENTIALS_ID}")
kubernetesCloud.setContainerCapStr("${CONTAINER_CAP}")
kubernetesCloud.setRetentionTimeout(5)
kubernetesCloud.setConnectTimeout(5)
kubernetesCloud.setReadTimeout(15)

// Pod retention policy
kubernetesCloud.setPodRetention(new OnFailure())

// Configure default pod template
def podTemplate = new PodTemplate()
podTemplate.setName("default-agent")
podTemplate.setLabel("jenkins-agent")
podTemplate.setServiceAccount("jenkins")
podTemplate.setNodeUsageMode(Node.Mode.NORMAL)

// Configure JNLP container
def jnlpContainer = new ContainerTemplate("jnlp", "jenkins/inbound-agent:latest")
jnlpContainer.setArgs("${computer.jnlpmac} ${computer.name}")  
jnlpContainer.setAlwaysPullImage(false)
jnlpContainer.setWorkingDir("/home/jenkins/agent")

// Resource limits for JNLP container
jnlpContainer.setResourceRequestMemory("256Mi")
jnlpContainer.setResourceLimitMemory("512Mi")
jnlpContainer.setResourceRequestCpu("100m")
jnlpContainer.setResourceLimitCpu("500m")

podTemplate.getContainers().add(jnlpContainer)

// Add Docker container for Docker builds
def dockerContainer = new ContainerTemplate("docker", "docker:dind")
dockerContainer.setPrivileged(true)
dockerContainer.setAlwaysPullImage(false)
dockerContainer.setWorkingDir("/home/jenkins/agent")
dockerContainer.setResourceRequestMemory("512Mi")
dockerContainer.setResourceLimitMemory("1Gi")
dockerContainer.setResourceRequestCpu("200m")
dockerContainer.setResourceLimitCpu("1000m")

podTemplate.getContainers().add(dockerContainer)

// Add kubectl container for Kubernetes operations
def kubectlContainer = new ContainerTemplate("kubectl", "bitnami/kubectl:latest")
kubectlContainer.setCommand("sleep")
kubectlContainer.setArgs("infinity")
kubectlContainer.setAlwaysPullImage(false)
kubectlContainer.setWorkingDir("/home/jenkins/agent")

podTemplate.getContainers().add(kubectlContainer)

// Add volumes for Docker socket and workspace
def dockerSocketVolume = new HostPathVolume("/var/run/docker.sock", "/var/run/docker.sock")
podTemplate.getVolumes().add(dockerSocketVolume)

kubernetesCloud.addTemplate(podTemplate)

// Add the cloud to Jenkins
jenkins.clouds.add(kubernetesCloud)
jenkins.save()

println("✅ Kubernetes cloud '${CLOUD_NAME}' configured successfully")
println("📋 Configuration:")
println("   Server URL: ${K8S_SERVER_URL}")
println("   Namespace: ${K8S_NAMESPACE}")
println("   Credentials: ${CREDENTIALS_ID}")
println("   Jenkins URL: ${JENKINS_URL}")