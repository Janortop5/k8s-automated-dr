import jenkins.model.*
import org.jenkinsci.plugins.*
import org.jenkinsci.plugins.oic.*

def instance = Jenkins.getInstance()

// Replace with your provider’s metadata URL, client ID/secret
def metadataUrl = "https://keycloak.example.com/auth/realms/myrealm/.well-known/openid-configuration"
def clientId    = "jenkins-client"
def clientSecret= "super-secret"

def realm = new OpenIdConnectSecurityRealm(
    metadataUrl,
    clientId,
    clientSecret,
    "openid email profile",     // scopes
    true,                        // useNonce
    "email",                     // nameField // maps email as Jenkins username
    "https://jenkins.example.com/securityRealm/finishLogin", // redirect URI
    []                           // additional claim mappings
)
instance.setSecurityRealm(realm)

// Use role-based strategy for authorization:
def authz = new GlobalMatrixAuthorizationStrategy()
// grant administrators full rights:
authz.add(Jenkins.ADMINISTER, "admin-group")
// grant read/build to everyone in dev-team-group:
authz.add(Jenkins.READ, "dev-team-group")
authz.add(Item.BUILD, "dev-team-group")
instance.setAuthorizationStrategy(authz)

instance.save()